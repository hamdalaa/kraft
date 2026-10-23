import Foundation

/// A release version such as `v1.2.0` or `1.2`: numeric parts compared in order, missing parts read as 0.
/// Anything after the numbers (`-beta`, `-2-gabc123`) is ignored.
public struct AppVersion: Comparable, Sendable, CustomStringConvertible {
    public let parts: [Int]

    public init?(_ text: String) {
        var s = Substring(text.trimmingCharacters(in: .whitespaces))
        if s.first == "v" || s.first == "V" { s = s.dropFirst() }
        var parts: [Int] = []
        for piece in s.split(separator: ".", omittingEmptySubsequences: false) {
            let digits = piece.prefix { $0.isASCII && $0.isNumber }
            guard let n = Int(digits) else { break }
            parts.append(n)
            if digits.count != piece.count { break }
        }
        guard !parts.isEmpty else { return nil }
        self.parts = parts
    }

    public var description: String { parts.map(String.init).joined(separator: ".") }

    public static func < (a: AppVersion, b: AppVersion) -> Bool {
        for i in 0..<max(a.parts.count, b.parts.count) {
            let x = i < a.parts.count ? a.parts[i] : 0, y = i < b.parts.count ? b.parts[i] : 0
            if x != y { return x < y }
        }
        return false
    }

    public static func == (a: AppVersion, b: AppVersion) -> Bool { !(a < b) && !(b < a) }
}

/// The newest published release, read from GitHub's `releases/latest` JSON.
public struct AppRelease: Equatable, Sendable {
    public let version: AppVersion
    public let title: String
    public let notes: String
    public let pageURL: URL
    /// The `Kraft.zip` asset, when the release has one.
    public let downloadURL: URL?

    public static func == (a: AppRelease, b: AppRelease) -> Bool { a.version == b.version && a.pageURL == b.pageURL }

    private struct Wire: Decodable {
        struct Asset: Decodable { let name: String; let browser_download_url: URL }
        let tag_name: String
        let name: String?
        let body: String?
        let html_url: URL
        let draft: Bool?
        let prerelease: Bool?
        let assets: [Asset]
    }

    /// Nil for drafts, pre-releases and tags that are not versions.
    public static func decode(_ data: Data, assetName: String = "Kraft.zip") throws -> AppRelease? {
        let w = try JSONDecoder().decode(Wire.self, from: data)
        guard w.draft != true, w.prerelease != true, let version = AppVersion(w.tag_name) else { return nil }
        return AppRelease(version: version, title: w.name ?? w.tag_name, notes: w.body ?? "", pageURL: w.html_url,
                          downloadURL: w.assets.first { $0.name == assetName }?.browser_download_url)
    }

    public init(version: AppVersion, title: String, notes: String, pageURL: URL, downloadURL: URL?) {
        self.version = version; self.title = title; self.notes = notes; self.pageURL = pageURL; self.downloadURL = downloadURL
    }
}

public enum UpdatePolicy {
    /// Automatic checks run at most once a day.
    public static let interval: TimeInterval = 24 * 60 * 60

    public static func isNewer(_ release: AppRelease?, than current: AppVersion?) -> Bool {
        guard let release else { return false }
        guard let current else { return true }
        return current < release.version
    }

    public static func shouldCheck(lastCheck: Date?, now: Date, automatic: Bool) -> Bool {
        guard automatic else { return false }
        guard let lastCheck else { return true }
        return now.timeIntervalSince(lastCheck) >= interval || lastCheck > now
    }
}
