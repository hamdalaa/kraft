import Foundation
import Testing

/// Checks `Resources/Localization/{en,ar}.lproj/Localizable.strings` against each other and against the UI sources.
///
/// Rule for the UI code: every user-facing literal is a key. Literals passed to SwiftUI's localizing
/// initialisers (`Text("…")`, `Button("…")`, `.help("…")`, `EditorLabel("…")`…), to `String(localized:)`,
/// returned from `case .x: "…"` mappings, or in a ternary inside one of those calls are collected, with each
/// `\(…)` read as `%@` — so interpolate Strings only (numbers go through `KraftFormat` first).
/// A literal handed to the kit's plain-`String` APIs (`GlossyTag(text: "…")`) is never localized: that fails too.
/// Opt a line out with `// not localized` (language names shown in their own script).
@Suite struct LocalizationStringsTests {
    static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    static let languages = ["en", "ar"]
    /// Counted phrases (`Plural.string`) need every CLDR category in both files.
    static let pluralFamilies = ["count.stickies", "count.items"]
    static let pluralCategories = ["zero", "one", "two", "few", "many", "other"]

    static func table(_ language: String) throws -> [String: String] {
        let url = root.appendingPathComponent("Resources/Localization/\(language).lproj/Localizable.strings")
        let data = try Data(contentsOf: url)
        let plist = try PropertyListSerialization.propertyList(from: data, format: nil)
        return try #require(plist as? [String: String], "\(language): not a strings table")
    }

