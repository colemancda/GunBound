import Foundation
import Testing
@testable import GunBound
@testable import GunBoundProtocol

/// Wire-format tests for the packets introduced or reshaped by the
/// reference-emulator alignment work: the in-game tunnel pair, the room
/// leave/host-migration notifications, the death/game-end announcements,
/// join-room error returns, and room-list pagination.
@Suite struct ServerFixPacketTests {

    // MARK: - Tunnel

    @Test func tunnelRoundtrip() {
        let value = Tunnel(value0: 0x1234, destinationSlot: 3, payload: [0xAA, 0xBB, 0xCC])
        #expect(Tunnel.opcode == .tunnel)
        #expect(Tunnel.opcode.rawValue == 0x4500)
        #expect(Tunnel.opcode.type == .command)
        let packet = Packet(
            opcode: .tunnel,
            id: 0x0000,
            parameters: [0x34, 0x12, 0x03, 0xAA, 0xBB, 0xCC]
        )
        assertEncodeDecrypted(value, packet)
        assertDecodeDecrypted(value, packet)
    }

    @Test func tunnelForwardRoundtrip() {
        let value = TunnelForward(sourceSlot: 1, payload: [0xDE, 0xAD])
        #expect(TunnelForward.opcode == .tunnelForward)
        #expect(TunnelForward.opcode.rawValue == 0x4501)
        #expect(TunnelForward.opcode.type == .notification)
        let packet = Packet(
            opcode: .tunnelForward,
            id: 0x0000,
            parameters: [0x01, 0xDE, 0xAD]
        )
        assertEncodeDecrypted(value, packet)
        assertDecodeDecrypted(value, packet)
    }

    // MARK: - Room leave lifecycle

    @Test func userQuitNotificationCarriesTheVacatedSlot() {
        let value = UserQuitNotification(slot: 2)
        #expect(UserQuitNotification.opcode.rawValue == 0x3020)
        #expect(UserQuitNotification.opcode.type == .notification)
        let packet = Packet(
            opcode: .userQuitNotification,
            id: 0x0000,
            parameters: [0x02, 0x00]
        )
        assertEncodeDecrypted(value, packet)
        assertDecodeDecrypted(value, packet)
    }

    @Test func hostMigrationRoundtrip() {
        let value = HostMigrationNotification(
            masterSlot: 1,
            name: "test",
            map: .metropolis,
            settings: 0xB262_0000,
            capacity: ._2_2
        )
        #expect(HostMigrationNotification.opcode.rawValue == 0x3400)
        #expect(HostMigrationNotification.opcode.type == .notification)
        let packet = Packet(
            opcode: .hostMigrationNotification,
            id: 0x0000,
            parameters: [
                0x01,  // new master slot
                0x04, 0x74, 0x65, 0x73, 0x74,  // "test"
                0x03,  // metropolis
                0x00, 0x00, 0x62, 0xB2,  // settings LE
                0xFF, 0xFF, 0xFF, 0xFF,  // item state
                0xFF, 0xFF, 0xFF, 0xFF,  // reserved
                0x04,  // capacity 2:2
            ]
        )
        assertEncodeDecrypted(value, packet)
        assertDecodeDecrypted(value, packet)
    }

    // MARK: - Death / game end

    @Test func playerDeadNotificationIsOneCipherBlock() {
        let value = PlayerDeadNotification(slot: 1, team: .b)
        #expect(PlayerDeadNotification.opcode.rawValue == 0x4102)
        #expect(PlayerDeadNotification.opcode.type == .notification)
        #expect(PlayerDeadNotification.opcode.isEncrypted)
        let packet = Packet(
            opcode: .playerDeadNotification,
            id: 0x0000,
            parameters: [0x01] + PlayerDeadNotification.reservedBytes + [0x01]
        )
        #expect(packet.parametersSize == 12)
        assertEncodeDecrypted(value, packet)
        assertDecodeDecrypted(value, packet)
    }

