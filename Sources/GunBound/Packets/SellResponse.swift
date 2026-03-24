/// Sell Response (0x6027)
public struct SellResponse: GunBoundPacket, GunBoundEncodable, Encodable {

    public static var opcode: Opcode { .sellResponse }

    public init() { }

    public func encode(to container: GunBoundEncodingContainer) throws {
        try container.encode(UInt16(0x0000)) // RTC
    }
}
