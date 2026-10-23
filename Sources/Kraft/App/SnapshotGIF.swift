import AppKit
import ImageIO
import KraftCore
import SwiftUI
import UniformTypeIdentifiers

/// README animation: a sticky crumples into a ball and arcs into the bin. Written by snapshot mode.
@MainActor
enum CrumpleGIF {
    static let canvas = CGSize(width: 780, height: 420)

    static func write(sticky: Sticky, to url: URL) {
        let paperRenderer = ImageRenderer(content: ThrowController.handPaper(sticky))
        paperRenderer.scale = 2
        guard let cg = paperRenderer.cgImage else { return }
        let size = CGSize(width: CGFloat(cg.width) / 2, height: CGFloat(cg.height) / 2)
        let image = Image(decorative: cg, scale: 2)

        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.gif.identifier as CFString, 0, nil) else { return }
        CGImageDestinationSetProperties(dest, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)

        let frames = 54
        for i in 0..<frames {
            let p = Double(i) / Double(frames - 1)
            let frame = Frame(p: p, image: image, size: size, paper: sticky.style.color.color(customHex: nil))
            let r = ImageRenderer(content: frame.frame(width: canvas.width, height: canvas.height))
            r.scale = 1.25
            guard let img = r.cgImage else { continue }
            let hold = (i == 0 || i == frames - 1) ? 0.9 : 0.035
            CGImageDestinationAddImage(dest, img, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: hold]] as CFDictionary)
        }
        CGImageDestinationFinalize(dest)
        print("wrote \(url.path)")
    }

    private struct Frame: View {
        let p: Double
        let image: Image
        let size: CGSize
        let paper: Color

        private var crumple: Double { smooth(min(1, p / 0.5)) * 0.95 + (p > 0.5 ? 0.05 : 0) }
        private var flight: Double { smooth(min(1, max(0, (p - 0.42) / 0.42))) }
        private var landed: Bool { p >= 0.86 }

        var body: some View {
            let start = CGPoint(x: 210, y: 230)
            let bin = CGPoint(x: 600, y: 300)
            let mouth = CGPoint(x: bin.x, y: bin.y - 62)
            let control = CGPoint(x: (start.x + mouth.x) / 2, y: 30)
            let u = CGFloat(flight)
            let a = (1 - u) * (1 - u), b = 2 * (1 - u) * u, c = u * u
            let point = CGPoint(x: a * start.x + b * control.x + c * mouth.x, y: a * start.y + b * control.y + c * mouth.y)
            let endScale = 52 / (size.width * 0.4)
            ZStack {
                Tok.Kraft.base
                GrainOverlay(image: Grain.kraft, opacity: 0.5).blendMode(.multiply)
                WasteBin(balls: landed ? [paper] : [])
                    .scaleEffect(x: squash.width, y: squash.height, anchor: .bottom)
                    .scaleEffect(2)
                    .position(bin)
                if !landed {
                    CrumpleView(image: image, size: size, paper: paper, progress: crumple)
                        .rotationEffect(.degrees(-2 + 540 * flight))
                        .scaleEffect(1 + (endScale - 1) * u)
                        .shadow(color: .black.opacity(0.22), radius: 12, y: 12)
                        .position(point)
                }
            }
            .compositingGroup()
        }

        /// Bin squash right after the ball lands.
        private var squash: CGSize {
            guard landed else { return CGSize(width: 1, height: 1) }
            let k = min(1, (p - 0.86) / 0.14)
            let s = sin(k * .pi * 2) * (1 - k) * 0.16
            return CGSize(width: 1 + s, height: 1 - s)
        }

        private func smooth(_ x: Double) -> Double { x * x * (3 - 2 * x) }
    }
}
