import Foundation

/// Daily copies of `stickies.json` in `Backups/stickies-YYYY-MM-DD.json`, newest 30 kept.
public struct StickyBackups: Sendable {
    public static let keep = 30

    public let directory: URL
    public var calendar: Calendar

    public init(directory: URL, calendar: Calendar = .current) {
        self.directory = directory
        self.calendar = calendar
    }

    public func fileName(for date: Date) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "stickies-%04d-%02d-%02d.json", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// Copies `file` into today's backup unless today already has one, then prunes old ones.
    /// Returns the backup written, if any.
    @discardableResult
    public func backUpIfNeeded(_ file: URL, now: Date) throws -> URL? {
        let fm = FileManager.default
        guard fm.fileExists(atPath: file.path) else { return nil }
        let target = directory.appending(path: fileName(for: now), directoryHint: .notDirectory)
        guard !fm.fileExists(atPath: target.path) else { return nil }
        try PrivateFiles.makeFolder(directory)
        try fm.copyItem(at: file, to: target)
        PrivateFiles.restrictFile(target)
        try prune()
        return target
    }

    /// Backups, newest first (the date in the name sorts lexicographically).
    public func all() -> [URL] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        return names
            .filter { $0.hasPrefix("stickies-") && $0.hasSuffix(".json") && $0.count == "stickies-YYYY-MM-DD.json".count }
            .sorted(by: >)
            .map { directory.appending(path: $0, directoryHint: .notDirectory) }
    }

    public func prune(keeping count: Int = StickyBackups.keep) throws {
        for old in all().dropFirst(count) {
            try FileManager.default.removeItem(at: old)
        }
    }
}
