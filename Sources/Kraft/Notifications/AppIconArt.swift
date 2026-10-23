import SwiftUI

/// The app icon, drawn in a 512 pt space (rendered @2x → 1024 px): a die-cut sticker of a taped sticky note
/// (ref-6/7: bold ink, flat bright fill, white die-cut edge, offset shadow) pressed onto a kraft-paper tile
/// laid out on the macOS icon grid (824/1024 tile, 100 px margins, soft drop shadow).
struct AppIconArt: View {
    static let canvas: CGFloat = 512
    static let tile: CGFloat = 412

    var body: some View {
        ZStack {
            KraftTile()
                .frame(width: Self.tile, height: Self.tile)
            StickerNote()
                .frame(width: StickerNote.box, height: StickerNote.box)
                .rotationEffect(.degrees(-8))
                .scaleEffect(1.1)
                .offset(x: 2, y: 6)
        }
        .frame(width: Self.canvas, height: Self.canvas)
        .accessibilityHidden(true)
    }
}

/// Rounded-square kraft card: warm top light, fibre grain, a pressed edge and a 1 pt highlight for thickness.
private struct KraftTile: View {
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: AppIconArt.tile * 0.225, style: .continuous)
        shape
            .fill(LinearGradient(colors: [Tok.Kraft.light, Tok.Kraft.base, Tok.Kraft.base.mix(with: Tok.Kraft.deep, by: 0.45)],
                                 startPoint: .top, endPoint: .bottom))
            .overlay { GrainOverlay(image: Grain.kraft, opacity: 0.55).blendMode(.multiply).clipShape(shape) }
            .overlay {
                // Light catching the top edge, a little shade gathering at the bottom.
                shape.strokeBorder(LinearGradient(colors: [.white.opacity(0.55), .white.opacity(0), .black.opacity(0.10)],
                                                  startPoint: .top, endPoint: .bottom), lineWidth: 3)
            }
            .overlay { shape.strokeBorder(Tok.Kraft.deep.opacity(0.55), lineWidth: 1) }
            .compositingGroup()
            .shadow(color: .black.opacity(0.18), radius: 1, y: 1)
            .shadow(color: .black.opacity(0.26), radius: 9, y: 7)
    }
}

/// The sticker: yellow note with a folded corner and three written lines, pink washi tape across the top.
private struct StickerNote: View {
    static let box: CGFloat = 300
    static let note = CGRect(x: 47, y: 62, width: 206, height: 206)
    static let ear: CGFloat = 54
    static let inkWidth: CGFloat = 11
    static let dieCut: CGFloat = 15

    var body: some View {
        let silhouette = Self.notePath().union(Self.tapePath())
        let ink = Tok.Sticker.ink
        ZStack {
            // Offset shadow (flat, ink-tinted) and the white die-cut edge, both following the silhouette.
            DieCut(path: silhouette, width: Self.dieCut)
                .fill(ink.opacity(0.24))
                .offset(x: 5, y: 9)
            DieCut(path: silhouette, width: Self.dieCut)
                .fill(.white)
                .shadow(color: .black.opacity(0.14), radius: 7, y: 6)

            PathShape(path: Self.notePath()).fill(Tok.Sticker.yellow)
            PathShape(path: Self.linesPath()).fill(ink)
            PathShape(path: Self.earPath()).fill(Tok.Sticker.yellow.mix(with: Color(hex: 0xE89A2C), by: 0.45))
            PathShape(path: Self.earPath()).stroke(ink, style: StrokeStyle(lineWidth: Self.inkWidth, lineJoin: .round))
            PathShape(path: Self.notePath()).stroke(ink, style: StrokeStyle(lineWidth: Self.inkWidth, lineJoin: .round))

            PathShape(path: Self.tapePath()).fill(Tok.Sticker.pink)
            PathShape(path: Self.tapeShinePath()).fill(.white.opacity(0.45))
            PathShape(path: Self.tapePath()).stroke(ink, style: StrokeStyle(lineWidth: Self.inkWidth * 0.8, lineJoin: .round))
        }
        .compositingGroup()
    }

