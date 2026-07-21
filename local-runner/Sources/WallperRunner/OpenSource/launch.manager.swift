import Foundation
import Combine

@MainActor
final class LaunchBootstrapper: ObservableObject {
    static let shared = LaunchBootstrapper()
    private weak var licenseManager: LicenseManager?
    
    enum Phase: Int { case idle = 0, checking, downloading, installing, banning, ready, offline, denied }
    @Published private(set) var phase: Phase = .idle
    @Published private(set) var status: String = "Checking for updates…"
    @Published private(set) var isFinished = false
    @Published private(set) var isUpdateAvailable = false
    @Published private(set) var isAppReady = false

    private var cancellables = Set<AnyCancellable>()
    private let updater = UpdateManager.shared
    private let banChecker = BanChecker()
    private let maxRetries = 15
    private let retryDelay: TimeInterval = 10

    private var countdown = 0
    private var countdownTimer: Timer?
    private var countdownCompletion: (() -> Void)?

    private init() {}

    func start(licenseManager: LicenseManager) {
        self.licenseManager = licenseManager

        Env.shared.loadSyncFromLambda()
        log("bootstrap start")
        logDeviceToLambda()

        let hwid = HWIDProvider.getHWID()
        licenseManager.checkFirstSeen(for: hwid)
        licenseManager.checkLicense(for: hwid)

        phase = .checking
        status = "Checking for updates…"
        tryUpdateWithRetries(retries: maxRetries, delay: retryDelay)
    }

    private func tryUpdateWithRetries(retries: Int, delay: TimeInterval) {
        guard retries > 0 else {
            phase = .offline
            status = "Offline mode – could not check for updates."
            isFinished = true
            isAppReady = false
            log("OFFLINE: out of retries, giving up")
            return
        }

        status = "Checking for updates…"
        log("UPDATE: requesting check (\(retries) tries left)")
        updater.checkForUpdate()

        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            Task { @MainActor in
                guard let self else { return }

                if self.updater.didFinishCheck {
                    if self.updater.isUpdateAvailable {
                        self.isUpdateAvailable = true
                        self.phase = .downloading
                        self.status = "Update found – downloading…"
                        self.log("UPDATE: found \(self.updater.updateInfo?.version ?? "?"), downloading…")

                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            Task { @MainActor in
                                self.phase = .installing
                                self.status = "Installing update…"
                                self.log("UPDATE: installing → app will terminate & relaunch")
                                self.updater.startUpdate()
                            }
                        }
                    } else {
                        self.log("UPDATE: no update available")
                        self.runBanFlow()
                    }
                } else {
                    self.log("UPDATE: didFinishCheck = false, retrying in \(Int(delay))s (left: \(retries - 1))")
                    self.startCountdown(seconds: Int(delay)) { [weak self] in
                        guard let self else { return }
                        Task { @MainActor in
                            self.tryUpdateWithRetries(retries: retries - 1, delay: delay)
                        }
                    }
                }
            }
        }
    }

    private func runBanFlow() {
        phase = .banning
        status = "Validating access…"
        log("BAN: checking status…")

        banChecker.checkBanStatus { [weak self] banned in
            guard let self else { return }
            if banned {
                self.phase = .denied
                self.status = "Access Denied"
                self.isFinished = true
                self.isAppReady = false
                self.log("BAN: denied")
                return
            }

            self.log("BAN: allowed")
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                self.phase = .ready
                self.status = "You're up to date!"
                self.isFinished = true
                self.log("READY: finishing bootstrap")

                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.isAppReady = true
                    self.log("READY: isAppReady = true")
                }
            }
        }
    }

    // MARK: - Utilities

    private func startCountdown(seconds: Int, completion: @escaping () -> Void) {
        countdownTimer?.invalidate()
        countdown = seconds
        status = "Retrying in \(countdown)."
        log("RETRY: start \(countdown)s")
        countdownCompletion = completion
        countdownTimer = Timer.scheduledTimer(
            timeInterval: 1,
            target: self,
            selector: #selector(countdownTick(_:)),
            userInfo: nil,
            repeats: true
        )
    }

    @objc private func countdownTick(_ timer: Timer) {
        countdown -= 1
        status = "Retrying in \(countdown)."

        if countdown <= 0 {
            timer.invalidate()
            log("RETRY: fire")
            countdownCompletion?()
            countdownCompletion = nil
        }
    }

    // MARK: - Logging

    private func log(_ message: String) {
        let ts = Self.timestamp()
        print("🧭 [Bootstrap \(ts)] \(message)")
    }

    private static func timestamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f.string(from: Date())
    }
}
