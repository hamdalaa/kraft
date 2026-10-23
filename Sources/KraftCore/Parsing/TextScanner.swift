import Foundation

/// Normalised view of the input with a claim mask, so each rule takes a phrase exactly once and
/// whatever nobody claimed becomes the title.
///
/// Matching runs on `text`: Latin lower-cased, Arabic-Indic digits → ASCII, أ/إ/آ → ا, ى → ي, ة → ه,
/// harakat and tatweel removed, ، → ",". `map` takes any UTF-16 offset in `text` back to the original.
struct TextScanner {
    let original: String
    let text: String
    private let ns: NSString
    private let map: [String.Index]
    private(set) var claimed: [Bool]
    private(set) var spans: [(ParsedSpan.Field, NSRange)] = []

    init(_ original: String) {
        self.original = original
        var out = ""
        var map: [String.Index] = []
        var i = original.startIndex
        while i < original.endIndex {
            let next = original.index(after: i)
            let piece = Self.normalize(original[i])
            out += piece
            map += Array(repeating: i, count: piece.utf16.count)
            i = next
        }
        map.append(original.endIndex)
        self.text = out
        self.ns = out as NSString
        self.map = map
        self.claimed = Array(repeating: false, count: ns.length)
    }

    var length: Int { ns.length }

    // MARK: Matching

    func isFree(_ r: NSRange) -> Bool {
        guard r.location != NSNotFound, r.length > 0 else { return false }
        return !claimed[r.location..<(r.location + r.length)].contains(true)
    }

    /// Every match whose whole range is still unclaimed.
    func freeMatches(_ regex: NSRegularExpression) -> [NSTextCheckingResult] {
        regex.matches(in: text, range: NSRange(location: 0, length: length)).filter { isFree($0.range) }
    }

    func firstFree(_ regex: NSRegularExpression) -> NSTextCheckingResult? { freeMatches(regex).first }

    /// First free match among patterns tried in order (longer phrasings first).
    func firstFree(_ regexes: [NSRegularExpression]) -> NSTextCheckingResult? {
        for r in regexes { if let m = firstFree(r) { return m } }
        return nil
    }

    func group(_ m: NSTextCheckingResult, _ i: Int) -> String? {
        guard i < m.numberOfRanges else { return nil }
        let r = m.range(at: i)
        return r.location == NSNotFound ? nil : ns.substring(with: r)
    }

    func group(_ m: NSTextCheckingResult, _ name: String) -> String? {
        let r = m.range(withName: name)
        return r.location == NSNotFound ? nil : ns.substring(with: r)
    }

    // MARK: Claims

    mutating func claim(_ r: NSRange, as field: ParsedSpan.Field?) {
        let r = trimmed(r)
        guard r.length > 0 else { return }
        for k in r.location..<(r.location + r.length) { claimed[k] = true }
        if let field { spans.append((field, r)) }
    }

    mutating func release(_ field: ParsedSpan.Field) {
        for (f, r) in spans where f == field {
            for k in r.location..<(r.location + r.length) { claimed[k] = false }
        }
        spans.removeAll { $0.0 == field }
    }

    mutating func unclaim(_ r: NSRange) {
        guard r.length > 0 else { return }
        for k in r.location..<(r.location + r.length) { claimed[k] = false }
        spans.removeAll { NSIntersectionRange($0.1, r).length > 0 }
    }

    func hasSpan(_ field: ParsedSpan.Field) -> Bool { spans.contains { $0.0 == field } }

    /// Spans mapped back onto the original text, in reading order.
    func parsedSpans() -> [ParsedSpan] {
        spans.sorted { $0.1.location < $1.1.location }.map { field, r in
            let range = originalRange(r)
            return ParsedSpan(field: field, range: range, text: String(original[range]))
        }
    }

    func originalRange(_ r: NSRange) -> Range<String.Index> {
        map[r.location]..<map[r.location + r.length]
    }

    func originalText(_ r: NSRange) -> String { String(original[originalRange(r)]) }

    /// Drops surrounding whitespace so spans highlight the words, not the gaps.
    private func trimmed(_ r: NSRange) -> NSRange {
        var lo = r.location, hi = r.location + r.length
        while lo < hi, Self.isSpace(ns.character(at: lo)) { lo += 1 }
        while hi > lo, Self.isSpace(ns.character(at: hi - 1)) { hi -= 1 }
        return NSRange(location: lo, length: hi - lo)
    }

    // MARK: Words around a trigger (people's names)

