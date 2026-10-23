import Foundation
import Observation
import os

/// The sticky records, every mutation with undo, and (when backed by a `StickyDisk`) debounced saves
/// and merging of outside changes. `StickyStore` in the app is a thin wrapper around this.
@MainActor
@Observable
public final class StickyRepository {
    /// All records, tombstones included.
    public private(set) var records: [Sticky]
    /// Undo target for every mutation; nil means changes are not undoable (no window yet).
    @ObservationIgnored public var undoManager: UndoManager?
    /// How the file was found at launch (nil when in memory only).
    public private(set) var loadOutcome: StickyDisk.Outcome?

    @ObservationIgnored public var now: () -> Date
    @ObservationIgnored public let saveDelay: Duration
    @ObservationIgnored public static let coalesceWindow: TimeInterval = 1.5

    @ObservationIgnored private let disk: StickyDisk?
    @ObservationIgnored private var seededSampleData: Bool
    @ObservationIgnored private var isDirty = false
    @ObservationIgnored private var saveTask: Task<Void, Never>?
    @ObservationIgnored private var reloadTask: Task<Void, Never>?
    @ObservationIgnored private var watcher: FolderWatcher?
    @ObservationIgnored private var coalescing: Coalescing?
    @ObservationIgnored private var registrations = 0
    @ObservationIgnored private let log = Logger(subsystem: "io.github.hamdalaa.kraft", category: "store")

    private struct Coalescing {
        var id: Sticky.ID
        var at: Date
        var registration: Int
        var undoManager: ObjectIdentifier
    }

    /// In memory only (snapshots, previews, tests).
    public init(records: [Sticky] = [], now: @escaping () -> Date = Date.init) {
        self.records = records
        self.now = now
        self.saveDelay = .zero
        self.disk = nil
        self.seededSampleData = true
    }

    /// Loads `disk` (recovering from backups if it is corrupt), seeds `seed()` once per file,
    /// purges tombstones older than 90 days, and saves `saveDelay` after each change.
    public init(
        disk: StickyDisk,
        seed: () -> [Sticky] = { [] },
        saveDelay: Duration = .milliseconds(500),
        now: @escaping () -> Date = Date.init
    ) {
        self.disk = disk
        self.now = now
        self.saveDelay = saveDelay
        let loaded = disk.load(now: now())
        var records = StickyMerge.purgeTombstones(loaded.file.records, now: now())
        var seeded = loaded.file.seededSampleData
        if !seeded, !disk.isReadOnly {
            records += seed()
            seeded = true
        }
        self.records = records
        self.seededSampleData = seeded
        self.loadOutcome = loaded.outcome
        if records != loaded.file.records || seeded != loaded.file.seededSampleData || loaded.outcome != .loaded {
            isDirty = true
            flush()
        }
    }

    public func sticky(_ id: Sticky.ID) -> Sticky? { records.first { $0.id == id } }

    // MARK: Mutations

    public func add(_ sticky: Sticky, actionName: String) {
        guard self.sticky(sticky.id) == nil else { return update(sticky, actionName: actionName) }
        var copy = sticky
        copy.updatedAt = now()
        records.append(copy)
        registerUndo(restoring: nil, for: sticky.id, actionName: actionName)
        coalescing = nil
        changed()
    }

    /// Replaces the record with the same id and bumps `updatedAt`. With `coalesce`, edits to the same
    /// sticky less than 1.5 s apart share one undo step (typing).
    public func update(_ sticky: Sticky, actionName: String, coalesce: Bool = false) {
        guard let index = records.firstIndex(where: { $0.id == sticky.id }) else { return }
        let previous = records[index]
        var copy = sticky
        copy.updatedAt = previous.updatedAt
        guard copy != previous else { return }
        let stamp = now()
        copy.updatedAt = stamp
        records[index] = copy
        if coalesce, joinsCoalescedStep(sticky.id, at: stamp) {
            coalescing?.at = stamp
        } else {
            registerUndo(restoring: previous, for: sticky.id, actionName: actionName)
            coalescing = coalesce ? undoManager.map {
                Coalescing(id: sticky.id, at: stamp, registration: registrations, undoManager: ObjectIdentifier($0))
            } : nil
        }
        changed()
    }

