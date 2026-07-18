import GunBoundProtocol

/// Logic for Server / Channel select (state 2) — owns the connect/login
/// flow: real GunBound looks up the world-server list from a broker/
/// directory server first, falling back to a manually configured
/// server/port directly (e.g. for a standalone `GunBoundServer world` with
/// no broker running) if the broker can't be reached or has no enabled
/// servers, then runs the nonce + login handshake against whichever server
/// it lands on.
///
/// Button positions are **confirmed**, not guessed: decompiling
/// `State02_ServerSelect_OnEnter` (`0x4e14b0`) found its three
/// `CreateButtonWidget` calls with explicit x/y/width/height args —
/// `b_server_exitgame` at (40, 551), `b_server_buddygame` at (163, 551),
/// `b_server_choiceserver` at (409, 551), all 107×45 — so those are used
/// verbatim here rather than computed from loaded-texture size.
///
/// `server_list.img`'s own on-screen position isn't decomp-confirmed (no
/// decompiled code path references it by name), but it's visually
/// unambiguous: `server_back.img` already has a full "WORLD LIST" panel
/// baked in (its empty/placeholder-character-art state — same border, title
/// bar, and scrollbar), and `server_list.img` is a second, identically-sized
/// (546×530) rendering of that *same* panel in its populated-with-servers
/// state. They're two states of one panel meant to overlay exactly, not a
/// background plus a separately-placed overlay — so `panelRect`'s origin is
/// `server_back.img`'s own panel position, (11,13), found by comparing the
/// two images' border-region pixels across candidate offsets and taking the
/// minimum difference (a clean, isolated best match), not eyeballed or
/// centered.
@MainActor
public final class ServerSelectViewModel: ScreenViewModel {
    
    public struct Button: Equatable, Sendable {
        public let name: String
        public let rect: Rect
    }

    public let backgroundImageName = "server_back.img"
    public let panelImageName = "server_list.img"
    public let waitImageName = "waitmessage.img"
    /// The shared error dialog's panel chrome and OK-button artwork.
    public let errorBackImageName = "error_back.img"
    public let errorConfirmImageName = "b_error_confirm.img"
    /// The shared buddy panel's chrome and its Add / Del / close-X buttons
    /// (the same `BuildBuddyPanel` singleton every screen shows).
    public let buddyBackImageName = "buddy_back.img"
    public let buddyAddImageName = "b_buddy_plus.img"
    public let buddyDelImageName = "b_buddy_del.img"
    public let buddyCloseImageName = "b_buddy_exit.img"
    public let musicName: String? = "channel.mp3"
    public let loopMusic = true

    /// The three bottom-bar buttons at confirmed positions (see the
    /// type-level doc comment), plus the WORLD LIST panel's own two buttons.
    /// `BuildWorldListPanel` (`0x5099d0`) creates View All / Friends via
    /// `CreateLabelWidget` with panel-relative rects: View All at
    /// (0x145, 0x1eb, 0x4a, 0x1a) = (325, 491, 74×26), Friends at
    /// (0x1a3, 0x1eb, 0x4a, 0x1a) = (419, 491, 74×26). The panel is placed
    /// at (0xb, 0xd) = (11, 13), so the screen-absolute rects add that
    /// origin (matching the buddy-panel precedent where child coords are
    /// panel-relative and the widget system adds the parent origin at draw
    /// and hit-test time).
    public let buttons: [Button] = [
        Button(name: "b_server_exitgame.img", rect: Rect(x: 40, y: 551, width: 107, height: 45)),
        Button(name: "b_server_buddygame.img", rect: Rect(x: 163, y: 551, width: 107, height: 45)),
        Button(name: "b_server_choiceserver.img", rect: Rect(x: 409, y: 551, width: 107, height: 45)),
        // View All / Friends tab widget rects — the runtime `gbview` dump
        // reports both as 74×26 at (336,504)/(430,504), matching the decomp
        // builder. (The `b_server_*.img` art is 81×33; the sprite is drawn
        // into the smaller widget rect.)
        Button(name: "b_server_all.img", rect: Rect(x: 336, y: 504, width: 74, height: 26)),
        Button(name: "b_server_friend.img", rect: Rect(x: 430, y: 504, width: 74, height: 26)),
    ]

    /// Not decomp-confirmed — see the type-level doc comment. Set by the
    /// view once it knows `server_list.img`'s loaded size.
    public var panelRect: Rect = .zero

