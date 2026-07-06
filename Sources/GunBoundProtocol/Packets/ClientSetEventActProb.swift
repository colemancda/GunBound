/// Client Set Event Activation Probability (`SVC_CMD_SET_EVENTACTPROB`)
///
/// Sent by the server to set the event activation probability (0-100).
///
/// **Note:** This is a best-effort reconstruction from the opcode name alone.
public struct ClientSetEventActProb: GunBoundPacket, GunBoundPacketEncodable, Equatable, Hashable, Sendable {

    public static var opcode: Opcode { .clientSetEventActProb }

    public let probability: UInt8

    public init(probability: UInt8) {
        self.probability = probability
    }

    public func encode(to output: inout ByteWriter) {
        output.write(probability)
    }
}
