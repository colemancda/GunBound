import Foundation
import Testing
@testable import GunBound
@testable import GunBoundClient
import GunBoundFile

/// Shared headless harness for driving `GameScreen`s in tests: a renderer that
/// synthesizes a texture for any name (so `onEnter`/`render` run without real
/// assets), a `ClientContext` over a nonexistent asset dir, and a silent audio
/// player. Screens whose direct asset touches are `try?`-guarded render fine
/// against this; the goal is to exercise their layout/draw code.
@MainActor
enum ScreenHarness {

    final class Texture: ClientTexture {
        let name: String
        let frame: Int
        init(_ name: String, _ frame: Int) { self.name = name; self.frame = frame }
    }

    final class Renderer: ClientRenderer {
        private(set) var draws: [(tex: Texture, rect: Rect)] = []
        func texture(named name: String, frame frameIndex: Int, assets: AssetLibrary) -> ClientTexture? {
            Texture(name, frameIndex)
        }
        func texture(from frame: ImgFile.Frame) -> ClientTexture? { Texture("<inline>", 0) }
        func size(of texture: ClientTexture?) -> (width: Float, height: Float) { (64, 64) }
        func clear() { draws.removeAll() }
        func draw(_ texture: ClientTexture, in rect: Rect, tint: (r: UInt8, g: UInt8, b: UInt8)?, blend: ClientBlendMode, opacity: Float) {
            if let tex = texture as? Texture { draws.append((tex, rect)) }
        }
        func present() {}
    }

    final class SilentAudio: ClientAudioPlayer {
        func play(named name: String, assets: AssetLibrary, loop: Bool) {}
        func playEffect(named name: String, assets: AssetLibrary) -> Bool { false }
        func stop() {}
        var isPlaying: Bool { false }
        func update(deltaTime: Double) {}
    }

    static func context(_ renderer: ClientRenderer) -> ClientContext {
        let assets = AssetLibrary(directory: URL(fileURLWithPath: "/nonexistent", isDirectory: true))
        let network = NetworkConfig(username: "u", password: "p", serverAddress: "127.0.0.1", serverPort: 8370, brokerPort: 8372)
        return ClientContext(assets: assets, renderer: renderer, network: network) { SilentAudio() }
    }

    /// A spread of input events that walk every corner/edge of the 800×600
    /// canvas plus keys, so a screen's hit-testing and input branches run.
    static let inputs: [ScreenInputEvent] = {
        var events: [ScreenInputEvent] = []
        for x in stride(from: Float(0), through: 800, by: 100) {
            for y in stride(from: Float(0), through: 600, by: 100) {
                events.append(.pointerMoved(x: x, y: y))
                events.append(.pointerDown(x: x, y: y))
                events.append(.pointerUp(x: x, y: y))
            }
        }
        events.append(contentsOf: [.activate, .scroll(x: 400, y: 300, steps: 1), .scroll(x: 400, y: 300, steps: -1)])
        for key in [ScreenInputEvent.Key.up, .down, .left, .right, .tab, .backspace] {
            events.append(.key(key))
        }
        return events
    }()
}
