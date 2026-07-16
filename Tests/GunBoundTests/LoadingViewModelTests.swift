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

    /// The roster and map come from the start notification when present —
    /// the real match path — with tanks resolved for the icon row.
    @Test func battleDataDrivesTheRosterAndMap() {
        let network = NetworkConfig(username: "admin", password: "1234", serverAddress: "127.0.0.1", serverPort: 8370, brokerPort: 8372)
        let delegate = MockViewModelDelegate(network: network)
        let viewModel = LoadingViewModel(delegate: delegate)
        // Room says .random; the start notification resolved it to a map.
        delegate.session.currentRoom = JoinRoomResponse(room: 1, name: "R", map: .random, settings: 0, capacity: ._2_2, players: [])
        delegate.session.battle = StartGameNotification(
            settings: 0,
            map: .seaHero,
            players: [
                StartGameNotification.Player(id: 0, username: "admin", team: .a, primaryTank: .boomer, secondaryTank: .random, xPosition: 100, yPosition: 200, turnOrder: 0),
                StartGameNotification.Player(id: 1, username: "guest", team: .b, primaryTank: .armor, secondaryTank: .random, xPosition: 500, yPosition: 200, turnOrder: 1),
            ],
            events: 0,
            commandData: []
        )

        #expect(viewModel.map == .seaHero)
        #expect(viewModel.players == [
            LoadingViewModel.LoadingPlayer(name: "admin", team: .a, mobile: .boomer),
            LoadingViewModel.LoadingPlayer(name: "guest", team: .b, mobile: .armor),
        ])

        // The loading slot walks the roster as progress advances.
        viewModel.onEnter()
        #expect(viewModel.loadingSlot == 0)
        viewModel.update(deltaTime: 1.1)   // past the halfway point (2 players / 2s)
        #expect(viewModel.isReady(playerIndex: 0))
        #expect(viewModel.loadingSlot == 1)
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
