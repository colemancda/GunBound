/// Gift Response
///
/// Sent by the server in response to a GiftRequest.
/// Acknowledges a successful gift transaction.
///
/// **Opcode:** 0x6037
///
/// **Usage:**
/// Sent after successfully processing a gift request.
/// The RTC (return code) field indicates the result of the gift:
/// - 0x6005: Success
/// - Other values: Error codes
///
/// The client should wait for this response before allowing further gifts.
/// If successful, the item is removed from the sender's inventory and added
/// to the recipient's inventory.
public struct GiftResponse: GunBoundPacket, GunBoundEncodable, Encodable {

    public static var opcode: Opcode { .giftResponse }

    public init() {}

    public func encode(to container: GunBoundEncodingContainer) throws {
        try container.encode(UInt16(0x6005))  // RTC (Return Code: 0x6005 = success)
    }
}
