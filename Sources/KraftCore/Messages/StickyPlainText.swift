import Foundation

public extension Sticky {
    /// The paper as plain text for the clipboard: title, body, then the checklist as ☐ / ☑ lines.
    var plainText: String {
        let lines = [title, body].map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            + checklist.map { "\($0.isDone ? "☑" : "☐") \($0.text)" }
        return lines.filter { !$0.isEmpty }.joined(separator: "\n")
    }
}
