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
public struct SetAvatarResponse: GunBoundPacket, GunBoundEncodable, Encodable {

    public static var opcode: Opcode { .setAvatarResponse }

    public init() {}

    public func encode(to container: GunBoundEncodingContainer) throws {
        try container.encode(UInt16(0x0000))  // RTC (Return Code: 0x0000 = success)
    }
}
