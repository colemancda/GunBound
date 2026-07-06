/// Create Room Response
///
/// Sent by the server in response to a CreateRoomRequest.
/// Contains the ID of the newly created room and a status message.
///
/// **Usage:**
/// Sent to the client who requested the room creation.
/// The room ID is used to identify the room in all subsequent communications.
/// The message field typically contains status information or error messages.
///
/// Upon successful room creation, the server also broadcasts a RoomUpdateNotification
/// to all players in the channel to update the room list.
public struct CreateRoomResponse: GunBoundPacket, GunBoundPacketEncodable, Equatable, Hashable, Sendable {

    public static var opcode: Opcode { .createRoomResponse }

    /// The ID of the newly created room
    public var room: RoomID

    /// Status message (empty on success, contains error details on failure)
    public var message: String

    public init(
        room: RoomID,
        message: String
    ) {
        self.room = room
        self.message = message
    }

    public func encode(to output: inout ByteWriter) {
        output.write([0x00, 0x00, 0x00])
        room.encode(to: &output)
        output.write(Array(message.utf8))
    }
}
