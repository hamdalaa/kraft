import Foundation
import KraftCore

/// Counted phrases with Arabic plural forms: keys `<base>.zero` … `<base>.other` in Localizable.strings,
/// each holding one `%@` for the number (already in the chosen digits).
enum Plural {
    static func string(_ base: String, _ count: Int, _ format: KraftFormat, bundle: Bundle = .main) -> String {
        let key = "\(base).\(PluralCategory.of(count, language: format.language).rawValue)"
        let template = bundle.localizedString(forKey: key, value: nil, table: nil)
        return String(format: template, format.number(count))
    }
}

extension KraftFormat {
    /// SF Symbols flip "backward" / "forward" glyphs in right-to-left on their own; plain and diagonal
    /// left/right arrows mean a direction on screen, so they are swapped here.
    func symbol(_ name: String) -> String {
        guard isRightToLeft else { return name }
        return name.split(separator: ".").map { part in
            switch part {
            case "left": "right"
            case "right": "left"
            default: String(part)
            }
        }.joined(separator: ".")
    }
}

// MARK: Display names

extension Currency {
    var title: LocalizedStringResource {
        switch self {
        case .iqd: "IQD"
        case .usd: "USD"
        }
    }
}

extension PaperColor {
    var title: String {
        switch self {
        case .lemon: String(localized: "Lemon")
        case .mint: String(localized: "Mint")
        case .sky: String(localized: "Sky")
        case .pink: String(localized: "Pink")
        case .peach: String(localized: "Peach")
        case .lilac: String(localized: "Lilac")
        case .white: String(localized: "White")
        case .custom: String(localized: "Custom colour")
        }
    }
}

extension InkColor {
    var title: String {
        switch self {
        case .graphite: String(localized: "Graphite")
        case .blue: String(localized: "Blue ink")
        case .red: String(localized: "Red ink")
        case .green: String(localized: "Green ink")
        }
    }
}
