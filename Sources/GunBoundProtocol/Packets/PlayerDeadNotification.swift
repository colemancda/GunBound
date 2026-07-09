/// Player Dead Notification
///
/// Broadcast to every player in the room when someone dies in-game: the
/// dead player's slot, 10 reserved bytes, and the dead player's team —
/// 12 bytes total, exactly one AES block.
public struct PlayerDeadNotification: GunBoundPacket, GunBoundPacketEncodable, GunBoundPacketDecodable, Equatable, Hashable, Sendable {

    public static var opcode: Opcode { .playerDeadNotification }

    /// Reserved bytes observed between the slot and team fields.
    public static let reservedBytes: [UInt8] = [0x13, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x44, 0x34, 0x47]

    /// Room slot of the player that died.
    public let slot: UInt8

    /// Reserved field (see `reservedBytes` for the observed value).
    internal let reserved: [UInt8]

    /// Team of the player that died.
    public let team: Team

    public init(slot: UInt8, team: Team) {
        self.slot = slot
        self.reserved = Self.reservedBytes
        self.team = team
    }

    public init(parsing input: inout ParserSpan) throws {
        self.slot = try UInt8(parsing: &input)
        self.reserved = try [UInt8](parsing: &input, byteCount: Self.reservedBytes.count)
        self.team = try Team(parsing: &input)
    }

    public func encode(to output: inout ByteWriter) {
        output.write(slot)
        output.write(reserved)
        team.encode(to: &output)
    }
}
