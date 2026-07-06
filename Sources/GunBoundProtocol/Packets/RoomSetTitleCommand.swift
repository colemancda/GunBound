/// Room Set Title Command
///
/// Sent by room host to change the room's display name.
/// Only room host can send this command.
///
/// **Usage:**
/// Used when room host wants to rename the room.
/// The new title appears in the room list for all players in the channel.
///
/// Upon successful change:
/// - Server validates the title
/// - Server broadcasts RoomUpdateNotification to all players in room
/// - Room list in lobby is updated with the new title
public struct RoomSetTitleCommand: GunBoundPacket, GunBoundPacketDecodable, Equatable, Hashable, Sendable {

    public static var opcode: Opcode { .roomSetTitleCommand }

    /// The new title/name for the room
    public var title: String

    public init(title: String) {
        self.title = title
    }

    public init(parsing input: inout ParserSpan) throws(ParsingError) {
        let bytes = [UInt8](parsingRemainingBytes: &input)
        self.title = String(decoding: bytes, as: UTF8.self)
    }
}
