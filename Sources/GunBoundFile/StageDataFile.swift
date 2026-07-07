/// `stage.dat`'s decoded record layout.
///
/// **Note:** Reconstructed from static analysis of the original client's
/// `LoadGameDataFiles` loader loop directly (not just pattern-matching
/// decoded bytes, unlike the initial `itemdata.dat` pass) — the record
/// stride and slot count are confirmed straight from the loop's pointer
/// arithmetic (`pcVar10 += 0x1e4`) and initial counter (`0x20` = 32). Only
/// the stage name field within each record is confirmed at the field
/// level; the loader also reads several 4-byte fields at offsets
/// `+0x80`/`+0x82`/`+0x84`/`+0x88`...`+0xa0` and an 8-element sub-array
/// starting at `+0xc4`, none of which were mapped field-by-field, so this
/// type only exposes the confirmed header/name split plus the remaining
/// bytes as an opaque blob.
///
public enum StageDataFile {

    /// Every record is this many bytes, confirmed directly from the
    /// decompiled loader's pointer-advance (`pcVar10 = pcVar10 + 0x1e4`).
    public static let recordSize = 0x1e4

    /// Total slot count, confirmed directly from the loader's initial loop
    /// counter (`0x20` = 32, decremented to 0). `32 * 0x1e4 == 0x3c80`,
    /// matching `DatFile.stageDataDecodedSize` exactly.
    public static let totalSlots = 32

    /// One parsed `stage.dat` record.
    public struct StageRecord: Equatable, Hashable, Sendable {

        /// Leading 4 bytes of unconfirmed purpose (possibly a stage ID or
        /// checksum fragment) preceding the name field.
        public let header: [UInt8]

        /// Stage name, NUL-terminated ASCII/text (e.g. `"Cave(Random)"`).
        /// Empty for unused slots.
        public let name: String

        /// Remaining, unmapped bytes of the record (fields the loader
        /// reads at offsets `+0x80` onward, relative to the record start).
        /// For unused slots, this was observed as non-zero but
        /// non-meaningful repeating byte patterns (leftover/uninitialized
        /// memory from whatever built this particular file), not real
        /// stage data.
        public let trailingData: [UInt8]
    }

    /// Byte budget for the header + name fields before the loader's other
    /// confirmed fields begin at relative offset `0x80`.
    private static let nameFieldEnd = 0x80

    /// Parses every fixed-size record from a decompressed `stage.dat`
    /// buffer (see `DatFile.decompress(_:decodedSize:)` with
    /// `DatFile.stageDataDecodedSize`).
    public static func readRecords(_ decodedData: [UInt8]) throws -> [StageRecord] {
        var records = [StageRecord]()
        var offset = 0
        while offset + recordSize <= decodedData.count {
            let record = Array(decodedData[offset..<(offset + recordSize)])
            records.append(try parseRecord(record))
            offset += recordSize
        }
        return records
    }

    static func parseRecord(_ record: [UInt8]) throws -> StageRecord {
        precondition(record.count == recordSize)
        return try record.withParserSpan { input in
            let header = try [UInt8](parsing: &input, byteCount: 4)
            var nameSpan = try input.sliceSpan(byteCount: nameFieldEnd - 4)
            let nameBytes = [UInt8](parsingRemainingBytes: &nameSpan)
            let nameEnd = nameBytes.firstIndex(of: 0) ?? nameBytes.count
            let name = String(decoding: nameBytes[..<nameEnd], as: UTF8.self)
            let trailingData = [UInt8](parsingRemainingBytes: &input)
            return StageRecord(header: header, name: name, trailingData: trailingData)
        }
    }
}
