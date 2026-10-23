import Foundation

/// Where `stickies.json` and its `Backups/` folder live.
public enum StoreLocation: Equatable, Sendable {
    /// `~/Library/Application Support/Kraft/` — the default.
    case local
    /// `~/Library/Mobile Documents/com~apple~CloudDocs/Kraft/` — iCloud Drive, so a future iPhone app
    /// can merge the same file. Available, not switched on.
    case iCloudDrive
    /// Any folder (tests, `KRAFT_STORE_DIR`).
    case folder(URL)

    public static let fileName = "stickies.json"
    public static let backupsFolderName = "Backups"

    public var directory: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        switch self {
        case .local:
            let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? home.appending(path: "Library/Application Support", directoryHint: .isDirectory)
            return support.appending(path: "Kraft", directoryHint: .isDirectory)
        case .iCloudDrive:
            return home.appending(path: "Library/Mobile Documents/com~apple~CloudDocs/Kraft", directoryHint: .isDirectory)
        case .folder(let url):
            return url
        }
    }

    public var fileURL: URL { directory.appending(path: Self.fileName, directoryHint: .notDirectory) }
    public var backupsDirectory: URL { directory.appending(path: Self.backupsFolderName, directoryHint: .isDirectory) }
}
