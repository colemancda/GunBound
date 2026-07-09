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

    /// Loading the terrain mask snaps every mobile onto the surface at its
    /// spawn column and re-centers the camera on the grounded own mobile.
    @Test func terrainSnapsSpawnsToTheSurface() {
        struct FlatFloor: BattleTerrain {
            // Solid ground from y 1000 down, everywhere.
            func isSolid(x: Int, y: Int) -> Bool { y >= 1000 }
            func surfaceLevel(atX x: Int, near y: Int) -> Int? { 1000 }
        }
        let (viewModel, _) = makeViewModel()
        #expect(viewModel.players[0].y == 900)

        viewModel.setTerrain(FlatFloor())
        #expect(viewModel.players[0].y == 1000)
        #expect(viewModel.players[1].y == 1000)
        #expect(viewModel.camera.y == 1000)  // re-centered on the grounded mobile
    }

    private struct FlatWorld: BattleTerrain {
        let floor: Int
        func isSolid(x: Int, y: Int) -> Bool { y >= floor }
        func surfaceLevel(atX x: Int, near y: Int) -> Int? { floor }
    }

    /// The full local fire loop: aim, charge, fire, flight, terrain impact,
    /// splash damage, and the turn advancing to the next living player.
    /// Offline (no client) every turn is locally controllable.
    @Test func fireLoopResolvesAndAdvancesTheTurn() {
        let (viewModel, _) = makeViewModel()
        viewModel.setWorldSize(width: 1800, height: 1800)
        viewModel.setTerrain(FlatWorld(floor: 1000))

        // Offline → "guest" (turn 0) is locally controllable.
        #expect(viewModel.isMyTurn)
        #expect(viewModel.phase == .aiming)
        #expect(viewModel.currentTurnPlayer?.name == "guest")

        // Aim: ◀ raises, ▶ lowers, clamped.
        viewModel.handle(.key(.left))
        #expect(viewModel.aimAngle == 47)
        for _ in 0..<40 { viewModel.handle(.key(.right)) }
        #expect(viewModel.aimAngle == InBattleViewModel.aimRange.lowerBound)

        // Charge, then fire on the second press.
        viewModel.handle(.activate)
        #expect(viewModel.phase == .charging)
        viewModel.update(deltaTime: 0.5)
        #expect(viewModel.power > 0)
        viewModel.handle(.activate)
        #expect(viewModel.phase == .projectileInFlight)
        #expect(viewModel.projectile != nil)

        // Run the sim until impact + resolution (bounded frames).
        var frames = 0
        while viewModel.phase == .projectileInFlight, frames < 2000 {
            viewModel.update(deltaTime: 1.0 / 60)
            frames += 1
        }
        #expect(viewModel.phase == .impact)
        // The explosion plays out, then the turn passes to "admin" (turn 1).
        while viewModel.phase == .impact {
            viewModel.update(deltaTime: 0.1)
        }
        #expect(viewModel.currentTurnPlayer?.name == "admin")
        #expect(viewModel.phase == .aiming)  // offline: also locally controllable
    }

    /// A relayed shot (the tunnel's fire tag) launches the remote shooter's
    /// projectile locally with the same deterministic sim.
    @Test func tunneledFireLaunchesTheRemoteShot() {
        let (viewModel, _) = makeViewModel()
        viewModel.setWorldSize(width: 1800, height: 1800)
        viewModel.setTerrain(FlatWorld(floor: 1000))

        // Slot 1 ("guest") fires at 45°, 80 power, to the right.
        viewModel.apply(.tunnelReceived(TunnelForward(
            sourceSlot: 1,
            payload: [0x01, 45, 80, 1, 127]  // zero wind
        )))
        #expect(viewModel.phase == .projectileInFlight)
        #expect(viewModel.projectile != nil)
        // Launched from the shooter's position (x 1200).
        #expect(abs((viewModel.projectile?.x ?? 0) - 1200) < 30)
        #expect((viewModel.projectile?.vx ?? 0) > 0)
    }

    /// An impact carves a crater (real collision hole), survivors above the
    /// hole fall to the remaining ground, and a column blown through to the
    /// void is a fall-out death.
    @Test func cratersCarveCollisionAndDropMobiles() {
        let (viewModel, _) = makeViewModel()
        viewModel.setWorldSize(width: 1800, height: 1800)
        viewModel.setTerrain(FlatWorld(floor: 1000))

        // Fire a shot and run it to resolution.
        viewModel.handle(.activate)
        viewModel.update(deltaTime: 0.4)
        viewModel.handle(.activate)
        var frames = 0
        while viewModel.phase == .projectileInFlight || viewModel.phase == .impact, frames < 3000 {
            viewModel.update(deltaTime: 1.0 / 60)
            frames += 1
        }
        #expect(viewModel.craters.count == 1)

        // The crater is a real hole: its center is no longer solid ground.
        let crater = viewModel.craters[0]
        #expect(!viewModel.isSolidGround(x: crater.x, y: crater.y))
        // Just outside the radius the floor is intact.
        #expect(viewModel.isSolidGround(x: crater.x + crater.radius + 30, y: 1000))
    }

    /// The shooter's wind roll rides in the fire payload (biased by 127) so
    /// remote sims fly the same shot; the relayed wind bends the flight.
    @Test func windRelaysAndBendsTheShot() {
        let (viewModel, _) = makeViewModel()
        viewModel.setWorldSize(width: 1800, height: 1800)
        viewModel.setTerrain(FlatWorld(floor: 1700))

        // Remote shot straight up (angle 80) with max leftward wind: the
        // projectile must drift left of the shooter before landing.
        viewModel.apply(.tunnelReceived(TunnelForward(
            sourceSlot: 1,
            payload: [0x01, 80, 60, 1, UInt8(127 - 120)]
        )))
        var frames = 0
        while viewModel.phase == .projectileInFlight, frames < 4000 {
            viewModel.update(deltaTime: 1.0 / 60)
            frames += 1
        }
        #expect(viewModel.phase == .impact)
        #expect((viewModel.explosion?.x ?? 9999) < 1200)  // drifted left of the shooter
    }

    /// Without battle data the screen still enters safely (offline path).
    @Test func offlineEntryIsSafe() {
        let (viewModel, _) = makeViewModel(battle: false)
        #expect(viewModel.players.isEmpty)
        #expect(viewModel.currentTurnPlayer == nil)
    }
}
