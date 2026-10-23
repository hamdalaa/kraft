import KraftCore
import Testing

@Suite("Appearance")
struct AppearanceTests {
    @Test("Stored appearance values round-trip; unknown ones fall back to System")
    func storedValue() {
        for choice in AppAppearance.allCases {
            #expect(AppAppearance(storedValue: choice.rawValue) == choice)
        }
        #expect(AppAppearance(storedValue: nil) == .system)
        #expect(AppAppearance(storedValue: "sepia") == .system)
    }

    @Test("Hex parsing and contrast follow WCAG")
    func colourMaths() {
        #expect(RGB(hex: 0xCD9059).hex == 0xCD9059)
        #expect(RGB(hexString: "#FFF1A8")?.hex == 0xFFF1A8)
        #expect(RGB(hexString: "nope") == nil)
        let white = RGB(hex: 0xFFFFFF), black = RGB(hex: 0x000000)
        #expect(abs(white.contrast(with: black) - 21) < 0.001)
        #expect(white.contrast(with: white) == 1)
        #expect(RGB(hex: 0x000000).over(white, alpha: 0.5).hex == 0x808080)
    }

    @Test("Light mode keeps the approved DESIGN.md values")
    func lightUnchanged() {
        #expect(Palette.Page.base.light == 0xFDF6E6)
        #expect(Palette.Kraft.base.light == 0xCD9059)
        #expect(Palette.Kraft.ink.light == 0x744416)
        #expect(Palette.Tint.blue.ink.light == 0x5390E0)
        #expect(Palette.Paper.lemon.light == 0xFFF1A8)
        #expect(Palette.Sticker.border.light == 0xFFFFFF)
        #expect(Palette.Kraft.lamp.lightAlpha == 0.22)
    }

    @Test("Lamplit paper is a little dimmer but keeps its hue")
    func lamplitPaper() {
        let papers: [UInt32] = [0xFFF1A8, 0xDDF6D2, 0xD8EEFC, 0xFFDDE8, 0xFFE2CF, 0xE9E0FA, 0xFFFDF6]
        for hex in papers {
            let day = RGB(hex: hex), night = day.lamplit
            #expect(night.luminance < day.luminance)
            #expect(night.luminance > day.luminance * 0.7, "still a pale paper: \(String(hex, radix: 16))")
            // The strongest channel stays the strongest: sky stays blue, lemon stays yellow.
            let dayOrder = [day.red, day.green, day.blue].enumerated().max { $0.element < $1.element }?.offset
            let nightOrder = [night.red, night.green, night.blue].enumerated().max { $0.element < $1.element }?.offset
            #expect(dayOrder == nightOrder)
        }
        #expect(Swatch.paper(0xD8EEFC).dark == RGB(hex: 0xD8EEFC).lamplit.hex)
    }

    @Test("Ink on paper stays dark and readable at night")
    func inkOnPaper() {
        // Graphite (the default) and blue keep 4.5:1; red and green are 16 pt+ handwriting, so the large-text 3:1 applies.
        for paper in Palette.Paper.all {
            let night = paper.rgb(dark: true)
            #expect(RGB(hex: 0x2E2A33).contrast(with: night) >= 7)
            #expect(RGB(hex: 0x1F4FA8).contrast(with: night) >= 4.5)
            for ink: UInt32 in [0xB3261E, 0x1E6B47] {
                #expect(RGB(hex: ink).contrast(with: night) >= 4)
            }
        }
    }

    /// UI text in dark appearance, at the faintest opacity each surface uses for real text.
    @Test("Dark UI text reaches 4.5:1 on every surface")
    func darkTextContrast() {
        let ink = Palette.Kraft.ink.rgb(dark: true)
        let surfaces: [(String, RGB)] = [
            ("page", Palette.Page.base.rgb(dark: true)),
            ("page.hi", Palette.Page.hi.rgb(dark: true)),
            ("page card", Palette.Card.top.rgb(dark: true)),
            ("kraft", Palette.Kraft.base.rgb(dark: true)),
            ("kraft.light", Palette.Kraft.light.rgb(dark: true)),
            ("kraft under the lamp", Palette.Kraft.lamp.rgb(dark: true).over(Palette.Kraft.light.rgb(dark: true), alpha: Palette.Kraft.lamp.darkAlpha)),
            ("inactive tab", Palette.Kraft.tabTop.rgb(dark: true)),
        ]
        for (name, surface) in surfaces {
            // Labels and hints go down to 55 % ink on page stock; on kraft the faintest text is 72 %.
            let faintest = name.hasPrefix("page") ? 0.55 : 0.72
            let text = ink.over(surface, alpha: faintest)
            #expect(text.contrast(with: surface) >= 4.5, "\(name): \(text.contrast(with: surface))")
        }
        let slip = Palette.Card.slip.rgb(dark: true).over(Palette.Page.base.rgb(dark: true), alpha: Palette.Card.slip.darkAlpha)
        #expect(Palette.Card.text.rgb(dark: true).contrast(with: slip) >= 4.5)
        #expect(Palette.Card.example.rgb(dark: true).over(Palette.Page.base.rgb(dark: true), alpha: 0.7)
            .contrast(with: Palette.Page.base.rgb(dark: true)) >= 4.5)
        #expect(Palette.Sticker.label.rgb(dark: true).contrast(with: RGB(hex: 0x2A2420)) >= 4.5)
    }

    @Test("Dark glossy tags: bright ink on deep glass, edge lighter than the fill")
    func darkTags() {
        for tint in Palette.Tint.all {
            let ink = tint.ink.rgb(dark: true)
            #expect(ink.contrast(with: tint.top.rgb(dark: true)) >= 4.5)
            #expect(ink.contrast(with: tint.bottom.rgb(dark: true)) >= 4.5)
            #expect(tint.edge.rgb(dark: true).luminance > tint.top.rgb(dark: true).luminance, "bevel edge stays visible")
            #expect(tint.top.rgb(dark: true).luminance < 0.1, "deep glass, not pastel")
        }
    }

    @Test("Night page is warm brown-black: not black, not grey, not blue")
    func nightPage() {
        for swatch in [Palette.Page.base, Palette.Page.hi, Palette.Kraft.base] {
            let c = swatch.rgb(dark: true)
            #expect(c.hex != 0x000000)
            #expect(c.red > c.green && c.green > c.blue, "warm: \(String(swatch.dark, radix: 16))")
        }
        #expect(Palette.Page.base.rgb(dark: true).luminance < 0.02)
        #expect(Palette.Kraft.base.rgb(dark: true).contrast(with: Palette.Page.base.rgb(dark: true)) > 1.4, "board reads against the page")
    }
}
