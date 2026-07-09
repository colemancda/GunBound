import GunBoundProtocol

/// Logic for the pre-battle Ready Room (state 9) — roster, map, the
/// character/mobile picker, team change, ready/start, and room chat.
///
/// Geometry and the button set come from the decompiled
/// `State09_ReadyRoom_OnEnter` (`0x4d6810`) and command dispatcher
/// (`State09_ReadyRoom_OnCommand`, `0x4d54e0`; `docs/screens/09_ready_room.md`):
/// the bottom bar reuses the lobby's 107×45 buttons at y `0x227` (551) —
/// exit 40, buddy 163, change-team 532, and ready **or** start at 655 (the
/// original creates Start for the host and Ready for guests in the same
/// slot). The character picker is a 5-column grid of 66×50 cells at
/// `(i%5)·0x42+0x21, (i/5)·0x32+0x184` — 15 cells covering the 14 standard
/// mobiles (cell 13, Aduka, disabled in this build) plus random — shown over
/// the chat area as a mode; clicking one sends `0x3200`.
///
/// Wire actions (all decomp-confirmed opcodes): ready `0x3230`, start (host)
/// `0x3430` → everyone moves to Loading on the `0x3432` push, change team
/// `0x3210`, select mobile `0x3200`. Room chat diverges: the decomp's
/// ready-room chat commit sends `0x3104`, but our server assigns that opcode
/// to room-title changes (the community SVC name), so chat reuses the channel
/// path (`0x2010`/`0x201F`) — room members are in the channel, so the
/// round-trip works; lines just aren't room-scoped.
@MainActor
public final class ReadyRoomViewModel: ScreenViewModel {

    public enum ButtonAction: Equatable, Sendable {
        case exit          // id 3 → leave the room (decomp sends 0x2000)
        case buddy         // id 300 → shared buddy panel
        case changeTeam    // id 2 → 0x3210
        case readyOrStart  // id 0/1 → 0x3230 (guest) / 0x3430 (host)
        case togglePicker  // id 500 → show/hide the character picker
    }

    public struct Button: Equatable, Sendable {
        public let id: Int
        public let action: ButtonAction
        /// Confirmed on-screen rect (`State09_ReadyRoom_OnEnter`).
        public let rect: Rect
    }

    public let backgroundImageName = "ready_back.img"
    /// The Ready Room continues `channel.mp3` too — `State09_ReadyRoom_OnEnter`
    /// makes the same `PlayMusicTrack` call as the lobby/Server Select.
    public let musicName: String? = "channel.mp3"
    public let loopMusic = true
    /// 22 map thumbnails (136×84), indexed by map.
    public let mapThumbImageName = "ready_selectmap.img"
    /// 17 character portraits (113×146) for the picker/preview.
    public let characterImageName = "ready_selectcharacter.img"
    public let readyButtonImageName = "b_ready_ready.img"
    public let startButtonImageName = "b_ready_startgame.img"
    public let teamButtonImageName = "b_ready_changeteam.img"
    public let exitButtonImageName = "b_ready_exit.img"
    public let buddyButtonImageName = "b_ready_buddy.img"

    /// The bottom-bar buttons at the decomp rects, plus the picker toggle
    /// (id 500 at (0x25, 0x16b), the chat panel's top-left corner).
    public let buttons: [Button] = [
        Button(id: 3, action: .exit, rect: Rect(x: 40, y: 551, width: 107, height: 45)),
        Button(id: 300, action: .buddy, rect: Rect(x: 163, y: 551, width: 107, height: 45)),
        Button(id: 2, action: .changeTeam, rect: Rect(x: 532, y: 551, width: 107, height: 45)),
        Button(id: 0, action: .readyOrStart, rect: Rect(x: 655, y: 551, width: 107, height: 45)),
        Button(id: 500, action: .togglePicker, rect: Rect(x: 37, y: 363, width: 25, height: 20)),
    ]

    // MARK: Character picker grid (decomp: (i%5)·0x42+0x21, (i/5)·0x32+0x184)
    public static let pickerColumns = 5
    public static let pickerCellSize = (width: Float(66), height: Float(50))
    public static let pickerOrigin = (x: Float(0x21), y: Float(0x184))
    /// 15 grid cells; the decomp disables cell 13 (Aduka).
    public static let pickerCellCount = 15
    public static let pickerDisabledCell = 13

