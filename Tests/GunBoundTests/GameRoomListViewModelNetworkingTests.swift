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

    @Test func sendChatEchoesBackAsAMessage() async throws { try await TestServer.exclusive {
        let (delegate, server) = try await TestServer.delegate()
        defer { withExtendedLifetime(server) {} }
        let viewModel = GameRoomListViewModel(delegate: delegate)
        viewModel.onEnter()

        viewModel.sendChat("hello lobby")
        let echoed = await TestServer.wait {
            viewModel.chatMessages.contains { $0.message.contains("hello lobby") }
        }
        #expect(echoed)

        // Empty/whitespace chat is dropped before hitting the network.
        let before = viewModel.chatMessages.count
        viewModel.sendChat("   ")
        #expect(viewModel.chatMessages.count == before)
        viewModel.onExit()
    } }

    @Test func addAndRemoveBuddyUpdateTheRosterFromPushes() async throws { try await TestServer.exclusive {
        let (delegate, server) = try await TestServer.delegate()
        defer { withExtendedLifetime(server) {} }
        let viewModel = GameRoomListViewModel(delegate: delegate)
        viewModel.onEnter()

        viewModel.addBuddy(named: "guest")
        let added = await TestServer.wait { viewModel.buddies.contains("guest") }
        #expect(added)

        viewModel.removeBuddy(named: "guest")
        let removed = await TestServer.wait { !viewModel.buddies.contains("guest") }
        #expect(removed)
        viewModel.onExit()
    } }
}
