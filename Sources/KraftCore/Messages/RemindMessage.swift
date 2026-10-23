import Foundation

/// Language of a "remind them" message.
public enum MessageLanguage: String, CaseIterable, Sendable {
    case english, arabic

    /// The language the note is written in: Arabic when its first strong character is Arabic.
    public static func of(_ text: String) -> MessageLanguage {
        ScriptDirection.detect(text) == .rightToLeft ? .arabic : .english
    }
}

/// A short, polite message about money between two people, in English or plain Modern Standard Arabic.
/// "Owes me" asks gently; "I owe" reassures. Arabic avoids gendered phrasing so it suits anyone.
public enum RemindMessage {
    public static func text(
        for money: MoneyInfo,
        kind: StickyKind = .owedToMe,
        language: MessageLanguage,
        digits: DigitStyle = .western,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> String {
        let isArabic = language == .arabic
        let digits = isArabic ? digits : .western
        let parts = Parts(
            name: money.person.trimmingCharacters(in: .whitespacesAndNewlines),
            total: MoneyFormat.string(money.amount, money.currency, arabic: isArabic, digits: digits),
            remaining: money.paid > 0 && money.remaining > 0
                ? MoneyFormat.string(money.remaining, money.currency, arabic: isArabic, digits: digits) : nil,
            due: upcomingDue(money.dueDate, now: now, calendar: calendar)
                .map { formatDate($0, arabic: isArabic, digits: digits, calendar: calendar) }
        )
        let reassure = kind == .iOwe
        switch language {
        case .english: return reassure ? english(iOwe: parts) : english(owedToMe: parts)
        case .arabic: return reassure ? arabic(iOwe: parts) : arabic(owedToMe: parts)
        }
    }

    private struct Parts {
        let name: String
        let total: String
        let remaining: String?
        let due: String?
    }

    // MARK: English

    private static func english(owedToMe p: Parts) -> String {
        let greeting = p.name.isEmpty ? "Hi," : "Hi \(p.name),"
        let amount = p.remaining.map { "the remaining \($0) of the \(p.total)" } ?? "the \(p.total)"
        let timing = p.due.map { "Whenever it suits you, ideally by \($0)." } ?? "Whenever it suits you is fine."
        return "\(greeting) I hope you're doing well. Just a gentle reminder about \(amount). \(timing) Thank you so much!"
    }

    private static func english(iOwe p: Parts) -> String {
        let greeting = p.name.isEmpty ? "Hi," : "Hi \(p.name),"
        let amount = p.remaining.map { "the \(p.total) I owe you (\($0) still to go)" } ?? "the \(p.total) I owe you"
        let timing = p.due.map { "I'll settle it by \($0)." } ?? "I'll settle it as soon as I can."
        return "\(greeting) I hope you're doing well. Just letting you know I haven't forgotten \(amount). \(timing) Thank you for your patience!"
    }

    // MARK: Arabic (MSA, gender-neutral)

    private static func arabic(owedToMe p: Parts) -> String {
        let greeting = p.name.isEmpty ? "مرحبًا،" : "مرحبًا \(p.name)،"
        let amount = p.remaining.map { "بالمبلغ المتبقي \($0) من أصل \(p.total)" } ?? "بمبلغ \(p.total)"
        let timing = p.due.map { "متى ما تيسّر لك ذلك، ويا حبّذا قبل \($0)." } ?? "متى ما تيسّر لك ذلك."
        return "\(greeting) أتمنى أن يكون كل شيء على ما يرام. أودّ تذكيرك بلطف \(amount)، \(timing) شكرًا جزيلًا لك."
    }

    private static func arabic(iOwe p: Parts) -> String {
        let greeting = p.name.isEmpty ? "مرحبًا،" : "مرحبًا \(p.name)،"
        let amount = p.remaining.map { "مبلغ \(p.total) الذي عليّ لك، والمتبقي منه \($0)" } ?? "مبلغ \(p.total) الذي عليّ لك"
        let timing = p.due.map { "سأسدّده قبل \($0)." } ?? "سأسدّده في أقرب وقت ممكن."
        return "\(greeting) أتمنى أن يكون كل شيء على ما يرام. أودّ طمأنتك بأنني لم أنسَ \(amount). \(timing) شكرًا على صبرك."
    }

    // MARK: Dates

    /// Only mention a due date that is still ahead: pointing at a missed date reads as a complaint.
    static func upcomingDue(_ due: Date?, now: Date, calendar: Calendar) -> Date? {
        guard let due, due >= calendar.startOfDay(for: now) else { return nil }
        return due
    }

    static func formatDate(_ date: Date, arabic: Bool, digits: DigitStyle, calendar: Calendar) -> String {
        let id = arabic ? (digits == .arabic ? "ar_IQ" : "ar_IQ@numbers=latn") : "en_GB"
        var style = Date.FormatStyle(date: .omitted, time: .omitted, locale: Locale(identifier: id), calendar: calendar,
                                     timeZone: calendar.timeZone)
        style = style.weekday(.wide).day().month(.wide)
        return date.formatted(style)
    }
}
