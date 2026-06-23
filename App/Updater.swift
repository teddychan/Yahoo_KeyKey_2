import Foundation
import Sparkle

/// Owns the Sparkle updater for the lifetime of the input-method process.
/// Sparkle reads SUFeedURL / SUPublicEDKey / SUEnableAutomaticChecks from
/// Info.plist, so this wrapper only starts the controller and exposes a
/// manual check for the input menu.
///
/// Guarded: if SUPublicEDKey is absent (e.g. an ad-hoc dev build that skipped
/// the key), the updater is not started — Sparkle requires the key and would
/// otherwise log errors on every launch.
final class Updater {
    static let shared = Updater()

    private let controller: SPUStandardUpdaterController?

    private init() {
        let hasKey = (Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String)?.isEmpty == false
        guard hasKey else {
            controller = nil
            NSLog("YahooKeyKey: SUPublicEDKey missing; auto-update disabled")
            return
        }
        // startingUpdater: true begins scheduled checks using the Info.plist config.
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    /// Manual check, wired to the "檢查更新…" input-menu item.
    func checkForUpdates() {
        controller?.checkForUpdates(nil)
    }
}