    // MARK: Runtime state mapping
    //
    // A runtime memory dump of the live `State02` object (`gbview`) confirms
    // this model and names the fields the decomp left as `m_unkXX`:
    //
    //   gbview field        →  here
    //   m_viewMode          →  worldListFilter (0 = .all)
    //   m_highlightedSlot   →  selectedIndex   (-1 = nil)
    //   m_selectedSlot      →  selectedIndex   (the decomp's +0x0c, moves in
    //                          lockstep with m_highlightedSlot on a row click;
    //                          we fold both into one field)
    //   m_scrollOffset/A    →  scrollOffset
    //   m_connecting        →  state == .connecting
    //   m_connectingSlot    →  (the slot a connect is in flight for)
    //   m_inputEnabled      →  isConnectEnabled (0 until a row is selected)
    //   m_uiDirty           →  the "interactable" gate (row clicks apply only
    //                          when set) — we gate on `state` instead
    //   m_wantInitialList   →  reload()-on-enter
    //   m_tickCounter       →  (a free-running frame counter; unmodelled)

    public private(set) var hoveredIndex: Int?
    /// The button currently held down — drives the `pressed` button frame.
    public private(set) var pressedIndex: Int?

    /// Which world-list view the panel's View All / Friends toggle is on.
    /// These are 5-frame toggle buttons: the current one shows its `selected`
    /// (yellow) frame. `all` is the default; `friends` (worlds where buddies
    /// are online) isn't filtered yet, so it only drives the toggle highlight.
    public enum WorldListFilter: Equatable, Sendable {
        case all
        case friends
    }
    public private(set) var worldListFilter: WorldListFilter = .all

    /// Whether a panel toggle button (`b_server_all` / `b_server_friend`) is
    /// the current world-list view — the button's `selected` state.
    public func isFilterSelected(_ buttonName: String) -> Bool {
        switch buttonName {
        case "b_server_all.img": return worldListFilter == .all
        case "b_server_friend.img": return worldListFilter == .friends
        default: return false
        }
    }

    /// Whether the shared buddy-list panel is open — the BUDDY button
    /// toggles it, matching the singleton `BuildBuddyPanel` shown across
    /// screens. `buddies` stays empty until a buddy-list protocol path
    /// exists; settable for tests/previews.
    public private(set) var isBuddyPanelVisible = false
    public var buddies: [String] = []

    /// Closes the buddy panel (its close-X button).
    public func dismissBuddyPanel() {
        setBuddyPanelVisible(false)
    }

    /// Shows or hides the buddy panel — also used by previews/tests.
    public func setBuddyPanelVisible(_ visible: Bool) {
        isBuddyPanelVisible = visible
    }

    /// The screen's lifecycle state: `.loading` while the world list is
    /// being fetched (input disabled), `.loaded` once rows are shown,
    /// `.connecting` while a connect attempt is in flight (drives the
    /// `waitmessage.img` overlay), `.error` when either fails.
    public private(set) var state: State = .loading {
        didSet {
            // Entering a busy state re-arms the wait-overlay debounce — the
            // original zeroes its wait counter when the request fires.
            let wasBusy = oldValue.isLoading || oldValue.isConnecting
            let isBusy = state.isLoading || state.isConnecting
            if isBusy && !wasBusy { busyElapsed = 0 }
        }
    }

    /// How long the current loading/connect has been in flight — the
    /// original's wait counter (`DAT_0056d118`: 0 when the request fires,
    /// +1 per `GameTick`, -1 when idle).
    private var busyElapsed: Double = 0

    /// The debounce before the PLEASE WAIT overlay appears: the original
    /// draws it only once its wait counter passes 40 game ticks (the signed
    /// `cmp eax, 0x28` gate at 0x41363f), so a fast server reply never
    /// flashes the spinner. 40 ticks at the 60 Hz game tick ≈ 0.67 s.
    public static let waitOverlayDelay: Double = 40.0 / 60.0

    /// Whether the animated `waitmessage.img` PLEASE WAIT overlay should
    /// draw: a request is in flight *and* it has been outstanding longer
    /// than the debounce.
    public var showsWaitOverlay: Bool {
        (state.isLoading || state.isConnecting) && busyElapsed > Self.waitOverlayDelay
    }
    
    /// The most world-server entries the client keeps, matching the
    /// decompiled `State02_ServerSelect_ProcessPacket` (`0x4e02b0`): it
    /// unpacks the `0x1102` list into a structure-of-arrays in the global
    /// client arena (`g_clientContext + 0x3f808`) whose backing tables are
    /// sized for exactly 16 entries (e.g. the 256-byte `desc` table is
    /// `0x1000` = 16 × 256), and the Enter-key selection loop bounds its
    /// scan at `i < 0x10`. Anything the broker sends past 16 is dropped.
    public static let maxServers = 16

