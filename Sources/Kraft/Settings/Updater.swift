import AppKit
import KraftCore
import Observation

/// Checks GitHub for a newer Kraft and installs it: download `Kraft.zip`, verify it, swap the app in place, relaunch.
/// Settings › Updates and the app menu drive it; with «Check automatically» on, launch checks once a day.
@MainActor
@Observable
final class Updater {
    static let shared = Updater()

    static let repoURL = URL(string: "https://github.com/hamdalaa/kraft")!
    static let latestURL = URL(string: "https://api.github.com/repos/hamdalaa/kraft/releases/latest")!
    static let releasesURL = URL(string: "https://github.com/hamdalaa/kraft/releases")!

    enum State: Equatable {
        case idle
        case checking
        case upToDate
        case available(AppRelease)
        case installing(AppRelease)
        case failed(String)
    }

    private enum Key {
        static let automatic = "KraftAutoCheckUpdates"
        static let lastCheck = "KraftLastUpdateCheck"
    }

    @ObservationIgnored private let defaults: UserDefaults
    var state: State = .idle
    private(set) var lastCheck: Date?

    var checksAutomatically: Bool {
        didSet { defaults.set(checksAutomatically, forKey: Key.automatic) }
    }

    /// `CFBundleShortVersionString` of the running app (from the repo's VERSION file at bundle time).
    let currentVersionText: String
    var currentVersion: AppVersion? { AppVersion(currentVersionText) }

    init(defaults: UserDefaults = .standard, bundle: Bundle = .main, state: State = .idle) {
        self.defaults = defaults
        currentVersionText = bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
        checksAutomatically = defaults.object(forKey: Key.automatic) as? Bool ?? true
        lastCheck = defaults.object(forKey: Key.lastCheck) as? Date
        self.state = state
    }

    var availableRelease: AppRelease? {
        if case .available(let release) = state { release } else { nil }
    }

    /// Launch: a quiet check when the last one is a day old. Failures stay quiet too.
    func checkAutomaticallyIfDue() {
        guard UpdatePolicy.shouldCheck(lastCheck: lastCheck, now: Date(), automatic: checksAutomatically) else { return }
        Task { await check(quiet: true) }
    }

    func check(quiet: Bool = false) async {
        guard state != .checking, !isInstalling else { return }
        let previous = state
        state = .checking
        do {
            var request = URLRequest(url: Self.latestURL, timeoutInterval: 20)
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            request.setValue("Kraft/\(currentVersionText)", forHTTPHeaderField: "User-Agent")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw UpdateError.server }
            let release = try AppRelease.decode(data)
            lastCheck = Date()
            defaults.set(lastCheck, forKey: Key.lastCheck)
            if let release, UpdatePolicy.isNewer(release, than: currentVersion) {
                state = .available(release)
            } else {
                state = .upToDate
            }
        } catch {
            NSLog("Kraft: update check failed: %@", error.localizedDescription)
            state = quiet ? previous : .failed(String(localized: "Couldn’t reach GitHub. Check your connection and try again."))
        }
    }

    private var isInstalling: Bool {
        if case .installing = state { true } else { false }
    }

    /// Downloads, verifies and swaps in the release, then quits so the helper can relaunch the new copy.
    /// Falls back to the release page when the app's folder isn't writable or the release has no zip.
    func install(_ release: AppRelease) async {
        let appURL = Bundle.main.bundleURL
        guard let zipURL = release.downloadURL,
              FileManager.default.isWritableFile(atPath: appURL.deletingLastPathComponent().path) else {
            NSWorkspace.shared.open(release.pageURL)
            return
        }
        state = .installing(release)
        do {
            let (download, response) = try await URLSession.shared.download(from: zipURL)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw UpdateError.server }
            let newApp = try await Self.unpackAndVerify(zip: download, expecting: release.version, replacing: appURL)
            try Self.swapAndRelaunch(newApp: newApp, oldApp: appURL)
            NSApp.terminate(nil)
        } catch {
            NSLog("Kraft: update install failed: %@", error.localizedDescription)
            state = .failed(String(localized: "The update couldn’t be installed. Download it from GitHub instead."))
        }
    }

    enum UpdateError: Error { case server, badArchive, wrongApp, unsigned, tool }

    /// Unzips next to nothing the user owns (a fresh temp folder), checks bundle id, version and signature,
    /// and carries over the private handwriting font the public download leaves out.
    nonisolated private static func unpackAndVerify(zip: URL, expecting version: AppVersion, replacing old: URL) async throws -> URL {
        let fm = FileManager.default
        let dir = fm.temporaryDirectory.appendingPathComponent("kraft-update-\(UUID().uuidString)")
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        try run("/usr/bin/ditto", ["-x", "-k", zip.path, dir.path])
        let app = dir.appendingPathComponent("Kraft.app")
        guard let info = Bundle(url: app)?.infoDictionary else { throw UpdateError.badArchive }
        guard info["CFBundleIdentifier"] as? String == Bundle.main.bundleIdentifier,
              let shipped = (info["CFBundleShortVersionString"] as? String).flatMap(AppVersion.init), shipped == version
        else { throw UpdateError.wrongApp }
        try run("/usr/bin/codesign", ["--verify", "--deep", "--strict", app.path], error: .unsigned)

        let font = "Contents/Resources/Fonts/Molhim.ttf"
        let oldFont = old.appendingPathComponent(font), newFont = app.appendingPathComponent(font)
        if fm.fileExists(atPath: oldFont.path), !fm.fileExists(atPath: newFont.path) {
            try fm.copyItem(at: oldFont, to: newFont)
            try run("/usr/bin/codesign", ["--force", "--deep", "--options", "runtime", "--sign", "-", app.path])
        }
        try? run("/usr/bin/xattr", ["-dr", "com.apple.quarantine", app.path])
        return app
    }

    /// A small shell helper waits for this process to exit, moves the old app aside, moves the new one in
    /// (putting the old one back if that fails), and opens it.
    private static func swapAndRelaunch(newApp: URL, oldApp: URL) throws {
        let script = """
        while kill -0 "$0" 2>/dev/null; do sleep 0.2; done
        rm -rf "$2.previous"
        if mv "$2" "$2.previous" && mv "$1" "$2"; then rm -rf "$2.previous"; else mv "$2.previous" "$2"; fi
        /usr/bin/open "$2"
        """
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c", script, String(ProcessInfo.processInfo.processIdentifier), newApp.path, oldApp.path]
        try task.run()
    }

    nonisolated private static func run(_ tool: String, _ args: [String], error: UpdateError = .tool) throws {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: tool)
        task.arguments = args
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice
        try task.run()
        task.waitUntilExit()
        guard task.terminationStatus == 0 else { throw error }
    }
}
