import CoreGraphics
import Foundation

/// Tidy, non-overlapping placement for stickies pinned to the Mac desktop.
///
/// Every rect is a paper footprint (no shadow or fastener) in AppKit screen coordinates: origin at the
/// bottom-left of the main display, y grows upward. Screens are passed as their `visibleFrame`
/// (menu bar and Dock already excluded).
///
/// The grid starts at the top-trailing corner of a screen and fills downward, then moves one column
/// toward the leading edge, the way Finder arranges desktop icons.
public struct DesktopLayout: Sendable, Equatable {
    /// Space kept clear along the screen edges.
    public var margin: CGFloat
    /// Grid cell side; the largest paper fits exactly.
    public var cell: CGFloat
    /// Space between grid cells; leaves room for tape, pins and shadows.
    public var gutter: CGFloat
    /// The closest two papers may be placed to each other.
    public var minGap: CGFloat
    /// A dropped paper snaps to a free slot whose origin is at most this far away.
    public var snapDistance: CGFloat
    /// `.rightToLeft` mirrors the grid: first column on the left.
    public var direction: ScriptDirection

    public init(margin: CGFloat = 24, cell: CGFloat = StickySize.large.side, gutter: CGFloat = 30,
                minGap: CGFloat = 14, snapDistance: CGFloat = 56, direction: ScriptDirection = .leftToRight) {
        self.margin = margin
        self.cell = cell
        self.gutter = gutter
        self.minGap = minGap
        self.snapDistance = snapDistance
        self.direction = direction
    }

    /// Lattice step for the fallback search when every grid slot is taken.
    static let fineStep: CGFloat = 12
    /// Offset between papers when the screen is completely full.
    static let cascadeStep: CGFloat = 24

    // MARK: Slots

    /// Grid slots for a paper of `size` on one screen, in fill order. The paper hugs the
    /// top-trailing corner of its cell so every column shares a clean trailing edge.
    public func slots(for size: CGSize, in visible: CGRect) -> [CGRect] {
        let cellSize = CGSize(width: max(cell, size.width), height: max(cell, size.height))
        return lattice(for: size, in: visible, step: CGSize(width: cellSize.width + gutter, height: cellSize.height + gutter),
                       reserve: cellSize)
    }

    /// Candidate positions in fill order: columns from the trailing edge, each column top to bottom.
    /// `reserve` is the footprint each candidate must fit (a whole cell for the grid, the paper for the lattice).
    func lattice(for size: CGSize, in visible: CGRect, step: CGSize, reserve: CGSize) -> [CGRect] {
        let area = visible.insetBy(dx: margin, dy: margin)
        guard !area.isNull, area.width >= size.width, area.height >= size.height else { return [] }
        let columns = max(1, Int(((area.width - reserve.width) / step.width).rounded(.down)) + 1)
        let rows = max(1, Int(((area.height - reserve.height) / step.height).rounded(.down)) + 1)
        var result: [CGRect] = []
        result.reserveCapacity(columns * rows)
        for column in 0..<columns {
            let shift = CGFloat(column) * step.width
            let x = direction == .leftToRight ? area.maxX - shift - size.width : area.minX + shift
            for row in 0..<rows {
                let top = area.maxY - CGFloat(row) * step.height
                result.append(CGRect(x: x, y: top - size.height, width: size.width, height: size.height))
            }
        }
        return result
    }

    /// True when `rect` keeps at least `minGap` from every paper in `others`.
    public func isFree(_ rect: CGRect, avoiding others: [CGRect]) -> Bool {
        let padded = rect.insetBy(dx: -minGap, dy: -minGap)
        return !others.contains { padded.intersects($0) }
    }

    // MARK: Placement

    /// Where a new paper goes: the first free grid slot; failing that, the first free spot on a fine
    /// lattice (other papers were dragged into odd places). Only a screen with no room left at all
    /// makes papers overlap, as a short cascade from the first slot.
    public func place(_ size: CGSize, in visible: CGRect, avoiding others: [CGRect]) -> CGRect {
        let grid = slots(for: size, in: visible)
        if let free = grid.first(where: { isFree($0, avoiding: others) }) { return free }
        let fine = lattice(for: size, in: visible, step: CGSize(width: Self.fineStep, height: Self.fineStep), reserve: size)
        if let free = fine.first(where: { isFree($0, avoiding: others) }) { return free }
        let base = grid.first ?? clamp(CGRect(origin: visible.origin, size: size), to: [visible])
        let n = CGFloat(others.count % 8)
        let sign: CGFloat = direction == .leftToRight ? -1 : 1
        return clamp(base.offsetBy(dx: sign * n * Self.cascadeStep, dy: -n * Self.cascadeStep), to: [visible])
    }

