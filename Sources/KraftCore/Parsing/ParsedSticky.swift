import Foundation

/// What `QuickParser` understood from one sentence. Turn it into a record with `makeSticky(style:)`.
public struct ParsedSticky: Equatable, Sendable {
    public var kind: StickyKind
    public var title: String
    public var body: String
    public var person: String?
    public var amount: Decimal?
    public var currency: Currency?
    /// Due date (money) or fire date (reminder, dated to-do). Includes the time when `hasTime`.
    public var date: Date?
    public var hasTime: Bool
    public var repeatRule: RepeatRule
    public var checklist: [String]
    /// The phrases that were recognised, in text order, so the UI can mark them.
    public var spans: [ParsedSpan]
    public var direction: ScriptDirection

    public init(
        kind: StickyKind = .note, title: String = "", body: String = "", person: String? = nil,
        amount: Decimal? = nil, currency: Currency? = nil, date: Date? = nil, hasTime: Bool = false,
        repeatRule: RepeatRule = .never, checklist: [String] = [], spans: [ParsedSpan] = [],
        direction: ScriptDirection = .leftToRight
    ) {
        self.kind = kind
        self.title = title
        self.body = body
        self.person = person
        self.amount = amount
        self.currency = currency
        self.date = date
        self.hasTime = hasTime
        self.repeatRule = repeatRule
        self.checklist = checklist
        self.spans = spans
        self.direction = direction
    }

    public var isEmpty: Bool {
        title.isEmpty && body.isEmpty && checklist.isEmpty && person == nil && amount == nil
    }

    /// Builds the record. `style` comes from the UI (paper colour, tilt…).
    public func makeSticky(style: PaperStyle = PaperStyle(), now: Date = Date(), calendar: Calendar = .current) -> Sticky {
        let reminder = date.map { ReminderInfo(fireDate: $0, repeatRule: repeatRule) }
        // A bill is due on a day; its reminder rings that morning.
        let billReminder = date.map { d in
            ReminderInfo(fireDate: hasTime ? d : ScheduleResolver.at(.defaultReminder, on: d, cal: calendar), repeatRule: repeatRule)
        }
        switch kind {
        case .note:
            return Sticky(kind: .note, title: title, body: body, style: style, createdAt: now)
        case .todo:
            return Sticky(kind: .todo, title: title, checklist: checklist.map { ChecklistItem(text: $0) },
                          reminder: reminder, style: style, createdAt: now)
        case .reminder:
            return Sticky(kind: .reminder, title: title, body: body, reminder: reminder, style: style, createdAt: now)
        case .owedToMe, .iOwe, .bill:
            let money = MoneyInfo(person: person ?? "", amount: amount ?? 0,
                                  currency: currency ?? .preferred, dueDate: date)
            return Sticky(kind: kind, title: title, body: body, money: money,
                          reminder: kind == .bill ? billReminder : nil, style: style, createdAt: now)
        }
    }
}

/// One recognised phrase. `range` indexes the text that was parsed.
public struct ParsedSpan: Equatable, Sendable {
    public enum Field: String, Sendable, CaseIterable {
        case kind, person, amount, date, time, repeatRule
    }

    public var field: Field
    public var range: Range<String.Index>
    public var text: String

    public init(field: Field, range: Range<String.Index>, text: String) {
        self.field = field
        self.range = range
        self.text = text
    }
}

public struct TimeOfDay: Equatable, Hashable, Sendable {
    public var hour: Int
    public var minute: Int

    public init(hour: Int, minute: Int = 0) {
        self.hour = hour
        self.minute = minute
    }

    public init(_ date: Date, calendar: Calendar) {
        let c = calendar.dateComponents([.hour, .minute], from: date)
        self.init(hour: c.hour ?? 0, minute: c.minute ?? 0)
    }

    /// When nothing more specific is said: reminders ring at 9 in the morning.
    public static let defaultReminder = TimeOfDay(hour: 9)
}


