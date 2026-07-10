/// The localized UI-string table — the port of the original's `Language.txt`
/// (an entry *inside* `graphics.xfs`, not a standalone file). The decomp's
/// `LoadLocalizedStrings` (`0x43da00`) parses it into `g_localizedStringTable`,
/// which `GetLocalizedString` then serves every dialog/message string from;
/// see GunBound-Decomp's ARCHITECTURE.md "Text localization".
///
/// Every visible string is **data keyed by a numeric id**, so the runtime
/// language is just whichever `Language.txt` the archive ships — the code
/// stays locale-agnostic. The reference `graphics.xfs` carries a Portuguese
/// table; the error-dialog family lives at ids 200+ (200 server-access,
/// 201 access-time-expired, 205 bad-password, …).
///
/// Format, confirmed against the real archive: plain text, one entry per
/// line as `<id>\t<message>`, lines terminated by CRLF. A literal `\n` in a
/// message is a line break (so a multi-line error — a title sentence, a
/// blank line, then detail — is a single entry) and `\t` a tab. Lines
/// without a tab or with a non-numeric id are skipped rather than failing
/// the whole table (the shipped data has a few malformed rows).
public struct LanguageFile: Equatable, Sendable {

    /// Message text keyed by string id (escape sequences already resolved).
    public let strings: [Int: String]

    public init(strings: [Int: String]) {
        self.strings = strings
    }

    /// The localized message for `id`, or `nil` when the table has none.
    public func string(id: Int) -> String? {
        strings[id]
    }

    /// Parses a decompressed `Language.txt` payload. Never throws — a
    /// malformed line is skipped, matching the original's lenient
    /// line-by-line load.
    public static func read(_ data: [UInt8]) -> LanguageFile {
        var strings: [Int: String] = [:]
        // Decode as UTF-8 (invalid bytes become U+FFFD rather than failing);
        // the real lines are ASCII plus the odd Latin accent.
        let text = String(decoding: data, as: UTF8.self)
        for line in text.split(whereSeparator: \.isNewline) {
            guard let tab = line.firstIndex(of: "\t") else { continue }
            guard let id = Int(line[..<tab]) else { continue }
            strings[id] = unescape(line[line.index(after: tab)...])
        }
        return LanguageFile(strings: strings)
    }

    /// Turns the file's `\n`/`\t` escapes into real characters; any other
    /// backslash sequence (e.g. the data's occasional typo'd `\O`) is kept
    /// verbatim.
    private static func unescape(_ text: Substring) -> String {
        guard text.contains("\\") else { return String(text) }
        var out = ""
        out.reserveCapacity(text.count)
        var iterator = text.makeIterator()
        while let character = iterator.next() {
            guard character == "\\", let next = iterator.next() else {
                out.append(character)
                continue
            }
            switch next {
            case "n": out.append("\n")
            case "t": out.append("\t")
            default:
                out.append("\\")
                out.append(next)
            }
        }
        return out
    }
}
