import KraftCore
import SwiftUI

/// Shown over the board when a sticky is clicked: the note zooms up into an editor, the board dims behind it.
///
/// Contract: read `model.editingID`, write through `model.store`, close with `model.closeEditor()`.
/// The board card and the editor paper share `namespace` (`matchedGeometryEffect`), so the paper grows out of
/// the card and shrinks back into it.
struct StickyEditorHost: View {
    @Bindable var model: BoardModel
    let namespace: Namespace.ID

    var body: some View {
        ZStack {
            if let id = model.editingID, let sticky = model.store.sticky(id), sticky.deletedAt == nil {
                Color.black.opacity(0.34)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { model.closeEditor() }
                    .accessibilityLabel(Text("Close editor"))
                    .transition(.opacity)
                StickyEditor(model: model, sticky: sticky, namespace: namespace)
            }
        }
    }
}

struct StickyEditor: View {
    let model: BoardModel
    let sticky: Sticky
    let namespace: Namespace.ID

    @FocusState private var focus: EditorFocus?

    private var edit: StickyEditing { StickyEditing(store: model.store, id: sticky.id) }

    var body: some View {
        let geometry = EditorGeometry(size: sticky.style.size)
        HStack(alignment: .center, spacing: 30) {
            VStack(spacing: 4) {
                EditorZoomBox(side: geometry.box) {
                    EditorPaper(sticky: sticky, edit: edit, side: geometry.paper, focus: $focus)
                        .padding(geometry.inset)
                }
                .matchedGeometryEffect(id: sticky.id, in: namespace)
                .frame(width: geometry.box, height: geometry.box)
                .transition(.modifier(active: EditorTilt(degrees: sticky.style.tilt), identity: EditorTilt(degrees: 0))
                    .combined(with: .opacity))
                EditorActions(sticky: sticky, edit: edit, model: model)
                    .transition(.opacity)
            }
            EditorPanel(sticky: sticky, edit: edit, close: model.closeEditor)
                .transition(.opacity.combined(with: .scale(scale: 0.97)))
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { EditorShortcuts(close: model.closeEditor) }
        .onExitCommand { model.closeEditor() }
        .onAppear {
            if sticky.title.isEmpty, sticky.kind != .todo || !sticky.checklist.isEmpty { focus = .title }
        }
    }
}

/// What can hold the keyboard inside the editor.
enum EditorFocus: Hashable {
    case title, body, item(ChecklistItem.ID)
}

/// Board card → editor proportions. The board's matched frame is the card plus a 14 pt hover inset on each
/// side; the editor keeps the same proportions so the zoom is a pure scale.
struct EditorGeometry {
    let paper: CGFloat
    let scale: CGFloat

    init(size: StickySize) {
        paper = switch size {
        case .small: 440
        case .medium: 460
        case .large: 480
        }
        scale = paper / CGFloat(size.side)
    }

    static let boardInset: CGFloat = 14
    var inset: CGFloat { Self.boardInset * scale }
    var box: CGFloat { paper + inset * 2 }
}

/// Lays the paper out at its editing size and scales it to whatever frame the matched geometry proposes,
/// so mid-zoom the paper is a scaled copy rather than a reflowing one.
private struct EditorZoomBox<Content: View>: View {
    let side: CGFloat
    @ViewBuilder var content: Content

    var body: some View {
        GeometryReader { geo in
            content
                .frame(width: side, height: side)
                .scaleEffect(max(0.01, min(geo.size.width, geo.size.height) / side))
                .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}

/// The paper keeps the card's tilt while it flies and straightens out for writing.
private struct EditorTilt: ViewModifier {
    let degrees: Double
    func body(content: Content) -> some View { content.rotationEffect(.degrees(degrees)) }
}

/// ⌘W and Esc close the editor, even while a field has the keyboard.
private struct EditorShortcuts: View {
    let close: () -> Void

    var body: some View {
        ZStack {
            Button("Close", action: close).keyboardShortcut("w", modifiers: .command)
            Button("Close", action: close).keyboardShortcut(.cancelAction)
        }
        .opacity(0)
        .frame(width: 0, height: 0)
        .accessibilityHidden(true)
    }
}
