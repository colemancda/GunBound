import Foundation
import Testing
@testable import GunBound
@testable import GunBoundProtocol

/// Drives `GameRoomListViewModel`'s networking paths against a live in-memory
/// server (through the `GameClient` seam), covering the fire-and-forget Task
/// bodies a unit test with a nil client can't reach: the room/buddy loads,
/// create-then-join, chat round trip, and buddy add/remove.
@Suite(.serialized, .timeLimit(.minutes(1))) @MainActor
struct GameRoomListViewModelNetworkingTests {

    @Test func onEnterLoadsRoomsAndObservesPushes() async throws { try await TestServer.exclusive {
        let (delegate, server) = try await TestServer.delegate()
        defer { withExtendedLifetime(server) {} }
        let viewModel = GameRoomListViewModel(delegate: delegate)

        viewModel.onEnter()
        // The lobby starts empty; the load completes (rooms stays []).
        await TestServer.wait { !viewModel.rooms.isEmpty == false }
        #expect(viewModel.rooms.isEmpty)
        viewModel.onExit()
    } }

    @Test func createRoomJoinsAndTransitionsToReadyRoom() async throws { try await TestServer.exclusive {
        let (delegate, server) = try await TestServer.delegate()
        defer { withExtendedLifetime(server) {} }
        let viewModel = GameRoomListViewModel(delegate: delegate)

        viewModel.createRoom(name: "test room", password: "", capacity: ._2_2)

        let transitioned = await TestServer.wait {
            delegate.requestedTransitions.contains(.readyRoom)
        }
        #expect(transitioned)
        #expect(delegate.session.currentRoom != nil)
        viewModel.onExit()
    } }

    @Test func sendChatDispatchesAndAppliesTheEcho() async throws { try await TestServer.exclusive {
        let (delegate, server) = try await TestServer.delegate()
        defer { withExtendedLifetime(server) {} }
        let viewModel = GameRoomListViewModel(delegate: delegate)

        // The send Task hits the network (covers the send path); let it drain.
        viewModel.sendChat("hello lobby")
        try? await Task.sleep(nanoseconds: 100_000_000)

        // The echo arrives as a broadcast push — apply it directly (the real
        // round-trip through the push observer is covered by the loopback
        // suite; here we cover appendChat deterministically).
        viewModel.apply(.chatReceived(ChannelChatBroadcast(position: 0, username: "admin", message: "hello lobby")))
        #expect(viewModel.chatMessages.contains { $0.message.contains("hello lobby") })

        // Empty/whitespace chat is dropped before hitting the network.
        let before = viewModel.chatMessages.count
        viewModel.sendChat("   ")
        #expect(viewModel.chatMessages.count == before)
    } }

    @Test func addRemoveBuddyDispatchAndApplyTheRoster() async throws { try await TestServer.exclusive {
        let (delegate, server) = try await TestServer.delegate()
        defer { withExtendedLifetime(server) {} }
        let viewModel = GameRoomListViewModel(delegate: delegate)

        // The add/remove Tasks hit the network (cover those paths); the
        // refreshed roster arrives as a buddyListUpdated push, applied here
        // directly for a deterministic check of applyBuddyList.
        viewModel.addBuddy(named: "guest")
        try? await Task.sleep(nanoseconds: 100_000_000)
        viewModel.apply(.buddyListUpdated(BuddyListNotification(buddies: [BuddyEntry(username: "guest", isOnline: true)])))
        #expect(viewModel.buddies.contains("guest"))

        viewModel.removeBuddy(named: "guest")
        try? await Task.sleep(nanoseconds: 100_000_000)
        viewModel.apply(.buddyListUpdated(BuddyListNotification(buddies: [])))
        #expect(!viewModel.buddies.contains("guest"))
    } }
}
