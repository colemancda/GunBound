/// Buy Response (0x6017) — acknowledges both gold and cash purchases
public struct BuyResponse: GunBoundPacket, GunBoundEncodable, Encodable {

    public static var opcode: Opcode { .buyResponse }

    public init() { }

    public func encode(to container: GunBoundEncodingContainer) throws {
        try container.encode(UInt16(0x0000)) // RTC
    }
}
