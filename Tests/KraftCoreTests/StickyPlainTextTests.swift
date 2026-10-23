import Foundation
import KraftCore
import Testing

@Suite struct StickyPlainTextTests {
    @Test func titleBodyAndChecklistInOrder() {
        var s = Sticky(kind: .todo, title: " Groceries ", body: "")
        s.checklist = [ChecklistItem(text: "Milk", isDone: false), ChecklistItem(text: "Bread", isDone: true)]
        #expect(s.plainText == "Groceries\n☐ Milk\n☑ Bread")
    }

    @Test func emptyPartsAreSkipped() {
        #expect(Sticky(kind: .note, title: "", body: "Call Sara").plainText == "Call Sara")
    }
}
