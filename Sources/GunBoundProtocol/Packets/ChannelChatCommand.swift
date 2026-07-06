/// Channel Chat Command
///
/// Sent by the client to broadcast a chat message to all users in a channel.
///
/// **Usage:**
/// When a player types a message in the channel chat, this packet is sent to the server.
/// The server validates the message and broadcasts a ChannelChatBroadcast to all users
/// in the channel, including the sender.
public struct ChannelChatCommand: GunBoundPacket, GunBoundPacketEncodable, GunBoundPacketDecodable, Equatable, Hashable, Sendable {

    public static var opcode: Opcode { .channelChatCommand }

    /// The chat message content to broadcast
    public var message: String

    public init(message: String) {
        self.message = message
    }

    public init(parsing input: inout ParserSpan) throws(ParsingError) {
        self.message = try String(parsingLengthPrefixedASCII: &input)
    }

    public func encode(to output: inout ByteWriter) {
        output.writeLengthPrefixed(ascii: message)
    }
}
