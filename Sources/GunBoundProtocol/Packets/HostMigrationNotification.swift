/// Host Migration Notification
///
/// Broadcast to the room when the master leaves and another player takes
/// over. Carries the new master's slot and a summary of the room the
/// remaining clients re-sync against (title, map, settings, item state,
/// capacity). Receiving it also makes the client redraw its primary action
/// button — "Start Game" for the new master, "Ready" for everyone else.
public struct HostMigrationNotification: GunBoundPacket, GunBoundPacketEncodable, GunBoundPacketDecodable, Equatable, Hashable, Sendable {

    public static var opcode: Opcode { .hostMigrationNotification }

    /// Room slot of the newly elected master.
    public let masterSlot: UInt8

    /// The room's title.
    public let name: String

    /// The room's current map.
    public let map: GameMap

    /// Game settings bitmask (game mode, turn time, etc.)
    public let settings: UInt32

    /// Item availability state (0xFFFFFFFF = default/all).
    public let itemState: UInt32

    /// Reserved (0xFFFFFFFF on the wire).
    internal let value0: UInt32

    /// Maximum number of players allowed in the room.
    public let capacity: RoomCapacity

    public init(
        masterSlot: UInt8,
        name: String,
        map: GameMap,
        settings: UInt32,
        itemState: UInt32 = 0xFFFF_FFFF,
        value0: UInt32 = 0xFFFF_FFFF,
        capacity: RoomCapacity
    ) {
        self.masterSlot = masterSlot
        self.name = name
        self.map = map
        self.settings = settings
        self.itemState = itemState
        self.value0 = value0
        self.capacity = capacity
    }

    public init(parsing input: inout ParserSpan) throws {
        self.masterSlot = try UInt8(parsing: &input)
        self.name = try String(parsingLengthPrefixedASCII: &input)
        self.map = try GameMap(parsing: &input)
        self.settings = try UInt32(parsingLittleEndian: &input)
        self.itemState = try UInt32(parsingLittleEndian: &input)
        self.value0 = try UInt32(parsingLittleEndian: &input)
        self.capacity = try RoomCapacity(parsing: &input)
    }

    public func encode(to output: inout ByteWriter) {
        output.write(masterSlot)
        output.writeLengthPrefixed(ascii: name)
        map.encode(to: &output)
        output.write(settings, endianness: .little)
        output.write(itemState, endianness: .little)
        output.write(value0, endianness: .little)
        capacity.encode(to: &output)
    }
}
