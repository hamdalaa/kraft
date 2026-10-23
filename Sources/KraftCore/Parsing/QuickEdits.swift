import Foundation

/// A correction the user made to one understood field. `.auto` keeps what the parser read.
public enum FieldEdit<Value: Equatable & Sendable>: Equatable, Sendable {
    case auto
    case set(Value)
    case removed
}

/// Corrections made in the quick-add tags, laid over each fresh parse while the user keeps typing.
public struct QuickEdits: Equatable, Sendable {
    public var kind: StickyKind?
    public var person: FieldEdit<String> = .auto
    public var amount: FieldEdit<Decimal> = .auto
    public var currency: Currency?
    public var day: FieldEdit<Date> = .auto
    public var time: FieldEdit<TimeOfDay> = .auto
    public var repeatRule: RepeatRule?

    public init() {}

    public var isEmpty: Bool { self == QuickEdits() }
}

extension ParsedSticky {
    /// Parses `text` as `edits.kind` (if set) and lays the other corrections over the result.
    public static func reading(_ text: String, edits: QuickEdits, now: Date = Date(), calendar: Calendar = .current) -> ParsedSticky {
        QuickParser.parse(text, now: now, calendar: calendar, kind: edits.kind).applying(edits, now: now, calendar: calendar)
    }

    public func applying(_ edits: QuickEdits, now: Date = Date(), calendar cal: Calendar = .current) -> ParsedSticky {
        var p = self
        if kind.isMoney {
            switch edits.person {
            case .auto: break
            case .set(let name): p.person = name.trimmingCharacters(in: .whitespaces).isEmpty ? nil : name
            case .removed: p.person = nil
            }
            switch edits.amount {
            case .auto: break
            case .set(let value): p.amount = value
            case .removed: p.amount = nil
            }
            if let c = edits.currency { p.currency = c }
            if p.amount != nil, p.currency == nil { p.currency = Currency.default(for: p.amount ?? 0) }
            if p.kind != .bill { p.title = Wording.moneyTitle(p.kind, person: p.person, isArabic: direction == .rightToLeft) }
        }
        guard kind != .note else { return p }
        if let r = edits.repeatRule { p.repeatRule = r }

        var day = p.date.map { cal.startOfDay(for: $0) }
        var time = p.hasTime ? p.date.map { TimeOfDay($0, calendar: cal) } : nil
        switch edits.day {
        case .auto: break
        case .set(let d): day = cal.startOfDay(for: d)
        case .removed: day = nil; time = nil
        }
        switch edits.time {
        case .auto: break
        case .set(let t): time = t
        case .removed: time = nil
        }
        guard edits.day != .auto || edits.time != .auto else { return p }

        var sched = Schedule()
        sched.day = day
        sched.time = time
        sched.timeIsExplicit = true
        if edits.day == .removed, edits.time == .auto { p.date = nil; p.hasTime = false; return p }
        (p.date, p.hasTime) = ScheduleResolver.resolve(sched, kind: kind, now: now, calendar: cal)
        return p
    }
}
