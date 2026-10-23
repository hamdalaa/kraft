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
        defaults.removePersistentDomain(forName: suite)
        return [
            ("settings", AnyView(SettingsView().kraftEnvironment(fresh))),
            ("settings-relaunch", AnyView(SettingsView().kraftEnvironment(changed))),
        ]
    }
}
