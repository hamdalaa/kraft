import Foundation
import Testing
@testable import KraftCore

@Suite struct PersistenceMergeTests {
    let id = UUID()

    @Test func unionKeepsRecordsOnlyOneSideKnows() {
        let a = Fixture.sticky("Mac only"), b = Fixture.sticky("iPhone only"), shared = Fixture.sticky("Both")
        let merged = StickyMerge.merge(local: [a, shared], remote: [shared, b])
        #expect(merged.map(\.title) == ["Mac only", "Both", "iPhone only"])
    }

    @Test func newerUpdateWinsEitherWay() {
        let old = Fixture.sticky("old", id: id, updated: 10), new = Fixture.sticky("جديد", id: id, updated: 20)
        #expect(StickyMerge.merge(local: [old], remote: [new]).map(\.title) == ["جديد"])
        #expect(StickyMerge.merge(local: [new], remote: [old]).map(\.title) == ["جديد"])
    }

    @Test func newerTombstoneBeatsOlderEdit() {
        let edit = Fixture.sticky("edit", id: id, updated: 10)
        let tomb = Fixture.sticky("edit", id: id, updated: 5, deleted: 20)
        #expect(StickyMerge.merge(local: [edit], remote: [tomb]).first?.deletedAt != nil)
        #expect(StickyMerge.merge(local: [tomb], remote: [edit]).first?.deletedAt != nil)
    }

    @Test func editMadeAfterDeleteWins() {
        let tomb = Fixture.sticky("x", id: id, updated: 10, deleted: 10)
        let later = Fixture.sticky("still needed", id: id, updated: 30)
        let merged = StickyMerge.merge(local: [tomb], remote: [later])
        #expect(merged.first?.deletedAt == nil)
        #expect(merged.first?.title == "still needed")
    }

    @Test func tieGoesToTombstone() {
        let live = Fixture.sticky("x", id: id, updated: 10)
        let tomb = Fixture.sticky("x", id: id, updated: 10, deleted: 10)
        #expect(StickyMerge.merge(local: [live], remote: [tomb]).first?.deletedAt != nil)
        #expect(StickyMerge.merge(local: [tomb], remote: [live]).first?.deletedAt != nil)
    }

    @Test func tieBetweenLiveEditsIsDeterministic() {
        let a = Fixture.sticky("Mac", id: id, updated: 10), b = Fixture.sticky("iPhone", id: id, updated: 10)
        let one = StickyMerge.merge(local: [a], remote: [b])
        let two = StickyMerge.merge(local: [b], remote: [a])
        #expect(one == two)
        #expect(one.count == 1)
    }

    @Test func mergeConvergesWhicheverSideIsLocal() {
        let ids = (0..<6).map { _ in UUID() }
        let mac = ids.enumerated().map { i, id in Fixture.sticky("mac \(i)", id: id, updated: Double(i % 3), deleted: i == 4 ? 9 : nil) }
        let phone = ids.dropFirst(2).enumerated().map { i, id in Fixture.sticky("phone \(i)", id: id, updated: Double(2 - i % 3)) }
            + [Fixture.sticky("phone new")]
        let one = StickyMerge.merge(local: mac, remote: phone)
        let two = StickyMerge.merge(local: phone, remote: mac)
        #expect(Set(one) == Set(two))
        #expect(one.count == 7)
        #expect(StickyMerge.merge(local: one, remote: phone) == one)
    }

    @Test func duplicateIdsCollapseToTheWinner() {
        let a = Fixture.sticky("a", id: id, updated: 1), b = Fixture.sticky("b", id: id, updated: 2)
        #expect(StickyMerge.merge(local: [a, b], remote: []).map(\.title) == ["b"])
    }

    @Test func purgeDropsOnlyOldTombstones() {
        let now = Fixture.at(100 * 86_400)
        let ancient = Fixture.sticky("ancient", deleted: 9 * 86_400)
        let recent = Fixture.sticky("recent", deleted: 11 * 86_400)
        let live = Fixture.sticky("live")
        #expect(StickyMerge.purgeTombstones([ancient, recent, live], now: now).map(\.title) == ["recent", "live"])
    }
}