    static func rawKeys(_ language: String) throws -> [String] {
        let url = root.appendingPathComponent("Resources/Localization/\(language).lproj/Localizable.strings")
        let text = try String(contentsOf: url, encoding: .utf8)
        let regex = try NSRegularExpression(pattern: #"^\s*"((?:[^"\\]|\\.)*)"\s*="#, options: .anchorsMatchLines)
        return regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap {
            Range($0.range(at: 1), in: text).map { String(text[$0]) }
        }
    }

    /// `%@`, `%lld`, `%1$@` → their types, sorted, positions dropped.
    static func specifiers(_ s: String) -> [String] {
        let regex = try! NSRegularExpression(pattern: #"%(?:\d+\$)?(@|lld|ld|d|lf|f|%)"#)
        return regex.matches(in: s, range: NSRange(s.startIndex..., in: s)).compactMap {
            Range($0.range(at: 1), in: s).map { String(s[$0]) }
        }.filter { $0 != "%" }.sorted()
    }

    @Test func bothFilesParseAndHaveNoDuplicateKeys() throws {
        for language in Self.languages {
            _ = try Self.table(language)
            let keys = try Self.rawKeys(language)
            let duplicates = Dictionary(grouping: keys, by: { $0 }).filter { $0.value.count > 1 }.keys.sorted()
            #expect(duplicates.isEmpty, "\(language) has duplicate keys: \(duplicates)")
        }
    }

    @Test func englishAndArabicHaveTheSameKeys() throws {
        let en = Set(try Self.table("en").keys), ar = Set(try Self.table("ar").keys)
        #expect(en.subtracting(ar).sorted() == [], "missing in ar")
        #expect(ar.subtracting(en).sorted() == [], "missing in en")
    }

    @Test func formatSpecifiersMatchAcrossKeyAndTranslations() throws {
        let tables = try Self.languages.map { try Self.table($0) }
        for key in tables[0].keys.sorted() {
            // Plural values hold at most the number («ملصقان» needs none); their keys hold nothing.
            let isPlural = Self.pluralFamilies.contains { key.hasPrefix($0 + ".") }
            for (language, table) in zip(Self.languages, tables) {
                guard let value = table[key] else { continue }
                let found = Self.specifiers(value)
                let ok = isPlural ? (found == ["@"] || found.isEmpty) : found == Self.specifiers(key)
                #expect(ok, "\(language): \"\(key)\" = \"\(value)\"")
                #expect(!value.isEmpty, "\(language): empty value for \"\(key)\"")
            }
        }
    }

    @Test func arabicIsTranslated() throws {
        let en = try Self.table("en"), ar = try Self.table("ar")
        // Same text in both is fine only without letters ("⌥Space") or for names that stay Latin.
        let keepLatin: Set<String> = ["Kraft", "Playpen", "WhatsApp", "Finder"]
        let latinLetters = try NSRegularExpression(pattern: "[A-Za-z]")
        for (key, value) in ar where !keepLatin.contains(key) {
            let stripped = value.replacingOccurrences(of: #"%(?:\d+\$)?(?:@|lld|d)"#, with: "", options: .regularExpression)
                .replacingOccurrences(of: "Kraft", with: "")
            let hasLatin = latinLetters.firstMatch(in: stripped, range: NSRange(stripped.startIndex..., in: stripped)) != nil
            #expect(!hasLatin || value != en[key], "ar: \"\(key)\" is not translated")
        }
    }

    @Test func pluralFamiliesAreComplete() throws {
        for language in Self.languages {
            let table = try Self.table(language)
            for family in Self.pluralFamilies {
                for category in Self.pluralCategories {
                    #expect(table["\(family).\(category)"] != nil, "\(language): missing \(family).\(category)")
                }
            }
        }
    }

    @Test func everyLocalizedLiteralInTheUIHasAKey() throws {
        let table = try Self.table("en")
        let scan = try LiteralScanner.scan(Self.root.appendingPathComponent("Sources/Kraft"))
        let missing = scan.keys.filter { table[$0.key] == nil }.map { "\($0.place): \"\($0.key)\"" }
        #expect(missing.isEmpty, "literals without a key:\n\(missing.joined(separator: "\n"))")
        #expect(scan.plain.isEmpty, "plain String literals in kit APIs (wrap in String(localized:)):\n\(scan.plain.joined(separator: "\n"))")
        #expect(scan.keys.count > 150, "scanner found suspiciously few literals (\(scan.keys.count))")
    }

    @Test func noUnusedKeys() throws {
        let scan = try LiteralScanner.scan(Self.root.appendingPathComponent("Sources/Kraft"))
        let used = Set(scan.keys.map(\.key))
        let unused = try Self.table("en").keys.filter { key in
            !used.contains(key) && !Self.pluralFamilies.contains { key.hasPrefix($0 + ".") }
        }.sorted()
        #expect(unused.isEmpty, "keys no source uses: \(unused)")
    }
}

/// Finds the string literals in Swift sources that SwiftUI / Foundation look up as localization keys.
enum LiteralScanner {
    struct Found { let key: String; let place: String }
    struct Result { var keys: [Found] = []; var plain: [String] = [] }

    static let calls = ["Text", "Button", "Label", "Toggle", "Menu", "CommandMenu", "Window", "Section", "TextField",
                        "EditorLabel", "EditorChip", "help", "accessibilityLabel", "navigationTitle",
                        "LocalizedStringKey", "LocalizedStringResource", "action", "row", "set"]
    static let plainKit = ["GlossyTag", "EmbossedLabel", "KeyHint"]

    static func scan(_ dir: URL) throws -> Result {
        var result = Result()
        let files = FileManager.default.enumerator(at: dir, includingPropertiesForKeys: nil)?
            .compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }.sorted { $0.path < $1.path } ?? []
        for file in files {
            let source = try String(contentsOf: file, encoding: .utf8)
            for (n, line) in source.components(separatedBy: "\n").enumerated() where !line.contains("// not localized") {
                let place = "\(file.lastPathComponent):\(n + 1)"
                for literal in literals(in: line) {
                    let before = String(line[..<literal.start]).trimmingCharacters(in: .init(charactersIn: " "))
                    if isPlainKit(before) {
                        if !file.lastPathComponent.hasPrefix("Snapshot") { result.plain.append("\(place): \"\(literal.key)\"") }
                    } else if isText(literal.key), isLocalized(before: before, line: line) {
                        result.keys.append(Found(key: literal.key, place: place))
                    }
                }
            }
        }
        return result
    }

    private static func isPlainKit(_ before: String) -> Bool {
        plainKit.contains { before.range(of: "\\b\($0)\\([^)]*\\btext:$", options: .regularExpression) != nil }
    }

    /// Something a person reads: not empty, not only spaces and format specifiers.
    private static func isText(_ key: String) -> Bool {
        !key.replacingOccurrences(of: "%@", with: "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private static func endsWithCall(_ text: String) -> Bool {
        calls.contains { text.range(of: "(^|[^\\w])\($0)\\($", options: .regularExpression) != nil }
    }

    private static func isLocalized(before: String, line: String) -> Bool {
        if before.hasSuffix("verbatim:") { return false }
        if before.range(of: #"\bEditorHint\([^)]*\btext:$"#, options: .regularExpression) != nil { return true }
        if before.hasSuffix("localized:") { return true }
        if endsWithCall(before) { return true }
        if before.range(of: #"(^|\s)case [.\w, ]+:$"#, options: .regularExpression) != nil { return true }
        // A ternary branch counts when its argument is unlabelled (or `localized:`) inside a localizing call.
        guard before.hasSuffix("?") || before.hasSuffix(" :") else { return false }
        let argument = before.components(separatedBy: CharacterSet(charactersIn: "(,")).last ?? before
        if argument.contains("localized:") { return true }
        if argument.range(of: #"\w+:\s"#, options: .regularExpression) != nil { return false }
        let head = String(before.prefix(before.count - argument.count))
        return head.hasSuffix("localized:") || endsWithCall(head) || head.hasSuffix(",") && (line.contains("localized:") || calls.contains { line.contains("\($0)(") })
    }

    struct Literal { let start: String.Index; let key: String }

    /// Single-line string literals on `line` (comments skipped), with `\(…)` as `%@` and escapes resolved.
    static func literals(in line: String) -> [Literal] {
        var out: [Literal] = []
        var i = line.startIndex
        while i < line.endIndex {
            let c = line[i]
            if c == "/", line[i...].hasPrefix("//") { break }
            guard c == "\"" else { i = line.index(after: i); continue }
            if line[i...].hasPrefix("\"\"\"") { break }
            let start = i
            var key = ""
            i = line.index(after: i)
            while i < line.endIndex, line[i] != "\"" {
                if line[i] == "\\" {
                    let next = line.index(after: i)
                    guard next < line.endIndex else { break }
                    switch line[next] {
                    case "(":
                        key += "%@"
                        i = skipInterpolation(line, from: line.index(after: next))
                        continue
                    case "n": key += "\n"
                    case "t": key += "\t"
                    case "u":
                        if let close = line[next...].firstIndex(of: "}"),
                           let v = UInt32(line[line.index(next, offsetBy: 2)..<close], radix: 16), let s = Unicode.Scalar(v) {
                            key.unicodeScalars.append(s)
                            i = line.index(after: close)
                            continue
                        }
                    default: key.append(line[next])
                    }
                    i = line.index(after: next)
                } else {
                    key.append(line[i])
                    i = line.index(after: i)
                }
            }
            out.append(Literal(start: start, key: key))
            if i < line.endIndex { i = line.index(after: i) }
        }
        return out
    }

    /// Index just past the `)` closing an interpolation, skipping nested parentheses and strings.
    private static func skipInterpolation(_ line: String, from index: String.Index) -> String.Index {
        var depth = 1, i = index, inString = false
        while i < line.endIndex {
            let c = line[i]
            if inString {
                if c == "\\" { i = line.index(after: i) } else if c == "\"" { inString = false }
            } else if c == "\"" {
                inString = true
            } else if c == "(" {
                depth += 1
            } else if c == ")" {
                depth -= 1
                if depth == 0 { return line.index(after: i) }
            }
            if i < line.endIndex { i = line.index(after: i) }
        }
        return i
    }
}