    /// Up to `max` unclaimed words starting at `offset`, stopping at punctuation, digits or `stop` words.
    func words(after offset: Int, max: Int, stop: Set<String>) -> NSRange? {
        var ranges: [NSRange] = []
        var k = offset
        while ranges.count < max {
            while k < length, Self.isSpace(ns.character(at: k)) { k += 1 }
            guard let w = word(at: k) else { break }
            if stop.contains(ns.substring(with: w)) { break }
            ranges.append(w)
            k = w.location + w.length
        }
        return union(ranges)
    }

    /// Up to `max` unclaimed words ending right before `offset`.
    func words(before offset: Int, max: Int, stop: Set<String>) -> NSRange? {
        var ranges: [NSRange] = []
        var k = offset
        while ranges.count < max {
            while k > 0, Self.isSpace(ns.character(at: k - 1)) { k -= 1 }
            guard k > 0 else { break }
            var lo = k
            while lo > 0, Self.isWordUnit(ns.character(at: lo - 1)) { lo -= 1 }
            let w = NSRange(location: lo, length: k - lo)
            guard w.length > 0, isFree(w), !Self.hasDigit(ns.substring(with: w)) else { break }
            if stop.contains(ns.substring(with: w)) { break }
            ranges.insert(w, at: 0)
            k = lo
        }
        return union(ranges)
    }

    private func word(at k: Int) -> NSRange? {
        var hi = k
        while hi < length, Self.isWordUnit(ns.character(at: hi)) { hi += 1 }
        let w = NSRange(location: k, length: hi - k)
        guard w.length > 0, isFree(w), !Self.hasDigit(ns.substring(with: w)) else { return nil }
        return w
    }

    private func union(_ ranges: [NSRange]) -> NSRange? {
        guard let first = ranges.first, let last = ranges.last else { return nil }
        return NSRange(location: first.location, length: last.location + last.length - first.location)
    }

    // MARK: Leftovers

    /// The original text with every claimed phrase removed. Newlines survive (lists), runs of spaces collapse.
    func remainder() -> String {
        var out = ""
        var k = 0
        while k < length {
            var hi = k
            let isClaimed = claimed[k]
            while hi < length, claimed[hi] == isClaimed { hi += 1 }
            out += isClaimed ? " " : originalText(NSRange(location: k, length: hi - k))
            k = hi
        }
        return out
            .replacingOccurrences(of: "[ \\t]+", with: " ", options: .regularExpression)
            .replacingOccurrences(of: " ?\\n ?", with: "\n", options: .regularExpression)
    }

    // MARK: Character classes

    private static func isSpace(_ u: unichar) -> Bool { u == 0x20 || u == 0x09 || u == 0x0A || u == 0x0D || u == 0xA0 }

    private static func isWordUnit(_ u: unichar) -> Bool {
        guard let s = Unicode.Scalar(u) else { return true } // surrogate halves: part of a word
        return s.properties.isAlphabetic || s.properties.generalCategory == .nonspacingMark || s == "'" || s == "-"
    }

    private static func hasDigit(_ s: String) -> Bool { s.contains { $0.isASCII && $0.isNumber } }

    // MARK: Normalisation

    static func normalize(_ c: Character) -> String {
        var out = ""
        for s in c.unicodeScalars {
            switch s.value {
            case 0x0660...0x0669: out.unicodeScalars.append(Unicode.Scalar(s.value - 0x0660 + 0x30)!)
            case 0x06F0...0x06F9: out.unicodeScalars.append(Unicode.Scalar(s.value - 0x06F0 + 0x30)!)
            case 0x064B...0x065F, 0x0670, 0x0640: continue // harakat, superscript alef, tatweel
            case 0x0622, 0x0623, 0x0625, 0x0671: out += "ا"
            case 0x0649, 0x06CC: out += "ي"
            case 0x0629: out += "ه"
            case 0x06A9: out += "ك"
            case 0x060C: out += ","
            case 0x061B: out += ";"
            case 0x061F: out += "?"
            case 0x066B: out += "."
            case 0x066C: out += ","
            case 0x00A0: out += " "
            default:
                if s.properties.generalCategory == .nonspacingMark, out.isEmpty { continue }
                out += String(s).lowercased()
            }
        }
        return out
    }
}

extension NSRegularExpression {
    /// Case-insensitive pattern; the lexicon is trusted, so a bad pattern is a programmer error.
    static func make(_ pattern: String) -> NSRegularExpression {
        do {
            return try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
        } catch {
            preconditionFailure("QuickParser: bad pattern \(pattern): \(error)")
        }
    }
}
