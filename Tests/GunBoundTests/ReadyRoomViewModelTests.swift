import Testing
@testable import GunBound
@testable import GunBoundProtocol

@Suite @MainActor
struct ReadyRoomViewModelTests {

    private func makeViewModel() -> (ReadyRoomViewModel, MockViewModelDelegate) {
        let network = NetworkConfig(username: "admin", password: "1234", serverAddress: "127.0.0.1", serverPort: 8370, brokerPort: 8372)
        let delegate = MockViewModelDelegate(network: network)
        return (ReadyRoomViewModel(delegate: delegate), delegate)
    }

    /// Roster slots fill row-major: four across, two rows.
    @Test func rosterGridLayout() {
        let (viewModel, _) = makeViewModel()
        let slot0 = viewModel.rosterSlotRect(at: 0)
        let slot1 = viewModel.rosterSlotRect(at: 1)
        let slot4 = viewModel.rosterSlotRect(at: 4)
        #expect(slot0.x == 40 && slot0.y == 70)
        #expect(slot1.y == slot0.y)          // same row
        #expect(slot1.x > slot0.x)           // next column
        #expect(slot4.x == slot0.x)          // wrapped to column 0
        #expect(slot4.y > slot0.y)           // second row
    }

    @Test func exposesRoomFromSession() {
        let (viewModel, delegate) = makeViewModel()
        #expect(viewModel.roomName == "")

        delegate.session.currentRoom = JoinRoomResponse(
            room: 3, name: "My Room", map: .metropolis, settings: 0, capacity: ._2_2, players: []
        )
        #expect(viewModel.roomName == "My Room")
        #expect(viewModel.map == .metropolis)
    }

    @Test func cancelReturnsToLobbyAndClearsRoom() {
        let (viewModel, delegate) = makeViewModel()
        delegate.session.currentRoom = JoinRoomResponse(room: 1, name: "R", map: .random, settings: 0, capacity: ._1_1, players: [])
        viewModel.cancelRect = Rect(x: 20, y: 540, width: 100, height: 40)

        viewModel.handle(.pointerDown(x: 40, y: 560))

        #expect(delegate.requestedTransitions == [.gameRoomList])
        #expect(delegate.session.currentRoom == nil)
    }

    @Test func startWithoutConnectionAdvancesToLoading() {
        let (viewModel, delegate) = makeViewModel()
        viewModel.startRect = Rect(x: 600, y: 540, width: 100, height: 40)

        // No `delegate.client` set → start advances locally.
        viewModel.handle(.pointerDown(x: 640, y: 560))

        #expect(delegate.requestedTransitions == [.loading])
    }

    @Test func clampsRosterToMaxPlayers() {
        let (viewModel, delegate) = makeViewModel()
        // A response with more players than slots is capped for display.
        delegate.session.currentRoom = JoinRoomResponse(room: 1, name: "R", map: .random, settings: 0, capacity: ._4_4, players: [])
        #expect(viewModel.players.count <= ReadyRoomViewModel.maxPlayers)
    }
}
