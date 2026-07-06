/// Client Set Event Activation Probability (`SVC_CMD_SET_EVENTACTPROB`)
///
/// Sent by the server to set the event activation probability (0-100).
///
/// **Note:** This is a best-effort reconstruction from the opcode name alone.
public struct ClientSetEventActProb: GunBoundPacket, GunBoundPacketEncodable, GunBoundPacketDecodable, Equatable, Hashable, Sendable {

    public static var opcode: Opcode { .clientSetEventActProb }

    public let probability: UInt8

    public init(probability: UInt8) {
        self.probability = probability
    }

    public init(parsing input: inout ParserSpan) throws(ParsingError) {
        self.probability = try UInt8(parsing: &input)
    }

    public func encode(to output: inout ByteWriter) {
        output.write(probability)
    }
}
