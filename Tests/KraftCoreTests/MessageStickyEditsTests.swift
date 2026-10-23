import Foundation
import Testing
@testable import KraftCore

private let utc: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "UTC")!
    return c
}()

private func date(_ y: Int, _ m: Int, _ d: Int, hour: Int = 0, minute: Int = 0) -> Date {
    utc.date(from: DateComponents(year: y, month: m, day: d, hour: hour, minute: minute))!
}

@Suite struct ChecklistEditTests {
    let items = [ChecklistItem(text: "Milk"), ChecklistItem(text: "Bread"), ChecklistItem(text: "Eggs")]

    @Test func returnInsertsAfterTheCurrentItem() {
        let (list, id) = StickyEdits.insertItem(after: items[0].id, in: items)
        #expect(list.map(\.text) == ["Milk", "", "Bread", "Eggs"])
        #expect(list[1].id == id)
    }

    @Test func insertWithoutAnchorAppends() {
        let (list, id) = StickyEdits.insertItem(after: nil, in: items)
        #expect(list.last?.id == id)
        #expect(list.count == 4)
    }

    @Test func removingFocusesThePreviousItem() {
        let (list, focus) = StickyEdits.removeItem(items[1].id, from: items)
        #expect(list.map(\.text) == ["Milk", "Eggs"])
        #expect(focus == items[0].id)
    }

    @Test func removingTheFirstFocusesTheNext() {
        let (list, focus) = StickyEdits.removeItem(items[0].id, from: items)
        #expect(focus == items[1].id)
        #expect(list.count == 2)
        #expect(StickyEdits.removeItem(items[0].id, from: [items[0]]).1 == nil)
    }

    @Test func dragMovesToTheTargetSlot() {
        #expect(StickyEdits.moveItem(items[2].id, to: items[0].id, in: items).map(\.text) == ["Eggs", "Milk", "Bread"])
        #expect(StickyEdits.moveItem(items[0].id, to: items[2].id, in: items).map(\.text) == ["Bread", "Eggs", "Milk"])
        #expect(StickyEdits.moveItem(items[1].id, to: items[1].id, in: items) == items)
    }
}

@Suite struct KindSwitchTests {
    let now = date(2026, 10, 23, hour: 10, minute: 20)

    @Test func noteLinesBecomeChecklistItems() {
        let note = Sticky(kind: .note, title: "Shop", body: "Milk\n  Bread \n\nEggs")
        let todo = StickyEdits.switchKind(note, to: .todo, now: now, calendar: utc)
        #expect(todo.checklist.map(\.text) == ["Milk", "Bread", "Eggs"])
        #expect(todo.body.isEmpty)
    }

    @Test func checklistBecomesNoteLines() {
        let todo = Sticky(kind: .todo, checklist: [ChecklistItem(text: "Milk"), ChecklistItem(text: ""), ChecklistItem(text: "Eggs")])
        let note = StickyEdits.switchKind(todo, to: .note, now: now, calendar: utc)
        #expect(note.body == "Milk\nEggs")
        #expect(note.checklist.isEmpty)
    }

    @Test func reminderGetsTheNextWholeHourAndIsDroppedWhenLeaving() {
        let reminder = StickyEdits.switchKind(Sticky(kind: .note), to: .reminder, now: now, calendar: utc)
        #expect(reminder.reminder?.fireDate == date(2026, 10, 23, hour: 11))
        #expect(StickyEdits.switchKind(reminder, to: .note, now: now, calendar: utc).reminder == nil)
    }

    @Test func moneyIsKeptBetweenMoneyKindsAndDroppedOtherwise() {
        let owed = StickyEdits.switchKind(Sticky(kind: .note), to: .owedToMe, now: now, calendar: utc)
        #expect(owed.money == MoneyInfo(person: "", amount: 0, currency: .iqd))
        var withAmount = owed
        withAmount.money?.amount = 40
        #expect(StickyEdits.switchKind(withAmount, to: .iOwe, now: now, calendar: utc).money?.amount == 40)
        #expect(StickyEdits.switchKind(withAmount, to: .todo, now: now, calendar: utc).money == nil)
    }

