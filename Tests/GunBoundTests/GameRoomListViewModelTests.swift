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

    @Test func createButtonTransitionsToReadyRoom() {
        let (viewModel, delegate) = makeViewModel()
        viewModel.setRect(Rect(x: 20, y: 540, width: 100, height: 40), forButtonAt: 0)  // gamelist_create.img
        viewModel.handle(.pointerDown(x: 40, y: 560))
        #expect(delegate.requestedTransitions == [.readyRoom])
    }

    @Test func avatarButtonTransitionsToAvatarShop() {
        let (viewModel, delegate) = makeViewModel()
        viewModel.setRect(Rect(x: 20, y: 540, width: 100, height: 40), forButtonAt: 3)  // b_gamelist_avatar.img
        viewModel.handle(.pointerDown(x: 40, y: 560))
        #expect(delegate.requestedTransitions == [.avatarShop])
    }
}
