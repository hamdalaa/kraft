import Foundation
import Testing
@testable import KraftCore

/// Wall-clock dates in a fixed zone so DST cases are deterministic.
struct Clock {
    let calendar: Calendar

    init(_ zone: String) {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: zone)!
        calendar = c
    }

    func at(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 9, _ min: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    func parts(_ date: Date?) -> [Int] {
        guard let date else { return [] }
        let c = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        return [c.year!, c.month!, c.day!, c.hour!, c.minute!]
    }
}

@Suite struct RecurrenceTests {
    struct Case: CustomTestStringConvertible, Sendable {
        let name: String
        let zone: String
        let rule: RepeatRule
        let anchor: [Int]
        let after: [Int]
        let expected: [Int]
        var testDescription: String { name }
    }

    static let cases: [Case] = [
        Case(name: "daily, same day later", zone: "Asia/Baghdad", rule: .daily,
             anchor: [2026, 10, 1, 9, 0], after: [2026, 10, 23, 12, 0], expected: [2026, 10, 24, 9, 0]),
        Case(name: "daily, before today's time", zone: "Asia/Baghdad", rule: .daily,
             anchor: [2026, 10, 1, 9, 0], after: [2026, 10, 23, 8, 59], expected: [2026, 10, 23, 9, 0]),
        Case(name: "daily, exactly at occurrence is strictly after", zone: "Asia/Baghdad", rule: .daily,
             anchor: [2026, 10, 1, 9, 0], after: [2026, 10, 23, 9, 0], expected: [2026, 10, 24, 9, 0]),
        Case(name: "daily, years later", zone: "Asia/Baghdad", rule: .daily,
             anchor: [2020, 1, 1, 9, 0], after: [2026, 10, 23, 12, 0], expected: [2026, 10, 24, 9, 0]),
        Case(name: "daily across London spring-forward keeps 09:00", zone: "Europe/London", rule: .daily,
             anchor: [2026, 3, 20, 9, 0], after: [2026, 3, 28, 10, 0], expected: [2026, 3, 29, 9, 0]),
        Case(name: "daily across London fall-back keeps 09:00", zone: "Europe/London", rule: .daily,
             anchor: [2026, 10, 20, 9, 0], after: [2026, 10, 24, 10, 0], expected: [2026, 10, 25, 9, 0]),
        Case(name: "daily 02:30 lands in New York DST gap → 03:30", zone: "America/New_York", rule: .daily,
             anchor: [2026, 3, 1, 2, 30], after: [2026, 3, 7, 3, 0], expected: [2026, 3, 8, 3, 30]),
        Case(name: "daily 02:30 returns after the gap", zone: "America/New_York", rule: .daily,
             anchor: [2026, 3, 1, 2, 30], after: [2026, 3, 8, 4, 0], expected: [2026, 3, 9, 2, 30]),
        Case(name: "weekly across fall-back", zone: "Europe/London", rule: .weekly,
             anchor: [2026, 10, 19, 9, 0], after: [2026, 10, 23, 12, 0], expected: [2026, 10, 26, 9, 0]),
        Case(name: "weekly before first", zone: "Europe/London", rule: .weekly,
             anchor: [2026, 10, 19, 9, 0], after: [2026, 10, 1, 12, 0], expected: [2026, 10, 19, 9, 0]),
        Case(name: "monthly 31st → end of February", zone: "Asia/Baghdad", rule: .monthly,
             anchor: [2026, 1, 31, 9, 0], after: [2026, 2, 1, 9, 0], expected: [2026, 2, 28, 9, 0]),
        Case(name: "monthly 31st → back to 31 March", zone: "Asia/Baghdad", rule: .monthly,
             anchor: [2026, 1, 31, 9, 0], after: [2026, 3, 1, 9, 0], expected: [2026, 3, 31, 9, 0]),
        Case(name: "monthly 31st → 30 April", zone: "Asia/Baghdad", rule: .monthly,
             anchor: [2026, 1, 31, 9, 0], after: [2026, 4, 1, 9, 0], expected: [2026, 4, 30, 9, 0]),
        Case(name: "monthly 31st → 29 Feb in a leap year", zone: "Asia/Baghdad", rule: .monthly,
             anchor: [2027, 12, 31, 9, 0], after: [2028, 2, 1, 9, 0], expected: [2028, 2, 29, 9, 0]),
        Case(name: "monthly 30th survives February", zone: "Asia/Baghdad", rule: .monthly,
             anchor: [2026, 1, 30, 9, 0], after: [2026, 3, 1, 9, 0], expected: [2026, 3, 30, 9, 0]),
        Case(name: "monthly across DST", zone: "Europe/London", rule: .monthly,
             anchor: [2026, 1, 15, 9, 0], after: [2026, 3, 30, 9, 0], expected: [2026, 4, 15, 9, 0]),
        Case(name: "yearly 29 Feb → 28 Feb", zone: "Asia/Baghdad", rule: .yearly,
             anchor: [2024, 2, 29, 9, 0], after: [2024, 3, 1, 9, 0], expected: [2025, 2, 28, 9, 0]),
        Case(name: "yearly 29 Feb → 29 Feb in the next leap year", zone: "Asia/Baghdad", rule: .yearly,
             anchor: [2024, 2, 29, 9, 0], after: [2027, 3, 1, 9, 0], expected: [2028, 2, 29, 9, 0]),
        Case(name: "yearly birthday", zone: "Asia/Baghdad", rule: .yearly,
             anchor: [1990, 6, 14, 8, 0], after: [2026, 10, 23, 9, 0], expected: [2027, 6, 14, 8, 0]),
        Case(name: "never, still ahead", zone: "Asia/Baghdad", rule: .never,
             anchor: [2026, 11, 1, 9, 0], after: [2026, 10, 23, 9, 0], expected: [2026, 11, 1, 9, 0]),
        Case(name: "never, passed", zone: "Asia/Baghdad", rule: .never,
             anchor: [2026, 10, 1, 9, 0], after: [2026, 10, 23, 9, 0], expected: []),
    ]

