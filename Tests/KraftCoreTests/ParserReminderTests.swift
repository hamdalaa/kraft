import Foundation
import Testing
@testable import KraftCore

@Suite struct ParserReminderTests {
    static let englishCases: [Expect] = [
        Expect(text: "remind me to call mum tomorrow 6pm", kind: .reminder, title: "Call mum", date: PF.date(2026, 10, 22, 18),
               hasTime: true, repeatRule: .never),
        Expect(text: "remind me to stretch at 4", kind: .reminder, title: "Stretch", date: PF.date(2026, 10, 21, 16)),
        Expect(text: "dentist friday 9:30am", kind: .reminder, title: "Dentist", date: PF.date(2026, 10, 23, 9, 30)),
        Expect(text: "call the bank in 2 hours", kind: .reminder, title: "Call the bank", date: PF.date(2026, 10, 21, 12, 30)),
        Expect(text: "pay rent on the 1st", kind: .reminder, title: "Pay rent", date: PF.date(2026, 11, 1, 9)),
        Expect(text: "water the plants every friday", kind: .reminder, title: "Water the plants", date: PF.date(2026, 10, 23, 9),
               repeatRule: .weekly),
        Expect(text: "don't forget passport renewal 3 Nov", kind: .reminder, title: "Passport renewal", date: PF.date(2026, 11, 3, 9)),
        Expect(text: "standup every weekday", kind: .note), // not understood → plain note
        Expect(text: "vitamins every morning", kind: .reminder, title: "Vitamins", date: PF.date(2026, 10, 22, 9), repeatRule: .daily),
        Expect(text: "tonight film with Sara", kind: .reminder, title: "Film with Sara", date: PF.date(2026, 10, 21, 20)),
        Expect(text: "meeting at 7 in the evening", kind: .reminder, title: "Meeting", date: PF.date(2026, 10, 21, 19)),
        Expect(text: "gym 18:15 daily", kind: .reminder, title: "Gym", date: PF.date(2026, 10, 21, 18, 15), repeatRule: .daily),
        Expect(text: "remind me tomorrow", kind: .reminder, title: "", date: PF.date(2026, 10, 22, 9), hasTime: false),
        Expect(text: "renew licence end of month", kind: .reminder, date: PF.date(2026, 10, 31, 9)),
        Expect(text: "flight day after tomorrow 7am", kind: .reminder, title: "Flight", date: PF.date(2026, 10, 23, 7)),
        Expect(text: "birthday party next month", kind: .reminder, title: "Birthday party", date: PF.date(2026, 11, 1, 9)),
        Expect(text: "remind me to call mum", kind: .reminder, title: "Call mum", date: .some(nil)),
        Expect(text: "report due today", kind: .reminder, title: "Report", date: PF.date(2026, 10, 21, 11)),
    ]

    static let arabicCases: [Expect] = [
        Expect(text: "ذكرني بالدواء الساعة ٩ كل يوم", kind: .reminder, title: "الدواء", date: PF.date(2026, 10, 22, 9),
               hasTime: true, repeatRule: .daily),
        Expect(text: "ذكرني أتصل بأمي بكرة الساعة ٦ المساء", kind: .reminder, title: "أتصل بأمي", date: PF.date(2026, 10, 22, 18)),
        Expect(text: "فكرني بموعد الطبيب باچر ١٠ صباحًا", kind: .reminder, title: "موعد الطبيب", date: PF.date(2026, 10, 22, 10)),
        Expect(text: "اجتماع الخميس الساعة ٣ ونص", kind: .reminder, title: "اجتماع", date: PF.date(2026, 10, 22, 15, 30)),
        Expect(text: "دواء الضغط يوميًا ٨ مساءً", kind: .reminder, title: "دواء الضغط", date: PF.date(2026, 10, 21, 20), repeatRule: .daily),
        Expect(text: "لا تنسى تدفع الإيجار يوم الجمعة", kind: .reminder, title: "تدفع الإيجار", date: PF.date(2026, 10, 23, 9)),
        Expect(text: "ذكرني بعد ساعتين أطفي الفرن", kind: .reminder, title: "أطفي الفرن", date: PF.date(2026, 10, 21, 12, 30)),
        Expect(text: "زيارة جدتي كل جمعة", kind: .reminder, title: "زيارة جدتي", date: PF.date(2026, 10, 23, 9), repeatRule: .weekly),
        Expect(text: "تجديد الجواز ١٥ تشرين الثاني", kind: .reminder, title: "تجديد الجواز", date: PF.date(2026, 11, 15, 9)),
        Expect(text: "ذكرني اليوم بالليل أشحن السيارة", kind: .reminder, title: "أشحن السيارة", date: PF.date(2026, 10, 21, 20)),
        Expect(text: "سفر بعد بكرة", kind: .reminder, title: "سفر", date: PF.date(2026, 10, 23, 9)),
        Expect(text: "حفلة الأسبوع الجاي", kind: .reminder, title: "حفلة", date: PF.date(2026, 10, 28, 9)),
        Expect(text: "دفع القسط آخر الشهر", kind: .reminder, date: PF.date(2026, 10, 31, 9)),
        Expect(text: "ذكرني بكرة", kind: .reminder, title: "", date: PF.date(2026, 10, 22, 9)),
        Expect(text: "اتصل بخالتي غدًا", kind: .reminder, title: "اتصل بخالتي", date: PF.date(2026, 10, 22, 9)),
    ]

    @Test(arguments: englishCases) func english(_ e: Expect) { check(e) }
    @Test(arguments: arabicCases) func arabic(_ e: Expect) { check(e) }

    @Test func weekdayTodayWithTimeAheadStaysToday() {
        let friday = PF.date(2026, 10, 23, 8)
        check(Expect(text: "call Omar friday 5pm", kind: .reminder, date: PF.date(2026, 10, 23, 17)), now: friday)
        check(Expect(text: "call Omar friday", kind: .reminder, date: PF.date(2026, 10, 30, 9)), now: friday)
    }

    @Test func timeAlreadyPassedMeansTomorrow() {
        check(Expect(text: "remind me to stretch at 9am", kind: .reminder, date: PF.date(2026, 10, 22, 9)))
    }

    @Test func hoursWithoutAmPm() {
        #expect(DateRules.hour24(6, am: false, pm: false) == 18)
        #expect(DateRules.hour24(9, am: false, pm: false) == 9)
        #expect(DateRules.hour24(12, am: true, pm: false) == 0)
        #expect(DateRules.hour24(12, am: false, pm: true) == 12)
        #expect(DateRules.hour24(18, am: false, pm: false) == 18)
    }
}
