import SwiftUI
import KraftCore

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }

    /// `#RRGGBB` → Color. Nil for malformed input.
    init?(hexString: String) {
        let s = hexString.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "#", with: "")
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return nil }
        self.init(hex: v)
    }
}

/// Design tokens. Values come from DESIGN.md (sampled from the references).
enum Tok {
    enum Page {
        static let base = Color(hex: 0xFDF6E6)
        static let hi = Color(hex: 0xFFF9E9)
    }

    enum Kraft {
        static let base = Color(hex: 0xCD9059)
        static let light = Color(hex: 0xD59862)
        static let deep = Color(hex: 0xB87541)
        static let ink = Color(hex: 0x744416)
        static let tabTop = Color(hex: 0xC99059)
        static let tabBottom = Color(hex: 0xB07440)
    }

    enum Grid {
        static let paper = Color(hex: 0xF3EBDD)
        static let line = Color(hex: 0xD2C9B8)
    }

    /// Sticker ink and fills (ref-6 / ref-7).
    enum Sticker {
        static let ink = Color(hex: 0x271F2C)
        static let sky = Color(hex: 0x68C9F6)
        static let coral = Color(hex: 0xFBA08E)
        static let yellow = Color(hex: 0xFFD96A)
        static let pink = Color(hex: 0xFE93B1)
        static let purple = Color(hex: 0xC3A7E1)
        static let green = Color(hex: 0x94E387)
        static let lime = Color(hex: 0xAEFF5D)
    }

    enum Stamp {
        static let red = Color(hex: 0xE0313F)
        static let pin = Color(hex: 0xFD2441)
    }

    enum Space {
        static let page: CGFloat = 20
        static let board: CGFloat = 28
    }
}

extension PaperColor {
    func color(customHex: String?) -> Color {
        switch self {
        case .lemon: Color(hex: 0xFFF1A8)
        case .mint: Color(hex: 0xDDF6D2)
        case .sky: Color(hex: 0xD8EEFC)
        case .pink: Color(hex: 0xFFDDE8)
        case .peach: Color(hex: 0xFFE2CF)
        case .lilac: Color(hex: 0xE9E0FA)
        case .white: Color(hex: 0xFFFDF6)
        case .custom: customHex.flatMap { Color(hexString: $0) } ?? Color(hex: 0xFFF1A8)
        }
    }
}

extension InkColor {
    var color: Color {
        switch self {
        case .graphite: Color(hex: 0x2E2A33)
        case .blue: Color(hex: 0x1F4FA8)
        case .red: Color(hex: 0xB3261E)
        case .green: Color(hex: 0x1E6B47)
        }
    }
}

/// Die-cut sticker artwork per kind (DESIGN.md table).
struct StickerArt {
    let symbol: String
    let fill: Color
}

extension StickyKind {
    var sticker: StickerArt {
        switch self {
        case .note: StickerArt(symbol: "square.and.pencil", fill: Tok.Sticker.sky)
        case .todo: StickerArt(symbol: "list.bullet", fill: Tok.Sticker.coral)
        case .reminder: StickerArt(symbol: "bell", fill: Tok.Sticker.yellow)
        case .owedToMe: StickerArt(symbol: "wallet.bifold", fill: Tok.Sticker.pink)
        case .iOwe: StickerArt(symbol: "creditcard", fill: Tok.Sticker.purple)
        case .bill: StickerArt(symbol: "receipt", fill: Tok.Sticker.green)
        }
    }
}

extension BoardTab {
    var title: String {
        switch self {
        case .all: String(localized: "All")
        case .today: String(localized: "Today")
        case .money: String(localized: "Money")
        case .reminders: String(localized: "Reminders")
        case .todo: String(localized: "To-do")
        case .notes: String(localized: "Notes")
        case .done: String(localized: "tab.done", defaultValue: "Done")
        }
    }

    var heading: String {
        switch self {
        case .all: String(localized: "Everything")
        case .today: String(localized: "Today")
        case .money: String(localized: "Money")
        case .reminders: String(localized: "Reminders")
        case .todo: String(localized: "To-do")
        case .notes: String(localized: "Notes")
        case .done: String(localized: "tab.done", defaultValue: "Done")
        }
    }

    var sticker: StickerArt {
        switch self {
        case .all: StickerArt(symbol: "rectangle.stack", fill: Tok.Sticker.yellow)
        case .today: StickerArt(symbol: "sun.max", fill: Tok.Sticker.coral)
        case .money: StickerArt(symbol: "banknote", fill: Tok.Sticker.pink)
        case .reminders: StickyKind.reminder.sticker
        case .todo: StickyKind.todo.sticker
        case .notes: StickyKind.note.sticker
        case .done: StickerArt(symbol: "checkmark", fill: Tok.Sticker.lime)
        }
    }
}
