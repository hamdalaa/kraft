import CoreGraphics
import Foundation
import Testing
@testable import KraftCore

@Suite struct DesktopLayoutTests {
    /// A 1440×900 display with a 25 pt menu bar.
    let screen = CGRect(x: 0, y: 0, width: 1440, height: 875)
    let layout = DesktopLayout()
    let medium = CGSize(width: 204, height: 204)

    private func assertNoOverlap(_ rects: [CGRect], sourceLocation: SourceLocation = #_sourceLocation) {
        for (i, a) in rects.enumerated() {
            for b in rects[(i + 1)...] {
                #expect(!a.intersects(b), "\(a) overlaps \(b)", sourceLocation: sourceLocation)
            }
        }
    }

    @Test func firstSlotIsTopTrailingCornerInsideMargins() {
        let r = layout.place(medium, in: screen, avoiding: [])
        #expect(r == CGRect(x: 1440 - 24 - 204, y: 875 - 24 - 204, width: 204, height: 204))
    }

    @Test func rightToLeftStartsTopLeft() {
        var rtl = layout
        rtl.direction = .rightToLeft
        let r = rtl.place(medium, in: screen, avoiding: [])
        #expect(r.origin == CGPoint(x: 24, y: 875 - 24 - 204))
    }

    @Test func fillsDownwardThenMovesOneColumnTowardLeading() {
        var placed: [CGRect] = []
        for _ in 0..<4 { placed.append(layout.place(medium, in: screen, avoiding: placed)) }
        #expect(placed[0].minX == placed[1].minX && placed[1].minX == placed[2].minX)
        #expect(placed[0].minY > placed[1].minY && placed[1].minY > placed[2].minY)
        #expect(placed[3].maxY == placed[0].maxY)
        #expect(placed[3].maxX == placed[0].maxX - (layout.cell + layout.gutter))
    }

    @Test func mixedSizesShareTheTrailingEdgeOfTheirColumn() {
        let small = layout.place(CGSize(width: 176, height: 176), in: screen, avoiding: [])
        let large = layout.place(CGSize(width: 236, height: 236), in: screen, avoiding: [small])
        #expect(small.maxX == large.maxX)
        #expect(large.maxY == small.maxY - (layout.cell + layout.gutter))
    }

