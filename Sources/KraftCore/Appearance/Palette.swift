/// Every colour in Kraft, light and "night desk" dark (DESIGN.md). Views never read this directly:
/// `Tok` in the app wraps each swatch as an adaptive SwiftUI colour. It lives here so contrast is tested.
public enum Palette {
    public enum Page {
        public static let base = Swatch(0xFDF6E6, dark: 0x1A140F)
        public static let hi = Swatch(0xFFF9E9, dark: 0x231B15)
    }

    public enum Kraft {
        public static let base = Swatch(0xCD9059, dark: 0x4C311B)
        public static let light = Swatch(0xD59862, dark: 0x55371F)
        public static let deep = Swatch(0xB87541, dark: 0x2E1C0E)
        /// Text and marks on kraft and on page stock: debossed brown by day, warm cream by lamplight.
        public static let ink = Swatch(0x744416, dark: 0xFCEBD0)
        public static let tabTop = Swatch(0xC99059, dark: 0x452D19)
        public static let tabBottom = Swatch(0xB07440, dark: 0x332010)
        /// Lamp pool falling on the board from the top-leading corner.
        public static let lamp = Swatch(0xFFEBC8, dark: 0xFFAE5C, alpha: 0.22, darkAlpha: 0.13)
        /// Vignette at the board's edges.
        public static let vignette = Swatch(0x744416, dark: 0x0E0805, alpha: 0.16, darkAlpha: 0.72)
    }

    public enum Grid {
        public static let paper = Swatch(0xF3EBDD, dark: 0x3B322A)
        public static let line = Swatch(0xD2C9B8, dark: 0x564A3E)
    }

    /// Die-cut sticker parts (ref-6 / ref-7). Fills and ink are the same at night; the border warms a little.
    public enum Sticker {
        public static let ink = Swatch.fixed(0x271F2C)
        public static let border = Swatch(0xFFFFFF, dark: 0xF6ECDD)
        /// UI text that used sticker ink on light popovers.
        public static let label = Swatch(0x271F2C, dark: 0xEFE2CF)
        public static let sky = Swatch.fixed(0x68C9F6)
        public static let coral = Swatch.fixed(0xFBA08E)
        public static let yellow = Swatch.fixed(0xFFD96A)
        public static let pink = Swatch.fixed(0xFE93B1)
        public static let purple = Swatch.fixed(0xC3A7E1)
        public static let green = Swatch.fixed(0x94E387)
        public static let lime = Swatch.fixed(0xAEFF5D)
    }

    public enum Stamp {
        public static let red = Swatch.fixed(0xE0313F)
        public static let pin = Swatch.fixed(0xFD2441)
    }

    /// Light on top edges, and the 1 pt lip under embossed text.
    public enum Light {
        /// Embossed text: a white lip below by day, a dark letterpress lip at night.
        public static let emboss = Swatch(0xFFFFFF, dark: 0x0B0705, darkAlpha: 0.6)
        /// Top-edge highlights and sheens on cards, tabs and glass.
        public static let edge = Swatch(0xFFFFFF, dark: 0xFFE6C2, darkAlpha: 0.34)
        /// A faint lift for ghost controls on page stock.
        public static let lift = Swatch(0xFFFFFF, dark: 0xFFE6C2, darkAlpha: 0.22)
    }

    public enum Shadow {
        public static let board = Swatch(0x744416, dark: 0x050302, alpha: 0.16, darkAlpha: 0.55)
        public static let card = Swatch(0x744416, dark: 0x050302, alpha: 0.28, darkAlpha: 0.6)
    }