    /// Whether the character picker is shown (over the chat area), toggled
    /// by button 500 — the decomp swaps these panels in the same region.
    public private(set) var isPickerVisible = false

    // MARK: Roster grid (2 rows × 2 columns each side of the center panel —
    // positions eyeballed from ready_back.img's slot art; the decomp's
    // roster renderer (`FUN_004d7db0`) positions aren't extracted yet)
    public static let maxPlayers = 8
    static let rosterSlotSize = (width: Float(140), height: Float(130))
    static let rosterColumnX: [Float] = [36, 177, 497, 637]
    static let rosterRowY: [Float] = [58, 200]

    /// The center map panel's thumbnail slot (the orange panel between the
    /// roster halves; its scroll arrows are the confirmed (324,97)/(457,97)).
    public static let mapThumbRect = Rect(x: 332, y: 65, width: 136, height: 84)

    public private(set) var isReady = false
    public private(set) var isBusy = false
    public private(set) var hoveredButtonIndex: Int?

    /// The player's selected mobile (the character picker); `.random` until
    /// chosen, mirroring the original's default.
    public private(set) var selectedMobile: Mobile = .random

    /// Players currently readied. Own state is tracked from `0x3231` acks;
    /// other players' bits need a per-player ready notification our server
    /// doesn't emit yet, so in practice this holds self only.
    public var readyPlayers: Set<String> = []

    /// Room chat lines (see the type-level note on the chat opcode).
    public var chatMessages: [ChatLine] = []
    public static let maxChatLines = 100

    private var pushTask: Task<Void, Never>?

    private let delegate: ViewModelDelegate

    public init(delegate: ViewModelDelegate) {
        self.delegate = delegate
    }

    /// The joined room's name, or empty if the room isn't known.
    public var roomName: String { delegate.session.currentRoom?.name ?? "" }

    /// The selected map for this room.
    public var map: GameMap { delegate.session.currentRoom?.map ?? .random }

    /// The roster from the join response (up to `maxPlayers`).
    public var players: [JoinRoomResponse.PlayerSession] {
        Array((delegate.session.currentRoom?.players ?? []).prefix(Self.maxPlayers))
    }

    /// Whether this client is the room host (slot 0) — hosts get the Start
    /// button where guests get Ready, matching the original's same-slot swap.
    public var isHost: Bool {
        guard let first = players.first else { return true }  // empty room → creator
        return String(describing: first.username) == delegate.network.username
    }

    /// The on-screen rect of roster slot `index` (0..<`maxPlayers`) — 2×2 on
    /// each side of the center panel.
    public func rosterSlotRect(at index: Int) -> Rect {
        Rect(
            x: Self.rosterColumnX[index % Self.rosterColumnX.count],
            y: Self.rosterRowY[(index / Self.rosterColumnX.count) % Self.rosterRowY.count],
            width: Self.rosterSlotSize.width,
            height: Self.rosterSlotSize.height
        )
    }

    /// The picker cell rect for cell `index` (0..<`pickerCellCount`).
    public static func pickerCellRect(at index: Int) -> Rect {
        Rect(
            x: pickerOrigin.x + Float(index % pickerColumns) * pickerCellSize.width,
            y: pickerOrigin.y + Float(index / pickerColumns) * pickerCellSize.height,
            width: pickerCellSize.width,
            height: pickerCellSize.height
        )
    }

    public func onEnter() {
        isReady = false
        isBusy = false
        isPickerVisible = false
        hoveredButtonIndex = nil
        selectedMobile = .random
        readyPlayers = []
        startObservingPushes()
    }

    public func onExit() {
        isBusy = false
        pushTask?.cancel()
        pushTask = nil
    }

    public func update(deltaTime: Double) {}

    // MARK: - Server pushes

    private func startObservingPushes() {
        guard pushTask == nil, let client = delegate.client else { return }
        pushTask = Task { [weak self] in
            for await push in await client.pushes {
                guard let self, !Task.isCancelled else { return }
                self.apply(push)
            }
        }
    }

    /// Applies one server push — split out so tests can drive it directly.
    public func apply(_ push: ServerPush) {
        switch push {
        case .gameStarted(let start):
            // The 0x3432 start notification moves everyone to Loading.
            delegate.session.battle = start
            delegate.requestTransition(to: .loading)
        case .chatReceived(let broadcast):
            appendChat(ChatLine(
                sender: String(describing: broadcast.username),
                message: broadcast.message,
                type: .normal
            ))
        case .clientPrint(let notice):
            appendChat(ChatLine(message: notice.message, type: .notice))
        case .roomUpdated, .roomPlayerLeft, .userJoinedChannel, .raw:
            break
        }
    }

