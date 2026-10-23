import AppKit
import KraftCore
import SwiftUI

/// Writes one sticky through the store: copy, change, write back. No-op edits are dropped so undo stays clean.
@MainActor
struct StickyEditing {
    let store: StickyStore
    let id: Sticky.ID

    static let typing = String(localized: "Edit Sticky")

    func change(_ actionName: String, coalesce: Bool = false, _ body: (inout Sticky) -> Void) {
        guard let current = store.sticky(id) else { return }
        var copy = current
        body(&copy)
        guard copy != current else { return }
        store.update(copy, actionName: actionName, coalesce: coalesce)
    }

    /// Binding for typing into a text property; rapid keystrokes coalesce into one undo step.
    func text(_ keyPath: WritableKeyPath<Sticky, String>) -> Binding<String> {
        Binding(
            get: { store.sticky(id)?[keyPath: keyPath] ?? "" },
            set: { value in change(Self.typing, coalesce: true) { $0[keyPath: keyPath] = value } }
        )
    }
}

/// Neutral "paper" tag for unselected choices; selected choices take a kit tint.
extension TagTint {
    static let paper = TagTint(top: Color(hex: 0xFFFDF8), bottom: Color(hex: 0xF5EEDF), edge: Color(hex: 0xDCCDB3), ink: Color(hex: 0x86704F))
}

/// A glossy choice tag (ref-5): paper when off, tinted when on.
struct EditorChip: View {
    let title: LocalizedStringResource
    var symbol: String?
    var isOn = false
    var tint: TagTint = .blue
    var size: TagSize = .mini
    let action: () -> Void

    init(_ title: LocalizedStringResource, symbol: String? = nil, isOn: Bool = false, tint: TagTint = .blue,
         size: TagSize = .mini, action: @escaping () -> Void) {
        self.title = title
        self.symbol = symbol
        self.isOn = isOn
        self.tint = tint
        self.size = size
        self.action = action
    }

    var body: some View {
        let t = isOn ? tint : .paper
        Button(action: action) {
            EmbossedLabel(text: String(localized: title), symbol: symbol, tint: t, size: size)
        }
        .buttonStyle(GlossyButtonStyle(tint: t, size: size))
        .accessibilityAddTraits(isOn ? .isSelected : [])
        .animation(.spring(duration: 0.25), value: isOn)
    }
}

/// Small caps section label, debossed into the card like the board title.
struct EditorLabel: View {
    let title: LocalizedStringKey
    init(_ title: LocalizedStringKey) { self.title = title }

    var body: some View {
        Text(title)
            .font(.system(size: 10.5, weight: .semibold))
            .textCase(.uppercase)
            .tracking(0.8)
            .foregroundStyle(Tok.Kraft.ink.opacity(0.62))
            .shadow(color: .white.opacity(0.8), radius: 0, y: 1)
            .accessibilityAddTraits(.isHeader)
    }
}

/// A white paper slip that holds a native field, with an optional leading SF Symbol.
struct EditorSlip<Content: View>: View {
    var symbol: String?
    @ViewBuilder var content: Content

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)
        HStack(spacing: 7) {
            if let symbol {
                Image(systemName: symbol)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Tok.Kraft.ink.opacity(0.45))
                    .frame(width: 14)
            }
            content
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundStyle(Color(hex: 0x2E2A33))
        }
        .padding(.horizontal, 9)
        .frame(minHeight: 30)
        .background {
            shape.fill(Color.white.opacity(0.92))
                .overlay { shape.strokeBorder(Color(hex: 0xE2D5BE), lineWidth: 1) }
                .overlay {
                    // Pressed-in: a faint shade under the top edge.
                    shape.inset(by: 1).strokeBorder(LinearGradient(colors: [.black.opacity(0.07), .clear],
                                                                  startPoint: .top, endPoint: .center), lineWidth: 1.5)
                }
        }
    }
}

