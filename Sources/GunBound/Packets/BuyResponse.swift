/// Buy Response
///
/// Sent by the server in response to both BuyGoldRequest and BuyCashRequest.
/// Acknowledges a successful avatar purchase.
///
/// **Opcode:** 0x6017
///
/// **Usage:**
/// Sent after successfully processing a purchase request.
/// The RTC (return code) field indicates the result of the purchase:
/// - 0x0000: Success
/// - Non-zero: Error occurred
///
/// The client should wait for this response before allowing further purchases.
public struct BuyResponse: GunBoundPacket, GunBoundEncodable, Encodable {

    public static var opcode: Opcode { .buyResponse }

    public init() {}

    public func encode(to container: GunBoundEncodingContainer) throws {
        try container.encode(UInt16(0x0000))  // RTC (Return Code: 0 = success)
    }
}
