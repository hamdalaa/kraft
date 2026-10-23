import Foundation

/// Stickies hold money and personal reminders: keep every file owner-only (0600) and every folder 0700,
/// so other accounts on the same Mac cannot read them.
enum PrivateFiles {
    static let fileMode: Int16 = 0o600
    static let folderMode: Int16 = 0o700

    static func restrictFile(_ url: URL) {
        try? FileManager.default.setAttributes([.posixPermissions: fileMode], ofItemAtPath: url.path)
    }

    /// Fixes files written by older builds: folder → 0700, every JSON inside → 0600.
    static func tighten(_ folder: URL) {
        let fm = FileManager.default
        guard fm.fileExists(atPath: folder.path) else { return }
        try? fm.setAttributes([.posixPermissions: folderMode], ofItemAtPath: folder.path)
        for name in (try? fm.contentsOfDirectory(atPath: folder.path)) ?? [] where name.hasSuffix(".json") {
            restrictFile(folder.appending(path: name, directoryHint: .notDirectory))
        }
    }

    static func makeFolder(_ url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true,
                                                attributes: [.posixPermissions: folderMode])
        try? FileManager.default.setAttributes([.posixPermissions: folderMode], ofItemAtPath: url.path)
    }
}
