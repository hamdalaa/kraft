import Foundation
import Testing
@testable import KraftCore

private let utc: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "UTC")!
    return c
}()

/// Friday 23 October 2026, 10:00 UTC.
private let now = utc.date(from: DateComponents(year: 2026, month: 10, day: 23, hour: 10))!

private func day(_ d: Int, month: Int = 10) -> Date {
    utc.date(from: DateComponents(year: 2026, month: month, day: d))!
}

@Suite struct RemindMessageTests {
    let ali = MoneyInfo(person: "Ali", amount: 40, currency: .usd, dueDate: day(30),
                        payments: [Payment(amount: 10, date: day(20))])

    @Test func englishOwedToMeMentionsRemainderTotalAndUpcomingDate() {
        let text = RemindMessage.text(for: ali, language: .english, now: now, calendar: utc)
        #expect(text.hasPrefix("Hi Ali, I hope you're doing well."))
        #expect(text.contains("the remaining $30 of the $40"))
        #expect(text.contains("Friday 30 October"))
        #expect(text.hasSuffix("Thank you so much!"))
    }

    @Test func englishWithoutPaymentsOrDateStaysShort() {
        let m = MoneyInfo(person: "Sara", amount: 25, currency: .usd)
        let text = RemindMessage.text(for: m, language: .english, now: now, calendar: utc)
        #expect(text == "Hi Sara, I hope you're doing well. Just a gentle reminder about the $25. Whenever it suits you is fine. Thank you so much!")
    }

    @Test func pastDueDateIsLeftOut() {
        var m = ali
        m.dueDate = day(1)
        let text = RemindMessage.text(for: m, language: .english, now: now, calendar: utc)
        #expect(!text.contains("October"))
        #expect(text.contains("Whenever it suits you is fine."))
    }

    @Test func dueTodayIsStillMentioned() {
        var m = ali
        m.dueDate = day(23)
        #expect(RemindMessage.text(for: m, language: .english, now: now, calendar: utc).contains("23 October"))
    }

    @Test func iOweReassuresInsteadOfAsking() {
        let m = MoneyInfo(person: "Ahmad", amount: 150_000, currency: .iqd)
        let text = RemindMessage.text(for: m, kind: .iOwe, language: .english, now: now, calendar: utc)
        #expect(text.contains("I haven't forgotten the 150,000 IQD I owe you"))
        #expect(text.contains("as soon as I can"))
        #expect(!text.contains("reminder"))
    }

    @Test func emptyNameGreetsPlainly() {
        let m = MoneyInfo(person: "  ", amount: 5, currency: .usd)
        #expect(RemindMessage.text(for: m, language: .english, now: now, calendar: utc).hasPrefix("Hi, I hope"))
        #expect(RemindMessage.text(for: m, language: .arabic, now: now, calendar: utc).hasPrefix("مرحبًا، أتمنى"))
    }

    @Test func arabicUsesArabicDigitsAndDinarSign() {
        let m = MoneyInfo(person: "أحمد", amount: 150_000, currency: .iqd, dueDate: day(30),
                          payments: [Payment(amount: 50_000, date: day(20))])
        let text = RemindMessage.text(for: m, language: .arabic, digits: .arabic, now: now, calendar: utc)
        #expect(text.hasPrefix("مرحبًا أحمد،"))
        #expect(text.contains("بالمبلغ المتبقي ١٠٠٬٠٠٠ د.ع من أصل ١٥٠٬٠٠٠ د.ع"))
        #expect(text.contains("قبل الجمعة"))
        #expect(text.contains("٣٠"))
        #expect(!text.contains("30"))
        #expect(text.hasSuffix("شكرًا جزيلًا لك."))
    }

    @Test func arabicWithWesternDigits() {
        let text = RemindMessage.text(for: ali, language: .arabic, digits: .western, now: now, calendar: utc)
        #expect(text.contains("$30"))
        #expect(text.contains("$40"))
        #expect(text.contains("30"))
        #expect(!text.contains("٣٠"))
    }

    @Test func englishIgnoresArabicDigitStyle() {
        let text = RemindMessage.text(for: ali, language: .english, digits: .arabic, now: now, calendar: utc)
        #expect(text.contains("$30"))
    }

    @Test func arabicIOwe() {
        let m = MoneyInfo(person: "أحمد", amount: 150_000, currency: .iqd)
        let text = RemindMessage.text(for: m, kind: .iOwe, language: .arabic, digits: .arabic, now: now, calendar: utc)
        #expect(text.contains("لم أنسَ مبلغ ١٥٠٬٠٠٠ د.ع الذي عليّ لك"))
        #expect(text.contains("في أقرب وقت ممكن"))
    }

    @Test func languageFollowsTheNote() {
        #expect(MessageLanguage.of("إيجار أحمد") == .arabic)
        #expect(MessageLanguage.of("Ali owes me") == .english)
        #expect(MessageLanguage.of("") == .english)
    }
}

@Suite struct WhatsAppLinkTests {
    @Test func encodesEverythingButUnreservedCharacters() {
        #expect(WhatsAppLink.encode("Hi Ali, $30 & more?") == "Hi%20Ali%2C%20%2430%20%26%20more%3F")
        #expect(WhatsAppLink.encode("a+b#c\nd") == "a%2Bb%23c%0Ad")
        #expect(WhatsAppLink.encode("safe-._~") == "safe-._~")
    }

    @Test func encodesArabicAsUTF8() {
        #expect(WhatsAppLink.encode("مرحبًا") == "%D9%85%D8%B1%D8%AD%D8%A8%D9%8B%D8%A7")
        #expect(WhatsAppLink.encode("١٠") == "%D9%A1%D9%A0")
    }

    @Test func buildsWaMeURL() {
        #expect(WhatsAppLink.url(text: "Hi there")?.absoluteString == "https://wa.me/?text=Hi%20there")
        #expect(WhatsAppLink.url(text: "x", phone: "+964 770-123")?.absoluteString == "https://wa.me/964770123?text=x")
    }

    @Test func roundTripsThroughURLComponents() throws {
        let message = RemindMessage.text(for: MoneyInfo(person: "علي", amount: 40, currency: .usd), language: .arabic, digits: .arabic)
        let url = try #require(WhatsAppLink.url(text: message))
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
        #expect(items?.first { $0.name == "text" }?.value == message)
    }
}
