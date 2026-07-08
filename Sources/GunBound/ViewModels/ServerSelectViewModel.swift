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
    public let musicName: String? = "channel.mp3"
    public let loopMusic = true

    /// Confirmed positions — see the type-level doc comment.
    public let buttons: [Button] = [
        Button(name: "b_server_exitgame.img", rect: Rect(x: 40, y: 551, width: 107, height: 45)),
        Button(name: "b_server_buddygame.img", rect: Rect(x: 163, y: 551, width: 107, height: 45)),
        Button(name: "b_server_choiceserver.img", rect: Rect(x: 409, y: 551, width: 107, height: 45)),
    ]

    /// Not decomp-confirmed — see the type-level doc comment. Set by the
    /// view once it knows `server_list.img`'s loaded size.
    public var panelRect: Rect = .zero

    public private(set) var hoveredIndex: Int?

    /// The screen's lifecycle state: `.loading` while the world list is
    /// being fetched (input disabled), `.loaded` once rows are shown,
    /// `.connecting` while a connect attempt is in flight (drives the
    /// `waitmessage.img` overlay), `.error` when either fails.
    public private(set) var state: State = .loading
    
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

    /// The highlighted row (the state object's `+0x08`, init −1): set by
    /// clicking an online row (`WorldListRowHitTest` only accepts online
    /// rows); the SERVER button then connects to it. When nothing is
    /// selected, connecting auto-picks the first joinable server — the
    /// decompiled Enter-key behaviour.
    public private(set) var selectedIndex: Int?

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

    /// The population gauge's rect, beside the row background.
    public func gaugeRect(at index: Int) -> Rect {
        let row = rowRect(at: index)
        return Rect(x: row.x + row.width + 2, y: row.y, width: Self.gaugeSize.width, height: Self.gaugeSize.height)
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
        selectedIndex = nil  // the real client resets +0x08 to -1 on enter
        // Populate the WORLD LIST up front, like the real client.
        reload()
    }

    public func onExit() {
        hoveredIndex = nil
        selectedIndex = nil
        task?.cancel()
        task = nil  // let a later re-entry start a fresh reload
    }

    public func update(deltaTime: Double) {}

    public func handle(_ event: ScreenInputEvent) {
        switch event {
        case .pointerMoved(let x, let y):
            hoveredIndex = buttons.firstIndex { $0.rect.contains(x: x, y: y) }

        case .pointerDown(let x, let y):
            // No user interaction while the list is loading or a connect
            // attempt is already in flight.
            guard !state.isLoading, !state.isConnecting else { return }
            // Row click first — `WorldListRowHitTest` maps the click through
            // the same grid geometry as the renderer and only accepts online
            // rows (fullness is checked later, at connect time).
            if let row = (0..<availableServers.count).first(where: { rowRect(at: $0).contains(x: x, y: y) }) {
                if availableServers[row].isEnabled {
                    selectedIndex = row
                }
                return
            }
            guard let index = buttons.firstIndex(where: { $0.rect.contains(x: x, y: y) }) else { return }
            switch buttons[index].name {
            case "b_server_choiceserver.img":
                connect()
            case "b_server_exitgame.img":
                delegate.requestQuit()
            default:
                print("[GunBound] clicked server-select button: \(buttons[index].name)")
            }

        case .activate:
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
                self.state = .error("Couldn't reach the server broker: \(error.localizedDescription)")
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
                finishConnecting(client: nil, success: false)
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
                finishConnecting(client: nil, success: false)
                return
            }
            print("[GunBound] joined channel \(joinResponse.channel) (\(joinResponse.users.count) user(s) present)")
            delegate.session.channel = joinResponse
            finishConnecting(client: client, success: true)
        } catch {
            print("[GunBound] connection failed: \(error)")
            finishConnecting(client: nil, success: false)
        }
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
    func fetchDirectoryAndChooseServer() async -> (address: String, port: UInt16) {
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

    private func finishConnecting(client: NetworkClient<GunBoundSocketIPv4TCP>?, success: Bool) {
        if let client {
            delegate.client = client
        }
        if success {
            state = .loaded
            delegate.requestTransition(to: .gameRoomList)
        } else {
            state = .error("Couldn't connect to the server — check the address and try again.")
        }
    }
}

public extension ServerSelectViewModel {
    
    enum State: Equatable, Hashable, Sendable {

        case loading
        case loaded
        case connecting
        case error(String)
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

    var error: String? {
        switch self {
        case let .error(error):
            return error
        default:
            return nil
        }
    }
}
