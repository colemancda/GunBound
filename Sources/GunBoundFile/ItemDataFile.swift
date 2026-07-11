/// `itemdata.dat`'s decoded record layout.
///
/// **Note:** Reconstructed from static analysis of the original client's
/// `LoadGameDataFiles` consumer code directly (an earlier pass had only
/// pattern-matched the decoded bytes, which got the name field's exact
/// width and the flags/description-boundary breakdown slightly wrong —
/// this corrects both). The name/description/three boolean-flag fields
/// are confirmed copied into a persistent per-item structure; the
/// `field0x20`/`field0x30` fields are confirmed read and checksummed but
/// not confirmed copied anywhere under a named field, so their purpose
/// remains unconfirmed.
public enum ItemDataFile {

    /// Every record is this many bytes; confirmed via a full-file scan for
    /// printable-string offsets landing on a consistent stride.
    public static let recordSize = 0x134

    /// One parsed `itemdata.dat` record.
    public struct ItemRecord: Equatable, Hashable, Sendable {

        /// Item name (NUL-terminated ASCII/text within a confirmed 0x20-byte
        /// budget at the start of the record, copied into a persistent
        /// per-item structure). A handful of items in some client builds
        /// contain untranslated Korean text, which reads as mojibake under
        /// a Latin-1/ASCII decode.
        public let name: String

        /// `uint32` at record offset `0x20`. Read and fed through the
        /// packet-checksum accumulator, but not confirmed copied to a named
        /// persistent field — purpose unconfirmed. Often `0` in practice.
        public let field0x20: UInt32

        /// Price/value at record offset `0x24`. A value of `0` was
        /// observed for some entries, suggesting not every item is
        /// purchasable (possibly quest/event-only items).
        public let price: UInt32

        /// Item type/index ID at record offset `0x28`. Observed shared
        /// across item "families" (e.g. "Energy up 1" and "Energy up 2"
        /// shared the same value), so this is likely a category ID, not a
        /// unique per-item ID.
        public let itemTypeID: UInt32

        /// Boolean flag at record offset `0x2c`. Individually
        /// XOR/`rand()`-obfuscated when copied into persistent storage — an
        /// anti-memory-editing measure applied to exactly this and the next
        /// two flags, no other item field. The on-disk value here is the
        /// plain (pre-obfuscation) byte. Named `Shot?` (most likely: can
        /// this item be fired as a shot, vs. a passive/utility item).
        public let shotFlag: UInt8

        /// Boolean flag at record offset `0x2d`, same obfuscation-on-copy
        /// treatment as `shotFlag`, independently. Most likely: using this
        /// item skips/ends the player's turn (see `shotFlag`'s doc comment
        /// for how this was identified).
        public let skipFlag: UInt8

        /// Boolean flag at record offset `0x2e`, same obfuscation-on-copy
        /// treatment as `shotFlag`/`skipFlag`, independently. Most likely:
        /// this item occupies two inventory slots (see `shotFlag`'s doc
        /// comment for how this was identified).
        public let twoSlotsFlag: UInt8

        /// `uint16` at record offset `0x30` — the item's **packed
        /// shelf-icon code** (decomp `fc6a7cb`; GunBound-Decomp
        /// `ARCHITECTURE.md` Ready Room section / `FILEFORMATS.md`). The low
        /// byte is an icon-pair index and the high byte (`0x00`/`0xff`)
        /// selects between the two Ready Room item-shop icon sheets — see
        /// `shelfIcon`. (The same code is what the Ready Room's runtime
        /// `DAT_0056dc40` icon table stores, so `0x30` is the record's own
        /// pre-baked icon.)
        public let field0x30: UInt16

        /// Localized item description, NUL-terminated, confirmed to start
        /// at exactly record offset `0x32` and copied into persistent
        /// storage independent of the other fields. Empty for items with
        /// no description (the byte at `0x32` is `0x00` in that case).
        public let descriptionText: String

