/// Join Room Notification (Self)
///
/// Sent by the server to the player who just joined a room.
/// Confirms successful room join with minimal data.
///
/// **Usage:**
/// Sent to the joining player after a successful JoinRoomRequest.
/// Unlike JoinRoomNotification (which is sent to other players),
/// this packet is sent only to the player who joined.
///
/// After receiving this, the client should:
/// - Display the room interface
/// - Wait for JoinRoomNotification packets for other players in the room
/// - Expect RoomUpdateNotification for any room state changes
public struct JoinRoomNotificationSelf: GunBoundPacket, GunBoundPacketEncodable, Equatable, Hashable, Sendable {

    public static var opcode: Opcode { .joinRoomNotificationSelf }

    /// Return code (0x00 = success)
    internal let rtc: UInt16

    /// Unknown value (typically 0x03, purpose not yet determined)
    internal let value: UInt8

    public init() {
        self.rtc = 0x00
        self.value = 03
    }

    public func encode(to output: inout ByteWriter) {
        output.write(rtc, endianness: .little)
        output.write(value)
    }
}