    /// Servers returned by the most recent broker fetch — the real,
    /// server-driven data behind the "WORLD LIST" panel (`server_list.img`
    /// itself is just static chrome/art with no live data baked in), capped
    /// at `maxServers` to match the client's fixed-size storage.
    public private(set) var availableServers: [ServerDirectoryResponse.Server] = []

    // MARK: World-list row grid (decomp-confirmed geometry)
    //
    // `RenderWorldListRow` (0x50dc80) lays rows out 2-across inside the
    // panel: x = (i%2)·0xf7 + 0x16 + panelX, y = (i/2)·0x49 + 0x2d + panelY
    // (247px column pitch, 73px row pitch). The row background sprite is
    // 181×65 (server_list.img frames 1–4, one per state) with the 42×65
    // population gauge (frames 5–9, five fill levels) beside it.
    public static let rowColumns = 2
    public static let rowSize = (width: Float(181), height: Float(65))
    public static let gaugeSize = (width: Float(42), height: Float(65))
    static let rowOrigin = (x: Float(0x16), y: Float(0x2d))  // relative to panel
    static let rowPitch = (x: Float(0xf7), y: Float(0x49))

    /// How many rows fit on screen: 6 per column × 2 columns (a 7th row
    /// would start past the panel's bottom edge). Entries past 12 scroll
    /// into view via `scrollOffset`.
    public static let maxVisibleRows = 12

    /// The scroll position in row-*lines* (pairs of servers, one grid line),
    /// driven by the panel's scrollbar. `0` shows entries 0–11; each step
    /// slides the window down one line (two servers).
    public private(set) var scrollOffset = 0

    /// Total grid lines the fetched list occupies.
    public var lineCount: Int {
        (availableServers.count + Self.rowColumns - 1) / Self.rowColumns
    }

    /// The furthest `scrollOffset` can go (lines beyond the visible six).
    public var maxScrollOffset: Int {
        max(0, lineCount - Self.maxVisibleRows / Self.rowColumns)
    }

    public func setScrollOffset(_ offset: Int) {
        scrollOffset = min(max(0, offset), maxScrollOffset)
    }

    /// The servers actually drawn/hit-tested — the scroll window over the
    /// fetched list, capped to the 12 on-screen row slots.
    public var visibleServers: ArraySlice<ServerDirectoryResponse.Server> {
        // The Friends view lists only worlds where buddies are online; with no
        // buddy data wired the decomp clears the server count outright — a
        // live capture (`gbview`, m_viewMode 2) shows the empty panel.
        guard worldListFilter == .all else { return [] }
        return availableServers
            .dropFirst(scrollOffset * Self.rowColumns)
            .prefix(Self.maxVisibleRows)
    }

    /// Maps an on-screen row slot (0..<12) back to its index in
    /// `availableServers`, accounting for the scroll window.
    public func absoluteIndex(forVisibleSlot slot: Int) -> Int {
        scrollOffset * Self.rowColumns + slot
    }

    /// The highlighted row (the state object's `+0x08`, init −1): set by
    /// clicking an online row (`WorldListRowHitTest` only accepts online
    /// rows); the SERVER button then connects to it. When nothing is
    /// selected, connecting auto-picks the first joinable server — the
    /// decompiled Enter-key behaviour.
    public private(set) var selectedIndex: Int?

    /// Whether the SERVER button is live: one click selects a row (which
    /// enables the button), then the button — or a double-click on the
    /// selected row — connects. Disabled until then, and while the list
    /// loads or a connect attempt is in flight.
    public var isConnectEnabled: Bool {
        selectedIndex != nil && !state.isLoading && !state.isConnecting
    }

    /// Two clicks on the already-selected row within this window connect.
    public static let doubleClickInterval: Double = 0.4
    private var clock: Double = 0
    private var lastRowClick: (index: Int, time: Double)?

    private let delegate: ViewModelDelegate
    
    private let directoryFetcher: ServerDirectoryFetching
    
    private var task: Task<Void, Error>?
    
    public init(delegate: ViewModelDelegate, directoryFetcher: ServerDirectoryFetching = IPv4ServerDirectoryFetcher()) {
        self.delegate = delegate
        self.directoryFetcher = directoryFetcher
    }

