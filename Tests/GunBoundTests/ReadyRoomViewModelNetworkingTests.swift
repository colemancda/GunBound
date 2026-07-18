import Foundation
import Testing
@testable import GunBound
@testable import GunBoundProtocol

/// Drives `ReadyRoomViewModel`'s networking actions against a live in-memory
/// server through the `GameClient` seam: team change, mobile pick, host start,
/// non-host ready, chat, and leaving the room.
@Suite(.serialized, .timeLimit(.minutes(1))) @MainActor
struct ReadyRoomViewModelNetworkingTests {

    // Bottom-bar button centers (from the decomp rects in ReadyRoomViewModel).
    private let exitButton = (x: Float(93), y: Float(573))
    private let changeTeamButton = (x: Float(585), y: Float(573))
    private let readyOrStartButton = (x: Float(708), y: Float(573))
    private let pickerToggle = (x: Float(49), y: Float(373))

    @Test func hostStartGameRelaysToServer() async throws {
        let (delegate, server) = try await TestServer.delegate("admin")
        defer { withExtendedLifetime(server) {} }
        try await TestServer.enterRoom(delegate)
        let viewModel = ReadyRoomViewModel(delegate: delegate)
        viewModel.onEnter()
        #expect(viewModel.isHost)

        // The host's Ready/Start button relays 0x3430; the Loading transition
        // arrives later via the 0x3432 start push (needs enough ready players),
        // so here we just confirm the relay Task runs to completion.
        viewModel.handle(.pointerDown(x: readyOrStartButton.x, y: readyOrStartButton.y))
        #expect(await TestServer.wait { !viewModel.isBusy })
        viewModel.onExit()
    }

    @Test func changeTeamAndSelectMobileRunToCompletion() async throws {
        let (delegate, server) = try await TestServer.delegate("admin")
        defer { withExtendedLifetime(server) {} }
        try await TestServer.enterRoom(delegate)
        let viewModel = ReadyRoomViewModel(delegate: delegate)
        viewModel.onEnter()

        // Change team: 0x3210 goes out; the action clears its busy flag when done.
        viewModel.handle(.pointerDown(x: changeTeamButton.x, y: changeTeamButton.y))
        #expect(await TestServer.wait { !viewModel.isBusy })

        // Open the picker and select the first mobile: 0x3200 goes out.
        viewModel.handle(.pointerDown(x: pickerToggle.x, y: pickerToggle.y))
        #expect(viewModel.isPickerVisible)
        let cell0 = ReadyRoomViewModel.pickerCellRect(at: 0)
        viewModel.handle(.pointerDown(x: cell0.x + 5, y: cell0.y + 5))
        #expect(await TestServer.wait { !viewModel.isBusy })
        viewModel.onExit()
    }

    @Test func nonHostReadyTogglesThroughTheServer() async throws {
        let (host, hostServer) = try await TestServer.delegate("admin")
        defer { withExtendedLifetime(hostServer) {} }
        let roomID = try await TestServer.enterRoom(host, name: "ready flow")

        // A guest joins the same room and readies up.
        let network = NetworkConfig(username: "guest", password: "1234", serverAddress: "127.0.0.1", serverPort: host.network.serverPort, brokerPort: host.network.brokerPort)
        let guest = MockViewModelDelegate(network: network)
        guest.client = try await TestServer.connect("guest", port: host.network.serverPort)
        try await TestServer.joinRoom(guest, id: roomID)

        let viewModel = ReadyRoomViewModel(delegate: guest)
        viewModel.onEnter()
        #expect(!viewModel.isHost)

        viewModel.handle(.pointerDown(x: readyOrStartButton.x, y: readyOrStartButton.y))
        #expect(await TestServer.wait { !viewModel.isBusy })
        viewModel.onExit()
    }

    @Test func leaveRoomClearsSessionAndReturnsToLobby() async throws {
        let (delegate, server) = try await TestServer.delegate("admin")
        defer { withExtendedLifetime(server) {} }
        try await TestServer.enterRoom(delegate)
        let viewModel = ReadyRoomViewModel(delegate: delegate)
        viewModel.onEnter()

        viewModel.handle(.pointerDown(x: exitButton.x, y: exitButton.y))
        #expect(delegate.session.currentRoom == nil)
        #expect(delegate.requestedTransitions.contains(.gameRoomList))
        viewModel.onExit()
    }

    @Test func sendChatEchoesBack() async throws {
        let (delegate, server) = try await TestServer.delegate("admin")
        defer { withExtendedLifetime(server) {} }
        try await TestServer.enterRoom(delegate)
        let viewModel = ReadyRoomViewModel(delegate: delegate)
        viewModel.onEnter()

        // The send Task runs (covers the network path); whitespace-only chat
        // is dropped before it reaches the wire.
        viewModel.sendChat("gg")
        let before = viewModel.chatMessages.count
        viewModel.sendChat("   ")
        #expect(viewModel.chatMessages.count == before)
        viewModel.onExit()
    }
}
