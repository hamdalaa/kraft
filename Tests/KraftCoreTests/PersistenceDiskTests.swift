import Foundation
import Testing
@testable import KraftCore

@MainActor
@Suite struct PersistenceDiskTests {
    let folder = Fixture.tempFolder()
    let mac = UUID(), phone = UUID()
    let clock = TestClock()
    var location: StoreLocation { .folder(folder) }

    func repo(_ device: UUID? = nil, seed: [Sticky] = []) -> StickyRepository {
        let clock = clock
        return StickyRepository(disk: StickyDisk(location: location, deviceID: device ?? mac), seed: { seed }, saveDelay: .seconds(60), now: { clock.now })
    }

    func onDisk() throws -> StickyFile {
        try StickyFileCodec.decode(Data(contentsOf: location.fileURL))
    }

    @Test func firstRunSeedsOnceAndRemembersItInTheFile() throws {
        let first = repo(seed: [Fixture.sticky("sample")])
        #expect(first.loadOutcome == .fresh)
        #expect(try onDisk().seededSampleData)
        #expect(try onDisk().deviceID == mac)
        first.delete(first.records[0].id, actionName: "Delete Sticky")
        first.flush()

        let second = repo(seed: [Fixture.sticky("sample")])
        #expect(second.loadOutcome == .loaded)
        #expect(second.records.count == 1)
        #expect(second.records[0].deletedAt != nil)
    }

    @Test func savesAreDebouncedAndFlushWrites() throws {
        let r = repo()
        r.add(Fixture.sticky("علي يدين لي"), actionName: "Add Sticky")
        #expect(r.hasUnsavedChanges)
        #expect(try onDisk().records.isEmpty, "nothing written before the debounce fires")
        r.flush()
        #expect(!r.hasUnsavedChanges)
        #expect(try onDisk().records.map(\.title) == ["علي يدين لي"])
        #expect(repo().records == r.records)
    }

    @Test func debounceFiresOnItsOwn() async throws {
        let r = StickyRepository(disk: StickyDisk(location: location, deviceID: mac), saveDelay: .milliseconds(50))
        r.add(Fixture.sticky("soon"), actionName: "Add Sticky")
        r.add(Fixture.sticky("sooner"), actionName: "Add Sticky")
        try await Task.sleep(for: .milliseconds(400))
        #expect(!r.hasUnsavedChanges)
        #expect(try onDisk().records.count == 2)
    }

    @Test func oldTombstonesArePurgedOnLoad() throws {
        let file = StickyFile(deviceID: phone, seededSampleData: true, records: [
            Fixture.sticky("gone", deleted: -91 * 86_400), Fixture.sticky("kept", deleted: -2 * 86_400), Fixture.sticky("live"),
        ])
        try StickyFileCodec.encode(file).write(to: location.fileURL)
        let r = repo()
        #expect(r.records.map(\.title) == ["kept", "live"])
        #expect(try onDisk().records.map(\.title) == ["kept", "live"])
    }

    @Test func outsideChangesAreMergedIn() throws {
        let macRepo = repo(seed: [Fixture.sticky("shared")])
        let shared = macRepo.records[0]
        let phoneRepo = repo(phone)

        clock.advance(5)
        phoneRepo.modify(shared.id, actionName: "Edit Sticky") { $0.title = "من الآيفون" }
        phoneRepo.add(Fixture.sticky("phone note"), actionName: "Add Sticky")
        phoneRepo.flush()
        #expect(try onDisk().deviceID == phone)

        macRepo.add(Fixture.sticky("mac note"), actionName: "Add Sticky")
        macRepo.reloadFromDisk()
        #expect(Set(macRepo.records.map(\.title)) == ["من الآيفون", "phone note", "mac note"])
        #expect(macRepo.hasUnsavedChanges, "the mac-only note still has to reach the file")
        macRepo.flush()
        #expect(Set(try onDisk().records.map(\.title)) == ["من الآيفون", "phone note", "mac note"])
    }

    @Test func writeMergesChangesTheWatcherHasNotDelivered() throws {
        let macRepo = repo(seed: [Fixture.sticky("a"), Fixture.sticky("b")])
        let phoneRepo = repo(phone)
        let (a, b) = (macRepo.records[0], macRepo.records[1])

        clock.advance(1)
        phoneRepo.delete(a.id, actionName: "Delete Sticky")
        phoneRepo.flush()
        clock.advance(1)
        macRepo.modify(b.id, actionName: "Edit Sticky") { $0.title = "b2" }
        macRepo.flush()

        let disk = try onDisk().records
        #expect(disk.first { $0.id == a.id }?.deletedAt != nil)
        #expect(disk.first { $0.id == b.id }?.title == "b2")
        #expect(macRepo.sticky(a.id)?.deletedAt != nil)
    }

    @Test func ownWritesAreNotOutsideChanges() {
        let r = repo(seed: [Fixture.sticky("x")])
        r.reloadFromDisk()
        #expect(!r.hasUnsavedChanges)
    }

    @Test func watcherPicksUpAnotherWriter() async throws {
        let macRepo = repo()
        macRepo.startWatching()
        defer { macRepo.stopWatching() }
        let phoneRepo = repo(phone)
        phoneRepo.add(Fixture.sticky("وصل"), actionName: "Add Sticky")
        phoneRepo.flush()
        for _ in 0..<40 where macRepo.records.isEmpty {
            try await Task.sleep(for: .milliseconds(50))
        }
        #expect(macRepo.records.map(\.title) == ["وصل"])
    }
}
