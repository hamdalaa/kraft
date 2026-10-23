import Foundation

public enum DigitStyle: String, Codable, CaseIterable, Sendable {
    case western, arabic
}

public enum MoneyFormat {
    /// "$40", "€12.50", "£8", "150,000 IQD", "40 SAR"; Arabic: "$40", "١٥٠٬٠٠٠ د.ع", "٤٠ ر.س" when `arabic` is true.
    /// Currencies with a well-known sign put it in front; the rest follow the number with their code (or Arabic
    /// abbreviation). Decimals show only when the amount has them, never past what the currency uses.
    public static func string(_ amount: Decimal, _ currency: Currency, arabic: Bool = false, digits: DigitStyle = .western) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = currency.fractionDigits
        f.locale = Locale(identifier: digits == .arabic ? "ar_IQ" : "en_US")
        let number = f.string(from: amount as NSDecimalNumber) ?? "\(amount)"
        if let sign = prefixSigns[currency.code] { return sign + number }
        if arabic, let short = arabicShort[currency.code] { return number + " " + short }
        return number + " " + currency.code
    }

    /// Signs people read the same everywhere, written before the number.
    static let prefixSigns: [String: String] = [
        "USD": "$", "EUR": "€", "GBP": "£", "JPY": "¥", "CNY": "¥", "INR": "₹", "KRW": "₩", "TRY": "₺",
        "RUB": "₽", "NGN": "₦", "PHP": "₱", "ILS": "₪", "VND": "₫", "THB": "฿", "UAH": "₴", "BRL": "R$",
        "CAD": "CA$", "AUD": "A$", "MXN": "MX$", "HKD": "HK$", "SGD": "S$",
    ]

    /// The abbreviations Arab readers write after the number.
    static let arabicShort: [String: String] = [
        "IQD": "د.ع", "SAR": "ر.س", "AED": "د.إ", "QAR": "ر.ق", "KWD": "د.ك", "BHD": "د.ب", "OMR": "ر.ع",
        "JOD": "د.أ", "EGP": "ج.م", "LBP": "ل.ل", "SYP": "ل.س", "MAD": "د.م", "DZD": "د.ج", "TND": "د.ت",
        "LYD": "د.ل", "SDG": "ج.س", "YER": "ر.ي",
    ]
}
