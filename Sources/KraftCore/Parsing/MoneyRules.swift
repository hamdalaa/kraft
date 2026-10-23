import Foundation

/// Debt phrasings, bill hints and amounts.
///
/// Iraqi usage, as chosen here:
/// - "علي يطلبني ٤٠" — Ali has a claim on me → **I owe** Ali. ("أطلب علي ٤٠" = I have a claim on Ali → Ali owes me.)
/// - "لي عند علي"، "لي على علي"، "علي مدين لي"، "علي عنده لي"، "سلّفت علي" → **Ali owes me**.
/// - "أنا مدين لأحمد"، "لأحمد عندي"، "أحمد له عندي"، "استلفت من أحمد"، "أحمد سلّفني"، "أحمد يريد مني" → **I owe** Ahmad.
enum MoneyRules {
    enum Slot { case before, after, named }

    struct Trigger {
        let kind: StickyKind
        let regex: NSRegularExpression
        let slot: Slot
        /// Phrasings that also have an everyday meaning ("اطلب" = order) only count next to an amount.
        var needsAmount = false
    }

    private static let l = Lex.l, r = Lex.r
    private static let owe = "(?:مدين|مديون|مدينه|مديونه)"

    /// Order matters: "owes me" before "owe X", "مدين لي" before "مدين لـX", "lent me" before "lent X".
    static let triggers: [Trigger] = [
        Trigger(kind: .owedToMe, regex: .make("\(l)owes?\\s+me\(r)"), slot: .before),
        Trigger(kind: .owedToMe, regex: .make("\(l)(?:borrowed|took)\\s+(?:money\\s+)?from\\s+me\(r)"), slot: .before),
        Trigger(kind: .iOwe, regex: .make("\(l)(?:lent|loaned)\\s+me\(r)"), slot: .before),
        Trigger(kind: .owedToMe, regex: .make("\(l)(?:i\\s+)?(?:lent|loaned)\\s+"), slot: .after),
        Trigger(kind: .owedToMe, regex: .make("\(l)owed\\s+by\\s+"), slot: .after),
        Trigger(kind: .iOwe, regex: .make("\(l)(?:i\\s+)?owe\\s+"), slot: .after),
        Trigger(kind: .iOwe, regex: .make("\(l)(?:i\\s+)?(?:borrowed|took)\\s+(?:money\\s+)?from\\s+"), slot: .after),
        Trigger(kind: .iOwe, regex: .make("\(l)pay\\s+back\\s+"), slot: .after),

        Trigger(kind: .owedToMe, regex: .make("\(l)\(owe)\\s*لي\(r)|\(l)(?:مديونلي|مدينلي)\(r)"), slot: .before),
        Trigger(kind: .owedToMe, regex: .make("\(l)(?:عنده|عندها|بذمته|بذمتها|عليه|عليها)\\s+(?:لي|الي)\(r)"), slot: .before),
        Trigger(kind: .owedToMe, regex: .make("\(l)(?:لي|الي)\\s+(?:عند|بذمه|على|ع)\\s+"), slot: .after),
        Trigger(kind: .owedToMe, regex: .make("\(l)(?:سلفت|داينت|دينت|اقرضت|قرضت)\\s+"), slot: .after),
        Trigger(kind: .owedToMe, regex: .make("\(l)(?:اطلب|نطلب)\\s+"), slot: .after, needsAmount: true),
        Trigger(kind: .iOwe, regex: .make("\(l)(?:يطلبني|تطلبني|يطلبوني|يريد\\s+مني|تريد\\s+مني|يريدمني|يريدون\\s+مني)\(r)"), slot: .before),
        Trigger(kind: .iOwe, regex: .make("\(l)(?:سلفني|دينني|داينني|اقرضني|قرضني)\(r)"), slot: .before, needsAmount: true),
        Trigger(kind: .iOwe, regex: .make("\(l)(?:له|لها)\\s+(?:عندي|بذمتي)\(r)"), slot: .before),
        Trigger(kind: .iOwe, regex: .make("\(l)ل(?<p>[^\\s\\d,.;:]+(?:\\s+[^\\s\\d,.;:]+)?)\\s+(?:عندي|بذمتي)\(r)"), slot: .named),
        Trigger(kind: .iOwe, regex: .make("\(l)(?:(?:انا|اني)\\s+)?\(owe)\\s+ل\\s*"), slot: .after),
        Trigger(kind: .iOwe, regex: .make("\(l)(?:استلفت|تسلفت|اقترضت|استدنت|تدينت|دنت|اخذت\\s+دين)\\s+من\\s+"), slot: .after),
    ]

