import Foundation
import SpriteKit
import GameController
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
            // software cursor off there. A one-shot `NSCursor.hide()` is
            // unreliable (AppKit re-shows the cursor on window activation
            // and cursor-rect updates), so visibility is driven by a
            // tracking area on the hosting view: hidden while the pointer is
            // over the game, restored when it leaves — see `mouseEntered`/
            // `mouseExited` and `hideOSCursor`.
            #if os(macOS)
            stateMachine.cursor.isVisible = true
            let trackingArea = NSTrackingArea(
                rect: .zero,
                options: [.mouseEnteredAndExited, .mouseMoved, .activeInKeyWindow, .inVisibleRect],
                owner: self,
                userInfo: nil
            )
            view.addTrackingArea(trackingArea)
            #endif
            self.stateMachine = stateMachine
        } catch {
            print("[GunBoundSpriteKit] failed to start state machine: \(error)")
        }
    }

    #if os(macOS)
    /// Whether we've hidden the OS cursor (NSCursor.hide/unhide must stay
    /// balanced — they're a global counter).
    private var isOSCursorHidden = false
    private var windowResignObserver: NSObjectProtocol?

    private func hideOSCursor() {
        guard !isOSCursorHidden else { return }
        isOSCursorHidden = true
        NSCursor.hide()
        // `mouseExited` doesn't fire on cmd-tab/window deactivation while the
        // pointer stays inside the view — restore the cursor whenever the
        // window resigns key so it's never hidden over another app.
        if windowResignObserver == nil, let window = view?.window {
            windowResignObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.didResignKeyNotification, object: window, queue: .main
            ) { [weak self] _ in
                Task { @MainActor in self?.unhideOSCursor() }
            }
        }
    }

    private func unhideOSCursor() {
        guard isOSCursorHidden else { return }
        isOSCursorHidden = false
        NSCursor.unhide()
    }

    override func willMove(from view: SKView) {
        unhideOSCursor()
        if let observer = windowResignObserver {
            NotificationCenter.default.removeObserver(observer)
            windowResignObserver = nil
        }
        super.willMove(from: view)
    }
    #endif

    override func update(_ currentTime: TimeInterval) {
        defer { lastUpdateTime = currentTime }
        guard let stateMachine else { return }
        if let context, context.quitRequested, !didRequestQuit {
            didRequestQuit = true
            onQuitRequested?()
            return
        }
        let deltaTime = lastUpdateTime.map { currentTime - $0 } ?? 0
        applyGamepad(stateMachine, deltaTime: deltaTime)
        do {
            try stateMachine.update(deltaTime: deltaTime)
            try stateMachine.render()
        } catch {
            print("[GunBoundSpriteKit] frame error: \(error)")
        }
    }

    /// Feeds the connected controller's left stick to the virtual cursor —
    /// the primary pointer on tvOS (no touch/mouse), and a bonus on iOS/macOS
    /// when a pad is attached. The stick's up-positive Y is negated for the
    /// cursor's y-down screen space; the A/cross button is the click.
    private func applyGamepad(_ stateMachine: GameStateMachine, deltaTime: TimeInterval) {
        guard let pad = GCController.current?.extendedGamepad
            ?? GCController.controllers().first?.extendedGamepad else { return }
        stateMachine.applyGamepad(
            stickX: pad.leftThumbstick.xAxis.value,
            stickY: -pad.leftThumbstick.yAxis.value,
            click: pad.buttonA.isPressed,
            deltaTime: deltaTime
        )
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
        // Belt-and-braces: AppKit can re-show the cursor (window switches,
        // cursor-rect updates); re-hide whenever the pointer moves over the
        // game. Guarded, so the hide/unhide counter stays balanced.
        hideOSCursor()
        stateMachine?.handleInput(motionEvent(for: event.location(in: self)))
    }

    override func mouseEntered(with event: NSEvent) {
        hideOSCursor()
    }

    override func mouseExited(with event: NSEvent) {
        unhideOSCursor()
    }

    /// Accumulates trackpad deltas into whole scroll steps (wheel clicks are
    /// ±1 line each; precise trackpad deltas are ~10px per visual line).
    private var scrollAccumulator: CGFloat = 0

    override func scrollWheel(with event: NSEvent) {
        // AppKit: positive deltaY = scroll up; our event: positive steps =
        // scroll down. Natural-scrolling inversion is already applied by the
        // system in the delta values.
        let unit: CGFloat = event.hasPreciseScrollingDeltas ? 10 : 1
        scrollAccumulator += event.scrollingDeltaY / unit
        let steps = Int(scrollAccumulator.rounded(.towardZero))
        guard steps != 0 else { return }
        scrollAccumulator -= CGFloat(steps)
        let location = event.location(in: self)
        stateMachine?.handleInput(.scroll(
            x: Float(location.x),
            y: Float(Self.canvasSize.height - location.y),
            steps: -steps
        ))
    }

    override func keyDown(with event: NSEvent) {
        // Return/Enter is the confirm/submit key; backspace and arrows are
        // editing keys for text fields; other printable input becomes text
        // (proper characters via NSEvent, unlike the SDL keycode fallback).
        switch event.keyCode {
        case 36, 76:  // Return, keypad Enter
            stateMachine?.handleInput(.activate)
        case 51:      // Delete/Backspace
            stateMachine?.handleInput(.key(.backspace))
        case 123:     // Left arrow
            stateMachine?.handleInput(.key(.left))
        case 124:     // Right arrow
            stateMachine?.handleInput(.key(.right))
        default:
            if let characters = event.characters, !characters.isEmpty,
               characters.unicodeScalars.allSatisfy({ !$0.properties.isDefaultIgnorableCodePoint && $0.value >= 0x20 }) {
                stateMachine?.handleInput(.text(characters))
            }
        }
    }
    #endif
}
