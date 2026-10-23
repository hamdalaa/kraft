import Foundation
import KraftCore
import Testing

@Suite struct AppUpdateTests {
    @Test(arguments: [
        ("v1.2.0", "1.2.0"), ("1.2", "1.2"), ("V2", "2"), ("v1.1.0-2-gfda3aaf", "1.1.0"), (" 1.10.3 ", "1.10.3"), ("1.2beta", "1.2"),
    ])
    func parses(_ text: String, _ expected: String) throws {
        #expect(try #require(AppVersion(text)).description == expected)
    }

    @Test(arguments: ["", "v", "beta", "x1.2"])
    func rejectsNonVersions(_ text: String) { #expect(AppVersion(text) == nil) }

    @Test func comparesNumericallyNotAsText() throws {
        let v = { (s: String) in AppVersion(s)! }
        #expect(v("1.10.0") > v("1.9.9"))
        #expect(v("1.2") == v("1.2.0"))
        #expect(v("0.1") < v("1.1.1"))
        #expect(!(v("1.2.0") < v("1.2")))
    }

    static func json(tag: String, draft: Bool = false, prerelease: Bool = false, asset: String = "Kraft.zip") -> Data {
        Data("""
        {"tag_name":"\(tag)","name":"Kraft \(tag)","body":"New icon","html_url":"https://github.com/hamdalaa/kraft/releases/tag/\(tag)",
         "draft":\(draft),"prerelease":\(prerelease),
         "assets":[{"name":"\(asset)","browser_download_url":"https://github.com/hamdalaa/kraft/releases/download/\(tag)/\(asset)"}]}
        """.utf8)
    }

    @Test func decodesTheLatestRelease() throws {
        let r = try #require(try AppRelease.decode(Self.json(tag: "v1.2.0")))
        #expect(r.version == AppVersion("1.2.0")!)
        #expect(r.notes == "New icon")
        #expect(r.downloadURL?.lastPathComponent == "Kraft.zip")
    }

    @Test func skipsDraftsAndPrereleasesAndMissingAssets() throws {
        #expect(try AppRelease.decode(Self.json(tag: "v9.0.0", draft: true)) == nil)
        #expect(try AppRelease.decode(Self.json(tag: "v9.0.0", prerelease: true)) == nil)
        #expect(try AppRelease.decode(Self.json(tag: "v1.2.0", asset: "Other.zip"))?.downloadURL == nil)
    }

    @Test func newerOnlyWhenTheReleaseIsAhead() throws {
        let r = try AppRelease.decode(Self.json(tag: "v1.2.0"))
        #expect(UpdatePolicy.isNewer(r, than: AppVersion("1.1.1")))
        #expect(!UpdatePolicy.isNewer(r, than: AppVersion("1.2.0")))
        #expect(!UpdatePolicy.isNewer(r, than: AppVersion("1.3")))
        #expect(!UpdatePolicy.isNewer(nil, than: AppVersion("1.0")))
    }

    @Test func automaticChecksRunOnceADay() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        #expect(UpdatePolicy.shouldCheck(lastCheck: nil, now: now, automatic: true))
        #expect(!UpdatePolicy.shouldCheck(lastCheck: now.addingTimeInterval(-3600), now: now, automatic: true))
        #expect(UpdatePolicy.shouldCheck(lastCheck: now.addingTimeInterval(-UpdatePolicy.interval), now: now, automatic: true))
        #expect(UpdatePolicy.shouldCheck(lastCheck: now.addingTimeInterval(3600), now: now, automatic: true)) // clock moved back
        #expect(!UpdatePolicy.shouldCheck(lastCheck: nil, now: now, automatic: false))
    }
}
