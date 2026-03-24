/// Gift Response (0x6037)
public struct GiftResponse: GunBoundPacket, GunBoundEncodable, Encodable {

    public static var opcode: Opcode { .giftResponse }

    public init() {}

    public func encode(to container: GunBoundEncodingContainer) throws {
        try container.encode(UInt16(0x6005))  // RTC
    }
}
