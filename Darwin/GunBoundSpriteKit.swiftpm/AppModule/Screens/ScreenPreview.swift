//
//  ScreenPreview.swift
//  GunBoundSpriteKit
//
//  Shared plumbing for the per-screen #Previews (see LogoScreen.swift for
//  the original pattern): hosts any single `GameScreen` in its own SKScene,
//  driving the same onEnter/update/render loop `GameScene` runs for the full
//  state machine — but scoped to just one screen, with no transitions.
//

import SwiftUI
import SpriteKit
import GunBound
import GunBoundProtocol
import GunBoundClient

/// SwiftUI view that renders one `GameScreen` via SpriteKit — the generic
/// version of `LogoScreenView`, used by every screen's `#Preview`.
struct ScreenPreviewView: View {
    private let scene: ScreenPreviewScene

    init(screen: GameScreen, assetsDirectory: URL = previewAssetsDirectory()) {
        let scene = ScreenPreviewScene(screen: screen, assetsDirectory: assetsDirectory)
        scene.scaleMode = .aspectFit
        self.scene = scene
    }

    var body: some View {
        SpriteView(scene: scene)
            .aspectRatio(GameScene.canvasSize, contentMode: .fit)
    }
}

/// Where the previews load the game archives from — the bundled
/// `AppModule/Resources` folder (run `Darwin/copy-dependencies.sh` to
/// populate it; an empty folder just renders a black canvas).
func previewAssetsDirectory() -> URL {
    Bundle.main.resourceURL!
}

/// Hosts a single `GameScreen`, forwarding touches so hover/click states are
/// interactive in the preview canvas.
final class ScreenPreviewScene: SKScene {
    private let screen: GameScreen
    private let assetsDirectory: URL
    private var renderer: SpriteKitRenderer?
    private var lastUpdateTime: TimeInterval?

    init(screen: GameScreen, assetsDirectory: URL) {
        self.screen = screen
        self.assetsDirectory = assetsDirectory
        super.init(size: GameScene.canvasSize)
        backgroundColor = .black
        anchorPoint = .zero
    }

    required init?(coder aDecoder: NSCoder) { fatalError() }

    override func didMove(to view: SKView) {
        super.didMove(to: view)
        let renderer = SpriteKitRenderer(scene: self)
        let assets = AssetLibrary(directory: assetsDirectory)
        let context = ClientContext(
            assets: assets,
            renderer: renderer,
            network: ScreenPreviewDelegate().network
        ) {
            SpriteKitAudioPlayer()
        }
        self.renderer = renderer
        try? screen.onEnter(context: context)
    }

    override func update(_ currentTime: TimeInterval) {
        defer { lastUpdateTime = currentTime }
        guard let renderer else { return }
        let deltaTime = lastUpdateTime.map { currentTime - $0 } ?? 0
        screen.update(deltaTime: deltaTime)
        try? screen.render(renderer)
    }

    private func input(for location: CGPoint, moved: Bool) -> ScreenInputEvent {
        let x = Float(location.x)
        let y = Float(GameScene.canvasSize.height - location.y)
        return moved ? .pointerMoved(x: x, y: y) : .pointerDown(x: x, y: y)
    }

    #if canImport(UIKit)
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let location = touches.first?.location(in: self) else { return }
        screen.handleInput(input(for: location, moved: false))
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let location = touches.first?.location(in: self) else { return }
        screen.handleInput(input(for: location, moved: true))
    }
    #endif

    // The macOS targets' preview canvas delivers mouse events, not touches —
    // mirror GameScene's handlers so previews are interactive there too.
    #if os(macOS)
    override func mouseDown(with event: NSEvent) {
        screen.handleInput(input(for: event.location(in: self), moved: false))
    }

    override func mouseDragged(with event: NSEvent) {
        screen.handleInput(input(for: event.location(in: self), moved: true))
    }

    override func mouseMoved(with event: NSEvent) {
        screen.handleInput(input(for: event.location(in: self), moved: true))
    }
    #endif
}

/// Mirrors `MockViewModelDelegate` from `GunBoundTests` — records nothing
/// and drives no SDL/network stack; screens that fetch on entry all guard on
/// `client == nil` and just render their chrome.
@MainActor
final class ScreenPreviewDelegate: ViewModelDelegate {
    let network = NetworkConfig(
        username: "admin",
        password: "1234",
        serverAddress: "127.0.0.1",
        serverPort: 8370,
        brokerPort: 8372
    )
    var client: NetworkClient<GunBoundSocketIPv4TCP>?
    let session = ClientSession()

    func requestTransition(to mode: ClientMode) {}
    func requestQuit() {}

    /// A canned joined room + 4-player roster, so the session-driven screens
    /// (Ready Room, Loading) preview with real content instead of an empty
    /// roster.
    func withSampleRoom() -> ScreenPreviewDelegate {
        func player(_ id: UInt8, _ name: Username, _ mobile: Mobile, _ team: Team) -> JoinRoomResponse.PlayerSession {
            JoinRoomResponse.PlayerSession(
                id: id,
                username: name,
                address: GunBoundAddress(address: "127.0.0.1", port: 8370)!,
                address2: GunBoundAddress(address: "127.0.0.1", port: 8370)!,
                primaryTank: mobile,
                secondary: .random,
                team: team,
                avatarEquipped: 0,
                guild: "",
                rankCurrent: 20,
                rankSeason: 20
            )
        }
        session.currentRoom = JoinRoomResponse(
            room: 1,
            name: "Preview Room",
            map: .metropolis,
            settings: 0,
            capacity: ._2_2,
            players: [
                player(0, "alsey", .armor, .a),
                player(1, "boomer", .boomer, .b),
                player(2, "trico", .trico, .a),
                player(3, "mage", .mage, .b),
            ]
        )
        return self
    }
}
