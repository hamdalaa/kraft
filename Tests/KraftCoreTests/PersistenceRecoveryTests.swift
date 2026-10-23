import Foundation
import Testing
@testable import KraftCore

@MainActor
@Suite struct PersistenceBackupTests {
    let folder = Fixture.tempFolder()
    var location: StoreLocation { .folder(folder) }
    var utc: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    @Test func firstSaveOfEachDayBacksUpThePreviousFile() throws {
        let day1 = Date(timeIntervalSince1970: 1_800_000_000)  // 2027-01-15 08:00 UTC
        let disk = StickyDisk(location: location, deviceID: UUID(), calendar: utc)
        let one = StickyFile(deviceID: disk.deviceID, records: [Fixture.sticky("v1")])
        try disk.write(one, now: day1)
        #expect(disk.backups.all().isEmpty, "nothing to back up before the first file exists")

        var two = one
        two.records[0].title = "v2"
        try disk.write(two, now: day1.addingTimeInterval(60))
        var three = two
        three.records[0].title = "v3"
        try disk.write(three, now: day1.addingTimeInterval(120))
        #expect(disk.backups.all().map(\.lastPathComponent) == ["stickies-2027-01-15.json"])
        #expect(try StickyFileCodec.decode(Data(contentsOf: disk.backups.all()[0])).records[0].title == "v1")

        var four = three
        four.records[0].title = "v4"
        try disk.write(four, now: day1.addingTimeInterval(86_400))
        #expect(disk.backups.all().map(\.lastPathComponent) == ["stickies-2027-01-16.json", "stickies-2027-01-15.json"])
        #expect(try StickyFileCodec.decode(Data(contentsOf: disk.backups.all()[0])).records[0].title == "v3")
    }

    @Test func rotationKeepsTheNewestThirty() throws {
        let backups = StickyBackups(directory: location.backupsDirectory, calendar: utc)
        try FileManager.default.createDirectory(at: backups.directory, withIntermediateDirectories: true)
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        for day in 0..<35 {
            let name = backups.fileName(for: start.addingTimeInterval(Double(day) * 86_400))
            try Data("{}".utf8).write(to: backups.directory.appending(path: name))
        }
        try Data("keep me".utf8).write(to: backups.directory.appending(path: "notes.txt"))

        try backups.prune()
        let names = backups.all().map(\.lastPathComponent)
        #expect(names.count == 30)
        #expect(names.first == "stickies-2027-02-18.json")
        #expect(names.last == "stickies-2027-01-20.json")
        #expect(FileManager.default.fileExists(atPath: backups.directory.appending(path: "notes.txt").path))
    }
}

@MainActor
@Suite struct PersistenceRecoveryTests {
    let folder = Fixture.tempFolder()
    let device = UUID()
    var location: StoreLocation { .folder(folder) }
    let garbage = Data("{\"schemaVersion\": 1, \"records\": [ {\"id\": tru".utf8)

    func corruptCopies() -> [URL] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
        return names.filter { $0.hasPrefix("stickies.corrupt-") }.map { folder.appending(path: $0) }
    }

    func writeBackup(_ name: String, _ records: [Sticky]) throws {
        try FileManager.default.createDirectory(at: location.backupsDirectory, withIntermediateDirectories: true)
        let data = try StickyFileCodec.encode(StickyFile(deviceID: UUID(), seededSampleData: true, records: records))
        try data.write(to: location.backupsDirectory.appending(path: name))
    }

    @Test func corruptFileIsMovedAsideAndNewestBackupLoaded() throws {
        try garbage.write(to: location.fileURL)
        try writeBackup("stickies-2027-01-14.json", [Fixture.sticky("older")])
        try writeBackup("stickies-2027-01-15.json", [Fixture.sticky("newest")])

        let repo = StickyRepository(disk: StickyDisk(location: location, deviceID: device), seed: { [Fixture.sticky("sample")] })

        #expect(repo.records.map(\.title) == ["newest"])
        let copies = corruptCopies()
        #expect(copies.count == 1)
        #expect(try Data(contentsOf: copies[0]) == garbage, "the corrupt bytes are kept untouched")
        guard case .recovered(let copy, let backup) = repo.loadOutcome else { Issue.record("not recovered"); return }
        #expect(copy?.lastPathComponent == copies[0].lastPathComponent)
        #expect(backup?.lastPathComponent == "stickies-2027-01-15.json")
        #expect(try StickyFileCodec.decode(Data(contentsOf: location.fileURL)).records.map(\.title) == ["newest"])
    }

    @Test func corruptBackupsAreSkipped() throws {
        try garbage.write(to: location.fileURL)
        try writeBackup("stickies-2027-01-14.json", [Fixture.sticky("good")])
        try garbage.write(to: location.backupsDirectory.appending(path: "stickies-2027-01-15.json"))
        let repo = StickyRepository(disk: StickyDisk(location: location, deviceID: device))
        #expect(repo.records.map(\.title) == ["good"])
    }

    @Test func corruptWithoutBackupsStartsEmptyAndDoesNotReseed() throws {
        try garbage.write(to: location.fileURL)
        let repo = StickyRepository(disk: StickyDisk(location: location, deviceID: device), seed: { [Fixture.sticky("sample")] })
        #expect(repo.records.isEmpty)
        #expect(repo.loadOutcome == .recovered(corruptCopy: corruptCopies().first, backup: nil))
        #expect(corruptCopies().count == 1)
    }

    @Test func fileCorruptedWhileRunningIsMovedAsideAndRewritten() throws {
        let repo = StickyRepository(disk: StickyDisk(location: location, deviceID: device), seed: { [Fixture.sticky("mine")] })
        try garbage.write(to: location.fileURL)
        repo.reloadFromDisk()
        #expect(corruptCopies().count == 1)
        #expect(repo.records.map(\.title) == ["mine"])
        repo.flush()
        #expect(try StickyFileCodec.decode(Data(contentsOf: location.fileURL)).records.map(\.title) == ["mine"])
    }

    @Test func newerSchemaIsShownButNeverOverwritten() throws {
        let future = Data(#"{"schemaVersion": 2, "deviceID": "\#(UUID().uuidString)", "records": [], "newThing": true}"#.utf8)
        try future.write(to: location.fileURL)
        let repo = StickyRepository(disk: StickyDisk(location: location, deviceID: device), seed: { [Fixture.sticky("sample")] })
        #expect(repo.loadOutcome == .readOnly)
        #expect(repo.records.isEmpty, "no samples seeded into a newer file")
        repo.add(Fixture.sticky("local"), actionName: "Add Sticky")
        repo.flush()
        #expect(try Data(contentsOf: location.fileURL) == future)
        #expect(corruptCopies().isEmpty)
    }
}
