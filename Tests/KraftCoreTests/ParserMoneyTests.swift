import Foundation
import Testing
@testable import KraftCore

@Suite struct ParserMoneyTests {
    static let englishCases: [Expect] = [
        Expect(text: "Ali owes me 40$ friday", kind: .owedToMe, title: "Ali owes me", person: "Ali", amount: 40,
               currency: .usd, date: PF.date(2026, 10, 23), hasTime: false),
        Expect(text: "Ali owes me $40", kind: .owedToMe, person: "Ali", amount: 40, currency: .usd, date: .some(nil)),
        Expect(text: "I owe Omar 150k IQD", kind: .iOwe, title: "I owe Omar", person: "Omar", amount: 150_000, currency: .iqd),
        Expect(text: "I owe Omar 150,000 dinar by the 1st", kind: .iOwe, person: "Omar", amount: 150_000, currency: .iqd,
               date: PF.date(2026, 11, 1)),
        Expect(text: "Sara owes me 25 dollars for lunch", kind: .owedToMe, body: "lunch", person: "Sara", amount: 25, currency: .usd),
        Expect(text: "my brother Karim owes me 300 USD next week", kind: .owedToMe, person: "brother Karim", amount: 300,
               currency: .usd, date: PF.date(2026, 10, 28)),
        Expect(text: "lent Zaid 20000", kind: .owedToMe, person: "Zaid", amount: 20_000, currency: .iqd),
        Expect(text: "Omar lent me 50$", kind: .iOwe, person: "Omar", amount: 50, currency: .usd),
        Expect(text: "borrowed 100$ from Huda", kind: .note), // no phrasing we read: stays a note
        Expect(text: "I borrowed from Huda 100$ on 15/11", kind: .iOwe, person: "Huda", amount: 100, date: PF.date(2026, 11, 15)),
        Expect(text: "owe mum 5k", kind: .iOwe, person: "mum", amount: 5000, currency: .iqd),
        Expect(text: "Ali owes me", kind: .owedToMe, title: "Ali owes me", person: "Ali"),
        Expect(text: "Ali owes me 12.5$ tomorrow 6pm", kind: .owedToMe, amount: 12.5, date: PF.date(2026, 10, 22, 18), hasTime: true),
        Expect(text: "Ali owes me 1.5 million IQD", kind: .owedToMe, amount: 1_500_000, currency: .iqd),
    ]

    static let arabicCases: [Expect] = [
        Expect(text: "أنا مدين لأحمد ١٥٠ ألف", kind: .iOwe, title: "مدين لأحمد", person: "أحمد", amount: 150_000, currency: .iqd),
        Expect(text: "علي يطلبني ٤٠ دولار الجمعة", kind: .iOwe, title: "مدين لعلي", person: "علي", amount: 40, currency: .usd,
               date: PF.date(2026, 10, 23)),
        Expect(text: "لي عند علي ٤٠ دولار", kind: .owedToMe, title: "لي عند علي", person: "علي", amount: 40, currency: .usd),
        Expect(text: "علي مدين لي ٢٥ ألف دينار", kind: .owedToMe, person: "علي", amount: 25_000, currency: .iqd),
        Expect(text: "أطلب حسين ١٠ آلاف بكرة", kind: .owedToMe, person: "حسين", amount: 10_000, currency: .iqd,
               date: PF.date(2026, 10, 22)),
        Expect(text: "لأحمد عندي ٥٠ ألف", kind: .iOwe, person: "أحمد", amount: 50_000, currency: .iqd),
        Expect(text: "أحمد له عندي ٢٠$", kind: .iOwe, person: "أحمد", amount: 20, currency: .usd),
        Expect(text: "استلفت من خالي ١٠٠ دولار أول الشهر", kind: .iOwe, person: "خالي", amount: 100, currency: .usd,
               date: PF.date(2026, 11, 1)),
        Expect(text: "سلفت مصطفى ٧٥٬٠٠٠ د.ع", kind: .owedToMe, person: "مصطفى", amount: 75_000, currency: .iqd),
        Expect(text: "أبو علي يطلبني ألفين", kind: .iOwe, person: "أبو علي", amount: 2000, currency: .iqd),
        Expect(text: "علي يريد مني ١٥ دولار باچر", kind: .iOwe, person: "علي", amount: 15, date: PF.date(2026, 10, 22)),
        Expect(text: "اطلب بيتزا", kind: .note), // "order a pizza": no amount, not a debt
    ]

    static let billsCases: [Expect] = [
        Expect(text: "every month internet 35000 IQD", kind: .bill, title: "Internet", amount: 35_000, currency: .iqd,
               date: PF.date(2026, 11, 21), repeatRule: .monthly),
        Expect(text: "internet bill 35k on the 25th", kind: .bill, title: "Internet bill", amount: 35_000, date: PF.date(2026, 10, 25)),
        Expect(text: "netflix 10$ monthly", kind: .bill, title: "Netflix", amount: 10, currency: .usd, repeatRule: .monthly),
        Expect(text: "اشتراك المولدة ٤٠ ألف شهريًا", kind: .bill, title: "اشتراك المولدة", amount: 40_000, currency: .iqd, repeatRule: .monthly),
        Expect(text: "كل شهر انترنت ٣٥ الف يوم ٥", kind: .bill, title: "انترنت", amount: 35_000, date: PF.date(2026, 11, 5),
               repeatRule: .monthly),
        Expect(text: "every day drink 8 glasses of water", kind: .reminder, repeatRule: .daily),
    ]

    @Test(arguments: englishCases) func english(_ e: Expect) { check(e) }
    @Test(arguments: arabicCases) func arabic(_ e: Expect) { check(e) }
    @Test(arguments: billsCases) func bills(_ e: Expect) { check(e) }

    @Test func thousandsMeanDinarsSmallSumsMeanDollars() {
        #expect(Currency.default(for: 40) == .usd)
        #expect(Currency.default(for: 150_000) == .iqd)
    }
}
