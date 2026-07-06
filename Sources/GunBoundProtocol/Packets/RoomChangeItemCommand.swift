/// Room Change Item Command
///
/// Sent by room host to change the item state in a room.
/// Only room host can send this command.
///
/// **Usage:**
/// Used when room host wants to enable/disable game items
/// or change item-related room settings.
///
/// The itemState field is a bitmask that controls which items
/// are available in the game. Different bits may represent
/// different item types or categories.
///
/// Upon successful change:
/// - Server validates the item state
/// - Server broadcasts RoomUpdateNotification to all players in room
/// - Room list in lobby is updated to reflect new settings
public struct RoomChangeItemCommand: GunBoundPacket, GunBoundPacketDecodable, GunBoundPacketEncodable, Equatable, Hashable, Sendable {

    public static var opcode: Opcode { .roomChangeUseItemCommand }

    /// Item state bitmask
    /// Controls which items are available/enabled in the room
    public var itemState: UInt16

    public init(itemState: UInt16 = 0) {
        self.itemState = itemState
    }

    public init(parsing input: inout ParserSpan) throws(ParsingError) {
        self.itemState = try UInt16(parsingLittleEndian: &input)
    }

    public func encode(to output: inout ByteWriter) {
        output.write(itemState, endianness: .little)
    }
}
