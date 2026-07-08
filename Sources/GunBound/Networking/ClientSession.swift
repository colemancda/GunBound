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

    /// The player's owned avatar items, once the Avatar Store has fetched
    /// them (each is one `0x6002` `InventoryItem`).
    public var inventory: [AvatarInventoryResponse]?

    public init() {}
}