    @Test(arguments: cases)
    func nextOccurrence(_ c: Case) {
        let clock = Clock(c.zone)
        let a = c.anchor, x = c.after
        let next = Recurrence.next(after: clock.at(x[0], x[1], x[2], x[3], x[4]),
                                   anchor: clock.at(a[0], a[1], a[2], a[3], a[4]), rule: c.rule, calendar: clock.calendar)
        #expect(clock.parts(next) == c.expected)
    }

    @Test func dstDaysAreShortAndLong() {
        let clock = Clock("Europe/London")
        let spring = Recurrence.next(after: clock.at(2026, 3, 28, 10), anchor: clock.at(2026, 3, 28), rule: .daily, calendar: clock.calendar)!
        #expect(spring.timeIntervalSince(clock.at(2026, 3, 28)) == 23 * 3600)
        let fall = Recurrence.next(after: clock.at(2026, 10, 24, 10), anchor: clock.at(2026, 10, 24), rule: .daily, calendar: clock.calendar)!
        #expect(fall.timeIntervalSince(clock.at(2026, 10, 24)) == 25 * 3600)
    }
}

@Suite struct ReminderSeriesTests {
    let clock = Clock("Asia/Baghdad")
    var cal: Calendar { clock.calendar }

    @Test func doneOnMonthly31stWalksMonthEndsWithoutDrift() {
        var r = ReminderInfo(fireDate: clock.at(2026, 1, 31), repeatRule: .monthly)
        var seen: [[Int]] = []
        for _ in 0..<4 {
            r = r.completing(occurrence: r.fireDate, now: r.fireDate.addingTimeInterval(300), calendar: cal)!
            seen.append(clock.parts(r.fireDate))
        }
        #expect(seen == [[2026, 2, 28, 9, 0], [2026, 3, 31, 9, 0], [2026, 4, 30, 9, 0], [2026, 5, 31, 9, 0]])
        #expect(r.anchor == clock.at(2026, 1, 31))
    }

