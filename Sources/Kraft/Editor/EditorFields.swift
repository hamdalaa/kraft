import KraftCore
import SwiftUI

// MARK: Reminder

struct EditorReminderFields: View {
    let sticky: Sticky
    let edit: StickyEditing

    @Environment(\.kraftFormat) private var format

    private var reminder: ReminderInfo { sticky.reminder ?? ReminderInfo(fireDate: Date()) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            EditorLabel("When")
            EditorSlip(symbol: "bell") {
                DatePicker("", selection: fireDate, displayedComponents: [.date, .hourAndMinute])
                    .labelsHidden()
                    .datePickerStyle(.field)
            }
            EditorFlow(spacing: 6) {
                EditorChip("In an hour", symbol: "clock") { set(Date().addingTimeInterval(3600)) }
                EditorChip("Tonight \(format.time(at(20, dayOffset: 0)))") { set(at: 20, dayOffset: 0) }
                EditorChip("Tomorrow \(format.time(at(9, dayOffset: 1)))") { set(at: 9, dayOffset: 1) }
            }
            EditorLabel("Repeat").padding(.top, 4)
            EditorFlow(spacing: 6) {
                ForEach(RepeatRule.allCases, id: \.self) { rule in
                    EditorChip(rule.editorTitle, isOn: reminder.repeatRule == rule, tint: .amber) {
                        edit.change(String(localized: "Change Repeat")) {
                            $0.reminder = ReminderInfo(fireDate: $0.reminder?.fireDate ?? Date(), repeatRule: rule)
                        }
                    }
                }
            }
        }
    }

    private var fireDate: Binding<Date> {
        Binding(get: { reminder.fireDate }, set: { set($0) })
    }

    private func set(_ date: Date) {
        edit.change(String(localized: "Change Reminder"), coalesce: true) {
            $0.reminder = ReminderInfo(fireDate: date, repeatRule: $0.reminder?.repeatRule ?? .never)
        }
    }

    private func set(at hour: Int, dayOffset: Int) { set(at(hour, dayOffset: dayOffset)) }

    private func at(_ hour: Int, dayOffset: Int) -> Date {
        let cal = Calendar.current
        let day = cal.date(byAdding: .day, value: dayOffset, to: cal.startOfDay(for: Date())) ?? Date()
        return cal.date(bySettingHour: hour, minute: 0, second: 0, of: day) ?? day
    }
}

// MARK: Money (owes me / I owe)

struct EditorMoneyFields: View {
    let sticky: Sticky
    let edit: StickyEditing

    @State private var newPayment = ""
    @State private var showsRemind = false
    @Environment(\.kraftFormat) private var format

    private var money: MoneyInfo { sticky.money ?? MoneyInfo(person: "", amount: 0, currency: .iqd) }
    private var arabic: Bool { Hand(text: sticky.primaryText).direction == .rightToLeft }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            EditorLabel(sticky.kind == .owedToMe ? "Who owes you" : "Who you owe")
            EditorSlip(symbol: "person") {
                TextField("", text: person, prompt: Text("Name"))
                    .editorWriting(ScriptDirection.detect(money.person))
            }
            EditorAmountRow(money: money, edit: edit, format: format)
            EditorDueRow(due: money.dueDate, edit: edit)
            payments
            summary
        }
    }

    private var person: Binding<String> {
        Binding(get: { money.person }, set: { value in
            edit.change(StickyEditing.typing, coalesce: true) { $0.money?.person = value }
        })
    }

    private var payments: some View {
        VStack(alignment: .leading, spacing: 6) {
            EditorLabel("Payments").padding(.top, 4)
            ForEach(money.payments) { p in
                HStack(spacing: 8) {
                    Image(systemName: format.symbol("arrow.turn.down.right")).font(.system(size: 10, weight: .bold)).foregroundStyle(Tok.Kraft.ink.opacity(0.4))
                    Text(format.money(p.amount, money.currency)).font(.system(size: 13, weight: .semibold).monospacedDigit())
                    Text(format.dayMonth(p.date)).font(.system(size: 12)).foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        withAnimation(.spring(duration: 0.3)) {
                            edit.change(String(localized: "Remove Payment")) { $0.money = $0.money.map { StickyEdits.removePayment(p.id, from: $0) } }
                        }
                    } label: {
                        Image(systemName: "minus.circle.fill").font(.system(size: 13)).foregroundStyle(TagTint.pink.ink.opacity(0.75))
                    }
                    .buttonStyle(.plain)
                    .help(Text("Remove payment"))
                }
                .foregroundStyle(Tok.Card.text)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            if !money.isSettled {
                HStack(spacing: 6) {
                    EditorSlip(symbol: "plus") {
                        TextField("", text: $newPayment, prompt: Text("Amount paid"))
                            .onSubmit(addPayment)
                    }
                    EditorChip("Add", tint: .mint) { addPayment() }
                        .disabled(StickyEdits.parseAmount(newPayment) == nil)
                    if money.amount > 0 {
                        EditorChip("All", tint: .mint) { add(money.remaining) }
                            .help(Text("Paid in full"))
                    }
                }
            }
        }
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text("Paid \(format.money(money.paid, money.currency))")
                Spacer()
                Text(money.isSettled ? "All settled" : "Left \(format.money(money.remaining, money.currency))")
                    .foregroundStyle(money.isSettled ? TagTint.mint.ink : Tok.Kraft.ink)
            }
            .font(.system(size: 13, weight: .semibold).monospacedDigit())
            .foregroundStyle(Tok.Kraft.ink.opacity(0.85))
            .contentTransition(.numericText())
            if !money.isSettled, money.amount > 0 {
                Button { showsRemind = true } label: {
                    EmbossedLabel(text: String(localized: sticky.kind == .owedToMe ? "Remind them" : "Message them"),
                                  symbol: "bubble.left.and.text.bubble.right", tint: .mint, size: .regular)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(GlossyButtonStyle(tint: .mint))
                .popover(isPresented: $showsRemind, arrowEdge: .bottom) {
                    EditorRemindPopover(sticky: sticky)
                }
            }
        }
        .padding(.top, 2)
    }

    private func addPayment() {
        guard let amount = StickyEdits.parseAmount(newPayment) else { return }
        add(amount)
    }

    private func add(_ amount: Decimal) {
        guard amount > 0 else { return }
        withAnimation(.spring(duration: 0.3)) {
            edit.change(String(localized: "Add Payment")) { $0.money = $0.money.map { StickyEdits.addPayment(amount, on: Date(), to: $0) } }
        }
        newPayment = ""
    }
}

