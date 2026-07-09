import GunBoundProtocol

/// Logic for the Game Room List / channel lobby (state 3) — the busiest
/// screen. On entering, it requests the channel's room list (opcode
/// `0x2100`), displays up to six rooms in a 3-row × 2-column card grid,
/// lets the player highlight one and join it (opcode `0x2110` → Ready Room
/// on success), and drives the confirmed bottom-bar buttons (exit, create,
/// join, view-all/waiting filter, page prev/next, find-friend, direct-go,
/// ranking, buddy, avatar — see `buttons`).
///
/// Grid geometry is taken from the decompiled `RenderRoomLabel`/`FUN_0042a220`
/// (`docs/screens/03_game_room_list.md`): two columns at x `0x18`/`0x144`,
/// `roomIndex/3` → column, `roomIndex%3` → row at a `0x3c` (60px) stride,
/// cards `257×58` (frames 1–3 of `gamelist_back.img`: base / highlighted /
/// joined). The room grid's vertical origin isn't given in the decomp, so
/// `gridTop` is estimated from where `gamelist_back.img`'s content region
/// begins; hit-testing and drawing share it, so interaction stays consistent
/// regardless.
@MainActor
public final class GameRoomListViewModel: ScreenViewModel {

    /// The confirmed bottom-bar button actions, keyed to the decompiled
    /// command dispatcher's `buttonId`s (`FUN_004285c0`,
    /// `docs/screens/03_game_room_list.md`).
    public enum ButtonAction: Equatable, Sendable {
        case exit          // id 0x0 → Server Select (ChangeGameState(2))
        case buddy         // id 0x1 → (re)build buddy-list panel
        case ranking       // id 0x2 → no case in this build (genuinely a no-op)
        case avatar        // id 0x3 → Avatar Store (sends 0x6000)
        case createRoom    // id 0x4 → open the Create Room dialog
        case joinSelected  // id 0x5 → join the highlighted room (0x2110)
        case viewAll       // id 0xa → filter: all rooms (0x2100 mode 1)
        case waitingOnly   // id 0xb → filter: waiting-only (0x2100 mode 2)
        case pagePrev      // id 0xc → previous page
        case pageNext      // id 0xd → next page
        case findFriend    // id 0xe → jump to a buddy's room
        case directGo      // id 0xf → open "enter room by number" dialog
    }

    public struct Button: Equatable, Sendable {
        /// The decompiled dispatcher's `buttonId`.
        public let id: Int
        public let name: String
        public let action: ButtonAction
        public var rect: Rect = .zero
    }

    /// Waiting / in-progress / full — chooses the per-card status icon
    /// (frames 7 / 8 / 9 of `gamelist_back.img`, per the decomp).
    public enum RoomStatus: Sendable {
        case waiting
        case playing
        case full
    }

    /// The room-list filter the View All / Waiting buttons toggle. The real
    /// client re-requests a filtered page from the server (`0x2100` mode
    /// byte); with our single-page broker we apply it locally instead.
    public enum RoomFilter: Equatable, Sendable {
        case all
        case waitingOnly
    }

    public let backgroundImageName = "gamelist_back.img"
    /// The shared buddy panel's chrome and its Add / Del / close-X buttons.
    public let buddyBackImageName = "buddy_back.img"
    public let buddyAddImageName = "b_buddy_plus.img"
    public let buddyDelImageName = "b_buddy_del.img"
    public let buddyCloseImageName = "b_buddy_exit.img"
    /// The Create Room / Enter-Room-By-Number dialog chrome and their shared
    /// OK (`yes`) / Cancel (`no`) buttons.
    public let createBackImageName = "gamelist_create.img"
    public let directGoBackImageName = "gamelist_directgo.img"
    public let dialogOKImageName = "b_gamelist_yes.img"
    public let dialogCancelImageName = "b_gamelist_no.img"

    // MARK: Room-card grid geometry (see the type-level doc comment)
    public static let maxVisibleRooms = 6
    public static let cardSize = (width: Float(257), height: Float(58))
    static let columnX: [Float] = [24, 324]   // decomp Xc: 0x18 / 0x144
    static let gridTop: Float = 290
    static let rowStride: Float = 60           // decomp Yr pitch: 0x3c

