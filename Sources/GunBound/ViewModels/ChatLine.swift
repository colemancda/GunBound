/// One chat-log line: a sender, a message, and the decomp's per-message
/// **type byte** that drives color-coded rendering. The decompiled chat-row
/// renderers (`RenderReadyRoomChatRow`, `0x50d200`, and the in-battle chat)
/// switch on this byte (`g_clientContext+0x3c4d8`) to pick a name color and
/// a message color per line — see `docs/widgets.md` and the widget layer's
/// color table.
public struct ChatLine: Equatable, Hashable, Sendable {

    /// The decomp's message-type byte (cases `0`–`0x10` in the renderer's
    /// color switch). Semantics are only partially traced, so just the types
    /// we produce are named; the raw value is preserved for the rest.
    public struct MessageType: RawRepresentable, Equatable, Hashable, Sendable {

        public var rawValue: UInt8

        public init(rawValue: UInt8) {
            self.rawValue = rawValue
        }

        /// Normal player chat (type 0 — white name, white message).
        public static let normal = MessageType(rawValue: 0)

        /// A system/server notice (type 2 — yellow message, no name color).
        public static let notice = MessageType(rawValue: 2)
    }

    /// The sender's name, empty for system lines.
    public let sender: String

    public let message: String

    public let type: MessageType

    public init(sender: String = "", message: String, type: MessageType = .normal) {
        self.sender = sender
        self.message = message
        self.type = type
    }
}
