import Foundation
@testable import KraftCore

/// Fixed clock for parser tests: Wednesday 21 October 2026, 10:30 in Baghdad.
enum PF {
    static let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Baghdad")!
        c.locale = Locale(identifier: "en_US_POSIX")
        return c
    }()

    static let now = date(2026, 10, 21, 10, 30)

    static func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0, _ min: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    static func parse(_ text: String, kind: StickyKind? = nil, now: Date = PF.now) -> ParsedSticky {
        QuickParser.parse(text, now: now, calendar: calendar, kind: kind)
    }
}

/// One row of a parser table. `nil` fields are not checked.
struct Expect: CustomTestStringConvertible, Sendable {
    let text: String
    var kind: StickyKind
    var title: String? = nil
    var body: String? = nil
    var person: String?? = nil
    var amount: Decimal? = nil
    var currency: Currency? = nil
    var date: Date?? = nil
    var hasTime: Bool? = nil
    var repeatRule: RepeatRule? = nil
    var checklist: [String]? = nil

    var testDescription: String { text }
}

import Testing

func check(_ e: Expect, now: Date = PF.now) {
    let p = PF.parse(e.text, now: now)
    #expect(p.kind == e.kind, "kind for \(e.text)")
    if let t = e.title { #expect(p.title == t, "title for \(e.text)") }
    if let b = e.body { #expect(p.body == b, "body for \(e.text)") }
    if let person = e.person { #expect(p.person == person, "person for \(e.text)") }
    if let a = e.amount { #expect(p.amount == a, "amount for \(e.text)") }
    if let c = e.currency { #expect(p.currency == c, "currency for \(e.text)") }
    if let d = e.date { #expect(p.date == d, "date for \(e.text): got \(String(describing: p.date))") }
    if let h = e.hasTime { #expect(p.hasTime == h, "hasTime for \(e.text)") }
    if let r = e.repeatRule { #expect(p.repeatRule == r, "repeat for \(e.text)") }
    if let c = e.checklist { #expect(p.checklist == c, "checklist for \(e.text)") }
}
