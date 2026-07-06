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
public struct GiftResponse: GunBoundPacket, GunBoundPacketEncodable, GunBoundPacketDecodable, Sendable {

    public static var opcode: Opcode { .giftResponse }

    public init() {}

    public init(parsing input: inout ParserSpan) throws(ParsingError) {
        _ = try UInt16(parsingLittleEndian: &input)  // RTC (Return Code: 0x6005 = success)
    }

    public func encode(to output: inout ByteWriter) {
        output.write(UInt16(0x6005), endianness: .little)  // RTC (Return Code: 0x6005 = success)
    }
}