    static let billHint: NSRegularExpression = .make(
        "\(l)(?:bills?|subscription|rent|internet|wifi|electricity|electric|netflix|spotify|icloud|"
            + "generator|insurance|fees?|installment|فاتوره|فواتير|اشتراك|ايجار|الايجار|انترنت|الانترنت|نت|كهرباء|الكهرباء|"
            + "مولده|المولده|قسط|القسط|نتفلكس)\(r)")

    // MARK: Amounts

    struct Amount {
        let value: Decimal
        let currency: Currency?
        let range: NSRange
        /// A plain number with no currency or "k" next to it.
        var isBare = false
    }

    private static let n = Lex.number
    private static let mult = "(?:\\s?(?:(\(Lex.thousand))|(\(Lex.million))))"

    /// $40, €12, USD 40, SAR 40
    private static let prefixed: NSRegularExpression = .make("(\(CurrencyWords.before))\\s?\(n)\(mult)?\(r)")
    /// 40$, 12€, 150k IQD, ١٥٠ ألف دينار, 35,000 د.ع, 40 riyals
    private static let suffixed: NSRegularExpression = .make("\(l)\(n)\(mult)?\\s?(\(CurrencyWords.after))(?:(?<=[^\\p{L}\\p{N}])|\(r))")
    /// 150k, ١٥٠ ألف
    private static let scaled: NSRegularExpression = .make("\(l)\(n)\(mult)\(r)")
    /// ألفين، ألف دينار، مليون
    private static let wordOnly: NSRegularExpression = .make("\(l)(الفين|مليونين|الف|مليون)(?:\\s+(\(CurrencyWords.after)))?\(r)")
    private static let bare: NSRegularExpression = .make("\(l)\(n)\(r)")

    /// The first amount in the text. Bare numbers ("Ali owes me 40") only count when `allowBare`.
    /// A written currency resolves against `preferred` ("$" is CA$ for someone whose default is CAD).
    static func amount(in s: TextScanner, allowBare: Bool, preferred: Currency) -> Amount? {
        if let m = s.firstFree(prefixed) {
            return make(s, m, number: 2, thousand: 3, million: 4, currency: s.group(m, 1), preferred: preferred)
        }
        if let m = s.firstFree(suffixed) {
            return make(s, m, number: 1, thousand: 2, million: 3, currency: s.group(m, 4), preferred: preferred)
        }
        if let m = s.firstFree(scaled) {
            return make(s, m, number: 1, thousand: 2, million: 3, currency: nil, preferred: preferred)
        }
        if let m = s.firstFree(wordOnly), let word = s.group(m, 1) {
            let value: Decimal = ["الفين": 2000, "مليونين": 2_000_000, "الف": 1000, "مليون": 1_000_000][word] ?? 0
            let cur = s.group(m, 2).flatMap { CurrencyWords.resolve($0, preferred: preferred) }
            return Amount(value: value, currency: cur, range: m.range)
        }
        if allowBare, let m = s.firstFree(bare), var a = make(s, m, number: 1, thousand: nil, million: nil, currency: nil, preferred: preferred) {
            a.isBare = true
            return a
        }
        return nil
    }

    private static func make(_ s: TextScanner, _ m: NSTextCheckingResult, number: Int, thousand: Int?, million: Int?,
                             currency: String?, preferred: Currency) -> Amount? {
        guard let raw = s.group(m, number), var value = Decimal(string: raw.replacingOccurrences(of: ",", with: ""),
                                                                    locale: Locale(identifier: "en_US_POSIX")) else { return nil }
        if let thousand, s.group(m, thousand) != nil { value *= 1000 }
        if let million, s.group(m, million) != nil { value *= 1_000_000 }
        return Amount(value: value, currency: currency.flatMap { CurrencyWords.resolve($0, preferred: preferred) }, range: m.range)
    }
}
