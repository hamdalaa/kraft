import Foundation

/// Reads leftover text as a list: "buy milk, bread, eggs", "Groceries: …", one item per line.
struct ListParts {
    var header: String?
    var verb: String?
    var items: [String] = []
    var lineCount = 1
    var isBulleted = false

    private static let verbs = NSRegularExpression.make(
        "^\\s*(buy|get|pick\\s+up|grab|shop\\s+for|اشتري|اشتر|اشتريلي|جيب|جيبلي|شراء|نشتري|لازم\\s+نشتري)\\s+")

    init(_ text: String) {
        var rest = text.trimmingCharacters(in: .whitespacesAndNewlines)
        lineCount = rest.split(whereSeparator: \.isNewline).count
        isBulleted = rest.range(of: "(?m)^\\s*(?:[-•*·–]|\\[ ?\\])\\s", options: .regularExpression) != nil
        if let colon = rest.firstIndex(of: ":"), rest.distance(from: rest.startIndex, to: colon) <= 32,
           !rest[..<colon].contains(where: \.isNewline) {
            let h = Wording.tidy(String(rest[..<colon]))
            if !h.isEmpty { header = h }
            rest = String(rest[rest.index(after: colon)...])
        }
        let ns = rest as NSString
        if let m = Self.verbs.firstMatch(in: rest, range: NSRange(location: 0, length: ns.length)) {
            verb = ns.substring(with: m.range(at: 1))
            rest = ns.substring(from: m.range.length)
        }
        let isArabic = ScriptDirection.detect(rest) == .rightToLeft
        var parts = rest.components(separatedBy: CharacterSet(charactersIn: ",،;\n"))
        if let last = parts.popLast() {
            // "milk, bread and eggs"; with a verb or header, "milk and bread" / "حليب وخبز" too.
            let joiner = header != nil || verb != nil || parts.count > 0
                ? (isArabic ? "\\s+و\\s*(?=\\S)" : "\\s+(?:and|&)\\s+") : "(?!)"
            parts += last.replacingOccurrences(of: joiner, with: "\u{1F}", options: [.regularExpression, .caseInsensitive])
                .components(separatedBy: "\u{1F}")
        }
        items = parts.map { Wording.tidy($0.replacingOccurrences(of: "^\\s*(?:[-•*·–]|\\[ ?\\])\\s*", with: "", options: .regularExpression)) }
            .filter { !$0.isEmpty }
    }

    /// Short comma lists ("milk, bread, eggs") or anything with a header, a shopping verb or several lines.
    var isList: Bool {
        let short = items.allSatisfy { $0.split(separator: " ").count <= 4 }
        if lineCount >= 2 && items.count >= 2 && (isBulleted || short) { return true }
        if (header != nil || verb != nil) && items.count >= 2 { return true }
        return items.count >= 3 && items.allSatisfy { $0.split(separator: " ").count <= 3 }
    }
}

/// Titles and bodies made from what was left over.
enum Wording {
    static func fill(_ p: inout ParsedSticky, remainder: String, isArabic: Bool) {
        let rest = tidy(remainder)
        switch p.kind {
        case .note:
            let lines = remainder.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: "\n")
            if lines.count > 1 {
                p.title = lines[0].trimmingCharacters(in: .whitespaces)
                p.body = lines.dropFirst().joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            } else if rest.count <= 40 {
                p.title = remainder.trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                p.body = remainder.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        case .todo:
            let list = ListParts(remainder)
            p.title = list.header ?? list.verb.map(capitalized) ?? ""
            p.checklist = list.items.map(capitalized)
            if p.checklist.isEmpty, !rest.isEmpty { p.checklist = [capitalized(rest)] }
        case .reminder:
            p.title = capitalized(rest)
        case .bill:
            p.title = rest.isEmpty ? (isArabic ? "فاتورة" : "Bill") : capitalized(rest)
        case .owedToMe, .iOwe:
            p.title = moneyTitle(p.kind, person: p.person, isArabic: isArabic)
            p.body = rest
        }
    }

    static func moneyTitle(_ kind: StickyKind, person: String?, isArabic: Bool) -> String {
        let name = person?.trimmingCharacters(in: .whitespaces) ?? ""
        switch (kind, isArabic, name.isEmpty) {
        case (.owedToMe, false, false): return "\(name) owes me"
        case (.owedToMe, false, true): return "Owed to me"
        case (.owedToMe, true, false): return "لي عند \(name)"
        case (.owedToMe, true, true): return "دين لي"
        case (_, false, false): return "I owe \(name)"
        case (_, false, true): return "I owe"
        case (_, true, false): return "مدين " + attachLam(name)
        default: return "دين علي"
        }
    }

    /// لـ + name, Arabic style: "لأحمد", "للحاج".
    static func attachLam(_ name: String) -> String {
        guard let first = name.unicodeScalars.first, ScriptDirection.isArabic(first) else { return "لـ" + name }
        return name.hasPrefix("ال") ? "ل" + name.dropFirst() : "ل" + name
    }

    private static let edgeWords: Set<String> = [
        "at", "on", "by", "to", "due", "for", "in", "from", "and", "about", "that", "of", "until", "before", "&",
        "في", "على", "ع", "يوم", "ب", "عن", "الى", "و", "حتى", "لحد", "قبل", "بتاريخ", "الساعه", "من", "بس",
    ]

    /// Trims spaces, stray punctuation and orphaned little words ("call mum at" → "call mum").
    static func tidy(_ text: String) -> String {
        var words = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: " ,.;:-–—!?،؛").union(.whitespacesAndNewlines))
            .split(separator: " ").map(String.init)
        while let w = words.first, edgeWords.contains(norm(w)) { words.removeFirst() }
        while let w = words.last, edgeWords.contains(norm(w)) || w == "the" { words.removeLast() }
        return words.joined(separator: " ").trimmingCharacters(in: CharacterSet(charactersIn: " ,.;:-–—!?،؛"))
    }

    private static func norm(_ w: String) -> String { w.map(TextScanner.normalize).joined() }

    static func capitalized(_ s: String) -> String {
        guard let first = s.first, first.isLowercase else { return s }
        return first.uppercased() + s.dropFirst()
    }
}
