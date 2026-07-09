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
    /// executable).
    private static func startServer() async throws -> (server: GunBoundServer<GunBoundSocketIPv4TCP, GunBoundSocketIPv4UDP, InMemoryGunBoundServerDataSource>, port: UInt16) {
        let dataSource = InMemoryGunBoundServerDataSource()
        await dataSource.update {
            $0.passwords["admin"] = "1234"
            $0.users["admin"] = User(id: "admin", isBanned: false, rank: .administrator, gold: 0, cash: 0)
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
}