    /// Edits a record in place: `modify(id, actionName: "Tick Item") { $0.isDone.toggle() }`.
    public func modify(_ id: Sticky.ID, actionName: String, coalesce: Bool = false, _ change: (inout Sticky) -> Void) {
        guard var s = sticky(id) else { return }
        change(&s)
        update(s, actionName: actionName, coalesce: coalesce)
    }

    /// Soft delete: a tombstone that other devices learn about when they merge.
    public func delete(_ id: Sticky.ID, actionName: String) {
        modify(id, actionName: actionName) { $0.deletedAt = now() }
    }

    private func joinsCoalescedStep(_ id: Sticky.ID, at stamp: Date) -> Bool {
        guard let c = coalescing, let undoManager else { return false }
        return c.id == id
            && c.registration == registrations
            && c.undoManager == ObjectIdentifier(undoManager)
            && stamp.timeIntervalSince(c.at) < Self.coalesceWindow
            && undoManager.canUndo
    }

    // MARK: Undo

    /// Registers "put `snapshot` back" (nil = the record did not exist) as one named undo step.
    private func registerUndo(restoring snapshot: Sticky?, for id: Sticky.ID, actionName: String) {
        guard let undoManager else { return }
        undoManager.beginUndoGrouping()
        undoManager.registerUndo(withTarget: self) { repo in
            MainActor.assumeIsolated { repo.restore(snapshot, for: id, actionName: actionName) }
        }
        undoManager.setActionName(actionName)
        undoManager.endUndoGrouping()
        registrations += 1
    }

    /// Undo/redo: puts a snapshot back, stamped now so the restore also wins the next merge.
    private func restore(_ snapshot: Sticky?, for id: Sticky.ID, actionName: String) {
        let current = sticky(id)
        registerUndo(restoring: current, for: id, actionName: actionName)
        coalescing = nil
        let stamp = now()
        if var back = snapshot {
            back.updatedAt = stamp
            if let index = records.firstIndex(where: { $0.id == id }) { records[index] = back } else { records.append(back) }
        } else if let index = records.firstIndex(where: { $0.id == id }) {
            records[index].deletedAt = stamp
            records[index].updatedAt = stamp
        }
        changed()
    }

    // MARK: Saving

    private func changed() {
        guard disk != nil else { return }
        isDirty = true
        saveTask?.cancel()
        let delay = saveDelay
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            self?.flush()
        }
    }

    /// Writes pending changes now (debounce elapsed, app quitting, tests).
    public func flush() {
        saveTask?.cancel()
        saveTask = nil
        guard let disk, isDirty else { return }
        isDirty = false
        do {
            let file = StickyFile(deviceID: disk.deviceID, seededSampleData: seededSampleData, records: records)
            let written = try disk.write(file, now: now())
            seededSampleData = written.seededSampleData
            if written.records != records { records = written.records }
        } catch {
            log.error("Saving stickies failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    public var hasUnsavedChanges: Bool { isDirty }

    // MARK: Outside changes

    /// Watches the store folder and merges changes written by other processes or devices.
    public func startWatching() {
        guard let disk, watcher == nil else { return }
        watcher = FolderWatcher(directory: disk.location.directory, file: disk.fileURL) { [weak self] in
            self?.scheduleReload()
        }
    }

    public func stopWatching() {
        watcher?.cancel()
        watcher = nil
    }

    private func scheduleReload() {
        reloadTask?.cancel()
        reloadTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }
            self?.reloadFromDisk()
        }
    }

    /// Merges whatever another writer left in the file. Local changes that the file lacks are saved back.
    public func reloadFromDisk() {
        guard let disk else { return }
        switch disk.readChange(now: now()) {
        case .unchanged:
            return
        case .changed(let outside):
            seededSampleData = seededSampleData || outside.seededSampleData
            let merged = StickyMerge.merge(local: records, remote: outside.records)
            if merged != records { records = merged }
            if merged != outside.records { changed() }
        case .missing, .corrupt:
            changed()
        }
    }
}
