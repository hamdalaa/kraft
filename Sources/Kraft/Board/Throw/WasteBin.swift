import KraftCore
import SwiftUI

/// Die-cut wastepaper basket (ref-6/7 sticker style): bold ink outline, flat sky fill, white border,
/// offset shadow. Paper balls of recently thrown stickies peek over the rim.
struct WasteBin: View {
    var balls: [Color] = []
    var isAwake = false
    var isTargeted = false
    var landings = 0

    private static let size = CGSize(width: 66, height: 74)
    private static let ballSpots: [(CGFloat, CGFloat)] = [(-12, -4), (11, -6), (-1, -13), (17, 1)]

    var body: some View {
        ZStack(alignment: .top) {
            // White die-cut border + offset shadow, from the silhouette.
            BinSilhouette().fill(Tok.Sticker.border)
                .overlay { BinSilhouette().stroke(Tok.Sticker.border, style: StrokeStyle(lineWidth: 12, lineJoin: .round)) }
                .shadow(color: Tok.Sticker.ink.opacity(0.22), radius: 0.6, x: 3, y: 4)
                .shadow(color: .black.opacity(0.12), radius: 5, y: 4)
            BinMouth().fill(Tok.Sticker.sky.mix(with: Tok.Sticker.ink, by: 0.5))
            ForEach(Array(balls.prefix(4).enumerated()), id: \.offset) { index, color in
                PaperBall(color: color, seed: UInt64(index + 11))
                    .frame(width: 26, height: 26)
                    .offset(x: Self.ballSpots[index].0, y: Self.ballSpots[index].1)
                    .transition(.offset(y: -40).combined(with: .opacity))
            }
            .frame(width: Self.size.width, height: Self.size.height, alignment: .top)
            BinFront().fill(Tok.Sticker.sky)
            BinSlats().stroke(Tok.Sticker.ink, style: StrokeStyle(lineWidth: 2, lineCap: .round))
            BinFront().stroke(Tok.Sticker.ink, style: StrokeStyle(lineWidth: 2.6, lineJoin: .round))
            BinMouth().stroke(Tok.Sticker.ink, lineWidth: 2.6)
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .keyframeAnimator(initialValue: CGSize(width: 1, height: 1), trigger: landings) { content, squash in
            content.scaleEffect(x: squash.width, y: squash.height, anchor: .bottom)
        } keyframes: { _ in
            SpringKeyframe(CGSize(width: 1.14, height: 0.84), duration: 0.12)
            SpringKeyframe(CGSize(width: 0.94, height: 1.08), duration: 0.16)
            SpringKeyframe(CGSize(width: 1, height: 1), duration: 0.3, spring: .bouncy)
        }
        .scaleEffect(isTargeted ? 1.2 : (isAwake ? 1.07 : 1), anchor: .bottom)
        .rotationEffect(.degrees(isTargeted ? -7 : 0), anchor: .bottom)
        .animation(.spring(duration: 0.35, bounce: 0.45), value: isTargeted)
        .animation(.spring(duration: 0.4, bounce: 0.3), value: isAwake)
        .animation(.spring(duration: 0.4), value: balls.count)
        .rotationEffect(.degrees(4))
    }
}

// MARK: - Shapes (drawn in a 66 × 74 box)

private enum BinGeometry {
    static let rim = CGRect(x: 4, y: 4, width: 58, height: 17)
    static let bottomInset: CGFloat = 9
    static let bottomY: CGFloat = 70

    /// Lower half of the rim ellipse, left → right.
    static func frontRim(in r: CGRect, steps: Int = 24) -> [CGPoint] {
        let e = rim.offsetBy(dx: r.minX, dy: r.minY)
        return (0...steps).map { i in
            let a = Double.pi - Double(i) / Double(steps) * .pi
            return CGPoint(x: e.midX + cos(a) * e.width / 2, y: e.midY + sin(a) * e.height / 2)
        }
    }
}

private struct BinMouth: Shape {
    func path(in r: CGRect) -> Path { Path(ellipseIn: BinGeometry.rim.offsetBy(dx: r.minX, dy: r.minY)) }
}

private struct BinFront: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let rim = BinGeometry.frontRim(in: r)
        p.addLines(rim)
        let right = CGPoint(x: r.minX + BinGeometry.rim.maxX - BinGeometry.bottomInset, y: r.minY + BinGeometry.bottomY)
        let left = CGPoint(x: r.minX + BinGeometry.rim.minX + BinGeometry.bottomInset, y: r.minY + BinGeometry.bottomY)
        p.addLine(to: CGPoint(x: right.x, y: right.y - 5))
        p.addQuadCurve(to: CGPoint(x: right.x - 6, y: right.y), control: right)
        p.addLine(to: CGPoint(x: left.x + 6, y: left.y))
        p.addQuadCurve(to: CGPoint(x: left.x, y: left.y - 5), control: left)
        p.closeSubpath()
        return p
    }
}

