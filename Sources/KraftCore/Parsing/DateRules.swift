import Foundation

/// When something happens, as said in the sentence (before it is pinned to a calendar date).
struct Schedule: Equatable {
    var day: Date?
    var weekday: Int?
    var dayOfMonth: Int?
    var time: TimeOfDay?
    /// The time was said with am/pm or صباحًا/مساءً, so it is not re-guessed.
    var timeIsExplicit = false
    /// "morning", "بالليل" — used when no clock time is given, or to pick am/pm for one.
    var softTime: TimeOfDay?
    /// "in 2 hours", "بعد ١٠ دقائق".
    var exact: Date?
    var repeatRule: RepeatRule = .never

    var isEmpty: Bool {
        day == nil && weekday == nil && dayOfMonth == nil && time == nil && softTime == nil && exact == nil && repeatRule == .never
    }
}

/// Repeat, time and date phrases (EN + AR). Claims each phrase in the scanner.
enum DateRules {
    typealias Rule = (NSRegularExpression, @Sendable (NSTextCheckingResult, TextScanner, inout Schedule) -> Bool)

    static func scan(_ s: inout TextScanner, now: Date, calendar cal: Calendar) -> Schedule {
        var sched = Schedule()
        apply(repeatRules, field: .repeatRule, to: &s, &sched)
        apply(relativeRules(now: now, cal: cal), field: .time, to: &s, &sched)
        apply(timeRules, field: .time, to: &s, &sched)
        apply(dayRules(now: now, cal: cal), field: .date, to: &s, &sched)
        if sched.time == nil || !sched.timeIsExplicit {
            apply([softTimeRule], field: .time, to: &s, &sched)
        }
        return sched
    }

    /// Each rule fires once at most; a handler returning false leaves the phrase for someone else.
    private static func apply(_ rules: [Rule], field: ParsedSpan.Field, to s: inout TextScanner, _ sched: inout Schedule) {
        for (regex, handle) in rules {
            for m in s.freeMatches(regex) where s.isFree(m.range) {
                if handle(m, s, &sched) { s.claim(m.range, as: field); break }
            }
        }
    }

    // MARK: Repeat

    static let l = Lex.l, r = Lex.r

    static let repeatRules: [Rule] = [
        (.make("\(l)(?:every|each)\\s+(\(Lex.englishWeekday))s?\(r)|\(l)on\\s+(\(Lex.englishWeekday))s\(r)"), { m, s, sc in
            guard sc.repeatRule == .never, let w = Lex.weekday(named: s.group(m, 1) ?? s.group(m, 2) ?? "") else { return false }
            sc.repeatRule = .weekly; sc.weekday = w; return true
        }),
        (.make("\(l)كل\\s+(?:يوم\\s+)?(?:ال)?(\(Lex.arabicWeekday))\(r)"), { m, s, sc in
            guard sc.repeatRule == .never, let w = Lex.weekday(named: s.group(m, 1) ?? "") else { return false }
            sc.repeatRule = .weekly; sc.weekday = w; return true
        }),
        (.make("\(l)(?:every|each)\\s+(morning|afternoon|evening|night)\(r)|\(l)كل\\s+(صباح|ليله|مساء|يوم\\s+الصبح|يوم\\s+بالليل)\(r)"), { m, s, sc in
            guard sc.repeatRule == .never else { return false }
            sc.repeatRule = .daily
            sc.softTime = softTime(for: s.group(m, 1) ?? s.group(m, 2) ?? "")
            return true
        }),
        (.make("\(l)(?:(?:every|each)\\s+(?:single\\s+)?day|every\\s?day|daily)\(r)|\(l)(?:كل\\s+(?:يوم|نهار)|يوميا)\(r)"), { _, _, sc in
            set(.daily, &sc)
        }),
        (.make("\(l)(?:(?:every|each)\\s+week|weekly|(?:a|per)\\s+week)\(r)|\(l)(?:كل\\s+(?:اسبوع|سبوع)|اسبوعيا|بالاسبوع)\(r)"), { _, _, sc in
            set(.weekly, &sc)
        }),
        (.make("\(l)(?:every|each)\\s+(\\d{1,2})(?:st|nd|rd|th)(?:\\s+of\\s+(?:the|each|every)\\s+month)?\(r)|\(l)كل\\s+(\\d{1,2})\\s+(?:بالشهر|من\\s+الشهر)\(r)"), { m, s, sc in
            guard sc.repeatRule == .never, let d = Int(s.group(m, 1) ?? s.group(m, 2) ?? ""), (1...31).contains(d) else { return false }
            sc.repeatRule = .monthly; sc.dayOfMonth = d; return true
        }),
        (.make("\(l)(?:(?:every|each)\\s+month|monthly|(?:a|per)\\s+month)\(r)|/\\s?mo(?:nth)?\(r)|\(l)(?:كل\\s+شهر|شهريا|بالشهر)\(r)"), { _, _, sc in
            set(.monthly, &sc)
        }),
        (.make("\(l)(?:(?:every|each)\\s+year|yearly|annually|(?:a|per)\\s+year)\(r)|\(l)(?:كل\\s+(?:سنه|عام)|سنويا|بالسنه)\(r)"), { _, _, sc in
            set(.yearly, &sc)
        }),
    ]

