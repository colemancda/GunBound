import Foundation
import Testing
@testable import GunBound
@testable import GunBoundProtocol

/// Shared harness for view-model networking tests: an in-memory
/// `GunBoundServer` plus a connected, authenticated `NetworkClient` that can
/// be injected into a `MockViewModelDelegate.client`, so the view models'
/// networking Task bodies run against a real server over the deterministic
/// in-memory socket.
enum TestServer {

    typealias Server = GunBoundServer<InMemoryTCPSocket, InMemoryUDPSocket, InMemoryGunBoundServerDataSource>

    /// Starts a world server seeded with `admin`/`guest`/`extra` accounts on
    /// an in-memory port.
    static func start() async throws -> (server: Server, port: UInt16) {
        let dataSource = InMemoryGunBoundServerDataSource()
        await dataSource.update {
            for name in ["admin", "guest", "extra"] {
                $0.passwords[name] = "1234"
                $0.users[Username(rawValue: name)!] = User(
                    id: Username(rawValue: name)!,
                    isBanned: false,
                    rank: name == "admin" ? .administrator : .chick,
                    gold: 0,
                    cash: 0
                )
            }
        }
        var lastError: Swift.Error?
        for _ in 0..<5 {
            let port = UInt16.random(in: 20_000...60_000)
            guard let address = GunBound.GunBoundAddress(address: "127.0.0.1", port: port) else { continue }
            do {
                let server = try await GunBoundServer(
                    configuration: GunBoundServerConfiguration(address: address, backlog: 8),
                    dataSource: dataSource,
                    socket: (InMemoryTCPSocket.self, InMemoryUDPSocket.self)
                )
                return (server, port)
            } catch {
                lastError = error
            }
        }
        throw lastError ?? GunBoundDecodingError.invalidPacket
    }

    /// Connects a client for `username`, logs it in, and joins the lobby
    /// channel — the state a view model reached from Server Select would be in.
    static func connect(_ username: String, port: UInt16) async throws -> NetworkClient<InMemoryTCPSocket> {
        let client = try await NetworkClient<InMemoryTCPSocket>.connect(
            NetworkConfig(
                username: username, password: "1234",
                serverAddress: "127.0.0.1", serverPort: port, brokerPort: port
            ),
            requestTimeout: .seconds(30)
        )
        _ = try await client.authenticate(username: username, password: "1234")
        _ = try await client.joinChannel()
        return client
    }

    /// A `MockViewModelDelegate` wired to a live in-memory client, plus the
    /// server keeping the connection alive for the test's duration.
    @MainActor
    static func delegate(_ username: String = "admin") async throws -> (
        delegate: MockViewModelDelegate,
        server: Server
    ) {
        let (server, port) = try await start()
        let client = try await connect(username, port: port)
        let network = NetworkConfig(
            username: username, password: "1234",
            serverAddress: "127.0.0.1", serverPort: port, brokerPort: port
        )
        let delegate = MockViewModelDelegate(network: network)
        delegate.client = client
        return (delegate, server)
    }

    /// Creates a room through `delegate.client`, joins it, and records it as
    /// the session's current room — the state a Ready Room view model expects.
    /// Returns the room id so a second client can join the same room.
    @MainActor
    @discardableResult
    static func enterRoom(_ delegate: MockViewModelDelegate, name: String = "room") async throws -> RoomID {
        let client = try #require(delegate.client)
        let created = try await client.createRoom(name: name, password: "", capacity: ._4_4)
        let joined = try await client.joinRoom(created.room)
        delegate.session.currentRoom = joined
        return created.room
    }

    /// Joins `delegate.client` into an existing room and records it as the
    /// session's current room (a non-host player).
    @MainActor
    static func joinRoom(_ delegate: MockViewModelDelegate, id: RoomID) async throws {
        let client = try #require(delegate.client)
        delegate.session.currentRoom = try await client.joinRoom(id)
    }

    /// Polls `condition` in real time until it holds or ~5s elapse, so a view
    /// model's fire-and-forget networking Task (and the server's async
    /// processing behind it) has wall-clock time to complete. Returns whether
    /// the condition became true (the caller asserts on it).
    @MainActor
    @discardableResult
    static func wait(for condition: @MainActor () -> Bool) async -> Bool {
        for _ in 0..<500 {
            if condition() { return true }
            try? await Task.sleep(nanoseconds: 10_000_000)  // 10ms
        }
        return condition()
    }
}
