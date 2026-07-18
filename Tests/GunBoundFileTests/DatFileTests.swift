import Testing
import Foundation
@testable import GunBoundFile

@Suite
struct DatFileTests {

    private func loadResource(_ name: String, _ ext: String) throws -> [UInt8] {
        let url = Bundle.module.url(forResource: name, withExtension: ext, subdirectory: "Resources")!
        return try [UInt8](Data(contentsOf: url))
    }

    /// Each `.dat` file has its own confirmed target decompressed size — an
    /// earlier pass had incorrectly assumed all of them shared
    /// `characterdata.dat`'s `0x14c0`, which only decoded a truncated
    /// prefix for `itemdata.dat`/`stage.dat`. Decompiling
    /// `LoadGameDataFiles` directly corrected this (see `DatFile`'s doc
    /// comment). Decompressing each real sample at its correct size
    /// produces the exact byte count expected, not just "some" output.
    ///
    /// (`specialdata.dat` isn't tested here — static analysis confirmed
    /// the game client never loads it at all, so there's no client-derived
    /// size to test against.)
    @Test
    func decompressCharacterData() throws {
        let compressed = try loadResource("characterdata", "dat")
        let decoded = DatFile.decompress(compressed, decodedSize: DatFile.characterDataDecodedSize)
        #expect(decoded.count == DatFile.characterDataDecodedSize)
    }

    @Test
    func decompressItemData() throws {
        let compressed = try loadResource("itemdata", "dat")
        let decoded = DatFile.decompress(compressed, decodedSize: DatFile.itemDataDecodedSize)
        #expect(decoded.count == DatFile.itemDataDecodedSize)
    }

    @Test
    func decompressStageData() throws {
        let compressed = try loadResource("stage", "dat")
        let decoded = DatFile.decompress(compressed, decodedSize: DatFile.stageDataDecodedSize)
        #expect(decoded.count == DatFile.stageDataDecodedSize)
    }

    /// The `ParserSpan` overload consumes the compressed bytes from a span
    /// and yields the same result as the array-based path — the form callers
    /// parsing a larger container in place use.
    @Test
    func decompressFromParserSpan() throws {
        let compressed = try loadResource("characterdata", "dat")
        let decoded = try compressed.withParserSpan { span in
            DatFile.decompress(parsing: &span, decodedSize: DatFile.characterDataDecodedSize)
        }
        #expect(decoded == DatFile.decompress(compressed, decodedSize: DatFile.characterDataDecodedSize))
        #expect(decoded.count == DatFile.characterDataDecodedSize)
    }
}
