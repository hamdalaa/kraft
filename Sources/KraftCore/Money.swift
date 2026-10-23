import Foundation

import Synchronization

/// Any ISO 4217 currency, stored as its upper-case code ("USD", "EUR", "IQD") — the same single string
/// the old two-case enum wrote, so existing notes decode unchanged.
public struct Currency: Hashable, Codable, Sendable, RawRepresentable, Identifiable, CustomStringConvertible {
    public let code: String
    public var rawValue: String { code }
    public var id: String { code }
    public var description: String { code }

    public init(_ code: String) { self.code = code.uppercased() }
    public init?(rawValue: String) {
        let c = rawValue.trimmingCharacters(in: .whitespaces).uppercased()
        guard c.count == 3, c.allSatisfy({ $0.isASCII && $0.isLetter }) else { return nil }
        self.code = c
    }

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        guard let c = Currency(rawValue: raw) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "not a currency code: \(raw)"))
        }
        self = c
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(code)
    }

    public static let usd = Currency("USD"), eur = Currency("EUR"), gbp = Currency("GBP"), jpy = Currency("JPY")
    public static let iqd = Currency("IQD"), sar = Currency("SAR"), aed = Currency("AED"), egp = Currency("EGP")

    /// The pickers' short list: the world's most used currencies, then the Arab world's, then the rest by region.
    public static let common: [Currency] = [
        "USD", "EUR", "GBP", "JPY", "CNY", "INR", "CAD", "AUD", "CHF", "KRW", "SGD", "HKD", "SEK", "NOK", "DKK", "PLN",
        "TRY", "BRL", "MXN", "ZAR", "NGN", "KES", "PKR", "BDT", "IDR", "MYR", "PHP", "THB", "VND", "RUB", "UAH", "ILS",
        "SAR", "AED", "QAR", "KWD", "BHD", "OMR", "JOD", "EGP", "IQD", "LBP", "SYP", "MAD", "DZD", "TND", "LYD", "SDG", "YER",
    ].map(Currency.init)

    /// Every currency Foundation knows a name for.
    public static var all: [Currency] { Locale.commonISOCurrencyCodes.map(Currency.init) }

    /// The currency of the Mac's region, or US dollars when the region has none.
    public static var regional: Currency { Locale.current.currency.map { Currency($0.identifier) } ?? .usd }

    private static let preferredBox = Mutex<Currency?>(nil)

    /// The owner's default currency: what an amount means when no currency is written. Set by the app from
    /// Settings; until then it follows the Mac's region. Every parse takes it as a parameter, so tests pin their own.
    public static var preferred: Currency {
        get { preferredBox.withLock { $0 } ?? regional }
        set { preferredBox.withLock { $0 = newValue } }
    }

    /// "US Dollar", "دولار أمريكي" — the name in `locale`'s language.
    public func name(in locale: Locale) -> String { locale.localizedString(forCurrencyCode: code) ?? code }

    /// Digits after the decimal point this currency is written with (ISO 4217), 0 for currencies whose
    /// smallest units are not used day to day.
    public var fractionDigits: Int {
        if Self.wholeOnly.contains(code) { return 0 }
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = code
        return f.maximumFractionDigits
    }

    private static let wholeOnly: Set<String> = ["IQD", "LBP", "SYP", "IRR", "YER", "IDR", "VND", "KRW", "JPY", "CLP", "ISK", "UGX", "HUF"]
}

public struct Payment: Codable, Hashable, Sendable, Identifiable {
    public var id: UUID
    public var amount: Decimal
    public var date: Date

    public init(id: UUID = UUID(), amount: Decimal, date: Date) {
        self.id = id
        self.amount = amount
        self.date = date
    }
}

public struct MoneyInfo: Codable, Hashable, Sendable {
    public var person: String
    public var amount: Decimal
    public var currency: Currency
    public var dueDate: Date?
    public var payments: [Payment]

    public init(person: String, amount: Decimal, currency: Currency, dueDate: Date? = nil, payments: [Payment] = []) {
        self.person = person
        self.amount = amount
        self.currency = currency
        self.dueDate = dueDate
        self.payments = payments
    }

    public var paid: Decimal { payments.reduce(0) { $0 + $1.amount } }
    public var remaining: Decimal { max(0, amount - paid) }
    public var isSettled: Bool { amount > 0 && remaining == 0 }
    /// 0…1, for progress marks on the paper.
    public var progress: Double {
        guard amount > 0 else { return 0 }
        return min(1, NSDecimalNumber(decimal: paid / amount).doubleValue)
    }
}
