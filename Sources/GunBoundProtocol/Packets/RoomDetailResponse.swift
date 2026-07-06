/// Room Detail Response (`RoomPlayerSlot`, opcode `0x2105`)
///
/// Broadcasts one player's room-list-row data ("slot") to be displayed in
/// the room list. Static analysis of the original client's `0x2105` handler
/// confirmed this is **not one packed struct on the wire** — the per-slot
/// state is a name buffer plus several separate same-indexed fields, with a
/// count-prefixed variable-length equipped-item list following them.
///
/// **Note:** Reconstructed from static analysis of the original client, not
/// a live packet capture or verified traffic. The four trailing flag bytes'
/// individual meanings, the 4-byte `value` field's semantics, and the exact
/// sub-field layout within each 32-byte equipped-item entry are all
/// unconfirmed beyond their sizes; only the overall shape (name, 5 scalar
/// fields, count-prefixed 32-byte-stride item list) is confirmed directly
/// from the decompiled handler.
public struct RoomDetailResponse: GunBoundPacket, GunBoundPacketEncodable, GunBoundPacketDecodable, Equatable, Hashable, Sendable {

    public static var opcode: Opcode { .roomDetailResponse }

    public let name: String

    /// Ready/ID byte (mirrored to a per-slot array at client offset `+0x4497c`).
    public let readyID: UInt8

    /// 4-byte value mirrored to a per-slot array at client offset `+0x44984`;
    /// semantics not confirmed.
    public let value: UInt32

    /// Byte flag mirrored to `+0x4499c`; also doubles as `equippedItems.count`.
    public let flag1: UInt8

    /// Byte flag mirrored to `+0x449a2`.
    public let flag2: UInt8

    /// Byte flag mirrored to `+0x449a8`.
    public let flag3: UInt8

    /// Byte flag mirrored to `+0x449ae`.
    public let flag4: UInt8

    /// Equipped-item list, present only when `flag1 != 0` (`flag1` doubles
    /// as this list's count). Each entry is a confirmed 32-byte wire
    /// record; its internal sub-field layout (two short NUL-terminated
    /// string-like codes, a masked bitfield, two more values) wasn't
    /// decoded to individual field boundaries, so each entry is kept as a
    /// raw 32-byte blob here.
    public let equippedItems: [[UInt8]]

    public init(
        name: String,
        readyID: UInt8 = 0,
        value: UInt32 = 0,
        flag2: UInt8 = 0,
        flag3: UInt8 = 0,
        flag4: UInt8 = 0,
        equippedItems: [[UInt8]] = []
    ) {
        self.name = name
        self.readyID = readyID
        self.value = value
        self.flag1 = UInt8(min(equippedItems.count, Int(UInt8.max)))
        self.flag2 = flag2
        self.flag3 = flag3
        self.flag4 = flag4
        self.equippedItems = equippedItems
    }

    public init(parsing input: inout ParserSpan) throws {
        self.name = try String(parsingLengthPrefixedASCII: &input)
        self.readyID = try UInt8(parsing: &input)
        self.value = try UInt32(parsingLittleEndian: &input)
        self.flag1 = try UInt8(parsing: &input)
        self.flag2 = try UInt8(parsing: &input)
        self.flag3 = try UInt8(parsing: &input)
        self.flag4 = try UInt8(parsing: &input)
        var items = [[UInt8]]()
        items.reserveCapacity(Int(flag1))
        for _ in 0..<flag1 {
            items.append(try [UInt8](parsing: &input, byteCount: 32))
        }
        self.equippedItems = items
    }

    public func encode(to output: inout ByteWriter) {
        output.writeLengthPrefixed(ascii: name)
        output.write(readyID)
        output.write(value, endianness: .little)
        output.write(flag1)
        output.write(flag2)
        output.write(flag3)
        output.write(flag4)
        for item in equippedItems {
            output.write(item)
        }
    }
}
