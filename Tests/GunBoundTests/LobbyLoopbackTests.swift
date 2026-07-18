import Foundation
import Testing
@testable import GunBound
@testable import GunBoundProtocol

/// End-to-end: a real `GunBoundServer` and a real `NetworkClient`, wired
/// together through an in-memory socket (`InMemoryTCPSocket`) instead of a
/// TCP loopback. Exercises the whole stack together — login handshake,
/// confirm-connect, the background packet pump, room create, and the
/// server's `0x3105` room-update push arriving on `pushes` (the live-lobby
/// refresh signal) — deterministically, with no file descriptors.
///
/// Serialized so the shared socket registry hands each test its own server
/// address; time-limited so a logic hang fails fast instead of wedging.
@Suite(.serialized, .timeLimit(.minutes(1)))
struct LobbyLoopbackTests {

    /// Starts an in-process world server on an ephemeral loopback port with
    /// the standard admin user (same seeding as the `GunBoundServer world`
    /// executable) plus a plain guest account for two-client tests.
    private static func startServer() async throws -> (server: GunBoundServer<InMemoryTCPSocket, InMemoryUDPSocket, InMemoryGunBoundServerDataSource>, port: UInt16) {
        let dataSource = InMemoryGunBoundServerDataSource()
        await dataSource.update {
            $0.passwords["admin"] = "1234"
            $0.users["admin"] = User(id: "admin", isBanned: false, rank: .administrator, gold: 0, cash: 0)
            $0.passwords["guest"] = "1234"
            $0.users["guest"] = User(id: "guest", isBanned: false, rank: .chick, gold: 0, cash: 0)
        }
        // Ephemeral port, retrying a few times in case of a collision.
        let port = await InMemoryTCPRegistry.shared.uniqueServerPort()
        let address = GunBound.GunBoundAddress(address: "127.0.0.1", port: port)!
        let server = try await GunBoundServer(
            configuration: GunBoundServerConfiguration(address: address, backlog: 8),
            dataSource: dataSource,
            socket: (InMemoryTCPSocket.self, InMemoryUDPSocket.self)
        )
        return (server, port)
    }

    /// login → join channel → create room → the server's room-update push
    /// (`0x3105`) arrives on the client's push stream, and the refreshed
    /// room list contains the created room.
    @Test func createRoomEmitsARoomUpdatePush() async throws { try await TestServer.exclusive {
        let (server, port) = try await Self.startServer()
        defer { withExtendedLifetime(server) {} }

        let client = try await TestServer.connect("admin", port: port)
        defer { Task { await client.close() } }

        // Empty lobby to start.
        let before = try await client.fetchRoomList()
        #expect(before.isEmpty)

        // Create a room; the server replies 0x2121 *and* sends the 0x3105
        // room-update notification the live lobby refreshes on.
        let created = try await client.createRoom(name: "loopback", capacity: ._2_2)

        var sawRoomUpdate = false
        for await push in await client.pushes {
            if case .roomUpdated = push {
                sawRoomUpdate = true
                break
            }
        }
        #expect(sawRoomUpdate)

        // The refreshed list shows the created room.
        let after = try await client.fetchRoomList()
        #expect(after.contains { $0.id == created.room })
    } }

    /// Channel chat round-trip over real sockets: the encrypted `0x2010`
    /// command goes out, the server broadcasts the (also encrypted) `0x201F`
    /// back to the channel, and the pump decrypts + decodes it into a typed
    /// push — AES exercised in both directions with the session key.
    @Test func chatRoundTripsEncrypted() async throws { try await TestServer.exclusive {
        let (server, port) = try await Self.startServer()
        defer { withExtendedLifetime(server) {} }

        let client = try await TestServer.connect("admin", port: port)
        defer { Task { await client.close() } }

        try await client.send(ChannelChatCommand(message: "hello loopback"))

        var received: ChannelChatBroadcast?
        for await push in await client.pushes {
            if case .chatReceived(let broadcast) = push {
                received = broadcast
                break
            }
        }
        #expect(received?.message == "hello loopback")
        #expect(received.map { String(describing: $0.username) } == "admin")
    } }

