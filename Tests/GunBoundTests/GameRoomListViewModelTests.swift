import Testing
@testable import GunBound
@testable import GunBoundProtocol

@Suite @MainActor
struct GameRoomListViewModelTests {

    private func makeViewModel() -> (GameRoomListViewModel, MockViewModelDelegate) {
        let network = NetworkConfig(username: "admin", password: "1234", serverAddress: "127.0.0.1", serverPort: 8370, brokerPort: 8372)
        let delegate = MockViewModelDelegate(network: network)
        return (GameRoomListViewModel(delegate: delegate), delegate)
    }

    private func room(id: RoomID, players: UInt8 = 2, capacity: RoomCapacity = ._4_4, playing: Bool = false) -> RoomListResponse.Room {
        RoomListResponse.Room(id: id, name: "Room \(id)", map: .random, settings: 0, playerCount: players, capacity: capacity, isPlaying: playing, isLocked: false)
    }

    /// Cards fill column-major: the first three rooms go down the left column
    /// (x = 24), the next three down the right column (x = 324), each row 60px
    /// below the last — matching the decompiled `roomIndex/3` → column,
    /// `roomIndex%3` → row grid math.
    @Test func roomGridLayout() {
        let (viewModel, _) = makeViewModel()
        #expect(viewModel.roomRect(at: 0) == Rect(x: 24, y: 290, width: 257, height: 58))
        #expect(viewModel.roomRect(at: 1) == Rect(x: 24, y: 350, width: 257, height: 58))
        #expect(viewModel.roomRect(at: 2) == Rect(x: 24, y: 410, width: 257, height: 58))
        #expect(viewModel.roomRect(at: 3) == Rect(x: 324, y: 290, width: 257, height: 58))
        #expect(viewModel.roomRect(at: 5) == Rect(x: 324, y: 410, width: 257, height: 58))
    }

    @Test func visibleRoomCountCapsAtSix() {
        let (viewModel, _) = makeViewModel()
        viewModel.rooms = (0..<10).map { room(id: RoomID(rawValue: UInt16($0))) }
        #expect(viewModel.visibleRoomCount == GameRoomListViewModel.maxVisibleRooms)
    }

    @Test func clickingRoomCardSelectsIt() {
        let (viewModel, _) = makeViewModel()
        viewModel.rooms = (0..<6).map { room(id: RoomID(rawValue: UInt16($0))) }

        #expect(viewModel.selectedRoomIndex == nil)
        // Center of card index 3 (right column, top row): x≈324+128, y≈290+29.
        let rect = viewModel.roomRect(at: 3)
        viewModel.handle(.pointerDown(x: rect.x + rect.width / 2, y: rect.y + rect.height / 2))
        #expect(viewModel.selectedRoomIndex == 3)
    }

    @Test func hoverTracksRoomUnderCursor() {
        let (viewModel, _) = makeViewModel()
        viewModel.rooms = (0..<6).map { room(id: RoomID(rawValue: UInt16($0))) }

        let rect = viewModel.roomRect(at: 2)
        viewModel.handle(.pointerMoved(x: rect.x + 5, y: rect.y + 5))
        #expect(viewModel.hoveredRoomIndex == 2)

        viewModel.handle(.pointerMoved(x: 700, y: 10))  // empty area
        #expect(viewModel.hoveredRoomIndex == nil)
    }

    @Test func statusReflectsRoomState() {
        let (viewModel, _) = makeViewModel()
        #expect(viewModel.status(of: room(id: 1, players: 2, capacity: ._4_4, playing: false)) == .waiting)
        #expect(viewModel.status(of: room(id: 2, players: 2, capacity: ._4_4, playing: true)) == .playing)
        #expect(viewModel.status(of: room(id: 3, players: 8, capacity: ._4_4, playing: false)) == .full)
    }

    /// Clicks the (first) button with the given action after giving it a
    /// hit-test rect — buttons are identified by their confirmed action, not
    /// a positional index.
    private func click(_ action: GameRoomListViewModel.ButtonAction, in viewModel: GameRoomListViewModel) {
        guard let index = viewModel.buttons.firstIndex(where: { $0.action == action }) else {
            Issue.record("no button with action \(action)")
            return
        }
        viewModel.setRect(Rect(x: 20, y: 540, width: 100, height: 40), forButtonAt: index)
        viewModel.handle(.pointerDown(x: 40, y: 560))
    }

    @Test func buttonSetMatchesTheDecompiledBar() {
        let (viewModel, _) = makeViewModel()
        // The confirmed b_gamelist_* bottom bar (dialog sheets like
        // gamelist_create.img are NOT buttons).
        #expect(viewModel.buttons.allSatisfy { $0.name.hasPrefix("b_gamelist_") })
        #expect(Set(viewModel.buttons.map(\.action)) == [
            .exit, .buddy, .ranking, .avatar, .createRoom, .joinSelected,
            .viewAll, .waitingOnly, .pagePrev, .pageNext, .findFriend, .directGo,
        ])
        // buttonId 0 is Exit → Server Select in the decomp.
        #expect(viewModel.buttons.first { $0.action == .exit }?.id == 0)
    }

    @Test func exitButtonReturnsToServerSelect() {
        let (viewModel, delegate) = makeViewModel()
        click(.exit, in: viewModel)
        #expect(delegate.requestedTransitions == [.serverSelect])
    }

    @Test func createButtonTransitionsToReadyRoom() {
        let (viewModel, delegate) = makeViewModel()
        click(.createRoom, in: viewModel)
        #expect(delegate.requestedTransitions == [.readyRoom])
    }

    @Test func avatarButtonTransitionsToAvatarShop() {
        let (viewModel, delegate) = makeViewModel()
        click(.avatar, in: viewModel)
        #expect(delegate.requestedTransitions == [.avatarShop])
    }

    @Test func buddyButtonTogglesThePanel() {
        let (viewModel, delegate) = makeViewModel()
        #expect(!viewModel.isBuddyPanelVisible)

        click(.buddy, in: viewModel)
        #expect(viewModel.isBuddyPanelVisible)
        // Toggling opens/closes; it doesn't navigate anywhere.
        #expect(delegate.requestedTransitions.isEmpty)

        click(.buddy, in: viewModel)
        #expect(!viewModel.isBuddyPanelVisible)

        // The panel's own close-X path clears it too.
        click(.buddy, in: viewModel)
        #expect(viewModel.isBuddyPanelVisible)
        viewModel.dismissBuddyPanel()
        #expect(!viewModel.isBuddyPanelVisible)
    }

    @Test func waitingFilterHidesInProgressRooms() {
        let (viewModel, _) = makeViewModel()
        viewModel.rooms = [
            room(id: 1, playing: false),
            room(id: 2, playing: true),
            room(id: 3, playing: false),
        ]
        #expect(viewModel.visibleRoomCount == 3)

        click(.waitingOnly, in: viewModel)
        #expect(viewModel.filter == .waitingOnly)
        #expect(viewModel.visibleRooms.map(\.id) == [1, 3])

        click(.viewAll, in: viewModel)
        #expect(viewModel.filter == .all)
        #expect(viewModel.visibleRoomCount == 3)
    }
}
