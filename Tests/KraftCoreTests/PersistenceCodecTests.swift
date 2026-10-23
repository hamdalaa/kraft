import Foundation
import Testing
@testable import KraftCore

/// Fixed dates and stickies shared by the persistence tests.
enum Fixture {
    static let t0 = Date(timeIntervalSince1970: 1_800_000_000.250)

    static func at(_ seconds: TimeInterval) -> Date { t0.addingTimeInterval(seconds) }

    static func sticky(_ title: String, id: UUID = UUID(), updated: TimeInterval = 0, deleted: TimeInterval? = nil) -> Sticky {
        Sticky(id: id, kind: .note, title: title, createdAt: t0, updatedAt: at(updated), deletedAt: deleted.map(at))
    }

    static func tempFolder() -> URL {
        let url = FileManager.default.temporaryDirectory.appending(path: "kraft-tests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}

@Suite struct PersistenceCodecTests {
    let device = UUID(uuidString: "6B1F3C2A-0000-4000-8000-000000000001")!

    func richStickies() -> [Sticky] {
        [
            Sticky(
                kind: .iOwe, title: "إيجار أحمد", body: "الدفعة الأولى ✓",
                money: MoneyInfo(person: "أحمد", amount: Decimal(string: "150000.75")!, currency: .iqd, dueDate: Fixture.at(86_400),
                                 payments: [Payment(amount: Decimal(string: "0.1")!, date: Fixture.at(10))]),
                style: PaperStyle(color: .pink, size: .medium, fastener: .tape, tilt: 2.6),
                createdAt: Fixture.t0, updatedAt: Fixture.at(0.123)
            ),
            Sticky(
                kind: .todo, title: "Groceries",
                checklist: [ChecklistItem(text: "حليب"), ChecklistItem(text: "Bread", isDone: true)],
                reminder: ReminderInfo(fireDate: Fixture.at(3_600), repeatRule: .weekly),
                createdAt: Fixture.t0, deletedAt: Fixture.at(5)
            ),
            Sticky(
                kind: .owedToMe, title: "Ali",
                money: MoneyInfo(person: "Ali", amount: Decimal(string: "12345.67")!, currency: .usd,
                                 payments: [Payment(amount: Decimal(string: "0.33")!, date: Fixture.t0)]),
                createdAt: Fixture.t0
            ),
        ]
    }

    @Test func roundTripKeepsArabicDecimalsAndDates() throws {
        let file = StickyFile(deviceID: device, seededSampleData: true, records: richStickies())
        let data = try StickyFileCodec.encode(file)
        let back = try StickyFileCodec.decode(data)
        #expect(back == file)
        #expect(back.records[0].money?.amount == Decimal(string: "150000.75"))
        #expect(back.records[0].money?.payments.first?.amount == Decimal(string: "0.1"))
        #expect(back.records[2].money?.remaining == Decimal(string: "12345.34"))
        #expect(back.records[0].title == "إيجار أحمد")
    }

    @Test func encodingIsPrettySortedISO8601AndUnescaped() throws {
        let file = StickyFile(deviceID: device, records: richStickies())
        let text = try #require(String(data: StickyFileCodec.encode(file), encoding: .utf8))
        #expect(text.contains("\n  \"deviceID\""))
        let keys = ["\"deviceID\"", "\"records\"", "\"schemaVersion\"", "\"seededSampleData\""].map { text.range(of: $0)!.lowerBound }
        #expect(keys == keys.sorted())
        #expect(text.contains("\"schemaVersion\" : 1"))
        #expect(text.contains("\"createdAt\" : \"2027-01-15T08:00:00.250Z\""))
        #expect(text.contains("إيجار أحمد"))
        #expect(text.contains("150000.75"))
    }

    @Test func encodingIsStable() throws {
        let file = StickyFile(deviceID: device, records: richStickies())
        #expect(try StickyFileCodec.encode(file) == StickyFileCodec.encode(StickyFileCodec.decode(StickyFileCodec.encode(file))))
    }

    @Test func readsDatesWithoutFractionAndMissingOptionalKeys() throws {
        let json = """
        {"schemaVersion": 1, "deviceID": "\(device.uuidString)", "records": [{
          "id": "\(UUID().uuidString)", "kind": "note", "title": "قديم", "body": "", "checklist": [],
          "style": {"color": "lemon", "handwriting": "auto", "size": "medium", "ink": "graphite", "ruling": "none", "fastener": "none", "tilt": 0},
          "isDone": false, "isOnDesktop": false,
          "createdAt": "2026-01-02T03:04:05Z", "updatedAt": "2026-01-02T03:04:05Z"}]}
        """
        let file = try StickyFileCodec.decode(Data(json.utf8))
        #expect(file.seededSampleData == false)
        #expect(file.records.first?.title == "قديم")
        #expect(file.records.first?.createdAt == Date(timeIntervalSince1970: 1_767_323_045))
    }

    @Test func newerSchemaIsRefused() throws {
        let json = #"{"schemaVersion": 99, "deviceID": "\#(device.uuidString)", "records": []}"#
        #expect(throws: StickyFileCodec.Failure.newerSchema(99)) { try StickyFileCodec.decode(Data(json.utf8)) }
    }

    @Test func garbageThrows() {
        #expect(throws: (any Error).self) { try StickyFileCodec.decode(Data("{\"schemaVersion\": 1, \"rec".utf8)) }
    }
}
