/// Tunnel (`SVC_TUNNEL`)
///
/// P2P tunneling packet, relayed by the server between two clients attempting
/// a direct connection. Carries an opaque, forwarded payload.
///
/// **Note:** This is a best-effort reconstruction from the opcode name alone.
public struct Tunnel: GunBoundPacket, GunBoundPacketEncodable, GunBoundPacketDecodable, Equatable, Hashable, Sendable {

    public static var opcode: Opcode { .tunnel }

    public let payload: [UInt8]

    public init(payload: [UInt8]) {
        self.payload = payload
    }

    public init(parsing input: inout ParserSpan) throws {
        self.payload = [UInt8](parsingRemainingBytes: &input)
    }

    public func encode(to output: inout ByteWriter) {
        output.write(payload)
    }
}
