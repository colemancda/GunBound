import Foundation
import Testing
@testable import GunBoundFile

@Suite struct LanguageFileTests {

    /// A synthetic table shaped like the real `Language.txt`: id-keyed,
    /// tab-separated, CRLF-terminated, with `\n` line-break escapes and a
    /// deliberately malformed row that must be skipped.
    private func makeTable() -> [UInt8] {
        let text = [
            "200\tServer access error\\n\\nCan't reach it.",
            "201\tAccess time has expired.\\n\\nTry later.",
            "malformed line without a tab",
            "205\tWrong password.",
            "",  // blank line
        ].joined(separator: "\r\n")
        return Array(text.utf8)
    }

    @Test func parsesIdKeyedEntries() {
        let table = LanguageFile.read(makeTable())
        #expect(table.string(id: 200) == "Server access error\n\nCan't reach it.")
        #expect(table.string(id: 205) == "Wrong password.")
        // The `\n\n` escapes became real line breaks (title / blank / body).
        #expect(table.string(id: 201) == "Access time has expired.\n\nTry later.")
        #expect(table.string(id: 201)?.split(whereSeparator: \.isNewline).count == 2)
        // Malformed and blank lines are skipped, not fatal.
        #expect(table.strings.count == 3)
        #expect(table.string(id: 999) == nil)
    }

    @Test func leavesUnknownEscapesVerbatim() {
        // The real data has a typo'd `\O`; it should pass through unchanged.
        let table = LanguageFile.read(Array("202\tServer\\nerror\\Otypo".utf8))
        #expect(table.string(id: 202) == "Server\nerror\\Otypo")
    }

    /// The real `Language.txt` from the game archive parses and carries the
    /// known error-dialog family (skipped when the archive isn't on disk).
    @Test func parsesTheRealTable() throws {
        let url = URL(fileURLWithPath: NSString(string: "~/Developer/GunBound-Decomp/orig/graphics.xfs").expandingTildeInPath)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        let archive = try [UInt8](Data(contentsOf: url))
        let entries = try XFSArchive.readEntries(archive)
        let entry = try #require(entries.first { $0.name == "Language.txt" })
        let table = LanguageFile.read(try XFSArchive.readEntryData(archive, entry: entry))

        #expect(table.strings.count > 100)
        // id 201 = the network-timeout / "access time expired" dialog; a
        // multi-line message with the detail after a blank line.
        let expired = try #require(table.string(id: 201))
        #expect(expired.contains("\n\n"))
        #expect(table.string(id: 200) != nil)  // server-access error
        #expect(table.string(id: 205) != nil)  // bad password
    }
}
