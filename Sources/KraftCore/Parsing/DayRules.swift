import Foundation

/// Day phrases: today/tomorrow, weekdays, the 1st, 15/11, 3 Nov, next week, أول الشهر…
extension DateRules {
    static func dayRules(now: Date, cal: Calendar) -> [Rule] {
        let today = cal.startOfDay(for: now)
        @Sendable func plus(_ n: Int) -> Date? { cal.date(byAdding: .day, value: n, to: today) }
        let enLead = "(?:(?:on|by|before|until|till|due|for|this|next|coming)\\s+)*"
        let arLead = "(?:(?:قبل|لحد|الى|حتى|في|لغايه)\\s+)?"
        let arTomorrow = "(?:بكره|بكرا|باجر|باچر|غدا|الغد|باكر)"
        let arNext = "(?:\\s+(?:الجاي|الجايه|القادم|القادمه|الياي|الجايي))?"
        let shortSafe = "monday|tuesday|wednesday|thursday|friday|saturday|sunday|mon|tues|tue|thurs|thur|thu|fri"

        return [
            (.make("\(l)(?:the\\s+)?day\\s+after\\s+(?:tomorrow|tmrw)\(r)|\(l)(?:بعد|عقب)\\s+\(arTomorrow)\(r)"), { _, _, sc in
                setDay(plus(2), &sc)
            }),
            (.make("\(l)(?:(?:by|until|till|for|on)\\s+)?(today|tonight|tomorrow|tmrw|tmr|tomorow|tommorow|tommorrow)\(r)"), { m, s, sc in
                let w = s.group(m, 1) ?? ""
                if w == "tonight" { sc.softTime = sc.softTime ?? TimeOfDay(hour: 20) }
                return setDay(plus(w == "today" || w == "tonight" ? 0 : 1), &sc)
            }),
            (.make("\(l)\(arLead)(اليوم|الليله|\(arTomorrow))\(r)"), { m, s, sc in
                let w = s.group(m, 1) ?? ""
                if w == "الليله" { sc.softTime = sc.softTime ?? TimeOfDay(hour: 20) }
                return setDay(plus(w == "اليوم" || w == "الليله" ? 0 : 1), &sc)
            }),
            (.make("\(l)\(enLead)(\(shortSafe))\(r)|\(l)(?:on|by|this|next|before|until)\\s+(sat|sun|wed)\(r)"), { m, s, sc in
                setWeekday(Lex.weekday(named: s.group(m, 1) ?? s.group(m, 2) ?? ""), &sc)
            }),
            (.make("\(l)\(arLead)(?:ب?يوم\\s+)?ال(\(Lex.arabicWeekday))\(arNext)\(r)|\(l)\(arLead)ب?يوم\\s+(\(Lex.arabicWeekday))\(arNext)\(r)"), { m, s, sc in
                setWeekday(Lex.weekday(named: s.group(m, 1) ?? s.group(m, 2) ?? ""), &sc)
            }),
            // 15/11, 15/11/2026, 2026-11-15
            (.make("\(l)\(enLead)\(arLead)(\\d{1,2})/(\\d{1,2})(?:/(\\d{2,4}))?\(r)"), { m, s, sc in
                setDate(day: Int(s.group(m, 1) ?? ""), month: Int(s.group(m, 2) ?? ""), year: s.group(m, 3).flatMap { Int($0) },
                        today: today, cal: cal, &sc)
            }),
            (.make("\(l)(\\d{4})-(\\d{1,2})-(\\d{1,2})\(r)"), { m, s, sc in
                setDate(day: Int(s.group(m, 3) ?? ""), month: Int(s.group(m, 2) ?? ""), year: Int(s.group(m, 1) ?? ""),
                        today: today, cal: cal, &sc)
            }),
            // 3 Nov, 15 تموز, 15 شهر 11, Nov 3rd
            (.make("\(l)\(enLead)\(arLead)(?:يوم\\s+)?(?:the\\s+)?(\\d{1,2})(?:st|nd|rd|th)?\\s+(?:of\\s+)?(\(Lex.monthName))\(r)"), { m, s, sc in
                setDate(day: Int(s.group(m, 1) ?? ""), month: Lex.month(named: s.group(m, 2) ?? ""), year: nil, today: today, cal: cal, &sc)
            }),
            (.make("\(l)\(arLead)(?:يوم\\s+)?(\\d{1,2})\\s+(?:من\\s+)?شهر\\s+(\\d{1,2})\(r)"), { m, s, sc in
                setDate(day: Int(s.group(m, 1) ?? ""), month: Int(s.group(m, 2) ?? ""), year: nil, today: today, cal: cal, &sc)
            }),
            (.make("\(l)\(enLead)(\(Lex.monthName))\\s+(\\d{1,2})(?:st|nd|rd|th)?\(r)"), { m, s, sc in
                setDate(day: Int(s.group(m, 2) ?? ""), month: Lex.month(named: s.group(m, 1) ?? ""), year: nil, today: today, cal: cal, &sc)
            }),
            // the 1st, by the 15th, on the 3
            (.make("\(l)\(enLead)(?:the\\s+)?(\\d{1,2})(?:st|nd|rd|th)(?:\\s+of\\s+(?:the\\s+|this\\s+|next\\s+)?month)?\(r)|\(l)(?:on|by|before|until|due)\\s+the\\s+(\\d{1,2})\(r)"), { m, s, sc in
                setDayOfMonth(Int(s.group(m, 1) ?? s.group(m, 2) ?? ""), &sc)
            }),
            (.make("\(l)\(arLead)ب?يوم\\s+(\\d{1,2})(?:\\s+(?:بالشهر|من\\s+الشهر|الشهر|من\\s+هذا\\s+الشهر))?\(r)"), { m, s, sc in
                setDayOfMonth(Int(s.group(m, 1) ?? ""), &sc)
            }),
            // start / middle / end of the month, أول الشهر، نص الشهر، آخر الشهر
            (.make("\(l)(?:(?:by|at|on|until|before)\\s+)?(?:the\\s+)?(start|beginning|middle|mid|end)(?:\\s+of)?(?:\\s+the|\\s+this)?\\s*-?month\(r)"), { m, s, sc in
                monthPart(s.group(m, 1) ?? "", today: today, cal: cal, &sc)
            }),
            (.make("\(l)\(arLead)ب?(اول|بدايه|راس|نص|منتصف|نهايه|اخر|اخير)\\s+(?:ال)?شهر\(arNext)\(r)"), { m, s, sc in
                monthPart(s.group(m, 1) ?? "", today: today, cal: cal, &sc)
            }),
            // next week / month / year, الأسبوع الجاي، الشهر القادم
            (.make("\(l)(?:(?:by|until|before|in)\\s+)?next\\s+(week|month|year)\(r)|\(l)\(arLead)ب?ال(اسبوع|سبوع|شهر|سنه)\\s+(?:الجاي|الجايه|القادم|القادمه|الياي)\(r)"), { m, s, sc in
                let unit = s.group(m, 1) ?? s.group(m, 2) ?? ""
                switch unit {
                case "week", "اسبوع", "سبوع": return setDay(plus(7), &sc)
                case "month", "شهر":
                    let start = cal.dateInterval(of: .month, for: today)?.start ?? today
                    return setDay(cal.date(byAdding: .month, value: 1, to: start), &sc)
                default:
                    let start = cal.dateInterval(of: .year, for: today)?.start ?? today
                    return setDay(cal.date(byAdding: .year, value: 1, to: start), &sc)
                }
            }),
        ]
    }

