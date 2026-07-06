/// Room Specific List Request (`SVC_ROOM_SPECIFIC_LIST`)
///
/// Sent by the client to request the list of specific rooms (by ID), as
/// opposed to `RoomListRequest`'s general sorted/filtered listing.
///
/// **Note:** This is a best-effort reconstruction from the opcode name alone.
public struct RoomSpecificList: GunBoundPacket, GunBoundPacketDecodable, Equatable, Hashable, Sendable {

    public static var opcode: Opcode { .roomSpecificList }

    public let rooms: [RoomID]

    public init(rooms: [RoomID]) {
        self.rooms = rooms
    }

    public init(parsing input: inout ParserSpan) throws(ParsingError) {
        let count = try UInt8(parsing: &input)
        self.rooms = try Array(parsing: &input, count: Int(count), parser: RoomID.init(parsing:))
    }
}
