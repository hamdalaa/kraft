import Foundation
import Testing
@testable import KraftCore

@Suite struct SnoozeTests {
    struct Case: Sendable, CustomTestStringConvertible {
        let name: String
        let zone: String
        let option: SnoozeOption
        let now: [Int]
        let expected: [Int]
        var testDescription: String { name }
    }

    static let cases: [Case] = [
        Case(name: "10 min", zone: "Asia/Baghdad", option: .tenMinutes, now: [2026, 10, 23, 9, 55], expected: [2026, 10, 23, 10, 5]),
        Case(name: "1 h across midnight", zone: "Asia/Baghdad", option: .oneHour, now: [2026, 10, 23, 23, 30], expected: [2026, 10, 24, 0, 30]),
        Case(name: "tomorrow from the evening", zone: "Asia/Baghdad", option: .tomorrow, now: [2026, 10, 23, 21, 0], expected: [2026, 10, 24, 9, 0]),
        Case(name: "tomorrow just after midnight is the next calendar day", zone: "Asia/Baghdad", option: .tomorrow,
             now: [2026, 10, 24, 0, 30], expected: [2026, 10, 25, 9, 0]),
        Case(name: "tomorrow onto the London fall-back day", zone: "Europe/London", option: .tomorrow,
             now: [2026, 10, 24, 22, 0], expected: [2026, 10, 25, 9, 0]),
        Case(name: "tomorrow onto the New York spring-forward day", zone: "America/New_York", option: .tomorrow,
             now: [2026, 3, 7, 22, 0], expected: [2026, 3, 8, 9, 0]),
        Case(name: "1 h during the London fall-back repeats the hour", zone: "Europe/London", option: .oneHour,
             now: [2026, 10, 25, 0, 30], expected: [2026, 10, 25, 1, 30]),
    ]

    @Test(arguments: cases)
    func target(_ c: Case) {
        let clock = Clock(c.zone)
        let n = c.now
        let t = c.option.target(from: clock.at(n[0], n[1], n[2], n[3], n[4]), calendar: clock.calendar)
        #expect(clock.parts(t) == c.expected)
    }
}

@Suite struct DueAlertTests {
    let clock = Clock("Asia/Baghdad")

    @Test func billRingsAtNineOnTheDueDay() {
        let due = clock.at(2026, 10, 25, 0)
        #expect(clock.parts(DueAlert.next(forDue: due, after: clock.at(2026, 10, 23, 12), calendar: clock.calendar)) == [2026, 10, 25, 9, 0])
        // A due date saved with a time of day still rings that morning.
        let evening = clock.at(2026, 10, 25, 18)
        #expect(clock.parts(DueAlert.next(forDue: evening, after: clock.at(2026, 10, 23, 12), calendar: clock.calendar)) == [2026, 10, 25, 9, 0])
    }

    @Test func noAlertOnceTheMorningHasPassed() {
        #expect(DueAlert.next(forDue: clock.at(2026, 10, 25, 0), after: clock.at(2026, 10, 25, 9, 1), calendar: clock.calendar) == nil)
        #expect(DueAlert.next(forDue: clock.at(2026, 10, 20, 0), after: clock.at(2026, 10, 23, 12), calendar: clock.calendar) == nil)
    }

    @Test func dueMorningOnDSTDay() {
        let london = Clock("Europe/London")
        #expect(london.parts(DueAlert.morning(of: london.at(2026, 3, 29, 0), calendar: london.calendar)) == [2026, 3, 29, 9, 0])
    }
}

@Suite struct AlertPlannerTests {
    let clock = Clock("Asia/Baghdad")
    var now: Date { clock.at(2026, 10, 23, 12) }

    func plan(_ s: [Sticky]) -> [PlannedAlert] { AlertPlanner.plan(s, now: now, calendar: clock.calendar) }

