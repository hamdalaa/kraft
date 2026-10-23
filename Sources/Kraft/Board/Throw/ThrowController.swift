import AppKit
import KraftCore
import Observation
import SwiftUI

enum BoardSpace {
    static let name = "board"
}

/// TEMP debug: `KRAFT_DEBUG_THROW=1` prints gesture + frame events to stderr.
enum ThrowDebug {
    static let on = ProcessInfo.processInfo.environment["KRAFT_DEBUG_THROW"] != nil
    static func log(_ s: @autoclosure () -> String) {
        guard on else { return }
        FileHandle.standardError.write(Data(("[throw] " + s() + "\n").utf8))
    }
}

/// Hold a sticky to pick it up, fling it at the bin: it crumples, arcs in, the bin bounces.
/// Release anywhere else and it springs back to its place.
@MainActor
@Observable
final class ThrowController {
    enum Phase { case idle, holding, throwing, returning }

    private(set) var phase: Phase = .idle
    private(set) var sticky: Sticky?
    /// Flat, untilted render of the paper used for the crumple.
    private(set) var paperImage: Image?
    private(set) var paperSize: CGSize = .zero

    /// Centre of the held card, in board space.
    private(set) var location: CGPoint = .zero
    private(set) var swing: Double = 0
    private(set) var crumple: Double = 0
    private(set) var flight: Double = 0
    private(set) var flightStart: CGPoint = .zero

    var binFrame: CGRect = .zero
    /// Bumped on every landing; the bin squashes.
    private(set) var landings = 0
    /// Last thrown sticky, offered as "Put Back" for a few seconds.
    var lastThrown: Sticky.ID?

    private var origin: CGPoint = .zero
    private var grabOffset: CGSize = .zero
    private var delete: ((Sticky.ID) -> Void)?

    var isHolding: Bool { phase == .holding }
    /// Over the bin as soon as the carried paper touches it, not only its centre.
    var isOverBin: Bool {
        guard phase == .holding, binFrame != .zero else { return false }
        let side = (sticky?.style.size.side ?? 200) * 0.8
        let paper = CGRect(x: location.x - side / 2, y: location.y - side / 2, width: side, height: side)
        return paper.intersects(binFrame.insetBy(dx: -8, dy: -8))
    }
    func isCarrying(_ id: Sticky.ID) -> Bool { phase != .idle && sticky?.id == id }

    var binMouth: CGPoint { CGPoint(x: binFrame.midX, y: binFrame.minY + binFrame.height * 0.3) }

    func pickUp(_ sticky: Sticky, cardFrame: CGRect, at point: CGPoint, delete: @escaping (Sticky.ID) -> Void) {
        guard phase == .idle else { return }
        self.sticky = sticky
        self.delete = delete
        origin = CGPoint(x: cardFrame.midX, y: cardFrame.midY)
        location = origin
        grabOffset = CGSize(width: point.x - origin.x, height: point.y - origin.y)
        crumple = 0
        flight = 0
        renderPaper(sticky)
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
        withAnimation(.spring(duration: 0.25, bounce: 0.3)) { phase = .holding }
        withAnimation(.spring(duration: 0.3, bounce: 0.35)) { crumple = Self.grabCrinkle }
    }

