import Foundation

/// The on-disk envelope of `stickies.json`.
///
/// ```json
/// { "schemaVersion": 1, "deviceID": "…", "seededSampleData": true, "records": [ … ] }
/// ```
/// `deviceID` names the device that wrote the file last. `seededSampleData` remembers the first-run
/// samples in the file itself, so a second device or a reinstall never seeds twice.
public struct StickyFile: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var deviceID: UUID
    public var seededSampleData: Bool
    public var records: [Sticky]

    public init(
        schemaVersion: Int = StickyFile.currentSchemaVersion,
        deviceID: UUID,
        seededSampleData: Bool = false,
        records: [Sticky] = []
    ) {
        self.schemaVersion = schemaVersion
        self.deviceID = deviceID
        self.seededSampleData = seededSampleData
        self.records = records
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try c.decode(Int.self, forKey: .schemaVersion)
        deviceID = try c.decode(UUID.self, forKey: .deviceID)
        seededSampleData = try c.decodeIfPresent(Bool.self, forKey: .seededSampleData) ?? false
        records = try c.decodeIfPresent([Sticky].self, forKey: .records) ?? []
    }
}

/// JSON codec for `StickyFile`: ISO-8601 dates (with milliseconds), pretty-printed, sorted keys —
/// stable bytes, readable diffs, and decodable by a future iPhone app.
public enum StickyFileCodec {
    public enum Failure: Error, Equatable {
        /// Valid JSON written by a newer Kraft; this build must not overwrite it.
        case newerSchema(Int)
    }

    public static func encode(_ file: StickyFile) throws -> Data {
        var data = try encoder.encode(file)
        data.append(0x0A)
        return data
    }

    public static func decode(_ data: Data, allowingNewerSchema: Bool = false) throws -> StickyFile {
        let probe = try decoder.decode(SchemaProbe.self, from: data)
        guard allowingNewerSchema || probe.schemaVersion <= StickyFile.currentSchemaVersion else {
            throw Failure.newerSchema(probe.schemaVersion)
        }
        return try decoder.decode(StickyFile.self, from: data)
    }

    /// Canonical bytes of one record, used for the deterministic merge tie-break.
    static func canonical(_ sticky: Sticky) -> Data {
        (try? encoder.encode(sticky)) ?? Data()
    }

    private struct SchemaProbe: Decodable { var schemaVersion: Int }

    private static var encoder: JSONEncoder {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        e.dateEncodingStrategy = .custom { date, encoder in
            var c = encoder.singleValueContainer()
            try c.encode(date.formatted(fractional))
        }
        return e
    }

    private static var decoder: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let c = try decoder.singleValueContainer()
            let text = try c.decode(String.self)
            if let date = try? Date(text, strategy: fractional) { return date }
            if let date = try? Date(text, strategy: whole) { return date }
            throw DecodingError.dataCorruptedError(in: c, debugDescription: "Not an ISO-8601 date: \(text)")
        }
        return d
    }

    private static let fractional = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
    private static let whole = Date.ISO8601FormatStyle()
}
