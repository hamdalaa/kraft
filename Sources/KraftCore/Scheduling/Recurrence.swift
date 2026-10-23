import Foundation

/// Calendar math for repeating reminders. Every occurrence is computed from the series anchor
/// (anchor + n days / weeks / months / years), never from the previous occurrence, so the wall-clock
/// time survives DST changes and month-end / leap-day clamping never drifts (31st → 28 Feb → 31 Mar).
public enum Recurrence {
    /// The `n`-th occurrence (0 = the anchor itself). Nil for `.never` beyond the first.
    public static func occurrence(_ n: Int, anchor: Date, rule: RepeatRule, calendar: Calendar) -> Date? {
        switch rule {
        case .never: n == 0 ? anchor : nil
        case .daily: calendar.date(byAdding: .day, value: n, to: anchor)
        case .weekly: calendar.date(byAdding: .day, value: 7 * n, to: anchor)
        case .monthly: calendar.date(byAdding: .month, value: n, to: anchor)
        case .yearly: calendar.date(byAdding: .year, value: n, to: anchor)
        }
    }

    /// First occurrence strictly after `date`.
    public static func next(after date: Date, anchor: Date, rule: RepeatRule, calendar: Calendar) -> Date? {
        if anchor > date { return anchor }
        guard rule != .never else { return nil }
        // Jump close with a whole-unit estimate, then step forward; one or two steps at most.
        var n = max(0, elapsedUnits(from: anchor, to: date, rule: rule, calendar: calendar) - 1)
        for _ in 0..<8 {
            guard let d = occurrence(n, anchor: anchor, rule: rule, calendar: calendar) else { return nil }
            if d > date { return d }
            n += 1
        }
        return nil
    }

    private static func elapsedUnits(from a: Date, to b: Date, rule: RepeatRule, calendar: Calendar) -> Int {
        switch rule {
        case .never: 0
        case .daily: calendar.dateComponents([.day], from: a, to: b).day ?? 0
        case .weekly: (calendar.dateComponents([.day], from: a, to: b).day ?? 0) / 7
        case .monthly: calendar.dateComponents([.month], from: a, to: b).month ?? 0
        case .yearly: calendar.dateComponents([.year], from: a, to: b).year ?? 0
        }
    }
}

extension ReminderInfo {
    /// Start of the series `fireDate` belongs to: `anchor` while `fireDate` is still one of its occurrences
    /// (the editor may have moved `fireDate` since), otherwise `fireDate` itself.
    public func seriesAnchor(calendar: Calendar) -> Date {
        guard repeatRule != .never, let anchor, anchor <= fireDate else { return fireDate }
        let probe = Recurrence.next(after: fireDate.addingTimeInterval(-1), anchor: anchor, rule: repeatRule, calendar: calendar)
        guard let probe, abs(probe.timeIntervalSince(fireDate)) < 1 else { return fireDate }
        return anchor
    }

    /// The next time this reminder should ring after `now`, snooze included. Nil when it has nothing left to say.
    public func nextAlert(after now: Date, calendar: Calendar) -> Date? {
        if let snoozedUntil, snoozedUntil > now { return snoozedUntil }
        if fireDate > now { return fireDate }
        guard repeatRule != .never else { return nil }
        return Recurrence.next(after: now, anchor: seriesAnchor(calendar: calendar), rule: repeatRule, calendar: calendar)
    }

    /// "Done" pressed on the alert for `occurrence`. Repeating: moves to the next occurrence after both
    /// `now` and `occurrence`. One-off: nil, meaning the sticky itself is done.
    public func completing(occurrence: Date, now: Date, calendar: Calendar) -> ReminderInfo? {
        guard repeatRule != .never else { return nil }
        var copy = self
        let anchor = seriesAnchor(calendar: calendar)
        copy.anchor = anchor
        copy.snoozedUntil = nil
        let after = max(now, occurrence)
        // A stale alert (the series already moved past it) changes nothing but the snooze.
        if fireDate <= after {
            copy.fireDate = Recurrence.next(after: after, anchor: anchor, rule: repeatRule, calendar: calendar) ?? fireDate
        }
        return copy
    }
}
