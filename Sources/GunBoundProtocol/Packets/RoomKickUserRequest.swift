/// Room Kick User Request (`SVC_ROOM_KICK_USER`)
///
/// Sent by the room owner to kick a player from the room.
///
/// **Note:** No reverse-engineering evidence for this Channel 1 opcode was found
/// (Channel 2's action `0x8200` documents the corresponding real-time "kick
/// from room" notification, but not this request's wire shape); this is a
/// best-effort reconstruction from the opcode name alone.
public struct RoomKickUserRequest: GunBoundPacket, GunBoundPacketDecodable, Equatable, Hashable, Sendable {

    public static var opcode: Opcode { .roomKickUserRequest }

    /// The room-slot ID of the player to kick.
    public let playerID: UInt8

    public init(parsing input: inout ParserSpan) throws(ParsingError) {
        self.playerID = try UInt8(parsing: &input)
    }
}
