import Testing
@testable import GunBound
@testable import GunBoundProtocol

@Suite @MainActor
struct InBattleViewModelTests {

    private func makeViewModel(battle: Bool = true) -> (InBattleViewModel, MockViewModelDelegate) {
        let network = NetworkConfig(username: "admin", password: "1234", serverAddress: "127.0.0.1", serverPort: 8370, brokerPort: 8372)
        let delegate = MockViewModelDelegate(network: network)
        if battle {
            delegate.session.battle = StartGameNotification(
                settings: 0,
                map: .metropolis,
                players: [
                    StartGameNotification.Player(id: 0, username: "admin", team: .a, primaryTank: .boomer, secondaryTank: .random, xPosition: 600, yPosition: 900, turnOrder: 1),
                    StartGameNotification.Player(id: 1, username: "guest", team: .b, primaryTank: .armor, secondaryTank: .random, xPosition: 1200, yPosition: 900, turnOrder: 0),
                ],
                events: 0,
                commandData: []
            )
        }
        let viewModel = InBattleViewModel(delegate: delegate)
        viewModel.onEnter()
        return (viewModel, delegate)
    }

    /// Spawns, teams, tanks, and turn order come from the start notification;
    /// the camera opens centered on our own mobile.
    @Test func battleDataDrivesTheScene() {
        let (viewModel, _) = makeViewModel()
        #expect(viewModel.map == .metropolis)
        #expect(viewModel.players.count == 2)
        #expect(viewModel.players[0].mobile == .boomer)
        #expect(viewModel.players[1].x == 1200)

        // Camera centered on "admin"'s spawn (600, 900).
        #expect(viewModel.camera.x == 600)
        #expect(viewModel.camera.y == 900)

        // Turn display: lowest turn order among the living — "guest".
        #expect(viewModel.currentTurnPlayer?.name == "guest")

        // World → screen: own spawn lands at the view center.
        let own = viewModel.screenPosition(x: 600, y: 900)
        #expect(own.x == InBattleViewModel.halfView.x)
        #expect(own.y == InBattleViewModel.halfView.y)
    }

    /// The camera clamps to the world bounds and pans with the edge bands.
    @Test func cameraClampsAndEdgeScrolls() {
        let (viewModel, _) = makeViewModel()
        viewModel.setWorldSize(width: 1800, height: 1800)

        // Clamped: can't center closer than half a view to an edge.
        viewModel.handle(.scroll(x: 400, y: 300, steps: -100))
        #expect(viewModel.camera.y == InBattleViewModel.halfView.y)
        viewModel.handle(.scroll(x: 400, y: 300, steps: 200))
        #expect(viewModel.camera.y == 1800 - InBattleViewModel.halfView.y)

        // Pointer in the left edge band pans the camera left over time.
        let before = viewModel.camera.x
        viewModel.handle(.pointerMoved(x: 5, y: 300))
        viewModel.update(deltaTime: 0.5)
        #expect(viewModel.camera.x < before)
        #expect(viewModel.camera.x >= InBattleViewModel.halfView.x)
    }

    /// Battle pushes: a death grays the slot (turn skips them), a quit
    /// removes it, and game end returns to the lobby clearing the battle.
    @Test func battlePushesUpdateTheScene() {
        let (viewModel, delegate) = makeViewModel()

        viewModel.apply(.playerDied(PlayerDeadNotification(slot: 1, team: .b)))
        #expect(viewModel.players[1].isAlive == false)
        #expect(viewModel.currentTurnPlayer?.name == "admin")  // dead skipped

        viewModel.apply(.userQuit(UserQuitNotification(slot: 1)))
        #expect(viewModel.players.count == 1)

        viewModel.apply(.gameEnded(GameEndNotification(payload: [0x00])))
        #expect(delegate.requestedTransitions == [.gameRoomList])
        #expect(delegate.session.battle == nil)
    }

    /// Without battle data the screen still enters safely (offline path).
    @Test func offlineEntryIsSafe() {
        let (viewModel, _) = makeViewModel(battle: false)
        #expect(viewModel.players.isEmpty)
        #expect(viewModel.currentTurnPlayer == nil)
    }
}
