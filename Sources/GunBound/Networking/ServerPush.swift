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
        default:
            break
        }
        self = .raw(packet)
    }
}
