/// Sell Response
///
/// Sent by the server in response to a SellRequest.
/// Confirms successful sale of an avatar item.
///
/// **Opcode:** 0x6027
///
/// **Usage:**
/// Sent after successfully processing a sell request.
/// The RTC field indicates the result:
/// - 0x0000: Success
/// - Non-zero: Error codes
///
/// After successful sale:
/// - Item is removed from player's inventory
/// - Gold is credited to player's account
/// - Server sends GoldUpdateResponse with new balance
public struct SellResponse: GunBoundPacket, GunBoundPacketEncodable, Sendable {

    public static var opcode: Opcode { .sellResponse }

    public init() {}

    public func encode(to output: inout ByteWriter) {
        output.write(UInt16(0x0000), endianness: .little)  // RTC (Return Code: 0x0000 = success)
    }
}
