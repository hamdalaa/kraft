import Foundation
import Testing
@testable import KraftCore

/// Kraft is not only for Iraq: any currency can be written, read and stored.
@Suite struct CurrencyWorldTests {
    struct Case: CustomTestStringConvertible, Sendable {
        let text: String
        let preferred: String
        let amount: Decimal
        let code: String
        var testDescription: String { "\(text) [\(preferred)]" }
    }

    static let cases: [Case] = [
        Case(text: "Ali owes me €40", preferred: "USD", amount: 40, code: "EUR"),
        Case(text: "Ali owes me 40€", preferred: "USD", amount: 40, code: "EUR"),
        Case(text: "I owe Sam £12.50", preferred: "USD", amount: 12.5, code: "GBP"),
        Case(text: "Ali owes me 40 euros", preferred: "USD", amount: 40, code: "EUR"),
        Case(text: "I owe Kenji 3000 yen", preferred: "USD", amount: 3000, code: "JPY"),
        Case(text: "Priya owes me ₹500", preferred: "USD", amount: 500, code: "INR"),
        Case(text: "I owe Omar 200 SAR", preferred: "USD", amount: 200, code: "SAR"),
        Case(text: "I owe Omar AED 200", preferred: "USD", amount: 200, code: "AED"),
        Case(text: "Ali owes me 40 riyals", preferred: "USD", amount: 40, code: "SAR"),
        Case(text: "Ali owes me 40 riyals", preferred: "QAR", amount: 40, code: "QAR"),
        Case(text: "Ali owes me $40", preferred: "CAD", amount: 40, code: "CAD"),
        Case(text: "Ali owes me $40", preferred: "EUR", amount: 40, code: "USD"),
        Case(text: "Ali owes me 40", preferred: "EUR", amount: 40, code: "EUR"),
        Case(text: "owe mum 5k", preferred: "GBP", amount: 5000, code: "GBP"),
        Case(text: "علي يطلبني ٢٠٠ ريال", preferred: "USD", amount: 200, code: "SAR"),
        Case(text: "لي عند سارة ٥٠ درهم", preferred: "USD", amount: 50, code: "AED"),
        Case(text: "لي عند سارة ٥٠ درهم", preferred: "MAD", amount: 50, code: "MAD"),
        Case(text: "علي يطلبني ٣٠٠ جنيه", preferred: "USD", amount: 300, code: "EGP"),
        Case(text: "لي عند علي ١٠٠ يورو", preferred: "USD", amount: 100, code: "EUR"),
        Case(text: "لي عند علي ٥ دينار", preferred: "KWD", amount: 5, code: "KWD"),
        Case(text: "لي عند علي ٥٠٠ ليرة", preferred: "USD", amount: 500, code: "TRY"),
        Case(text: "لي عند علي ٥٠٠ ليرة", preferred: "LBP", amount: 500, code: "LBP"),
        Case(text: "علي يطلبني ٧٥ ر.س", preferred: "USD", amount: 75, code: "SAR"),
    ]

    @Test(arguments: cases) func readsAnyCurrency(_ c: Case) {
        let p = PF.parse(c.text, currency: Currency(c.preferred))
        #expect(p.amount == c.amount)
        #expect(p.currency?.code == c.code)
    }

    @Test func tryIsAWordNotTurkishLira() {
        let p = PF.parse("try 40 pushups every day", currency: .usd)
        #expect(p.currency == nil)
    }

    @Test(arguments: [
        ("EUR", Decimal(12.5), false, "€12.5"), ("EUR", Decimal(40), false, "€40"), ("GBP", Decimal(8), false, "£8"),
        ("SAR", Decimal(40), false, "40 SAR"), ("SAR", Decimal(40), true, "40 ر.س"), ("IQD", Decimal(150_000), true, "150,000 د.ع"),
        ("JPY", Decimal(3000), false, "¥3,000"), ("KWD", Decimal(1.25), false, "1.25 KWD"), ("USD", Decimal(40), true, "$40"),
    ])
    func formats(_ code: String, _ amount: Decimal, _ arabic: Bool, _ expected: String) {
        #expect(MoneyFormat.string(amount, Currency(code), arabic: arabic) == expected)
    }

    @Test func oldNotesStillDecode() throws {
        let data = Data(#"{"person":"Ali","amount":40,"currency":"IQD","payments":[]}"#.utf8)
        let money = try JSONDecoder().decode(MoneyInfo.self, from: data)
        #expect(money.currency == .iqd)
        let euro = try JSONDecoder().decode(MoneyInfo.self, from: try JSONEncoder().encode(MoneyInfo(person: "Ali", amount: 40, currency: .eur)))
        #expect(euro.currency.code == "EUR")
    }

    @Test func rejectsNonCodes() {
        #expect(Currency(rawValue: "dollars") == nil)
        #expect(Currency(rawValue: "eur") == .eur)
    }
}
