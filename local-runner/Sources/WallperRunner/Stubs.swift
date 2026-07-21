import Foundation
import Combine
import AppKit
import IOKit.ps

// MARK: - Safety-Mode Stubs
// These are minimal implementations to allow the open-source files to compile
// without performing any system changes (wallpapers, screensavers, etc.).

@MainActor
final class LicenseManager {
    var isChecked: Bool = false

    func checkFirstSeen(for _: String) {}

    func checkLicense(for _: String) {
        isChecked = true
    }
}

@MainActor
final class VideoLibraryStore {
    func loadAll() async {}
    func loadCachedVideos() {}
}

@MainActor
final class VideoFilterStore {
    func fetchDynamicFilters() async {}
}

@MainActor
final class WallperUI {}

@MainActor
final class DeviceLoader {
    private(set) var isLoaded: Bool = false
    func loadAllDevices() { isLoaded = true }
}

extension VideoLibraryStore: @unchecked Sendable {}
extension VideoFilterStore: @unchecked Sendable {}
extension DeviceLoader: @unchecked Sendable {}

@MainActor
final class WindowManager {
    static let shared = WindowManager()

    var cancellables = Set<AnyCancellable>()
    private(set) var isUIReady: Bool = false

    func setupStatusBarMenu() {}
    func setCanOpenUI(_ ready: Bool) { isUIReady = ready }

    func launchMainWindow(
        licenseManager _: LicenseManager,
        videoLibrary _: VideoLibraryStore,
        filterStore _: VideoFilterStore,
        ui _: WallperUI,
        deviceLoader _: DeviceLoader
    ) {}

    func restoreFromDockClick() {}
}

enum WallpaperRestorer {
    static func restore() {}
}

@MainActor
final class PowerMonitor {
    static let shared = PowerMonitor()
    private var timer: Timer?

    func startMonitoring() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            _ = self.isCurrentlyOnBattery()
        }
    }

    func checkPowerStatus() {
        _ = isCurrentlyOnBattery()
    }

    func isCurrentlyOnBattery() -> Bool {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef]
        else {
            return false
        }

        for ps in list {
            if let desc = IOPSGetPowerSourceDescription(info, ps)?.takeUnretainedValue() as? [String: Any],
               let state = desc[kIOPSPowerSourceStateKey as String] as? String {
                return state == kIOPSBatteryPowerValue
            }
        }

        return false
    }
}

@MainActor
final class Env {
    static let shared = Env()
    func loadSyncFromLambda() {}
}

func logDeviceToLambda() {}

final class BanChecker {
    func checkBanStatus(completion: @escaping (Bool) -> Void) {
        completion(false)
    }
}

@MainActor
final class UpdateManager {
    static let shared = UpdateManager()

    var didFinishCheck: Bool = true
    var isUpdateAvailable: Bool = false
    var updateInfo: UpdateInfo? = nil

    func checkForUpdate() {
        didFinishCheck = true
        isUpdateAvailable = false
    }

    func startUpdate() {}
}

struct UpdateInfo {
    let version: String
}

enum HWIDProvider {
    static func getHWID() -> String { "LOCAL-HWID" }
}

enum DisplaySettingsStorage {
    static func load(for _: String) -> DisplayConfig? { nil }
}

struct DisplayConfig {
    var scale: CGFloat = 1.0
    var offset: CGSize = .zero
}

@MainActor
final class ScreensaverManager {
    static let shared = ScreensaverManager()
    func installOrUpdateSaver(with _: URL) {}
}

enum LaunchAgentManager {
    private static let label = "com.local.wallperrunner"

    private static var plistURL: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent("Library/LaunchAgents/\(label).plist")
    }

    static func install() throws {
        let appPath = Bundle.main.bundlePath
        let plist: [String: Any] = [
            "Label": label,
            "ProgramArguments": [appPath + "/Contents/MacOS/WallperRunner"],
            "RunAtLoad": true,
            "KeepAlive": true
        ]

        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try FileManager.default.createDirectory(
            at: plistURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: plistURL, options: .atomic)

        try runLaunchctl(["bootstrap", "gui/\(getuid())", plistURL.path])
    }

    static func uninstall() throws {
        if FileManager.default.fileExists(atPath: plistURL.path) {
            try runLaunchctl(["bootout", "gui/\(getuid())", plistURL.path])
            try FileManager.default.removeItem(at: plistURL)
        }
    }

    private static func runLaunchctl(_ args: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = args
        try process.run()
        process.waitUntilExit()
        if process.terminationStatus != 0 {
            throw NSError(domain: "Launchctl", code: Int(process.terminationStatus), userInfo: [
                NSLocalizedDescriptionKey: "launchctl failed with code \(process.terminationStatus)"
            ])
        }
    }
}