    /// The full Ready Room flow with two real clients: the host creates a
    /// room, a guest joins, picks a mobile (`0x3200`), switches to team B
    /// (`0x3210`), readies up (`0x3230`), and the host starts (`0x3430`) —
    /// then **both** clients receive the encrypted `0x3432` start push with
    /// the map and spawn data.
    @Test func twoClientReadyRoomFlowStartsTheGame() async throws { try await TestServer.exclusive {
        let (server, port) = try await Self.startServer()
        defer { withExtendedLifetime(server) {} }

        func connect(_ username: String) async throws -> NetworkClient<InMemoryTCPSocket> {
            try await TestServer.connect(username, port: port)
        }

        let host = try await connect("admin")
        defer { Task { await host.close() } }
        let guest = try await connect("guest")
        defer { Task { await guest.close() } }

        // Host creates and enters the room; guest joins it.
        let created = try await host.createRoom(name: "ready flow", capacity: ._2_2)
        let hostJoin = try await host.joinRoom(created.room)
        #expect(hostJoin.isSuccess)
        let guestJoin = try await guest.joinRoom(created.room)
        #expect(guestJoin.isSuccess)

        // Guest: pick a mobile, move to team B, ready up.
        _ = try await guest.selectTank(primary: .boomer)
        _ = try await guest.selectTeam(.b)
        let ready = try await guest.setReady(true)
        #expect(ready.isSuccess)

        // Host starts; both clients get the 0x3432 push (decrypted by the
        // pump — startGameNotification is an encrypted opcode).
        try await host.startGame()

        for client in [host, guest] {
            var started: StartGameNotification?
            for await push in await client.pushes {
                if case .gameStarted(let notification) = push {
                    started = notification
                    break
                }
            }
            #expect(started != nil)
            #expect(started?.players.count == 2)
        }

        // The guest's mobile dies (self-reported, the original's `0x4100`
        // flow): the server broadcasts the death and — the guest being all
        // of team B — ends the match, pushing the winner to both clients.
        try await guest.reportDeath()
        for client in [host, guest] {
            var ended: GameEndNotification?
            for await push in await client.pushes {
                if case .gameEnded(let notification) = push {
                    ended = notification
                    break
                }
            }
            #expect(ended?.winner == .a)
        }

        // Both players return to the room for the next round.
        try await host.returnToRoom()
        try await guest.returnToRoom()
    } }

    /// The buddy list end to end (our own convention — see `BuddyEntry`'s
    /// type-level note): an empty roster fetches clean, adding a connected
    /// username reports it online in the refreshed push, and removing it
    /// clears the roster again.
    @Test func buddyListAddRemoveReflectsOnlineStatus() async throws { try await TestServer.exclusive {
        let (server, port) = try await Self.startServer()
        defer { withExtendedLifetime(server) {} }

        func connect(_ username: String) async throws -> NetworkClient<InMemoryTCPSocket> {
            try await TestServer.connect(username, port: port)
        }

        let admin = try await connect("admin")
        defer { Task { await admin.close() } }
        let guest = try await connect("guest")
        defer { Task { await guest.close() } }

        #expect(try await admin.fetchBuddyList().isEmpty)

        try await admin.addBuddy("guest")
        var afterAdd: [BuddyEntry]?
        for await push in await admin.pushes {
            if case .buddyListUpdated(let notification) = push {
                afterAdd = notification.buddies
                break
            }
        }
        #expect(afterAdd == [BuddyEntry(username: "guest", isOnline: true)])

        try await admin.removeBuddy("guest")
        var afterRemove: [BuddyEntry]?
        for await push in await admin.pushes {
            if case .buddyListUpdated(let notification) = push {
                afterRemove = notification.buddies
                break
            }
        }
        #expect(afterRemove == [])
        #expect(try await admin.fetchBuddyList().isEmpty)
    } }
}
