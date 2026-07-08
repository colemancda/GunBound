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

    private let delegate: ViewModelDelegate

    public init(delegate: ViewModelDelegate) {
        self.delegate = delegate
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
        let network = delegate.network
        Task {
            do {
                var worldAddress = network.serverAddress
                var worldPort = network.serverPort
                do {
                    let directory = try await NetworkClient.fetchServerDirectory(address: network.serverAddress, brokerPort: network.brokerPort)
                    print("[GunBound] broker returned \(directory.count) server(s): \(directory.map(\.name))")
                    if let chosen = directory.first(where: \.isEnabled) {
                        worldAddress = chosen.address.rawValue
                        worldPort = chosen.port
                    }
                } catch {
                    print("[GunBound] couldn't reach broker at \(network.serverAddress):\(network.brokerPort) (\(error)), connecting directly instead")
                }

                print("[GunBound] connecting to \(worldAddress):\(worldPort) as \(network.username)")
                let client = try await NetworkClient.connect(
                    NetworkConfig(username: network.username, password: network.password, serverAddress: worldAddress, serverPort: worldPort, brokerPort: network.brokerPort)
                )
                let response = try await client.authenticate(username: network.username, password: network.password)
                if response.status == .success {
                    print("[GunBound] authenticated as \(network.username)")
                    await self.finishConnecting(client: client, success: true)
                } else {
                    print("[GunBound] authentication failed: \(response.status)")
                    await client.close()
                    await self.finishConnecting(client: nil, success: false)
                }
            } catch {
                print("[GunBound] connection failed: \(error)")
                await self.finishConnecting(client: nil, success: false)
            }
        }
    }

    private func finishConnecting(client: NetworkClient?, success: Bool) {
        isConnecting = false
        if let client {
            delegate.client = client
        }
        if success {
            delegate.requestTransition(to: .gameRoomList)
        }
    }
}
