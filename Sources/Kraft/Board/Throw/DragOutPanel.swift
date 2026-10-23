import AppKit
import KraftCore
import SwiftUI

/// The paper you carry once the pointer leaves the board window: a click-through floating panel that follows
/// the pointer over the desktop, with a «Drop to pin» tag under it. Dropping pins the sticky right there.
@MainActor
final class DragOutPanel: NSPanel {
    /// Room around the paper for its lift shadow and the tag underneath.
    private static let pad: CGFloat = 40
    private static let tagRoom: CGFloat = 44
    private let side: CGFloat

    init(sticky: Sticky) {
        side = sticky.style.size.side
        let size = CGSize(width: side + Self.pad * 2, height: side + Self.pad * 2 + Self.tagRoom)
        super.init(contentRect: CGRect(origin: .zero, size: size), styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        isReleasedWhenClosed = false
        animationBehavior = .none
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        let host = NSHostingView(rootView: DragOutPaper(sticky: sticky).kraftEnvironment())
        host.sizingOptions = []
        contentView = host
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }

    /// Puts the paper's centre at `center` (screen coordinates, y up).
    func carry(paperCenter center: CGPoint) {
        setFrameOrigin(NSPoint(x: center.x - frame.width / 2, y: center.y - side / 2 - Self.pad - Self.tagRoom))
    }

    func paperRect(centeredAt center: CGPoint) -> CGRect {
        CGRect(x: center.x - side / 2, y: center.y - side / 2, width: side, height: side)
    }

    func show() {
        alphaValue = 0
        orderFrontRegardless()
        fade(to: 1, duration: 0.12)
    }

    /// Glides the paper onto `rect` (where the desktop sticky now hangs) while fading, then closes.
    func land(on rect: CGRect) {
        let origin = NSPoint(x: rect.midX - frame.width / 2, y: rect.minY - Self.pad - Self.tagRoom)
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = Motion.enabled ? 0.22 : 0
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            animator().setFrameOrigin(origin)
            animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            MainActor.assumeIsolated { self?.close() }
        })
    }

    func dismiss() {
        fade(to: 0, duration: 0.12) { [weak self] in self?.close() }
    }

    private func fade(to alpha: CGFloat, duration: TimeInterval, then done: (@MainActor () -> Void)? = nil) {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = Motion.enabled ? duration : 0
            animator().alphaValue = alpha
        }, completionHandler: {
            MainActor.assumeIsolated { done?() }
        })
    }
}

private struct DragOutPaper: View {
    let sticky: Sticky

    var body: some View {
        VStack(spacing: 10) {
            StickyCard(sticky: sticky, lifted: true)
                .rotationEffect(.degrees(sticky.style.tilt * 0.5))
            GlossyTag(text: String(localized: "Drop to pin on the desktop"), symbol: "pin.fill", tint: .blue, size: .mini)
        }
        .padding(.top, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}