        public init(
            name: String,
            field0x20: UInt32 = 0,
            price: UInt32,
            itemTypeID: UInt32,
            shotFlag: UInt8 = 0,
            skipFlag: UInt8 = 0,
            twoSlotsFlag: UInt8 = 0,
            field0x30: UInt16 = 0,
            descriptionText: String = ""
        ) {
            self.name = name
            self.field0x20 = field0x20
            self.price = price
            self.itemTypeID = itemTypeID
            self.shotFlag = shotFlag
            self.skipFlag = skipFlag
            self.twoSlotsFlag = twoSlotsFlag
            self.field0x30 = field0x30
            self.descriptionText = descriptionText
        }

        /// The item's Ready Room shelf icon, decoded from `field0x30` — the
        /// enabled/disabled frame pair and which icon sheet they live on
        /// (decomp `fc6a7cb`). The consumer computes `frame = (code & 0xff)
        /// * 2`, blitting `frame - 2` when the item is owned/enabled and
        /// `frame - 1` when disabled; the high byte selects sheet
        /// `0x2713` (`sheetIndex 0`) or `0x2714` (`sheetIndex 1`).
        public var shelfIcon: ShelfIcon {
            ItemDataFile.shelfIcon(forCode: field0x30)
        }
    }

    /// Decodes a packed shelf-icon code (an `itemdata.dat` `0x30` field, or a
    /// `DAT_0056dc40` battle-item-ordinal entry — same encoding) into its
    /// sheet + frame pair (decomp `fc6a7cb`/`703fd5f`).
    public static func shelfIcon(forCode code: UInt16) -> ShelfIcon {
        let pair = Int(code & 0xff)
        return ShelfIcon(
            sheetIndex: (code & 0xff00) != 0 ? 1 : 0,
            enabledFrame: pair * 2 - 2,
            disabledFrame: pair * 2 - 1
        )
    }

    /// A decoded shelf-icon reference (see `ItemRecord.shelfIcon`).
    public struct ShelfIcon: Equatable, Hashable, Sendable {
        /// Which item-shop icon sheet: `0` = texture `0x2713`, `1` = `0x2714`.
        public let sheetIndex: Int
        /// Sheet frame for the owned/enabled state.
        public let enabledFrame: Int
        /// Sheet frame for the unowned/disabled (greyed) state.
        public let disabledFrame: Int

        public init(sheetIndex: Int, enabledFrame: Int, disabledFrame: Int) {
            self.sheetIndex = sheetIndex
            self.enabledFrame = enabledFrame
            self.disabledFrame = disabledFrame
        }
    }

    /// Parses every fixed-size record from a decompressed `itemdata.dat`
    /// buffer (see `DatFile.decompress(_:decodedSize:)` with
    /// `DatFile.itemDataDecodedSize`). Unused/empty slots decode to a
    /// record with an empty `name`.
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
            var nameSpan = try input.sliceSpan(byteCount: 0x20)
            let nameBytes = [UInt8](parsingRemainingBytes: &nameSpan)
            let nameEnd = nameBytes.firstIndex(of: 0) ?? nameBytes.count
            let name = String(decoding: nameBytes[..<nameEnd], as: UTF8.self)

            let field0x20 = try UInt32(parsingLittleEndian: &input)
            let price = try UInt32(parsingLittleEndian: &input)
            let itemTypeID = try UInt32(parsingLittleEndian: &input)
            let shotFlag = try UInt8(parsing: &input)
            let skipFlag = try UInt8(parsing: &input)
            let twoSlotsFlag = try UInt8(parsing: &input)
            _ = try UInt8(parsing: &input) // 0x2f: unaccounted gap, not read by the client
            let field0x30 = try UInt16(parsingLittleEndian: &input)
            let descriptionBytes = [UInt8](parsingRemainingBytes: &input)
            let descriptionEnd = descriptionBytes.firstIndex(of: 0) ?? descriptionBytes.count
            let descriptionText = String(decoding: descriptionBytes[..<descriptionEnd], as: UTF8.self)

            return ItemRecord(
                name: name,
                field0x20: field0x20,
                price: price,
                itemTypeID: itemTypeID,
                shotFlag: shotFlag,
                skipFlag: skipFlag,
                twoSlotsFlag: twoSlotsFlag,
                field0x30: field0x30,
                descriptionText: descriptionText
            )
        }
    }
}
