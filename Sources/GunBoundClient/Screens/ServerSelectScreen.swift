import CSDL3
import SDL3Swift
import GunBound

/// State 2 — Server / Channel select (`server_list.img`,
/// `b_server_choiceserver.img`, `channel.mp3`). Clicking the "choose server"
/// button now opens a real TCP connection to `context.network`'s
/// server/port and runs the nonce + login handshake
/// (`NetworkClient.authenticate`) using the configured username/password —
/// only on a successful `AuthenticationResponse` does it transition to the
/// Game Room List; any failure (bad credentials, connection error) is
/// logged and the screen stays put so the attempt can be retried.
///
/// Button screen position isn't reverse-engineered in the decomp docs, so
/// it's placed at a fixed bottom-of-window rect purely to be visible and
/// clickable — not claimed pixel-accurate to the original layout.
@MainActor
final class ServerSelectScreen: ImageBackgroundScreen {
    private var buttonTexture: SDLTexture?
    private var buttonRect = SDL_FRect(x: 0, y: 0, w: 0, h: 0)
    private var isConnecting = false

    init() {
        super.init(backgroundImageName: "server_list.img", musicName: "channel.mp3")
    }

    override func onEnter(context: ScreenContext) throws {
        try super.onEnter(context: context)
        buttonTexture = loadTexture(named: "b_server_choiceserver.img", context: context)
        if let buttonTexture, let attributes = try? buttonTexture.attributes() {
            buttonRect = SDL_FRect(x: 20, y: Float(600 - attributes.height - 20), w: Float(attributes.width), h: Float(attributes.height))
        }
    }

    override func onExit() {
        buttonTexture = nil
        isConnecting = false
        super.onExit()
    }

    override func handleEvent(_ event: SDLEvent, context: ScreenContext) {
        switch event {
        case .mouseButtonDown(_, let x, let y, _) where contains(buttonRect, x: x, y: y):
            guard !isConnecting else { return }
            isConnecting = true
            let network = context.network
            print("[GunBoundClient] connecting to \(network.serverAddress):\(network.serverPort) as \(network.username)")
            Task {
                do {
                    let client = try await NetworkClient.connect(network)
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
                        await self.finishConnecting()
                    }
                } catch {
                    print("[GunBoundClient] connection failed: \(error)")
                    await self.finishConnecting()
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
        guard let buttonTexture else { return }
        try renderer.copy(buttonTexture, destination: buttonRect)
    }
}

func contains(_ rect: SDL_FRect, x: Float, y: Float) -> Bool {
    x >= rect.x && x <= rect.x + rect.w && y >= rect.y && y <= rect.y + rect.h
}
