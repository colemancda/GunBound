import Testing
@testable import GunBound
@testable import GunBoundProtocol

@Suite @MainActor
struct LoadingViewModelTests {

    private func makeViewModel() -> (LoadingViewModel, MockViewModelDelegate) {
        let network = NetworkConfig(username: "admin", password: "1234", serverAddress: "127.0.0.1", serverPort: 8370, brokerPort: 8372)
        let delegate = MockViewModelDelegate(network: network)
        return (LoadingViewModel(delegate: delegate), delegate)
    }

    @Test func stageOverlayNameIsTwoDigitMapId() {
        let (viewModel, delegate) = makeViewModel()
        delegate.session.currentRoom = JoinRoomResponse(room: 1, name: "R", map: .metropolis, settings: 0, capacity: ._1_1, players: [])
        // metropolis == 3
        #expect(viewModel.stageOverlayImageName == "load_stage03.img")
    }

    @Test func advancesToBattleAfterDuration() {
        let (viewModel, delegate) = makeViewModel()
        viewModel.onEnter()

        viewModel.update(deltaTime: 1.0)
        #expect(delegate.requestedTransitions.isEmpty)  // not done yet

        viewModel.update(deltaTime: 1.5)  // past the 2.0s duration
        #expect(delegate.requestedTransitions == [.inGameSession])
    }

    @Test func progressIsClampedToOne() {
        let (viewModel, _) = makeViewModel()
        viewModel.onEnter()
        viewModel.update(deltaTime: 10.0)
        #expect(viewModel.progress == 1.0)
    }

    @Test func readyStateWithNoRosterDoesNotCrash() {
        let (viewModel, _) = makeViewModel()
        viewModel.onEnter()
        // No roster — isReady must handle an empty player list.
        #expect(viewModel.isReady(playerIndex: 0) == false)
        viewModel.update(deltaTime: 5.0)
        #expect(viewModel.isReady(playerIndex: 0) == true)
    }
}
