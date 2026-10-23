import AppKit
import KraftCore
import SwiftUI

@main
struct KraftApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let services = AppServices.shared

    init() {
        FontRegistry.registerAll()
    }

    var body: some Scene {
        Window("Kraft", id: "board") {
            BoardScreen(model: services.board)
                .frame(minWidth: 900, minHeight: 620)
                .onChange(of: services.store.stickies) { services.storeDidChange() }
                .capturesBoardWindowOpener()
                .kraftEnvironment()
        }
        .windowStyle(.hiddenTitleBar)
        .windowBackgroundDragBehavior(.enabled)
        .defaultSize(width: 1220, height: 820)
        .commands {
            CommandGroup(after: .appInfo) { CheckForUpdatesCommand() }
            CommandGroup(replacing: .newItem) {
                Button("New Sticky") { services.board.isQuickAddPresented = true }
                    .keyboardShortcut("n")
            }
            CommandMenu("Stickies") {
                Button("Show or Hide Desktop Stickies") { services.desktop.toggleAllVisible() }
                    .keyboardShortcut("d", modifiers: [.control, .option])
                Button("Tidy Desktop Stickies") { services.desktop.tidy() }
            }
        }

        Settings {
            SettingsView()
                .kraftEnvironment()
        }
        .windowResizability(.contentSize)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        MainActor.assumeIsolated { AppPreferences.shared.applyAppearance() }
        if let dir = ProcessInfo.processInfo.environment["KRAFT_SNAPSHOT"] {
            MainActor.assumeIsolated {
                FontRegistry.registerAll()
                Snapshot.renderAll(to: URL(fileURLWithPath: dir))
            }
            exit(0)
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        MainActor.assumeIsolated {
            AppServices.shared.start()
            Updater.shared.checkAutomaticallyIfDue()
        }
    }

    // Dock click: bring the board back even when desktop stickies count as visible windows.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        MainActor.assumeIsolated { BoardWindow.show() }
        return false
    }

    // Stay alive with the window closed: desktop stickies, ⌥Space and reminders keep working.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}

/// App menu › «Check for Updates…» (or «Update Available…» once a check found one): opens Settings and checks.
private struct CheckForUpdatesCommand: View {
    @Environment(\.openSettings) private var openSettings
    private let updater = Updater.shared

    var body: some View {
        Button(updater.availableRelease == nil ? "Check for Updates…" : "Update Available…") {
            openSettings()
            NSApp.activate()
            if updater.availableRelease == nil { Task { await updater.check() } }
        }
    }
}
