import Foundation
import Testing
@testable import GunBound
@testable import GunBoundProtocol

/// End-to-end coverage for the room lifecycle work: join-room error returns,
/// the in-game tunnel relay, room-wide update broadcasts, master-only guards,
/// the death → winner flow, and the leave/host-migration notifications. Real
/// `GunBoundServer` + `NetworkClient` wired through an in-memory socket
/// (`InMemoryTCPSocket`), like `LobbyLoopbackTests`.
///
/// One sequential scenario over long-lived connections: the in-memory socket
/// removes the fd-reuse/lost-wakeup races that made the real-socket version
/// flaky, but the single-server, strictly-sequential shape is kept as it
/// mirrors the real client's traffic pattern.
@Suite(.serialized, .timeLimit(.minutes(2)))
struct RoomLifecycleLoopbackTests {

    private static func startServer() async throws -> (server: GunBoundServer<InMemoryTCPSocket, InMemoryUDPSocket, InMemoryGunBoundServerDataSource>, port: UInt16) {
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
        let port = await InMemoryTCPRegistry.shared.uniqueServerPort()
        let address = GunBound.GunBoundAddress(address: "127.0.0.1", port: port)!
        let server = try await GunBoundServer(
            configuration: GunBoundServerConfiguration(address: address, backlog: 8),
            dataSource: dataSource,
            socket: (InMemoryTCPSocket.self, InMemoryUDPSocket.self)
        )
        return (server, port)
    }

    private static func connect(_ username: String, port: UInt16) async throws -> NetworkClient<InMemoryTCPSocket> {
        try await TestServer.connect(username, port: port)
    }

    /// One 1:1 room, lived in from creation to host migration:
    /// 1. join errors — wrong password, unknown room, and a full room are
    ///    answered with error return codes and the connection survives
    /// 2. the join response carries the master's and the joiner's slots
    /// 3. tunnel traffic is relayed to the addressed slot with the sender's
    ///    slot in front
    /// 4. only the master's map change is applied, and the room-update push
    ///    reaches the other player
    /// 5. only the master can start the game; the death of team B's only
    ///    player announces the death and the winner to the room and returns
    ///    the room to the waiting state
    /// 6. the master disconnecting hands the seat to the lowest occupied
    ///    slot and notifies the survivors
    @Test func roomLifecycleEndToEnd() async throws { try await TestServer.exclusive {
        let (server, port) = try await Self.startServer()
        defer { withExtendedLifetime(server) {} }

        let host = try await Self.connect("admin", port: port)
        let guest = try await Self.connect("guest", port: port)
        let extra = try await Self.connect("extra", port: port)

        // 1:1 room: capacity 2, so a third join must be rejected as full
        let created = try await host.createRoom(name: "lifecycle", password: "abcd", capacity: ._1_1)
        let hostJoin = try await host.joinRoom(created.room, password: "abcd")
        #expect(hostJoin.isSuccess)
        #expect(hostJoin.masterSlot == 0)
        #expect(hostJoin.slot == 0)

        // — join errors keep the connection usable —
        let wrongPassword = try await guest.joinRoom(created.room, password: "nope")
        #expect(wrongPassword.isSuccess == false)
        let unknownRoom = try await guest.joinRoom(9999)
        #expect(unknownRoom.isSuccess == false)
        let listAfterRejects = try await guest.fetchRoomList()
        #expect(listAfterRejects.contains { $0.id == created.room })

        let guestJoin = try await guest.joinRoom(created.room, password: "abcd")
        #expect(guestJoin.isSuccess)
        #expect(guestJoin.masterSlot == 0)
        #expect(guestJoin.slot == 1)

        // — the room is now at capacity: a third player is turned away —
        let rejected = try await extra.joinRoom(created.room, password: "abcd")
        #expect(rejected.isSuccess == false)

        // — tunnel relay: guest (slot 1) → host (slot 0) —
        try await guest.sendTunnel(to: hostJoin.slot, payload: [0xAA, 0xBB, 0xCC])
        var forward: TunnelForward?
        for await push in await host.pushes {
            if case .tunnelReceived(let value) = push {
                forward = value
                break
            }
        }
        #expect(forward?.sourceSlot == guestJoin.slot)
        #expect(forward?.payload == [0xAA, 0xBB, 0xCC])

        // — master-only room changes, broadcast to the whole room —
        // the guest's attempt must be ignored; the master's applies
        try await guest.send(RoomChangeStageCommand(map: .dragon))
        try await Task.sleep(for: .milliseconds(300))
        try await host.send(RoomChangeStageCommand(map: .metropolis))

        // earlier buffered 0x3105 pushes (e.g. from room creation) may
        // arrive first: keep consuming update pushes until the list shows
        // the master's map, bounded by a handful of attempts
        var observedMap: GameMap?
        for _ in 0..<10 {
            var sawUpdate = false
            for await push in await guest.pushes {
                if case .roomUpdated = push {
                    sawUpdate = true
                    break
                }
            }
            guard sawUpdate else { break }
            let rooms = try await guest.fetchRoomList()
            observedMap = rooms.first { $0.id == created.room }?.map
            if observedMap == .metropolis { break }
        }
        #expect(observedMap == .metropolis)

        // — only the master starts the game —
        _ = try await guest.selectTeam(.b)
        #expect(try await guest.setReady(true).isSuccess)
        try await guest.startGame()
        try await Task.sleep(for: .milliseconds(300))
        let beforeStart = try await host.fetchRoomList()
        #expect(beforeStart.first { $0.id == created.room }?.isPlaying == false)

        try await host.startGame()
        for await push in await guest.pushes {
            if case .gameStarted = push { break }
        }

        // — death flow: team B's only player dies, team A wins —
        try await guest.send(UserDeathRequest())
        var death: PlayerDeadNotification?
        var end: GameEndNotification?
        for await push in await guest.pushes {
            if case .playerDied(let value) = push {
                death = value
            }
            if case .gameEnded(let value) = push {
                end = value
            }
            if death != nil && end != nil {
                break
            }
        }
        #expect(death?.slot == guestJoin.slot)
        #expect(death?.team == .b)
        #expect(end?.winner == .a)

        let afterGame = try await host.fetchRoomList()
        #expect(afterGame.first { $0.id == created.room }?.isPlaying == false)

        // — host migration: the master leaves, the guest inherits the seat —
        await host.close()
        var quit: UserQuitNotification?
        var migration: HostMigrationNotification?
        for await push in await guest.pushes {
            if case .userQuit(let value) = push {
                quit = value
            }
            if case .hostMigrated(let value) = push {
                migration = value
            }
            if quit != nil && migration != nil {
                break
            }
        }
        #expect(quit?.slot == UInt16(hostJoin.slot))
        #expect(migration?.masterSlot == guestJoin.slot)
        #expect(migration?.name == "lifecycle")

        await guest.close()
        await extra.close()
    } }
}
