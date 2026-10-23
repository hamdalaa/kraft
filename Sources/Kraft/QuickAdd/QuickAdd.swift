import KraftCore
import SwiftUI

/// The one way to add: "+" / ⌘N in the window (sheet), ⌥Space from any app (floating panel).
/// A sheet of notepad paper with one handwriting line; what it understood shows as glossy tags,
/// and the sticky it will make sits on a strip of kraft beside it.
struct QuickAddView: View {
    enum Presentation { case sheet, panel }

    let store: StickyStore
    var presentation: Presentation = .sheet
    /// Snapshot mode draws a SwiftUI replica of the text field (ImageRenderer cannot draw AppKit views).
    var isSnapshot = false
    let dismiss: () -> Void
    var onAdded: () -> Void = {}

    static let fieldSize: CGFloat = 23

    @State private var model: QuickAddModel
    @State private var appeared = !Motion.enabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(store: StickyStore, presentation: Presentation = .sheet, model: QuickAddModel = QuickAddModel(),
         isSnapshot: Bool = false, onAdded: @escaping () -> Void = {}, dismiss: @escaping () -> Void) {
        self.store = store
        self.presentation = presentation
        self.isSnapshot = isSnapshot
        self.onAdded = onAdded
        self.dismiss = dismiss
        _model = State(initialValue: model)
    }

    var body: some View {
        let parsed = model.parse()
        card(parsed)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared || reduceMotion ? 0 : 10)
            .scaleEffect(appeared || reduceMotion ? 1 : 0.985, anchor: .top)
            .onAppear {
                guard !appeared else { return }
                withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .spring(duration: 0.42, bounce: 0.14)) { appeared = true }
            }
            .onExitCommand(perform: dismiss)
    }

    private func card(_ parsed: ParsedSticky) -> some View {
        HStack(spacing: 0) {
            writingSide(parsed)
                .padding(.leading, 22)
                .padding(.trailing, 26)
                .padding(.vertical, 22)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            PreviewStrip(sticky: model.sticky(for: parsed), isBlank: model.isBlank)
                .frame(width: 250)
        }
        .frame(width: 790)
        .frame(minHeight: 262)
        .fixedSize(horizontal: false, vertical: true)
        .background(NotepadPaper(marginX: 22 + 74))
        .clipShape(RoundedRectangle(cornerRadius: presentation == .panel ? 16 : 0, style: .continuous))
        .overlay {
            if presentation == .panel {
                RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.black.opacity(0.10), lineWidth: 0.5)
            }
        }
    }

    private func writingSide(_ parsed: ParsedSticky) -> some View {
        HStack(alignment: .top, spacing: 0) {
            KindStickerButton(kind: parsed.kind, model: model)
                .frame(width: 74, alignment: .center)
                .padding(.top, 34)
            VStack(alignment: .leading, spacing: 0) {
                header
                field(parsed)
                    .padding(.top, 10)
                Rectangle().fill(Tok.Grid.line).frame(height: 1).padding(.top, 2)
                understood(parsed)
                    .padding(.top, 14)
                Spacer(minLength: 18)
                footer
            }
            .padding(.leading, 16)
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("New Sticky")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Tok.Kraft.ink)
            Spacer()
            if presentation == .panel {
                Text(verbatim: "⌥Space").font(.system(size: 11, weight: .medium)).foregroundStyle(Tok.Kraft.ink.opacity(0.5))
            }
        }
    }

    @ViewBuilder private func field(_ parsed: ParsedSticky) -> some View {
        let marks = parsed.spans.map { FieldMark(range: $0.range, color: $0.field.markColor(kind: parsed.kind)) }
        ZStack(alignment: .topLeading) {
            if model.isBlank {
                let placeholder = String(localized: "Say it like you'd say it…")
                Text(placeholder)
                    .font(Hand(text: placeholder).font(QuickAddView.fieldSize))
                    .foregroundStyle(Tok.Kraft.ink.opacity(0.34))
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            if isSnapshot {
                HandwritingReplica(text: model.text, marks: marks, size: QuickAddView.fieldSize)
            } else {
                HandwritingField(text: $model.text, marks: marks, size: QuickAddView.fieldSize, onSubmit: add, onCancel: dismiss)
            }
        }
        .frame(minHeight: 40)
    }

    @ViewBuilder private func understood(_ parsed: ParsedSticky) -> some View {
        if model.isBlank {
            ExampleLines { model.text = $0 }
        } else {
            UnderstoodTagRow(parsed: parsed, model: model)
        }
    }

    private var footer: some View {
        HStack(spacing: 14) {
            KeyHint(key: "return", text: String(localized: "Add"))
            KeyHint(key: "option", text: String(localized: "New line"), extra: "return")
            KeyHint(key: "escape", text: String(localized: "Close"))
            Spacer()
            Button(action: add) {
                EmbossedLabel(text: String(localized: "Add Sticky"), symbol: "plus", tint: .blue, size: .regular)
            }
            .buttonStyle(GlossyButtonStyle(tint: .blue))
            .fixedSize()
            .disabled(model.isBlank)
            .opacity(model.isBlank ? 0.55 : 1)
        }
    }

    private func add() {
        guard model.commit(to: store) else { return }
        onAdded()
        dismiss()
    }
}

/// Example sentences under an empty field; clicking one writes it in.
private struct ExampleLines: View {
    let use: (String) -> Void
    private let examples = ["Ali owes me $40 friday", "ذكرني بالدواء الساعة ٩ كل يوم", "buy milk, bread, eggs"]

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Try")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Tok.Kraft.ink.opacity(0.55))
            FlowLayout(spacing: 14, lineSpacing: 6) {
                ForEach(examples, id: \.self) { example in
                    Button { use(example) } label: {
                        Text(example)
                            .font(Hand(text: example).font(15))
                            .foregroundStyle(InkColor.blue.color.opacity(0.7))
                            .underline(pattern: .dot, color: InkColor.blue.color.opacity(0.35))
                            .environment(\.layoutDirection, Hand(text: example).layoutDirection)
                    }
                    .buttonStyle(.plain)
                    .help(Text("Use this example"))
                }
            }
        }
    }
}

private struct KeyHint: View {
    let key: String
    let text: String
    var extra: String?

    var body: some View {
        HStack(spacing: 4) {
            HStack(spacing: 1) {
                Image(systemName: key)
                if let extra { Image(systemName: extra) }
            }
            .font(.system(size: 9, weight: .bold))
            .padding(.horizontal, 4)
            .frame(height: 16)
            .background(RoundedRectangle(cornerRadius: 4, style: .continuous).fill(.white.opacity(0.7)))
            .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous).strokeBorder(Tok.Grid.line, lineWidth: 0.8))
            Text(text).font(.system(size: 11, weight: .medium))
        }
        .foregroundStyle(Tok.Kraft.ink.opacity(0.62))
        .fixedSize()
    }
}
