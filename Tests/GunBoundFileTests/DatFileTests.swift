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
    /// earlier pass had incorrectly assumed all four shared
    /// `characterdata.dat`'s `0x14c0`, which only decoded a truncated
    /// prefix for `itemdata.dat`/`stage.dat`. Decompiling
    /// `LoadGameDataFiles` directly corrected this for three of the four
    /// files (see `DatFile`'s doc comment). Decompressing each real sample
    /// at its correct size produces the exact byte count expected, not
    /// just "some" output.
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

    /// `specialdata.dat`'s correct target size is **not confirmed** — its
    /// loader wasn't located in static analysis, and an earlier pass's
    /// `0x14c0` guess (`characterdata.dat`'s size) was explicitly flagged
    /// as untrustworthy. This only smoke-tests that the LZHUF decoder
    /// doesn't crash on this file at that unconfirmed size; it does not
    /// assert the output is actually correct.
    @Test
    func decompressSpecialDataDoesNotCrash() throws {
        let compressed = try loadResource("specialdata", "dat")
        let decoded = DatFile.decompress(compressed, decodedSize: DatFile.characterDataDecodedSize)
        #expect(decoded.count == DatFile.characterDataDecodedSize)
    }
}
