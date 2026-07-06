/// Room Detail Request (`SVC_ROOM_DETAIL`)
///
/// Sent by the client to get detailed information about a specific room.
///
/// **Note:** This is a best-effort reconstruction from the opcode name alone.
public struct RoomDetailRequest: GunBoundPacket, GunBoundPacketDecodable, Equatable, Hashable, Sendable {

    public static var opcode: Opcode { .roomDetailRequest }

    public let room: RoomID

    public init(parsing input: inout ParserSpan) throws(ParsingError) {
        self.room = try RoomID(parsing: &input)
    }
}