    /// The on-screen rect of world-list row `index`'s background sprite.
    public func rowRect(at index: Int) -> Rect {
        Rect(
            x: panelRect.x + Self.rowOrigin.x + Float(index % Self.rowColumns) * Self.rowPitch.x,
            y: panelRect.y + Self.rowOrigin.y + Float(index / Self.rowColumns) * Self.rowPitch.y,
            width: Self.rowSize.width,
            height: Self.rowSize.height
        )
    }

    /// The population gauge's rect, flush against the row background's right
    /// edge (the original draws them contiguous, no gap).
    public func gaugeRect(at index: Int) -> Rect {
        let row = rowRect(at: index)
        return Rect(x: row.x + row.width, y: row.y, width: Self.gaugeSize.width, height: Self.gaugeSize.height)
    }

    /// The gauge fill level (0…4) — `currentPlayers·100/maxCapacity`
    /// bucketed into five levels, mirroring the decompiled threshold lookup
    /// (`DAT_005a9050`; the exact thresholds aren't dumped, so even 20%
    /// quintiles are used).
    public func populationLevel(of server: ServerDirectoryResponse.Server) -> Int {
        guard server.capacity > 0 else { return 4 }
        let percent = Int(server.utilization) * 100 / Int(server.capacity)
        return min(4, percent / 20)
    }

    public func onEnter() {
        hoveredIndex = nil
        pressedIndex = nil
        worldListFilter = .all
        selectedIndex = nil  // the real client resets +0x08 to -1 on enter
        scrollOffset = 0
        // Populate the WORLD LIST up front, like the real client.
        reload()
    }

    public func onExit() {
        hoveredIndex = nil
        pressedIndex = nil
        selectedIndex = nil
        task?.cancel()
        task = nil  // let a later re-entry start a fresh reload
    }

    /// The error dialog's OK button. On Server Select the errors are all
    /// connection failures whose sockets are already torn down ("The
    /// connection will close automatically."), so confirming exits the
    /// client — the same action as the EXIT button — rather than returning
    /// to a dead world list.
    public func confirmError() {
        delegate.requestQuit()
    }

    public func update(deltaTime: Double) {
        clock += deltaTime  // the double-click window's timebase
        if state.isLoading || state.isConnecting {
            busyElapsed += deltaTime
        }
    }

    /// Switches the world-list view tab (`WorldListPanelWidget`'s View All /
    /// Friends). Ignored while the list is loading or a connect is in flight,
    /// matching the pointer guard. `all` re-requests the full list; `friends`
    /// only moves the toggle highlight (friend-server filtering isn't wired).
    public func selectWorldListView(_ filter: WorldListFilter) {
        guard !state.isLoading, !state.isConnecting else { return }
        // Either tab clears the row highlight (the decomp's OnCommand sets
        // m_highlightedSlot = -1 and disables the connect button; confirmed by
        // a live capture with m_highlightedSlot -1 / m_inputEnabled 0 right
        // after a tab switch).
        selectedIndex = nil
        switch filter {
        case .all:
            worldListFilter = .all
            reload()
        case .friends:
            worldListFilter = .friends
        }
    }

    /// Handles a pointer press over the world-list row grid — the panel
    /// widget's row hit-test. Selects the online row under `(x, y)`, or
    /// connects on a double-click of the already-selected row (mirroring
    /// `WorldListRowHitTest` + the decomp's row select). Returns whether a row
    /// cell was hit. Ignored while the screen is busy.
    @discardableResult
    public func selectRow(atPoint x: Float, y: Float) -> Bool {
        guard !state.isLoading, !state.isConnecting else { return false }
        guard let slot = (0..<visibleServers.count).first(where: { rowRect(at: $0).contains(x: x, y: y) }) else {
            return false
        }
        let index = absoluteIndex(forVisibleSlot: slot)
        guard availableServers.indices.contains(index), availableServers[index].isEnabled else {
            return true  // landed on a row cell, just not a selectable one
        }
        // A second click on the selected row inside the window is a
        // double-click: connect straight away.
        if selectedIndex == index,
           let last = lastRowClick, last.index == index,
           clock - last.time <= Self.doubleClickInterval {
            lastRowClick = nil
            connect()
        } else {
            selectedIndex = index
            lastRowClick = (index: index, time: clock)
        }
        return true
    }