/// Amount slip (Western or Arabic digits) and the IQD / USD tags.
private struct EditorAmountRow: View {
    let money: MoneyInfo
    let edit: StickyEditing
    let format: KraftFormat
    @State private var text: String

    init(money: MoneyInfo, edit: StickyEditing, format: KraftFormat) {
        self.money = money
        self.edit = edit
        self.format = format
        _text = State(initialValue: Self.text(money.amount, format))
    }

    var body: some View {
        HStack(spacing: 6) {
            EditorSlip(symbol: "banknote") {
                TextField("", text: $text, prompt: Text("Amount"))
                    .onChange(of: text) {
                        guard let value = StickyEdits.parseAmount(text), value != money.amount else { return }
                        edit.change(String(localized: "Change Amount"), coalesce: true) { $0.money?.amount = value }
                    }
            }
            ForEach(Currency.allCases, id: \.self) { c in
                EditorChip(c.title, isOn: money.currency == c, tint: .mint) {
                    edit.change(String(localized: "Change Currency")) { $0.money?.currency = c }
                }
            }
        }
        .onChange(of: money.amount) {
            // Undo or another window changed it: show the stored value unless it is what is being typed.
            if StickyEdits.parseAmount(text) != money.amount { text = Self.text(money.amount, format) }
        }
        .onChange(of: format.digits) { text = format.digits(in: text) }
    }

    /// Amount in the chosen digits ("150,000" / «١٥٠٬٠٠٠»); StickyEdits.parseAmount reads both back.
    static func text(_ amount: Decimal, _ format: KraftFormat) -> String {
        guard amount > 0 else { return "" }
        return amount.formatted(.number.locale(format.locale))
    }
}

/// Optional due date: a tag to add one, a date field with a remove button once set.
private struct EditorDueRow: View {
    let due: Date?
    let edit: StickyEditing

    var body: some View {
        if let due {
            HStack(spacing: 6) {
                EditorSlip(symbol: "calendar") {
                    DatePicker("", selection: Binding(get: { due }, set: { d in
                        edit.change(String(localized: "Change Due Date"), coalesce: true) { $0.money?.dueDate = d }
                    }), displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.field)
                }
                EditorChip("No date", tint: .pink) {
                    edit.change(String(localized: "Remove Due Date")) { $0.money?.dueDate = nil }
                }
            }
        } else {
            EditorChip("Add a due date", symbol: "calendar.badge.plus", tint: .mint) {
                let week = Calendar.current.date(byAdding: .day, value: 7, to: Calendar.current.startOfDay(for: Date()))
                edit.change(String(localized: "Add Due Date")) { $0.money?.dueDate = week }
            }
        }
    }
}

// MARK: Bill

struct EditorBillFields: View {
    let sticky: Sticky
    let edit: StickyEditing

    @Environment(\.kraftFormat) private var format

    private var money: MoneyInfo { sticky.money ?? MoneyInfo(person: "", amount: 0, currency: .iqd) }
    private var dueDay: Int? { money.dueDate.map { Calendar.current.component(.day, from: $0) } }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            EditorLabel("Amount")
            EditorAmountRow(money: money, edit: edit, format: format)
            HStack {
                EditorLabel("Due every month on")
                Spacer()
                if let dueDay {
                    Text("day \(format.number(dueDay))").font(.system(size: 12, weight: .semibold)).foregroundStyle(TagTint.lime.ink)
                }
            }
            .padding(.top, 4)
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(30), spacing: 6), count: 7), spacing: 6) {
                ForEach(1...31, id: \.self) { day in
                    EditorDayCell(day: day, isOn: day == dueDay) {
                        edit.change(String(localized: "Change Due Day")) {
                            $0.money?.dueDate = StickyEdits.billDue(day: day, after: Date())
                        }
                    }
                }
            }
            if let due = money.dueDate {
                Text("Next: \(format.longDay(due))")
                    .font(.system(size: 12))
                    .foregroundStyle(Tok.Kraft.ink.opacity(0.7))
            }
        }
    }
}

/// One day on the little bill calendar: a glossy dot when chosen.
private struct EditorDayCell: View {
    let day: Int
    let isOn: Bool
    let action: () -> Void
    @Environment(\.kraftFormat) private var format

    var body: some View {
        Button(action: action) {
            Text(verbatim: format.number(day))
                .font(.system(size: 11.5, weight: isOn ? .bold : .medium).monospacedDigit())
                .foregroundStyle(isOn ? TagTint.lime.ink : Tok.Kraft.ink.opacity(0.7))
                .frame(width: 28, height: 28)
                .background {
                    if isOn { GlossyTagBackground(tint: .lime, height: 28).clipShape(Circle()) }
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}
