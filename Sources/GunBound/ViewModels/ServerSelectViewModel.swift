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
    public private(set) var isConnecting = false

    /// Servers returned by the most recent broker fetch — the real,
    /// server-driven data behind the "WORLD LIST" panel (`server_list.img`
    /// itself is just static chrome/art with no live data baked in).
    public private(set) var availableServers: [ServerDirectoryResponse.Server] = []

    private let delegate: ViewModelDelegate
    private let directoryFetcher: ServerDirectoryFetching

    public init(delegate: ViewModelDelegate, directoryFetcher: ServerDirectoryFetching = IPv4ServerDirectoryFetcher()) {
        self.delegate = delegate
        self.directoryFetcher = directoryFetcher
    }

    public func onEnter() {
        isConnecting = false
        hoveredIndex = nil
    }

    public func onExit() {
        isConnecting = false
        hoveredIndex = nil
    }

    public func update(deltaTime: Double) {}

    public func handle(_ event: ScreenInputEvent) {
        switch event {
        case .pointerMoved(let x, let y):
            hoveredIndex = buttons.firstIndex { $0.rect.contains(x: x, y: y) }

        case .pointerDown(let x, let y):
            guard !isConnecting, let index = buttons.firstIndex(where: { $0.rect.contains(x: x, y: y) }) else { return }
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

    private func connect() {
        isConnecting = true
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
            if response.status == .success {
                print("[GunBound] authenticated as \(network.username)")
                finishConnecting(client: client, success: true)
            } else {
                print("[GunBound] authentication failed: \(response.status)")
                await client.close()
                finishConnecting(client: nil, success: false)
            }
        } catch {
            print("[GunBound] connection failed: \(error)")
            finishConnecting(client: nil, success: false)
        }
    }

    /// Fetches the broker's server directory (populating `availableServers`)
    /// and returns the address/port to connect to next — the first enabled
    /// entry, or the manually configured server/port if the broker can't be
    /// reached or has no enabled servers.
    ///
    /// Not `private` so tests can verify `availableServers` population with
    /// a mock `directoryFetcher` without also exercising the real network
    /// connect `performConnect()` does afterward.
    func fetchDirectoryAndChooseServer() async -> (address: String, port: UInt16) {
        let network = delegate.network
        var worldAddress = network.serverAddress
        var worldPort = network.serverPort
        do {
            let directory = try await directoryFetcher.fetchServerDirectory(address: network.serverAddress, brokerPort: network.brokerPort)
            availableServers = directory
            print("[GunBound] broker returned \(directory.count) server(s): \(directory.map(\.name))")
            if let chosen = directory.first(where: \.isEnabled) {
                worldAddress = chosen.address.rawValue
                worldPort = chosen.port
            }
        } catch {
            print("[GunBound] couldn't reach broker at \(network.serverAddress):\(network.brokerPort) (\(error)), connecting directly instead")
        }
        return (worldAddress, worldPort)
    }

    private func finishConnecting(client: NetworkClient<GunBoundSocketIPv4TCP>?, success: Bool) {
        isConnecting = false
        if let client {
            delegate.client = client
        }
        if success {
            delegate.requestTransition(to: .gameRoomList)
        }
    }
}