    /// Cards of page stock (editor side card, settings) and the slips that hold native fields.
    public enum Card {
        /// Card stock: the page by day; a step lighter than the page at night, so cards rise instead of sinking.
        public static let top = Swatch(0xFFF9E9, dark: 0x30251D)
        public static let bottom = Swatch(0xFDF6E6, dark: 0x271E17)
        /// Hairline around floating cards (the ⌥Space panel).
        public static let rim = Swatch(0x000000, dark: 0xFFE6C2, alpha: 0.10, darkAlpha: 0.14)
        public static let edge = Swatch(0xE6D7BC, dark: 0x45372C)
        public static let slip = Swatch(0xFFFFFF, dark: 0x140F0B, alpha: 0.92, darkAlpha: 0.55)
        public static let slipEdge = Swatch(0xE2D5BE, dark: 0x4D3E32)
        /// Typed text in slips; also the handwriting typed on the quick-add notepad.
        public static let text = Swatch(0x2E2A33, dark: 0xF2E3CC)
        /// Example sentences on the notepad.
        public static let example = Swatch(0x1F4FA8, dark: 0x9FC0F7)
    }

    /// Washi tape with no tint, and the border of a white paper slip.
    public enum Tape {
        public static let plain = Swatch(0xFFFFFF, dark: 0xEFE2CC)
        public static let slipEdge = Swatch(0xE6D7BC, dark: RGB(hex: 0xE6D7BC).lamplit.hex)
    }

    public enum Paper {
        public static let lemon = Swatch.paper(0xFFF1A8)
        public static let mint = Swatch.paper(0xDDF6D2)
        public static let sky = Swatch.paper(0xD8EEFC)
        public static let pink = Swatch.paper(0xFFDDE8)
        public static let peach = Swatch.paper(0xFFE2CF)
        public static let lilac = Swatch.paper(0xE9E0FA)
        public static let white = Swatch.paper(0xFFFDF6)

        public static let all = [lemon, mint, sky, pink, peach, lilac, white]
    }

    /// Glossy tag tints (ref-5). Night: deeper tinted glass, brighter ink of the same hue.
    public struct Tint: Sendable {
        public let top: Swatch
        public let bottom: Swatch
        public let edge: Swatch
        public let ink: Swatch

        public static let blue = Tint(top: Swatch(0xDCEFFE, dark: 0x27456A), bottom: Swatch(0xCFE9FF, dark: 0x1D3654),
                                      edge: Swatch(0x93C3F3, dark: 0x4876A8), ink: Swatch(0x5390E0, dark: 0xA7D0FF))
        public static let lime = Tint(top: Swatch(0xEEFF8D, dark: 0x3C4914), bottom: Swatch(0xE4F86A, dark: 0x2F3A0D),
                                      edge: Swatch(0xC4D698, dark: 0x6A7E22), ink: Swatch(0x7A9D0F, dark: 0xD8F45E))
        public static let mint = Tint(top: Swatch(0xD7FCDD, dark: 0x1E4B37), bottom: Swatch(0xC6F5CE, dark: 0x163C2C),
                                      edge: Swatch(0xA3E3AF, dark: 0x3D8463), ink: Swatch(0x27A274, dark: 0x93EDBE))
        public static let pink = Tint(top: Swatch(0xFFE3EE, dark: 0x5A2540), bottom: Swatch(0xFFD3E3, dark: 0x481C33),
                                      edge: Swatch(0xF2A7C3, dark: 0x974468), ink: Swatch(0xD4497F, dark: 0xFFADCD))
        public static let amber = Tint(top: Swatch(0xFFF2CC, dark: 0x5A421B), bottom: Swatch(0xFFE7A6, dark: 0x4A3513),
                                       edge: Swatch(0xE8C774, dark: 0x9A7430), ink: Swatch(0xB07C12, dark: 0xFFD47E))
        /// Neutral tag for unselected choices.
        public static let paper = Tint(top: Swatch(0xFFFDF8, dark: 0x3A2E25), bottom: Swatch(0xF5EEDF, dark: 0x30261E),
                                       edge: Swatch(0xDCCDB3, dark: 0x5A493B), ink: Swatch(0x86704F, dark: 0xDCC6A6))

        public static let all: [Tint] = [blue, lime, mint, pink, amber, paper]
    }
}
