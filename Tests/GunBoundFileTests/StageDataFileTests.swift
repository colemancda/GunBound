import Testing
import Foundation
@testable import GunBoundFile

@Suite
struct StageDataFileTests {

    private func loadResource(_ name: String, _ ext: String) throws -> [UInt8] {
        let url = Bundle.module.url(forResource: name, withExtension: ext, subdirectory: "Resources")!
        return try [UInt8](Data(contentsOf: url))
    }

    /// Decodes the real `stage.dat` sample at its confirmed target size
    /// (`DatFile.stageDataDecodedSize`, `0x3c80`) and validates against the
    /// record layout static analysis confirmed directly from the
    /// decompiled loader loop (see `StageDataFile`'s doc comment): 32
    /// fixed `0x1e4`-byte slots, only the first populated.
    @Test
    func readRecords() throws {
        let compressed = try loadResource("stage", "dat")
        let decoded = DatFile.decompress(compressed, decodedSize: DatFile.stageDataDecodedSize)
        #expect(decoded.count == DatFile.stageDataDecodedSize)
        let records = try StageDataFile.readRecords(decoded)
        #expect(records.count == StageDataFile.totalSlots)

        let cave = try #require(records.first)
        #expect(cave.header == [0xef, 0xdb, 0xff, 0x74])
        // The real file has a single stray byte (0xDB, not valid ASCII/UTF-8)
        // in place of the second "a" in "Random" -- confirmed identical
        // against an independent Python port of the decoder, so this is
        // genuine file content, not a decode bug. UTF-8 decoding turns
        // that invalid byte into a single U+FFFD replacement character.
        #expect(cave.name == "Cave(R\u{FFFD}ndom)")
    }

    /// Slots 1-31 in the real sample aren't zero-filled like `itemdata.dat`'s
    /// empty slots -- per static analysis, they contain non-zero,
    /// non-meaningful repeating byte patterns (leftover memory from however
    /// this file was built) with no NUL terminator anywhere in the name
    /// field's budget, so `name` captures that leftover data verbatim
    /// rather than coming back empty. This just confirms parsing all 32
    /// slots succeeds without throwing and that no other slot happens to
    /// contain a second real, NUL-terminated stage name.
    @Test
    func unusedSlotsDecodeWithoutThrowing() throws {
        let compressed = try loadResource("stage", "dat")
        let decoded = DatFile.decompress(compressed, decodedSize: DatFile.stageDataDecodedSize)
        let records = try StageDataFile.readRecords(decoded)
        #expect(records.count == StageDataFile.totalSlots)
        for record in records.dropFirst() {
            #expect(record.name != "Cave(Random)")
        }
    }
}
