/// Start Game Command
///
/// Sent by the room master to start the game.
/// Only the room master can send this command.
///
/// **Usage:**
/// Used when all players in the room are ready and the master
/// wants to begin the match. The server validates that all
/// players are ready and the teams are balanced.
///
/// Upon successful start:
/// - Server sends StartGameNotification to all players, echoing this
///   command's payload at the end of the notification
/// - Game transitions from lobby to playing state
/// - Players load the game map and begin gameplay
///
/// Note: Game cannot start if:
/// - The sender is not the room master
/// - Not all players are ready
/// - Game is already in progress
public struct StartGameCommand: GunBoundPacket, GunBoundPacketEncodable, GunBoundPacketDecodable, Equatable, Hashable, Sendable {

    public static var opcode: Opcode { .startGameCommand }

    /// Opaque payload from the game host, echoed back to every player at
    /// the end of the StartGameNotification.
    public let payload: [UInt8]

    public init(payload: [UInt8] = []) {
        self.payload = payload
    }

    public init(parsing input: inout ParserSpan) throws {
        self.payload = [UInt8](parsingRemainingBytes: &input)
    }

    public func encode(to output: inout ByteWriter) {
        output.write(payload)
    }
}
