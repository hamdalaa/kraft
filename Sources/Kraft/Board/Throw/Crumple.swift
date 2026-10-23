import SwiftUI

/// Paper crumpling into a ball. The sticky's image is cut into a grid of triangles; each vertex
/// travels from its flat position to a point on a lumpy ball (edges fold first), and every facet is
/// drawn through the affine map from its flat triangle to its folded one, with its own light and shade.
/// Facets that flip over show the paper's plain back.
struct CrumpleView: View, Animatable {
    let image: Image
    let size: CGSize
    let paper: Color
    var progress: Double
    var seed: UInt64 = 7

    nonisolated var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    private static let cells = 7

    var body: some View {
        Canvas { ctx, _ in
            let mesh = CrumpleMesh(size: size, cells: Self.cells, seed: seed)
            let points = mesh.points(at: progress)
            let resolved = ctx.resolve(image)
            ctx.drawLayer { layer in
                // 1. Every facet carries its piece of the image (flipped facets mirror it).
                for tri in mesh.triangles {
                    let src = (mesh.flat[tri.a], mesh.flat[tri.b], mesh.flat[tri.c])
                    let dst = (points[tri.a], points[tri.b], points[tri.c])
                    guard let map = CGAffineTransform(mapping: src, to: dst) else { continue }
                    var facet = layer
                    facet.clip(to: Path.triangle(inflated(dst, by: 0.6)))
                    facet.concatenate(map)
                    facet.draw(resolved, in: CGRect(origin: .zero, size: size))
                }
                // 2. Light, shade and the paper's plain back — only where there is paper (source-atop).
                layer.blendMode = .sourceAtop
                for tri in mesh.triangles {
                    let src = (mesh.flat[tri.a], mesh.flat[tri.b], mesh.flat[tri.c])
                    let dst = (points[tri.a], points[tri.b], points[tri.c])
                    let path = Path.triangle(inflated(dst, by: 0.6))
                    if signedArea(src) * signedArea(dst) <= 0 {
                        layer.fill(path, with: .color(paper.mix(with: .black, by: 0.12)))
                    }
                    let shade = tri.shade * progress
                    layer.fill(path, with: .color(shade > 0 ? .black.opacity(shade * 0.32) : .white.opacity(-shade * 0.45)))
                }
            }
        }
        .frame(width: size.width, height: size.height)
        .accessibilityHidden(true)
    }

    private func signedArea(_ t: (CGPoint, CGPoint, CGPoint)) -> CGFloat {
        ((t.1.x - t.0.x) * (t.2.y - t.0.y) - (t.2.x - t.0.x) * (t.1.y - t.0.y)) / 2
    }

    /// Grows a triangle a hair around its centroid so neighbouring facets leave no seams.
    private func inflated(_ t: (CGPoint, CGPoint, CGPoint), by d: CGFloat) -> (CGPoint, CGPoint, CGPoint) {
        let c = CGPoint(x: (t.0.x + t.1.x + t.2.x) / 3, y: (t.0.y + t.1.y + t.2.y) / 3)
        func grow(_ p: CGPoint) -> CGPoint {
            let dx = p.x - c.x, dy = p.y - c.y, len = max(hypot(dx, dy), 0.001)
            return CGPoint(x: p.x + dx / len * d, y: p.y + dy / len * d)
        }
        return (grow(t.0), grow(t.1), grow(t.2))
    }
}

/// The deterministic geometry behind a crumple: flat grid, ball targets, per-vertex timing, facets.
struct CrumpleMesh {
    struct Triangle { let a: Int, b: Int, c: Int, shade: Double }

    let flat: [CGPoint]
    let ball: [CGPoint]
    let delay: [Double]
    let wobble: [CGVector]
    let triangles: [Triangle]

    init(size: CGSize, cells n: Int, seed: UInt64) {
        var rng = SplitMix64(seed: seed)
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let radius = min(size.width, size.height) * 0.2
        var flat: [CGPoint] = [], ball: [CGPoint] = [], delay: [Double] = [], wobble: [CGVector] = []
        for j in 0...n {
            for i in 0...n {
                let u = Double(i) / Double(n) * 2 - 1, v = Double(j) / Double(n) * 2 - 1
                flat.append(CGPoint(x: size.width * CGFloat(i) / CGFloat(n), y: size.height * CGFloat(j) / CGFloat(n)))
                // Square → disc, then a lumpy, inward-folded ball.
                let dx = u * (1 - v * v / 2).squareRoot(), dy = v * (1 - u * u / 2).squareRoot()
                let lump = 0.55 + rng.unit() * 0.5
                let spin = (rng.unit() - 0.5) * 1.2
                let x = dx * cos(spin) - dy * sin(spin), y = dx * sin(spin) + dy * cos(spin)
                ball.append(CGPoint(x: center.x + CGFloat(x * lump) * radius, y: center.y + CGFloat(y * lump) * radius))
                delay.append((1 - max(abs(u), abs(v))) * 0.4 + rng.unit() * 0.08)
                wobble.append(CGVector(dx: (rng.unit() - 0.5) * radius * 0.9, dy: (rng.unit() - 0.5) * radius * 0.9))
            }
        }
        var tris: [Triangle] = []
        let row = n + 1
        for j in 0..<n {
            for i in 0..<n {
                let p00 = j * row + i, p10 = p00 + 1, p01 = p00 + row, p11 = p01 + 1
                if rng.unit() < 0.5 {
                    tris.append(Triangle(a: p00, b: p10, c: p11, shade: rng.unit() * 2 - 1))
                    tris.append(Triangle(a: p00, b: p11, c: p01, shade: rng.unit() * 2 - 1))
                } else {
                    tris.append(Triangle(a: p00, b: p10, c: p01, shade: rng.unit() * 2 - 1))
                    tris.append(Triangle(a: p10, b: p11, c: p01, shade: rng.unit() * 2 - 1))
                }
            }
        }
        // Outer facets end up on top of the ball, like a real crumple.
        self.triangles = tris.sorted { delay[$0.a] > delay[$1.a] }
        self.flat = flat
        self.ball = ball
        self.delay = delay
        self.wobble = wobble
    }

