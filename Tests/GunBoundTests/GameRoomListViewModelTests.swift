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

    /// Status maps to the `gamelist_back.img` label frames: PLAY 7 / FULL 8 /
    /// WAIT 9.
    @Test func statusFrameMapsToLabelFrames() {
        let (viewModel, _) = makeViewModel()
        #expect(viewModel.statusFrame(of: room(id: 1, playing: true)) == 7)
        #expect(viewModel.statusFrame(of: room(id: 2, players: 8, capacity: ._4_4)) == 8)
        #expect(viewModel.statusFrame(of: room(id: 3, players: 1)) == 9)
    }

    /// Card frame: left column base 1, right column base 4; +1 when
    /// hovered/selected, +2 when it's the joined room (which wins over hover).
    @Test func cardFrameByColumnStateAndJoined() {
        let (viewModel, delegate) = makeViewModel()
        viewModel.rooms = (1...6).map { room(id: RoomID(rawValue: UInt16($0))) }

        #expect(viewModel.cardFrame(forVisibleSlot: 0) == 1)   // left, plain
        #expect(viewModel.cardFrame(forVisibleSlot: 3) == 4)   // right, plain

        // Hovering slot 0 → +1.
        let r0 = viewModel.roomRect(at: 0)
        viewModel.handle(.pointerMoved(x: r0.x + 2, y: r0.y + 2))
        #expect(viewModel.cardFrame(forVisibleSlot: 0) == 2)

        // The player's joined room (id 4 → slot 3) uses the joined frame (+2),
        // which beats hover.
        delegate.session.currentRoom = JoinRoomResponse(
            room: 4, name: "Room 4", map: .random, settings: 0, capacity: ._4_4, players: []
        )
        #expect(viewModel.joinedRoomIndex == 3)
        #expect(viewModel.cardFrame(forVisibleSlot: 3) == 6)   // 4 + 2
    }

    /// Game-mode label frame = 10 + settings bits 18–19 (SOLO…JEWEL).
    @Test func modeFrameFromSettingsBits() {
        let (viewModel, _) = makeViewModel()
        func room(settings: UInt32) -> RoomListResponse.Room {
            RoomListResponse.Room(id: 1, name: "R", map: .random, settings: settings, playerCount: 1, capacity: ._4_4, isPlaying: false, isLocked: false)
        }
        #expect(viewModel.modeFrame(of: room(settings: 0)) == 10)
        #expect(viewModel.modeFrame(of: room(settings: 1 << 18)) == 11)
        #expect(viewModel.modeFrame(of: room(settings: 3 << 18)) == 13)
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
