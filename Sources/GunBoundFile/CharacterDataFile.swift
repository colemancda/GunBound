/// `characterdata.dat`'s decoded record layout.
///
/// **Note:** Reconstructed from static analysis of the original client.
/// Unlike `ItemDataFile`/`StageDataFile`, the record **count and stride**
/// here come directly from decompiled code (`LoadGameDataFiles`'s
/// post-decode checksum-validation loop advances a pointer by a constant
/// `0x14c` bytes per iteration, `16` times — `16 * 0x14c == 0x14c0`,
/// exactly matching the confirmed total decoded size). That loop is
/// validation plumbing, not a field-by-name parser, so it doesn't reveal
/// individual field *meanings* — the few named fields below are
/// best-effort inferences from cross-record numeric patterns in the real
/// sample file (e.g. two near-constant leading fields plausible as a
/// bounding box, and two records sharing unusually large values in three
/// fields suggestive of a matched heavy/tank-type pair), not confirmed
/// against code. Treat every field name here as a hypothesis, not a fact.
///
/// Static analysis also found this file has no client-side consumer beyond
/// the checksum-validation loop above (a whole-binary search for
/// `"characterdata.dat"` turned up only the one reference, and the decoded
/// buffer is a stack-local, never copied to persistent storage) —
/// suggesting this file's role client-side is purely an anti-tamper
/// integrity check (detecting a locally-edited stats file), not a source
/// of values the client itself computes with. Real mobile stats most
/// likely live server-side, consistent with GunBound's server-authoritative
/// gameplay model. This means field *names* here can't be confirmed
/// further by tracing client execution — only by server-side code or
/// outside knowledge of GunBound's actual mobile stats.
///
/// A companion editor tool (`Asuka.exe`, from the same private-server
/// toolset) does have real Korean field labels recovered from its dialog
/// resources — max HP/shield/shield-regen, energy, search width/height
/// and body height (hitbox), firing angle range, max firing power, move
/// distance, max incline angle, base delay, and per-weapon-slot
/// power/shape/density/attribute values (each split into inner/mid/outer
/// sub-values) — but the dialog's control order isn't confirmed to match
/// the on-disk field order, so none of that maps onto `field0`-`field5`/
/// `remainingFields` below with confidence.
public enum CharacterDataFile {

    /// Every record is this many bytes, confirmed directly from the
    /// decompiled checksum loop's per-iteration pointer advance
    /// (`puStack_181d8 = puStack_181d8 + 0x53`, i.e. 0x53 `uint32`s = `0x14c`).
    public static let recordSize = 0x14c

    /// Total slot count, confirmed directly from the loop's initial
    /// counter (`0x10` = 16, decremented to 0) — matches GunBound's
    /// classic 16-mobile roster.
    public static let totalSlots = 16

    /// One parsed `characterdata.dat` record (one mobile/tank's stats).
    public struct MobileRecord: Equatable, Hashable, Sendable {

        /// `uint32` at record offset `0x00`. Near-constant (`28`) across
        /// most records in the real sample — a plausible, unconfirmed
        /// guess is a bounding-box/hitbox width.
        public let field0: UInt32

        /// `uint32` at record offset `0x04`. Near-constant (`24`) across
        /// most records — plausible bounding-box/hitbox height.
        public let field1: UInt32

        /// `uint32` at record offset `0x08`. Mostly `0`, small values
        /// (`2`-`4`) in a handful of records — possibly a team/type/
        /// category enum.
        public let field2: UInt32

        /// `uint32` at record offset `0x0c`. Plausible small-integer
        /// game-balance stat (observed range roughly 10-170 across the
        /// real sample).
        public let field3: UInt32

        /// `uint32` at record offset `0x10`. Same character as `field3`.
        public let field4: UInt32

        /// `uint32` at record offset `0x14`. Same character as `field3`.
        public let field5: UInt32

        /// Every other `uint32` field in the record (raw, unmapped),
        /// starting at record offset `0x18`.
        public let remainingFields: [UInt32]
    }

    /// Parses every fixed-size record from a decompressed
    /// `characterdata.dat` buffer (see `DatFile.decompress(_:decodedSize:)`
    /// with `DatFile.characterDataDecodedSize`).
    public static func readRecords(_ decodedData: [UInt8]) throws -> [MobileRecord] {
        var records = [MobileRecord]()
        var offset = 0
        while offset + recordSize <= decodedData.count {
            let record = Array(decodedData[offset..<(offset + recordSize)])
            records.append(try parseRecord(record))
            offset += recordSize
        }
        return records
    }

    static func parseRecord(_ record: [UInt8]) throws -> MobileRecord {
        precondition(record.count == recordSize)
        return try record.withParserSpan { input in
            let field0 = try UInt32(parsingLittleEndian: &input)
            let field1 = try UInt32(parsingLittleEndian: &input)
            let field2 = try UInt32(parsingLittleEndian: &input)
            let field3 = try UInt32(parsingLittleEndian: &input)
            let field4 = try UInt32(parsingLittleEndian: &input)
            let field5 = try UInt32(parsingLittleEndian: &input)
            var remaining = [UInt32]()
            remaining.reserveCapacity((recordSize - 0x18) / 4)
            while input.count >= 4 {
                remaining.append(try UInt32(parsingLittleEndian: &input))
            }
            return MobileRecord(
                field0: field0,
                field1: field1,
                field2: field2,
                field3: field3,
                field4: field4,
                field5: field5,
                remainingFields: remaining
            )
        }
    }
}
