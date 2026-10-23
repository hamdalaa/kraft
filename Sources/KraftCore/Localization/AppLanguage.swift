import Foundation

/// The Settings language choice. Kraft ships English and Arabic; "System" follows the Mac.
public enum AppLanguage: String, CaseIterable, Sendable {
    case system, english, arabic

    public static let shipped = ["en", "ar"]

    /// Value for the app's own `AppleLanguages` default; nil means "no override, follow the Mac".
    public var appleLanguages: [String]? {
        switch self {
        case .system: nil
        case .english: ["en"]
        case .arabic: ["ar"]
        }
    }

    /// Reads back the app's `AppleLanguages` override.
    public init(appleLanguages: [String]?) {
        switch appleLanguages?.first.map({ String($0.prefix(2)) }) {
        case "en": self = .english
        case "ar": self = .arabic
        default: self = .system
        }
    }

    /// The UI language the app runs in for these preferred languages: the first shipped match, else English.
    public static func resolve(preferred: [String]) -> String {
        Bundle.preferredLocalizations(from: shipped, forPreferences: preferred).first ?? "en"
    }

    /// The language this choice leads to on the next launch, given the Mac's own preferred languages.
    public func uiLanguage(system preferred: [String]) -> String {
        Self.resolve(preferred: appleLanguages ?? preferred)
    }
}
