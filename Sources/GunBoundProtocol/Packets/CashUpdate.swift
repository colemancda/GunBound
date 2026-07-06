/// Cash Update Notification
///
/// Sent by the server to update the client's current cash balance.
/// This is typically sent after purchases or when cash is awarded.
///
/// **Usage:**
/// The client should update its cached cash balance when receiving this packet.
/// This ensures the UI displays the correct amount of available cash.
///
/// **Note:** This packet is encrypted before transmission.
public struct CashUpdate: GunBoundPacket, GunBoundPacketEncodable, GunBoundPacketDecodable, Hashable, Sendable {

    public static var opcode: Opcode { .cashUpdateNotification }

    /// The player's current cash balance (real currency)
    public let cash: UInt32

    public init(cash: UInt32 = 0) {
        self.cash = cash
    }

    public init(parsing input: inout ParserSpan) throws(ParsingError) {
        self.cash = try UInt32(parsingLittleEndian: &input)
    }

    public func encode(to output: inout ByteWriter) {
        output.write(cash, endianness: .little)
    }
}
