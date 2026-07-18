import Foundation
import Testing
@testable import GunBound
@testable import GunBoundClient
import GunBoundProtocol

/// Covers `ScreenFactory` and `GameStateMachine`: the factory maps every mode
/// to a screen, and the state machine boots, transitions through every screen
/// (arming the transition wipe each time), and forwards input/gamepad/render.
@Suite @MainActor
struct GameStateMachineTests {

    private static let screenModes: [ClientMode] = [
        .logo1, .logo2, .title, .serverSelect, .gameRoomList,
        .readyRoom, .avatarShop, .loading, .inGameSession,
    ]

    @Test func factoryProducesEveryScreen() {
        let renderer = ScreenHarness.Renderer()
        let context = ScreenHarness.context(renderer)
        for mode in Self.screenModes {
            #expect(makeGameScreen(for: mode, delegate: context) != nil, "\(mode)")
        }
        // Exit has no screen.
        #expect(makeGameScreen(for: .exitToDesktop, delegate: context) == nil)
    }

    @Test func stateMachineBootsTransitionsAndRenders() throws {
        let renderer = ScreenHarness.Renderer()
        let context = ScreenHarness.context(renderer)
        // Seed the state the room/battle screens read on enter.
        context.session.currentRoom = JoinRoomResponse(
            room: RoomID(rawValue: 1), name: "r", map: .random, settings: 0,
            capacity: ._4_4, players: []
        )
        context.session.battle = StartGameNotification(
            settings: 0, map: .metropolis,
            players: [StartGameNotification.Player(id: 0, username: "admin", team: .a, primaryTank: .boomer, secondaryTank: .random, xPosition: 600, yPosition: 900, turnOrder: 0)],
            events: 0, commandData: []
        )

        let machine = try GameStateMachine(context: context, initialMode: .logo1) { mode in
            makeGameScreen(for: mode, delegate: context)
        }

        try machine.render()
        machine.handleInput(.pointerMoved(x: 100, y: 100))
        machine.handleInput(.activate)
        machine.applyGamepad(stickX: 0.5, stickY: -0.5, click: true, deltaTime: 0.016)

        // Walk through every screen: request the transition, then update
        // applies it (and arms the wipe), then render draws the new screen.
        for mode in Self.screenModes.dropFirst() {
            context.requestTransition(to: mode)
            try machine.update(deltaTime: 0.016)
            try machine.render()
            #expect(machine.current != nil)
        }

        // Run the transition wipe out over several frames.
        for _ in 0..<15 {
            try machine.update(deltaTime: 0.1)
            try machine.render()
        }
    }
}
