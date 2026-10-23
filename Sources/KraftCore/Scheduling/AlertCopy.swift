import Foundation

/// Notification text in the note's own language: an Arabic note gets plain MSA, whatever the Mac's
/// language is. That is why these strings are tables keyed by the note's script, not `String(localized:)`.
public struct AlertCopy: Hashable, Sendable {
    public var title: String
    public var body: String
    public var isArabic: Bool

    public static let bodyLimit = 180

    /// `digits`: the owner's digit choice for amounts; nil keeps the note's own (Arabic notes → ١٢٣).
    public static func make(for sticky: Sticky, digits: DigitStyle? = nil, calendar: Calendar = .current) -> AlertCopy {
        let arabic = ScriptDirection.detect(sticky.primaryText) == .rightToLeft
        let title = clean(sticky.title)
        return AlertCopy(
            title: title.isEmpty ? fallbackTitle(sticky.kind, arabic: arabic) : title,
            body: body(for: sticky, arabic: arabic, digits: digits ?? (arabic ? .arabic : .western)),
            isArabic: arabic
        )
    }

    /// Button titles in the order Done, Snooze 10 min, Snooze 1 hour, Tomorrow.
    public static func actionTitles(arabic: Bool, digits: DigitStyle? = nil) -> (done: String, tenMinutes: String, oneHour: String, tomorrow: String) {
        let d = digits ?? (arabic ? .arabic : .western)
        return arabic
            ? ("تم", KraftFormat.applying(d, to: "غفوة ١٠ دقائق"), "غفوة ساعة", "غدًا")
            : ("Done", KraftFormat.applying(d, to: "Snooze 10 min"), "Snooze 1 hour", "Tomorrow")
    }

    static func fallbackTitle(_ kind: StickyKind, arabic: Bool) -> String {
        switch kind {
        case .note: arabic ? "ملاحظة" : "Note"
        case .todo: arabic ? "مهام" : "To-do"
        case .reminder: arabic ? "تذكير" : "Reminder"
        case .owedToMe: arabic ? "دَين لك" : "Owed to you"
        case .iOwe: arabic ? "دَين عليك" : "You owe"
        case .bill: arabic ? "فاتورة" : "Bill"
        }
    }

    static func body(for sticky: Sticky, arabic: Bool, digits: DigitStyle) -> String {
        if sticky.reminder == nil, let money = sticky.money { return moneyLine(sticky.kind, money, arabic: arabic, digits: digits) }
        let text = clean(sticky.body)
        if !text.isEmpty { return truncated(text) }
        let open = sticky.checklist.filter { !$0.isDone }.map { clean($0.text) }.filter { !$0.isEmpty }
        if !open.isEmpty { return truncated(open.joined(separator: arabic ? "، " : ", ")) }
        if let money = sticky.money { return moneyLine(sticky.kind, money, arabic: arabic, digits: digits) }
        return repeatLine(sticky.reminder?.repeatRule ?? .never, arabic: arabic)
    }

    static func moneyLine(_ kind: StickyKind, _ money: MoneyInfo, arabic: Bool, digits: DigitStyle) -> String {
        let amount = MoneyFormat.string(money.remaining, money.currency, arabic: arabic, digits: digits)
        // U+2068/2069 isolate the amount and name so "$" and Latin names don't reorder Arabic text.
        let a = arabic ? "\u{2068}\(amount)\u{2069}" : amount
        let person = clean(money.person)
        let who = arabic ? "\u{2068}\(person)\u{2069}" : person
        switch (kind, arabic) {
        case (.owedToMe, false): return person.isEmpty ? "\(a) owed to you is due today." : "\(who) owes you \(a), due today."
        case (.owedToMe, true): return person.isEmpty ? "لك مبلغ \(a) يُستحق اليوم." : "لك على \(who) مبلغ \(a) يُستحق اليوم."
        case (.iOwe, false): return person.isEmpty ? "You owe \(a), due today." : "You owe \(who) \(a), due today."
        case (.iOwe, true): return person.isEmpty ? "عليك مبلغ \(a) يُستحق اليوم." : "عليك لـ\(who) مبلغ \(a) يُستحق اليوم."
        case (_, false): return person.isEmpty ? "\(a) is due today." : "\(who): \(a) due today."
        case (_, true): return person.isEmpty ? "فاتورة بمبلغ \(a) تُستحق اليوم." : "فاتورة \(who) بمبلغ \(a) تُستحق اليوم."
        }
    }

    static func repeatLine(_ rule: RepeatRule, arabic: Bool) -> String {
        switch rule {
        case .never: ""
        case .daily: arabic ? "كل يوم" : "Every day"
        case .weekly: arabic ? "كل أسبوع" : "Every week"
        case .monthly: arabic ? "كل شهر" : "Every month"
        case .yearly: arabic ? "كل سنة" : "Every year"
        }
    }

    /// Whitespace and newlines collapsed to single spaces.
    static func clean(_ s: String) -> String {
        s.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    static func truncated(_ s: String) -> String {
        s.count > bodyLimit ? String(s.prefix(bodyLimit - 1)) + "…" : s
    }
}