    // Card-relative icon anchors, from `RenderRoomCard` (`0x42a220`): each
    // element's blit origin minus the card background's own origin
    // `(Xc, Yr+0x3a)`. All icons live as extra frames of `gamelist_back.img`
    // (frames 7–9 status, 10–13 game-mode label, 15 padlock). Frame 14 (small
    // icon) and the flag icons (frames from per-room byte flags) have no field
    // in `RoomListResponse.Room`, so they're not drawn.
    public static let statusIconOffset = (x: Float(0x13), y: Float(0x55 - 0x3a))  // (19, 27)
    public static let modeIconOffset = (x: Float(0xb1), y: Float(0x5b - 0x3a))    // (177, 33)
    public static let lockIconOffsetY = Float(0x52 - 0x3a)                        // 24
    /// The padlock sits 6px further left in the right column (decomp's
    /// `0xea - 6` for `slot/3 != 0`).
    public static func lockIconX(rightColumn: Bool) -> Float { rightColumn ? Float(0xea - 6) : Float(0xea) }

    /// The confirmed bottom-bar button set (`b_gamelist_*` images, decomp
    /// `buttonId`s). Exact on-screen positions aren't decomp-confirmed, so
    /// the view lays them out itself and pushes the rects back via
    /// `setRect`. `ranking` is included for fidelity though the original has
    /// no handler for it.
    public private(set) var buttons: [Button] = [
        Button(id: 0x0, name: "b_gamelist_exit.img", action: .exit),
        Button(id: 0x4, name: "b_gamelist_create.img", action: .createRoom),
        Button(id: 0x5, name: "b_gamelist_join.img", action: .joinSelected),
        Button(id: 0xf, name: "b_gamelist_directgo.img", action: .directGo),
        Button(id: 0xa, name: "b_gamelist_viewall.img", action: .viewAll),
        Button(id: 0xb, name: "b_gamelist_wait.img", action: .waitingOnly),
        Button(id: 0xc, name: "b_gamelist_prev.img", action: .pagePrev),
        Button(id: 0xd, name: "b_gamelist_next.img", action: .pageNext),
        Button(id: 0xe, name: "b_gamelist_friend.img", action: .findFriend),
        Button(id: 0x2, name: "b_gamelist_ranking.img", action: .ranking),
        Button(id: 0x1, name: "b_gamelist_buddy.img", action: .buddy),
        Button(id: 0x3, name: "b_gamelist_avatar.img", action: .avatar),
    ]

    /// The active room-list filter (View All / Waiting bottom-bar buttons).
    public private(set) var filter: RoomFilter = .all

    /// Rooms from the most recent `0x2103` room-list response — the full
    /// fetched list (`visibleRooms` applies the filter and page cap for
    /// display). Settable so tests and SwiftUI previews can populate it
    /// directly — the production path fills it from `delegate.client`, which
    /// is a concrete socket type that can't be mocked at this layer.
    public var rooms: [RoomListResponse.Room] = []

    public private(set) var hoveredButtonIndex: Int?
    public private(set) var hoveredRoomIndex: Int?
    /// The highlighted room card (`this+8` in the decomp) — set by clicking a
    /// card, joined via the Join button.
    public private(set) var selectedRoomIndex: Int?
    public private(set) var isLoadingRooms = false
    public private(set) var isJoiningRoom = false

    /// Whether the shared buddy-list panel is open — the BUDDY button
    /// (`b_gamelist_buddy`, id 1) toggles it, matching the decomp's
    /// `BuildBuddyPanel` (a singleton that's shown/hidden, not rebuilt).
    public private(set) var isBuddyPanelVisible = false

    /// Which modal dialog (if any) is open — CREATE opens the Create Room
    /// dialog, DIRECT-GO the enter-room-by-number dialog.
    public private(set) var isCreateRoomDialogVisible = false
    public private(set) var isEnterNumberDialogVisible = false

    /// The player's buddies. No `0x1010`-family buddy-list packet is wired up
    /// yet, so this stays empty (the panel opens showing an empty list) until
    /// that protocol path exists — settable so tests/previews can populate it.
    public var buddies: [String] = []

    private let delegate: ViewModelDelegate

    public init(delegate: ViewModelDelegate) {
        self.delegate = delegate
    }

    public func onEnter() {
        hoveredButtonIndex = nil
        hoveredRoomIndex = nil
        selectedRoomIndex = nil
        filter = .all
        isJoiningRoom = false
        loadRooms()
    }

    public func onExit() {
        hoveredButtonIndex = nil
        hoveredRoomIndex = nil
        selectedRoomIndex = nil
    }

    public func update(deltaTime: Double) {}

