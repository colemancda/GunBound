import GunBoundProtocol

/// Logic for Server / Channel select (state 2) — owns the connect/login
/// flow: real GunBound looks up the world-server list from a broker/
/// directory server first, falling back to a manually configured
/// server/port directly (e.g. for a standalone `GunBoundServer world` with
/// no broker running) if the broker can't be reached or has no enabled
/// servers, then runs the nonce + login handshake against whichever server
/// it lands on.
///
/// Rects are pushed in by the view once it knows loaded-texture sizes
/// (`server_back.img` full backdrop, `server_list.img` panel/chrome overlay,
/// `b_server_choiceserver.img` button, `waitmessage.img` connecting overlay)
/// — this view model never touches a texture, only named resources and
/// `Rect` hit-testing state.
@MainActor
public final class ServerSelectViewModel: ScreenViewModel {
    public let backgroundImageName = "server_back.img"
    public let panelImageName = "server_list.img"
    public let buttonImageName = "b_server_choiceserver.img"
    public let waitImageName = "waitmessage.img"
    public let musicName: String? = "channel.mp3"
    public let loopMusic = true

    public var buttonRect: Rect = .zero

    public private(set) var isConnecting = false

    /// Servers returned by the most recent broker fetch — the real,
    /// server-driven data behind the "WORLD LIST" panel (`server_list.img`
    /// itself is just static chrome/art with no live data baked in).
    public private(set) var availableServers: [ServerDirectoryResponse.Server] = []

    private let delegate: ViewModelDelegate
    private let directoryFetcher: ServerDirectoryFetching

    public init(delegate: ViewModelDelegate, directoryFetcher: ServerDirectoryFetching = LiveServerDirectoryFetcher()) {
        self.delegate = delegate
        self.directoryFetcher = directoryFetcher
    }

    public func onEnter() {
        isConnecting = false
    }

    public func onExit() {
        isConnecting = false
    }

    public func update(deltaTime: Double) {}

    public func handle(_ event: ScreenInputEvent) {
        guard case .pointerDown(let x, let y) = event else { return }
        guard !isConnecting, buttonRect.contains(x: x, y: y) else { return }
        connect()
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