    private static func set(_ rule: RepeatRule, _ sc: inout Schedule) -> Bool {
        guard sc.repeatRule == .never else { return false }
        sc.repeatRule = rule
        return true
    }

    // MARK: "in 2 hours" / "بعد ساعتين"

    static func relativeRules(now: Date, cal: Calendar) -> [Rule] {
        let enCount = "(\\d+|an?|one|two|three|four|five|six|seven|eight|nine|ten|twelve|a couple of|a few)"
        let enUnit = "(minutes?|mins?|m|hours?|hrs?|h|days?|d|weeks?|w|months?)"
        let arUnit = "(دقيقه|دقائق|دقايق|دقيقتين|ساعه|ساعات|ساعتين|يوم|ايام|يومين|اسبوع|اسابيع|اسبوعين|شهر|اشهر|شهور|شهرين)"
        return [
            (.make("\(l)in\\s+half\\s+an\\s+hour\(r)|\(l)(?:بعد|خلال)\\s+(?:نص|نصف)\\s+ساعه\(r)"), { _, _, sc in
                sc.exact = cal.date(byAdding: .minute, value: 30, to: now); return true
            }),
            (.make("\(l)(?:بعد|خلال)\\s+ربع\\s+ساعه\(r)"), { _, _, sc in
                sc.exact = cal.date(byAdding: .minute, value: 15, to: now); return true
            }),
            (.make("\(l)in\\s+\(enCount)\\s?\(enUnit)\(r)"), { m, s, sc in
                let raw = s.group(m, 1) ?? "1"
                guard let n = Int(raw) ?? Lex.english12[raw], let unit = s.group(m, 2) else { return false }
                return relative(n, unit: unit, now: now, cal: cal, &sc)
            }),
            (.make("\(l)(?:بعد|خلال)\\s+(?:(\\d+)\\s+)?\(arUnit)\(r)"), { m, s, sc in
                guard let unit = s.group(m, 2) else { return false }
                let n = Int(s.group(m, 1) ?? "") ?? (unit.hasSuffix("ين") ? 2 : 1)
                return relative(n, unit: unit, now: now, cal: cal, &sc)
            }),
        ]
    }

    private static func relative(_ n: Int, unit: String, now: Date, cal: Calendar, _ sc: inout Schedule) -> Bool {
        let u = unit.lowercased()
        let today = cal.startOfDay(for: now)
        if u.hasPrefix("m") && !u.hasPrefix("mo") || u.hasPrefix("دق") {
            sc.exact = cal.date(byAdding: .minute, value: n, to: now)
        } else if u.hasPrefix("h") || u.hasPrefix("ساع") {
            sc.exact = cal.date(byAdding: .hour, value: n, to: now)
        } else if u.hasPrefix("d") || u.hasPrefix("يوم") || u.hasPrefix("ايام") {
            sc.day = cal.date(byAdding: .day, value: n, to: today)
        } else if u.hasPrefix("w") || u.hasPrefix("اسب") || u.hasPrefix("اساب") {
            sc.day = cal.date(byAdding: .day, value: 7 * n, to: today)
        } else {
            sc.day = cal.date(byAdding: .month, value: n, to: today)
        }
        return true
    }

    // MARK: Clock times