    /// Where a dragged paper lands: the nearest free slot if it is within `snapDistance`,
    /// otherwise the drop spot itself, pulled fully on-screen.
    public func snap(_ rect: CGRect, screens: [CGRect], avoiding others: [CGRect]) -> CGRect {
        let dropped = clamp(rect, to: screens)
        guard let screen = screen(for: dropped, in: screens) else { return dropped }
        let nearest = slots(for: dropped.size, in: screen)
            .filter { isFree($0, avoiding: others) }
            .min { distance($0.origin, dropped.origin) < distance($1.origin, dropped.origin) }
        if let nearest, distance(nearest.origin, dropped.origin) <= snapDistance { return nearest }
        return dropped
    }

    // MARK: Screens

    /// The screen a paper belongs to: the one it overlaps most, else the nearest one.
    public func screen(for rect: CGRect, in screens: [CGRect]) -> CGRect? {
        func shared(_ screen: CGRect) -> CGFloat {
            let overlap = screen.intersection(rect)
            return overlap.isNull ? 0 : overlap.width * overlap.height
        }
        if let best = screens.max(by: { shared($0) < shared($1) }), shared(best) > 0 { return best }
        return screens.min { distance($0.center, rect.center) < distance($1.center, rect.center) }
    }

    /// Pulls a paper fully inside its screen's margins. A paper taller or wider than the screen keeps
    /// its top-leading corner visible.
    public func clamp(_ rect: CGRect, to screens: [CGRect]) -> CGRect {
        guard let screen = screen(for: rect, in: screens) else { return rect }
        let inset = screen.insetBy(dx: margin, dy: margin)
        let area = inset.isNull ? screen : inset
        let x = direction == .leftToRight
            ? max(area.minX, min(rect.minX, area.maxX - rect.width))
            : min(area.maxX - rect.width, max(rect.minX, area.minX))
        let y = min(area.maxY - rect.height, max(rect.minY, area.minY))
        return CGRect(x: x, y: y, width: rect.width, height: rect.height)
    }

    // MARK: Whole-desktop passes

    /// "Tidy Desktop Stickies": every paper moves into grid slots on the screen it is on, keeping the
    /// current reading order (trailing column first, top to bottom).
    public func tidy<ID: Hashable>(_ items: [(id: ID, rect: CGRect)], screens: [CGRect]) -> [ID: CGRect] {
        var result: [ID: CGRect] = [:]
        for screen in screens {
            let mine = items.filter { self.screen(for: $0.rect, in: screens) == screen }
            var placed: [CGRect] = []
            for item in readingOrder(mine, in: screen) {
                let rect = place(item.rect.size, in: screen, avoiding: placed)
                placed.append(rect)
                result[item.id] = rect
            }
        }
        return result
    }

    /// After displays change: papers still fully on a screen stay put; the rest are pulled on-screen,
    /// and given a fresh slot if pulling them in would cover another paper.
    public func relocate<ID: Hashable>(_ items: [(id: ID, rect: CGRect)], screens: [CGRect]) -> [ID: CGRect] {
        guard !screens.isEmpty else { return Dictionary(items.map { ($0.id, $0.rect) }, uniquingKeysWith: { a, _ in a }) }
        var result: [ID: CGRect] = [:]
        var placed: [CGRect] = []
        let (kept, moved) = items.partitioned { item in screens.contains { $0.contains(item.rect) } }
        for item in kept {
            result[item.id] = item.rect
            placed.append(item.rect)
        }
        for item in moved {
            var rect = clamp(item.rect, to: screens)
            if !isFree(rect, avoiding: placed), let screen = screen(for: rect, in: screens) {
                rect = place(rect.size, in: screen, avoiding: placed)
            }
            result[item.id] = rect
            placed.append(rect)
        }
        return result
    }

    private func readingOrder<ID>(_ items: [(id: ID, rect: CGRect)], in screen: CGRect) -> [(id: ID, rect: CGRect)] {
        let pitch = cell + gutter
        func column(_ r: CGRect) -> Int {
            let fromTrailing = direction == .leftToRight ? screen.maxX - r.maxX : r.minX - screen.minX
            return Int((max(0, fromTrailing) / pitch).rounded(.down))
        }
        return items.sorted { a, b in
            let ca = column(a.rect), cb = column(b.rect)
            return ca != cb ? ca < cb : a.rect.maxY > b.rect.maxY
        }
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat { hypot(a.x - b.x, a.y - b.y) }
}

private extension CGRect {
    var center: CGPoint { CGPoint(x: midX, y: midY) }
}

private extension Array {
    func partitioned(by belongsInFirst: (Element) -> Bool) -> ([Element], [Element]) {
        var first: [Element] = [], second: [Element] = []
        for element in self {
            if belongsInFirst(element) { first.append(element) } else { second.append(element) }
        }
        return (first, second)
    }
}
