import AppKit
import KraftCore
import SwiftUI

/// Everything you can do to one sticky, as one list: the board's right-click menu and a desktop sticky's
/// right-click menu are both drawn from it, so they never drift apart. Every action is undoable (⌘Z).
@MainActor
enum StickyMenu {
    struct Item: Identifiable {
        let id = UUID()
        let title: String
        var symbol: String?
        var checked: Bool?
        var destructive = false
        var keyEquivalent = ""
        var modifiers: NSEvent.ModifierFlags = []
        let run: () -> Void
    }

    enum Entry: Identifiable {
        case item(Item)
        case submenu(id: String, title: String, symbol: String, items: [Item])
        case separator(Int)

        var id: String {
            switch self {
            case .item(let item): item.id.uuidString
            case .submenu(let id, _, _, _): id
            case .separator(let n): "separator-\(n)"
            }
        }
    }

    /// Where the menu opens: the board (opens in the editor) or a desktop sticky (brings the board forward).
    enum Place { case board, desktop }

    static func entries(for sticky: Sticky, store: StickyStore, place: Place, open: @escaping () -> Void,
                        desktop: DesktopStickiesController) -> [Entry] {
        let id = sticky.id
        var entries: [Entry] = [
            .item(Item(title: String(localized: place == .board ? "Open Sticky" : "Open in Kraft"),
                       symbol: place == .board ? "square.and.pencil" : "macwindow", run: open)),
            .separator(0),
            .item(Item(title: String(localized: sticky.isDone ? "Mark as Not Done" : "Mark Done"),
                       symbol: sticky.isDone ? "arrow.uturn.backward" : "checkmark") {
                store.setDone(!sticky.isDone, for: id)
            }),
            .item(Item(title: String(localized: sticky.isOnDesktop ? "Remove from Desktop" : "Pin to Desktop"),
                       symbol: sticky.isOnDesktop ? "pin.slash" : "pin") {
                guard let current = store.sticky(id) else { return }
                let name = String(localized: current.isOnDesktop ? "Remove from Desktop" : "Pin to Desktop")
                store.update(current.pinnedToDesktop(!current.isOnDesktop), actionName: name)
            }),
            .item(Item(title: String(localized: "Duplicate"), symbol: "plus.square.on.square") {
                var copy = StickyEdits.duplicate(sticky)
                copy.style.tilt = sticky.style.tilt > 0 ? -1.5 : 1.5
                store.add(copy)
            }),
            .item(Item(title: String(localized: "Copy Text"), symbol: "doc.on.doc") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(sticky.plainText, forType: .string)
            }),
            .separator(1),
        ]
        entries += lookEntries(for: sticky, store: store)
        if place == .desktop {
            entries += [
                .separator(2),
                .item(Item(title: String(localized: "Tidy Desktop Stickies"), symbol: "square.grid.2x2") { desktop.tidy() }),
                .item(Item(title: String(localized: "Hide Desktop Stickies"), symbol: "eye.slash", keyEquivalent: "d",
                           modifiers: [.control, .option]) { desktop.toggleAllVisible() }),
            ]
        }
        entries += [
            .separator(3),
            .item(Item(title: String(localized: "Throw Away"), symbol: "trash", destructive: true) {
                withAnimation(.spring(duration: 0.5, bounce: 0.2)) { store.delete(id) }
            }),
        ]
        return entries
    }

    /// Paper, size, ruling, fastener and ink, each a submenu with the current choice ticked.
    private static func lookEntries(for sticky: Sticky, store: StickyStore) -> [Entry] {
        func choices<T: Equatable>(_ all: [T], current: T, title: (T) -> String, apply: @escaping (inout PaperStyle, T) -> Void,
                                   action: String) -> [Item] {
            all.map { value in
                Item(title: title(value), checked: value == current) {
                    guard var copy = store.sticky(sticky.id) else { return }
                    apply(&copy.style, value)
                    store.update(copy, actionName: action)
                }
            }
        }
        let style = sticky.style
        let colours = PaperColor.allCases.filter { $0 != .custom || style.color == .custom }
        return [
            .submenu(id: "paper", title: String(localized: "Paper"), symbol: "paintpalette",
                     items: choices(colours, current: style.color, title: \.title, apply: { $0.color = $1 },
                                    action: String(localized: "Paper"))),
            .submenu(id: "size", title: String(localized: "Size"), symbol: "arrow.up.left.and.arrow.down.right",
                     items: choices(StickySize.allCases, current: style.size, title: \.title, apply: { $0.size = $1 },
                                    action: String(localized: "Size"))),
            .submenu(id: "ruling", title: String(localized: "Ruling"), symbol: "line.3.horizontal",
                     items: choices(Ruling.allCases, current: style.ruling, title: \.title, apply: { $0.ruling = $1 },
                                    action: String(localized: "Ruling"))),
            .submenu(id: "fastener", title: String(localized: "Fastener"), symbol: "paperclip",
                     items: choices(Fastener.allCases, current: style.fastener, title: \.title, apply: { $0.fastener = $1 },
                                    action: String(localized: "Fastener"))),
            .submenu(id: "ink", title: String(localized: "Ink"), symbol: "pencil.tip",
                     items: choices(InkColor.allCases, current: style.ink, title: \.title, apply: { $0.ink = $1 },
                                    action: String(localized: "Ink"))),
        ]
    }

    // MARK: AppKit

    static func nsMenu(_ entries: [Entry]) -> NSMenu {
        let menu = NSMenu()
        for entry in entries {
            switch entry {
            case .item(let item): menu.addItem(nsItem(item))
            case .submenu(_, let title, let symbol, let items):
                let parent = NSMenuItem(title: title, action: nil, keyEquivalent: "")
                parent.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
                parent.submenu = NSMenu(title: title)
                for item in items { parent.submenu?.addItem(nsItem(item)) }
                menu.addItem(parent)
            case .separator: menu.addItem(.separator())
            }
        }
        return menu
    }

    private static func nsItem(_ item: Item) -> NSMenuItem {
        let menuItem = ActionMenuItem(item.title, symbol: item.checked == nil ? item.symbol : nil,
                                      keyEquivalent: item.keyEquivalent, modifiers: item.modifiers, handler: item.run)
        if let checked = item.checked { menuItem.state = checked ? .on : .off }
        return menuItem
    }
}

