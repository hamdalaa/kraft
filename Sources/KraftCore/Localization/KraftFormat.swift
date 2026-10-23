import Foundation

/// How the UI writes numbers and dates: the UI language plus the owner's digit choice
/// (Western 123 by default in both languages, Arabic-Indic ١٢٣ on request).
public struct KraftFormat: Sendable, Equatable {
    /// UI language code, `"en"` or `"ar"`.
    public var language: String
    public var digits: DigitStyle
    /// Region for month names and time style (`"IQ"` → «تشرين الأول»); nil for the bare language.
    public var region: String?
    public var calendar: Calendar

    public init(language: String = "en", digits: DigitStyle = .western, region: String? = Locale.current.region?.identifier,
                calendar: Calendar = .current) {
        self.language = language
        self.digits = digits
        self.region = region
        self.calendar = calendar
    }

    public var isArabic: Bool { language.hasPrefix("ar") }
    public var isRightToLeft: Bool { Locale.Language(identifier: language).characterDirection == .rightToLeft }

    /// `ar_IQ@numbers=latn`, `en_IQ@numbers=arab`: the numbering system follows `digits`, not the language.
    public var locale: Locale {
        var id = language
        if let region, !region.isEmpty { id += "_" + region }
        id += "@numbers=" + (digits == .arabic ? "arab" : "latn")
        return Locale(identifier: id)
    }

    // MARK: Numbers

    /// Counts and amounts with grouping: "1,250" / "١٬٢٥٠".
    public func number(_ n: Int) -> String { n.formatted(.number.locale(locale)) }

    /// Money in the UI language: "$40", "150,000 IQD", "١٥٠٬٠٠٠ د.ع".
    public func money(_ amount: Decimal, _ currency: Currency) -> String {
        MoneyFormat.string(amount, currency, arabic: isArabic, digits: digits)
    }

    /// Money written on a note in its own language (`arabic` = the note's script), digits as chosen.
    public func money(_ amount: Decimal, _ currency: Currency, arabic: Bool) -> String {
        MoneyFormat.string(amount, currency, arabic: arabic, digits: digits)
    }

    // MARK: Dates

    public func date(_ date: Date, _ style: Date.FormatStyle) -> String {
        var s = style.locale(locale)
        s.calendar = calendar
        s.timeZone = calendar.timeZone
        return date.formatted(s)
    }

    /// Arabic has no short weekday names (ICU's «جمعة» reads clipped), so Arabic always writes «الجمعة».
    private var shortWeekday: Date.FormatStyle.Symbol.Weekday { isArabic ? .wide : .abbreviated }

    /// "Fri" / «الجمعة».
    public func weekday(_ d: Date) -> String { date(d, Date.FormatStyle().weekday(shortWeekday)) }
    /// "Friday" / «الجمعة».
    public func weekdayWide(_ d: Date) -> String { date(d, Date.FormatStyle().weekday(.wide)) }
    /// "25 Oct" / «٢٥ تشرين الأول».
    public func dayMonth(_ d: Date) -> String { date(d, Date.FormatStyle().day().month(.abbreviated)) }
    /// "Fri 25 Oct".
    public func weekdayDayMonth(_ d: Date) -> String { date(d, Date.FormatStyle().weekday(shortWeekday).day().month(.abbreviated)) }
    /// "Friday, 25 October".
    public func longDay(_ d: Date) -> String { date(d, Date.FormatStyle().weekday(.wide).day().month(.wide)) }
    /// "9:00 AM" / «٩:٠٠ ص».
    public func time(_ d: Date) -> String { date(d, Date.FormatStyle(date: .omitted, time: .shortened)) }
    /// "Fri 25 Oct, 9:00 AM".
    public func dayAndTime(_ d: Date) -> String {
        date(d, Date.FormatStyle().weekday(shortWeekday).day().month(.abbreviated).hour().minute())
    }

    // MARK: Digits in free text

    /// Rewrites the digits of an already-built string ("⌘1", typed amounts) in the chosen style.
    public static func applying(_ digits: DigitStyle, to text: String) -> String {
        var out = String.UnicodeScalarView()
        for s in text.unicodeScalars {
            switch (digits, s.value) {
            case (.arabic, 0x30...0x39): out.append(Unicode.Scalar(s.value - 0x30 + 0x0660)!)
            case (.western, 0x0660...0x0669): out.append(Unicode.Scalar(s.value - 0x0660 + 0x30)!)
            case (.western, 0x06F0...0x06F9): out.append(Unicode.Scalar(s.value - 0x06F0 + 0x30)!)
            default: out.append(s)
            }
        }
        return String(out)
    }

    public func digits(in text: String) -> String { Self.applying(digits, to: text) }
}

/// CLDR plural categories, so counts read naturally in Arabic («ملصق واحد», «ملصقان», «٣ ملصقات», «١١ ملصقًا»).
public enum PluralCategory: String, CaseIterable, Sendable {
    case zero, one, two, few, many, other

    public static func of(_ n: Int, language: String) -> PluralCategory {
        let n = abs(n)
        guard language.hasPrefix("ar") else { return n == 1 ? .one : .other }
        switch (n, n % 100) {
        case (0, _): return .zero
        case (1, _): return .one
        case (2, _): return .two
        case (_, 3...10): return .few
        case (_, 11...99): return .many
        default: return .other
        }
    }
}
