import Foundation

/// Pins a `Schedule` to a calendar date.
enum ScheduleResolver {
    /// - Time only: today if still ahead, else tomorrow.
    /// - Weekday: the next one (today only when the time given is still ahead).
    /// - Day only: reminders ring at 9:00 (or the next whole hour if that has passed today); money is due that day.
    /// - A repeating bill with no day: the next one is due one period from today.
    static func resolve(_ sc: Schedule, kind: StickyKind, now: Date, calendar cal: Calendar) -> (Date?, Bool) {
        if let exact = sc.exact { return (exact, true) }
        let today = cal.startOfDay(for: now)
        let time = clockTime(sc)

        var day = sc.day
        if let w = sc.weekday {
            day = nextWeekday(w, today: today, time: time, now: now, cal: cal)
        } else if let d = sc.dayOfMonth {
            day = nextDayOfMonth(d, today: today, cal: cal)
        }

        guard let day else {
            if let time {
                let candidate = at(time, on: today, cal: cal)
                return (candidate > now ? candidate : at(time, on: plusDays(1, today, cal), cal: cal), true)
            }
            switch (kind, sc.repeatRule) {
            case (_, .never): return (nil, false)
            case (.bill, let rule): return (cal.date(byAdding: rule.component, value: 1, to: today), false)
            case (.reminder, _), (.todo, _):
                let nine = at(.defaultReminder, on: today, cal: cal)
                return (nine > now ? nine : at(.defaultReminder, on: plusDays(1, today, cal), cal: cal), false)
            default: return (nil, false)
            }
        }

        if let time { return (at(time, on: day, cal: cal), true) }
        if kind.isMoney { return (day, false) }
        let nine = at(.defaultReminder, on: day, cal: cal)
        if nine > now { return (nine, false) }
        let nextHour = cal.dateInterval(of: .hour, for: now)?.end ?? now
        return (cal.isDate(day, inSameDayAs: now) ? nextHour : nine, false)
    }

    /// The clock time, with "in the evening" / "الصبح" settling am vs pm when no am/pm was written.
    static func clockTime(_ sc: Schedule) -> TimeOfDay? {
        guard var t = sc.time else { return sc.softTime }
        if !sc.timeIsExplicit, let soft = sc.softTime {
            if soft.hour >= 15, t.hour < 12 { t.hour += 12 }
            if soft.hour < 12, t.hour > 12, t.hour - 12 <= 6 { t.hour -= 12 }
        }
        return t
    }

    static func nextWeekday(_ w: Int, today: Date, time: TimeOfDay?, now: Date, cal: Calendar) -> Date {
        if cal.component(.weekday, from: today) == w, let time, at(time, on: today, cal: cal) > now { return today }
        return cal.nextDate(after: today, matching: DateComponents(weekday: w), matchingPolicy: .nextTime) ?? today
    }

    /// The next `d`th: this month if still ahead (or today), else next month. Clamped to short months.
    static func nextDayOfMonth(_ d: Int, today: Date, cal: Calendar) -> Date {
        let todayDay = cal.component(.day, from: today)
        let monthStart = cal.dateInterval(of: .month, for: today)?.start ?? today
        let start = d >= todayDay ? monthStart : (cal.date(byAdding: .month, value: 1, to: monthStart) ?? monthStart)
        let length = cal.range(of: .day, in: .month, for: start)?.count ?? 28
        return plusDays(min(d, length) - 1, start, cal)
    }

    static func at(_ t: TimeOfDay, on day: Date, cal: Calendar) -> Date {
        cal.date(bySettingHour: t.hour, minute: t.minute, second: 0, of: day) ?? day
    }

    static func plusDays(_ n: Int, _ d: Date, _ cal: Calendar) -> Date { cal.date(byAdding: .day, value: n, to: d) ?? d }
}

extension RepeatRule {
    var component: Calendar.Component {
        switch self {
        case .never, .daily: .day
        case .weekly: .weekOfYear
        case .monthly: .month
        case .yearly: .year
        }
    }
}
