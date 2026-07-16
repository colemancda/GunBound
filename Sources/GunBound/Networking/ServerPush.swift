import GunBoundProtocol

/// An unsolicited server-to-client packet ("push"), delivered on
/// `NetworkClient.pushes` by the background read loop — the client-side
/// counterpart of the decompiled `ProcessIncomingPackets` pump, which routes
/// every inbound packet to the current screen's handler whether or not the
/// client asked for it.
///
/// Lobby-relevant notifications are decoded into typed cases; everything else
/// arrives as `.raw` so a screen can decode the packet types it knows about
/// (`GunBoundDecoder.decode(_:from:)`) without this enum having to enumerate
/// the whole protocol up front.
public enum ServerPush: Equatable, Sendable {

    /// A room was created/changed in the channel (`0x3105`) — the lobby
    /// refreshes that room's card.
    case roomUpdated(RoomUpdateNotification)

    /// A player left a room (`0x21F1`) — the decomp also uses this family to
    /// clear emptied room slots.
    case roomPlayerLeft(RoomPlayerLeftNotification)

    /// A user joined the channel (`0x200E`) — feeds the channel user list.
    case userJoinedChannel(JoinChannelNotification)

    /// A channel chat line (`0x201F`, decrypted by the read loop) — feeds
    /// the lobby chat panel. The outgoing side (`0x2010`) is decomp-
    /// confirmed as the original's chat send (`FUN_00507660` writes it into
    /// the outgoing packet buffer after parsing `/`-commands); `0x201F` as
    /// the broadcast is our server's convention — the decompiled client's
    /// `0x201f` handler inserts a per-slot record (slot byte + payload,
    /// PROTOCOL.md "Per-slot record lookup/insert"), which is *plausibly*
    /// this same chat-line insert but isn't confirmed.
    case chatReceived(ChannelChatBroadcast)

    /// A server text notice (`0x5101`) — command responses and system
    /// messages, shown as a color-coded system line in the chat log.
    case clientPrint(ClientPrintNotification)

    /// The match is starting (`0x3432`, encrypted) — carries the map and
    /// per-player spawn data; the Ready Room transitions to Loading on it.
    case gameStarted(StartGameNotification)

    /// A player left the room (`0x3020`) — carries the vacated slot so the
    /// Ready Room can clear that seat.
    case userQuit(UserQuitNotification)

    /// The room master left and another player took over (`0x3400`) —
    /// carries the new master's slot and a room summary.
    case hostMigrated(HostMigrationNotification)

    /// In-game tunnel traffic (`0x4501`) — an opaque game payload relayed
    /// from another player's slot.
    case tunnelReceived(TunnelForward)

    /// A player died in-game (`0x4102`, encrypted) — carries the dead
    /// player's slot and team.
    case playerDied(PlayerDeadNotification)

    /// The match is over (`0x4410`, encrypted) — the winning team, or the
    /// relayed jewel-mode summary.
    case gameEnded(GameEndNotification)

    /// The requester's buddy roster refreshed after an add/remove
    /// (`0x2204`, our own convention — see `BuddyEntry`'s type-level note).
    case buddyListUpdated(BuddyListNotification)

    /// Any other notification, undecoded.
    case raw(Packet)
}

extension ServerPush {

    /// Wraps a notification packet, decoding the typed cases and falling back
    /// to `.raw` for everything else (including bodies that fail to parse —
    /// a malformed known notification still surfaces rather than vanishing).
    init(_ packet: Packet, decoder: GunBoundDecoder) {
        switch packet.opcode {
        case .roomUpdateNotification:
            if let value = try? decoder.decode(RoomUpdateNotification.self, from: packet) {
                self = .roomUpdated(value)
                return
            }
        case .roomPlayerLeftNotification:
            if let value = try? decoder.decode(RoomPlayerLeftNotification.self, from: packet) {
                self = .roomPlayerLeft(value)
                return
            }
        case .joinChannelNotification:
            if let value = try? decoder.decode(JoinChannelNotification.self, from: packet) {
                self = .userJoinedChannel(value)
                return
            }
        case .channelChatBroadcast:
            if let value = try? decoder.decode(ChannelChatBroadcast.self, from: packet) {
                self = .chatReceived(value)
                return
            }
        case .clientPrintNotification:
            if let value = try? decoder.decode(ClientPrintNotification.self, from: packet) {
                self = .clientPrint(value)
                return
            }
        case .startGameNotification:
            if let value = try? decoder.decode(StartGameNotification.self, from: packet) {
                self = .gameStarted(value)
                return
            }
        case .userQuitNotification:
            if let value = try? decoder.decode(UserQuitNotification.self, from: packet) {
                self = .userQuit(value)
                return
            }
        case .hostMigrationNotification:
            if let value = try? decoder.decode(HostMigrationNotification.self, from: packet) {
                self = .hostMigrated(value)
                return
            }
        case .tunnelForward:
            if let value = try? decoder.decode(TunnelForward.self, from: packet) {
                self = .tunnelReceived(value)
                return
            }
        case .playerDeadNotification:
            if let value = try? decoder.decode(PlayerDeadNotification.self, from: packet) {
                self = .playerDied(value)
                return
            }
        case .gameEndNotification:
            if let value = try? decoder.decode(GameEndNotification.self, from: packet) {
                self = .gameEnded(value)
                return
            }
        case .buddyListNotification:
            if let value = try? decoder.decode(BuddyListNotification.self, from: packet) {
                self = .buddyListUpdated(value)
                return
            }
        default:
            break
        }
        self = .raw(packet)
    }
}
