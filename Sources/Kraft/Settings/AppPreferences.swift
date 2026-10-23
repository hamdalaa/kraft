import AppKit
import KraftCore
import Observation
import SwiftUI

/// The owner's UI preferences, in one place: language (applies on relaunch), digits and appearance (apply live).
/// Views read it through the environment (`kraftEnvironment()`); services read `AppPreferences.shared`.
@MainActor
@Observable
final class AppPreferences {
    static let shared = AppPreferences()

    private enum Key {
        static let digits = "KraftDigits"
        static let appearance = "KraftAppearance"
        static let languages = "AppleLanguages"
    }

    @ObservationIgnored private let defaults: UserDefaults

    /// The language this launch runs in (`"en"` / `"ar"`): what the bundle actually loaded.
    let runningLanguage: String
    /// The choice at launch, to tell whether a relaunch is pending.
    @ObservationIgnored private let launchLanguage: AppLanguage

    var digits: DigitStyle {
        didSet { defaults.set(digits.rawValue, forKey: Key.digits) }
    }

    /// System / Light / Dark for every window, panel, popover and menu (`NSApp.appearance`).
    var appearance: AppAppearance {
        didSet {
            defaults.set(appearance.rawValue, forKey: Key.appearance)
            applyAppearance()
        }
    }

    /// Written to the app's own `AppleLanguages`, which the next launch picks up.
    var language: AppLanguage {
        didSet {
            if let codes = language.appleLanguages { defaults.set(codes, forKey: Key.languages) } else { defaults.removeObject(forKey: Key.languages) }
        }
    }

    init(defaults: UserDefaults = .standard, bundle: Bundle = .main) {
        self.defaults = defaults
        runningLanguage = bundle.preferredLocalizations.first.map { String($0.prefix(2)) } ?? "en"
        digits = defaults.string(forKey: Key.digits).flatMap(DigitStyle.init(rawValue:)) ?? .western
        appearance = AppAppearance(storedValue: defaults.string(forKey: Key.appearance))
        // Only the app's own override counts as a choice; the Mac's list (global domain) is "System".
        let own = bundle.bundleIdentifier.flatMap { defaults.persistentDomain(forName: $0)?[Key.languages] as? [String] }
        let choice = AppLanguage(appleLanguages: own)
        language = choice
        launchLanguage = choice
    }

    var format: KraftFormat { KraftFormat(language: runningLanguage, digits: digits) }
    var layoutDirection: LayoutDirection { format.isRightToLeft ? .rightToLeft : .leftToRight }
    var needsRelaunch: Bool { language != launchLanguage }

    /// Nil follows the Mac. Desktop stickies and the ⌥Space panel inherit it with every other window.
    func applyAppearance() {
        NSApp?.appearance = switch appearance {
        case .system: nil
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        }
    }

    /// The scheme offscreen renders use (they have no window to inherit from); System renders light.
    var snapshotScheme: ColorScheme { appearance == .dark ? .dark : .light }

    /// Starts a fresh copy once this one has quit, then quits.
    func relaunch() {
        let path = Bundle.main.bundleURL.path
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c", "while kill -0 \(ProcessInfo.processInfo.processIdentifier) 2>/dev/null; do sleep 0.2; done; /usr/bin/open \"$0\"", path]
        do {
            try task.run()
            NSApp.terminate(nil)
        } catch {
            NSLog("Kraft: relaunch failed: %@", error.localizedDescription)
        }
    }
}

/// Number and date formatting for the UI language and digit choice. (No `@Entry`: macros need Xcode.)
private struct KraftFormatKey: EnvironmentKey {
    static let defaultValue = KraftFormat()
}

extension EnvironmentValues {
    var kraftFormat: KraftFormat {
        get { self[KraftFormatKey.self] }
        set { self[KraftFormatKey.self] = newValue }
    }
}

extension View {
    /// Locale, direction and formats from `AppPreferences`. Put on every root view: windows, panels, snapshots.
    func kraftEnvironment(_ preferences: AppPreferences = .shared) -> some View {
        modifier(KraftEnvironment(preferences: preferences))
    }
}

private struct KraftEnvironment: ViewModifier {
    let preferences: AppPreferences

    func body(content: Content) -> some View {
        let format = preferences.format
        content
            .environment(\.kraftFormat, format)
            .environment(\.locale, format.locale)
            .environment(\.layoutDirection, preferences.layoutDirection)
            .environment(preferences)
    }
}
