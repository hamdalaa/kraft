import AppKit
import Foundation
import KraftCore
import Observation

/// The single source of truth for stickies. Board, editor, quick add, desktop stickies and
/// reminders all read `stickies` and write through these methods only.
///
/// OWNER: `store` session. A thin wrapper over `StickyRepository` (KraftCore), which does the
/// persistence, per-record merge, undo and daily backups. Keep this API stable.
@MainActor
@Observable
final class StickyStore {
    @ObservationIgnored let repository: StickyRepository
    @ObservationIgnored private var quitObserver: (any NSObjectProtocol)?

    /// All records, tombstones included — filter with `live` or `BoardTab`.
    var stickies: [Sticky] { repository.records }

    /// Set from the board window so Edit ▸ Undo/Redo (⌘Z / ⇧⌘Z) covers store changes.
    var undoManager: UndoManager? {
        get { repository.undoManager }
        set { repository.undoManager = newValue }
    }

    /// In memory only (snapshots, previews).
    init(stickies: [Sticky] = []) {
        repository = StickyRepository(records: stickies)
    }

    /// Backed by `stickies.json` in `location`: loads (or recovers), seeds samples on first run,
    /// saves 0.5 s after each change, flushes on quit and merges outside changes.
    init(location: StoreLocation, deviceID: UUID) {
        repository = StickyRepository(disk: StickyDisk(location: location, deviceID: deviceID), seed: { SampleData.stickies() })
        repository.startWatching()
        quitObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.flush() }
        }
    }

    /// The app's store: `~/Library/Application Support/Kraft/` (or `KRAFT_STORE_DIR`);
    /// in snapshot mode an in-memory copy of the samples so renders never touch real data.
    static func persistent() -> StickyStore {
        let env = ProcessInfo.processInfo.environment
        if env["KRAFT_SNAPSHOT"] != nil { return StickyStore(stickies: SampleData.stickies()) }
        let location = env["KRAFT_STORE_DIR"].map { StoreLocation.folder(URL(fileURLWithPath: $0, isDirectory: true)) } ?? .local
        return StickyStore(location: location, deviceID: deviceID)
    }

    /// Identifies this Mac in the file's envelope. Per device, so it lives in UserDefaults.
    private static var deviceID: UUID {
        let key = "KraftDeviceID"
        if let text = UserDefaults.standard.string(forKey: key), let id = UUID(uuidString: text) { return id }
        let id = UUID()
        UserDefaults.standard.set(id.uuidString, forKey: key)
        return id
    }

    /// Live (not deleted) stickies.
    var live: [Sticky] { stickies.filter { $0.deletedAt == nil } }

    func sticky(_ id: Sticky.ID) -> Sticky? { repository.sticky(id) }

    func add(_ sticky: Sticky) {
        repository.add(sticky, actionName: String(localized: "Add Sticky"))
    }

    /// Replaces the record with the same id and bumps `updatedAt`.
    /// `actionName` labels Edit ▸ Undo; `coalesce: true` merges rapid edits (typing) into one undo step.
    func update(_ sticky: Sticky, actionName: String? = nil, coalesce: Bool = false) {
        repository.update(sticky, actionName: actionName ?? String(localized: "Edit Sticky"), coalesce: coalesce)
    }

    /// Soft delete (tombstone) so other devices learn about it when merging.
    func delete(_ id: Sticky.ID) {
        repository.delete(id, actionName: String(localized: "Delete Sticky"))
    }

    func toggleChecklistItem(_ item: ChecklistItem.ID, in id: Sticky.ID) {
        let ticking = sticky(id)?.checklist.first { $0.id == item }?.isDone == false
        let name = ticking ? String(localized: "Tick Item") : String(localized: "Untick Item")
        repository.modify(id, actionName: name) { s in
            s.checklist = s.checklist.map { $0.id == item ? ChecklistItem(id: $0.id, text: $0.text, isDone: !$0.isDone) : $0 }
        }
    }

    func setDone(_ isDone: Bool, for id: Sticky.ID) {
        let name = isDone ? String(localized: "Mark as Done") : String(localized: "Mark as Not Done")
        repository.modify(id, actionName: name) { s in
            s.isDone = isDone
            s.completedAt = isDone ? Date() : nil
        }
    }

    /// Writes pending changes immediately (also runs automatically on quit).
    func flush() { repository.flush() }
}
