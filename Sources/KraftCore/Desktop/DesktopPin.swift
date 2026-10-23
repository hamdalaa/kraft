import CoreGraphics
import Foundation

/// `Sticky.desktopOrigin` is the paper's top-left corner in AppKit screen coordinates (y up), so a
/// paper that changes size stays hanging from the same spot.
public extension DesktopPoint {
    init(topLeftOf rect: CGRect) {
        self.init(x: Double(rect.minX), y: Double(rect.maxY))
    }

    /// The paper footprint for a square paper of `side` hanging from this point.
    func paperRect(side: Double) -> CGRect {
        CGRect(x: x, y: y - side, width: side, height: side)
    }
}

public extension Sticky {
    /// On the desktop and not deleted: gets a desktop window.
    var showsOnDesktop: Bool { isOnDesktop && deletedAt == nil }

    /// Copy pinned to or removed from the desktop. Removing forgets the spot, so pinning again
    /// finds a fresh free slot instead of landing on whatever moved in meanwhile.
    func pinnedToDesktop(_ pinned: Bool) -> Sticky {
        var copy = self
        copy.isOnDesktop = pinned
        if !pinned { copy.desktopOrigin = nil }
        return copy
    }

    /// Copy hanging from the top-left of `rect`.
    func movedOnDesktop(to rect: CGRect) -> Sticky {
        var copy = self
        copy.desktopOrigin = DesktopPoint(topLeftOf: rect)
        return copy
    }
}
