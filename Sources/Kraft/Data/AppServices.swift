import AppKit
import KraftCore
import SwiftUI

/// Long-lived services shared by the board window, the menu commands and the global hotkeys.
@MainActor
final class AppServices {
    static let shared = AppServices()

    let store: StickyStore
    let board: BoardModel
    let desktop: DesktopStickiesController
    let reminders: ReminderScheduler
    let quickAdd: QuickAddPanelController

    private init() {
        store = StickyStore.persistent()
        board = BoardModel(store: store)
        desktop = DesktopStickiesController(store: store)
        reminders = ReminderScheduler(store: store)
        quickAdd = QuickAddPanelController(store: store)
    }

    /// Called once the app has finished launching.
    func start() {
        HotKeys.shared.register(.quickAdd) { [weak self] in self?.quickAdd.showFromAnywhere() }
        HotKeys.shared.register(.toggleDesktopStickies) { [weak self] in self?.desktop.toggleAllVisible() }
        desktop.start()
        reminders.start()
    }

    /// Store changed: let the desktop windows and reminder schedule catch up.
    func storeDidChange() {
        desktop.sync()
        reminders.sync()
    }
}