    /// The view calls this once it knows the loaded texture's size for the
    /// button at `index` (buttons are laid out left-to-right by the view;
    /// this view model only stores the resulting hit-testing rect).
    public func setRect(_ rect: Rect, forButtonAt index: Int) {
        guard buttons.indices.contains(index) else { return }
        buttons[index].rect = rect
    }

    // MARK: - Room grid

    /// The rooms actually shown on the current page: the filter applied,
    /// then capped to the six on-screen cards.
    public var visibleRooms: [RoomListResponse.Room] {
        let filtered = filter == .waitingOnly ? rooms.filter { !$0.isPlaying } : rooms
        return Array(filtered.prefix(Self.maxVisibleRooms))
    }

    /// Number of room cards currently visible.
    public var visibleRoomCount: Int { visibleRooms.count }

    /// The on-screen rect of the room card at `index` (0..<`maxVisibleRooms`).
    public func roomRect(at index: Int) -> Rect {
        let column = index / 3
        let row = index % 3
        return Rect(
            x: Self.columnX[column],
            y: Self.gridTop + Float(row) * Self.rowStride,
            width: Self.cardSize.width,
            height: Self.cardSize.height
        )
    }

    /// Status of a room, for picking its status icon.
    public func status(of room: RoomListResponse.Room) -> RoomStatus {
        if room.isPlaying { return .playing }
        return room.playerCount >= room.capacity.rawValue ? .full : .waiting
    }

    /// The visible slot the player's own joined room occupies, if it's on this
    /// page — the decomp's `this+4`, which shifts a card to its joined frame.
    public var joinedRoomIndex: Int? {
        guard let joined = delegate.session.currentRoom else { return nil }
        return visibleRooms.firstIndex { $0.id == joined.room }
    }

    /// The card-background frame for a visible slot (`RenderRoomCard`): base
    /// `1` (left column) / `4` (right column), `+2` when it's the joined room
    /// (`this+4`), else `+1` when it's the highlighted/hovered room (`this+8`)
    /// → frames 1–6 of `gamelist_back.img`.
    public func cardFrame(forVisibleSlot slot: Int) -> Int {
        var frame = slot / 3 == 0 ? 1 : 4
        if joinedRoomIndex == slot {
            frame += 2
        } else if selectedRoomIndex == slot || hoveredRoomIndex == slot {
            frame += 1
        }
        return frame
    }

    /// The status-icon frame: PLAY `7` / FULL `8` / WAIT `9`.
    public func statusFrame(of room: RoomListResponse.Room) -> Int {
        switch status(of: room) {
        case .playing: return 7
        case .full: return 8
        case .waiting: return 9
        }
    }

    /// The game-mode label frame (SOLO / SCORE / TAG / JEWEL), mirroring
    /// `RenderRoomCard`'s `(info >> 0x12 & 3) + 10` via the typed
    /// `RoomSettings` bitmask.
    public func modeFrame(of room: RoomListResponse.Room) -> Int {
        10 + room.roomSettings.modeLabelIndex
    }

    // MARK: - Input

    public func handle(_ event: ScreenInputEvent) {
        switch event {
        case .pointerMoved(let x, let y):
            hoveredRoomIndex = (0..<visibleRoomCount).first { roomRect(at: $0).contains(x: x, y: y) }
            hoveredButtonIndex = buttons.firstIndex { $0.rect.contains(x: x, y: y) }

        case .pointerDown(let x, let y):
            if let roomIndex = (0..<visibleRoomCount).first(where: { roomRect(at: $0).contains(x: x, y: y) }) {
                selectedRoomIndex = roomIndex
                return
            }
            guard let index = buttons.firstIndex(where: { $0.rect.contains(x: x, y: y) }) else { return }
            handleButton(buttons[index].action)

        case .activate, .text, .key:
            break
        }
    }

    private func handleButton(_ action: ButtonAction) {
        switch action {
        case .exit:
            delegate.requestTransition(to: .serverSelect)
        case .avatar:
            delegate.requestTransition(to: .avatarShop)
        case .createRoom:
            // Open the Create Room dialog (name/password/capacity → 0x2120).
            isCreateRoomDialogVisible = true
            isEnterNumberDialogVisible = false
        case .directGo:
            // Open the enter-room-by-number dialog (→ 0x2110 by number).
            isEnterNumberDialogVisible = true
            isCreateRoomDialogVisible = false
        case .joinSelected:
            joinSelectedRoom()
        case .viewAll:
            setFilter(.all)
        case .waitingOnly:
            setFilter(.waitingOnly)
        case .buddy:
            // Toggle the shared buddy-list panel (BuildBuddyPanel is shown or
            // hidden, not rebuilt each click).
            setBuddyPanelVisible(!isBuddyPanelVisible)
        case .ranking, .pagePrev, .pageNext, .findFriend:
            // Page nav and find-friend aren't wired up (single-page broker);
            // `ranking` has no handler in the original build either.
            print("[GunBound] room-list action not implemented: \(action)")
        }
    }

