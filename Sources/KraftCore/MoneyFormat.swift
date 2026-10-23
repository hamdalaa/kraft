import Foundation

public enum DigitStyle: String, Codable, CaseIterable, Sendable {
    case western, arabic
}

public enum MoneyFormat {
    /// "$40", "150,000 IQD"; Arabic: "‎$40", "١٥٠٬٠٠٠ د.ع" when `arabic` is true.
    public static func string(_ amount: Decimal, _ currency: Currency, arabic: Bool = false, digits: DigitStyle = .western) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = currency == .usd ? 2 : 0
        f.locale = Locale(identifier: digits == .arabic ? "ar_IQ" : "en_US")
        let number = f.string(from: amount as NSDecimalNumber) ?? "\(amount)"
        switch currency {
        case .usd: return "$" + number
        case .iqd: return number + (arabic ? " د.ع" : " IQD")
        }
    }
}
