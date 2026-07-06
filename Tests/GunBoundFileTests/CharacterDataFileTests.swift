import Testing
import Foundation
@testable import GunBoundFile

@Suite
struct CharacterDataFileTests {

    private func loadResource(_ name: String, _ ext: String) throws -> [UInt8] {
        let url = Bundle.module.url(forResource: name, withExtension: ext, subdirectory: "Resources")!
        return try [UInt8](Data(contentsOf: url))
    }

    /// Decodes the real `characterdata.dat` sample and validates against
    /// the exact values static analysis documented (see
    /// `CharacterDataFile`'s doc comment): 16 fixed 332-byte mobile
    /// records, with `field0`/`field1` near-constant (`28`/`24`) except
    /// one outlier record, and two records (indices 2 and 15) sharing
    /// unusually large stat-like values -- strong corroborating evidence
    /// the record count/stride are correct, independent of the
    /// still-unconfirmed field *names*.
    @Test
    func readRecords() throws {
        let compressed = try loadResource("characterdata", "dat")
        let decoded = DatFile.decompress(compressed, decodedSize: DatFile.characterDataDecodedSize)
        #expect(decoded.count == DatFile.characterDataDecodedSize)
        let records = try CharacterDataFile.readRecords(decoded)
        #expect(records.count == CharacterDataFile.totalSlots)

        // field0/field1 are near-constant (28/24) across all but one record.
        let standardBoxRecords = records.filter { $0.field0 == 28 && $0.field1 == 24 }
        #expect(standardBoxRecords.count == 15)

        // Record index 13 is the one outlier.
        #expect(records[13].field0 == 26)
        #expect(records[13].field1 == 26)

        // Records 2 and 15 share unusually large stat-like values,
        // suggestive of a matched heavy/tank-type pair.
        #expect(records[2].field3 == 170)
        #expect(records[2].field4 == 130)
        #expect(records[2].field5 == 165)
        #expect(records[15].field3 == 170)
        #expect(records[15].field4 == 130)
        #expect(records[15].field5 == 170)

        // Every record's remaining raw fields fill out the confirmed stride exactly.
        for record in records {
            #expect(record.remainingFields.count == (CharacterDataFile.recordSize - 0x18) / 4)
        }
    }
}
