import Testing
import Foundation
@testable import GunBoundFile

@Suite
struct XFSArchiveTests {

    private func loadResource(_ name: String, _ ext: String) throws -> [UInt8] {
        let url = Bundle.module.url(forResource: name, withExtension: ext, subdirectory: "Resources")!
        return try [UInt8](Data(contentsOf: url))
    }

    /// Validates the container-framing part of the format (footer -> TOC
    /// offset/size -> LZHUF-compressed blob -> `"XFS2"` magic) against a
    /// real sample archive. `0x40`, the decompressed-size value static
    /// analysis observed being used for the table of contents, decodes this
    /// real file's TOC to a buffer whose first four bytes are exactly the
    /// `"XFS2"` magic, corroborating both the footer layout and this size
    /// constant.
    @Test
    func readFooterAndTOC() throws {
        let data = try loadResource("avatar", "xfs")
        let footer = try XFSArchive.readFooter(data)
        #expect(footer.tocOffset > 0)
        #expect(footer.tocCompressedSize > 0)

        let toc = try XFSArchive.readTableOfContents(data, footer: footer, decodedTOCSize: 0x40)
        #expect(Array(toc.prefix(4)) == XFSArchive.magic)
    }

    @Test
    func invalidFooterOnTooSmallFile() {
        #expect(throws: ParsingError.self) {
            _ = try XFSArchive.readFooter([0x01, 0x02])
        }
    }

    /// Enumerates the real `avatar.xfs` sample's table of contents: 8
    /// entries (the true entry count, the second `uint32_t` after the
    /// magic — not the first one, which is a still-unidentified field
    /// that happens to read `999` on every sample archive seen so far).
    /// This decodes real named entries with plausible filenames (avatar
    /// body-part sprites) rather than noise.
    @Test
    func readEntries() throws {
        let data = try loadResource("avatar", "xfs")
        let entries = try XFSArchive.readEntries(data)
        #expect(entries.map(\.name) == ["fb.dat", "ff.dat", "fg.dat", "fh.dat", "mb.dat", "mf.dat", "mg.dat", "mh.dat"])
        for entry in entries {
            #expect(entry.isCompressed)
            #expect(entry.decompressedSize > 0)
            #expect(entry.compressedSize > 0)
        }
    }

    @Test
    func readEntryDataForFirstEntry() throws {
        let data = try loadResource("avatar", "xfs")
        let entries = try XFSArchive.readEntries(data)
        let first = try #require(entries.first)
        let decoded = try XFSArchive.readEntryData(data, entry: first)
        #expect(decoded.count == Int(first.decompressedSize))
    }
}
