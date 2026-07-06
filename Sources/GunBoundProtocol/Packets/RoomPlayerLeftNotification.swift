/// Room Player Left Notification
///
/// A player/entity ID identifying who left the room; removes them from
/// local room-membership tracking. If the departing player was the local
/// client itself (self-initiated leave being echoed back), the client
/// resets its own cached slot index.
///
/// **Note:** Reconstructed from static analysis of the original client, not a live packet capture or verified traffic.
public struct RoomPlayerLeftNotification: GunBoundPacket, GunBoundPacketEncodable, GunBoundPacketDecodable, Equatable, Hashable, Sendable {

    public static var opcode: Opcode { .roomPlayerLeftNotification }

    public let playerID: UInt16

    public init(playerID: UInt16) {
        self.playerID = playerID
    }

    public init(parsing input: inout ParserSpan) throws(ParsingError) {
        self.playerID = try UInt16(parsingLittleEndian: &input)
    }

    public func encode(to output: inout ByteWriter) {
        output.write(playerID, endianness: .little)
    }
}
