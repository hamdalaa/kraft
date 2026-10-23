import AppKit
import CoreText
import KraftCore
import SwiftUI

/// Registers the bundled handwriting fonts and picks one per text direction.
enum FontRegistry {
    static let playpen = "PlaypenSansArabic-Regular"
    static let playpenMedium = "PlaypenSansArabic-Medium"
    static let molhim = "Molhim"

    @MainActor private static var registered = false

    @MainActor static func registerAll() {
        guard !registered else { return }
        registered = true
        for dir in candidateDirectories() {
            guard let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { continue }
            for url in files where url.pathExtension.lowercased() == "ttf" {
                var error: Unmanaged<CFError>?
                if !CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) {
                    // Already registered is fine; anything else is worth a log line.
                    if let err = error?.takeRetainedValue() { NSLog("Kraft: font %@: %@", url.lastPathComponent, String(describing: err)) }
                }
            }
            return
        }
        NSLog("Kraft: no Fonts directory found; handwriting falls back to the system font")
    }

    static var hasMolhim: Bool { NSFont(name: molhim, size: 12) != nil }

    /// Bundle Resources/Fonts first; `swift run` falls back to the repo's Resources folders.
    private static func candidateDirectories() -> [URL] {
        var dirs: [URL] = []
        if let res = Bundle.main.resourceURL { dirs.append(res.appendingPathComponent("Fonts")) }
        return dirs.filter { FileManager.default.fileExists(atPath: $0.path) }
    }
}

struct Hand {
    let direction: ScriptDirection
    let style: Handwriting

    init(text: String, style: Handwriting = .auto) {
        direction = ScriptDirection.detect(text)
        self.style = style
    }

    var usesMolhim: Bool {
        switch style {
        case .molhim: FontRegistry.hasMolhim
        case .playpen: false
        case .auto: direction == .rightToLeft && FontRegistry.hasMolhim
        }
    }

    /// Amounts read better in Playpen in both scripts (it covers Arabic too).
    static func amount(_ size: CGFloat) -> Font { .custom(FontRegistry.playpenMedium, fixedSize: size) }

    func font(_ size: CGFloat, medium: Bool = false) -> Font {
        if usesMolhim { return .custom(FontRegistry.molhim, fixedSize: size * 1.2) }
        return .custom(medium ? FontRegistry.playpenMedium : FontRegistry.playpen, fixedSize: size)
    }

    var layoutDirection: LayoutDirection { direction == .rightToLeft ? .rightToLeft : .leftToRight }

    /// The text set in this hand. Molhim draws 0–9 as ١٢٣, which would hide both the digit setting and the
    /// writer's own digits, so runs of Western digits are set in Playpen (same size, it covers both scripts).
    func text(_ string: String, _ size: CGFloat, medium: Bool = false) -> Text {
        let face = font(size, medium: medium)
        guard usesMolhim, string.contains(where: Self.isWesternDigit) else { return Text(verbatim: string).font(face) }
        let digits = Font.custom(medium ? FontRegistry.playpenMedium : FontRegistry.playpen, fixedSize: size)
        var pieces: [Text] = []
        var run = "", runIsDigits = false
        for ch in string {
            let isDigit = Self.isWesternDigit(ch)
            if isDigit != runIsDigits, !run.isEmpty {
                pieces.append(Text(verbatim: run).font(runIsDigits ? digits : face))
                run = ""
            }
            runIsDigits = isDigit
            run.append(ch)
        }
        if !run.isEmpty { pieces.append(Text(verbatim: run).font(runIsDigits ? digits : face)) }
        return pieces.dropFirst().reduce(pieces[0]) { Text("\($0)\($1)") }
    }

    private static func isWesternDigit(_ c: Character) -> Bool { c.isASCII && c.isNumber }
    var alignment: HorizontalAlignment { .leading }
}
