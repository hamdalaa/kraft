import Foundation

/// Understands one sentence, English or Arabic, and says what sticky it describes.
///
/// "Ali owes me 40$ friday" → owes me · Ali · $40 · due Friday.
/// "ذكرني بالدواء الساعة ٩ كل يوم" → reminder · الدواء · 09:00 daily.
///
/// Rules run in a fixed order and each claims its phrase: repeat → relative time → clock time → day →
/// money phrasing → amount → reminder / list phrasing → person. What nobody claimed becomes the title.
/// `kind` forces a kind (the user switched it in the UI); the sentence is then read for that kind.
public enum QuickParser {
    /// `currency` is what an amount means when none is written: the owner's default (Settings › Currency).
    public static func parse(_ text: String, now: Date = Date(), calendar: Calendar = .current,
                             kind forced: StickyKind? = nil, currency preferred: Currency = .preferred) -> ParsedSticky {
        var s = TextScanner(text)
        let direction = ScriptDirection.detect(text)
        let sched = DateRules.scan(&s, now: now, calendar: calendar)

        // Money phrasing.
        var trigger: (MoneyRules.Trigger, NSTextCheckingResult)?
        for t in MoneyRules.triggers {
            if let m = s.firstFree(t.regex) { trigger = (t, m); break }
        }
        let hasBillHint = s.firstFree(MoneyRules.billHint) != nil
        let allowBare = trigger != nil || forced?.isMoney == true || hasBillHint || sched.repeatRule != .never
        var amount = MoneyRules.amount(in: s, allowBare: allowBare, preferred: preferred)
        if let a = amount, a.isBare, trigger == nil, forced?.isMoney != true, !hasBillHint, a.value < 1000 {
            amount = nil // "every day drink 8 glasses" is not a bill
        }
        if let (t, _) = trigger, t.needsAmount, amount == nil { trigger = nil }
        let triggerRanges = trigger.map { t, m in t.slot == .named ? s.around(m, group: "p") : [m.range] } ?? []
        for r in triggerRanges { s.claim(r, as: .kind) }
        if let a = amount { s.claim(a.range, as: .amount) }

        // Reminder and list phrasing.
        let reminderTrigger = trigger == nil ? s.firstFree(KindRules.reminder) : nil
        if let m = reminderTrigger { s.claim(m.range, as: .kind) }
        let listHeader = trigger == nil && reminderTrigger == nil ? s.firstFree(KindRules.listHeader) : nil
        if let m = listHeader { s.claim(m.range, as: .kind) }

        // Decide the kind.
        let list = ListParts(s.remainderWithout(amount: amount?.range))
        let kind: StickyKind = forced ?? {
            if let (t, _) = trigger { return t.kind }
            if reminderTrigger != nil { return .reminder }
            if listHeader != nil { return .todo }
            if amount != nil && (sched.repeatRule != .never || hasBillHint) { return .bill }
            if list.isList { return .todo }
            if !sched.isEmpty { return .reminder }
            return .note
        }()

        // Give back what this kind does not use.
        if !kind.isMoney {
            s.release(.amount)
            for r in triggerRanges { s.unclaim(r) }
        }
        if kind != .reminder, let m = reminderTrigger { s.unclaim(m.range) }
        if kind != .todo, let m = listHeader { s.unclaim(m.range) }
        if kind == .note { s.release(.date); s.release(.time); s.release(.repeatRule) }

        // The person next to the money phrasing.
        var person: String?
        if kind == .owedToMe || kind == .iOwe, let (t, m) = trigger {
            let range: NSRange? = switch t.slot {
            case .before: s.words(before: m.range.location, max: 3, stop: Lex.nameStops)
            case .after: s.words(after: m.range.location + m.range.length, max: 2, stop: Lex.nameStops)
            case .named: m.range(withName: "p")
            }
            if let range, range.location != NSNotFound {
                person = s.originalText(range).trimmingCharacters(in: .whitespaces)
                s.claim(range, as: .person)
            }
        }

        var result = ParsedSticky(kind: kind, person: person, spans: [], direction: direction)
        if kind.isMoney, let amount {
            result.amount = amount.value
            result.currency = amount.currency ?? preferred
        }
        if kind != .note {
            result.repeatRule = sched.repeatRule
            (result.date, result.hasTime) = ScheduleResolver.resolve(sched, kind: kind, now: now, calendar: calendar)
        }
        Wording.fill(&result, remainder: s.remainder(), isArabic: direction == .rightToLeft)
        result.spans = s.parsedSpans()
        return result
    }
}

enum KindRules {
    private static let l = Lex.l, r = Lex.r

    static let reminder: [NSRegularExpression] = [
        .make("\(l)(?:please\\s+)?(?:remind|rmd)\\s+me\\s+(?:to|about|of|that)\\s+"),
        .make("\(l)(?:please\\s+)?remind\\s+me\(r)\\s*"),
        .make("\(l)reminder\\s*[:\\-]?\\s*"),
        .make("\(l)(?:don'?t|do\\s+not|dont)\\s+forget\\s+(?:to\\s+|about\\s+)?"),
        .make("\(l)remember\\s+to\\s+"),
        .make("\(l)(?:ذكرني|فكرني|نبهني|ذكريني|فكريني|ذكرنا|نبهيني)\\s*(?:ب(?=\\p{L}{3})|ان\\s+|اني\\s+|على\\s+|عن\\s+)"),
        .make("\(l)(?:ذكرني|فكرني|نبهني|ذكريني|فكريني|ذكرنا|نبهيني)\(r)\\s*"),
        .make("\(l)لا\\s*تنسي?\\s+(?:ان\\s+)?"),
        .make("\(l)تذكير\\s*[:\\-]?\\s*"),
    ]

    static let listHeader: [NSRegularExpression] = [
        .make("^\\s*(?:todo|to-do|to do|tasks?|checklist|list|مهام|قائمه|قائمه\\s+مهام|قائمة)\\s*[:\\-–]\\s*"),
    ]
}

extension TextScanner {
    /// The trigger minus the name captured inside it: "لـ" and "عندي" around "أحمد".
    func around(_ m: NSTextCheckingResult, group: String) -> [NSRange] {
        let g = m.range(withName: group)
        guard g.location != NSNotFound else { return [m.range] }
        let end = m.range.location + m.range.length, gEnd = g.location + g.length
        return [NSRange(location: m.range.location, length: g.location - m.range.location),
                NSRange(location: gEnd, length: end - gEnd)]
    }

    /// Remainder as if `amount` had not been claimed (to judge whether the rest reads like a list).
    func remainderWithout(amount: NSRange?) -> String {
        guard let amount else { return remainder() }
        var copy = self
        copy.unclaim(amount)
        return copy.remainder()
    }
}
