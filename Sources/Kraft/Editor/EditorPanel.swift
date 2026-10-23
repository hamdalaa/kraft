import KraftCore
import SwiftUI

/// The card beside the paper (trailing side; mirrors in right-to-left): kind, the details for that kind, and the look.
struct EditorPanel: View {
    let sticky: Sticky
    let edit: StickyEditing
    let close: () -> Void

    static let width: CGFloat = 320

    var body: some View {
        // Short windows scroll the card; otherwise it sits still.
        ViewThatFits(in: .vertical) {
            content
            ScrollView { content }.scrollIndicators(.never)
        }
        .frame(width: Self.width)
        .background(EditorCardBackground())
        .overlay(alignment: .top) {
            WashiTape(tint: sticky.kind.sticker.fill).scaleEffect(0.8).rotationEffect(.degrees(-3)).offset(y: -10)
                .allowsHitTesting(false)
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                EditorLabel("Kind")
                Spacer()
                Button(action: close) {
                    Image(systemName: "xmark").font(.system(size: 9, weight: .heavy)).foregroundStyle(TagTint.paper.ink)
                        .frame(width: 22, height: 22)
                        .background(GlossyTagBackground(tint: .paper, height: 22).clipShape(Circle()))
                }
                .buttonStyle(.plain)
                .help(Text("Close (Esc)"))
                .accessibilityLabel(Text("Close"))
            }
            .padding(.bottom, -6)
            EditorKindPicker(kind: sticky.kind) { kind in
                withAnimation(.spring(duration: 0.35)) {
                    edit.change(String(localized: "Change Kind")) { $0 = StickyEdits.switchKind($0, to: kind) }
                }
            }
            EditorPerforation()
            details
            EditorPerforation()
            EditorQuickLook(sticky: sticky, edit: edit)
        }
        .padding(.horizontal, 20)
        .padding(.top, 22)
        .padding(.bottom, 18)
    }

    @ViewBuilder private var details: some View {
        switch sticky.kind {
        case .note:
            EditorHint(symbol: "pencil.and.scribble", text: "Write straight on the paper. The handwriting follows the language you type.")
        case .todo:
            EditorTodoSummary(sticky: sticky, edit: edit)
        case .reminder:
            EditorReminderFields(sticky: sticky, edit: edit)
        case .owedToMe, .iOwe:
            EditorMoneyFields(sticky: sticky, edit: edit)
        case .bill:
            EditorBillFields(sticky: sticky, edit: edit)
        }
    }
}

/// Pressed feel for buttons that draw their own glossy background.
struct EditorPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .brightness(configuration.isPressed ? -0.04 : 0)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(duration: 0.2), value: configuration.isPressed)
    }
}

/// Six glossy tags, each with its kind's die-cut sticker.
struct EditorKindPicker: View {
    let kind: StickyKind
    let select: (StickyKind) -> Void

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 7), count: 3), spacing: 9) {
            ForEach(StickyKind.allCases, id: \.self) { k in
                let on = k == kind
                Button { select(k) } label: {
                    HStack(spacing: 1) {
                        DieCutSticker(art: k.sticker, size: 10, tilt: .degrees(on ? -10 : -4))
                            .frame(width: 18, height: 18)
                        EmbossedLabel(text: String(localized: k.editorTitle), tint: on ? k.editorTint : .paper, size: .mini)
                            .fixedSize()
                    }
                    .padding(.horizontal, 4)
                    .frame(maxWidth: .infinity, minHeight: 30)
                    .background(GlossyTagBackground(tint: on ? k.editorTint : .paper, height: 30))
                    .contentShape(Rectangle())
                }
                .buttonStyle(EditorPressStyle())
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
    }
}

private struct EditorHint: View {
    let symbol: String
    let text: LocalizedStringKey

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol).font(.system(size: 15, weight: .semibold)).foregroundStyle(Tok.Kraft.ink.opacity(0.5))
            Text(text).font(.system(size: 12.5)).foregroundStyle(Tok.Kraft.ink.opacity(0.75)).fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct EditorTodoSummary: View {
    let sticky: Sticky
    let edit: StickyEditing

    @Environment(\.kraftFormat) private var format

    var body: some View {
        let done = sticky.checklist.filter(\.isDone).count
        let total = sticky.checklist.count
        VStack(alignment: .leading, spacing: 10) {
            EditorLabel("Progress")
            HStack(alignment: .firstTextBaseline) {
                Text("\(format.number(done)) of \(format.number(total)) done")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Tok.Kraft.ink.opacity(0.85))
                    .contentTransition(.numericText())
                Spacer()
                if done > 0 {
                    EditorChip("Clear ticked", symbol: "eraser", tint: .pink) {
                        withAnimation(.spring(duration: 0.35)) {
                            edit.change(String(localized: "Clear Ticked Items")) { $0.checklist = $0.checklist.filter { !$0.isDone } }
                        }
                    }
                }
            }
            PencilProgress(progress: total == 0 ? 0 : Double(done) / Double(total))
                .scaleEffect(x: 2.2, anchor: .leading)
                .foregroundStyle(Tok.Kraft.ink)
            EditorHint(symbol: "return", text: "Return adds an item. Backspace on an empty one removes it. Drag the grip to reorder.")
        }
    }
}

/// Paper swatches always at hand; the full look (handwriting, size, ink, ruling, fastener, tilt) in a popover.
private struct EditorQuickLook: View {
    let sticky: Sticky
    let edit: StickyEditing
    @State private var showsLook = false

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            EditorLabel("Paper")
            HStack(spacing: 0) {
                EditorSwatches(style: sticky.style, edit: edit, side: 19)
                Spacer(minLength: 8)
                Button { showsLook = true } label: {
                    EmbossedLabel(text: String(localized: "Look"), symbol: "paintpalette", tint: .blue, size: .mini)
                        .fixedSize()
                }
                .buttonStyle(GlossyButtonStyle(tint: .blue, size: .mini))
                .help(Text("Handwriting, size, ink, ruling, fastener and tilt"))
                .popover(isPresented: $showsLook, arrowEdge: .bottom) {
                    EditorLookPanel(sticky: sticky, edit: edit)
                }
            }
        }
    }
}
