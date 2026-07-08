import Foundation
import SpriteKit
import GunBound
import GunBoundClient

/// Drives the same `GameStateMachine`/`makeGameScreen` flow `GunBoundSDL3`
/// uses, just rendered through `SpriteKitRenderer`/`SpriteKitAudioPlayer`
/// instead of SDL3 — every screen and view model is reused unchanged.
final class GameScene: SKScene {
    /// The fixed logical canvas — matches `GunBoundSDL3`'s (and the
    /// decomp's confirmed fullscreen exclusive resolution).
    static let canvasSize = CGSize(width: 800, height: 600)

    private var stateMachine: GameStateMachine?
    private var lastUpdateTime: TimeInterval?

    override func didMove(to view: SKView) {
        super.didMove(to: view)
        scaleMode = .aspectFit
        size = Self.canvasSize
        backgroundColor = .black
        anchorPoint = CGPoint(x: 0, y: 0)

        let renderer = SpriteKitRenderer(scene: self)

        // Same Mac filesystem path GunBoundSDL3 defaults to — only resolves
        // when run in the iOS Simulator on this Mac (a real device has no
        // such path; see this Playground's README).
        let assetsDirectory = URL(fileURLWithPath: "/Users/coleman/Developer/GunBound-Decomp/orig", isDirectory: true)
        let assets = AssetLibrary(directory: assetsDirectory)
        let network = NetworkConfig(username: "admin", password: "1234", serverAddress: "127.0.0.1", serverPort: 8370, brokerPort: 8372)
        let context = ClientContext(assets: assets, renderer: renderer, network: network) {
            SpriteKitAudioPlayer()
        }

        do {
            stateMachine = try GameStateMachine(context: context, initialMode: .logo1) { [unowned context] mode in
                makeGameScreen(for: mode, delegate: context)
            }
        } catch {
            print("[GunBoundSpriteKit] failed to start state machine: \(error)")
        }
    }

    override func update(_ currentTime: TimeInterval) {
        defer { lastUpdateTime = currentTime }
        guard let stateMachine else { return }
        let deltaTime = lastUpdateTime.map { currentTime - $0 } ?? 0
        do {
            try stateMachine.update(deltaTime: deltaTime)
            try stateMachine.render()
        } catch {
            print("[GunBoundSpriteKit] frame error: \(error)")
        }
    }

    /// Converts a touch/click location in this scene's own coordinate space
    /// (origin bottom-left, y up) into `Rect`'s convention (origin top-left,
    /// y down) that every `ScreenViewModel` expects.
    func inputEvent(for location: CGPoint) -> ScreenInputEvent {
        .pointerDown(x: Float(location.x), y: Float(Self.canvasSize.height - location.y))
    }

    func motionEvent(for location: CGPoint) -> ScreenInputEvent {
        .pointerMoved(x: Float(location.x), y: Float(Self.canvasSize.height - location.y))
    }

    #if canImport(UIKit)
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let location = touches.first?.location(in: self) else { return }
        stateMachine?.handleInput(inputEvent(for: location))
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let location = touches.first?.location(in: self) else { return }
        stateMachine?.handleInput(motionEvent(for: location))
    }
    #endif
}