/// Vertical wicker slats converging toward the base.
private struct BinSlats: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let rim = BinGeometry.frontRim(in: r)
        let topL = BinGeometry.rim.minX, topR = BinGeometry.rim.maxX
        let botL = topL + BinGeometry.bottomInset, botR = topR - BinGeometry.bottomInset
        for k in 1...4 {
            let f = CGFloat(k) / 5
            let top = rim[Int(f * CGFloat(rim.count - 1))]
            p.move(to: CGPoint(x: top.x, y: top.y + 6))
            p.addLine(to: CGPoint(x: r.minX + botL + (botR - botL) * f, y: r.minY + BinGeometry.bottomY - 6))
        }
        return p
    }
}

private struct BinSilhouette: Shape {
    func path(in r: CGRect) -> Path {
        var p = BinFront().path(in: r)
        p.addPath(BinMouth().path(in: r))
        return p
    }
}

// MARK: - Interactive bin on the board

/// The bin in the board's corner: target for thrown stickies, "Put Back" right after a throw,
/// and a popover of recently thrown stickies.
struct WasteBinControl: View {
    @Bindable var model: BoardModel
    @Environment(ThrowController.self) private var thrower
    @State private var showingContents = false

    var body: some View {
        VStack(spacing: 10) {
            hint
            Button { showingContents.toggle() } label: {
                WasteBin(balls: model.recentlyThrown.prefix(4).map { $0.style.color.color(customHex: $0.style.customHex) },
                         isAwake: thrower.isHolding, isTargeted: thrower.isOverBin, landings: thrower.landings)
            }
            .buttonStyle(.plain)
            .help(Text("Thrown-away stickies"))
            .accessibilityLabel(Text("Thrown-away stickies"))
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(BoardSpace.name)) } action: { thrower.binFrame = $0 }
            .popover(isPresented: $showingContents, arrowEdge: .top) { BinContents(model: model) }
        }
        .animation(.spring(duration: 0.3), value: thrower.isHolding)
        .animation(.spring(duration: 0.3), value: thrower.lastThrown)
    }

    @ViewBuilder private var hint: some View {
        if thrower.isHolding {
            GlossyTag(text: thrower.isOverBin ? String(localized: "Let go") : String(localized: "Throw it here"),
                      symbol: "arrow.down", tint: .pink, size: .mini)
                .transition(.scale(scale: 0.8, anchor: .bottom).combined(with: .opacity))
        } else if let id = thrower.lastThrown {
            Button { model.restore(id); thrower.lastThrown = nil } label: {
                EmbossedLabel(text: String(localized: "Put Back"), symbol: "arrow.uturn.backward", tint: .pink, size: .mini)
            }
            .buttonStyle(GlossyButtonStyle(tint: .pink, size: .mini))
            .transition(.scale(scale: 0.8, anchor: .bottom).combined(with: .opacity))
        }
    }
}

private struct BinContents: View {
    @Bindable var model: BoardModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recently thrown away").font(.system(size: 13, weight: .semibold))
            if model.recentlyThrown.isEmpty {
                Text("The bin is empty.").font(.system(size: 13)).foregroundStyle(.secondary)
            }
            ForEach(model.recentlyThrown.prefix(8)) { sticky in
                HStack(spacing: 10) {
                    DieCutSticker(art: sticky.kind.sticker, size: 12, tilt: .degrees(-6)).padding(-3)
                    Text(sticky.primaryText.isEmpty ? String(localized: "Untitled") : sticky.primaryText)
                        .font(.system(size: 13))
                        .lineLimit(1)
                    Spacer(minLength: 12)
                    Button { model.restore(sticky.id) } label: {
                        EmbossedLabel(text: String(localized: "Put Back"), symbol: nil, tint: .blue, size: .mini)
                    }
                    .buttonStyle(GlossyButtonStyle(tint: .blue, size: .mini))
                }
            }
        }
        .padding(16)
        .frame(width: 300)
    }
}