    @Test func samplesScheduleReminderAndOpenMoneyOnly() {
        let samples = SampleData.stickies(now: now, calendar: clock.calendar)
        let planned = plan(samples)
        let kinds = planned.compactMap { p in samples.first { $0.id == p.id }?.kind }
        // Daily medicine (tomorrow 09:00), Ali on Friday, Internet bill in two days. Settled rent + notes: nothing.
        #expect(Set(kinds) == [.reminder, .owedToMe, .bill])
        #expect(Set(planned.map(\.id)).count == planned.count)
        #expect(planned.map(\.date) == planned.map(\.date).sorted())
        let medicine = planned.first { p in samples.first { $0.id == p.id }?.kind == .reminder }!
        #expect(clock.parts(medicine.date) == [2026, 10, 24, 9, 0])
    }

    @Test func finishedDeletedAndPlainNotesAreSilent() {
        let future = ReminderInfo(fireDate: clock.at(2026, 10, 24))
        let done = Sticky(kind: .reminder, reminder: future, isDone: true)
        let deleted = Sticky(kind: .reminder, reminder: future, deletedAt: now)
        let note = Sticky(kind: .note, title: "Gift idea")
        let paid = Sticky(kind: .owedToMe, money: MoneyInfo(person: "Ali", amount: 10, currency: .usd, dueDate: clock.at(2026, 10, 25),
                                                         payments: [Payment(amount: 10, date: now)]))
        #expect(plan([done, deleted, note, paid]).isEmpty)
        #expect(!AlertPlanner.needsPermission([done, deleted, note, paid], now: now, calendar: clock.calendar))
        #expect(AlertPlanner.needsPermission([Sticky(kind: .reminder, reminder: future)], now: now, calendar: clock.calendar))
    }

    @Test func reminderWinsOverMoneyDueDate() {
        let s = Sticky(kind: .bill, money: MoneyInfo(person: "Earthlink", amount: 35_000, currency: .iqd, dueDate: clock.at(2026, 10, 30, 0)),
                       reminder: ReminderInfo(fireDate: clock.at(2026, 10, 28, 18)))
        #expect(clock.parts(plan([s]).first?.date) == [2026, 10, 28, 18, 0])
    }

    @Test func snoozingABillGivesItAOneOffReminder() {
        let bill = Sticky(kind: .bill, money: MoneyInfo(person: "Earthlink", amount: 35_000, currency: .iqd, dueDate: clock.at(2026, 10, 23, 0)))
        let snoozed = bill.snoozed(.oneHour, now: now, calendar: clock.calendar)
        #expect(snoozed.reminder?.repeatRule == .never)
        #expect(clock.parts(snoozed.reminder?.fireDate) == [2026, 10, 23, 9, 0])
        #expect(clock.parts(plan([snoozed]).first?.date) == [2026, 10, 23, 13, 0])
        // Once the snooze has rung, it stays quiet.
        #expect(AlertPlanner.alertDate(for: snoozed, now: clock.at(2026, 10, 23, 13, 1), calendar: clock.calendar) == nil)
    }

    @Test func doneOnRepeatingAdvancesAndOnOneOffFinishes() {
        let daily = Sticky(kind: .reminder, title: "الدواء", reminder: ReminderInfo(fireDate: clock.at(2026, 10, 23), repeatRule: .daily))
        let advanced = daily.completingAlert(occurrence: clock.at(2026, 10, 23), now: now, calendar: clock.calendar)
        #expect(!advanced.isDone)
        #expect(clock.parts(advanced.reminder?.fireDate) == [2026, 10, 24, 9, 0])

        let once = Sticky(kind: .todo, reminder: ReminderInfo(fireDate: clock.at(2026, 10, 23, 11)))
        let finished = once.completingAlert(occurrence: clock.at(2026, 10, 23, 11), now: now, calendar: clock.calendar)
        #expect(finished.isDone && finished.completedAt == now)
        #expect(plan([finished]).isEmpty)

        let bill = Sticky(kind: .bill, money: MoneyInfo(person: "Earthlink", amount: 35_000, currency: .iqd, dueDate: clock.at(2026, 10, 23, 0)))
        #expect(bill.completingAlert(occurrence: clock.at(2026, 10, 23, 9), now: now, calendar: clock.calendar).isFinished)
    }