    static let timeRules: [Rule] = [
        // 6pm, 6:30 pm, at 6 p.m.
        (.make("\(l)(?:(?:at|@|around|by)\\s?)?(\\d{1,2})(?:[:.](\\d{2}))?\\s?(?:(\(Lex.amEnglish))|(\(Lex.pmEnglish)))(?![\\p{L}])"), { m, s, sc in
            clock(m, s, hour: 1, minute: 2, am: 3, pm: 4, &sc)
        }),
        // الساعة ٩، ع الساعة ٦ ونص المساء
        (.make("\(l)(?:(?:على|ع|عل|في)\\s*)?(?:بال|ال)?ساعه\\s*(\\d{1,2})(?:[:.](\\d{2}))?(?:\\s*(و\\s?نص|و\\s?ربع|الا\\s?ربع|و\\s?ثلث|الا\\s?ثلث))?(?:\\s+(?:(\(Lex.amArabic))|(\(Lex.pmArabic))))?\(r)"), { m, s, sc in
            guard clock(m, s, hour: 1, minute: 2, am: 4, pm: 5, &sc), var t = sc.time else { return false }
            if let frac = s.group(m, 3)?.replacingOccurrences(of: " ", with: "") {
                let delta = ["ونص": 30, "وربع": 15, "الاربع": -15, "وثلث": 20, "الاثلث": -20][frac] ?? 0
                let total = (t.hour * 60 + t.minute + delta + 1440) % 1440
                t = TimeOfDay(hour: total / 60, minute: total % 60)
                sc.time = t
            }
            return true
        }),
        // ٩ صباحًا، 6 مساء
        (.make("\(l)(\\d{1,2})(?:[:.](\\d{2}))?\\s*(?:(\(Lex.amArabic))|(\(Lex.pmArabic)))\(r)"), { m, s, sc in
            clock(m, s, hour: 1, minute: 2, am: 3, pm: 4, &sc)
        }),
        // at 6, at 18:30
        (.make("\(l)(?:at|@)\\s?(\\d{1,2})(?:[:.](\\d{2}))?\(r)(?!\\s?(?:\\$|%|k\(r)))"), { m, s, sc in
            clock(m, s, hour: 1, minute: 2, am: nil, pm: nil, &sc)
        }),
        // 18:30
        (.make("\(l)(\\d{1,2}):(\\d{2})\(r)"), { m, s, sc in
            clock(m, s, hour: 1, minute: 2, am: nil, pm: nil, &sc)
        }),
    ]

    private static func clock(_ m: NSTextCheckingResult, _ s: TextScanner, hour: Int, minute: Int, am: Int?, pm: Int?,
                              _ sc: inout Schedule) -> Bool {
        guard sc.time == nil, sc.exact == nil, let h = Int(s.group(m, hour) ?? ""), (0...23).contains(h) else { return false }
        let min = Int(s.group(m, minute) ?? "") ?? 0
        guard (0...59).contains(min) else { return false }
        let isAM = am.flatMap { s.group(m, $0) } != nil
        let isPM = pm.flatMap { s.group(m, $0) } != nil
        sc.time = TimeOfDay(hour: hour24(h, am: isAM, pm: isPM), minute: min)
        sc.timeIsExplicit = isAM || isPM || h == 0 || h > 12
        return true
    }

    /// With no am/pm: 1–6 o'clock means the afternoon ("at 6" = 18:00), 7–12 means the morning/noon.
    static func hour24(_ h: Int, am: Bool, pm: Bool) -> Int {
        if am { return h == 12 ? 0 : h }
        if pm { return h < 12 ? h + 12 : h }
        if (1...6).contains(h) { return h + 12 }
        return h
    }

    static let softTimeRule: Rule = (
        .make("\(l)" + Lex.alt(Lex.softTimes.flatMap(\.1).sorted { $0.count > $1.count }) + "\(r)"),
        { m, s, sc in
            guard sc.softTime == nil, let t = softTime(for: s.text(of: m.range)) else { return false }
            sc.softTime = t
            return true
        }
    )

    static func softTime(for phrase: String) -> TimeOfDay? {
        let p = phrase.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        if p.hasPrefix("يوم ") { return softTime(for: String(p.dropFirst(4))) }
        if p == "صباح" { return TimeOfDay(hour: 9) }
        if p == "ليله" { return TimeOfDay(hour: 20) }
        return Lex.softTimes.first { $0.1.contains(p) }?.0
    }
}

extension TextScanner {
    func text(of r: NSRange) -> String { (text as NSString).substring(with: r) }
}
