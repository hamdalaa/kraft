import SwiftUI

/// Flowing rows like stickies pressed onto a board by hand: wraps to the width, then nudges each
/// item by a small deterministic offset so the board never reads as a uniform grid.
struct CollageLayout: Layout {
    var hSpacing: CGFloat = 40
    var vSpacing: CGFloat = 46
    var jitter: CGFloat = 9

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 1000
        let rows = rows(subviews: subviews, width: width)
        let height = rows.reduce(0) { $0 + $1.height } + vSpacing * CGFloat(max(0, rows.count - 1)) + jitter * 2
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY + jitter
        for row in rows(subviews: subviews, width: bounds.width) {
            var x = bounds.minX + (bounds.width - row.width) / 2
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                let dx = Self.noise(index, 1) * jitter
                let dy = Self.noise(index, 2) * jitter + (row.height - size.height) * 0.35
                subviews[index].place(at: CGPoint(x: x + dx, y: y + dy), proposal: .unspecified)
                x += size.width + hSpacing
            }
            y += row.height + vSpacing
        }
    }

    private struct Row { var indices: [Int] = []; var width: CGFloat = 0; var height: CGFloat = 0 }

    /// Greedy wrap gives the row count; items are then spread evenly (5 → 3+2, never 4+1).
    private func rows(subviews: Subviews, width: CGFloat) -> [Row] {
        let rowCount = greedyRows(subviews: subviews, width: width).count
        guard rowCount > 1 else { return greedyRows(subviews: subviews, width: width) }
        let perRow = Int((Double(subviews.count) / Double(rowCount)).rounded(.up))
        var rows: [Row] = []
        for start in stride(from: 0, to: subviews.count, by: perRow) {
            var row = Row()
            for index in start..<min(start + perRow, subviews.count) {
                let size = subviews[index].sizeThatFits(.unspecified)
                row.width += (row.indices.isEmpty ? 0 : hSpacing) + size.width
                row.height = max(row.height, size.height)
                row.indices.append(index)
            }
            rows.append(row)
        }
        return rows
    }

    private func greedyRows(subviews: Subviews, width: CGFloat) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let added = current.indices.isEmpty ? size.width : current.width + hSpacing + size.width
            if added > width, !current.indices.isEmpty {
                rows.append(current)
                current = Row()
            }
            current.width = current.indices.isEmpty ? size.width : current.width + hSpacing + size.width
            current.height = max(current.height, size.height)
            current.indices.append(index)
        }
        if !current.indices.isEmpty { rows.append(current) }
        return rows
    }

    /// Stable pseudo-random value in −1…1.
    private static func noise(_ i: Int, _ salt: Int) -> CGFloat {
        let v = sin(Double(i * 127 + salt * 311) * 12.9898) * 43758.5453
        return CGFloat((v - v.rounded(.down)) * 2 - 1)
    }
}