    /// Dismisses whichever room dialog is open (Cancel).
    public func dismissDialogs() {
        isCreateRoomDialogVisible = false
        isEnterNumberDialogVisible = false
    }

    /// Creates a room (`0x2120`) and, on success, joins it (`0x2110` by the
    /// returned id) so the client enters its Ready Room — the decomp's
    /// create-then-enter flow.
    public func createRoom(name: String, password: String, capacity: RoomCapacity) {
        guard !isJoiningRoom, let client = delegate.client else { return }
        isCreateRoomDialogVisible = false
        isJoiningRoom = true
        let roomPassword = RoomPassword(rawValue: password) ?? RoomPassword()
        Task {
            defer { isJoiningRoom = false }
            do {
                let created = try await client.createRoom(name: name, password: roomPassword, capacity: capacity)
                let response = try await client.joinRoom(created.room, password: roomPassword)
                if response.isSuccess {
                    print("[GunBound] created + joined room \(created.room)")
                    delegate.session.currentRoom = response
                    delegate.requestTransition(to: .readyRoom)
                } else {
                    print("[GunBound] created room \(created.room) but join was rejected")
                }
            } catch {
                print("[GunBound] couldn't create room: \(error)")
            }
        }
    }

    /// Joins a room by its typed number (`0x2110`), entering its Ready Room on
    /// success.
    public func joinRoomByNumber(_ number: Int) {
        guard !isJoiningRoom, let client = delegate.client else { return }
        isEnterNumberDialogVisible = false
        isJoiningRoom = true
        let room = RoomID(rawValue: UInt16(clamping: number))
        Task {
            defer { isJoiningRoom = false }
            do {
                let response = try await client.joinRoom(room)
                if response.isSuccess {
                    delegate.session.currentRoom = response
                    delegate.requestTransition(to: .readyRoom)
                } else {
                    print("[GunBound] join-by-number rejected for room \(room)")
                }
            } catch {
                print("[GunBound] couldn't join room \(room): \(error)")
            }
        }
    }

    /// Closes the buddy panel (its close-X button).
    public func dismissBuddyPanel() {
        setBuddyPanelVisible(false)
    }

    /// Shows or hides the buddy panel — the toggle path, also used by
    /// previews/tests to open it directly.
    public func setBuddyPanelVisible(_ visible: Bool) {
        isBuddyPanelVisible = visible
    }

    private func setFilter(_ newFilter: RoomFilter) {
        guard filter != newFilter else { return }
        filter = newFilter
        selectedRoomIndex = nil  // indices shift when the visible set changes
    }

    // MARK: - Networking

    /// Requests the channel room list (opcode `0x2100`) — the lobby's
    /// `OnEnter` behaviour. No-op (leaves the list empty) if there's no live
    /// connection, e.g. when the lobby was reached without a real login.
    private func loadRooms() {
        guard let client = delegate.client else { return }
        isLoadingRooms = true
        Task {
            defer { isLoadingRooms = false }
            do {
                self.rooms = try await client.fetchRoomList()
                print("[GunBound] room list: \(self.rooms.count) room(s)")
            } catch {
                print("[GunBound] couldn't fetch room list: \(error)")
            }
        }
    }

    /// Joins the highlighted room (opcode `0x2110`); on a successful
    /// `JoinRoomResponse` the client transitions into the room's Ready Room.
    private func joinSelectedRoom() {
        let visible = visibleRooms
        guard !isJoiningRoom, let index = selectedRoomIndex, visible.indices.contains(index),
              let client = delegate.client else { return }
        let room = visible[index]
        isJoiningRoom = true
        Task {
            defer { isJoiningRoom = false }
            do {
                let response = try await client.joinRoom(room.id)
                if response.isSuccess {
                    print("[GunBound] joined room \(room.id) '\(room.name)' (\(response.players.count) player(s))")
                    delegate.session.currentRoom = response
                    delegate.requestTransition(to: .readyRoom)
                } else {
                    print("[GunBound] room join rejected for \(room.id)")
                }
            } catch {
                print("[GunBound] couldn't join room \(room.id): \(error)")
            }
        }
    }
}
