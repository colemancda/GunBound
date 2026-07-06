/// Get Avatar / Inventory Request
///
/// Sent by the client to retrieve the player's avatar inventory.
/// The server responds with a GetAvatarResponse containing avatar data.
///
/// **Opcode:** 0x6000
///
/// **Usage:**
/// Used when the player opens the avatar/inventory screen or needs to
/// refresh their inventory data. The client can request basic or extended
/// inventory information based on the sendExtended flag.
///
/// When sendExtended is true, the response includes detailed information
/// about all avatar items in the player's inventory. When false, only
/// basic information is returned (typically just equipped avatars).
public struct GetAvatarRequest: GunBoundPacket, GunBoundPacketDecodable, GunBoundPacketEncodable, Sendable {

    public static var opcode: Opcode { .getAvatarRequest }

    /// If true, the full inventory list is included in the response.
    /// If false, only basic/equipped avatar information is returned.
    public let sendExtended: Bool

    public init(sendExtended: Bool) {
        self.sendExtended = sendExtended
    }

    public init(parsing input: inout ParserSpan) throws(ParsingError) {
        let raw = try UInt8(parsing: &input)
        sendExtended = raw == 1
    }

    public func encode(to output: inout ByteWriter) {
        output.write(sendExtended)
    }
}
