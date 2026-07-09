import GunBoundProtocol

/// Logic for the Game Room List / channel lobby (state 3) — the busiest
/// screen. On entering, it requests the channel's room list (opcode
/// `0x2100`), displays up to six rooms in a 3-row × 2-column card grid,
/// lets the player highlight one and join it (opcode `0x2110` → Ready Room
/// on success), and drives the confirmed bottom-bar buttons (exit, create,
/// join, view-all/waiting filter, page prev/next, find-friend, direct-go,
/// ranking, buddy, avatar — see `buttons`).
///
/// Grid geometry is taken from the decompiled `RenderRoomCard` (`0x42a220`):
/// two columns at x `0x18`/`0x144`, `roomIndex/3` → column, `roomIndex%3` →
/// row at a `0x3c` (60px) stride, each card blitted at `rowY + 0x3a` — so the
/// grid's first row starts at y 58 and the grid occupies the *top* of the
/// screen. Cards are 257×58 (`gamelist_back.img` frames 1–6 by
/// column/state/joined). All button rects come verbatim from
/// `State03_GameRoomList_CreateButtons` (`0x42aba0`).
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
        /// Confirmed on-screen rect (`State03_GameRoomList_CreateButtons`).
        public let rect: Rect
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
    /// The CHANNEL user-list panel's chrome.
    public let channelBackImageName = "gamelist_channel.img"
    /// The lobby chat panel's chrome.
    public let chatBackImageName = "gamelist_chat.img"

    // MARK: Room-card grid geometry (see the type-level doc comment)
    public static let maxVisibleRooms = 6
    public static let cardSize = (width: Float(257), height: Float(58))
    static let columnX: [Float] = [24, 324]   // decomp Xc: 0x18 / 0x144
    static let gridTop: Float = 58             // decomp: card y = row·0x3c + 0x3a
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

    /// The confirmed button set with verbatim rects from the decompiled
    /// `State03_GameRoomList_CreateButtons` (`0x42aba0`): six 107×45 main
    /// buttons along the bottom bar (y `0x227` = 551, same size/row as Server
    /// Select's), and six 33-tall filter/page buttons in the mid bar just
    /// below the room grid (y `0xf6` = 246). `ranking` is included for
    /// fidelity though the original has no handler for it.
    public let buttons: [Button] = [
        // Bottom bar (y 551, 107×45), left to right.
        Button(id: 0x0, name: "b_gamelist_exit.img", action: .exit, rect: Rect(x: 40, y: 551, width: 107, height: 45)),
        Button(id: 0x1, name: "b_gamelist_buddy.img", action: .buddy, rect: Rect(x: 163, y: 551, width: 107, height: 45)),
        Button(id: 0x2, name: "b_gamelist_ranking.img", action: .ranking, rect: Rect(x: 286, y: 551, width: 107, height: 45)),
        Button(id: 0x3, name: "b_gamelist_avatar.img", action: .avatar, rect: Rect(x: 409, y: 551, width: 107, height: 45)),
        Button(id: 0x4, name: "b_gamelist_create.img", action: .createRoom, rect: Rect(x: 532, y: 551, width: 107, height: 45)),
        Button(id: 0x5, name: "b_gamelist_join.img", action: .joinSelected, rect: Rect(x: 655, y: 551, width: 107, height: 45)),
        // Mid bar (y 246, height 33), below the grid.
        Button(id: 0xa, name: "b_gamelist_viewall.img", action: .viewAll, rect: Rect(x: 42, y: 246, width: 81, height: 33)),
        Button(id: 0xb, name: "b_gamelist_wait.img", action: .waitingOnly, rect: Rect(x: 131, y: 246, width: 81, height: 33)),
        Button(id: 0xc, name: "b_gamelist_prev.img", action: .pagePrev, rect: Rect(x: 242, y: 246, width: 49, height: 33)),
        Button(id: 0xd, name: "b_gamelist_next.img", action: .pageNext, rect: Rect(x: 292, y: 246, width: 49, height: 33)),
        Button(id: 0xe, name: "b_gamelist_friend.img", action: .findFriend, rect: Rect(x: 371, y: 246, width: 81, height: 33)),
        Button(id: 0xf, name: "b_gamelist_directgo.img", action: .directGo, rect: Rect(x: 460, y: 246, width: 81, height: 33)),
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

    /// Channel members shown in the CHANNEL panel — seeded from the join-
    /// channel roster (`0x2001`) and grown by `0x200E` pushes as users join.
    /// Settable so tests/previews can populate it directly.
    public var channelUsers: [String] = []

    /// Channel chat lines shown in the chat panel, oldest first — player
    /// lines fed by `0x201F` broadcasts (which echo the player's own sends
    /// back, so local sends don't append directly) and system lines by
    /// `0x5101` notices, each carrying the decomp's message-type byte for
    /// color-coded rendering. Capped to the most recent `maxChatLines`.
    /// Settable for tests/previews.
    public var chatMessages: [ChatLine] = []

    /// The decomp's chat-log panel embeds a ~4 KB history buffer; a line cap
    /// approximates that bound.
    public static let maxChatLines = 100

    /// The visible page of the room list, in 6-card pages over the fetched
    /// list (Prev/Next buttons). The original re-requests each page from the
    /// server (`0x2100` + page index); our broker returns the whole list in
    /// one reply, so paging is a local window — same UI behaviour, no wire
    /// round-trip.
    public private(set) var page = 0

    /// Task iterating the connection's push stream while this screen is
    /// active.
    private var pushTask: Task<Void, Never>?

    private let delegate: ViewModelDelegate

    public init(delegate: ViewModelDelegate) {
        self.delegate = delegate
    }

    public func onEnter() {
        hoveredButtonIndex = nil
        hoveredRoomIndex = nil
        selectedRoomIndex = nil
        filter = .all
        page = 0
        isJoiningRoom = false
        // Seed the CHANNEL panel from the join-channel roster, then keep it
        // (and the room grid) live from the connection's push stream.
        if let channel = delegate.session.channel {
            channelUsers = channel.users.map { String(describing: $0.username) }
        }
        startObservingPushes()
        loadRooms()
    }

    public func onExit() {
        hoveredButtonIndex = nil
        hoveredRoomIndex = nil
        selectedRoomIndex = nil
        pushTask?.cancel()
        pushTask = nil
    }

    public func update(deltaTime: Double) {}

    // MARK: - Server pushes

    /// Forwards the connection's unsolicited notifications into `apply(_:)`
    /// while this screen is active.
    private func startObservingPushes() {
        guard pushTask == nil, let client = delegate.client else { return }
        pushTask = Task { [weak self] in
            for await push in await client.pushes {
                guard let self, !Task.isCancelled else { return }
                self.apply(push)
            }
        }
    }

    /// Applies one server push to the lobby's state — split out from the
    /// stream loop so tests can drive it directly.
    public func apply(_ push: ServerPush) {
        switch push {
        case .roomUpdated, .roomPlayerLeft:
            // A room changed somewhere in the channel; re-request the list
            // (the wire notification carries no per-room fields to patch).
            loadRooms()
        case .userJoinedChannel(let notification):
            channelUsers.append(String(describing: notification.username))
        case .chatReceived(let broadcast):
            appendChat(ChatLine(
                sender: String(describing: broadcast.username),
                message: broadcast.message,
                type: .normal
            ))
        case .clientPrint(let notice):
            appendChat(ChatLine(message: notice.message, type: .notice))
        case .gameStarted:
            break  // only meaningful inside a room (Ready Room handles it)
        case .raw:
            break
        }
    }

    private func appendChat(_ line: ChatLine) {
        chatMessages.append(line)
        if chatMessages.count > Self.maxChatLines {
            chatMessages.removeFirst(chatMessages.count - Self.maxChatLines)
        }
    }

    /// Sends a channel chat line (`0x2010`, encrypted). Fire-and-forget: the
    /// line appears when the server's `0x201F` broadcast echoes it back —
    /// the same round-trip the original client renders from.
    public func sendChat(_ message: String) {
        let trimmed = message.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, let client = delegate.client else { return }
        Task {
            do {
                try await client.send(ChannelChatCommand(message: trimmed))
            } catch {
                print("[GunBound] couldn't send chat: \(error)")
            }
        }
    }

    // MARK: - Room grid

    /// Rooms passing the View All / Waiting filter — the list Prev/Next
    /// pages over.
    private var filteredRooms: [RoomListResponse.Room] {
        filter == .waitingOnly ? rooms.filter { !$0.isPlaying } : rooms
    }

    /// Total 6-card pages the filtered list occupies (at least 1).
    public var pageCount: Int {
        max(1, (filteredRooms.count + Self.maxVisibleRooms - 1) / Self.maxVisibleRooms)
    }

    /// The rooms actually shown: the filter applied, then the current page's
    /// window of six cards.
    public var visibleRooms: [RoomListResponse.Room] {
        Array(filteredRooms.dropFirst(page * Self.maxVisibleRooms).prefix(Self.maxVisibleRooms))
    }

    /// Steps the visible page (the Prev / Next buttons), clamped to the
    /// filtered list's page count. Selection clears because card slots now
    /// show different rooms.
    public func step(page delta: Int) {
        let newPage = min(max(0, page + delta), pageCount - 1)
        guard newPage != page else { return }
        page = newPage
        selectedRoomIndex = nil
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
        case .pagePrev:
            step(page: -1)
        case .pageNext:
            step(page: 1)
        case .ranking, .findFriend:
            // Find-friend needs buddy data that isn't wired up; `ranking` has
            // no handler in the original build either.
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
        page = 0                 // the filtered list re-paginates from the top
        selectedRoomIndex = nil  // indices shift when the visible set changes
    }

    // MARK: - Networking

    /// Requests the channel room list (opcode `0x2100`) — the lobby's
    /// `OnEnter` behaviour, also re-run whenever a room-update push arrives.
    /// No-op (leaves the list empty) if there's no live connection, e.g. when
    /// the lobby was reached without a real login, or while a fetch is
    /// already in flight (a burst of pushes coalesces into one refresh).
    private func loadRooms() {
        guard !isLoadingRooms, let client = delegate.client else { return }
        isLoadingRooms = true
        Task {
            defer { isLoadingRooms = false }
            do {
                self.rooms = try await client.fetchRoomList()
                // The list may have shrunk below the current page.
                self.page = min(self.page, self.pageCount - 1)
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
