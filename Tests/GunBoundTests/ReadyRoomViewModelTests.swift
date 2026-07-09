import Testing
@testable import GunBound
@testable import GunBoundProtocol

@Suite @MainActor
struct ReadyRoomViewModelTests {

    private func makeViewModel() -> (ReadyRoomViewModel, MockViewModelDelegate) {
        let network = NetworkConfig(username: "admin", password: "1234", serverAddress: "127.0.0.1", serverPort: 8370, brokerPort: 8372)
        let delegate = MockViewModelDelegate(network: network)
        return (ReadyRoomViewModel(delegate: delegate), delegate)
    }

    private func player(_ name: Username, team: Team = .a) -> JoinRoomResponse.PlayerSession {
        JoinRoomResponse.PlayerSession(
            id: 0, username: name,
            address: GunBoundProtocol.GunBoundAddress(address: "127.0.0.1", port: 8370)!,
            address2: GunBoundProtocol.GunBoundAddress(address: "127.0.0.1", port: 8370)!,
            primaryTank: .armor, secondary: .random, team: team,
            avatarEquipped: 0, guild: "", rankCurrent: 20, rankSeason: 20
        )
    }

    /// Roster slots: 2×2 on each side of the center map panel.
    @Test func rosterGridLayout() {
        let (viewModel, _) = makeViewModel()
        let slot0 = viewModel.rosterSlotRect(at: 0)
        let slot2 = viewModel.rosterSlotRect(at: 2)
        let slot4 = viewModel.rosterSlotRect(at: 4)
        #expect(slot0.x == 36 && slot0.y == 58)
        #expect(slot2.x == 497)              // right half
        #expect(slot4.x == slot0.x)          // wrapped to the second row
        #expect(slot4.y == 200)
    }

    /// Button rects come verbatim from `State09_ReadyRoom_OnEnter`: the
    /// lobby's bottom-bar convention (y 551, 107×45) plus the picker toggle.
    @Test func buttonRectsMatchTheDecomp() {
        let (viewModel, _) = makeViewModel()
        func rect(_ action: ReadyRoomViewModel.ButtonAction) -> Rect? {
            viewModel.buttons.first { $0.action == action }?.rect
        }
        #expect(rect(.exit) == Rect(x: 40, y: 551, width: 107, height: 45))
        #expect(rect(.buddy) == Rect(x: 163, y: 551, width: 107, height: 45))
        #expect(rect(.changeTeam) == Rect(x: 532, y: 551, width: 107, height: 45))
        #expect(rect(.readyOrStart) == Rect(x: 655, y: 551, width: 107, height: 45))
        #expect(rect(.togglePicker) == Rect(x: 37, y: 363, width: 25, height: 20))
    }

    /// The character grid: 15 66×50 cells, 5 per row, at the decomp origin.
    @Test func pickerGridMatchesTheDecomp() {
        #expect(ReadyRoomViewModel.pickerCellRect(at: 0) == Rect(x: 33, y: 388, width: 66, height: 50))
        #expect(ReadyRoomViewModel.pickerCellRect(at: 4) == Rect(x: 33 + 4 * 66, y: 388, width: 66, height: 50))
        #expect(ReadyRoomViewModel.pickerCellRect(at: 5) == Rect(x: 33, y: 438, width: 66, height: 50))
        #expect(ReadyRoomViewModel.pickerCellCount == 15)
        #expect(ReadyRoomViewModel.pickerDisabledCell == 13)
    }

    @Test func exposesRoomFromSession() {
        let (viewModel, delegate) = makeViewModel()
        #expect(viewModel.roomName == "")

        delegate.session.currentRoom = JoinRoomResponse(
            room: 3, name: "My Room", map: .metropolis, settings: 0, capacity: ._2_2, players: []
        )
        #expect(viewModel.roomName == "My Room")
        #expect(viewModel.map == .metropolis)
    }