    @Test func becomingABillMovesThePastDueDayForward() {
        var s = Sticky(kind: .owedToMe, money: MoneyInfo(person: "", amount: 1, currency: .usd, dueDate: date(2026, 10, 5)))
        s = StickyEdits.switchKind(s, to: .bill, now: now, calendar: utc)
        #expect(s.money?.dueDate == date(2026, 11, 5))
    }

    @Test func sameKindIsUnchanged() {
        let s = Sticky(kind: .note, body: "x")
        #expect(StickyEdits.switchKind(s, to: .note) == s)
    }
}

@Suite struct MoneyEditTests {
    let money = MoneyInfo(person: "Ali", amount: 40, currency: .usd)

    @Test func paymentsAddUpToSettled() {
        var m = StickyEdits.addPayment(10, on: .now, to: money)
        #expect(m.remaining == 30)
        m = StickyEdits.addPayment(m.remaining, on: .now, to: m)
        #expect(m.isSettled)
        #expect(m.payments.count == 2)
    }

    @Test func zeroOrNegativePaymentsAreIgnored() {
        #expect(StickyEdits.addPayment(0, on: .now, to: money) == money)
        #expect(StickyEdits.addPayment(-5, on: .now, to: money) == money)
    }

    @Test func removingAPaymentReopensTheDebt() {
        let paid = StickyEdits.addPayment(40, on: .now, to: money)
        let reopened = StickyEdits.removePayment(paid.payments[0].id, from: paid)
        #expect(!reopened.isSettled)
        #expect(reopened.remaining == 40)
    }

    @Test(arguments: [
        ("150,000", Decimal(150_000)), ("١٥٠٬٠٠٠", Decimal(150_000)), ("12.5", Decimal(string: "12.5")!),
        ("١٢٫٥", Decimal(string: "12.5")!), ("۴۰", Decimal(40)), (" 40 ", Decimal(40)), ("1 000", Decimal(1000)),
    ])
    func parsesWesternAndArabicDigits(text: String, expected: Decimal) {
        #expect(StickyEdits.parseAmount(text) == expected)
    }

    @Test(arguments: ["", ".", "abc", "12$", "1.2.3", "-5"])
    func rejectsNonNumbers(text: String) {
        #expect(StickyEdits.parseAmount(text) == nil)
    }
}

@Suite struct BillDueTests {
    @Test func laterThisMonth() {
        #expect(StickyEdits.billDue(day: 25, after: date(2026, 10, 23, hour: 9), calendar: utc) == date(2026, 10, 25))
    }

    @Test func todayCounts() {
        #expect(StickyEdits.billDue(day: 23, after: date(2026, 10, 23, hour: 22), calendar: utc) == date(2026, 10, 23))
    }

    @Test func passedRollsToNextMonth() {
        #expect(StickyEdits.billDue(day: 5, after: date(2026, 10, 23), calendar: utc) == date(2026, 11, 5))
    }

    @Test func clampsToShortMonths() {
        #expect(StickyEdits.billDue(day: 31, after: date(2026, 2, 10), calendar: utc) == date(2026, 2, 28))
        #expect(StickyEdits.billDue(day: 31, after: date(2026, 4, 3), calendar: utc) == date(2026, 4, 30))
    }
}

@Suite struct DuplicateTests {
    @Test func copyGetsFreshIdentity() {
        let original = Sticky(kind: .todo, title: "Groceries", checklist: [ChecklistItem(text: "Milk", isDone: true)],
                              isDone: true, completedAt: .now, isOnDesktop: true, desktopOrigin: DesktopPoint(x: 1, y: 2),
                              createdAt: .distantPast)
        let now = Date()
        let copy = StickyEdits.duplicate(original, now: now)
        #expect(copy.id != original.id)
        #expect(copy.checklist.map(\.text) == ["Milk"])
        #expect(copy.checklist[0].isDone)
        #expect(copy.checklist[0].id != original.checklist[0].id)
        #expect(!copy.isDone && copy.completedAt == nil)
        #expect(!copy.isOnDesktop && copy.desktopOrigin == nil)
        #expect(copy.createdAt == now)
        #expect(copy.title == original.title && copy.style == original.style)
    }
}
