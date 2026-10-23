import AppKit
import KraftCore
import Observation
import SwiftUI

/// Stickies pinned to the Mac desktop: one floating, non-activating panel per sticky with
/// `isOnDesktop`, placed tidily without overlap (`DesktopLayout`), dragged by the paper, snapped
/// to the grid on release. Panels follow the store on their own, so they stay live even while the
/// board window is closed.
@MainActor
final class DesktopStickiesController {
    let store: StickyStore

    /// Transparent room around each paper for shadow, tilt, sticker and fastener.
    static let panelPad: CGFloat = 36
    private static let hiddenDefaultsKey = "DesktopStickiesHidden"

    private var panels: [Sticky.ID: DesktopPanel] = [:]
    private var states: [Sticky.ID: DesktopPanelState] = [:]
    private(set) var isShowingAll = !UserDefaults.standard.bool(forKey: hiddenDefaultsKey)
    private var started = false
    private var screenObserver: NSObjectProtocol?

    init(store: StickyStore) { self.store = store }

    func start() {
        guard !started else { return }
        started = true
        #if DEBUG
        if UserDefaults.standard.bool(forKey: "KraftDesktopDemo") { pinDemoStickies() }
        #endif
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.sync() }
        }
        sync(initial: true)
        observeStore()
    }

    // MARK: Sync

    /// Open / close / move panels to match `store` (stickies with `isOnDesktop`).
    func sync() { sync(initial: false) }

    private func sync(initial: Bool) {
        guard started else { return }
        let pinned = store.stickies.filter(\.showsOnDesktop)
        let pinnedIDs = Set(pinned.map(\.id))
        for id in panels.keys where !pinnedIDs.contains(id) { closePanel(id) }

        let frames = targetFrames(for: pinned)
        var revealed = false
        for sticky in pinned {
            guard let rect = frames[sticky.id] else { continue }
            if let panel = panels[sticky.id] {
                if !panel.isDragging { panel.setPaperRect(rect, animated: true) }
            } else {
                openPanel(sticky.id, at: rect)
                revealed = revealed || !initial
            }
        }
        // Pinning a sticky while the rest are hidden means "I want to see it": bring them all back.
        if revealed && !isShowingAll { setShowingAll(true) }
    }

    /// Stored spots (pulled back on-screen if a display went away), plus a fresh grid slot, saved
    /// to the store, for every sticky pinned without one.
    private func targetFrames(for pinned: [Sticky]) -> [Sticky.ID: CGRect] {
        let anchored = pinned.compactMap { s in s.desktopOrigin.map { (id: s.id, rect: $0.paperRect(side: s.style.size.side)) } }
        var frames = layout.relocate(anchored, screens: screens)
        var occupied = Array(frames.values)
        for sticky in pinned where sticky.desktopOrigin == nil {
            let side = sticky.style.size.side
            let rect = layout.place(CGSize(width: side, height: side), in: mainScreen, avoiding: occupied)
            frames[sticky.id] = rect
            occupied.append(rect)
            store.update(sticky.movedOnDesktop(to: rect))
        }
        return frames
    }

    private func observeStore() {
        withObservationTracking { _ = store.stickies } onChange: { [weak self] in
            Task { @MainActor in
                self?.sync()
                self?.observeStore()
            }
        }
    }

    // MARK: Panels

    private func openPanel(_ id: Sticky.ID, at rect: CGRect) {
        let state = DesktopPanelState()
        let panel = DesktopPanel(paperRect: rect, pad: Self.panelPad,
                                 rootView: DesktopStickyView(store: store, id: id, state: state).kraftEnvironment())
        panel.onDragStateChanged = { dragging in state.isDragging = dragging }
        panel.onDragEnded = { [weak self] in self?.dragEnded(id) }
        panel.menuProvider = { [weak self] in self?.menu(for: id) }
        panels[id] = panel
        states[id] = state
        if isShowingAll { panel.fade(visible: true) }
    }

    private func closePanel(_ id: Sticky.ID) {
        guard let panel = panels.removeValue(forKey: id) else { return }
        states[id] = nil
        panel.fade(visible: false)
        // Let the fade finish before the window goes away.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { panel.close() }
    }

    private func dragEnded(_ id: Sticky.ID) {
        guard let panel = panels[id], let sticky = store.sticky(id) else { return }
        let others = panels.filter { $0.key != id }.map(\.value.paperRect)
        let landed = layout.snap(panel.paperRect, screens: screens, avoiding: others)
        panel.setPaperRect(landed, animated: true)
        store.update(sticky.movedOnDesktop(to: landed), actionName: String(localized: "Move Sticky"))
    }

    // MARK: Commands

    /// ⌃⌥D — short fade in or out for every desktop sticky.
    func toggleAllVisible() {
        guard !panels.isEmpty else { return setShowingAll(true) }
        setShowingAll(!isShowingAll)
    }

    private func setShowingAll(_ showing: Bool) {
        isShowingAll = showing
        UserDefaults.standard.set(!showing, forKey: Self.hiddenDefaultsKey)
        for panel in panels.values { panel.fade(visible: showing) }
    }

    /// Re-lays every desktop sticky into the tidy grid of the display it is on.
    func tidy() {
        let items = panels.map { (id: $0.key, rect: $0.value.paperRect) }
        let tidied = layout.tidy(items, screens: screens)
        for (id, rect) in tidied {
            panels[id]?.setPaperRect(rect, animated: true)
            if let sticky = store.sticky(id), sticky.desktopOrigin != DesktopPoint(topLeftOf: rect) {
                store.update(sticky.movedOnDesktop(to: rect), actionName: String(localized: "Tidy Desktop Stickies"), coalesce: true)
            }
        }
        if !isShowingAll { setShowingAll(true) }
    }

    /// Brings the board forward with this sticky open in the editor.
    func openInKraft(_ id: Sticky.ID) {
        BoardWindow.show()
        let board = AppServices.shared.board
        if let sticky = store.sticky(id), !board.tab.includes(sticky) {
            board.tab = sticky.isFinished ? .done : .all
        }
        // One runloop turn so a reopened window is on screen before the editor zooms in.
        DispatchQueue.main.async { board.open(id) }
    }

    /// Right-click on a desktop sticky: the same full menu as the board.
    private func menu(for id: Sticky.ID) -> NSMenu? {
        guard let sticky = store.sticky(id) else { return nil }
        let entries = StickyMenu.entries(for: sticky, store: store, place: .desktop, open: { [weak self] in self?.openInKraft(id) },
                                         desktop: self)
        return StickyMenu.nsMenu(entries)
    }

    /// A sticky carried out of the board window and dropped at `rect` (screen coordinates): pinned there,
    /// snapped to the grid clear of the others. Returns where it landed.
    @discardableResult
    func pin(_ id: Sticky.ID, droppedAt rect: CGRect) -> CGRect? {
        guard let sticky = store.sticky(id) else { return nil }
        let others = panels.filter { $0.key != id }.map(\.value.paperRect)
        let landed = layout.snap(rect, screens: screens, avoiding: others)
        panels[id]?.setPaperRect(landed, animated: true)
        store.update(sticky.pinnedToDesktop(true).movedOnDesktop(to: landed), actionName: String(localized: "Pin to Desktop"))
        return landed
    }

    // MARK: Geometry

    private var layout: DesktopLayout {
        DesktopLayout(direction: NSApp.userInterfaceLayoutDirection == .rightToLeft ? .rightToLeft : .leftToRight)
    }

    private var screens: [CGRect] { NSScreen.screens.map(\.visibleFrame) }

    /// New stickies go on the display with the menu bar.
    private var mainScreen: CGRect { NSScreen.screens.first?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 875) }

    #if DEBUG
    /// `-KraftDesktopDemo YES`: pin a few sample stickies for a live look.
    private func pinDemoStickies() {
        for sticky in store.live.prefix(4) where !sticky.isOnDesktop {
            store.update(sticky.pinnedToDesktop(true))
        }
    }
    #endif
}
