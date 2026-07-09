/// Tunnel Forward
///
/// Server-to-client leg of the in-game tunnel: when a player sends a
/// ``Tunnel`` (0x4500) addressed to a room slot, the server delivers the
/// payload to that player as this packet, with the *sender's* slot in front
/// so the recipient knows who the traffic came from.
public struct TunnelForward: GunBoundPacket, GunBoundPacketEncodable, GunBoundPacketDecodable, Equatable, Hashable, Sendable {

    public static var opcode: Opcode { .tunnelForward }

    /// Room slot (0-7) of the player the payload originated from.
    public let sourceSlot: UInt8

    /// Opaque game payload, forwarded unmodified from the tunnel request.
    public let payload: [UInt8]

    public init(sourceSlot: UInt8, payload: [UInt8]) {
        self.sourceSlot = sourceSlot
        self.payload = payload
    }

    public init(parsing input: inout ParserSpan) throws {
        self.sourceSlot = try UInt8(parsing: &input)
        self.payload = [UInt8](parsingRemainingBytes: &input)
    }

    public func encode(to output: inout ByteWriter) {
        output.write(sourceSlot)
        output.write(payload)
    }
}
