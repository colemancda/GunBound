/// Avatar Inventory Response
///
/// The owned/purchased item inventory list shown in the Avatar Store — each
/// item has an expiration date (many avatar/cosmetic items are time-limited
/// rentals rather than permanent purchases). Sent in response to
/// `GetAvatarRequest` (`0x6000`), one packet per owned item.
///
/// **Note:** Reconstructed from static analysis of the original client, not a live packet capture or verified traffic.
public struct AvatarInventoryResponse: GunBoundPacket, GunBoundPacketEncodable, GunBoundPacketDecodable, Equatable, Hashable, Sendable {

    public static var opcode: Opcode { .avatarInventoryResponse }

    public let id0: UInt32

    public let id1: UInt32

    public let id2: UInt32

    public let id3: UInt32

    /// Unix timestamp (seconds since epoch) the item expires.
    public let expirationDate: UInt32

    /// Trailing item data of unconfirmed shape.
    public let extra: [UInt8]

    public init(
        id0: UInt32,
        id1: UInt32,
        id2: UInt32,
        id3: UInt32,
        expirationDate: UInt32,
        extra: [UInt8] = []
    ) {
        self.id0 = id0
        self.id1 = id1
        self.id2 = id2
        self.id3 = id3
        self.expirationDate = expirationDate
        self.extra = extra
    }

    public init(parsing input: inout ParserSpan) throws(ParsingError) {
        self.id0 = try UInt32(parsingLittleEndian: &input)
        self.id1 = try UInt32(parsingLittleEndian: &input)
        self.id2 = try UInt32(parsingLittleEndian: &input)
        self.id3 = try UInt32(parsingLittleEndian: &input)
        self.expirationDate = try UInt32(parsingLittleEndian: &input)
        self.extra = [UInt8](parsingRemainingBytes: &input)
    }

    public func encode(to output: inout ByteWriter) {
        output.write(id0, endianness: .little)
        output.write(id1, endianness: .little)
        output.write(id2, endianness: .little)
        output.write(id3, endianness: .little)
        output.write(expirationDate, endianness: .little)
        output.write(extra)
    }
}
