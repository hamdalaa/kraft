import Foundation
import Testing
@testable import KraftCore

private let utc: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "UTC")!
    return c
}()

/// Friday 23 October 2026, 09:05 UTC.
private let friday = utc.date(from: DateComponents(year: 2026, month: 10, day: 23, hour: 9, minute: 5))!

private func format(_ language: String, _ digits: DigitStyle = .western, region: String? = "IQ") -> KraftFormat {
    KraftFormat(language: language, digits: digits, region: region, calendar: utc)
}

@Suite struct LocalizationFormatTests {
    @Test func localeCarriesTheDigitChoiceNotTheLanguageDefault() {
        #expect(format("ar").locale.identifier == "ar_IQ@numbers=latn")
        #expect(format("ar", .arabic).locale.identifier == "ar_IQ@numbers=arab")
        #expect(format("en", .arabic, region: nil).locale.identifier == "en@numbers=arab")
    }

    @Test func westernDigitsAreTheDefaultInBothLanguages() {
        #expect(KraftFormat(language: "ar").digits == .western)
        #expect(format("ar").number(1250) == "1,250")
        #expect(format("en").number(7) == "7")
    }

    @Test func arabicDigitsApplyToCountsMoneyAndDates() {
        let ar = format("ar", .arabic)
        #expect(ar.number(1250) == "١٬٢٥٠")
        #expect(ar.money(150_000, .iqd) == "١٥٠٬٠٠٠ د.ع")
        #expect(ar.dayMonth(friday).contains("٢٣"))
        #expect(!ar.time(friday).contains("9"))
        // English UI with Arabic digits still writes English words.
        let en = format("en", .arabic)
        #expect(en.weekday(friday) == "Fri")
        #expect(en.dayMonth(friday) == "٢٣ Oct")
    }

    @Test func englishDatesReadNaturally() {
        let en = format("en")
        #expect(en.weekday(friday) == "Fri")
        #expect(en.dayMonth(friday) == "23 Oct")
        #expect(en.longDay(friday) == "Friday, 23 October")
        #expect(en.time(friday).replacingOccurrences(of: "\u{202F}", with: " ") == "9:05 AM")
    }

    @Test func arabicDatesUseArabicNamesAndKeepWesternDigitsByDefault() {
        let ar = format("ar")
        #expect(ar.weekday(friday) == "الجمعة")
        #expect(ar.longDay(friday).contains("الجمعة"))
        #expect(ar.longDay(friday).contains("23"))
        // Iraqi month names for the IQ region.
        #expect(ar.dayMonth(friday).replacingOccurrences(of: "\u{A0}", with: " ").contains("تشرين الأول"))
        #expect(ar.weekdayDayMonth(friday).hasPrefix("الجمعة"))
        #expect(ar.time(friday).contains("9:05"))
    }

    @Test func noteMoneyKeepsItsOwnLanguageButTakesTheDigitChoice() {
        let en = format("en", .arabic)
        #expect(en.money(40, .usd, arabic: false) == "$٤٠")
        #expect(format("ar").money(35_000, .iqd, arabic: false) == "35,000 IQD")
        #expect(format("en").money(35_000, .iqd) == "35,000 IQD")
        #expect(format("ar").money(35_000, .iqd) == "35,000 د.ع")
    }

    @Test func rewritesDigitsInBuiltStrings() {
        #expect(KraftFormat.applying(.arabic, to: "Day 25, ⌘1") == "Day ٢٥, ⌘١")
        #expect(KraftFormat.applying(.western, to: "الساعة ٩ و۵") == "الساعة 9 و5")
        #expect(KraftFormat.applying(.western, to: "no digits") == "no digits")
    }

    @Test func directionFollowsTheUILanguage() {
        #expect(format("ar").isRightToLeft)
        #expect(!format("en").isRightToLeft)
    }
}

@Suite struct LocalizationPluralTests {
    @Test(arguments: [
        (0, PluralCategory.zero), (1, .one), (2, .two), (3, .few), (10, .few), (11, .many), (99, .many),
        (100, .other), (102, .other), (103, .few), (111, .many),
    ])
    func arabicCategories(n: Int, expected: PluralCategory) {
        #expect(PluralCategory.of(n, language: "ar") == expected)
    }

    @Test func englishHasOneAndOther() {
        #expect(PluralCategory.of(1, language: "en") == .one)
        #expect(PluralCategory.of(0, language: "en") == .other)
        #expect(PluralCategory.of(2, language: "en") == .other)
    }
}

@Suite struct LocalizationLanguageTests {
    @Test func choiceRoundTripsThroughAppleLanguages() {
        for choice in AppLanguage.allCases {
            #expect(AppLanguage(appleLanguages: choice.appleLanguages) == choice)
        }
        #expect(AppLanguage(appleLanguages: ["ar-IQ", "en"]) == .arabic)
        #expect(AppLanguage(appleLanguages: ["fr"]) == .system)
    }

    @Test func resolvesToAShippedLanguage() {
        #expect(AppLanguage.resolve(preferred: ["ar-IQ", "en-IQ"]) == "ar")
        #expect(AppLanguage.resolve(preferred: ["en-IQ", "ar-IQ"]) == "en")
        #expect(AppLanguage.resolve(preferred: ["fr-FR"]) == "en")
        #expect(AppLanguage.system.uiLanguage(system: ["ar-IQ"]) == "ar")
        #expect(AppLanguage.english.uiLanguage(system: ["ar-IQ"]) == "en")
        #expect(AppLanguage.arabic.uiLanguage(system: ["en-US"]) == "ar")
    }
}
