import KraftCore
import SwiftUI

/// A field quick add understood (or could understand) — one glossy tag each.
enum TagField: Hashable, CaseIterable {
    case kind, person, amount, date, time, repeatRule, items
}

struct UnderstoodTag: Identifiable {
    let field: TagField
    let text: String
    let symbol: String
    let tint: TagTint
    /// Not understood yet: drawn as a dashed outline that invites a click.
    var isGhost = false
    var id: TagField { field }

    static func tags(for p: ParsedSticky, format: KraftFormat, now: Date = Date(), calendar: Calendar = .current) -> [UnderstoodTag] {
        var out: [UnderstoodTag] = []
        let money = p.kind == .owedToMe || p.kind == .iOwe
        if money {
            out.append(p.person.map { UnderstoodTag(field: .person, text: $0, symbol: "person.fill", tint: .mint) }
                ?? ghost(.person, String(localized: "Who?"), "person"))
        }
        if p.kind.isMoney {
            out.append(p.amount.map {
                UnderstoodTag(field: .amount, text: format.money($0, p.currency ?? Currency.default(for: $0)),
                              symbol: "banknote.fill", tint: .pink)
            } ?? ghost(.amount, String(localized: "Amount"), "banknote"))
        }
        if p.kind != .note {
            if let date = p.date {
                let day = dayText(date, format: format, now: now, calendar: calendar)
                out.append(UnderstoodTag(field: .date, text: p.kind.isMoney ? String(localized: "Due \(day)") : day,
                                         symbol: "calendar", tint: .blue))
                if p.hasTime {
                    out.append(UnderstoodTag(field: .time, text: format.time(date),
                                             symbol: "clock.fill", tint: .amber))
                } else if p.kind == .reminder {
                    out.append(ghost(.time, String(localized: "Time"), "clock"))
                }
            } else if p.kind != .todo || !p.checklist.isEmpty {
                out.append(ghost(.date, p.kind.isMoney ? String(localized: "Due date") : String(localized: "When?"), "calendar"))
            }
        }
        if p.repeatRule != .never {
            out.append(UnderstoodTag(field: .repeatRule, text: p.repeatRule.label, symbol: "arrow.clockwise", tint: .lime))
        } else if p.kind == .reminder || p.kind == .bill {
            out.append(ghost(.repeatRule, String(localized: "Repeat"), "arrow.clockwise"))
        }
        if p.kind == .todo, !p.checklist.isEmpty {
            out.append(UnderstoodTag(field: .items, text: Plural.string("count.items", p.checklist.count, format), symbol: "checklist", tint: .blue))
        }
        return out
    }

    private static func ghost(_ field: TagField, _ text: String, _ symbol: String) -> UnderstoodTag {
        UnderstoodTag(field: field, text: text, symbol: symbol, tint: .blue, isGhost: true)
    }

    static func dayText(_ date: Date, format: KraftFormat, now: Date, calendar: Calendar) -> String {
        if calendar.isDate(date, inSameDayAs: now) { return String(localized: "Today") }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now), calendar.isDate(date, inSameDayAs: tomorrow) {
            return String(localized: "Tomorrow")
        }
        return format.weekdayDayMonth(date)
    }
}

extension RepeatRule {
    var label: String {
        switch self {
        case .never: String(localized: "Never")
        case .daily: String(localized: "Daily")
        case .weekly: String(localized: "Weekly")
        case .monthly: String(localized: "Monthly")
        case .yearly: String(localized: "Yearly")
        }
    }
}

extension ParsedSpan.Field {
    /// Highlighter colour in the field: the same hue as the field's tag.
    func markColor(kind: StickyKind) -> Color {
        switch self {
        case .kind: kind.sticker.fill.opacity(0.24)
        case .person: TagTint.mint.bottom
        case .amount: TagTint.pink.bottom
        case .date: TagTint.blue.bottom
        case .time: TagTint.amber.bottom
        case .repeatRule: TagTint.lime.bottom.opacity(0.8)
        }
    }
}

