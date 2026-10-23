import Foundation
import Testing
@testable import KraftCore

/// Stickies hold money and private reminders: other accounts on the Mac must not be able to read them.
@Suite struct PersistencePermissionsTests {
    let folder = Fixture.tempFolder().appending(path: "Kraft", directoryHint: .isDirectory)

    private func mode(_ url: URL) throws -> Int16 {
        let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
        return (attrs[.posixPermissions] as? NSNumber)?.int16Value ?? -1
    }

    @Test func dataFileFolderAndBackupsAreOwnerOnly() throws {
        let location = StoreLocation.folder(folder)
        let disk = StickyDisk(location: location, deviceID: UUID())
        let day1 = Date(timeIntervalSince1970: 1_800_000_000)
        try disk.write(StickyFile(deviceID: UUID(), records: [Sticky(kind: .note, title: "a")]), now: day1)
        // Next day: the first save backs the old file up.
        try disk.write(StickyFile(deviceID: UUID(), records: [Sticky(kind: .note, title: "b")]), now: day1.addingTimeInterval(86_400))

        #expect(try mode(folder) == 0o700)
        #expect(try mode(location.fileURL) == 0o600)
        let backup = try #require(StickyBackups(directory: location.backupsDirectory).all().first)
        #expect(try mode(location.backupsDirectory) == 0o700)
        #expect(try mode(backup) == 0o600)
    }
}
