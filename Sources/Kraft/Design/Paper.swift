import KraftCore
import SwiftUI

/// The sticky paper itself: colour, adhesive band, grain, ruling, lifted-corner shadow, and a
/// bottom-trailing corner that peels up (`curl`, in points) when the note is picked up.
struct PaperSurface: View {
    let color: Color
    let ruling: Ruling
    var lifted = false
    var curl: CGFloat = 0
    /// Off when the paper is rendered to an image for crumpling (the crumple casts its own shadow).
    var castsShadow = true

    var body: some View {
        let shape = CurledPaperShape(curl: curl)
        shape
            .fill(color)
            .overlay {
                // Adhesive band at the top + gentle shading toward the curled bottom.
                shape.fill(LinearGradient(stops: [
                    .init(color: .black.opacity(0.035), location: 0),
                    .init(color: .black.opacity(0.035), location: 0.16),
                    .init(color: .black.opacity(0), location: 0.165),
                    .init(color: .black.opacity(0), location: 0.8),
                    .init(color: .black.opacity(0.045), location: 1),
                ], startPoint: .top, endPoint: .bottom))
            }
            .overlay {
                shape.fill(LinearGradient(colors: [.white.opacity(0.22), .white.opacity(0)], startPoint: .topLeading, endPoint: .center))
            }
            .overlay { RulingView(ruling: ruling).clipShape(shape) }
            .overlay { GrainOverlay(image: Grain.paper, opacity: 0.35).blendMode(.multiply).clipShape(shape) }
            .compositingGroup()
            .overlay { CurlFlap(curl: curl, color: color) }
            .background { if castsShadow { CurlShadow(lifted: lifted) } }
            .shadow(color: .black.opacity(castsShadow ? 0.16 : 0), radius: 0.8, y: 0.8)
    }
}

/// Paper outline with the bottom-trailing corner folded away.
struct CurledPaperShape: Shape {
    var curl: CGFloat
    var radius: CGFloat = 3

    var animatableData: CGFloat {
        get { curl }
        set { curl = newValue }
    }

    func path(in r: CGRect) -> Path {
        let c = min(max(curl, 0), r.width * 0.4)
        var p = Path()
        p.move(to: CGPoint(x: r.minX + radius, y: r.minY))
        p.addArc(tangent1End: CGPoint(x: r.maxX, y: r.minY), tangent2End: CGPoint(x: r.maxX, y: r.maxY), radius: radius)
        if c > 0.5 {
            p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - c))
            p.addLine(to: CGPoint(x: r.maxX - c, y: r.maxY))
        } else {
            p.addArc(tangent1End: CGPoint(x: r.maxX, y: r.maxY), tangent2End: CGPoint(x: r.minX, y: r.maxY), radius: radius)
        }
        p.addArc(tangent1End: CGPoint(x: r.minX, y: r.maxY), tangent2End: CGPoint(x: r.minX, y: r.minY), radius: radius)
        p.addArc(tangent1End: CGPoint(x: r.minX, y: r.minY), tangent2End: CGPoint(x: r.maxX, y: r.minY), radius: radius)
        p.closeSubpath()
        return p
    }
}

/// The folded-back corner: the paper's underside, lit along the fold and shaded at the tip.
private struct CurlFlap: View {
    var curl: CGFloat
    let color: Color

    var body: some View {
        FlapShape(curl: curl)
            .fill(LinearGradient(
                colors: [color.mix(with: .black, by: 0.10), color.mix(with: .white, by: 0.55)],
                startPoint: .bottomTrailing, endPoint: .topLeading))
            .overlay { FlapShape(curl: curl).stroke(.black.opacity(0.06), lineWidth: 0.5) }
            .shadow(color: .black.opacity(0.18), radius: 2.5, x: -1.5, y: -1.5)
            .opacity(curl > 0.5 ? 1 : 0)
            .allowsHitTesting(false)
    }

    private struct FlapShape: Shape {
        var curl: CGFloat
        var animatableData: CGFloat {
            get { curl }
            set { curl = newValue }
        }

