/// GunBound Packet Encoder
public struct GunBoundEncoder: Sendable {

    /// Logging handler
    public var log: (@Sendable (String) -> Void)?

    public init() {}

    public func encode<T: GunBoundPacketEncodable>(_ value: T, id: Packet.ID) -> Packet {
        let opcode = T.opcode
        log?("Will encode \(opcode) packet")
        var writer = ByteWriter()
        value.encode(to: &writer)
        var packet = Packet(opcode: opcode, id: id, parameters: writer.bytes)
        packet.id = id
        return packet
    }

    public func encode(_ opcode: Opcode, id: Packet.ID) -> Packet {
        var packet = Packet(opcode: opcode)
        packet.id = id
        return packet
    }
}
