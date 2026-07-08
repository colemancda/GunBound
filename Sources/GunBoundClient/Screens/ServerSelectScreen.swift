import CSDL3
import SDL3Swift
import GunBound

/// State 2 — Server / Channel select (`server_back.img` full backdrop,
/// `server_list.img` panel/chrome overlay on top — `server_list.img` alone
/// is mostly transparent (a sparse-format sprite with just the panel
/// border/text baked in), so drawing it without the backdrop underneath
/// left the rest of the window solid black; `b_server_choiceserver.img`,
/// `channel.mp3`). Clicking the "choose server" button opens a real TCP
/// connection to `context.network`'s server/port and runs the nonce +
/// login handshake (`NetworkClient.authenticate`) using the configured
/// username/password — while that's in flight, a `waitmessage.img` overlay
/// is drawn so the attempt doesn't look like a silent hang; only on a
/// successful `AuthenticationResponse` does it transition to the Game Room
/// List, any failure (bad credentials, connection error) is logged and the
/// screen stays put so the attempt can be retried.
///
/// Button/overlay screen positions aren't reverse-engineered in the decomp
/// docs, so they're placed at fixed rects purely to be visible and
/// clickable — not claimed pixel-accurate to the original layout.
@MainActor
final class ServerSelectScreen: ImageBackgroundScreen {
    private var buttonTexture: SDLTexture?
    private var buttonRect = SDL_FRect(x: 0, y: 0, w: 0, h: 0)
    private var panelTexture: SDLTexture?
    private var panelRect = SDL_FRect(x: 0, y: 0, w: 0, h: 0)
    private var waitTexture: SDLTexture?
    private var waitRect = SDL_FRect(x: 0, y: 0, w: 0, h: 0)
    private var isConnecting = false

    init() {
        super.init(backgroundImageName: "server_back.img", musicName: "channel.mp3", loopMusic: true)
    }

    override func onEnter(context: ScreenContext) throws {
        try super.onEnter(context: context)
        buttonTexture = loadTexture(named: "b_server_choiceserver.img", context: context)
        if let buttonTexture, let attributes = try? buttonTexture.attributes() {
            buttonRect = SDL_FRect(x: 20, y: Float(600 - attributes.height - 20), w: Float(attributes.width), h: Float(attributes.height))
        }
        panelTexture = loadTexture(named: "server_list.img", context: context)
        if let panelTexture, let attributes = try? panelTexture.attributes() {
            panelRect = SDL_FRect(x: 0, y: 0, w: Float(attributes.width), h: Float(attributes.height))
        }
        waitTexture = loadTexture(named: "waitmessage.img", context: context)
        if let waitTexture, let attributes = try? waitTexture.attributes() {
            waitRect = SDL_FRect(
                x: Float(800 - attributes.width) / 2,
                y: Float(600 - attributes.height) / 2,
                w: Float(attributes.width),
                h: Float(attributes.height)
            )
        }
    }

    override func onExit() {
        buttonTexture = nil
        panelTexture = nil
        waitTexture = nil
        isConnecting = false
        super.onExit()
    }

    override func handleEvent(_ event: SDLEvent, context: ScreenContext) {
        switch event {
        case .mouseButtonDown(_, let x, let y, _) where contains(buttonRect, x: x, y: y):
            guard !isConnecting else { return }
            isConnecting = true
            let network = context.network
            Task {
                do {
                    // Real GunBound looks up the world-server list from a
                    // broker/directory server first — fall back to the
                    // manually configured server/port directly (e.g. for a
                    // standalone `GunBoundServer world` with no broker
                    // running) if the broker can't be reached or has no
                    // enabled servers.
                    var worldAddress = network.serverAddress
                    var worldPort = network.serverPort
                    do {
                        let directory = try await NetworkClient.fetchServerDirectory(address: network.serverAddress, brokerPort: network.brokerPort)
                        print("[GunBoundClient] broker returned \(directory.count) server(s): \(directory.map(\.name))")
                        if let chosen = directory.first(where: \.isEnabled) {
                            worldAddress = chosen.address.rawValue
                            worldPort = chosen.port
                        }
                    } catch {
                        print("[GunBoundClient] couldn't reach broker at \(network.serverAddress):\(network.brokerPort) (\(error)), connecting directly instead")
                    }

                    print("[GunBoundClient] connecting to \(worldAddress):\(worldPort) as \(network.username)")
                    let client = try await NetworkClient.connect(
                        NetworkConfig(username: network.username, password: network.password, serverAddress: worldAddress, serverPort: worldPort, brokerPort: network.brokerPort)
                    )
                    let response = try await client.authenticate(username: network.username, password: network.password)
                    if response.status == .success {
                        print("[GunBoundClient] authenticated as \(network.username)")
                        await MainActor.run {
                            context.client = client
                            context.requestTransition(to: .gameRoomList)
                        }
                    } else {
                        print("[GunBoundClient] authentication failed: \(response.status)")
                        await client.close()
                        self.finishConnecting()
                    }
                } catch {
                    print("[GunBoundClient] connection failed: \(error)")
                    self.finishConnecting()
                }
            }
        default:
            break
        }
    }

    private func finishConnecting() {
        isConnecting = false
    }

    override func render(_ renderer: SDLRenderer) throws {
        try super.render(renderer)
        if let panelTexture {
            try renderer.copy(panelTexture, destination: panelRect)
        }
        if let buttonTexture {
            try renderer.copy(buttonTexture, destination: buttonRect)
        }
        if isConnecting, let waitTexture {
            try renderer.copy(waitTexture, destination: waitRect)
        }
    }
}

func contains(_ rect: SDL_FRect, x: Float, y: Float) -> Bool {
    x >= rect.x && x <= rect.x + rect.w && y >= rect.y && y <= rect.y + rect.h
}
