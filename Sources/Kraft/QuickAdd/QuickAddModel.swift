import Foundation
import KraftCore
import Observation

/// State of one quick-add session: the sentence, the corrections made in the tags, and the paper it will land on.
@MainActor
@Observable
final class QuickAddModel {
    var text: String {
        didSet {
            // A fresh sentence starts with fresh guesses.
            if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { edits = QuickEdits() }
        }
    }
    var edits = QuickEdits()
    /// Chosen once per session so the preview doesn't wobble while typing.
    let tilt: Double

    init(text: String = "", tilt: Double = [-2.4, -1.6, 1.4, 2.2].randomElement() ?? -1.6) {
        self.text = text
        self.tilt = tilt
    }

    var isBlank: Bool { text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    /// Re-read on every keystroke; cheap (a few dozen regexes over one sentence).
    func parse(now: Date = Date()) -> ParsedSticky {
        ParsedSticky.reading(text, edits: edits, now: now)
    }

    func sticky(for parsed: ParsedSticky, now: Date = Date()) -> Sticky {
        parsed.makeSticky(style: PaperStyle.quickAdd(for: parsed.kind, tilt: tilt), now: now)
    }

    /// Adds the sticky. Returns false (and adds nothing) when there is nothing written.
    @discardableResult
    func commit(to store: StickyStore) -> Bool {
        guard !isBlank else { return false }
        store.add(sticky(for: parse()))
        return true
    }

    func setKind(_ kind: StickyKind) {
        var e = edits
        e.kind = kind
        edits = e
    }
}

extension PaperStyle {
    /// The paper each kind lands on, matching the sample board (owes me = mint + tape, reminder = lemon + pin…).
    static func quickAdd(for kind: StickyKind, tilt: Double) -> PaperStyle {
        switch kind {
        case .note: PaperStyle(color: .white, ruling: .grid, fastener: .clip, tilt: tilt)
        case .todo: PaperStyle(color: .sky, ruling: .lines, tilt: tilt)
        case .reminder: PaperStyle(color: .lemon, fastener: .pin, tilt: tilt)
        case .owedToMe: PaperStyle(color: .mint, fastener: .tape, tilt: tilt)
        case .iOwe: PaperStyle(color: .pink, fastener: .tape, tilt: tilt)
        case .bill: PaperStyle(color: .peach, tilt: tilt)
        }
    }
}

extension StickyKind {
    var quickAddName: String {
        switch self {
        case .note: String(localized: "Note")
        case .todo: String(localized: "To-do")
        case .reminder: String(localized: "Reminder")
        case .owedToMe: String(localized: "Owes me")
        case .iOwe: String(localized: "I owe")
        case .bill: String(localized: "Bill")
        }
    }
}
