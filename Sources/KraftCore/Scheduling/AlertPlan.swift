import Foundation

/// The notification actions besides "Done".
public enum SnoozeOption: String, CaseIterable, Sendable {
    case tenMinutes, oneHour, tomorrow

    /// 10 min / 1 h from `now`, or 09:00 on the next calendar day (wall clock, DST-safe).
    public func target(from now: Date, calendar: Calendar) -> Date {
        switch self {
        case .tenMinutes: return now.addingTimeInterval(10 * 60)
        case .oneHour: return now.addingTimeInterval(60 * 60)
        case .tomorrow:
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now
            return DueAlert.morning(of: tomorrow, calendar: calendar)
        }
    }
}

/// Money and bill stickies ring once, at 09:00 on the due day.
public enum DueAlert {
    public static let hour = 9

    /// 09:00 on the day of `date`.
    public static func morning(of date: Date, calendar: Calendar) -> Date {
        calendar.date(bySettingHour: hour, minute: 0, second: 0, of: calendar.startOfDay(for: date)) ?? date
    }

    /// The due-day alert for a money / bill due date, or nil once that morning has passed.
    public static func next(forDue due: Date, after now: Date, calendar: Calendar) -> Date? {
        let alert = morning(of: due, calendar: calendar)
        return alert > now ? alert : nil
    }
}

/// One notification that should be pending right now.
public struct PlannedAlert: Hashable, Sendable {
    public var id: UUID
    public var date: Date
    public var copy: AlertCopy
}

/// "What should be scheduled now": at most one alert per sticky, nothing for finished or deleted ones.
public enum AlertPlanner {
    public static func plan(_ stickies: [Sticky], now: Date, calendar: Calendar, digits: DigitStyle? = nil) -> [PlannedAlert] {
        stickies.compactMap { sticky in
            alertDate(for: sticky, now: now, calendar: calendar).map {
                PlannedAlert(id: sticky.id, date: $0, copy: AlertCopy.make(for: sticky, digits: digits, calendar: calendar))
            }
        }
        .sorted { $0.date < $1.date }
    }

    /// When this sticky should next ring, or nil. A reminder wins over a money due date.
    public static func alertDate(for sticky: Sticky, now: Date, calendar: Calendar) -> Date? {
        guard sticky.deletedAt == nil, !sticky.isFinished else { return nil }
        if let reminder = sticky.reminder { return reminder.nextAlert(after: now, calendar: calendar) }
        if let due = sticky.money?.dueDate { return DueAlert.next(forDue: due, after: now, calendar: calendar) }
        return nil
    }

    /// True when at least one sticky has a reminder or due date worth asking notification permission for.
    public static func needsPermission(_ stickies: [Sticky], now: Date, calendar: Calendar) -> Bool {
        stickies.contains { alertDate(for: $0, now: now, calendar: calendar) != nil }
    }
}

extension Sticky {
    /// Snooze / Tomorrow pressed. A money sticky without a reminder gains a one-off reminder on its due morning
    /// so the snooze has somewhere to live.
    public func snoozed(_ option: SnoozeOption, now: Date, calendar: Calendar) -> Sticky {
        var copy = self
        var reminder = reminder
            ?? ReminderInfo(fireDate: money?.dueDate.map { DueAlert.morning(of: $0, calendar: calendar) } ?? now)
        reminder.snoozedUntil = option.target(from: now, calendar: calendar)
        copy.reminder = reminder
        return copy
    }

    /// Done pressed on the alert for `occurrence`. Repeating reminders move on; everything else is done.
    public func completingAlert(occurrence: Date, now: Date, calendar: Calendar) -> Sticky {
        var copy = self
        if let next = reminder?.completing(occurrence: occurrence, now: now, calendar: calendar) {
            copy.reminder = next
        } else {
            copy.isDone = true
            copy.completedAt = now
            copy.reminder?.snoozedUntil = nil
        }
        return copy
    }
}
