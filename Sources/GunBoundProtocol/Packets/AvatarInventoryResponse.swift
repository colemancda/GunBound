/// Avatar Inventory Response (`InventoryItem`, opcode `0x6002`)
///
/// The owned/purchased item inventory list shown in the Avatar Store — each
/// item has an expiration date (many avatar/cosmetic items are time-limited
/// rentals rather than permanent purchases). Sent in response to
/// `GetAvatarRequest` (`0x6000`), one packet per owned item.
///
/// **Note:** Reconstructed from static analysis of the original client's
/// `0x6002` handler, not a live packet capture or verified traffic. Field
/// sizes/order/the length-prefix mechanism are confirmed; individual id
/// fields' semantics (item ID vs. price, etc.) and `itemData`'s internal
/// contents are not.
public struct AvatarInventoryResponse: GunBoundPacket, GunBoundPacketEncodable, GunBoundPacketDecodable, Equatable, Hashable, Sendable {

    public static var opcode: Opcode { .avatarInventoryResponse }

    public let id0: UInt32

    public let id1: UInt32

    public let id2: UInt32

    public let id3: UInt32

    /// Unix timestamp (seconds since epoch) the item expires, parsed
    /// client-side into separate year/month/day fields via `_localtime`
    /// (not stored raw) — represented here as the raw wire value.
    public let expirationDate: UInt32

    /// A 5th id field, distinct from `id0`-`id3`; fed to the same
    /// outgoing-packet-checksum accumulator as `id0`, suggesting the two
    /// form some kind of transaction/verification pair.
    public let id4: UInt32

    /// Variable-length trailing item data (item name string? serialized
    /// equip-slot/color data? not decoded), length-prefixed by a single
    /// byte on the wire.
    public let itemData: [UInt8]

    public init(
        id0: UInt32,
        id1: UInt32,
        id2: UInt32,
        id3: UInt32,
        expirationDate: UInt32,
        id4: UInt32,
        itemData: [UInt8] = []
    ) {
        self.id0 = id0
        self.id1 = id1
        self.id2 = id2
        self.id3 = id3
        self.expirationDate = expirationDate
        self.id4 = id4
        self.itemData = itemData
    }

    public init(parsing input: inout ParserSpan) throws {
        self.id0 = try UInt32(parsingLittleEndian: &input)
        self.id1 = try UInt32(parsingLittleEndian: &input)
        self.id2 = try UInt32(parsingLittleEndian: &input)
        self.id3 = try UInt32(parsingLittleEndian: &input)
        self.expirationDate = try UInt32(parsingLittleEndian: &input)
        self.id4 = try UInt32(parsingLittleEndian: &input)
        let length = try Int(UInt8(parsing: &input))
        self.itemData = try [UInt8](parsing: &input, byteCount: length)
    }

    public func encode(to output: inout ByteWriter) {
        output.write(id0, endianness: .little)
        output.write(id1, endianness: .little)
        output.write(id2, endianness: .little)
        output.write(id3, endianness: .little)
        output.write(expirationDate, endianness: .little)
        output.write(id4, endianness: .little)
        output.write(UInt8(itemData.count))
        output.write(itemData)
    }
}
