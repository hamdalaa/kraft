import Foundation

/// Six stickies covering every kind, in English and Arabic. Used by the first run and snapshot mode.
public enum SampleData {
    public static func stickies(now: Date = Date(), calendar: Calendar = .current) -> [Sticky] {
        let today = calendar.startOfDay(for: now)
        func day(_ offset: Int, hour: Int = 0) -> Date {
            let d = calendar.date(byAdding: .day, value: offset, to: today) ?? today
            return calendar.date(byAdding: .hour, value: hour, to: d) ?? d
        }
        let nextFriday = calendar.nextDate(after: now, matching: DateComponents(weekday: 6), matchingPolicy: .nextTime) ?? day(3)

        return [
            Sticky(
                kind: .owedToMe, title: "Ali owes me",
                money: MoneyInfo(person: "Ali", amount: 40, currency: .usd, dueDate: nextFriday,
                                 payments: [Payment(amount: 10, date: day(-2))]),
                style: PaperStyle(color: .mint, size: .medium, fastener: .tape, tilt: -2.2),
                createdAt: day(-5)
            ),
            Sticky(
                kind: .reminder, title: "الدواء", body: "الساعة ٩ صباحًا، كل يوم",
                reminder: ReminderInfo(fireDate: day(0, hour: 9), repeatRule: .daily),
                style: PaperStyle(color: .lemon, size: .medium, fastener: .pin, tilt: 1.8),
                createdAt: day(-1)
            ),
            Sticky(
                kind: .todo, title: "Groceries",
                checklist: [
                    ChecklistItem(text: "Milk"),
                    ChecklistItem(text: "Bread", isDone: true),
                    ChecklistItem(text: "Eggs"),
                    ChecklistItem(text: "Dates for Mum"),
                ],
                style: PaperStyle(color: .sky, size: .medium, ruling: .lines, tilt: -0.8),
                createdAt: day(0)
            ),
            Sticky(
                kind: .iOwe, title: "إيجار أحمد",
                money: MoneyInfo(person: "أحمد", amount: 150_000, currency: .iqd, dueDate: day(-1),
                                 payments: [Payment(amount: 150_000, date: day(-1))]),
                style: PaperStyle(color: .pink, size: .medium, fastener: .tape, tilt: 2.6),
                createdAt: day(-9)
            ),
            Sticky(
                kind: .note, title: "Gift idea",
                body: "The blue scarf from the souq — ask Sara which shop.",
                style: PaperStyle(color: .white, size: .large, ruling: .grid, fastener: .clip, tilt: -1.4),
                createdAt: day(-3)
            ),
            Sticky(
                kind: .bill, title: "Internet",
                money: MoneyInfo(person: "Earthlink", amount: 35_000, currency: .iqd, dueDate: day(2)),
                reminder: nil,
                style: PaperStyle(color: .peach, size: .small, tilt: 1.1),
                createdAt: day(-20)
            ),
        ]
    }
}
