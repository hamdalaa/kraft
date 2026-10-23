import Foundation

/// Words and phrasings QuickParser understands, English and Arabic (MSA + Iraqi), in normalised form
/// (see `TextScanner`: أ→ا, ة→ه, ى→ي, no harakat, digits ASCII, Latin lower-case).
enum Lex {
    /// Word edges that work for Arabic as well as Latin.
    static let l = "(?<![\\p{L}\\p{N}])"
    static let r = "(?![\\p{L}\\p{N}])"

    static func alt(_ words: [String]) -> String { "(?:" + words.joined(separator: "|") + ")" }

    // MARK: Numbers and money

    static let number = "(\\d{1,3}(?:,\\d{3})+(?:\\.\\d+)?|\\d+(?:\\.\\d+)?)"
    /// "k", "thousand", "ألف"/"الف"/"آلاف", "million"/"مليون".
    static let thousand = alt(["k", "thousand", "grand", "الف", "الاف", "تلاف"])
    static let million = alt(["mn", "million", "مليون", "ملايين"])

    // MARK: Days

    /// Weekday names → Calendar weekday (1 = Sunday).
    static let weekdays: [(Int, [String])] = [
        (1, ["sunday", "sun", "احد"]),
        (2, ["monday", "mon", "اثنين", "اتنين", "ثنين"]),
        (3, ["tuesday", "tues", "tue", "ثلاثاء", "ثلاثا", "ثلاثه"]),
        (4, ["wednesday", "wed", "اربعاء", "اربعا"]),
        (5, ["thursday", "thurs", "thur", "thu", "خميس"]),
        (6, ["friday", "fri", "جمعه"]),
        (7, ["saturday", "sat", "سبت"]),
    ]

    static func weekday(named word: String) -> Int? {
        let w = word.hasPrefix("ال") ? String(word.dropFirst(2)) : word
        return weekdays.first { $0.1.contains(w) || $0.1.contains(word) }?.0
    }

    static let englishWeekday = alt(weekdays.flatMap { $0.1.filter { $0.first?.isASCII == true } })
    static let arabicWeekday = alt(weekdays.flatMap { $0.1.filter { $0.first?.isASCII == false } })

    /// Month names → month number. Iraqi/Levantine and Egyptian/Gulf Arabic names both work.
    static let months: [(Int, [String])] = [
        (1, ["january", "jan", "يناير", "كانون الثاني"]),
        (2, ["february", "feb", "فبراير", "شباط"]),
        (3, ["march", "mar", "مارس", "اذار"]),
        (4, ["april", "apr", "ابريل", "نيسان"]),
        (5, ["may", "مايو", "ايار"]),
        (6, ["june", "jun", "يونيو", "حزيران"]),
        (7, ["july", "jul", "يوليو", "تموز"]),
        (8, ["august", "aug", "اغسطس", "اب"]),
        (9, ["september", "sept", "sep", "سبتمبر", "ايلول"]),
        (10, ["october", "oct", "اكتوبر", "تشرين الاول"]),
        (11, ["november", "nov", "نوفمبر", "تشرين الثاني"]),
        (12, ["december", "dec", "ديسمبر", "كانون الاول"]),
    ]

    static let monthName = alt(months.flatMap(\.1).sorted { $0.count > $1.count })

    static func month(named word: String) -> Int? {
        let w = word.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return months.first { $0.1.contains(w) }?.0
    }

    static let english12 = ["one": 1, "two": 2, "three": 3, "four": 4, "five": 5, "six": 6, "seven": 7, "eight": 8,
                            "nine": 9, "ten": 10, "eleven": 11, "twelve": 12, "a": 1, "an": 1, "a couple of": 2, "a few": 3]

    // MARK: Times of day

    static let amEnglish = alt(["am", "a\\.m\\.?"])
    static let pmEnglish = alt(["pm", "p\\.m\\.?"])
    static let amArabic = alt(["صباحا", "صباح", "الصبح", "الصباح", "بالصبح", "صبحا", "الفجر", "فجرا", "ص"])
    static let pmArabic = alt(["مساء", "المساء", "بالمساء", "العصر", "عصرا", "الظهر", "ظهرا", "بالليل", "الليل", "ليلا",
                              "بليل", "المغرب", "م"])

    /// Words that stand for a time on their own ("tomorrow morning", "بكرة الصبح").
    static let softTimes: [(TimeOfDay, [String])] = [
        (TimeOfDay(hour: 9), ["morning", "in the morning", "this morning", "الصبح", "الصباح", "صباحا", "بالصبح", "الفجر"]),
        (TimeOfDay(hour: 12), ["noon", "midday", "at noon", "الظهر", "ظهرا"]),
        (TimeOfDay(hour: 15), ["afternoon", "in the afternoon", "this afternoon", "العصر", "عصرا"]),
        (TimeOfDay(hour: 18), ["evening", "in the evening", "this evening", "المساء", "مساء", "بالمساء", "المغرب"]),
        (TimeOfDay(hour: 20), ["night", "at night", "tonight", "بالليل", "الليل", "ليلا", "بليل"]),
    ]

    // MARK: Names next to money phrasings

    /// Words that end a person's name ("I owe Omar for dinner", "يطلبني … عن").
    static let nameStops: Set<String> = [
        "for", "by", "on", "at", "before", "until", "due", "to", "back", "and", "the", "from", "about", "today",
        "tomorrow", "i", "me", "my", "is", "was", "owes", "owe",
        "عن", "على", "حق", "من", "الى", "لحد", "و", "قبل", "يوم", "بس", "انا", "اني", "هو", "هي", "لي", "مبلغ",
    ]
}
