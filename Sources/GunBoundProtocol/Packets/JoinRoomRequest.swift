/// Join Room Request
///
/// Sent by the client to join a specific game room.
/// The server validates the request and adds the player to the room.
///
/// **Usage:**
/// Used when a player double-clicks a room in the lobby room list
/// or selects a room and clicks "Join".
///
/// If the room is password-protected, the client must provide the correct password.
/// Empty password string indicates a public room.
///
/// Upon successful join:
/// - Server sends JoinRoomNotificationSelf to the joining player
/// - Server broadcasts JoinRoomNotification to all other players in the room
/// - Server sends JoinRoomNotification for each existing player in the room
public struct JoinRoomRequest: GunBoundPacket, GunBoundPacketDecodable, GunBoundPacketEncodable, Equatable, Hashable, Sendable {

    public static var opcode: Opcode { .joinRoomRequest }

    /// The ID of the room to join
    public var room: RoomID

    /// Room password (empty for public rooms).
    ///
    /// The decompiled client (`docs/screens/03_game_room_list.md`) confirms
    /// `0x2110` is a fixed 8-byte packet — `[u16 opcode][u16 roomNumber]
    /// [u32 payload]` — where this trailing field is a **fixed 4-byte value**,
    /// not a variable-length name (correcting an earlier misread). Our
    /// `RoomPassword` is exactly that fixed 4 bytes, so the wire format
    /// matches; the field's real meaning is unconfirmed in the decomp (we use
    /// it as the room password).
    public var password: RoomPassword

    public init(
        room: RoomID,
        password: RoomPassword = ""
    ) {
        self.room = room
        self.password = password
    }

    public init(parsing input: inout ParserSpan) throws {
        self.room = try RoomID(parsing: &input)
        self.password = try RoomPassword(parsing: &input)
    }

    public func encode(to output: inout ByteWriter) {
        room.encode(to: &output)
        password.encode(to: &output)
    }
}