    private static func setDay(_ d: Date?, _ sc: inout Schedule) -> Bool {
        guard let d, sc.day == nil, sc.weekday == nil, sc.dayOfMonth == nil else { return false }
        sc.day = d
        return true
    }

    private static func setWeekday(_ w: Int?, _ sc: inout Schedule) -> Bool {
        guard let w, sc.day == nil, sc.dayOfMonth == nil, sc.weekday == nil || sc.weekday == w else { return false }
        sc.weekday = w
        return true
    }

    private static func setDayOfMonth(_ d: Int?, _ sc: inout Schedule) -> Bool {
        guard let d, (1...31).contains(d), sc.day == nil, sc.weekday == nil, sc.dayOfMonth == nil || sc.dayOfMonth == d else { return false }
        sc.dayOfMonth = d
        return true
    }

    private static func setDate(day: Int?, month: Int?, year: Int?, today: Date, cal: Calendar, _ sc: inout Schedule) -> Bool {
        guard let day, let month, (1...31).contains(day), (1...12).contains(month) else { return false }
        let thisYear = cal.component(.year, from: today)
        var y = year.map { $0 < 100 ? 2000 + $0 : $0 } ?? thisYear
        guard var date = cal.date(from: DateComponents(year: y, month: month, day: day)),
              cal.component(.day, from: date) == day else { return false }
        if year == nil, date < today {
            y += 1
            date = cal.date(from: DateComponents(year: y, month: month, day: day)) ?? date
        }
        return setDay(date, &sc)
    }

    private static func monthPart(_ word: String, today: Date, cal: Calendar, _ sc: inout Schedule) -> Bool {
        switch word {
        case "start", "beginning", "اول", "بدايه", "راس": return setDayOfMonth(1, &sc)
        case "middle", "mid", "نص", "منتصف": return setDayOfMonth(15, &sc)
        default:
            // Last day of this month (or next month's, when today already is the last day).
            guard let month = cal.dateInterval(of: .month, for: today),
                  var last = cal.date(byAdding: .day, value: -1, to: month.end) else { return false }
            if last <= today, let next = cal.date(byAdding: .month, value: 1, to: month.start),
               let nextMonth = cal.dateInterval(of: .month, for: next) {
                last = cal.date(byAdding: .day, value: -1, to: nextMonth.end) ?? last
            }
            return setDay(cal.startOfDay(for: last), &sc)
        }
    }
}
