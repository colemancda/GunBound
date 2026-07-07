/// `avatar.xfs`'s per-gender/body-slot avatar costume catalog files
/// (`fb.dat`, `ff.dat`, `fg.dat`, `fh.dat`, `mb.dat`, `mf.dat`, `mg.dat`,
/// `mh.dat`) — stored as plain entries inside `avatar.xfs`, not
/// LZHUF-compressed on their own (read directly via
/// `XFSArchive.readEntryData(_:entry:)`).
///
/// **Note:** Reconstructed from static analysis of the original client.
/// Record field names/order/sizes are confirmed by decoding a real sample
/// (`mb.dat`) and checking the output against known-real costume names and
/// descriptions (e.g. `"Space Marine"` / `"Space marine uniform"`).
public enum AvatarInfoFile {

    /// One parsed avatar costume record.
    public struct Item: Equatable, Hashable, Sendable {

        /// The item's index within this file.
        public let index: Int32

        /// Costume name, NUL-terminated ASCII/text within a 23-byte budget.
        public let name: String

        /// Whether this item can be purchased.
        public let buyable: Bool

        /// Price in gold (the free/grindable currency).
        public let gold: Int32

        /// Price in cash (the premium currency).
        public let cash: Int32

        public let shotDelay: Int32
        public let bunge: Int32
        public let attack: Int32
        public let defense: Int32
        public let health: Int32
        public let itemDelay: Int32
        public let shield: Int32
        public let popularity: Int32

        /// Localized item description, NUL-terminated ASCII/text within a
        /// 64-byte budget.
        public let description: String
    }

    /// Byte budget for the fixed-width `name` field.
    static let nameFieldSize = 0x17

    /// Byte budget for the fixed-width `description` field.
    static let descriptionFieldSize = 0x40

    /// Parses every item record from a decoded avatar costume catalog file.
    public static func readItems(_ data: [UInt8]) throws -> [Item] {
        try data.withParserSpan { input in
            try readItems(parsing: &input)
        }
    }

    public static func readItems(parsing input: inout ParserSpan) throws -> [Item] {
        let count = try Int32(parsingLittleEndian: &input)
        var items = [Item]()
        items.reserveCapacity(Int(max(count, 0)))
        for _ in 0..<max(count, 0) {
            items.append(try readItem(parsing: &input))
        }
        return items
    }

    private static func readItem(parsing input: inout ParserSpan) throws -> Item {
        let index = try Int32(parsingLittleEndian: &input)
        let name = try readFixedLengthASCII(parsing: &input, length: nameFieldSize)
        let buyable = try UInt8(parsing: &input) != 0
        let gold = try Int32(parsingLittleEndian: &input)
        let cash = try Int32(parsingLittleEndian: &input)
        let shotDelay = try Int32(parsingLittleEndian: &input)
        let bunge = try Int32(parsingLittleEndian: &input)
        let attack = try Int32(parsingLittleEndian: &input)
        let defense = try Int32(parsingLittleEndian: &input)
        let health = try Int32(parsingLittleEndian: &input)
        let itemDelay = try Int32(parsingLittleEndian: &input)
        let shield = try Int32(parsingLittleEndian: &input)
        let popularity = try Int32(parsingLittleEndian: &input)
        let description = try readFixedLengthASCII(parsing: &input, length: descriptionFieldSize)

        return Item(
            index: index,
            name: name,
            buyable: buyable,
            gold: gold,
            cash: cash,
            shotDelay: shotDelay,
            bunge: bunge,
            attack: attack,
            defense: defense,
            health: health,
            itemDelay: itemDelay,
            shield: shield,
            popularity: popularity,
            description: description
        )
    }

    private static func readFixedLengthASCII(parsing input: inout ParserSpan, length: Int) throws -> String {
        var span = try input.sliceSpan(byteCount: length)
        let bytes = [UInt8](parsingRemainingBytes: &span)
        let end = bytes.firstIndex(of: 0) ?? bytes.count
        return String(decoding: bytes[..<end], as: UTF8.self)
    }
}