    @Test func gameEndNotificationAnnouncesTheWinner() {
        let value = GameEndNotification(winner: .a)
        #expect(GameEndNotification.opcode.rawValue == 0x4410)
        #expect(GameEndNotification.opcode.type == .notification)
        #expect(GameEndNotification.opcode.isEncrypted)
        #expect(value.winner == .a)
        #expect(value.payload.count == 12)
        let packet = Packet(
            opcode: .gameEndNotification,
            id: 0x0000,
            parameters: [0x00] + [UInt8](repeating: 0, count: 11)
        )
        assertEncodeDecrypted(value, packet)
        assertDecodeDecrypted(value, packet)
        // jewel mode relays an arbitrary client payload instead
        let relayed = GameEndNotification(payload: [0x01, 0x99])
        #expect(relayed.winner == .b)
    }

    @Test func endGameJewelRelaysItsPayload() {
        let value = EndGameJewelCommand(payload: [0x01, 0x02, 0x03])
        let packet = Packet(
            opcode: .endGameJewelCommand,
            id: 0x0000,
            parameters: [0x01, 0x02, 0x03]
        )
        assertEncodeDecrypted(value, packet)
        assertDecodeDecrypted(value, packet)
    }

    // MARK: - Game results

    @Test func gameResultRoundtrip() {
        let value = GameResultCommand(results: [
            .init(slot: 0, gold: 100, bonusGold: 20, gp: 30, bonusGP: 5),
            .init(slot: 1, gold: 50, gp: 10),
        ])
        var encoder = GunBoundEncoder()
        let packet = encoder.encode(value, id: 0x0000)
        var decoder = GunBoundDecoder()
        let decoded = try? decoder.decodePacket(GameResultCommand.self, from: packet.data)
        #expect(decoded == value)
    }

    @Test func emptyGameResultDecodesAsZeroResults() {
        let packet = Packet(opcode: .playResultCommand, id: 0x0000, parameters: [])
        var decoder = GunBoundDecoder()
        let decoded = try? decoder.decodePacket(GameResultCommand.self, from: packet.data)
        #expect(decoded == GameResultCommand())
    }

    // MARK: - Join room errors

    @Test func joinRoomErrorEncodesOnlyTheReturnCode() {
        let badRoom = JoinRoomResponse.error(JoinRoomResponse.errorBadRoom)
        #expect(badRoom.isSuccess == false)
        let badRoomPacket = Packet(
            opcode: .joinRoomResponse,
            id: 0x0000,
            parameters: [0x11, 0x00]
        )
        assertEncodeDecrypted(badRoom, badRoomPacket)
        assertDecodeDecrypted(badRoom, badRoomPacket)

        let full = JoinRoomResponse.error(JoinRoomResponse.errorRoomFull)
        #expect(full.isSuccess == false)
        let fullPacket = Packet(
            opcode: .joinRoomResponse,
            id: 0x0000,
            parameters: [0x01, 0x20]
        )
        assertEncodeDecrypted(full, fullPacket)
        assertDecodeDecrypted(full, fullPacket)
    }

    @Test func joinRoomSuccessCarriesMasterAndOwnSlots() {
        let value = JoinRoomResponse(
            rtc: 0x0000,
            masterSlot: 0,
            slot: 2,
            room: 5,
            name: "r",
            map: .random,
            settings: 0,
            capacity: ._2_2,
            players: []
        )
        var encoder = GunBoundEncoder()
        let packet = encoder.encode(value, id: 0x0000)
        // rtc(2) + masterSlot(1) + slot(1)
        #expect(Array(packet.parameters.prefix(4)) == [0x00, 0x00, 0x00, 0x02])
        var decoder = GunBoundDecoder()
        let decoded = try? decoder.decodePacket(JoinRoomResponse.self, from: packet.data)
        #expect(decoded?.masterSlot == 0)
        #expect(decoded?.slot == 2)
        #expect(decoded?.isSuccess == true)
    }

    // MARK: - Room list pagination

