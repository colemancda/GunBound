import Foundation
import Testing
@testable import GunBound
@testable import GunBoundClient
import GunBoundProtocol

/// Headless lifecycle coverage for every screen: `onEnter` → `render` →
/// a spread of input events (each followed by a render) → `update` → render.
/// The harness renderer synthesizes textures for any name, so these exercise
/// the screens' layout and draw code without real assets. Each asserts the
/// screen draws *something*, proving `render` ran end to end.
@Suite @MainActor
struct ScreenSmokeTests {

    /// Drives a screen through its whole lifecycle and returns the recorder.
    private func exercise(
        _ makeScreen: (ClientContext) throws -> GameScreen,
        setup: (ClientContext) -> Void = { _ in }
    ) throws -> ScreenHarness.Renderer {
        let renderer = ScreenHarness.Renderer()
        let context = ScreenHarness.context(renderer)
        setup(context)
        let screen = try makeScreen(context)
        try screen.onEnter(context: context)
        try screen.render(renderer)
        for event in ScreenHarness.inputs {
            screen.handleInput(event)
            screen.update(deltaTime: 0.016)
            try screen.render(renderer)
        }
        return renderer
    }

    @Test func logoScreen() throws {
        let renderer = try exercise {
            LogoScreen(viewModel: LogoViewModel(imageName: "logo2.img", musicName: nil, next: .title, delegate: $0))
        }
        #expect(!renderer.draws.isEmpty)
    }

    @Test func titleScreen() throws {
        let renderer = try exercise { TitleScreen(viewModel: TitleViewModel(delegate: $0)) }
        #expect(!renderer.draws.isEmpty)
    }

    @Test func loadingScreen() throws {
        let renderer = try exercise { LoadingScreen(viewModel: LoadingViewModel(delegate: $0)) }
        #expect(!renderer.draws.isEmpty)
    }

    @Test func serverSelectScreen() throws {
        let renderer = try exercise { ServerSelectScreen(viewModel: ServerSelectViewModel(delegate: $0)) }
        #expect(!renderer.draws.isEmpty)
    }

    @Test func avatarShopScreen() throws {
        let renderer = try exercise { context in
            let viewModel = AvatarShopViewModel(delegate: context)
            viewModel.setCatalog(
                [AvatarShopViewModel.ShopItem(id: 1, name: "Hat", gold: 100, cash: 0, isMale: true)],
                for: .head
            )
            return AvatarShopScreen(viewModel: viewModel)
        }
        #expect(!renderer.draws.isEmpty)
    }

    @Test func gameRoomListScreen() throws {
        let renderer = try exercise { GameRoomListScreen(viewModel: GameRoomListViewModel(delegate: $0)) }
        #expect(!renderer.draws.isEmpty)
    }

    @Test func readyRoomScreen() throws {
        let renderer = try exercise({ ReadyRoomScreen(viewModel: ReadyRoomViewModel(delegate: $0)) }, setup: { context in
            // Seed a room so the roster/host/team layout draws.
            context.session.currentRoom = Self.sampleRoom
        })
        #expect(!renderer.draws.isEmpty)
    }

    @Test func inBattleScreen() throws {
        let renderer = try exercise { context in
            // Seed a two-player battle the way a 0x3432 start push would.
            context.session.battle = StartGameNotification(
                settings: 0,
                map: .metropolis,
                players: [
                    StartGameNotification.Player(id: 0, username: "admin", team: .a, primaryTank: .boomer, secondaryTank: .random, xPosition: 600, yPosition: 900, turnOrder: 1),
                    StartGameNotification.Player(id: 1, username: "guest", team: .b, primaryTank: .armor, secondaryTank: .random, xPosition: 1200, yPosition: 900, turnOrder: 0),
                ],
                events: 0,
                commandData: []
            )
            return InBattleScreen(viewModel: InBattleViewModel(delegate: context))
        }
        #expect(!renderer.draws.isEmpty)
    }

    // A minimal successful JoinRoomResponse for the Ready Room roster.
    private static var sampleRoom: JoinRoomResponse {
        JoinRoomResponse(
            room: RoomID(rawValue: 1),
            name: "test",
            map: .random,
            settings: 0,
            capacity: ._4_4,
            players: []
        )
    }
}