    private func appendChat(_ line: ChatLine) {
        chatMessages.append(line)
        if chatMessages.count > Self.maxChatLines {
            chatMessages.removeFirst(chatMessages.count - Self.maxChatLines)
        }
    }

    // MARK: - Input

    public func handle(_ event: ScreenInputEvent) {
        switch event {
        case .pointerMoved(let x, let y):
            hoveredButtonIndex = buttons.firstIndex { $0.rect.contains(x: x, y: y) }

        case .pointerDown(let x, let y):
            guard !isBusy else { return }
            if isPickerVisible,
               let cell = (0..<Self.pickerCellCount).first(where: { Self.pickerCellRect(at: $0).contains(x: x, y: y) }) {
                selectMobile(at: cell)
                return
            }
            if let index = buttons.firstIndex(where: { $0.rect.contains(x: x, y: y) }) {
                handleButton(buttons[index].action)
            }

        case .activate, .text, .key:
            break
        }
    }

    private func handleButton(_ action: ButtonAction) {
        switch action {
        case .exit:
            leaveRoom()
        case .changeTeam:
            changeTeam()
        case .readyOrStart:
            isHost ? startGame() : toggleReady()
        case .togglePicker:
            isPickerVisible.toggle()
        case .buddy:
            print("[GunBound] ready-room buddy panel not wired yet")
        }
    }

    /// Sends a room chat line (see the type-level note on the opcode).
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

    // MARK: - Actions

    /// Picker cell `index` → `Mobile(rawValue: index)` → `0x3200`. Cell 13
    /// (Aduka) is disabled as in the original; the last cell maps to random
    /// (the dispatcher's `0x72` → `0x3200` with `0xff`).
    private func selectMobile(at index: Int) {
        guard index != Self.pickerDisabledCell else { return }
        let mobile = index == Self.pickerCellCount - 1
            ? Mobile.random
            : (Mobile(rawValue: UInt8(index)) ?? .random)
        isPickerVisible = false
        guard let client = delegate.client else {
            selectedMobile = mobile  // offline/preview: apply locally
            return
        }
        isBusy = true
        Task {
            defer { isBusy = false }
            do {
                _ = try await client.selectTank(primary: mobile)
                selectedMobile = mobile
            } catch {
                print("[GunBound] couldn't select mobile: \(error)")
            }
        }
    }

    /// Toggles the player's own team (`0x3210`) — a/b flips, matching the
    /// original's Change Team button.
    private func changeTeam() {
        guard let client = delegate.client else { return }
        let username = delegate.network.username
        let current = players.first { String(describing: $0.username) == username }?.team ?? .a
        let next: Team = current == .a ? .b : .a
        isBusy = true
        Task {
            defer { isBusy = false }
            do {
                _ = try await client.selectTeam(next)
            } catch {
                print("[GunBound] couldn't change team: \(error)")
            }
        }
    }

    /// Guest ready toggle (`0x3230`).
    private func toggleReady() {
        guard let client = delegate.client else {
            isReady.toggle()  // offline/preview
            return
        }
        isBusy = true
        Task {
            defer { isBusy = false }
            do {
                let response = try await client.setReady(!isReady)
                if response.isSuccess {
                    isReady.toggle()
                    let username = delegate.network.username
                    if isReady { readyPlayers.insert(username) } else { readyPlayers.remove(username) }
                }
            } catch {
                print("[GunBound] couldn't set ready: \(error)")
            }
        }
    }

    /// Host start (`0x3430`) — fire-and-forget; the `0x3432` push transitions
    /// everyone (this client included) to Loading. Offline it advances
    /// locally so the flow stays walkable without a server.
    private func startGame() {
        guard let client = delegate.client else {
            delegate.requestTransition(to: .loading)
            return
        }
        isBusy = true
        Task {
            defer { isBusy = false }
            do {
                try await client.startGame()
            } catch {
                print("[GunBound] couldn't start game: \(error)")
            }
        }
    }

    /// Leaves the room back to the lobby, clearing the session's current room.
    private func leaveRoom() {
        delegate.session.currentRoom = nil
        delegate.requestTransition(to: .gameRoomList)
    }
}