/// The row of tags under the field. Clicking a tag opens its editor in a popover.
struct UnderstoodTagRow: View {
    let parsed: ParsedSticky
    let model: QuickAddModel
    @State private var open: TagField?
    @Environment(\.kraftFormat) private var format

    var body: some View {
        let tags = UnderstoodTag.tags(for: parsed, format: format)
        FlowLayout(spacing: 8, lineSpacing: 9) {
            ForEach(tags) { tag in
                if tag.field == .items {
                    GlossyTag(text: tag.text, symbol: tag.symbol, tint: tag.tint)
                } else {
                    Button { open = tag.field } label: {
                        EmbossedLabel(text: tag.text, symbol: tag.symbol, tint: tag.isGhost ? .ghost : tag.tint, size: .regular)
                    }
                    .buttonStyle(TagButtonStyle(tint: tag.tint, isGhost: tag.isGhost))
                    .help(tag.isGhost ? Text("Add") : Text("Change"))
                    .popover(isPresented: isOpen(tag.field), arrowEdge: .bottom) {
                        TagEditor(field: tag.field, parsed: parsed, model: model) { open = nil }
                            .preferredColorScheme(.light)
                    }
                    .transition(.scale(scale: 0.85).combined(with: .opacity))
                }
            }
        }
        .animation(Motion.enabled ? .spring(duration: 0.3, bounce: 0.2) : nil, value: tags.map(\.text))
    }

    private func isOpen(_ f: TagField) -> Binding<Bool> {
        Binding(get: { open == f }, set: { if !$0, open == f { open = nil } })
    }
}

extension TagTint {
    /// Ink for not-yet-understood tags: kraft ink, quiet.
    static let ghost = TagTint(top: .clear, bottom: .clear, edge: Tok.Kraft.ink.opacity(0.35), ink: Tok.Kraft.ink.opacity(0.62))
}

/// Glossy tag for understood fields; a dashed die-line for fields still to fill.
struct TagButtonStyle: ButtonStyle {
    let tint: TagTint
    var isGhost = false

    func makeBody(configuration: Configuration) -> some View {
        if isGhost {
            let shape = RoundedRectangle(cornerRadius: TagSize.regular.height * 0.28, style: .continuous)
            configuration.label
                .padding(.horizontal, TagSize.regular.padding)
                .frame(height: TagSize.regular.height)
                .background(shape.fill(.white.opacity(configuration.isPressed ? 0.5 : 0.28)))
                .overlay(shape.strokeBorder(Tok.Kraft.ink.opacity(0.32), style: StrokeStyle(lineWidth: 1, dash: [3.5, 2.5])))
                .scaleEffect(configuration.isPressed ? 0.97 : 1)
                .contentShape(shape)
        } else {
            GlossyButtonStyle(tint: tint).makeBody(configuration: configuration)
        }
    }
}

/// Wrapping row in reading order (SwiftUI mirrors the placement in right-to-left).
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        let width = rows.map(\.width).max() ?? 0
        let height = rows.map(\.height).reduce(0, +) + lineSpacing * CGFloat(max(rows.count - 1, 0))
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for i in row.indices {
                let size = subviews[i].sizeThatFits(.unspecified)
                subviews[i].place(at: CGPoint(x: x, y: y + (row.height - size.height) / 2), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + lineSpacing
        }
    }

    private struct Row { var indices: [Int] = []; var width: CGFloat = 0; var height: CGFloat = 0 }

    private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = [Row()]
        for i in subviews.indices {
            let size = subviews[i].sizeThatFits(.unspecified)
            let extra = rows[rows.count - 1].indices.isEmpty ? size.width : size.width + spacing
            if rows[rows.count - 1].width + extra > width, !rows[rows.count - 1].indices.isEmpty {
                rows.append(Row())
            }
            let isFirst = rows[rows.count - 1].indices.isEmpty
            rows[rows.count - 1].indices.append(i)
            rows[rows.count - 1].width += isFirst ? size.width : size.width + spacing
            rows[rows.count - 1].height = max(rows[rows.count - 1].height, size.height)
        }
        return rows.filter { !$0.indices.isEmpty }
    }
}
