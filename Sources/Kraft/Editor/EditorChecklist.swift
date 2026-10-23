import AppKit
import KraftCore
import SwiftUI

/// To-do items written on the paper. Return adds the next item, Backspace on an empty item removes it,
/// the pen box ticks, and the grip that appears on hover drags an item to a new place.
struct EditorChecklist: View {
    let sticky: Sticky
    let edit: StickyEditing
    var focus: FocusState<EditorFocus?>.Binding

    @State private var dropTarget: ChecklistItem.ID?

    private var ink: Color { sticky.style.ink.color }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(sticky.checklist) { item in
                    EditorChecklistRow(
                        item: item, ink: ink, hand: hand(item.text), edit: edit, focus: focus,
                        submit: { insert(after: item.id) },
                        removeIfEmpty: { removeIfEmpty(item.id) }
                    )
                    .overlay(alignment: .top) {
                        if dropTarget == item.id {
                            Capsule().fill(ink.opacity(0.45)).frame(height: 2).offset(y: -1)
                        }
                    }
                    .dropDestination(for: String.self) { ids, _ in
                        guard let raw = ids.first, let id = UUID(uuidString: raw) else { return false }
                        withAnimation(.spring(duration: 0.3)) {
                            edit.change(String(localized: "Reorder Items")) { $0.checklist = StickyEdits.moveItem(id, to: item.id, in: $0.checklist) }
                        }
                        return true
                    } isTargeted: { targeted in
                        if targeted { dropTarget = item.id } else if dropTarget == item.id { dropTarget = nil }
                    }
                }
                addButton
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.never)
    }

    private func hand(_ text: String) -> Hand {
        Hand(text: text.isEmpty ? sticky.primaryText : text, style: sticky.style.handwriting)
    }

    private var addButton: some View {
        Button { insert(after: sticky.checklist.last?.id) } label: {
            HStack(spacing: 12) {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 21, height: 21)
                Text("Add an item").font(Hand(text: String(localized: "Add an item"), style: sticky.style.handwriting).font(19))
            }
            .padding(.leading, 22)
            .foregroundStyle(ink.opacity(0.38))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .environment(\.layoutDirection, hand("").layoutDirection)
        .padding(.top, 4)
    }

    private func insert(after id: ChecklistItem.ID?) {
        // Return on an empty last item does nothing, so a list never fills with blanks.
        if let id, let item = sticky.checklist.first(where: { $0.id == id }), item.text.isEmpty, item.id == sticky.checklist.last?.id {
            return
        }
        let (items, newID) = StickyEdits.insertItem(after: id, in: sticky.checklist)
        edit.change(StickyEditing.typing) { $0.checklist = items }
        Task { @MainActor in focus.wrappedValue = .item(newID) }
    }

    private func removeIfEmpty(_ id: ChecklistItem.ID) -> Bool {
        guard let item = sticky.checklist.first(where: { $0.id == id }), item.text.isEmpty else { return false }
        let (items, next) = StickyEdits.removeItem(id, from: sticky.checklist)
        edit.change(String(localized: "Delete Item")) { $0.checklist = items }
        focus.wrappedValue = next.map { .item($0) } ?? .title
        return true
    }
}

private struct EditorChecklistRow: View {
    let item: ChecklistItem
    let ink: Color
    let hand: Hand
    let edit: StickyEditing
    var focus: FocusState<EditorFocus?>.Binding
    let submit: () -> Void
    let removeIfEmpty: () -> Bool

    @State private var hovering = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(ink.opacity(hovering ? 0.4 : 0))
                .frame(width: 12, height: 28)
                .contentShape(Rectangle())
                .draggable(item.id.uuidString) {
                    Text(item.text.isEmpty ? " " : item.text)
                        .font(hand.font(19))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 6))
                }
                .pointerStyle(.grabIdle)
                .help(Text("Drag to reorder"))
            Button {
                NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
                withAnimation(.spring(duration: 0.35)) { edit.store.toggleChecklistItem(item.id, in: edit.id) }
            } label: {
                CheckDoodle(isDone: item.isDone, ink: ink).scaleEffect(1.3).frame(width: 21, height: 21).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(item.isDone ? "Mark as not done" : "Mark as done"))
            TextField("", text: text, prompt: Text(String(localized: "checklist.placeholder", defaultValue: "To-do")).foregroundStyle(ink.opacity(0.28)))
                .textFieldStyle(.plain)
                .font(hand.font(19))
                .strikethrough(item.isDone, color: ink.opacity(0.6))
                .opacity(item.isDone ? 0.5 : 1)
                .focused(focus, equals: .item(item.id))
                .onSubmit(submit)
                .onKeyPress(keys: [.delete, .deleteForward]) { _ in removeIfEmpty() ? .handled : .ignored }
                .editorWriting(hand.direction)
        }
        .environment(\.layoutDirection, hand.layoutDirection)
        .frame(minHeight: 30)
        .onHover { hovering = $0 }
    }

    private var text: Binding<String> {
        Binding(
            get: { edit.store.sticky(edit.id)?.checklist.first { $0.id == item.id }?.text ?? "" },
            set: { value in
                edit.change(StickyEditing.typing, coalesce: true) {
                    $0.checklist = $0.checklist.map { $0.id == item.id ? ChecklistItem(id: $0.id, text: value, isDone: $0.isDone) : $0 }
                }
            }
        )
    }
}