    @Test func manyStickiesNeverOverlapAndStayOnScreen() {
        let sizes = StickySize.allCases.map { CGSize(width: $0.side, height: $0.side) }
        var placed: [CGRect] = []
        for i in 0..<15 { placed.append(layout.place(sizes[i % 3], in: screen, avoiding: placed)) }
        assertNoOverlap(placed)
        for r in placed { #expect(screen.insetBy(dx: layout.margin, dy: layout.margin).contains(r)) }
    }

    @Test func skipsASlotCoveredByAHandPlacedSticky() {
        let first = layout.place(medium, in: screen, avoiding: [])
        let dragged = first.offsetBy(dx: -30, dy: -20)
        let next = layout.place(medium, in: screen, avoiding: [dragged])
        #expect(next.minX == first.minX)
        #expect(next.maxY == first.maxY - (layout.cell + layout.gutter))
    }

    @Test func findsAGapOffTheGridWhenEveryCellIsBlocked() {
        // One wide paper per grid row blocks every cell but leaves room below the last row.
        let blockers = layout.slots(for: medium, in: screen).map { $0.insetBy(dx: -10, dy: -10) }
        let tall = CGRect(x: 0, y: 0, width: 100, height: 10)
        let r = layout.place(CGSize(width: 40, height: 40), in: screen, avoiding: blockers + [tall])
        #expect(layout.isFree(r, avoiding: blockers + [tall]))
        #expect(screen.contains(r))
    }

    @Test func fullScreenCascadesButStaysVisible() {
        let wall = [screen]
        let r = layout.place(medium, in: screen, avoiding: wall)
        #expect(screen.contains(r))
    }

    @Test func dropNearAFreeSlotSnapsToIt() {
        let slot = layout.place(medium, in: screen, avoiding: [])
        let drop = slot.offsetBy(dx: -20, dy: 25)
        #expect(layout.snap(drop, screens: [screen], avoiding: []) == slot)
    }

    @Test func dropFarFromAnySlotStaysWhereItWasDropped() {
        let drop = CGRect(x: 600, y: 330, width: 204, height: 204)
        #expect(layout.snap(drop, screens: [screen], avoiding: []) == drop)
    }

    @Test func dropNearAnOccupiedSlotDoesNotSnapOntoTheOtherSticky() {
        let slot = layout.place(medium, in: screen, avoiding: [])
        let drop = slot.offsetBy(dx: -20, dy: -25)
        #expect(layout.snap(drop, screens: [screen], avoiding: [slot]) == drop)
    }

    @Test func dropHalfOffScreenIsPulledBackInside() {
        let drop = CGRect(x: 1350, y: -90, width: 204, height: 204)
        let r = layout.snap(drop, screens: [screen], avoiding: [])
        #expect(screen.insetBy(dx: layout.margin, dy: layout.margin).contains(r))
    }

    @Test func clampMovesAStickyFromAMissingDisplayOntoTheRemainingOne() {
        let onOldDisplay = CGRect(x: 2200, y: 300, width: 204, height: 204)
        let r = layout.clamp(onOldDisplay, to: [screen])
        #expect(screen.contains(r))
        #expect(r.maxX == screen.maxX - layout.margin)
    }

    @Test func screenForPicksTheDisplayWithTheLargestShare() {
        let second = CGRect(x: 1440, y: 0, width: 1920, height: 1055)
        let straddling = CGRect(x: 1400, y: 300, width: 204, height: 204)
        #expect(layout.screen(for: straddling, in: [screen, second]) == second)
    }

    @Test func tidyLaysEveryStickyIntoSlotsInReadingOrder() {
        let messy: [(id: Int, rect: CGRect)] = [
            (1, CGRect(x: 300, y: 200, width: 204, height: 204)),
            (2, CGRect(x: 1180, y: 600, width: 176, height: 176)),
            (3, CGRect(x: 1150, y: 120, width: 236, height: 236)),
        ]
        let tidy = layout.tidy(messy, screens: [screen])
        let slot0 = layout.slots(for: CGSize(width: 176, height: 176), in: screen)[0]
        let slot1 = layout.slots(for: CGSize(width: 236, height: 236), in: screen)[1]
        let slot2 = layout.slots(for: medium, in: screen)[2]
        #expect(tidy[2] == slot0)
        #expect(tidy[3] == slot1)
        #expect(tidy[1] == slot2, "third in reading order takes the third slot of the first column")
        assertNoOverlap(Array(tidy.values))
    }

    @Test func tidyKeepsEachStickyOnItsOwnDisplay() {
        let second = CGRect(x: 1440, y: 0, width: 1920, height: 1055)
        let items: [(id: String, rect: CGRect)] = [("a", CGRect(x: 100, y: 100, width: 204, height: 204)),
                                                   ("b", CGRect(x: 2000, y: 100, width: 204, height: 204))]
        let tidy = layout.tidy(items, screens: [screen, second])
        #expect(tidy["a"].map(screen.contains) == true)
        #expect(tidy["b"].map(second.contains) == true)
    }

    @Test func relocateKeepsOnScreenStickiesAndRehomesOrphansWithoutOverlap() {
        let home = layout.place(medium, in: screen, avoiding: [])
        let items: [(id: Int, rect: CGRect)] = [
            (1, home),
            // Was on a display that is gone; clamping would land it on top of sticky 1.
            (2, home.offsetBy(dx: 900, dy: 0)),
        ]
        let moved = layout.relocate(items, screens: [screen])
        #expect(moved[1] == home)
        let orphan = try! #require(moved[2])
        #expect(screen.contains(orphan))
        #expect(!orphan.intersects(home))
    }
}

@Suite struct DesktopPinTests {
    @Test func originIsTheTopLeftOfThePaper() {
        let rect = CGRect(x: 100, y: 300, width: 204, height: 204)
        let point = DesktopPoint(topLeftOf: rect)
        #expect(point == DesktopPoint(x: 100, y: 504))
        #expect(point.paperRect(side: 204) == rect)
        // A bigger paper still hangs from the same corner.
        #expect(point.paperRect(side: 236).maxY == 504)
    }

    @Test func unpinningForgetsTheSpot() {
        let s = Sticky(kind: .note, isOnDesktop: true, desktopOrigin: DesktopPoint(x: 1, y: 2))
        let removed = s.pinnedToDesktop(false)
        #expect(!removed.isOnDesktop)
        #expect(removed.desktopOrigin == nil)
        #expect(removed.pinnedToDesktop(true).isOnDesktop)
        #expect(s.isOnDesktop, "original is untouched")
    }

    @Test func deletedStickiesLeaveTheDesktop() {
        var s = Sticky(kind: .note, isOnDesktop: true)
        #expect(s.showsOnDesktop)
        s.deletedAt = Date()
        #expect(!s.showsOnDesktop)
    }

    @Test func movedOnDesktopStoresTheNewCorner() {
        let s = Sticky(kind: .todo).movedOnDesktop(to: CGRect(x: 10, y: 20, width: 176, height: 176))
        #expect(s.desktopOrigin == DesktopPoint(x: 10, y: 196))
    }
}
