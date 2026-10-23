import AppKit
import SwiftUI

/// Procedural paper and kraft grain, generated once and tiled.
@MainActor
enum Grain {
    static let paper: NSImage = make(side: 192, seed: 11, specks: 9000, maxAlpha: 0.22, fibres: 0)
    static let kraft: NSImage = make(side: 256, seed: 29, specks: 22000, maxAlpha: 0.35, fibres: 220)

    private static func make(side: Int, seed: UInt64, specks: Int, maxAlpha: Double, fibres: Int) -> NSImage {
        var rng = SplitMix64(seed: seed)
        guard let ctx = CGContext(
            data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return NSImage() }

        for _ in 0..<specks {
            let x = Double(rng.next() % UInt64(side)), y = Double(rng.next() % UInt64(side))
            let dark = rng.unit() < 0.7
            let a = rng.unit() * maxAlpha
            ctx.setFillColor(dark ? CGColor(gray: 0.15, alpha: a) : CGColor(gray: 1, alpha: a * 0.8))
            ctx.fill(CGRect(x: x, y: y, width: 1, height: 1))
        }
        // Short fibres for kraft: thin strokes at random angles, wrapped so the tile is seamless enough.
        ctx.setLineCap(.round)
        for _ in 0..<fibres {
            let x = rng.unit() * Double(side), y = rng.unit() * Double(side)
            let len = 3 + rng.unit() * 9, angle = rng.unit() * .pi
            let dark = rng.unit() < 0.6
            ctx.setStrokeColor(dark ? CGColor(red: 0.35, green: 0.2, blue: 0.08, alpha: 0.25) : CGColor(gray: 1, alpha: 0.22))
            ctx.setLineWidth(0.6 + rng.unit() * 0.6)
            ctx.move(to: CGPoint(x: x, y: y))
            ctx.addLine(to: CGPoint(x: x + cos(angle) * len, y: y + sin(angle) * len))
            ctx.strokePath()
        }
        guard let image = ctx.makeImage() else { return NSImage() }
        return NSImage(cgImage: image, size: NSSize(width: side / 2, height: side / 2))
    }
}

extension View {
    /// Grain on page stock and kraft: multiplied by day; laid on plainly at night, where multiply would vanish
    /// into the dark stock and the pale fibres need to show.
    func surfaceGrain() -> some View { modifier(SurfaceGrainBlend()) }
}

private struct SurfaceGrainBlend: ViewModifier {
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        if scheme == .dark {
            content
        } else {
            content.blendMode(.multiply)
        }
    }
}

struct GrainOverlay: View {
    let image: NSImage
    var opacity: Double

    var body: some View {
        Image(nsImage: image)
            .resizable(resizingMode: .tile)
            .opacity(opacity)
            .allowsHitTesting(false)
    }
}

struct SplitMix64 {
    private var state: UInt64
    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    mutating func unit() -> Double { Double(next() >> 11) / Double(1 << 53) }
}
