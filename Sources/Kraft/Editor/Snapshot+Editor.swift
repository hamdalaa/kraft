import AppKit
import KraftCore
import SwiftUI

extension Snapshot {
    /// Offscreen renders for this area: (file name without extension, view). Owned by the Editor session.
    /// Rendered through a real window first (`EditorCapture`) because the editor is made of text fields.
    static func editorShots() -> [(String, AnyView)] {
        var samples = SampleData.stickies()
        // A second payment so the money sticky shows a real list.
        if let i = samples.firstIndex(where: { $0.kind == .owedToMe }) {
            samples[i].money?.payments.append(Payment(amount: 5, date: Date()))
            samples[i].body = "For the concert tickets"
        }
        samples.append(Sticky(kind: .todo, title: "مشتريات", checklist: [
            ChecklistItem(text: "حليب"), ChecklistItem(text: "خبز", isDone: true), ChecklistItem(text: "تمر للوالدة"),
        ], style: PaperStyle(color: .lilac, ruling: .dots, fastener: .clip, tilt: 1)))
        func board(_ kind: StickyKind, arabic: Bool = false) -> AnyView {
            let model = BoardModel(store: StickyStore(stickies: samples))
            model.editingID = (kind == .todo && arabic ? samples.last : samples.first { $0.kind == kind })?.id
            return AnyView(EditorCapture.image(BoardScreen(model: model, scrolls: false).frame(width: 1220, height: 820)))
        }
        func card(_ view: some View) -> AnyView {
            AnyView(EditorCapture.image(
                view.background(EditorCardBackground()).padding(40).background(Tok.Kraft.base)
            ))
        }
        let edit = { (s: Sticky) in StickyEditing(store: StickyStore(stickies: samples), id: s.id) }
        let ali = samples.first { $0.kind == .owedToMe }!
        let ahmad = samples.first { $0.kind == .iOwe }!
        var openAhmad = ahmad
        openAhmad.money?.payments = [Payment(amount: 50_000, date: Date())]

        return [
            ("editor-note", board(.note)),
            ("editor-money", board(.owedToMe)),
            ("editor-reminder", board(.reminder)),
            ("editor-todo", board(.todo)),
            ("editor-todo-ar", board(.todo, arabic: true)),
            ("editor-bill", board(.bill)),
            ("editor-look", card(EditorLookPanel(sticky: ali, edit: edit(ali)))),
            ("editor-remind-en", card(EditorRemindPopover(sticky: ali))),
            ("editor-remind-ar", card(EditorRemindPopover(sticky: openAhmad))),
        ]
    }
}

/// Renders a view through a real (offscreen) window so AppKit-backed controls — text fields, date pickers —
/// draw as they do on screen. `ImageRenderer` leaves them blank.
@MainActor
enum EditorCapture {
    static func image(_ view: some View) -> some View {
        let scheme = AppPreferences.shared.snapshotScheme
        let host = NSHostingView(rootView: view.kraftEnvironment().environment(\.colorScheme, scheme))
        let size = host.fittingSize
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)
        window.contentView = host
        host.frame = NSRect(origin: .zero, size: size)
        host.layoutSubtreeIfNeeded()
        host.displayIfNeeded()
        guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return Image(nsImage: NSImage()).frame(width: 1, height: 1) }
        host.cacheDisplay(in: host.bounds, to: rep)
        let image = NSImage(size: size)
        image.addRepresentation(rep)
        return Image(nsImage: image).frame(width: size.width, height: size.height)
    }
}
