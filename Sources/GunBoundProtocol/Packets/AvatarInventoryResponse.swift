/// Avatar Inventory Response (`InventoryItem`, opcode `0x6002`)
///
/// The owned/purchased item inventory list shown in the Avatar Store — each
/// item has an expiration date (many avatar/cosmetic items are time-limited
/// rentals rather than permanent purchases). Sent in response to
/// `GetAvatarRequest` (`0x6000`), one packet per owned item.
///
/// **Decoded** (decomp `ab39248`, from `RenderInventoryItemDetail`
/// `0x44b900`): a 25-byte (`0x19`) fixed head then a length-prefixed
/// description blob. Wire layout —
/// `id` (`u32`), **`name` (`char[12]` inline ASCII)**, `expirationDate`
/// (`u32` `time_t`), `field` (`u32`, still unnamed), `descriptionLength`
/// (`u8`), `description` (`u8[length]` ASCII). So the item **name ships
/// inline** — the detail panel draws name + expiration + wrapped
/// description + the `%05d.img` icon straight from the packet, with no
/// separate id→name table needed. (An earlier pass mis-read the 12 name
/// bytes as three `u32` id fields and the description as an opaque blob.)
public struct AvatarInventoryResponse: GunBoundPacket, GunBoundPacketEncodable, GunBoundPacketDecodable, Equatable, Hashable, Sendable {

    public static var opcode: Opcode { .avatarInventoryResponse }

    /// The item ID (drives the `%05d.img` icon), tracked as a running
    /// min/max by the handler.
    public let id: UInt32

    /// The item's display name — 12-byte inline ASCII (`+0x04`).
    public let name: String

    /// Unix timestamp (seconds since epoch) the item expires, parsed
    /// client-side into separate year/month/day fields via `_localtime`
    /// (not stored raw) — represented here as the raw wire value.
    public let expirationDate: UInt32

    /// A 4-byte field at `+0x14`, fed to the same outgoing-packet-checksum
    /// accumulator as `id` (suggesting the two form a transaction/
    /// verification pair); its meaning is still unconfirmed.
    public let field: UInt32

    /// The item's description text — the length-prefixed blob, drawn
    /// word-wrapped in the detail panel.
    public let description: String

    /// The name field's fixed on-wire width.
    static let nameFieldLength = 12

    public init(
        id: UInt32,
        name: String,
        expirationDate: UInt32,
        field: UInt32,
        description: String = ""
    ) {
        self.id = id
        self.name = name
        self.expirationDate = expirationDate
        self.field = field
        self.description = description
    }

    public init(parsing input: inout ParserSpan) throws {
        self.id = try UInt32(parsingLittleEndian: &input)
        self.name = try String(parsingFixedLengthASCII: &input, length: Self.nameFieldLength)
        self.expirationDate = try UInt32(parsingLittleEndian: &input)
        self.field = try UInt32(parsingLittleEndian: &input)
        let length = try Int(UInt8(parsing: &input))
        let bytes = try [UInt8](parsing: &input, byteCount: length)
        self.description = String(decoding: bytes, as: UTF8.self)
    }

    public func encode(to output: inout ByteWriter) {
        output.write(id, endianness: .little)
        output.write(ascii: name, fixedLength: Self.nameFieldLength)
        output.write(expirationDate, endianness: .little)
        output.write(field, endianness: .little)
        let descriptionBytes = Array(description.utf8)
        output.write(UInt8(descriptionBytes.count))
        output.write(descriptionBytes)
    }
}
