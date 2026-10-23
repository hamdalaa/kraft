import Foundation

/// How people write a currency next to an amount, in English and Arabic, worldwide.
///
/// A sign or code names one currency ("€", "SAR", "د.ع"). A word can name a family: "dollar" is US,
/// Canadian or Australian, "riyal" Saudi, Qatari or Omani. A family resolves to the owner's default
/// currency when that currency is in it ("$40" is CA$40 for someone in Canada), otherwise to the family's
/// usual member. Patterns are in `TextScanner`'s normalised form (Latin lower-case, أ/إ/آ → ا, ة → ه).
enum CurrencyWords {
    struct Entry {
        let pattern: String
        let currencies: [Currency]
    }

    private static func c(_ codes: String...) -> [Currency] { codes.map(Currency.init) }

    static let dollars = c("USD", "CAD", "AUD", "NZD", "SGD", "HKD")

    /// Written before or after the number.
    static let signs: [Entry] = [
        Entry(pattern: "us\\$", currencies: c("USD")),
        Entry(pattern: "ca\\$|c\\$", currencies: c("CAD")),
        Entry(pattern: "a\\$|au\\$", currencies: c("AUD")),
        Entry(pattern: "nz\\$", currencies: c("NZD")),
        Entry(pattern: "hk\\$", currencies: c("HKD")),
        Entry(pattern: "s\\$", currencies: c("SGD")),
        Entry(pattern: "mx\\$", currencies: c("MXN")),
        Entry(pattern: "r\\$", currencies: c("BRL")),
        Entry(pattern: "\\$", currencies: dollars),
        Entry(pattern: "€", currencies: c("EUR")),
        Entry(pattern: "£", currencies: c("GBP", "EGP")),
        Entry(pattern: "¥|￥", currencies: c("JPY", "CNY")),
        Entry(pattern: "₹", currencies: c("INR")),
        Entry(pattern: "₩", currencies: c("KRW")),
        Entry(pattern: "₺", currencies: c("TRY")),
        Entry(pattern: "₽", currencies: c("RUB")),
        Entry(pattern: "₦", currencies: c("NGN")),
        Entry(pattern: "₱", currencies: c("PHP")),
        Entry(pattern: "₪", currencies: c("ILS")),
        Entry(pattern: "₫", currencies: c("VND")),
        Entry(pattern: "฿", currencies: c("THB")),
        Entry(pattern: "₴", currencies: c("UAH")),
    ]

    /// ISO codes written as words ("40 eur", "SAR 40"). TRY is left out: "try 40" is English.
    static let codes: [Entry] = Currency.common
        .filter { $0.code != "TRY" }
        .map { Entry(pattern: $0.code.lowercased(), currencies: [$0]) }