/// The SwiftUI rendering for `.contextMenu { … }` on the board.
struct StickyContextMenu: View {
    let entries: [StickyMenu.Entry]

    var body: some View {
        ForEach(entries) { entry in
            switch entry {
            case .item(let item): button(item)
            case .submenu(_, let title, let symbol, let items):
                Menu {
                    ForEach(items) { button($0) }
                } label: {
                    Label { Text(verbatim: title) } icon: { Image(systemName: symbol) }
                }
            case .separator: Divider()
            }
        }
    }

    @ViewBuilder private func button(_ item: StickyMenu.Item) -> some View {
        if let checked = item.checked {
            Toggle(isOn: Binding(get: { checked }, set: { _ in item.run() })) { Text(verbatim: item.title) }
        } else {
            Button(role: item.destructive ? .destructive : nil, action: item.run) {
                Label { Text(verbatim: item.title) } icon: { Image(systemName: item.symbol ?? "circle") }
            }
        }
    }
}

// MARK: Display names for the look submenus

extension StickySize {
    var title: String {
        switch self {
        case .small: String(localized: "Small")
        case .medium: String(localized: "Medium")
        case .large: String(localized: "Large")
        }
    }
}

extension Ruling {
    var title: String {
        switch self {
        case .none: String(localized: "Plain")
        case .lines: String(localized: "Lines")
        case .grid: String(localized: "Grid")
        case .dots: String(localized: "Dots")
        }
    }
}

extension Fastener {
    var title: String {
        switch self {
        case .none: String(localized: "None")
        case .tape: String(localized: "Tape")
        case .pin: String(localized: "Pin")
        case .clip: String(localized: "Clip")
        }
    }
}
