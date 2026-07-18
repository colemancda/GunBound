import Foundation
import Testing
@testable import GunBound
@testable import GunBoundClient
import GunBoundProtocol

/// Renders the screens in richer states — populated lists, open dialogs, buddy
/// panels, selections — to cover the render branches (and the embedded dialog
/// and panel widgets) the default smoke pass leaves untouched.
@Suite @MainActor
struct EnrichedScreenTests {

    private func render(_ screen: GameScreen, _ renderer: ScreenHarness.Renderer, extra: (ScreenHarness.Renderer) throws -> Void = { _ in }) throws {
        try screen.render(renderer)
        try extra(renderer)
    }

    @Test func gameRoomListWithRoomsDialogsAndBuddies() throws {
        let renderer = ScreenHarness.Renderer()
        let context = ScreenHarness.context(renderer)
        let viewModel = GameRoomListViewModel(delegate: context)
        viewModel.rooms = (1...5).map {
            RoomListResponse.Room(id: RoomID(rawValue: UInt16($0)), name: "Room \($0)", map: .random, settings: UInt32($0) << 18, playerCount: UInt8($0), capacity: ._4_4, isPlaying: $0.isMultiple(of: 2), isLocked: $0 == 3)
        }
        viewModel.buddies = ["alice", "bob"]
        let screen = GameRoomListScreen(viewModel: viewModel)
        try screen.onEnter(context: context)

        // Hover + select a room card.
        screen.handleInput(.pointerMoved(x: 30, y: 70))
        screen.handleInput(.pointerDown(x: 30, y: 70))
        try screen.render(renderer)

        // Open the Create Room dialog (button at 532,551) and render it.
        screen.handleInput(.pointerDown(x: 537, y: 556))
        try screen.render(renderer)

        // Open the buddy panel and render it.
        viewModel.setBuddyPanelVisible(true)
        try screen.render(renderer)
        #expect(!renderer.draws.isEmpty)
    }

    @Test func readyRoomWithRosterPickerAndBuddies() throws {
        let renderer = ScreenHarness.Renderer()
        let context = ScreenHarness.context(renderer)
        context.session.currentRoom = JoinRoomResponse(
            room: RoomID(rawValue: 1), name: "room", map: .metropolis, settings: 0,
            capacity: ._4_4, players: []
        )
        let viewModel = ReadyRoomViewModel(delegate: context)
        viewModel.buddies = ["alice"]
        viewModel.chatMessages = [ChatLine(message: "hi", type: .normal)]
        viewModel.readyPlayers = ["admin"]
        let screen = ReadyRoomScreen(viewModel: viewModel)
        try screen.onEnter(context: context)
        try screen.render(renderer)

        // Open the mobile picker (toggle at 49,373) and the buddy panel.
        screen.handleInput(.pointerDown(x: 49, y: 373))
        try screen.render(renderer)
        viewModel.setBuddyPanelVisible(true)
        try screen.render(renderer)
        #expect(!renderer.draws.isEmpty)
    }

    @Test func avatarShopWithCatalogSelectionAndPreview() throws {
        let renderer = ScreenHarness.Renderer()
        let context = ScreenHarness.context(renderer)
        let viewModel = AvatarShopViewModel(delegate: context)
        viewModel.setCatalog(
            (1...6).map { AvatarShopViewModel.ShopItem(id: $0, name: "Item \($0)", gold: Int32($0) * 100, cash: 0, isMale: true) },
            for: .head
        )
        let screen = AvatarShopScreen(viewModel: viewModel)
        try screen.onEnter(context: context)
        try screen.render(renderer)

        // Select the first card, then Try it on (previews a re-dressed avatar).
        let card = AvatarShopViewModel.cardRect(at: 0)
        screen.handleInput(.pointerDown(x: card.x + 5, y: card.y + 5))
        try screen.render(renderer)
        screen.handleInput(.pointerDown(x: AvatarShopViewModel.tryRect.x + 5, y: AvatarShopViewModel.tryRect.y + 5))
        try screen.render(renderer)
        // Switch category tabs.
        for i in 0..<AvatarShopViewModel.categoryTabs.count {
            let tab = AvatarShopViewModel.categoryTabRect(at: i)
            screen.handleInput(.pointerDown(x: tab.x + 5, y: tab.y + 5))
            try screen.render(renderer)
        }
        #expect(!renderer.draws.isEmpty)
    }

    @Test func serverSelectWithServersAndBuddyPanel() async throws {
        struct Fetcher: ServerDirectoryFetching {
            let servers: [ServerDirectoryResponse.Server]
            func fetchServerDirectory(address: String, brokerPort: UInt16) async throws -> [ServerDirectoryResponse.Server] { servers }
        }
        let renderer = ScreenHarness.Renderer()
        let context = ScreenHarness.context(renderer)
        var servers: [ServerDirectoryResponse.Server] = []
        for i in 0..<5 {
            let port = UInt16(8000 + i)
            let util = UInt16(i * 20)
            let server = ServerDirectoryResponse.Server(
                id: UInt16(i),
                name: "Server \(i)",
                descriptionText: "d",
                address: IPv4Address(127, 0, 0, 1),
                port: port,
                utilization: util,
                capacity: 100,
                isEnabled: i != 2
            )
            servers.append(server)
        }
        let viewModel = ServerSelectViewModel(delegate: context, directoryFetcher: Fetcher(servers: servers))
        let screen = ServerSelectScreen(viewModel: viewModel)
        try screen.onEnter(context: context)
        _ = await viewModel.fetchDirectoryAndChooseServer()
        try screen.render(renderer)

        // Select a row, then open the buddy panel.
        let row = viewModel.rowRect(at: 1)
        screen.handleInput(.pointerDown(x: row.x + 5, y: row.y + 5))
        try screen.render(renderer)
        viewModel.setBuddyPanelVisible(true)
        try screen.render(renderer)
        #expect(!renderer.draws.isEmpty)
    }
}
