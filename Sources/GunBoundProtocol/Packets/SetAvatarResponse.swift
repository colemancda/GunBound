/// Set Avatar Response
///
/// Sent by the server in response to a SetAvatarRequest.
/// Confirms successful avatar equipment change.
///
/// **Opcode:** 0x6005
///
/// **Usage:**
/// Sent after successfully processing an avatar equip request.
/// The RTC field indicates the result:
/// - 0x0000: Success
/// - Non-zero: Error codes
public struct SetAvatarResponse: GunBoundPacket, GunBoundPacketEncodable, GunBoundPacketDecodable, Sendable {

    public static var opcode: Opcode { .setAvatarResponse }

    public init() {}

    public init(parsing input: inout ParserSpan) throws(ParsingError) {
        _ = try UInt16(parsingLittleEndian: &input)  // RTC (Return Code: 0x0000 = success)
    }

    public func encode(to output: inout ByteWriter) {
        output.write(UInt16(0x0000), endianness: .little)  // RTC (Return Code: 0x0000 = success)
    }
}
