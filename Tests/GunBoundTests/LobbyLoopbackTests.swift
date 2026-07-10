import Foundation
import Testing
@testable import GunBound
@testable import GunBoundProtocol

/// End-to-end loopback: a real `GunBoundServer` on 127.0.0.1 and a real
/// `NetworkClient` over actual TCP sockets — no mocks. Exercises the whole
/// new stack together: login handshake, confirm-connect, the background
/// packet pump, room create, and the server's `0x3105` room-update push
/// arriving on `pushes` (the live-lobby refresh signal).
///
/// Serialized and time-limited: real sockets, and a hang here should fail
/// fast instead of wedging the suite.
@Suite(.serialized, .timeLimit(.minutes(1)))
struct LobbyLoopbackTests {

    /// Starts an in-process world server on an ephemeral loopback port with
    /// the standard admin user (same seeding as the `GunBoundServer world`
    /// executable) plus a plain guest account for two-client tests.
    private static func startServer() async throws -> (server: GunBoundServer<GunBoundSocketIPv4TCP, GunBoundSocketIPv4UDP, InMemoryGunBoundServerDataSource>, port: UInt16) {
        let dataSource = InMemoryGunBoundServerDataSource()
        await dataSource.update {
            $0.passwords["admin"] = "1234"
            $0.users["admin"] = User(id: "admin", isBanned: false, rank: .administrator, gold: 0, cash: 0)
            $0.passwords["guest"] = "1234"
            $0.users["guest"] = User(id: "guest", isBanned: false, rank: .chick, gold: 0, cash: 0)
        }
        // Ephemeral port, retrying a few times in case of a collision.
        var lastError: Swift.Error?
        for _ in 0..<5 {
            let port = UInt16.random(in: 20_000...60_000)
            guard let address = GunBound.GunBoundAddress(address: "127.0.0.1", port: port) else { continue }
            do {
                let server = try await GunBoundServer(
                    configuration: GunBoundServerConfiguration(address: address, backlog: 8),
                    dataSource: dataSource,
                    socket: (GunBoundSocketIPv4TCP.self, GunBoundSocketIPv4UDP.self)
                )
                return (server, port)
            } catch {
                lastError = error
            }
        }
        throw lastError ?? GunBoundDecodingError.invalidPacket
    }

    /// login → join channel → create room → the server's room-update push
    /// (`0x3105`) arrives on the client's push stream, and the refreshed
    /// room list contains the created room.
    @Test func createRoomEmitsARoomUpdatePush() async throws {
        let (server, port) = try await Self.startServer()
        defer { withExtendedLifetime(server) {} }

        let config = NetworkConfig(
            username: "admin", password: "1234",
            serverAddress: "127.0.0.1", serverPort: port, brokerPort: port
        )
        let client = try await NetworkClient<GunBoundSocketIPv4TCP>.connect(config)
        defer { Task { await client.close() } }

        // Full login handshake over real sockets.
        let auth = try await client.authenticate(username: "admin", password: "1234")
        #expect(auth.status == .success)

        let channel = try await client.joinChannel()
        #expect(channel.isSuccess)

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
    }

    /// Channel chat round-trip over real sockets: the encrypted `0x2010`
    /// command goes out, the server broadcasts the (also encrypted) `0x201F`
    /// back to the channel, and the pump decrypts + decodes it into a typed
    /// push — AES exercised in both directions with the session key.
    @Test func chatRoundTripsEncrypted() async throws {
        let (server, port) = try await Self.startServer()
        defer { withExtendedLifetime(server) {} }

        let config = NetworkConfig(
            username: "admin", password: "1234",
            serverAddress: "127.0.0.1", serverPort: port, brokerPort: port
        )
        let client = try await NetworkClient<GunBoundSocketIPv4TCP>.connect(config)
        defer { Task { await client.close() } }

        let auth = try await client.authenticate(username: "admin", password: "1234")
        #expect(auth.status == .success)
        let channel = try await client.joinChannel()
        #expect(channel.isSuccess)

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
    }

    /// The full Ready Room flow with two real clients: the host creates a
    /// room, a guest joins, picks a mobile (`0x3200`), switches to team B
    /// (`0x3210`), readies up (`0x3230`), and the host starts (`0x3430`) —
    /// then **both** clients receive the encrypted `0x3432` start push with
    /// the map and spawn data.
    @Test func twoClientReadyRoomFlowStartsTheGame() async throws {
        let (server, port) = try await Self.startServer()
        defer { withExtendedLifetime(server) {} }

        func connect(_ username: String) async throws -> NetworkClient<GunBoundSocketIPv4TCP> {
            let client = try await NetworkClient<GunBoundSocketIPv4TCP>.connect(NetworkConfig(
                username: username, password: "1234",
                serverAddress: "127.0.0.1", serverPort: port, brokerPort: port
            ))
            let auth = try await client.authenticate(username: username, password: "1234")
            #expect(auth.status == .success, "\(username)")
            let channel = try await client.joinChannel()
            #expect(channel.isSuccess, "\(username)")
            return client
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
    }

    /// The periodic keepalive (`0x0000`): a client on a fast cadence rides
    /// several intervals and the connection stays healthy — the server
    /// accepts each heartbeat rather than dropping the session on an
    /// unexpected packet.
    @Test func keepAliveHeartbeatsFlowPeriodically() async throws {
        let (server, port) = try await Self.startServer()
        defer { withExtendedLifetime(server) {} }

        let config = NetworkConfig(
            username: "admin", password: "1234",
            serverAddress: "127.0.0.1", serverPort: port, brokerPort: port
        )
        let client = try await NetworkClient<GunBoundSocketIPv4TCP>.connect(
            config,
            keepAliveInterval: .milliseconds(50)
        )
        defer { Task { await client.close() } }

        let auth = try await client.authenticate(username: "admin", password: "1234")
        #expect(auth.status == .success)

        // Let a handful of heartbeats go out, then prove the session still
        // works end to end (a dropped/errored connection would fail here).
        try await Task.sleep(for: .milliseconds(400))
        let channel = try await client.joinChannel()
        #expect(channel.isSuccess)
        try await Task.sleep(for: .milliseconds(200))
        _ = try await client.fetchRoomList()
    }

    /// The buddy list end to end (our own convention — see `BuddyEntry`'s
    /// type-level note): an empty roster fetches clean, adding a connected
    /// username reports it online in the refreshed push, and removing it
    /// clears the roster again.
    @Test func buddyListAddRemoveReflectsOnlineStatus() async throws {
        let (server, port) = try await Self.startServer()
        defer { withExtendedLifetime(server) {} }

        func connect(_ username: String) async throws -> NetworkClient<GunBoundSocketIPv4TCP> {
            let client = try await NetworkClient<GunBoundSocketIPv4TCP>.connect(NetworkConfig(
                username: username, password: "1234",
                serverAddress: "127.0.0.1", serverPort: port, brokerPort: port
            ))
            let auth = try await client.authenticate(username: username, password: "1234")
            #expect(auth.status == .success, "\(username)")
            let channel = try await client.joinChannel()
            #expect(channel.isSuccess, "\(username)")
            return client
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
    }
}