/// Perforated tear line between sections of the card.
struct EditorPerforation: View {
    var body: some View {
        Line()
            .stroke(Tok.Kraft.ink.opacity(0.18), style: StrokeStyle(lineWidth: 1, lineCap: .round, dash: [1, 4]))
            .frame(height: 1)
            .accessibilityHidden(true)
    }

    private struct Line: Shape {
        func path(in r: CGRect) -> Path {
            Path { p in p.move(to: CGPoint(x: r.minX, y: r.midY)); p.addLine(to: CGPoint(x: r.maxX, y: r.midY)) }
        }
    }
}

/// The side card the controls sit on: warm page stock, grain, a deckled top lip and a soft drop.
struct EditorCardBackground: View {
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        ZStack {
            shape.fill(LinearGradient(colors: [Tok.Page.hi, Tok.Page.base], startPoint: .top, endPoint: .bottom))
            GrainOverlay(image: Grain.paper, opacity: 0.3).blendMode(.multiply).clipShape(shape)
            shape.strokeBorder(Color(hex: 0xE6D7BC), lineWidth: 1)
            shape.inset(by: 1).strokeBorder(LinearGradient(colors: [.white.opacity(0.9), .clear], startPoint: .top, endPoint: .center), lineWidth: 1)
        }
        .compositingGroup()
        .shadow(color: .black.opacity(0.12), radius: 1, y: 1)
        .shadow(color: Tok.Kraft.ink.opacity(0.28), radius: 24, y: 14)
    }
}

/// Wrapping row of chips.
struct EditorFlow: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = rows(width: proposal.width ?? .infinity, subviews: subviews)
        let width = rows.map { $0.width }.max() ?? 0
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in rows(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y + (row.height - size.height) / 2), proposal: .unspecified)
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row { var indices: [Int] = []; var width: CGFloat = 0; var height: CGFloat = 0 }

    private func rows(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = [Row()]
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let extra = rows[rows.count - 1].indices.isEmpty ? size.width : size.width + spacing
            if rows[rows.count - 1].width + extra > width, !rows[rows.count - 1].indices.isEmpty {
                rows.append(Row())
            }
            let gap = rows[rows.count - 1].indices.isEmpty ? 0 : spacing
            rows[rows.count - 1].indices.append(index)
            rows[rows.count - 1].width += size.width + gap
            rows[rows.count - 1].height = max(rows[rows.count - 1].height, size.height)
        }
        return rows
    }
}

extension StickyKind {
    var editorTitle: LocalizedStringResource {
        switch self {
        case .note: "Note"
        case .todo: "To-do"
        case .reminder: "Reminder"
        case .owedToMe: "Owes me"
        case .iOwe: "I owe"
        case .bill: "Bill"
        }
    }

    var editorTint: TagTint {
        switch self {
        case .note: .blue
        case .todo: .pink
        case .reminder: .amber
        case .owedToMe: .mint
        case .iOwe: .pink
        case .bill: .lime
        }
    }
}

extension RepeatRule {
    var editorTitle: LocalizedStringResource {
        switch self {
        case .never: "Never"
        case .daily: "Daily"
        case .weekly: "Weekly"
        case .monthly: "Monthly"
        case .yearly: "Yearly"
        }
    }
}

extension View {
    /// Native text fields ignore SwiftUI's `layoutDirection`; they align against the app's direction.
    /// So reset the environment to the app's direction and align the field to its own text instead.
    func editorWriting(_ direction: ScriptDirection) -> some View {
        modifier(EditorWritingDirection(direction: direction))
    }
}

private struct EditorWritingDirection: ViewModifier {
    let direction: ScriptDirection

    func body(content: Content) -> some View {
        let appRTL = NSApplication.shared.userInterfaceLayoutDirection == .rightToLeft
        let app: ScriptDirection = appRTL ? .rightToLeft : .leftToRight
        content
            .multilineTextAlignment(direction == app ? .leading : .trailing)
            .environment(\.layoutDirection, appRTL ? .rightToLeft : .leftToRight)
    }
}