    @Test func roomListRequestPaginationRoundtrip() {
        let paged = RoomListRequest(filter: .waiting, startIndex: 6)
        let pagedPacket = Packet(
            opcode: .roomListRequest,
            id: 0x0000,
            parameters: [0x02, 0x06]
        )
        assertEncodeDecrypted(paged, pagedPacket)
        assertDecodeDecrypted(paged, pagedPacket)

        // a bare filter (no trailing byte) still decodes, unpaginated
        let bare = RoomListRequest(filter: .all)
        let barePacket = Packet(
            opcode: .roomListRequest,
            id: 0x0000,
            parameters: [0x01]
        )
        assertEncodeDecrypted(bare, barePacket)
        assertDecodeDecrypted(bare, barePacket)
    }

    // MARK: - Cash update request

    @Test func cashUpdateRequestOpcode() {
        #expect(CashUpdateRequest.opcode.rawValue == 0x6100)
        #expect(CashUpdateRequest.opcode.type == .command)
        let packet = Packet(opcode: .cashUpdateRequest, id: 0x0000, parameters: [])
        assertDecodeDecrypted(CashUpdateRequest(), packet)
    }

    // MARK: - Room model

    @Test func winningTeamFollowsAlivePlayers() {
        var room = Room(
            id: 1,
            channel: 0,
            name: "r",
            password: "",
            map: .random,
            settings: 0,
            capacity: ._2_2,
            isPlaying: true,
            players: [
                .init(id: 0, username: "a", address: GunBoundAddress(rawValue: "127.0.0.1:8363")!, primaryTank: .random, secondaryTank: .random, team: .a, status: .alive, isAdmin: true),
                .init(id: 1, username: "b", address: GunBoundAddress(rawValue: "127.0.0.1:8364")!, primaryTank: .random, secondaryTank: .random, team: .b, status: .alive, isAdmin: false),
            ],
            message: ""
        )
        #expect(room.winningTeam == nil)
        room.players[1].status = .dead
        #expect(room.winningTeam == .a)
        room.players[1].status = .alive
        room.players[0].status = .dead
        #expect(room.winningTeam == .b)
    }

    @Test func winningTeamFollowsScoreModeLives() {
        var room = Room(
            id: 1,
            channel: 0,
            name: "r",
            password: "",
            map: .random,
            settings: 0x0044_0000,  // score mode in the upper 16 bits
            capacity: ._2_2,
            isPlaying: true,
            players: [
                .init(id: 0, username: "a", address: GunBoundAddress(rawValue: "127.0.0.1:8363")!, primaryTank: .random, secondaryTank: .random, team: .a, status: .alive, isAdmin: true),
                .init(id: 1, username: "b", address: GunBoundAddress(rawValue: "127.0.0.1:8364")!, primaryTank: .random, secondaryTank: .random, team: .b, status: .alive, isAdmin: false),
            ],
            message: ""
        )
        #expect(room.gameMode == .score)
        room.score = Room.TeamScore(a: 1, b: 0)
        #expect(room.winningTeam == .a)
        room.score = Room.TeamScore(a: 0, b: 1)
        #expect(room.winningTeam == .b)
        // both teams still have lives and alive players: no winner yet
        room.score = Room.TeamScore(a: 1, b: 1)
        #expect(room.winningTeam == nil)
    }

    @Test func electNewMasterPicksTheLowestSlot() {
        var room = Room(
            id: 1,
            channel: 0,
            name: "r",
            password: "",
            map: .random,
            settings: 0,
            capacity: ._2_2,
            isPlaying: false,
            players: [
                .init(id: 3, username: "c", address: GunBoundAddress(rawValue: "127.0.0.1:8365")!, primaryTank: .random, secondaryTank: .random, team: .b, status: .waiting, isAdmin: false),
                .init(id: 1, username: "b", address: GunBoundAddress(rawValue: "127.0.0.1:8364")!, primaryTank: .random, secondaryTank: .random, team: .a, status: .waiting, isAdmin: false),
            ],
            message: ""
        )
        #expect(room.master == nil)
        let newMaster = room.electNewMaster()
        #expect(newMaster == 1)
        #expect(room.master?.username == "b")
    }
}
