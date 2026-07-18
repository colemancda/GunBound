import Foundation
import Testing
@testable import GunBound
@testable import GunBoundClient
import GunBoundProtocol

/// Drives a full offline battle through `InBattleScreen`, rendering every
/// frame, so the phase-dependent draw code (aim arc, charging gauge, projectile,
/// explosion, HUD, chat) and the underlying simulation both run.
@Suite @MainActor
struct InBattleDriveTests {

    private func battle() -> StartGameNotification {
        StartGameNotification(
            settings: 0, map: .metropolis,
            players: [
                StartGameNotification.Player(id: 0, username: "u", team: .a, primaryTank: .boomer, secondaryTank: .random, xPosition: 600, yPosition: 400, turnOrder: 0),
                StartGameNotification.Player(id: 1, username: "x", team: .b, primaryTank: .armor, secondaryTank: .random, xPosition: 1000, yPosition: 400, turnOrder: 1),
            ],
            events: 0, commandData: []
        )
    }

    @Test func fullFireLoopRendersEveryPhase() throws {
        let renderer = ScreenHarness.Renderer()
        let context = ScreenHarness.context(renderer)
        context.session.battle = battle()
        let viewModel = InBattleViewModel(delegate: context)
        let screen = InBattleScreen(viewModel: viewModel)
        try screen.onEnter(context: context)
        try screen.render(renderer)

        // Aim, walk, and switch weapons (each followed by a render).
        for event: ScreenInputEvent in [.key(.up), .key(.up), .key(.down), .key(.left), .key(.right), .key(.tab)] {
            screen.handleInput(event)
            try screen.render(renderer)
        }
        // Mouse aim + item-bar clicks along the bottom HUD.
        for x in stride(from: Float(0), through: 800, by: 50) {
            screen.handleInput(.pointerMoved(x: x, y: 560))
            screen.handleInput(.pointerDown(x: x, y: 575))
        }
        try screen.render(renderer)

        // Fire a few turns: charge, release, then run flight → impact → resolve.
        for _ in 0..<3 {
            if viewModel.phase == .aiming {
                screen.handleInput(.activate)          // begin charge
                screen.update(deltaTime: 0.4)
                try screen.render(renderer)
                screen.handleInput(.activate)          // release
            }
            var frames = 0
            while frames < 3000,
                  viewModel.phase == .charging || viewModel.phase == .projectileInFlight || viewModel.phase == .impact {
                screen.update(deltaTime: 1.0 / 60)
                try screen.render(renderer)
                frames += 1
            }
            if viewModel.isMatchOver { break }
        }

        #expect(!renderer.draws.isEmpty)
    }

    /// Score/Tag/Jewel modes each have their own simulation and render paths;
    /// drive a battle in each (with distinct secondary tanks so Tag can swap)
    /// through firing and a death, rendering every frame.
    @Test(arguments: [UInt32(0x0044_0000), 0x0008_0000, 0x000C_0000, 0])
    func battleModesRenderAndResolve(settings: UInt32) throws {
        let renderer = ScreenHarness.Renderer()
        let context = ScreenHarness.context(renderer)
        context.session.battle = StartGameNotification(
            settings: settings, map: .metropolis,
            players: [
                StartGameNotification.Player(id: 0, username: "u", team: .a, primaryTank: .boomer, secondaryTank: .mage, xPosition: 600, yPosition: 400, turnOrder: 0),
                StartGameNotification.Player(id: 1, username: "x", team: .b, primaryTank: .armor, secondaryTank: .nak, xPosition: 1000, yPosition: 400, turnOrder: 1),
            ],
            events: 0, commandData: []
        )
        let viewModel = InBattleViewModel(delegate: context)
        let screen = InBattleScreen(viewModel: viewModel)
        try screen.onEnter(context: context)

        // One fire, then the enemy dies (Tag swaps, Score decrements lives,
        // Solo/Jewel eliminate) and the match resolves.
        if viewModel.phase == .aiming {
            screen.handleInput(.activate)
            screen.update(deltaTime: 0.4)
            screen.handleInput(.activate)
            var frames = 0
            while frames < 3000, viewModel.phase != .aiming, viewModel.phase != .waiting {
                screen.update(deltaTime: 1.0 / 60)
                try screen.render(renderer)
                frames += 1
            }
        }
        viewModel.apply(.playerDied(PlayerDeadNotification(slot: 1, team: .b)))
        viewModel.apply(.playerDied(PlayerDeadNotification(slot: 1, team: .b)))  // second: past any Tag swap
        for _ in 0..<50 {
            screen.update(deltaTime: 0.1)
            try screen.render(renderer)
        }
        #expect(!renderer.draws.isEmpty)
    }

    @Test func chatOverlayAndRelayedActionsRender() throws {
        let renderer = ScreenHarness.Renderer()
        let context = ScreenHarness.context(renderer)
        context.session.battle = battle()
        let viewModel = InBattleViewModel(delegate: context)
        let screen = InBattleScreen(viewModel: viewModel)
        try screen.onEnter(context: context)

        // Battle chat, a relayed aim, and a death → match-end all draw.
        viewModel.apply(.chatReceived(ChannelChatBroadcast(position: 0, username: "x", message: "gg")))
        viewModel.apply(.tunnelReceived(TunnelForward(sourceSlot: 1, payload: [0x02, 45, 50, 1])))
        try screen.render(renderer)

        viewModel.apply(.playerDied(PlayerDeadNotification(slot: 1, team: .b)))
        for _ in 0..<20 {
            screen.update(deltaTime: 0.1)
            try screen.render(renderer)
        }
        #expect(!renderer.draws.isEmpty)
    }
}
