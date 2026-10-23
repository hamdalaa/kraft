import KraftCore
import SwiftUI

/// Shown when a folder tab has no stickies: the tab's die-cut sticker and one handwritten line.
struct EmptyBoard: View {
    let tab: BoardTab
    let add: () -> Void

    var body: some View {
        VStack(spacing: 22) {
            DieCutSticker(art: tab.sticker, size: 54, tilt: .degrees(-9))
            Hand(text: message).text(message, 19)
                .foregroundStyle(InkColor.graphite.color.opacity(0.85))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .frame(maxWidth: 360)
                .padding(.horizontal, 22)
                .padding(.vertical, 14)
                .background { PaperSurface(color: PaperColor.white.color(customHex: nil), ruling: .lines) }
                .rotationEffect(.degrees(1.5))
            if tab != .done {
                Button(action: add) {
                    EmbossedLabel(text: String(localized: "New Sticky"), symbol: "plus", tint: .blue, size: .regular)
                }
                .buttonStyle(GlossyButtonStyle(tint: .blue))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 70)
    }

    private var message: String {
        switch tab {
        case .all: String(localized: "A clean board. Add anything with ⌘N, or ⌥Space from any app.")
        case .today: String(localized: "Nothing due today.")
        case .money: String(localized: "Nobody owes anybody. Nice.")
        case .reminders: String(localized: "No reminders.")
        case .todo: String(localized: "No lists yet.")
        case .notes: String(localized: "No notes yet.")
        case .done: String(localized: "Finished stickies land here.")
        }
    }
}
