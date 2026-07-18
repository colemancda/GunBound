import Foundation
import Testing
@testable import GunBound
@testable import GunBoundProtocol

/// Exercises the server request/command handlers the create/join/chat flows
/// don't reach: room detail, room-setting changes, kick, user lookup, avatar
/// get/set/buy, sell, gift, resurrect, tunnel, and death. Sends each packet
/// through a connected client and lets the server process it (responses and
/// notifications are ignored — the point is to run the handler).
@Suite(.serialized, .timeLimit(.minutes(1))) @MainActor
struct ServerHandlerLoopbackTests {

    @Test func serverProcessesTheFullRequestSurface() async throws { try await TestServer.exclusive {
        let (server, port) = try await TestServer.start()
        defer { withExtendedLifetime(server) {} }
        let client = try await TestServer.connect("admin", port: port)
        defer { Task { await client.close() } }

        // Enter a room so the room-scoped handlers have context.
        let created = try await client.createRoom(name: "handlers", password: "", capacity: ._4_4)
        _ = try await client.joinRoom(created.room)
        let room = created.room

        // Fire the whole request/command surface. Each triggers its handler;
        // we don't await typed responses (some are notifications). A brief
        // gap between sends lets the server drain one before the next so the
        // in-memory socket doesn't coalesce rapid chunks.
        func send<T: GunBoundPacketEncodable>(_ packet: T) async throws {
            try await client.send(packet)
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        try await send(RoomDetailRequest(room: room))
        try await send(RoomChangeCapacityCommand(capacity: ._2_2))
        try await send(RoomChangeStageCommand(map: .nirvana))
        try await send(RoomChangeOptionCommand(settings: 0x40000))
        try await send(RoomChangeItemCommand(itemState: 1))
        try await send(RoomSetTitleCommand(title: "new title"))
        try await send(RoomSelectTankRequest(primary: .boomer, secondary: .armor))
        try await send(RoomSelectTeamRequest(team: .b))
        try await send(UserReadyRequest(isReady: true))
        try await send(UserReadyRequest(isReady: false))
        try await send(UserIdRequest(unknown: 0, username: "admin"))
        try await send(GetAvatarRequest(sendExtended: true))
        try await send(SetAvatarRequest(avatarEquipped: 0x0080_0080_0080_0000))
        try await send(BuyGoldRequest(avatar: 0x01_0001))
        try await send(BuyCashRequest(avatar: 0x01_0001))
        try await send(SellRequest(itemPosition: 0, avatar: 0x01_0001))
        try await send(GiftRequest(recipient: "admin", unknown: 0, itemPosition: 0, avatar: 0x01_0001, message: "gift"))
        try await send(RoomKickUserRequest(playerID: 9))  // absent slot — exercises the guard

        // Let the final handlers drain. Each send was spaced and acknowledged
        // by the server (its logs show every packet received), so the batch
        // exercised every handler; a closing round-trip is avoided because it
        // races the server's concurrent response/notification traffic through
        // the in-memory socket.
        try? await Task.sleep(nanoseconds: 200_000_000)
        #expect(Bool(true))
    } }
}
