/// Gold Update Response
///
/// Sent by the server in response to a GoldUpdateRequest.
/// Contains the player's current gold balance.
///
/// **Usage:**
/// The client should update its cached gold balance when receiving this packet.
/// This ensures the UI displays the correct amount of available gold for purchases.
///
/// This packet is typically sent after purchases, game rewards, or when explicitly
/// requested by the client.
public struct GoldUpdateResponse: GunBoundPacket, GunBoundPacketEncodable, Hashable, Sendable {

    public static var opcode: Opcode { .goldUpdateResponse }

    /// The player's current gold balance (in-game currency)
    public var gold: UInt64

    public init(gold: UInt64 = 0) {
        self.gold = gold
    }

    public func encode(to output: inout ByteWriter) {
        output.write(gold, endianness: .little)
    }
}