    public func handle(_ event: ScreenInputEvent) {
        switch event {
        case .pointerMoved(let x, let y):
            hoveredIndex = buttons.firstIndex { $0.rect.contains(x: x, y: y) }

        case .pointerDown(let x, let y):
            // No user interaction while the list is loading or a connect
            // attempt is already in flight.
            guard !state.isLoading, !state.isConnecting else { return }
            // Button click first (the panel's View All / Friends buttons
            // overlap the panel area), then row hit-testing —
            // `WorldListRowHitTest` maps the click through the same grid
            // geometry as the renderer and only accepts online rows
            // (fullness is checked later, at connect time).
            // In the running client `WorldListPanelWidget` consumes the panel's
            // View All / Friends tabs and the row grid (calling
            // `selectWorldListView` / `selectRow`) before this runs. This full
            // routing is kept so the view model stays usable standalone (tests,
            // previews) — the tab/row cases just forward to the same methods.
            if let index = buttons.firstIndex(where: { $0.rect.contains(x: x, y: y) }) {
                pressedIndex = index
                switch buttons[index].name {
                case "b_server_choiceserver.img":
                    // Live only once a row is selected.
                    guard isConnectEnabled else { return }
                    connect()
                case "b_server_exitgame.img":
                    delegate.requestQuit()
                case "b_server_buddygame.img":
                    // The screen's Buddy button (id 1, action 0x3e9) —
                    // toggles the shared buddy panel, as the same id does in
                    // the lobby and Avatar Store dispatchers.
                    setBuddyPanelVisible(!isBuddyPanelVisible)
                case "b_server_all.img":
                    selectWorldListView(.all)
                case "b_server_friend.img":
                    selectWorldListView(.friends)
                default:
                    print("[GunBound] clicked server-select button: \(buttons[index].name)")
                }
                return
            }
            selectRow(atPoint: x, y: y)

        case .activate:
            // Enter/return — mirrors the decomp keydown handler, which
            // connects to the current selection, defaulting to the first
            // online server when nothing is selected yet.
            guard !state.isLoading, !state.isConnecting else { return }
            if selectedIndex == nil {
                selectedIndex = availableServers.firstIndex(where: \.isEnabled)
            }
            if selectedIndex != nil {
                connect()
            }

        case .scroll(let x, let y, let steps):
            // Wheel over the WORLD LIST panel steps the scroll window, same
            // as the scrollbar arrows.
            guard !state.isLoading, !state.isConnecting,
                  panelRect.contains(x: x, y: y) else { return }
            setScrollOffset(scrollOffset + steps)

        case .pointerUp:
            pressedIndex = nil

        case .text, .key:
            break
        }
    }

    /// Refreshes the world list, tracking progress through `state` —
    /// `.loading` while the broker round-trip runs, then `.loaded` or
    /// `.error`. No-op while a refresh is already in flight.
    public func reload() {
        guard task == nil else {
            return
        }
        self.state = .loading
        self.task = Task(priority: .userInitiated) {
            defer { self.task = nil }
            do {
                try await fetchDirectory()
            } catch {
                print("[GunBound] couldn't reach broker: \(error)")
                self.state = .error(Self.dialogMessage(for: error))
            }
        }
    }

    private func connect() {
        state = .connecting
        Task { await performConnect() }
    }

    /// Looks up the world-server list from the broker (populating
    /// `availableServers`), then connects+authenticates to the first
    /// enabled entry, falling back to the manually configured server/port
    /// if the broker can't be reached or has none enabled.
    ///
    /// Not `private` so tests can call it directly with a mock
    /// `directoryFetcher` and `await` the result deterministically, instead
    /// of racing the background `Task` `connect()` normally wraps this in.
    func performConnect() async {
        let (worldAddress, worldPort) = await fetchDirectoryAndChooseServer()
        let network = delegate.network

        do {
            print("[GunBound] connecting to \(worldAddress):\(worldPort) as \(network.username)")
            let client = try await NetworkClient<GunBoundSocketIPv4TCP>.connect(
                NetworkConfig(username: network.username, password: network.password, serverAddress: worldAddress, serverPort: worldPort, brokerPort: network.brokerPort)
            )
            let response = try await client.authenticate(username: network.username, password: network.password)
            guard response.status == .success else {
                print("[GunBound] authentication failed: \(response.status)")
                await client.close()
                finishConnecting(client: nil, failure: .loginError)
                return
            }
            print("[GunBound] authenticated as \(network.username)")

            // Confirm-connect: join the default channel and wait for the
            // server's 0x2001 ack. Mirrors the decompiled State-2 client,
            // which only advances to the Game Room List (ChangeGameState(3))
            // once this acknowledgement comes back with a zero status.
            let joinResponse = try await client.joinChannel()
            guard joinResponse.isSuccess else {
                print("[GunBound] channel join rejected (status non-zero)")
                await client.close()
                finishConnecting(client: nil, failure: .serverAccessError)
                return
            }
            print("[GunBound] joined channel \(joinResponse.channel) (\(joinResponse.users.count) user(s) present)")
            delegate.session.channel = joinResponse
            finishConnecting(client: client, failure: nil)
        } catch {
            print("[GunBound] connection failed: \(error)")
            finishConnecting(client: nil, failure: Self.dialogMessage(for: error))
        }
    }

