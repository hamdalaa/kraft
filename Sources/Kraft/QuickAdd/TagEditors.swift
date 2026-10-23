import KraftCore
import SwiftUI

/// Popover editor behind one tag. Writes corrections into `model.edits`; the parse re-runs live.
struct TagEditor: View {
    let field: TagField
    let parsed: ParsedSticky
    let model: QuickAddModel
    let close: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
            editor
            HStack {
                if canRemove {
                    Button(role: .destructive) { remove(); close() } label: { Text("Remove") }
                        .buttonStyle(.borderless)
                }
                Spacer()
                Button { close() } label: { EmbossedLabel(text: String(localized: "Done"), tint: .blue, size: .mini) }
                    .buttonStyle(GlossyButtonStyle(tint: .blue, size: .mini))
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(14)
        .frame(width: field == .date ? 252 : 236)
    }

    private var title: String {
        switch field {
        case .person: parsed.kind == .owedToMe ? String(localized: "Who owes you") : String(localized: "Who you owe")
        case .amount: String(localized: "Amount")
        case .date: parsed.kind.isMoney ? String(localized: "Due") : String(localized: "Day")
        case .time: String(localized: "Time")
        case .repeatRule: String(localized: "Repeat")
        case .kind, .items: ""
        }
    }

    private var canRemove: Bool {
        switch field {
        case .person: parsed.person != nil
        case .amount: parsed.amount != nil
        case .date: parsed.date != nil
        case .time: parsed.hasTime
        case .repeatRule: parsed.repeatRule != .never
        case .kind, .items: false
        }
    }

    @ViewBuilder private var editor: some View {
        switch field {
        case .person:
            TextField(String(localized: "Name"), text: personBinding)
                .textFieldStyle(.roundedBorder)
                .onSubmit(close)
        case .amount:
            HStack(spacing: 8) {
                TextField(String(localized: "Amount"), value: amountBinding, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(close)
                CurrencyMenuButton(selected: currencyBinding.wrappedValue, tint: .pink) { currencyBinding.wrappedValue = $0 }
            }
        case .date:
            DatePicker("", selection: dayBinding, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .labelsHidden()
        case .time:
            DatePicker("", selection: timeBinding, displayedComponents: .hourAndMinute)
                .datePickerStyle(.field)
                .labelsHidden()
        case .repeatRule:
            VStack(alignment: .leading, spacing: 2) {
                ForEach(RepeatRule.allCases, id: \.self) { rule in
                    Button { edit { $0.repeatRule = rule }; close() } label: {
                        HStack {
                            Text(rule.label)
                            Spacer()
                            if rule == parsed.repeatRule { Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)) }
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 6)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        case .kind, .items:
            EmptyView()
        }
    }

    private func edit(_ change: (inout QuickEdits) -> Void) {
        var e = model.edits
        change(&e)
        model.edits = e
    }

    private func remove() {
        edit {
            switch field {
            case .person: $0.person = .removed
            case .amount: $0.amount = .removed
            case .date: $0.day = .removed
            case .time: $0.time = .removed
            case .repeatRule: $0.repeatRule = .never
            case .kind, .items: break
            }
        }
    }

    private var personBinding: Binding<String> {
        Binding(get: { parsed.person ?? "" }, set: { v in edit { $0.person = .set(v) } })
    }

    private var amountBinding: Binding<Decimal> {
        Binding(get: { parsed.amount ?? 0 }, set: { v in edit { $0.amount = .set(v) } })
    }

    private var currencyBinding: Binding<Currency> {
        Binding(get: { parsed.currency ?? .preferred }, set: { c in edit { $0.currency = c } })
    }

    /// Defaults when adding a missing date: tomorrow.
    private var dayBinding: Binding<Date> {
        Binding(get: { parsed.date ?? Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date() },
                set: { d in edit { $0.day = .set(d) } })
    }

    /// Defaults when adding a missing time: 9:00 on the parsed day.
    private var timeBinding: Binding<Date> {
        Binding(get: {
            if let d = parsed.date, parsed.hasTime { return d }
            return Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: parsed.date ?? Date()) ?? Date()
        }, set: { d in edit { $0.time = .set(TimeOfDay(d, calendar: .current)) } })
    }
}

/// The kind as a die-cut sticker; clicking it switches kind.
struct KindStickerButton: View {
    let kind: StickyKind
    let model: QuickAddModel
    @State private var isOpen = false
    @State private var bump = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button { isOpen = true } label: {
            VStack(spacing: 6) {
                DieCutSticker(art: kind.sticker, size: 30, tilt: .degrees(-8))
                    .scaleEffect(bump ? 1.12 : 1)
                HStack(spacing: 3) {
                    Text(kind.quickAddName)
                    Image(systemName: "chevron.down").font(.system(size: 8, weight: .bold))
                }
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Tok.Kraft.ink.opacity(0.8))
                .fixedSize()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(Text("Change kind"))
        .accessibilityLabel(Text("Kind: \(kind.quickAddName)"))
        .popover(isPresented: $isOpen, arrowEdge: .bottom) {
            KindPicker(selected: kind) { model.setKind($0); isOpen = false }
        }
        .onChange(of: kind) {
            guard Motion.enabled, !reduceMotion else { return }
            withAnimation(.spring(duration: 0.18)) { bump = true }
            withAnimation(.spring(duration: 0.4, bounce: 0.45).delay(0.12)) { bump = false }
        }
    }
}

struct KindPicker: View {
    let selected: StickyKind
    let choose: (StickyKind) -> Void

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.fixed(84), spacing: 6), count: 3), spacing: 6) {
            ForEach(StickyKind.allCases, id: \.self) { kind in
                Button { choose(kind) } label: {
                    VStack(spacing: 4) {
                        DieCutSticker(art: kind.sticker, size: 20)
                        Text(kind.quickAddName).font(.system(size: 11, weight: .semibold)).foregroundStyle(Tok.Sticker.label.opacity(0.8))
                    }
                    .frame(width: 84, height: 66)
                    .background {
                        if kind == selected { GlossyTagBackground(tint: .amber, height: 66) }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(kind == selected ? .isSelected : [])
            }
        }
        .padding(12)
    }
}
