/// Room Select Tank Request
///
/// Sent by the client to select mobile/tank types.
/// Players select their primary and secondary mobiles before the game starts.
///
/// **Usage:**
/// Used when a player wants to change their selected mobiles
/// in the room. Each player selects a primary mobile (the one
/// they will use in the game) and a secondary mobile (which may
/// be used for certain game modes or features).
///
/// Upon successful selection:
/// - Server validates the mobile selections
/// - Server broadcasts RoomUpdateNotification to all players
/// - Other players see the updated mobile selection in the room display
///
/// Note: Mobile selections cannot be changed once the game has started.
public struct RoomSelectTankRequest: GunBoundPacket, GunBoundPacketDecodable, GunBoundPacketEncodable, Equatable, Hashable, Sendable {

    public static var opcode: Opcode { .roomSelectTankRequest }

    /// The primary mobile/tank selection
    public var primary: Mobile

    /// The secondary mobile/tank selection
    public var secondary: Mobile

    public init(
        primary: Mobile = .random,
        secondary: Mobile = .random
    ) {
        self.primary = primary
        self.secondary = secondary
    }

    public init(parsing input: inout ParserSpan) throws {
        self.primary = try Mobile(parsing: &input)
        self.secondary = try Mobile(parsing: &input)
    }

    public func encode(to output: inout ByteWriter) {
        primary.encode(to: &output)
        secondary.encode(to: &output)
    }
}
