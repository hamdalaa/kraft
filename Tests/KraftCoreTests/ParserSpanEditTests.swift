import Foundation
import Testing
@testable import KraftCore

@Suite struct ParserSpanTests {
    @Test func englishSpansPointAtTheWords() {
        let p = PF.parse("Ali owes me 40$ friday")
        #expect(p.spans.map(\.field) == [.person, .kind, .amount, .date])
        #expect(p.spans.map(\.text) == ["Ali", "owes me", "40$", "friday"])
    }

    @Test func arabicSpansMapBackOverHarakatAndIndicDigits() {
        let text = "ذكّرني بالدواء الساعة ٩ كل يومٍ"
        let p = PF.parse(text)
        #expect(p.title == "الدواء")
        #expect(p.spans.map(\.field) == [.kind, .time, .repeatRule])
        #expect(p.spans.map(\.text) == ["ذكّرني ب", "الساعة ٩", "كل يومٍ"])
        for span in p.spans { #expect(String(text[span.range]) == span.text) }
    }

    @Test func normalisation() {
        #expect(TextScanner("أنا مدين لأحمد ١٥٠ ألف").text == "انا مدين لاحمد 150 الف")
        #expect(TextScanner("غداً، بكرة").text == "غدا, بكره")
        #expect(TextScanner("Ali OWES me").text == "ali owes me")
        #expect(TextScanner("ـــالجمعة").text == "الجمعه")
    }

    @Test func directionFollowsTheText() {
        #expect(PF.parse("علي يطلبني ٤٠").direction == .rightToLeft)
        #expect(PF.parse("I owe Omar 5").direction == .leftToRight)
    }

    @Test func emptyAndWhitespace() {
        #expect(PF.parse("").kind == .note)
        #expect(PF.parse("   ").isEmpty)
    }
}

@Suite struct QuickEditsTests {
    @Test func forcedKindRereadsTheSentence() {
        let note = PF.parse("Ali owes me 40$ friday", kind: .note)
        #expect(note.title == "Ali owes me 40$ friday")
        #expect(note.amount == nil && note.date == nil)

        let reminder = PF.parse("Ali owes me 40$ friday", kind: .reminder)
        #expect(reminder.title == "Ali owes me 40$")
        #expect(reminder.date == PF.date(2026, 10, 23, 9))

        let bill = PF.parse("internet 35000", kind: .bill)
        #expect(bill.amount == 35_000 && bill.title == "Internet")
    }

    @Test func correctionsOverrideTheParse() {
        var edits = QuickEdits()
        edits.person = .set("Alia")
        edits.amount = .set(55)
        edits.currency = .iqd
        edits.day = .set(PF.date(2026, 11, 2, 15))
        let p = ParsedSticky.reading("Ali owes me 40$ friday", edits: edits, now: PF.now, calendar: PF.calendar)
        #expect(p.person == "Alia")
        #expect(p.title == "Alia owes me")
        #expect(p.amount == 55 && p.currency == .iqd)
        #expect(p.date == PF.date(2026, 11, 2))
    }

    @Test func timeEditKeepsTheDay() {
        var edits = QuickEdits()
        edits.time = .set(TimeOfDay(hour: 7, minute: 15))
        let p = ParsedSticky.reading("call mum tomorrow 6pm", edits: edits, now: PF.now, calendar: PF.calendar)
        #expect(p.date == PF.date(2026, 10, 22, 7, 15))
        #expect(p.hasTime)
    }

    @Test func removingTheDateClearsIt() {
        var edits = QuickEdits()
        edits.day = .removed
        let p = ParsedSticky.reading("call mum tomorrow 6pm", edits: edits, now: PF.now, calendar: PF.calendar)
        #expect(p.date == nil && !p.hasTime)
    }

    @Test func repeatEdit() {
        var edits = QuickEdits()
        edits.repeatRule = .weekly
        #expect(ParsedSticky.reading("gym 6pm", edits: edits, now: PF.now, calendar: PF.calendar).repeatRule == .weekly)
    }
}

@Suite struct MakeStickyTests {
    @Test func moneySticky() {
        let s = PF.parse("Ali owes me 40$ friday").makeSticky(now: PF.now, calendar: PF.calendar)
        #expect(s.kind == .owedToMe)
        #expect(s.money == MoneyInfo(person: "Ali", amount: 40, currency: .usd, dueDate: PF.date(2026, 10, 23)))
        #expect(s.reminder == nil)
    }

    @Test func reminderSticky() {
        let s = PF.parse("ذكرني بالدواء الساعة ٩ كل يوم").makeSticky(now: PF.now, calendar: PF.calendar)
        #expect(s.kind == .reminder && s.title == "الدواء")
        #expect(s.reminder == ReminderInfo(fireDate: PF.date(2026, 10, 22, 9), repeatRule: .daily))
    }

    @Test func billRingsInTheMorningOfItsDueDay() {
        let s = PF.parse("internet bill 35k on the 25th monthly").makeSticky(now: PF.now, calendar: PF.calendar)
        #expect(s.money?.dueDate == PF.date(2026, 10, 25))
        #expect(s.reminder == ReminderInfo(fireDate: PF.date(2026, 10, 25, 9), repeatRule: .monthly))
    }

    @Test func checklistSticky() {
        let s = PF.parse("buy milk, bread, eggs").makeSticky(now: PF.now)
        #expect(s.kind == .todo && s.checklist.map(\.text) == ["Milk", "Bread", "Eggs"])
        #expect(s.checklist.allSatisfy { !$0.isDone })
    }
}