    /// Words and Arabic abbreviations, written after the number.
    static let words: [Entry] = [
        Entry(pattern: "dollars?|bucks|دولار|دولارات|دولارا|دولر", currencies: dollars),
        Entry(pattern: "دولار امريكي", currencies: c("USD")),
        Entry(pattern: "euros?|يورو", currencies: c("EUR")),
        Entry(pattern: "pounds?|quid|باوند|استرليني|جنيه استرليني", currencies: c("GBP", "EGP", "SDG")),
        Entry(pattern: "جنيه|جنيهات|جنيها|ج\\.\\s?م", currencies: c("EGP", "SDG", "GBP")),
        Entry(pattern: "ج\\.\\s?س", currencies: c("SDG")),
        Entry(pattern: "yen|ين", currencies: c("JPY")),
        Entry(pattern: "yuan|rmb|يوان", currencies: c("CNY")),
        Entry(pattern: "rupees?|روبيه", currencies: c("INR", "PKR", "LKR", "NPR")),
        Entry(pattern: "won", currencies: c("KRW")),
        Entry(pattern: "liras?|ليره|ليرات", currencies: c("TRY", "LBP", "SYP")),
        Entry(pattern: "ل\\.\\s?ل", currencies: c("LBP")),
        Entry(pattern: "ل\\.\\s?س", currencies: c("SYP")),
        Entry(pattern: "riyals?|rials?|ريال|ريالات|ريالا", currencies: c("SAR", "QAR", "OMR", "YER")),
        Entry(pattern: "ر\\.\\s?س", currencies: c("SAR")),
        Entry(pattern: "ر\\.\\s?ق", currencies: c("QAR")),
        Entry(pattern: "ر\\.\\s?ع", currencies: c("OMR")),
        Entry(pattern: "ر\\.\\s?ي", currencies: c("YER")),
        Entry(pattern: "dirhams?|درهم|دراهم", currencies: c("AED", "MAD")),
        Entry(pattern: "د\\.\\s?م", currencies: c("MAD")),
        Entry(pattern: "dinars?|دينار|دنانير", currencies: c("IQD", "KWD", "JOD", "BHD", "LYD", "TND", "DZD")),
        Entry(pattern: "د\\.\\s?ع|د ع|ع\\.د", currencies: c("IQD")),
        Entry(pattern: "د\\.\\s?ك", currencies: c("KWD")),
        Entry(pattern: "د\\.\\s?ا", currencies: c("AED", "JOD")),
        Entry(pattern: "د\\.\\s?ب", currencies: c("BHD")),
        Entry(pattern: "د\\.\\s?ل", currencies: c("LYD")),
        Entry(pattern: "د\\.\\s?ت", currencies: c("TND")),
        Entry(pattern: "د\\.\\s?ج", currencies: c("DZD")),
        Entry(pattern: "francs?|فرنك", currencies: c("CHF")),
        Entry(pattern: "pesos?|بيزو", currencies: c("MXN", "PHP", "ARS", "COP", "CLP")),
        Entry(pattern: "rubles?|roubles?|روبل", currencies: c("RUB")),
        Entry(pattern: "reais|real", currencies: c("BRL")),
        Entry(pattern: "rand", currencies: c("ZAR")),
        Entry(pattern: "naira", currencies: c("NGN")),
        Entry(pattern: "shekels?|شيكل", currencies: c("ILS")),
        Entry(pattern: "baht", currencies: c("THB")),
        Entry(pattern: "ringgit", currencies: c("MYR")),
        Entry(pattern: "rupiah", currencies: c("IDR")),
        Entry(pattern: "taka", currencies: c("BDT")),
        Entry(pattern: "kronor|krona", currencies: c("SEK")),
        Entry(pattern: "kroner|krone", currencies: c("NOK", "DKK")),
        Entry(pattern: "zloty|zł", currencies: c("PLN")),
        Entry(pattern: "hryvnias?", currencies: c("UAH")),
        Entry(pattern: "lev|leva", currencies: c("BGN")),
        Entry(pattern: "toman|tomans|تومان", currencies: c("IRR")),
    ]

    /// Longest patterns first so "us$" wins over "$" and "دولار امريكي" over "دولار".
    private static func alternation(_ entries: [Entry]) -> String {
        Lex.alt(entries.flatMap { $0.pattern.split(separator: "|").map(String.init) }.sorted { $0.count > $1.count })
    }

    /// Signs anywhere; codes only as whole words ("eur 40", not the end of "europe").
    static let before = "(?:\(alternation(signs))|\(Lex.l)\(alternation(codes)))"
    static let after = alternation(signs + codes + words)

    /// The currency a matched sign, code or word names, for an owner whose default is `preferred`.
    static func resolve(_ text: String, preferred: Currency) -> Currency? {
        let t = text.trimmingCharacters(in: .whitespaces)
        for entry in signs + codes + words {
            let regex = NSRegularExpression.make("^(?:\(entry.pattern))$")
            guard regex.firstMatch(in: t, range: NSRange(t.startIndex..., in: t)) != nil else { continue }
            return entry.currencies.contains(preferred) ? preferred : entry.currencies.first
        }
        return nil
    }
}