        func path(in r: CGRect) -> Path {
            let c = min(max(curl, 0), r.width * 0.4)
            let a = CGPoint(x: r.maxX, y: r.maxY - c)
            let b = CGPoint(x: r.maxX - c, y: r.maxY)
            let tip = CGPoint(x: r.maxX - c * 0.95, y: r.maxY - c * 0.95)
            var p = Path()
            p.move(to: a)
            p.addQuadCurve(to: tip, control: CGPoint(x: r.maxX - c * 0.35, y: r.maxY - c * 1.05))
            p.addQuadCurve(to: b, control: CGPoint(x: r.maxX - c * 1.05, y: r.maxY - c * 0.35))
            p.closeSubpath()
            return p
        }
    }
}

/// Shadow whose bottom edge bows upward in the middle, so the paper's corners read as lifted.
private struct CurlShadow: View {
    var lifted: Bool

    var body: some View {
        CurlShape(bow: lifted ? 10 : 7)
            .fill(.black.opacity(lifted ? 0.26 : 0.22))
            .blur(radius: lifted ? 9 : 6)
            .offset(y: lifted ? 10 : 5)
            .padding(.horizontal, 3)
    }

    private struct CurlShape: Shape {
        var bow: CGFloat
        func path(in r: CGRect) -> Path {
            var p = Path()
            p.move(to: CGPoint(x: r.minX + 6, y: r.minY + 12))
            p.addLine(to: CGPoint(x: r.maxX - 6, y: r.minY + 12))
            p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
            p.addQuadCurve(to: CGPoint(x: r.minX, y: r.maxY), control: CGPoint(x: r.midX, y: r.maxY - bow * 2))
            p.closeSubpath()
            return p
        }
    }
}

struct RulingView: View {
    let ruling: Ruling
    var ink: Color = Color(hex: 0x3B6FB6)

    var body: some View {
        Canvas { ctx, size in
            switch ruling {
            case .none:
                break
            case .lines:
                var p = Path()
                var y: CGFloat = 52
                while y < size.height - 8 { p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: size.width, y: y)); y += 26 }
                ctx.stroke(p, with: .color(ink.opacity(0.16)), lineWidth: 0.8)
            case .grid:
                var p = Path()
                var v: CGFloat = 13
                while v < max(size.width, size.height) {
                    p.move(to: CGPoint(x: v, y: 0)); p.addLine(to: CGPoint(x: v, y: size.height))
                    p.move(to: CGPoint(x: 0, y: v)); p.addLine(to: CGPoint(x: size.width, y: v))
                    v += 13
                }
                ctx.stroke(p, with: .color(ink.opacity(0.11)), lineWidth: 0.6)
            case .dots:
                var y: CGFloat = 13
                while y < size.height {
                    var x: CGFloat = 13
                    while x < size.width {
                        ctx.fill(Path(ellipseIn: CGRect(x: x - 0.8, y: y - 0.8, width: 1.6, height: 1.6)), with: .color(ink.opacity(0.22)))
                        x += 13
                    }
                    y += 13
                }
            }
        }
        .allowsHitTesting(false)
    }
}

/// Translucent washi tape with zig-zag torn ends.
struct WashiTape: View {
    var tint: Color = Tok.Tape.plain
    var body: some View {
        ZigZagStrip()
            .fill(tint.opacity(0.55))
            .overlay { ZigZagStrip().fill(LinearGradient(colors: [.white.opacity(0.35), .clear], startPoint: .top, endPoint: .bottom)) }
            .overlay { GrainOverlay(image: Grain.paper, opacity: 0.25).clipShape(ZigZagStrip()) }
            .frame(width: 72, height: 22)
            .shadow(color: .black.opacity(0.10), radius: 1.2, y: 1)
    }

    private struct ZigZagStrip: Shape {
        func path(in r: CGRect) -> Path {
            var p = Path()
            let teeth = 5, step = r.height / CGFloat(teeth), depth: CGFloat = 2.5
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
            return p
        }
    }
}

