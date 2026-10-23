import KraftCore
import Observation
import SwiftUI

/// Per-panel UI state the paper reacts to.
@MainActor
@Observable
final class DesktopPanelState {
    var isDragging = false
}

/// The paper inside a desktop panel: the same `StickyCard` as the board, reading the same record
/// from the store, so edits anywhere show here live and ticks here show everywhere.
struct DesktopStickyView: View {
    let store: StickyStore
    let id: Sticky.ID
    let state: DesktopPanelState

    @State private var hovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if let sticky = store.sticky(id) {
            StickyCard(sticky: sticky, lifted: state.isDragging || hovering) { item in
                store.toggleChecklistItem(item, in: id)
            }
            // Finished stickies stay pinned but step back, like a ticked-off list.
            .opacity(sticky.isFinished ? 0.62 : 1)
            .onHover { hovering = $0 }
            .animation(reduceMotion ? nil : .spring(duration: 0.35), value: state.isDragging || hovering)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