    @Test func oneOffDoneReturnsNil() {
        let r = ReminderInfo(fireDate: clock.at(2026, 10, 23))
        #expect(r.completing(occurrence: r.fireDate, now: clock.at(2026, 10, 23, 9, 1), calendar: cal) == nil)
    }

    @Test func doneAfterMissedDaysSkipsToNextFutureOccurrence() {
        let r = ReminderInfo(fireDate: clock.at(2026, 10, 1), repeatRule: .daily)
        let next = r.completing(occurrence: clock.at(2026, 10, 23), now: clock.at(2026, 10, 23, 9, 2), calendar: cal)!
        #expect(clock.parts(next.fireDate) == [2026, 10, 24, 9, 0])
    }

    @Test func staleDoneDoesNotSkipAnOccurrence() {
        let r = ReminderInfo(fireDate: clock.at(2026, 10, 24), repeatRule: .daily, anchor: clock.at(2026, 10, 1))
        let next = r.completing(occurrence: clock.at(2026, 10, 22), now: clock.at(2026, 10, 23, 12), calendar: cal)!
        #expect(next.fireDate == clock.at(2026, 10, 24))
    }

    @Test func doneClearsSnooze() {
        let r = ReminderInfo(fireDate: clock.at(2026, 10, 23), repeatRule: .daily, snoozedUntil: clock.at(2026, 10, 23, 10))
        let next = r.completing(occurrence: clock.at(2026, 10, 23), now: clock.at(2026, 10, 23, 10), calendar: cal)!
        #expect(next.snoozedUntil == nil)
        #expect(clock.parts(next.fireDate) == [2026, 10, 24, 9, 0])
    }

    @Test func anchorIsDroppedWhenFireDateLeavesTheSeries() {
        let moved = ReminderInfo(fireDate: clock.at(2026, 2, 15), repeatRule: .monthly, anchor: clock.at(2026, 1, 31))
        #expect(moved.seriesAnchor(calendar: cal) == clock.at(2026, 2, 15))
        let onSeries = ReminderInfo(fireDate: clock.at(2026, 2, 28), repeatRule: .monthly, anchor: clock.at(2026, 1, 31))
        #expect(onSeries.seriesAnchor(calendar: cal) == clock.at(2026, 1, 31))
    }

    struct AlertCase: Sendable, CustomTestStringConvertible {
        let name: String
        let reminder: ReminderInfo
        let expected: [Int]
        var testDescription: String { name }
    }

    static let alertCases: [AlertCase] = {
        let c = Clock("Asia/Baghdad")
        return [
            AlertCase(name: "one-off ahead", reminder: ReminderInfo(fireDate: c.at(2026, 10, 24)), expected: [2026, 10, 24, 9, 0]),
            AlertCase(name: "one-off passed", reminder: ReminderInfo(fireDate: c.at(2026, 10, 22)), expected: []),
            AlertCase(name: "one-off snoozed ahead",
                      reminder: ReminderInfo(fireDate: c.at(2026, 10, 23, 9), snoozedUntil: c.at(2026, 10, 23, 12, 10)),
                      expected: [2026, 10, 23, 12, 10]),
            AlertCase(name: "one-off snooze already rang",
                      reminder: ReminderInfo(fireDate: c.at(2026, 10, 23, 9), snoozedUntil: c.at(2026, 10, 23, 11)),
                      expected: []),
            AlertCase(name: "daily passed rolls to tomorrow",
                      reminder: ReminderInfo(fireDate: c.at(2026, 10, 20), repeatRule: .daily), expected: [2026, 10, 24, 9, 0]),
            AlertCase(name: "daily snoozed to tomorrow morning",
                      reminder: ReminderInfo(fireDate: c.at(2026, 10, 23), repeatRule: .daily, snoozedUntil: c.at(2026, 10, 24)),
                      expected: [2026, 10, 24, 9, 0]),
        ]
    }()

    @Test(arguments: alertCases)
    func nextAlert(_ c: AlertCase) {
        #expect(clock.parts(c.reminder.nextAlert(after: clock.at(2026, 10, 23, 12), calendar: cal)) == c.expected)
    }
}