    func points(at progress: Double) -> [CGPoint] {
        flat.indices.map { k in
            let raw = (progress * (1 + delay[k]) - delay[k])
            let t = smoothstep(min(max(raw, 0), 1))
            let bend = sin(t * .pi) // creases bulge out mid-fold
            return CGPoint(
                x: flat[k].x + (ball[k].x - flat[k].x) * t + wobble[k].dx * bend,
                y: flat[k].y + (ball[k].y - flat[k].y) * t + wobble[k].dy * bend
            )
        }
    }

    private func smoothstep(_ x: Double) -> Double { x * x * (3 - 2 * x) }
}

extension CGAffineTransform {
    /// The affine map taking triangle `s` onto triangle `d`; nil when `s` is degenerate.
    init?(mapping s: (CGPoint, CGPoint, CGPoint), to d: (CGPoint, CGPoint, CGPoint)) {
        let s1 = CGVector(dx: s.1.x - s.0.x, dy: s.1.y - s.0.y), s2 = CGVector(dx: s.2.x - s.0.x, dy: s.2.y - s.0.y)
        let d1 = CGVector(dx: d.1.x - d.0.x, dy: d.1.y - d.0.y), d2 = CGVector(dx: d.2.x - d.0.x, dy: d.2.y - d.0.y)
        let det = s1.dx * s2.dy - s2.dx * s1.dy
        guard abs(det) > 1e-6 else { return nil }
        // A = D · S⁻¹
        let i11 = s2.dy / det, i12 = -s2.dx / det, i21 = -s1.dy / det, i22 = s1.dx / det
        let a = d1.dx * i11 + d2.dx * i21, c = d1.dx * i12 + d2.dx * i22
        let b = d1.dy * i11 + d2.dy * i21, dd = d1.dy * i12 + d2.dy * i22
        self.init(a: a, b: b, c: c, d: dd, tx: d.0.x - (a * s.0.x + c * s.0.y), ty: d.0.y - (b * s.0.x + dd * s.0.y))
    }
}

extension Path {
    static func triangle(_ t: (CGPoint, CGPoint, CGPoint)) -> Path {
        var p = Path()
        p.move(to: t.0)
        p.addLine(to: t.1)
        p.addLine(to: t.2)
        p.closeSubpath()
        return p
    }
}

/// A finished paper ball sitting in the bin: lumpy outline, a few crease facets, sticker-ink edge.
struct PaperBall: View {
    let color: Color
    var seed: UInt64 = 3

    var body: some View {
        Canvas { ctx, size in
            var rng = SplitMix64(seed: seed)
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            let r = min(size.width, size.height) / 2 - 1.5
            let count = 9
            let rim: [CGPoint] = (0..<count).map { i in
                let a = Double(i) / Double(count) * 2 * .pi + rng.unit() * 0.3
                let rr = r * (0.82 + rng.unit() * 0.18)
                return CGPoint(x: c.x + cos(a) * rr, y: c.y + sin(a) * rr)
            }
            var outline = Path()
            outline.addLines(rim)
            outline.closeSubpath()
            ctx.fill(outline, with: .color(color))
            let inner = CGPoint(x: c.x + (rng.unit() - 0.5) * r * 0.5, y: c.y + (rng.unit() - 0.5) * r * 0.5)
            for i in 0..<count {
                let shade = rng.unit() * 2 - 1
                let facet = Path.triangle((inner, rim[i], rim[(i + 1) % count]))
                ctx.fill(facet, with: .color(shade > 0 ? .black.opacity(shade * 0.16) : .white.opacity(-shade * 0.35)))
                if rng.unit() < 0.6 {
                    var crease = Path()
                    crease.move(to: inner)
                    crease.addLine(to: rim[i])
                    ctx.stroke(crease, with: .color(Tok.Sticker.ink.opacity(0.22)), lineWidth: 0.8)
                }
            }
            ctx.stroke(outline, with: .color(Tok.Sticker.ink), style: StrokeStyle(lineWidth: 1.6, lineJoin: .round))
        }
        .accessibilityHidden(true)
    }
}
