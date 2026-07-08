import GunBoundProtocol

/// Mutable session state carried across screens as the player advances through
/// the flow: the channel they joined, the room they're currently in (with the
/// roster the join returned), and their avatar inventory once the store loads
/// it. Screens reach this through `ViewModelDelegate`, so e.g. the Ready Room
/// can show the roster the Game Room List's join produced without re-fetching
/// it — mirroring the original client's global session state
/// (`g_clientContext` fields) rather than passing data screen-to-screen.
@MainActor
public final class ClientSession {

    /// The channel the player is in (from the confirm-connect `0x2001`).
    public var channel: JoinChannelResponse?

    /// The room the player has joined and its full roster (from the
    /// `JoinRoomResponse`), or `nil` in the lobby.
    public var currentRoom: JoinRoomResponse?

    /// The player's equipped avatar + owned item IDs, once the Avatar Store
    /// (or anything else) has fetched them.
    public var avatar: PlayerAvatar?

    public init() {}
}

/// The player's avatar state decoded from a `getAvatarResponse` (`0x6001`):
/// the equipped-items bitmask plus the list of owned item IDs.
public struct PlayerAvatar: Equatable, Sendable {
    public var equipped: UInt64
    public var inventory: [UInt32]

    public init(equipped: UInt64, inventory: [UInt32]) {
        self.equipped = equipped
        self.inventory = inventory
    }
}
