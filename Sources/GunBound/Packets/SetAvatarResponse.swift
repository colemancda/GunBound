/// Set Avatar Response (0x6005)
public struct SetAvatarResponse: GunBoundPacket, GunBoundEncodable, Encodable {

    public static var opcode: Opcode { .setAvatarResponse }

    public init() {}

    public func encode(to container: GunBoundEncodingContainer) throws {
        try container.encode(UInt16(0x0000))  // RTC
    }
}
