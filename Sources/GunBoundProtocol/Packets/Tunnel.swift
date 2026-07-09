/// Tunnel (`SVC_TUNNEL`)
///
/// In-game relay: every gameplay action (shots, movement, turn sync) is sent
/// to the server as a tunnel packet addressed to a room slot. The server
/// forwards the opaque payload to that player as a ``TunnelForward``
/// (0x4501) carrying the sender's slot instead.
public struct Tunnel: GunBoundPacket, GunBoundPacketEncodable, GunBoundPacketDecodable, Equatable, Hashable, Sendable {

    public static var opcode: Opcode { .tunnel }

    /// Leading value observed before the destination slot; semantics
    /// unconfirmed (skipped by the reference server).
    public let value0: UInt16

    /// Room slot (0-7) of the player the payload is addressed to.
    public let destinationSlot: UInt8

    /// Opaque game payload, forwarded unmodified.
    public let payload: [UInt8]

    public init(value0: UInt16 = 0, destinationSlot: UInt8, payload: [UInt8]) {
        self.value0 = value0
        self.destinationSlot = destinationSlot
        self.payload = payload
    }

    public init(parsing input: inout ParserSpan) throws {
        self.value0 = try UInt16(parsingLittleEndian: &input)
        self.destinationSlot = try UInt8(parsing: &input)
        self.payload = [UInt8](parsingRemainingBytes: &input)
    }

    public func encode(to output: inout ByteWriter) {
        output.write(value0, endianness: .little)
        output.write(destinationSlot)
        output.write(payload)
    }
}