    func move(to point: CGPoint, velocity: CGSize) {
        guard phase == .holding else { return }
        let wasOver = isOverBin
        location = CGPoint(x: point.x - grabOffset.width, y: point.y - grabOffset.height)
        // The paper swings with the hand, like holding a sheet by one edge.
        withAnimation(.interactiveSpring(duration: 0.25)) { swing = max(-14, min(14, velocity.width / 90)) }
        if isOverBin != wasOver { NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now) }
        withAnimation(.interactiveSpring(duration: 0.35, extraBounce: 0.1)) { crumple = handCrumple }
    }

    /// How crumpled the paper is in your hand: a light crinkle when picked up, tighter as it nears
    /// the bin, almost a ball over it.
    private var handCrumple: Double {
        guard binFrame != .zero else { return Self.grabCrinkle }
        if isOverBin { return 0.84 }
        let distance = hypot(location.x - binFrame.midX, location.y - binFrame.midY)
        let near = 1 - min(1, max(0, (distance - 80) / 560))
        return Self.grabCrinkle + 0.42 * near * near
    }

    private static let grabCrinkle = 0.24

    func release(predicted: CGPoint, reduceMotion: Bool) {
        guard phase == .holding else { return }
        ThrowDebug.log("release at=\(location) predicted=\(predicted) over=\(isOverBin) bin=\(binFrame)")
        let thrown = binFrame.insetBy(dx: -140, dy: -140).contains(predicted) && Self.isHeadingTo(binFrame, from: location, predicted: predicted)
        if isOverBin || thrown { throwAway(reduceMotion: reduceMotion) } else { springBack() }
    }

    func cancel() {
        if phase == .holding { springBack() }
    }

    private func throwAway(reduceMotion: Bool) {
        guard let sticky else { return }
        phase = .throwing
        flightStart = location
        CrumpleSound.play()
        if reduceMotion {
            withAnimation(.easeOut(duration: 0.25)) { crumple = 1; flight = 1 }
        } else {
            // Finish the ball from wherever the hand left it, then drop it in.
            let rest = 0.34 * (1 - crumple)
            withAnimation(.easeIn(duration: max(0.12, rest))) { crumple = 1 }
            withAnimation(.timingCurve(0.35, 0, 0.65, 1, duration: 0.5).delay(max(0.06, rest * 0.6))) { flight = 1 }
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 260 : 720))
            land(sticky.id)
        }
    }

    private func land(_ id: Sticky.ID) {
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
        landings += 1
        withAnimation(.spring(duration: 0.5, bounce: 0.2)) {
            delete?(id)
            lastThrown = id
        }
        reset()
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(6))
            if lastThrown == id { withAnimation { lastThrown = nil } }
        }
    }

    private func springBack() {
        phase = .returning
        // The paper smooths itself out on the way back.
        withAnimation(.spring(duration: 0.42, bounce: 0.32)) {
            location = origin
            swing = 0
            crumple = 0
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(420))
            if phase == .returning { reset() }
        }
    }

    private func reset() {
        phase = .idle
        sticky = nil
        paperImage = nil
        crumple = 0
        flight = 0
        swing = 0
    }

    private func renderPaper(_ sticky: Sticky) {
        let renderer = ImageRenderer(content: Self.handPaper(sticky))
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2
        guard let cg = renderer.cgImage else { paperImage = nil; return }
        paperSize = CGSize(width: CGFloat(cg.width) / renderer.scale, height: CGFloat(cg.height) / renderer.scale)
        paperImage = Image(decorative: cg, scale: renderer.scale)
    }

    /// The paper as it crumples in the hand: untilted, sticker and stamp on, fastener pulled off, no shadow,
    /// padded so the die-cut sticker over the corner is included.
    static func handPaper(_ sticky: Sticky) -> some View {
        var flat = sticky
        flat.style.tilt = 0
        return StickyCard(sticky: flat, showsFastener: false, castsShadow: false).padding(26)
    }

    /// True when the fling points at the bin (within ~35°), so a flick toward it counts as a throw.
    private static func isHeadingTo(_ bin: CGRect, from start: CGPoint, predicted: CGPoint) -> Bool {
        let fling = CGVector(dx: predicted.x - start.x, dy: predicted.y - start.y)
        let toBin = CGVector(dx: bin.midX - start.x, dy: bin.midY - start.y)
        let lf = hypot(fling.dx, fling.dy), lb = hypot(toBin.dx, toBin.dy)
        guard lf > 30, lb > 0 else { return false }
        return (fling.dx * toBin.dx + fling.dy * toBin.dy) / (lf * lb) > 0.7 // within ~45°
    }
}

