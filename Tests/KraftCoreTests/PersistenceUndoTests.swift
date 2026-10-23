import Foundation
import Testing
@testable import KraftCore

/// A clock the tests move by hand.
@MainActor
final class TestClock {
    var now = Fixture.t0
    func advance(_ seconds: TimeInterval) { now = now.addingTimeInterval(seconds) }
}

@MainActor
@Suite struct PersistenceUndoTests {
    let clock = TestClock()
    let undo: UndoManager
    let repo: StickyRepository
    let note = Fixture.sticky("Gift idea")

    init() {
        undo = UndoManager()
        undo.groupsByEvent = false
        let clock = clock
        repo = StickyRepository(records: [note], now: { clock.now })
        repo.undoManager = undo
    }

    func edit(_ title: String, coalesce: Bool = true, after seconds: TimeInterval = 0.4) {
        clock.advance(seconds)
        var s = repo.sticky(note.id)!
        s.title = title
        repo.update(s, actionName: "Edit Sticky", coalesce: coalesce)
    }

    @Test func addUndoesToTombstoneAndRedoes() {
        let new = Fixture.sticky("ملاحظة")
        repo.add(new, actionName: "Add Sticky")
        #expect(undo.undoActionName == "Add Sticky")
        undo.undo()
        #expect(repo.sticky(new.id)?.deletedAt != nil)
        #expect(undo.redoActionName == "Add Sticky")
        undo.redo()
        #expect(repo.sticky(new.id)?.deletedAt == nil)
        #expect(repo.sticky(new.id)?.title == "ملاحظة")
    }

    @Test func deleteUndoAndRedo() {
        clock.advance(1)
        repo.delete(note.id, actionName: "Delete Sticky")
        #expect(repo.sticky(note.id)?.deletedAt == clock.now)
        clock.advance(1)
        undo.undo()
        #expect(repo.sticky(note.id)?.deletedAt == nil)
        #expect(repo.sticky(note.id)?.updatedAt == clock.now, "restores are stamped now so they win the next merge")
        undo.redo()
        #expect(repo.sticky(note.id)?.deletedAt != nil)
    }

    @Test func rapidEditsCoalesceIntoOneStep() {
        for title in ["G", "Gi", "Gif", "Gift!"] { edit(title) }
        #expect(repo.sticky(note.id)?.title == "Gift!")
        undo.undo()
        #expect(repo.sticky(note.id)?.title == "Gift idea")
        #expect(!undo.canUndo)
        undo.redo()
        #expect(repo.sticky(note.id)?.title == "Gift!")
    }

    @Test func pauseStartsANewStep() {
        edit("one")
        edit("one two")
        edit("one two three", after: 1.6)
        undo.undo()
        #expect(repo.sticky(note.id)?.title == "one two")
        undo.undo()
        #expect(repo.sticky(note.id)?.title == "Gift idea")
    }

    @Test func otherStickyOrOtherActionBreaksCoalescing() {
        let other = Fixture.sticky("other")
        repo.add(other, actionName: "Add Sticky")
        edit("a")
        repo.modify(other.id, actionName: "Edit Sticky", coalesce: true) { $0.body = "x" }
        edit("ab")
        undo.undo()
        #expect(repo.sticky(note.id)?.title == "a")
        undo.undo()
        #expect(repo.sticky(other.id)?.body == "")
    }

    @Test func undoEndsTheCoalescedStep() {
        edit("a")
        undo.undo()
        edit("b")
        edit("bc")
        undo.undo()
        #expect(repo.sticky(note.id)?.title == "Gift idea")
    }

    @Test func uncoalescedEditsAreSeparateSteps() {
        edit("a", coalesce: false)
        edit("ab", coalesce: false)
        undo.undo()
        #expect(repo.sticky(note.id)?.title == "a")
    }

    @Test func tickItemIsNamedAndUndoable() {
        let item = ChecklistItem(text: "حليب")
        var todo = Fixture.sticky("List")
        todo.checklist = [item]
        repo.add(todo, actionName: "Add Sticky")
        repo.modify(todo.id, actionName: "Tick Item") { $0.checklist[0].isDone.toggle() }
        #expect(undo.undoActionName == "Tick Item")
        undo.undo()
        #expect(repo.sticky(todo.id)?.checklist[0].isDone == false)
        undo.redo()
        #expect(repo.sticky(todo.id)?.checklist[0].isDone == true)
    }

    /// A window's undo manager groups by run-loop event (our groups nest inside it); each event must
    /// still be one named step. Sleeping lets the main run loop close the event group.
    @Test func worksWithEventGrouping() async throws {
        let windowUndo = UndoManager()
        repo.undoManager = windowUndo
        repo.add(Fixture.sticky("one"), actionName: "Add Sticky")
        try await Task.sleep(for: .milliseconds(30))
        edit("typed", coalesce: false)
        try await Task.sleep(for: .milliseconds(30))
        #expect(windowUndo.undoActionName == "Edit Sticky")
        windowUndo.undo()
        #expect(repo.sticky(note.id)?.title == "Gift idea")
        #expect(windowUndo.undoActionName == "Add Sticky")
        windowUndo.undo()
        #expect(repo.records.filter { $0.deletedAt == nil }.count == 1)
        windowUndo.redo()
        #expect(repo.records.filter { $0.deletedAt == nil }.count == 2)
    }

    @Test func noUndoManagerStillMutates() {
        repo.undoManager = nil
        edit("no undo")
        #expect(repo.sticky(note.id)?.title == "no undo")
        #expect(!undo.canUndo)
    }

    @Test func updateBumpsUpdatedAtAndSkipsNoOps() {
        clock.advance(3)
        repo.update(repo.sticky(note.id)!, actionName: "Edit Sticky")
        #expect(!undo.canUndo)
        edit("changed", coalesce: false)
        #expect(repo.sticky(note.id)?.updatedAt == clock.now)
    }
}
