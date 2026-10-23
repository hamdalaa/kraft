import AppKit
import SwiftUI

/// A borderless, non-activating panel that holds one desktop sticky. It floats above other apps,
/// joins every Space, never becomes key (so it never steals focus) and is dragged by the whole paper.
@MainActor
final class DesktopPanel: NSPanel {
    /// Transparent room around the paper for its shadow, tilt, sticker and fastener.
    let pad: CGFloat
    var onDragStateChanged: ((Bool) -> Void)?
    var onDragEnded: (() -> Void)?
    var menuProvider: (() -> NSMenu?)?
    private(set) var isDragging = false

    private var pendingMouseDown: NSEvent?
    private var dragStart: (mouse: NSPoint, origin: NSPoint)?
    private static let dragThreshold: CGFloat = 3

    init(paperRect: CGRect, pad: CGFloat, rootView: some View) {
        self.pad = pad
        super.init(contentRect: paperRect.insetBy(dx: -pad, dy: -pad), styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = true
        isReleasedWhenClosed = false
        isMovable = false
        animationBehavior = .none
        let host = FirstMouseHostingView(rootView: AnyView(rootView))
        host.sizingOptions = []
        contentView = host
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    /// `DesktopLayout` already keeps the paper on-screen; AppKit would otherwise push the transparent
    /// padding below the menu bar and knock the top row off the grid.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }

    /// The paper footprint, in screen coordinates.
    var paperRect: CGRect { frame.insetBy(dx: pad, dy: pad) }

    func setPaperRect(_ rect: CGRect, animated: Bool) {
        let target = rect.insetBy(dx: -pad, dy: -pad)
        guard target != frame else { return }
        guard animated, Motion.enabled, !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {
            setFrame(target, display: true)
            return
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.24
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            animator().setFrame(target, display: true)
        }
    }

    /// Short fade; the panel leaves the screen once fully transparent.
    func fade(visible: Bool) {
        if visible {
            if !isVisible { alphaValue = 0 }
            orderFrontRegardless()
        }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.18
            animator().alphaValue = visible ? 1 : 0
        }, completionHandler: { [weak self] in
            MainActor.assumeIsolated {
                guard let self, self.alphaValue < 0.01 else { return }
                self.orderOut(nil)
            }
        })
    }

    // MARK: Mouse

    /// The whole paper is the drag handle. A press is held back until the pointer either moves
    /// (a drag: the press never reaches the paper, so no checkbox toggles) or lifts (a click: the
    /// press and release are delivered together, so checklist ticks still work).
    override func sendEvent(_ event: NSEvent) {
        switch event.type {
        case .rightMouseDown:
            showMenu(for: event)
            return
        case .leftMouseDown where event.modifierFlags.contains(.control):
            showMenu(for: event)
            return
        case .leftMouseDown:
            pendingMouseDown = event
            dragStart = (NSEvent.mouseLocation, frame.origin)
            return
        case .leftMouseDragged:
            guard let start = dragStart else { break }
            let mouse = NSEvent.mouseLocation
            let dx = mouse.x - start.mouse.x, dy = mouse.y - start.mouse.y
            if !isDragging {
                guard hypot(dx, dy) >= Self.dragThreshold else { return }
                isDragging = true
                pendingMouseDown = nil
                onDragStateChanged?(true)
            }
            setFrameOrigin(NSPoint(x: start.origin.x + dx, y: start.origin.y + dy))
            return
        case .leftMouseUp:
            dragStart = nil
            if isDragging {
                isDragging = false
                onDragStateChanged?(false)
                onDragEnded?()
                return
            }
            if let down = pendingMouseDown {
                pendingMouseDown = nil
                super.sendEvent(down)
            }
        default:
            break
        }
        super.sendEvent(event)
    }

    private func showMenu(for event: NSEvent) {
        guard let menu = menuProvider?(), let view = contentView else { return }
        NSMenu.popUpContextMenu(menu, with: event, for: view)
    }
}

/// Clicks land on the paper even though Kraft is in the background and the panel is never key.
private final class FirstMouseHostingView: NSHostingView<AnyView> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

/// An `NSMenuItem` that runs a closure.
final class ActionMenuItem: NSMenuItem {
    private let handler: () -> Void

    init(_ title: String, symbol: String? = nil, keyEquivalent: String = "", modifiers: NSEvent.ModifierFlags = [],
         handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(fire), keyEquivalent: keyEquivalent)
        keyEquivalentModifierMask = modifiers
        target = self
        if let symbol { image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil) }
    }

    @available(*, unavailable)
    required init(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    @objc private func fire() { handler() }
}