/// Glossy push pin seen from above.
struct PushPin: View {
    var color: Color = Tok.Stamp.pin
    var body: some View {
        ZStack {
            Circle().fill(.black.opacity(0.25)).frame(width: 13, height: 13).blur(radius: 1.6).offset(x: 3, y: 4)
            Circle()
                .fill(RadialGradient(colors: [color.mix(with: .white, by: 0.45), color, color.mix(with: .black, by: 0.35)],
                                     center: UnitPoint(x: 0.35, y: 0.3), startRadius: 0, endRadius: 9))
                .frame(width: 15, height: 15)
            Circle().fill(.white.opacity(0.85)).frame(width: 4, height: 3).offset(x: -3, y: -3.5)
        }
        .accessibilityHidden(true)
    }
}

/// A steel gem paperclip, drawn as one wire.
struct PaperClip: View {
    var body: some View {
        ClipWire()
            .stroke(
                LinearGradient(colors: [Color(hex: 0xF4F5F7), Color(hex: 0x9EA3AB), Color(hex: 0xE3E5E9), Color(hex: 0x7D828B)],
                               startPoint: .topLeading, endPoint: .bottomTrailing),
                style: StrokeStyle(lineWidth: 1.9, lineCap: .round, lineJoin: .round))
            .frame(width: 16, height: 42)
            .shadow(color: .black.opacity(0.28), radius: 0.8, x: 1, y: 1.5)
            .shadow(color: .black.opacity(0.12), radius: 3, x: 2, y: 4)
            .accessibilityHidden(true)
    }

    private struct ClipWire: Shape {
        func path(in r: CGRect) -> Path {
            let sx = r.width / 16, sy = r.height / 42
            func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: r.minX + x * sx, y: r.minY + y * sy) }
            var p = Path()
            p.move(to: pt(5, 13))
            p.addLine(to: pt(5, 31))
            p.addCurve(to: pt(11, 31), control1: pt(5, 35.5), control2: pt(11, 35.5))
            p.addLine(to: pt(11, 5))
            p.addCurve(to: pt(2, 5), control1: pt(11, -0.5), control2: pt(2, -0.5))
            p.addLine(to: pt(2, 35))
            p.addCurve(to: pt(14, 35), control1: pt(2, 42), control2: pt(14, 42))
            p.addLine(to: pt(14, 10))
            return p
        }
    }
}

/// Inked "PAID" rubber stamp («مدفوع» in Arabic). Thumps down shortly after it appears.
struct PaidStamp: View {
    var text = String(localized: "PAID")
    @State private var stamped = !Motion.enabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        face
            .scaleEffect(stamped ? 1 : 1.7)
            .opacity(stamped ? 1 : 0)
            .onAppear {
                guard !stamped else { return }
                if reduceMotion { stamped = true; return }
                withAnimation(.spring(duration: 0.32, bounce: 0.35).delay(0.55)) { stamped = true }
            }
    }

    private var face: some View {
        Text(text)
            .font(.system(size: 28, weight: .heavy, design: .rounded))
            // Letter-spacing would break Arabic joins.
            .tracking(ScriptDirection.detect(text) == .rightToLeft ? 0 : 3)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .overlay { RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(lineWidth: 2.5) }
            .padding(3)
            .overlay { RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(lineWidth: 1.2) }
            .foregroundStyle(Tok.Stamp.red.opacity(0.85))
            .mask {
                // Uneven ink: punch tiny holes with the grain.
                Rectangle().overlay { GrainOverlay(image: Grain.kraft, opacity: 1).blendMode(.destinationOut) }.compositingGroup()
            }
            .blendMode(.multiply)
            .rotationEffect(.degrees(-14))
            .accessibilityLabel(Text(text))
    }
}

/// Global motion switch: snapshot mode turns entrance animations off so renders show the settled state.
@MainActor
enum Motion {
    static var enabled = true
}
