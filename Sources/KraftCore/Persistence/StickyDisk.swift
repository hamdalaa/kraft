import Foundation
import os

/// Reads and writes `stickies.json` in a `StoreLocation`.
///
/// - Every write is read-merge-write: outside changes that landed since our last read are merged in first.
/// - Writes are atomic and coordinated (`NSFileCoordinator`), so iCloud Drive sees whole files only.
/// - The first write of each day copies the old file to `Backups/` first.
/// - A corrupt or unreadable file is never overwritten: it is moved aside to
///   `stickies.corrupt-<date>.json` and the newest readable backup is loaded instead.
public final class StickyDisk {
    public enum Outcome: Equatable, Sendable {
        /// No file yet.
        case fresh
        case loaded
        /// The file was corrupt; it was moved to `corruptCopy` (nil if it could not be moved) and
        /// `backup` (nil when none was readable) was loaded instead.
        case recovered(corruptCopy: URL?, backup: URL?)
        /// Written by a newer Kraft or unreadable in place: shown, never written.
        case readOnly
    }

    public enum Change: Equatable, Sendable {
        case unchanged
        case changed(StickyFile)
        case missing
        /// The new contents were corrupt and have been moved aside.
        case corrupt
    }

    public let location: StoreLocation
    public let deviceID: UUID
    public let backups: StickyBackups
    public private(set) var isReadOnly = false
    /// Bytes we last read or wrote; equal bytes on disk mean "no outside change".
    private var knownData: Data?
    private let log = Logger(subsystem: "io.github.hamdalaa.kraft", category: "store")

    public init(location: StoreLocation, deviceID: UUID, calendar: Calendar = .current) {
        self.location = location
        self.deviceID = deviceID
        self.backups = StickyBackups(directory: location.backupsDirectory, calendar: calendar)
        try? PrivateFiles.makeFolder(location.directory) // owner-only
        PrivateFiles.tighten(location.directory)
        PrivateFiles.tighten(location.backupsDirectory)
    }

    public var fileURL: URL { location.fileURL }

    // MARK: Load

    public func load(now: Date = Date()) -> (file: StickyFile, outcome: Outcome) {
        let empty = StickyFile(deviceID: deviceID)
        let data: Data
        switch read() {
        case .none:
            return (empty, .fresh)
        case .failure(let error):
            log.error("stickies.json unreadable: \(error.localizedDescription, privacy: .public)")
            return recover(now: now)
        case .some(.success(let bytes)):
            data = bytes
        }
        do {
            let file = try StickyFileCodec.decode(data)
            knownData = data
            return (file, .loaded)
        } catch StickyFileCodec.Failure.newerSchema(let version) {
            log.error("stickies.json has schema \(version); this build reads \(StickyFile.currentSchemaVersion). Read-only.")
            isReadOnly = true
            let records = (try? StickyFileCodec.decode(data, allowingNewerSchema: true))?.records ?? []
            return (StickyFile(deviceID: deviceID, seededSampleData: true, records: records), .readOnly)
        } catch {
            log.error("stickies.json corrupt: \(String(describing: error), privacy: .private)")
            return recover(now: now)
        }
    }

    private func recover(now: Date) -> (file: StickyFile, outcome: Outcome) {
        let moved = moveAside(now: now)
        if moved == nil { isReadOnly = true }
        for backup in backups.all() {
            guard let data = try? Data(contentsOf: backup), let file = try? StickyFileCodec.decode(data) else { continue }
            log.notice("Recovered stickies from \(backup.lastPathComponent, privacy: .public)")
            return (file, moved == nil ? .readOnly : .recovered(corruptCopy: moved, backup: backup))
        }
        let blank = StickyFile(deviceID: deviceID, seededSampleData: true)
        return (blank, moved == nil ? .readOnly : .recovered(corruptCopy: moved, backup: nil))
    }

    /// Moves the current file to `stickies.corrupt-<date>.json`. Returns the new URL, nil on failure.
    @discardableResult
    func moveAside(now: Date) -> URL? {
        let stamp = now.formatted(.verbatim(
            "\(year: .defaultDigits)-\(month: .twoDigits)-\(day: .twoDigits)-\(hour: .twoDigits(clock: .twentyFourHour, hourCycle: .zeroBased))\(minute: .twoDigits)\(second: .twoDigits)",
            timeZone: .current, calendar: Calendar(identifier: .gregorian)))
        let fm = FileManager.default
        var target = location.directory.appending(path: "stickies.corrupt-\(stamp).json")
        var n = 2
        while fm.fileExists(atPath: target.path) {
            target = location.directory.appending(path: "stickies.corrupt-\(stamp)-\(n).json")
            n += 1
        }
        do {
            try fm.moveItem(at: fileURL, to: target)
            PrivateFiles.restrictFile(target)
            knownData = nil
            log.error("Moved corrupt stickies.json to \(target.lastPathComponent, privacy: .public)")
            return target
        } catch {
            log.error("Could not move corrupt stickies.json aside: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    // MARK: Watch

    /// What changed on disk since our last read or write.
    public func readChange(now: Date = Date()) -> Change {
        switch read() {
        case .none:
            knownData = nil
            return .missing
        case .failure:
            return .unchanged
        case .some(.success(let data)):
            if data == knownData { return .unchanged }
            do {
                let file = try StickyFileCodec.decode(data)
                knownData = data
                return .changed(file)
            } catch StickyFileCodec.Failure.newerSchema {
                isReadOnly = true
                return .unchanged
            } catch {
                return moveAside(now: now) == nil ? .unchanged : .corrupt
            }
        }
    }

    // MARK: Write

    /// Merges any outside change into `file`, backs up once a day, writes atomically.
    /// Returns what is now on disk (the merged file). Identical bytes are not rewritten.
    @discardableResult
    public func write(_ file: StickyFile, now: Date = Date()) throws -> StickyFile {
        guard !isReadOnly else { return file }
        var merged = file
        merged.deviceID = deviceID
        if case .changed(let outside) = readChange(now: now) {
            merged.records = StickyMerge.merge(local: file.records, remote: outside.records)
            merged.seededSampleData = file.seededSampleData || outside.seededSampleData
        }
        guard !isReadOnly else { return merged }
        let data = try StickyFileCodec.encode(merged)
        if data == knownData { return merged }
        do {
            try backups.backUpIfNeeded(fileURL, now: now)
        } catch {
            log.error("Daily backup failed: \(error.localizedDescription, privacy: .public)")
        }
        try coordinated(writing: true) { url in
            try data.write(to: url, options: .atomic)
            PrivateFiles.restrictFile(url)
        }
        knownData = data
        return merged
    }

    // MARK: File access

    /// nil when the file does not exist.
    private func read() -> Result<Data, any Error>? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        do {
            return .success(try coordinated(writing: false) { try Data(contentsOf: $0) })
        } catch {
            return .failure(error)
        }
    }

    private func coordinated<T>(writing: Bool, _ body: (URL) throws -> T) throws -> T {
        let coordinator = NSFileCoordinator(filePresenter: nil)
        var coordinationError: NSError?
        var result: Result<T, any Error>?
        if writing {
            coordinator.coordinate(writingItemAt: fileURL, options: .forReplacing, error: &coordinationError) { url in
                result = Result { try body(url) }
            }
        } else {
            coordinator.coordinate(readingItemAt: fileURL, options: [], error: &coordinationError) { url in
                result = Result { try body(url) }
            }
        }
        if let coordinationError { throw coordinationError }
        guard let result else { throw CocoaError(.fileReadUnknown) }
        return try result.get()
    }
}
