import KraftCore
import SwiftUI

/// SwiftUI stand-in for `HandwritingField` in snapshot mode (ImageRenderer cannot draw AppKit views).
/// Same faces, direction and highlighter marks.
struct HandwritingReplica: View {
    let text: String
    var marks: [FieldMark] = []
    var size: CGFloat = 25

    var body: some View {
        let hand = Hand(text: text)
        composed
            .font(hand.font(size))
            .foregroundStyle(Tok.Card.text.opacity(0.92))
            .lineSpacing(size * 0.3)
            .textRenderer(HighlighterRenderer())
            .frame(maxWidth: .infinity, alignment: .leading)
            .environment(\.layoutDirection, hand.layoutDirection)
    }

    private var composed: Text {
        var pieces: [Text] = []
        var cursor = text.startIndex
        for m in marks.sorted(by: { $0.range.lowerBound < $1.range.lowerBound }) where m.range.lowerBound >= cursor {
            pieces.append(Text(text[cursor..<m.range.lowerBound]))
            pieces.append(Text(text[m.range]).customAttribute(Highlight(color: m.color)))
            cursor = m.range.upperBound
        }
        pieces.append(Text(text[cursor...]))
        return pieces.reduce(Text(verbatim: "")) { Text("\($0)\($1)") }
    }
}

private struct Highlight: TextAttribute {
    let color: Color
}

/// Highlighter band under marked runs, then the glyphs on top — the same band as `HighlighterLayoutManager`.
private struct HighlighterRenderer: TextRenderer {
    func draw(layout: Text.Layout, in ctx: inout GraphicsContext) {
        for line in layout {
            for run in line {
                guard let mark = run[Highlight.self] else { continue }
                let r = run.typographicBounds.rect
                let band = CGRect(x: r.minX - 2, y: r.minY + r.height * 0.46, width: r.width + 4, height: r.height * 0.36)
                ctx.fill(Path(roundedRect: band, cornerRadius: band.height * 0.35), with: .color(mark.color))
            }
            ctx.draw(line)
        }
    }
}