private enum CrumpleSound {
    @MainActor static let sound: NSSound? = {
        let path = "/System/Library/Components/CoreAudio.component/Contents/SharedSupport/SystemSounds/finder/move to trash.aif"
        let s = NSSound(contentsOfFile: path, byReference: true)
        s?.volume = 0.55
        return s
    }()

    @MainActor static func play() {
        sound?.stop()
        sound?.play()
    }
}

// MARK: - Gesture

extension View {
    /// Drag a sticky to carry it (no hold needed — a plain click still opens it);
    /// drop it on the bin or fling it toward the bin to throw it away.
    func throwable(_ sticky: Sticky, frame: CGRect, thrower: ThrowController, reduceMotion: Bool,
                   delete: @escaping (Sticky.ID) -> Void) -> some View {
        gesture(
            DragGesture(minimumDistance: 4, coordinateSpace: .named(BoardSpace.name))
                .onChanged { drag in
                    if thrower.phase == .idle {
                        thrower.pickUp(sticky, cardFrame: frame, at: drag.startLocation, delete: delete)
                    }
                    thrower.move(to: drag.location, velocity: drag.velocity)
                }
                .onEnded { drag in
                    thrower.release(predicted: drag.predictedEndLocation, reduceMotion: reduceMotion)
                }
        )
    }
}

// MARK: - Layer

/// Draws the carried / crumpling / flying sticky above everything on the board.
struct ThrowLayer: View {
    @Environment(ThrowController.self) private var thrower

    var body: some View {
        ZStack {
            if let sticky = thrower.sticky {
                if let image = thrower.paperImage {
                    let paper = sticky.style.color.color(customHex: sticky.style.customHex)
                    CrumpleView(image: image, size: thrower.paperSize, paper: paper, progress: thrower.crumple)
                        .rotationEffect(.degrees(sticky.style.tilt * (1 - thrower.crumple) + thrower.swing))
                        .scaleEffect(thrower.phase == .holding ? 1.04 : 1)
                        .shadow(color: .black.opacity(0.10), radius: 1.5, y: 1)
                        .shadow(color: .black.opacity(thrower.phase == .holding ? 0.18 : 0.22), radius: 14, y: 14)
                        .modifier(FlightEffect(t: thrower.flight, start: thrower.phase == .throwing ? thrower.flightStart : thrower.location,
                                               end: thrower.binMouth,
                                               endScale: 30 / max(thrower.paperSize.width * 0.4, 1)))
                } else {
                    StickyCard(sticky: sticky, lifted: true)
                        .rotationEffect(.degrees(thrower.swing))
                        .position(thrower.location)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
    }
}

/// Moves a view along an arc (quadratic Bézier with a lifted control point), shrinking and spinning.
private struct FlightEffect: ViewModifier, Animatable {
    var t: Double
    /// Animatable too, so the paper glides home when it springs back.
    var start: CGPoint
    let end: CGPoint
    let endScale: CGFloat

    nonisolated var animatableData: AnimatablePair<Double, AnimatablePair<CGFloat, CGFloat>> {
        get { AnimatablePair(t, AnimatablePair(start.x, start.y)) }
        set {
            t = newValue.first
            start = CGPoint(x: newValue.second.first, y: newValue.second.second)
        }
    }

    func body(content: Content) -> some View {
        let lift = max(90, abs(end.x - start.x) * 0.35)
        let control = CGPoint(x: (start.x + end.x) / 2, y: min(start.y, end.y) - lift)
        let u = CGFloat(t)
        let a: CGFloat = (1 - u) * (1 - u)
        let b: CGFloat = 2 * (1 - u) * u
        let c: CGFloat = u * u
        let x: CGFloat = a * start.x + b * control.x + c * end.x
        let y: CGFloat = a * start.y + b * control.y + c * end.y
        let point = CGPoint(x: x, y: y)
        content
            .scaleEffect(1 + (endScale - 1) * u)
            .rotationEffect(.degrees(540 * t))
            .position(point)
    }
}