    @Test func oldRecordsWithoutNewFieldsStillDecode() throws {
        let json = #"{"fireDate": 800000000, "repeatRule": "weekly"}"#
        let r = try JSONDecoder().decode(ReminderInfo.self, from: Data(json.utf8))
        #expect(r.repeatRule == .weekly && r.snoozedUntil == nil && r.anchor == nil)
    }
}

@Suite struct AlertCopyTests {
    @Test func arabicReminderStaysArabic() {
        let s = Sticky(kind: .reminder, title: "الدواء", body: "الساعة ٩ صباحًا،\nكل يوم",
                       reminder: ReminderInfo(fireDate: .now, repeatRule: .daily))
        let c = AlertCopy.make(for: s)
        #expect(c.isArabic)
        #expect(c.title == "الدواء")
        #expect(c.body == "الساعة ٩ صباحًا، كل يوم")
    }

    @Test func englishMoneyLines() {
        let owed = Sticky(kind: .owedToMe, title: "Ali owes me",
                          money: MoneyInfo(person: "Ali", amount: 40, currency: .usd, payments: [Payment(amount: 10, date: .now)]))
        #expect(AlertCopy.make(for: owed).body == "Ali owes you $30, due today.")
        let bill = Sticky(kind: .bill, title: "Internet", money: MoneyInfo(person: "Earthlink", amount: 35_000, currency: .iqd))
        #expect(AlertCopy.make(for: bill).body == "Earthlink: 35,000 IQD due today.")
        let mine = Sticky(kind: .iOwe, money: MoneyInfo(person: "Sara", amount: 5, currency: .usd))
        #expect(AlertCopy.make(for: mine).title == "You owe")
        #expect(AlertCopy.make(for: mine).body == "You owe Sara $5, due today.")
    }

    @Test func arabicMoneyLinesUseArabicDigitsAndIsolates() {
        let rent = Sticky(kind: .iOwe, title: "إيجار أحمد", money: MoneyInfo(person: "أحمد", amount: 150_000, currency: .iqd))
        let c = AlertCopy.make(for: rent)
        #expect(c.isArabic)
        #expect(c.body == "عليك لـ\u{2068}أحمد\u{2069} مبلغ \u{2068}١٥٠٬٠٠٠ د.ع\u{2069} يُستحق اليوم.")
        let bill = Sticky(kind: .bill, title: "الكهرباء", money: MoneyInfo(person: "", amount: 25_000, currency: .iqd))
        #expect(AlertCopy.make(for: bill).body == "فاتورة بمبلغ \u{2068}٢٥٬٠٠٠ د.ع\u{2069} تُستحق اليوم.")
    }

    @Test func fallbacksForBareStickies() {
        let todo = Sticky(kind: .todo, checklist: [ChecklistItem(text: "Milk"), ChecklistItem(text: "Bread", isDone: true), ChecklistItem(text: "Eggs")],
                          reminder: ReminderInfo(fireDate: .now))
        #expect(AlertCopy.make(for: todo) == AlertCopy(title: "To-do", body: "Milk, Eggs", isArabic: false))
        let arabicTodo = Sticky(kind: .todo, title: "السوق", checklist: [ChecklistItem(text: "حليب"), ChecklistItem(text: "تمر")],
                                reminder: ReminderInfo(fireDate: .now))
        #expect(AlertCopy.make(for: arabicTodo).body == "حليب، تمر")
        let bare = Sticky(kind: .reminder, reminder: ReminderInfo(fireDate: .now, repeatRule: .weekly))
        #expect(AlertCopy.make(for: bare) == AlertCopy(title: "Reminder", body: "Every week", isArabic: false))
    }

    @Test func longBodiesAreTrimmed() {
        let s = Sticky(kind: .note, title: "Long", body: String(repeating: "word ", count: 100), reminder: ReminderInfo(fireDate: .now))
        let body = AlertCopy.make(for: s).body
        #expect(body.count == AlertCopy.bodyLimit)
        #expect(body.hasSuffix("…"))
    }

    @Test func actionTitlesFollowTheNoteLanguage() {
        #expect(AlertCopy.actionTitles(arabic: false).done == "Done")
        #expect(AlertCopy.actionTitles(arabic: true).tomorrow == "غدًا")
    }
}