    /// Maps a networking error to the dialog message the original would
    /// show: a request timeout (a slow/dead connection) is "access time
    /// expired" (id 201); anything else — connection refused, EOF, a bad
    /// address — is the "server access error" (id 200). Never leaks the
    /// underlying `Error`'s text.
    static func dialogMessage(for error: Swift.Error) -> DialogMessage {
        if case NetworkClient<GunBoundSocketIPv4TCP>.Error.timeout = error {
            return .accessTimeExpired
        }
        return .serverAccessError
    }

    /// Ensures the directory has been fetched (refreshing it if the eager
    /// `onEnter` fetch produced nothing) and returns the address/port to
    /// connect to next — the first joinable entry, or the manually
    /// configured server/port if the broker can't be reached or has no
    /// joinable servers.
    ///
    /// Not `private` so tests can verify `availableServers` population with
    /// a mock `directoryFetcher` without also exercising the real network
    /// connect `performConnect()` does afterward.
    public func fetchDirectoryAndChooseServer() async -> (address: String, port: UInt16) {
        if availableServers.isEmpty {
            // Broker unreachable is non-fatal here — fall through to the
            // manually configured server/port below.
            try? await fetchDirectory()
        }
        let network = delegate.network
        var worldAddress = network.serverAddress
        var worldPort = network.serverPort
        // The clicked row wins (the decompiled SERVER button connects to the
        // highlighted slot `+0x08`); with nothing selected, fall back to the
        // first joinable server — the Enter-key auto-select. Offline and
        // full servers are skipped either way: the decompiled connect
        // handlers validate the target is online and not full
        // (currentPlayers < maxCapacity) before opening a socket.
        let selected = selectedIndex.flatMap { availableServers.indices.contains($0) ? availableServers[$0] : nil }
        if let chosen = (selected?.isJoinable == true ? selected : availableServers.first(where: \.isJoinable)) {
            worldAddress = chosen.address.rawValue
            worldPort = chosen.port
        }
        return (worldAddress, worldPort)
    }

    /// Fetches the broker's directory into `availableServers` (capped at
    /// `maxServers`), logging and leaving the list unchanged if the broker
    /// can't be reached. Called eagerly from `onEnter` — the real client
    /// receives the `0x1102` server list on entering state 2 rather than
    /// waiting for a connect attempt.
    private func fetchDirectory() async throws {
        let network = delegate.network
        let directory = try await directoryFetcher.fetchServerDirectory(
            address: network.serverAddress,
            brokerPort: network.brokerPort
        )
        self.availableServers = Array(directory.prefix(Self.maxServers))
        self.state = .loaded
        print("Broker returned \(directory.count) server(s): \(directory.map(\.name)) (keeping \(availableServers.count))")
    }

    /// Finishes a connect attempt: `failure == nil` means success (advance
    /// to the lobby); otherwise show that dialog message.
    private func finishConnecting(client: NetworkClient<GunBoundSocketIPv4TCP>?, failure: DialogMessage?) {
        if let client {
            delegate.client = client
        }
        if let failure {
            state = .error(failure)
        } else {
            state = .loaded
            delegate.requestTransition(to: .gameRoomList)
        }
    }
}

public extension ServerSelectViewModel {
    
    enum State: Equatable, Hashable, Sendable {

        case loading
        case loaded
        case connecting
        case error(DialogMessage)
    }
}

public extension ServerSelectViewModel.State {

    var isLoading: Bool {
        switch self {
        case .loading:
            return true
        default:
            return false
        }
    }

    /// Whether a connect attempt is in flight — drives the
    /// `waitmessage.img` overlay.
    var isConnecting: Bool {
        switch self {
        case .connecting:
            return true
        default:
            return false
        }
    }

    var error: DialogMessage? {
        switch self {
        case let .error(message):
            return message
        default:
            return nil
        }
    }
}
