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
public struct GetAvatarRequest: GunBoundPacket, GunBoundDecodable, Decodable {

    public static var opcode: Opcode { .getAvatarRequest }

    /// If true, the full inventory list is included in the response.
    /// If false, only basic/equipped avatar information is returned.
    public let sendExtended: Bool

    public init(from container: GunBoundDecodingContainer) throws {
        let raw = try container.decode(UInt8.self)
        sendExtended = raw == 1
    }
}
