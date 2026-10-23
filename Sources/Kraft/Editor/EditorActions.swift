import KraftCore
import SwiftUI

/// Done, Pin to Desktop, Duplicate, Delete — glossy tags under the paper. Every one is undoable (⌘Z).
struct EditorActions: View {
    let sticky: Sticky
    let edit: StickyEditing
    let model: BoardModel

    var body: some View {
        HStack(spacing: 10) {
            action(sticky.isDone ? "Not Done" : "Done", symbol: sticky.isDone ? "arrow.uturn.backward" : "checkmark", tint: .lime) {
                withAnimation(.spring(duration: 0.35)) { edit.store.setDone(!sticky.isDone, for: sticky.id) }
            }
            action(sticky.isOnDesktop ? "Unpin from Desktop" : "Pin to Desktop",
                   symbol: sticky.isOnDesktop ? "pin.slash" : "pin", tint: .amber) {
                edit.change(String(localized: sticky.isOnDesktop ? "Unpin from Desktop" : "Pin to Desktop")) { $0.isOnDesktop.toggle() }
            }
            action("Duplicate", symbol: "plus.square.on.square", tint: .blue) {
                var copy = StickyEdits.duplicate(sticky)
                copy.style.tilt = sticky.style.tilt > 0 ? -1.5 : 1.5
                edit.store.add(copy)
                model.closeEditor()
            }
            action("Delete", symbol: "trash", tint: .pink) {
                model.closeEditor()
                edit.store.delete(sticky.id)
            }
        }
    }

    private func action(_ title: LocalizedStringResource, symbol: String, tint: TagTint, perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            EmbossedLabel(text: String(localized: title), symbol: symbol, tint: tint, size: .regular)
                .contentTransition(.opacity)
        }
        .buttonStyle(GlossyButtonStyle(tint: tint))
    }
}
