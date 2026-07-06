/// Channel Chat Broadcast
///
/// Sent by the server to broadcast a chat message to all users in a channel.
/// This is sent in response to a ChannelChatCommand from a user.
///
/// **Usage:**
/// All clients in the channel receive this packet when someone sends a message.
/// The client should display the message in the chat window with the sender's
/// username. The position field indicates the sender's user ID in the channel.
public struct ChannelChatBroadcast: GunBoundPacket, GunBoundPacketEncodable, GunBoundPacketDecodable, Equatable, Hashable, Sendable {

    public static var opcode: Opcode { .channelChatBroadcast }

    /// The sender's user ID position in the channel
    public let position: ChannelUserID

    /// The sender's username
    public let username: Username

    /// The chat message content
    public let message: String

    public init(
        position: ChannelUserID,
        username: Username,
        message: String
    ) {
        self.position = position
        self.username = username
        self.message = message
    }

    public init(parsing input: inout ParserSpan) throws {
        self.position = try ChannelUserID(parsing: &input)
        self.username = try Username(parsing: &input)
        self.message = try String(parsingLengthPrefixedASCII: &input)
    }

    public func encode(to output: inout ByteWriter) {
        position.encode(to: &output)
        username.encode(to: &output)
        output.writeLengthPrefixed(ascii: message)
    }
}
