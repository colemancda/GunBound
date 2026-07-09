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

    /// Cards fill column-major at the top of the screen: the first three
    /// rooms go down the left column (x = 24), the next three down the right
    /// column (x = 324), rows at y = row·60 + 58 — the decompiled
    /// `RenderRoomCard` grid math (`roomIndex/3` → column, card y =
    /// `roomIndex%3 · 0x3c + 0x3a`).
    @Test func roomGridLayout() {
        let (viewModel, _) = makeViewModel()
        #expect(viewModel.roomRect(at: 0) == Rect(x: 24, y: 58, width: 257, height: 58))
        #expect(viewModel.roomRect(at: 1) == Rect(x: 24, y: 118, width: 257, height: 58))
        #expect(viewModel.roomRect(at: 2) == Rect(x: 24, y: 178, width: 257, height: 58))
        #expect(viewModel.roomRect(at: 3) == Rect(x: 324, y: 58, width: 257, height: 58))
        #expect(viewModel.roomRect(at: 5) == Rect(x: 324, y: 178, width: 257, height: 58))
    }

    /// Button rects come verbatim from `State03_GameRoomList_CreateButtons`:
    /// six 107×45 buttons on the bottom bar (y 551) and six 33-tall
    /// filter/page buttons on the mid bar (y 246).
    @Test func buttonRectsMatchTheDecomp() {
        let (viewModel, _) = makeViewModel()
        func rect(_ action: GameRoomListViewModel.ButtonAction) -> Rect? {
            viewModel.buttons.first { $0.action == action }?.rect
        }
        #expect(rect(.exit) == Rect(x: 40, y: 551, width: 107, height: 45))
        #expect(rect(.joinSelected) == Rect(x: 655, y: 551, width: 107, height: 45))
        #expect(rect(.viewAll) == Rect(x: 42, y: 246, width: 81, height: 33))
        #expect(rect(.pageNext) == Rect(x: 292, y: 246, width: 49, height: 33))
        #expect(rect(.directGo) == Rect(x: 460, y: 246, width: 81, height: 33))
        // No button overlaps a room card (grid spans y 58–236).
        for button in viewModel.buttons {
            #expect(button.rect.y >= 236, "\(button.action)")
        }
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

    /// Clicks the center of the button with the given action — buttons are
    /// identified by their confirmed action and hit at their decomp rects.
    private func click(_ action: GameRoomListViewModel.ButtonAction, in viewModel: GameRoomListViewModel) {
        guard let button = viewModel.buttons.first(where: { $0.action == action }) else {
            Issue.record("no button with action \(action)")
            return
        }
        viewModel.handle(.pointerDown(
            x: button.rect.x + button.rect.width / 2,
            y: button.rect.y + button.rect.height / 2
        ))
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

    @Test func avatarButtonTransitionsToAvatarShop() {
        let (viewModel, delegate) = makeViewModel()
        click(.avatar, in: viewModel)
        #expect(delegate.requestedTransitions == [.avatarShop])
    }

    @Test func createButtonOpensTheCreateDialog() {
        let (viewModel, delegate) = makeViewModel()
        #expect(!viewModel.isCreateRoomDialogVisible)
        click(.createRoom, in: viewModel)
        #expect(viewModel.isCreateRoomDialogVisible)
        #expect(delegate.requestedTransitions.isEmpty)  // no longer jumps to Ready Room
        viewModel.dismissDialogs()
        #expect(!viewModel.isCreateRoomDialogVisible)
    }

    @Test func directGoButtonOpensTheNumberDialog() {
        let (viewModel, _) = makeViewModel()
        click(.directGo, in: viewModel)
        #expect(viewModel.isEnterNumberDialogVisible)
        #expect(!viewModel.isCreateRoomDialogVisible)
        // Opening one dialog closes the other.
        click(.createRoom, in: viewModel)
        #expect(viewModel.isCreateRoomDialogVisible)
        #expect(!viewModel.isEnterNumberDialogVisible)
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

    /// Prev/Next page a 6-card window over the filtered list, clamped at both
    /// ends; changing the filter re-paginates from page 0.
    @Test func pagingWindowsTheRoomList() {
        let (viewModel, _) = makeViewModel()
        viewModel.rooms = (1...14).map { room(id: RoomID(rawValue: UInt16($0))) }

        #expect(viewModel.pageCount == 3)
        #expect(viewModel.visibleRooms.map(\.id.rawValue) == [1, 2, 3, 4, 5, 6])

        click(.pageNext, in: viewModel)
        #expect(viewModel.page == 1)
        #expect(viewModel.visibleRooms.map(\.id.rawValue) == [7, 8, 9, 10, 11, 12])

        click(.pageNext, in: viewModel)
        #expect(viewModel.visibleRooms.map(\.id.rawValue) == [13, 14])
        click(.pageNext, in: viewModel)  // clamped at the last page
        #expect(viewModel.page == 2)

        click(.pagePrev, in: viewModel)
        click(.pagePrev, in: viewModel)
        click(.pagePrev, in: viewModel)  // clamped at the first page
        #expect(viewModel.page == 0)

        // Selection clears when the page turns (slots show different rooms).
        let rect = viewModel.roomRect(at: 0)
        viewModel.handle(.pointerDown(x: rect.x + 5, y: rect.y + 5))
        #expect(viewModel.selectedRoomIndex == 0)
        click(.pageNext, in: viewModel)
        #expect(viewModel.selectedRoomIndex == nil)

        // Filter change resets to page 0.
        click(.waitingOnly, in: viewModel)
        #expect(viewModel.page == 0)
    }

    /// A `0x200E` push appends the new user to the CHANNEL roster; room
    /// pushes are handled (they trigger a refresh, a no-op without a live
    /// connection) and raw pushes are ignored.
    @Test func pushesUpdateTheChannelRoster() {
        let (viewModel, _) = makeViewModel()
        viewModel.channelUsers = ["alsey"]

        viewModel.apply(.userJoinedChannel(JoinChannelNotification(
            channelPosition: 1, username: "boomer", avatarEquipped: 0, guild: "", rankCurrent: 20, rankSeason: 20
        )))
        #expect(viewModel.channelUsers == ["alsey", "boomer"])

        viewModel.apply(.roomUpdated(RoomUpdateNotification()))
        viewModel.apply(.raw(Packet(opcode: .roomUpdateNotification)))
        #expect(viewModel.channelUsers == ["alsey", "boomer"])  // unchanged
    }

    /// A `0x201F` broadcast appends a formatted chat line, capped to the most
    /// recent `maxChatLines`.
    @Test func chatBroadcastsAppendFormattedLines() {
        let (viewModel, _) = makeViewModel()
        viewModel.apply(.chatReceived(ChannelChatBroadcast(position: 0, username: "alsey", message: "hello lobby")))
        #expect(viewModel.chatMessages == ["alsey: hello lobby"])

        for i in 0..<(GameRoomListViewModel.maxChatLines + 10) {
            viewModel.apply(.chatReceived(ChannelChatBroadcast(position: 0, username: "bot", message: "\(i)")))
        }
        #expect(viewModel.chatMessages.count == GameRoomListViewModel.maxChatLines)
        #expect(viewModel.chatMessages.last == "bot: \(GameRoomListViewModel.maxChatLines + 9)")
    }

    /// Entering the lobby seeds the CHANNEL roster from the join-channel
    /// response stored in the session.
    @Test func onEnterSeedsChannelUsersFromSession() {
        let (viewModel, delegate) = makeViewModel()
        delegate.session.channel = JoinChannelResponse(
            status: 0, channel: 1, maxPosition: 2,
            users: [
                JoinChannelResponse.ChannelUser(id: 0, username: "alsey", avatarEquipped: 0, guild: "", rankCurrent: 20, rankSeason: 20),
                JoinChannelResponse.ChannelUser(id: 1, username: "trico", avatarEquipped: 0, guild: "", rankCurrent: 19, rankSeason: 19),
            ]
        )
        viewModel.onEnter()
        #expect(viewModel.channelUsers == ["alsey", "trico"])
        viewModel.onExit()
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
