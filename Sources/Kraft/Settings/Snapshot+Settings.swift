import KraftCore
import SwiftUI

extension Snapshot {
    /// Offscreen renders for Settings: as it opens, and after picking another language with Arabic digits.
    static func settingsShots() -> [(String, AnyView)] {
        let suite = "io.github.hamdalaa.kraft.snapshot-settings"
        let defaults = UserDefaults(suiteName: suite) ?? .standard
        defaults.removePersistentDomain(forName: suite)
        let fresh = AppPreferences(defaults: defaults)
        let changed = AppPreferences(defaults: defaults)
        changed.language = fresh.runningLanguage == "ar" ? .english : .arabic
        changed.digits = .arabic
        // Show the appearance being rendered as the chosen one.
        fresh.appearance = AppPreferences.shared.appearance
        changed.appearance = AppPreferences.shared.appearance
        defaults.removePersistentDomain(forName: suite)
        return [
            ("settings", AnyView(SettingsView().kraftEnvironment(fresh))),
            ("settings-relaunch", AnyView(SettingsView().kraftEnvironment(changed))),
            ("settings-update", AnyView(SettingsView(updater: sampleUpdater(defaults)).kraftEnvironment(fresh))),
        ]
    }

    /// Settings › Updates with a newer release waiting (no network: the release is made up here).
    private static func sampleUpdater(_ defaults: UserDefaults) -> Updater {
        let release = AppRelease(version: AppVersion("9.9.0")!, title: "Kraft 9.9", notes: "",
                                 pageURL: Updater.releasesURL, downloadURL: nil)
        return Updater(defaults: defaults, state: .available(release))
    }
}
