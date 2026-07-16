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
        #expect(dual.descriptionText.hasPrefix("Usando este item"))

        let teleport = records[1]
        #expect(teleport.name == "Teleport")
        #expect(teleport.price == 100)

        // Corrected from an earlier pass: "Blood" does have a real
        // description under the confirmed field layout (a previous,
        // byte-pattern-only model had a "marker byte" heuristic that
        // incorrectly reported no description for this item).
        let blood = records[4]
        #expect(blood.name == "Blood")
        #expect(blood.price == 0)
        #expect(blood.descriptionText.hasPrefix("Sacrificando 8%"))

        // Slots beyond the 13 populated entries are zero-filled/unused.
        let unused = try #require(records.last)
        #expect(unused.name.isEmpty)
        #expect(unused.price == 0)
        #expect(unused.descriptionText.isEmpty)

        // The shelf-icon code (`field0x30`) decodes to a sheet + frame pair:
        // Dual `0xff01` → sheet 1, enabled frame 0; Bunge shot `0x0001` →
        // sheet 0, frame 0; Teleport `0xff0a` → sheet 1, frame 18 (decomp
        // `fc6a7cb`).
        #expect(dual.field0x30 == 0xff01)
        #expect(dual.shelfIcon == ItemDataFile.ShelfIcon(sheetIndex: 1, enabledFrame: 0, disabledFrame: 1))
        #expect(records[11].name == "Bunge shot")
        #expect(records[11].shelfIcon == ItemDataFile.ShelfIcon(sheetIndex: 0, enabledFrame: 0, disabledFrame: 1))
        #expect(teleport.shelfIcon == ItemDataFile.ShelfIcon(sheetIndex: 1, enabledFrame: 18, disabledFrame: 19))
        #expect(blood.shelfIcon == ItemDataFile.ShelfIcon(sheetIndex: 0, enabledFrame: 4, disabledFrame: 5))
    }
}
