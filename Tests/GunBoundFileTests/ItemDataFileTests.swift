import Testing
import Foundation
@testable import GunBoundFile

@Suite
struct ItemDataFileTests {

    private func loadResource(_ name: String, _ ext: String) throws -> [UInt8] {
        let url = Bundle.module.url(forResource: name, withExtension: ext, subdirectory: "Resources")!
        return try [UInt8](Data(contentsOf: url))
    }

    /// Decodes the real `itemdata.dat` sample at its confirmed target size
    /// (`DatFile.itemDataDecodedSize`, `0x7850` — an earlier pass had
    /// incorrectly assumed `characterdata.dat`'s `0x14c0` applied here too,
    /// which only decoded a truncated prefix) and validates against the
    /// exact values static analysis documented (see `ItemDataFile`'s doc
    /// comment): 100 total slots, 13 populated, with real item names,
    /// prices, and localized (Portuguese, in this client build)
    /// descriptions all decoding correctly.
    @Test
    func readRecords() throws {
        let compressed = try loadResource("itemdata", "dat")
        let decoded = DatFile.decompress(compressed, decodedSize: DatFile.itemDataDecodedSize)
        #expect(decoded.count == DatFile.itemDataDecodedSize)
        let records = try ItemDataFile.readRecords(decoded)
        #expect(records.count == 100)

        let named = records.filter { !$0.name.isEmpty }
        #expect(named.count == 13)

        let dual = try #require(records.first)
        #expect(dual.name == "Dual")
        #expect(dual.price == 600)
        #expect(dual.itemTypeID == 1)
        #expect(dual.descriptionMarker == 0xff)
        #expect(dual.descriptionText?.hasPrefix("Usando este item") == true)

        let teleport = records[1]
        #expect(teleport.name == "Teleport")
        #expect(teleport.price == 100)

        // Records with no description marker report nil descriptionText.
        let blood = records[4]
        #expect(blood.name == "Blood")
        #expect(blood.price == 0)
        #expect(blood.descriptionMarker == 0)
        #expect(blood.descriptionText == nil)

        // Slots beyond the 13 populated entries are zero-filled/unused.
        let unused = try #require(records.last)
        #expect(unused.name.isEmpty)
        #expect(unused.price == 0)
    }
}
