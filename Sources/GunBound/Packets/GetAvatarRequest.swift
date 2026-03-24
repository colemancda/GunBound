/// Get Avatar / Inventory Request (0x6000)
public struct GetAvatarRequest: GunBoundPacket, GunBoundDecodable, Decodable {

    public static var opcode: Opcode { .getAvatarRequest }

    /// If true, the full inventory list is included in the response.
    public let sendExtended: Bool

    public init(from container: GunBoundDecodingContainer) throws {
        let raw = try container.decode(UInt8.self)
        sendExtended = raw == 1
    }
}