    /// Slot 0 is the host: the local player gets Start when first in the
    /// roster, Ready otherwise.
    @Test func hostIsRosterSlotZero() {
        let (viewModel, delegate) = makeViewModel()
        delegate.session.currentRoom = JoinRoomResponse(
            room: 1, name: "R", map: .random, settings: 0, capacity: ._2_2,
            players: [player("admin"), player("guest", team: .b)]
        )
        #expect(viewModel.isHost)

        delegate.session.currentRoom = JoinRoomResponse(
            room: 1, name: "R", map: .random, settings: 0, capacity: ._2_2,
            players: [player("someoneelse"), player("admin", team: .b)]
        )
        #expect(!viewModel.isHost)
    }

    @Test func exitButtonReturnsToLobbyAndClearsRoom() {
        let (viewModel, delegate) = makeViewModel()
        delegate.session.currentRoom = JoinRoomResponse(room: 1, name: "R", map: .random, settings: 0, capacity: ._1_1, players: [])

        let exit = viewModel.buttons.first { $0.action == .exit }!.rect
        viewModel.handle(.pointerDown(x: exit.x + 5, y: exit.y + 5))

        #expect(delegate.requestedTransitions == [.gameRoomList])
        #expect(delegate.session.currentRoom == nil)
    }

    /// With no live connection the host's Start advances locally so the
    /// screen flow stays walkable offline.
    @Test func startWithoutConnectionAdvancesToLoading() {
        let (viewModel, delegate) = makeViewModel()
        let start = viewModel.buttons.first { $0.action == .readyOrStart }!.rect
        viewModel.handle(.pointerDown(x: start.x + 5, y: start.y + 5))
        #expect(delegate.requestedTransitions == [.loading])
    }

    /// The picker toggle shows the grid; clicking a cell picks that mobile
    /// (offline: applied locally) and closes the picker; the disabled cell
    /// (Aduka) does nothing.
    @Test func pickerSelectsMobiles() {
        let (viewModel, _) = makeViewModel()
        #expect(!viewModel.isPickerVisible)

        let toggle = viewModel.buttons.first { $0.action == .togglePicker }!.rect
        viewModel.handle(.pointerDown(x: toggle.x + 2, y: toggle.y + 2))
        #expect(viewModel.isPickerVisible)

        // Cell 5 = boomer (raw 0x05).
        let cell = ReadyRoomViewModel.pickerCellRect(at: 5)
        viewModel.handle(.pointerDown(x: cell.x + 5, y: cell.y + 5))
        #expect(viewModel.selectedMobile == .boomer)
        #expect(!viewModel.isPickerVisible)

        // Reopen; the disabled cell leaves the selection and stays open.
        viewModel.handle(.pointerDown(x: toggle.x + 2, y: toggle.y + 2))
        let disabled = ReadyRoomViewModel.pickerCellRect(at: ReadyRoomViewModel.pickerDisabledCell)
        viewModel.handle(.pointerDown(x: disabled.x + 5, y: disabled.y + 5))
        #expect(viewModel.selectedMobile == .boomer)
        #expect(viewModel.isPickerVisible)
    }

    /// A game-started push stores the battle data and moves to Loading.
    @Test func gameStartedPushAdvancesToLoading() {
        let (viewModel, delegate) = makeViewModel()
        let start = StartGameNotification(settings: 0, map: .metropolis, players: [], events: 0, commandData: [])
        viewModel.apply(.gameStarted(start))
        #expect(delegate.session.battle == start)
        #expect(delegate.requestedTransitions == [.loading])
    }

    /// Chat pushes append color-typed lines, like the lobby.
    @Test func chatPushesAppendLines() {
        let (viewModel, _) = makeViewModel()
        viewModel.apply(.chatReceived(ChannelChatBroadcast(position: 0, username: "guest", message: "glhf")))
        viewModel.apply(.clientPrint(ClientPrintNotification(message: "match starting soon")))
        #expect(viewModel.chatMessages == [
            ChatLine(sender: "guest", message: "glhf", type: .normal),
            ChatLine(message: "match starting soon", type: .notice),
        ])
    }

    @Test func clampsRosterToMaxPlayers() {
        let (viewModel, delegate) = makeViewModel()
        delegate.session.currentRoom = JoinRoomResponse(room: 1, name: "R", map: .random, settings: 0, capacity: ._4_4, players: [])
        #expect(viewModel.players.count <= ReadyRoomViewModel.maxPlayers)
    }
}
