import KraftCore
import SwiftUI

extension Snapshot {
    /// Offscreen renders for this area: (file name without extension, view). Owned by the Desktop session.
    static func desktopShots() -> [(String, AnyView)] {
        [
            ("desktop", AnyView(MockDesktop(direction: .leftToRight))),
            ("desktop-rtl", AnyView(MockDesktop(direction: .rightToLeft))),
        ]
    }
}

/// A 1440×900 display with four stickies placed one after another by `DesktopLayout`, exactly as
/// pinning them from the board would.
private struct MockDesktop: View {
    let direction: ScriptDirection

    private static let screen = CGSize(width: 1440, height: 900)
    private static let menuBar: CGFloat = 25
    /// Visible frame in AppKit coordinates (y up): everything below the menu bar.
    private var visible: CGRect { CGRect(x: 0, y: 0, width: Self.screen.width, height: Self.screen.height - Self.menuBar) }

    private var placed: [(Sticky, CGRect)] {
        let samples = SampleData.stickies()
        let picks = [samples[2], samples[1], samples[0], samples[4]] // to-do, Arabic reminder, money, large note
        let layout = DesktopLayout(direction: direction)
        var rects: [CGRect] = []
        return picks.map { sticky in
            let side = sticky.style.size.side
            let rect = layout.place(CGSize(width: side, height: side), in: visible, avoiding: rects)
            rects.append(rect)
            return (sticky, rect)
        }
    }

    @Environment(\.layoutDirection) private var uiDirection

    var body: some View {
        ZStack(alignment: .topLeading) {
            Wallpaper()
            MenuBarStrip().environment(\.layoutDirection, uiDirection)
            ForEach(placed, id: \.0.id) { sticky, rect in
                StickyCard(sticky: sticky)
                    .opacity(sticky.isFinished ? 0.62 : 1)
                    .environment(\.layoutDirection, uiDirection)
                    // AppKit's y-up rect → SwiftUI's y-down position.
                    .position(x: rect.midX, y: Self.screen.height - rect.midY)
            }
        }
        // Screen coordinates are physical: never mirrored.
        .environment(\.layoutDirection, .leftToRight)
        .frame(width: Self.screen.width, height: Self.screen.height)
        .clipped()
    }
}

/// A calm, macOS-like wallpaper so the paper and its shadow read the way they will on a real desktop.
private struct Wallpaper: View {
    var body: some View {
        MeshGradient(width: 3, height: 3, points: [
            [0, 0], [0.5, 0], [1, 0],
            [0, 0.5], [0.62, 0.42], [1, 0.5],
            [0, 1], [0.5, 1], [1, 1],
        ], colors: [
            Color(hex: 0x2B4C7E), Color(hex: 0x3F6EA8), Color(hex: 0x86A9CF),
            Color(hex: 0x24406B), Color(hex: 0x5B87B8), Color(hex: 0xC9B79C),
            Color(hex: 0x1A2F52), Color(hex: 0x3A5B86), Color(hex: 0xD9A57A),
        ])
    }
}

private struct MenuBarStrip: View {
    @Environment(\.kraftFormat) private var format

    var body: some View {
        HStack(spacing: 18) {
            Image(systemName: "apple.logo").font(.system(size: 14, weight: .semibold))
            Text(verbatim: "Finder").font(.system(size: 13, weight: .bold))
            ForEach(Self.menus, id: \.self) {
                Text($0).font(.system(size: 13))
            }
            Spacer()
            Text(verbatim: format.weekday(Self.clock) + "  " + format.time(Self.clock)).font(.system(size: 13, weight: .medium))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 18)
        .frame(height: 25)
        .background(.black.opacity(0.12))
    }

    private static let menus: [String] = [
        String(localized: "File"), String(localized: "Edit"), String(localized: "View"),
        String(localized: "Go"), String(localized: "Window"), String(localized: "Help"),
    ]
    private static var clock: Date { Calendar.current.date(bySettingHour: 9, minute: 41, second: 0, of: Date()) ?? Date() }
}
