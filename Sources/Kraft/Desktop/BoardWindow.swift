import AppKit
import SwiftUI

/// Brings the board window back from anywhere: Dock click, a desktop sticky's "Open in Kraft".
/// SwiftUI only hands out `openWindow` inside a view, so the board captures it when it appears;
/// the action keeps working after that window is closed.
@MainActor
enum BoardWindow {
    static let id = "board"
    fileprivate static var openAction: OpenWindowAction?

    static func show() {
        NSApp.activate()
        if let window = NSApp.windows.first(where: isBoard), window.isMiniaturized {
            window.deminiaturize(nil)
        }
        openAction?(id: id)
    }

    /// The board window, while it exists.
    static var window: NSWindow? { NSApp.windows.first(where: isBoard) }

    private static func isBoard(_ window: NSWindow) -> Bool {
        !(window is NSPanel) && window.identifier?.rawValue.hasPrefix(id) == true
    }
}

extension View {
    /// Put on the board window's root view.
    func capturesBoardWindowOpener() -> some View { modifier(BoardWindowOpenerCapture()) }
}

private struct BoardWindowOpenerCapture: ViewModifier {
    @Environment(\.openWindow) private var openWindow

    func body(content: Content) -> some View {
        content.onAppear { BoardWindow.openAction = openWindow }
    }
}
