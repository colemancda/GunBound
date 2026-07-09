/// User Quit Notification
///
/// Broadcast to the remaining players in a room when someone leaves (either
/// returning to the lobby or disconnecting). The payload is the vacated
/// slot, so clients can clear that seat in the Ready Room.
public struct UserQuitNotification: GunBoundPacket, GunBoundPacketEncodable, GunBoundPacketDecodable, Equatable, Hashable, Sendable {

    public static var opcode: Opcode { .userQuitNotification }

    /// The room slot the departing player occupied.
    public let slot: UInt16

    public init(slot: UInt16) {
        self.slot = slot
    }

    public init(parsing input: inout ParserSpan) throws {
        self.slot = try UInt16(parsingLittleEndian: &input)
    }

    public func encode(to output: inout ByteWriter) {
        output.write(slot, endianness: .little)
    }
}
