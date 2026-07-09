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
    private var context: ClientContext?
    private var lastUpdateTime: TimeInterval?
    private var didRequestQuit = false

    /// Set by `LoginView` before this scene is presented — by that point the
    /// assets directory has already been confirmed to exist and decode a
    /// real sprite successfully, so this scene doesn't re-validate it.
    var assetsDirectory: URL!
    var network: NetworkConfig!

    /// Fired once when a screen requests quitting (e.g. Server Select's
    /// EXIT button) — the SwiftUI host uses it to leave the game and return
    /// to the login screen, since iOS/tvOS apps can't terminate themselves.
    var onQuitRequested: (() -> Void)?

    override func didMove(to view: SKView) {
        super.didMove(to: view)
        scaleMode = .aspectFit
        size = Self.canvasSize
        backgroundColor = .black
        anchorPoint = CGPoint(x: 0, y: 0)

        let renderer = SpriteKitRenderer(scene: self)
        let assets = AssetLibrary(directory: assetsDirectory)
        let context = ClientContext(assets: assets, renderer: renderer, network: network) {
            SpriteKitAudioPlayer()
        }
        self.context = context

        do {
            let stateMachine = try GameStateMachine(context: context, initialMode: .logo1) { [unowned context] mode in
                makeGameScreen(for: mode, delegate: context)
            }
            // macOS has an OS cursor to replace with the game's own
            // `cursor.img` pointer; iOS/tvOS are touch-driven, so leave the
            // software cursor off there.
            #if os(macOS)
            NSCursor.hide()
            stateMachine.cursor.isVisible = true
            #endif
            self.stateMachine = stateMachine
        } catch {
            print("[GunBoundSpriteKit] failed to start state machine: \(error)")
        }
    }

    override func update(_ currentTime: TimeInterval) {
        defer { lastUpdateTime = currentTime }
        guard let stateMachine else { return }
        if let context, context.quitRequested, !didRequestQuit {
            didRequestQuit = true
            onQuitRequested?()
            return
        }
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

    // macOS mouse input (the Darwin Xcode project's GunBound-macOS target —
    // see Darwin/). `mouseMoved` only fires if the hosting window has
    // `acceptsMouseMovedEvents = true`, which AppDelegate_macOS sets.
    #if os(macOS)
    override func mouseDown(with event: NSEvent) {
        stateMachine?.handleInput(inputEvent(for: event.location(in: self)))
    }

    override func mouseDragged(with event: NSEvent) {
        stateMachine?.handleInput(motionEvent(for: event.location(in: self)))
    }

    override func mouseMoved(with event: NSEvent) {
        stateMachine?.handleInput(motionEvent(for: event.location(in: self)))
    }

    override func keyDown(with event: NSEvent) {
        // Any key press maps to `.activate` (Enter-to-connect, dismiss a
        // dialog, advance the Title screen) — the same reduction the SDL
        // backends make.
        stateMachine?.handleInput(.activate)
    }
    #endif
}
