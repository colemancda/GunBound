import GunBoundProtocol

/// The set of server operations the view models drive, abstracted away from
/// the concrete `NetworkClient<Socket>` so a view model can be exercised with
/// any conforming client — the live `NetworkClient` in the app, or a
/// mock-socket-backed one in tests. Mirrors `NetworkClient`'s own request
/// surface exactly; the convenience overloads below reproduce its default
/// arguments (protocol requirements can't declare them) so existing call
/// sites are unchanged.
public protocol GameClient: Sendable {

    /// The server-push stream (room updates, chat, notifications). Immutable
    /// and `Sendable`, so it's read without actor hops.
    nonisolated var pushes: AsyncStream<ServerPush> { get }

    func close() async

    func authenticate(username: String, password: String) async throws -> AuthenticationResponse
    func joinChannel(_ channel: ChannelID) async throws -> JoinChannelResponse
    func fetchRoomList(filter: RoomFilter) async throws -> [RoomListResponse.Room]
    func fetchBuddyList() async throws -> [BuddyEntry]
    func addBuddy(_ username: Username) async throws
    func removeBuddy(_ username: Username) async throws
    func joinRoom(_ room: RoomID, password: RoomPassword) async throws -> JoinRoomResponse
    func createRoom(name: String, password: RoomPassword, capacity: RoomCapacity, settings: UInt32) async throws -> CreateRoomResponse
    func setReady(_ isReady: Bool) async throws -> UserReadyResponse
    func selectTank(primary: Mobile, secondary: Mobile) async throws -> RoomSelectTankResponse
    func selectTeam(_ team: Team) async throws -> RoomSelectTeamResponse
    func startGame() async throws
    func reportDeath() async throws
    func returnToRoom() async throws
    func resurrect() async throws
    func sendTunnel(to slot: UInt8, payload: [UInt8]) async throws
    func fetchAvatar() async throws -> PlayerAvatar
    func buyAvatarItem(_ code: AvatarShopItemCode, withGold: Bool) async throws
    func send<Request: GunBoundPacketEncodable>(_ requestValue: Request) async throws
}

public extension GameClient {

    func joinChannel() async throws -> JoinChannelResponse {
        try await joinChannel(0xFFFF)
    }

    func fetchRoomList() async throws -> [RoomListResponse.Room] {
        try await fetchRoomList(filter: .all)
    }

    func joinRoom(_ room: RoomID) async throws -> JoinRoomResponse {
        try await joinRoom(room, password: "")
    }

    func createRoom(name: String, password: RoomPassword, capacity: RoomCapacity) async throws -> CreateRoomResponse {
        try await createRoom(name: name, password: password, capacity: capacity, settings: 0)
    }

    func selectTank(primary: Mobile) async throws -> RoomSelectTankResponse {
        try await selectTank(primary: primary, secondary: .random)
    }
}
