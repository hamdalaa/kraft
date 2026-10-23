import AppKit
import KraftCore
import SwiftUI

/// ⌥Space from any app: a Spotlight-like floating panel on the active screen. It takes the keyboard
/// without activating Kraft (the board stays where it is). Return adds and closes; Esc, a click
/// elsewhere, or switching apps closes. Pressing ⌥Space again closes it too.
@MainActor
final class QuickAddPanelController {
    let store: StickyStore
    private var panel: QuickAddPanel?
    private var monitors: [Any] = []
    private var activationObserver: NSObjectProtocol?

    /// Room around the card for its shadow, and below it for the field to grow.
    private static let shadowRoom: CGFloat = 36
    private static let growRoom: CGFloat = 96

    init(store: StickyStore) {
        self.store = store
        #if DEBUG
        // `KRAFT_QUICKADD_DEMO="text"` opens the panel shortly after launch, for checking it without the hotkey.
        if let demo = ProcessInfo.processInfo.environment["KRAFT_QUICKADD_DEMO"] {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in self?.showFromAnywhere(text: demo) }
        }
        #endif
    }

    var isShown: Bool { panel?.isVisible == true }

    func showFromAnywhere(text: String = "") {
        if isShown { close(); return }
        let root = QuickAddView(store: store, presentation: .panel, model: QuickAddModel(text: text),
                                onAdded: { AppServices.shared.storeDidChange() },
                                dismiss: { [weak self] in self?.close() })
            .shadow(color: .black.opacity(0.22), radius: 26, y: 16)
            .shadow(color: .black.opacity(0.12), radius: 1.5, y: 1)
            .padding(Self.shadowRoom)
            .frame(maxHeight: .infinity, alignment: .top)
            .background {
                // Clicks on the clear margin count as "elsewhere".
                Color.clear.contentShape(Rectangle()).onTapGesture { [weak self] in self?.close() }
            }
            .kraftEnvironment()
        let host = NSHostingView(rootView: root)
        let fitting = host.fittingSize
        host.sizingOptions = [] // the panel keeps its size; the card grows down into the clear room below
        let size = NSSize(width: fitting.width, height: fitting.height + Self.growRoom)

        let panel = QuickAddPanel(contentRect: NSRect(origin: .zero, size: size))
        panel.contentView = host
        panel.setFrame(Self.frame(for: size), display: false)
        panel.makeKeyAndOrderFront(nil)
        self.panel = panel
        installMonitors()
    }

    func close() {
        removeMonitors()
        panel?.orderOut(nil)
        panel = nil
    }

    /// Centred on the screen under the pointer, a little above the middle (where Spotlight sits).
    private static func frame(for size: NSSize) -> NSRect {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        let visible = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let top = visible.maxY - visible.height * 0.2 + shadowRoom
        return NSRect(x: visible.midX - size.width / 2, y: top - size.height, width: size.width, height: size.height)
    }

    private func installMonitors() {
        removeMonitors()
        // A click in another app.
        if let m = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown], handler: { [weak self] _ in
            MainActor.assumeIsolated { self?.close() }
        }) { monitors.append(m) }
        // A click in one of Kraft's own windows (the board), but not in our popovers.
        if let m = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown], handler: { [weak self] event in
            MainActor.assumeIsolated {
                if let self, let panel = self.panel, let window = event.window, window !== panel, !Self.belongs(window, to: panel) {
                    self.close()
                }
            }
            return event
        }) { monitors.append(m) }
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] _ in MainActor.assumeIsolated { self?.close() } }
    }

    /// Popovers and menus opened from the panel live in their own windows.
    private static func belongs(_ window: NSWindow, to panel: NSWindow) -> Bool {
        var w: NSWindow? = window
        while let current = w {
            if current === panel { return true }
            w = current.parent
        }
        return String(describing: type(of: window)).contains("Popover") || window.level.rawValue > panel.level.rawValue
    }

    private func removeMonitors() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors = []
        if let o = activationObserver { NSWorkspace.shared.notificationCenter.removeObserver(o) }
        activationObserver = nil
    }
}

/// Borderless, non-activating, floats over full-screen apps and every Space.
final class QuickAddPanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(contentRect: contentRect, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isFloatingPanel = true
        level = .floating
        becomesKeyOnlyIfNeeded = false
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        isMovableByWindowBackground = true
        animationBehavior = .utilityWindow
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