    // MARK: Geometry (300 × 300 box)

    /// Note outline: rounded square whose bottom-trailing corner is folded away.
    static func notePath() -> Path {
        let r = note, c: CGFloat = 16
        var p = Path()
        p.move(to: CGPoint(x: r.minX + c, y: r.minY))
        p.addArc(tangent1End: CGPoint(x: r.maxX, y: r.minY), tangent2End: CGPoint(x: r.maxX, y: r.maxY), radius: c)
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - ear))
        p.addLine(to: CGPoint(x: r.maxX - ear, y: r.maxY))
        p.addArc(tangent1End: CGPoint(x: r.minX, y: r.maxY), tangent2End: CGPoint(x: r.minX, y: r.minY), radius: c)
        p.addArc(tangent1End: CGPoint(x: r.minX, y: r.minY), tangent2End: CGPoint(x: r.maxX, y: r.minY), radius: c)
        p.closeSubpath()
        return p
    }

    /// The folded-over flap, its tip rounded.
    static func earPath() -> Path {
        let r = note
        let a = CGPoint(x: r.maxX, y: r.maxY - ear), b = CGPoint(x: r.maxX - ear, y: r.maxY)
        let tip = CGPoint(x: r.maxX - ear, y: r.maxY - ear)
        var p = Path()
        p.move(to: a)
        p.addArc(tangent1End: tip, tangent2End: b, radius: 10)
        p.addLine(to: b)
        p.closeSubpath()
        return p
    }

    /// Three handwritten lines as bold rounded strokes; the last is short.
    static func linesPath() -> Path {
        var p = Path()
        let x = note.minX + 34, h: CGFloat = 13
        for (i, w) in [CGFloat(138), 138, 88].enumerated() {
            let y = note.minY + 74 + CGFloat(i) * 36
            p.addRoundedRect(in: CGRect(x: x, y: y, width: w, height: h), cornerSize: CGSize(width: h / 2, height: h / 2))
        }
        return p
    }

    /// Washi tape strip across the top edge, with zig-zag torn ends.
    static func tapePath() -> Path {
        let w: CGFloat = 116, h: CGFloat = 40, teeth = 3, depth: CGFloat = 7
        let r = CGRect(x: -w / 2, y: -h / 2, width: w, height: h)
        let step = h / CGFloat(teeth)
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        for i in 0..<teeth {
            p.addLine(to: CGPoint(x: r.maxX - depth, y: r.minY + step * (CGFloat(i) + 0.5)))
            p.addLine(to: CGPoint(x: r.maxX, y: r.minY + step * CGFloat(i + 1)))
        }
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        for i in (0..<teeth).reversed() {
            p.addLine(to: CGPoint(x: r.minX + depth, y: r.minY + step * (CGFloat(i) + 0.5)))
            p.addLine(to: CGPoint(x: r.minX, y: r.minY + step * CGFloat(i)))
        }
        p.closeSubpath()
        return p.applying(tapeTransform)
    }

    /// A flat highlight band along the tape's top third.
    static func tapeShinePath() -> Path {
        Path(roundedRect: CGRect(x: -44, y: -13, width: 80, height: 7), cornerRadius: 3.5).applying(tapeTransform)
    }

    private static var tapeTransform: CGAffineTransform {
        CGAffineTransform(translationX: note.midX + 4, y: note.minY + 2).rotated(by: 6 * .pi / 180)
    }
}

/// A path grown outward by `width` (round joins): the die-cut silhouette.
private struct DieCut: Shape {
    let path: Path
    let width: CGFloat

    func path(in rect: CGRect) -> Path {
        path.union(path.strokedPath(StrokeStyle(lineWidth: width * 2, lineCap: .round, lineJoin: .round)))
    }
}

private struct PathShape: Shape {
    let path: Path
    func path(in rect: CGRect) -> Path { path }
}
