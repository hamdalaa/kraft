import AppKit
import KraftCore
import SwiftUI

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

extension NSColor {
    /// A token that resolves per appearance: light values by day, the "night desk" values in Dark.
    static func swatch(_ s: Swatch) -> NSColor {
        NSColor(name: nil) { appearance in
            let dark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            let c = s.rgb(dark: dark)
            return NSColor(srgbRed: c.red, green: c.green, blue: c.blue, alpha: s.alpha(dark: dark))
        }
    }
}

extension Color {
    /// Adaptive token colour (see `Palette`). SwiftUI resolves it from the view's `colorScheme`.
    init(_ swatch: Swatch) { self.init(nsColor: .swatch(swatch)) }
}

/// Design tokens. Values come from DESIGN.md (sampled from the references); each one adapts to Light / Dark.
/// The numbers live in `KraftCore.Palette` so their contrast is tested.
enum Tok {
    enum Page {
        static let base = Color(Palette.Page.base)
        static let hi = Color(Palette.Page.hi)
    }

    enum Kraft {
        static let base = Color(Palette.Kraft.base)
        static let light = Color(Palette.Kraft.light)
        static let deep = Color(Palette.Kraft.deep)
        static let ink = Color(Palette.Kraft.ink)
        static let tabTop = Color(Palette.Kraft.tabTop)
        static let tabBottom = Color(Palette.Kraft.tabBottom)
        static let lamp = Color(Palette.Kraft.lamp)
        static let vignette = Color(Palette.Kraft.vignette)
    }

    enum Grid {
        static let paper = Color(Palette.Grid.paper)
        static let line = Color(Palette.Grid.line)
    }

    /// Sticker ink and fills (ref-6 / ref-7).
    enum Sticker {
        static let ink = Color(Palette.Sticker.ink)
        static let border = Color(Palette.Sticker.border)
        static let label = Color(Palette.Sticker.label)
        static let sky = Color(Palette.Sticker.sky)
        static let coral = Color(Palette.Sticker.coral)
        static let yellow = Color(Palette.Sticker.yellow)
        static let pink = Color(Palette.Sticker.pink)
        static let purple = Color(Palette.Sticker.purple)
        static let green = Color(Palette.Sticker.green)
        static let lime = Color(Palette.Sticker.lime)
    }

    enum Stamp {
        static let red = Color(Palette.Stamp.red)
        static let pin = Color(Palette.Stamp.pin)
    }

    /// Highlights: the lip under embossed text, top edges, the lift of ghost controls.
    enum Light {
        static let emboss = Color(Palette.Light.emboss)
        static let edge = Color(Palette.Light.edge)
        static let lift = Color(Palette.Light.lift)
    }

    enum Shadow {
        static let board = Color(Palette.Shadow.board)
        static let card = Color(Palette.Shadow.card)
    }

    enum Card {
        static let top = Color(Palette.Card.top)
        static let bottom = Color(Palette.Card.bottom)
        static let rim = Color(Palette.Card.rim)
        static let edge = Color(Palette.Card.edge)
        static let slip = Color(Palette.Card.slip)
        static let slipEdge = Color(Palette.Card.slipEdge)
        static let text = Color(Palette.Card.text)
        static let example = Color(Palette.Card.example)
    }

    enum Tape {
        static let plain = Color(Palette.Tape.plain)
        static let slipEdge = Color(Palette.Tape.slipEdge)
    }

    enum Space {
        static let page: CGFloat = 20
        static let board: CGFloat = 28
    }
}

extension PaperColor {
    var swatch: Swatch {
        switch self {
        case .lemon, .custom: Palette.Paper.lemon
        case .mint: Palette.Paper.mint
        case .sky: Palette.Paper.sky
        case .pink: Palette.Paper.pink
        case .peach: Palette.Paper.peach
        case .lilac: Palette.Paper.lilac
        case .white: Palette.Paper.white
        }
    }

    /// The paper colour; lamplit at night. Custom colours dim the same way.
    func color(customHex: String?) -> Color {
        if self == .custom, let rgb = customHex.flatMap(RGB.init(hexString:)) { return Color(.paper(rgb.hex)) }
        return Color(swatch)
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
