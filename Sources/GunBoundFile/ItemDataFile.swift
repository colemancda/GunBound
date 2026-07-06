/// `itemdata.dat`'s decoded record layout.
///
/// **Note:** Reconstructed from static analysis of the original client —
/// specifically, from pattern-matching the real decompressed file's bytes
/// (a scan for printable-string offsets confirming a consistent stride),
/// not from tracing `LoadGameDataFiles`'s consumer loop field-by-field.
/// The `flags` field's individual bit/byte meanings and the exact
/// description-offset rule are **not** confirmed for every record — treat
/// `descriptionText` as best-effort.
public enum ItemDataFile {

    /// Every record is this many bytes; static analysis confirmed this via
    /// a full-file scan for printable-string offsets landing on a
    /// consistent stride (an earlier, smaller sample had suggested `0x130`,
    /// which turned out to be wrong).
    public static let recordSize = 0x134

    /// One parsed `itemdata.dat` record.
    public struct ItemRecord: Equatable, Hashable, Sendable {

        /// Item name (NUL-terminated ASCII/text within a 0x24-byte budget
        /// at the start of the record). A handful of items in some client
        /// builds contain untranslated Korean text, which reads as mojibake
        /// under a Latin-1/ASCII decode.
        public let name: String

        /// Price/value at record offset `0x24`. A value of `0` was
        /// observed for some entries, suggesting not every item is
        /// purchasable (possibly quest/event-only items).
        public let price: UInt32

        /// Item type/index ID at record offset `0x28` (also duplicated as
        /// a single byte at `0x30`, kept here as `itemTypeIDByte`).
        /// Observed shared across item "families" (e.g. "Energy up 1" and
        /// "Energy up 2" shared the same value), so this is likely a
        /// category ID, not a unique per-item ID.
        public let itemTypeID: UInt32

        /// Unidentified 4-byte field at record offset `0x2c`. Varies per
        /// record; a `0x2e` byte of `1` seemed to correlate with the
        /// presence of a description, but this wasn't rigorously confirmed.
        public let flags: [UInt8]

        /// Duplicate of `itemTypeID`'s low byte, at record offset `0x30`.
        public let itemTypeIDByte: UInt8

        /// Marker byte at record offset `0x31`: `0xff` when a description
        /// follows, `0x00` observed on records without one. The exact
        /// offset a description starts at isn't perfectly fixed across
        /// every record, so `descriptionText` is best-effort.
        public let descriptionMarker: UInt8

        /// Raw trailing bytes from record offset `0x32` through the end of
        /// the record. May contain a NUL-terminated localized description
        /// when `descriptionMarker == 0xff` — see `descriptionText`.
        public let trailingData: [UInt8]

        /// Best-effort NUL-terminated decode of `trailingData` as the
        /// item's localized description, when `descriptionMarker` suggests
        /// one is present. `nil` otherwise.
        public var descriptionText: String? {
            guard descriptionMarker == 0xff else { return nil }
            let bytes = trailingData
            let end = bytes.firstIndex(of: 0) ?? bytes.count
            return String(decoding: bytes[..<end], as: UTF8.self)
        }
    }

    /// Parses every fixed-size record from a decompressed `itemdata.dat`
    /// buffer (see `DatFile.decompress(_:decodedSize:)`). Unused/empty
    /// slots decode to a record with an empty `name`.
    public static func readRecords(_ decodedData: [UInt8]) throws -> [ItemRecord] {
        var records = [ItemRecord]()
        var offset = 0
        while offset + recordSize <= decodedData.count {
            let record = Array(decodedData[offset..<(offset + recordSize)])
            records.append(try parseRecord(record))
            offset += recordSize
        }
        return records
    }

    static func parseRecord(_ record: [UInt8]) throws -> ItemRecord {
        precondition(record.count == recordSize)
        return try record.withParserSpan { input in
            var nameSpan = try input.sliceSpan(byteCount: 0x24)
            let nameBytes = [UInt8](parsingRemainingBytes: &nameSpan)
            let nameEnd = nameBytes.firstIndex(of: 0) ?? nameBytes.count
            let name = String(decoding: nameBytes[..<nameEnd], as: UTF8.self)

            let price = try UInt32(parsingLittleEndian: &input)
            let itemTypeID = try UInt32(parsingLittleEndian: &input)
            let flags = try [UInt8](parsing: &input, byteCount: 4)
            let itemTypeIDByte = try UInt8(parsing: &input)
            let descriptionMarker = try UInt8(parsing: &input)
            let trailingData = [UInt8](parsingRemainingBytes: &input)

            return ItemRecord(
                name: name,
                price: price,
                itemTypeID: itemTypeID,
                flags: flags,
                itemTypeIDByte: itemTypeIDByte,
                descriptionMarker: descriptionMarker,
                trailingData: trailingData
            )
        }
    }
}
