/// Room Change Capacity Command
///
/// Sent by the room host to change the maximum number of players.
/// Only the room host can send this command.
///
/// **Usage:**
/// Used when the room host wants to increase or decrease
/// the room capacity (number of players allowed).
///
/// Upon successful change:
/// - Server validates the new capacity
/// - Server broadcasts RoomUpdateNotification to all players in room
/// - Room list in lobby is updated to reflect new capacity
///
/// Note: Cannot reduce capacity below the current number of players
/// in the room.
public struct RoomChangeCapacityCommand: GunBoundPacket, GunBoundPacketDecodable, GunBoundPacketEncodable, Equatable, Hashable, Sendable {

    public static var opcode: Opcode { .roomChangeCapacityCommand }

    /// The new maximum capacity for the room
    public var capacity: RoomCapacity

    public init(capacity: RoomCapacity) {
        self.capacity = capacity
    }

    public init(parsing input: inout ParserSpan) throws {
        self.capacity = try RoomCapacity(parsing: &input)
    }

    public func encode(to output: inout ByteWriter) {
        capacity.encode(to: &output)
    }
}
