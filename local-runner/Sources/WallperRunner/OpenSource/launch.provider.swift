import Foundation

extension LicenseManager {
    @MainActor private static var didKickOff = false

    @MainActor
    func startCheckIfNeeded() {
        guard !Self.didKickOff, !isChecked else { return }
        Self.didKickOff = true
        let hwid = HWIDProvider.getHWID()
        checkLicense(for: hwid)
    }
}
