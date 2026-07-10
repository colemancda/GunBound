import Foundation
import SpriteKit
import GunBound
import GunBoundFile
import GunBoundClient

/// Wraps an `SKTexture` to satisfy the backend-agnostic `ClientTexture`
/// marker protocol.
final class SpriteKitClientTexture: ClientTexture {
    let texture: SKTexture

    init(_ texture: SKTexture) {
        self.texture = texture
    }
}

/// `ClientRenderer` implemented against SpriteKit. Every `GameScreen` in
/// `GunBoundClient` was written against this protocol only — none of them
/// know whether they're being drawn by this, `GunBoundSDL3`'s `SDL3Renderer`,
/// or any other backend.
///
/// `Rect`'s convention (origin top-left, y increasing downward, matching
/// SDL/most 2D UI coordinate systems) doesn't match SpriteKit's own scene
/// space (origin bottom-left, y increasing upward), so `draw(_:in:tint:)`
/// flips the y-axis itself — screens never need to know about that.
@MainActor
final class SpriteKitRenderer: ClientRenderer {
    private unowned let scene: SKScene
    private var drawnNodes: [SKSpriteNode] = []

    init(scene: SKScene) {
        self.scene = scene
    }

    func texture(named name: String, frame frameIndex: Int, assets: AssetLibrary) -> ClientTexture? {
        do {
            let frame = try assets.imageFrame(named: name, at: frameIndex)
            return SpriteKitClientTexture(makeTexture(from: frame))
        } catch {
            print("[GunBoundSpriteKit] warning: couldn't load image '\(name)#\(frameIndex)': \(error)")
            return nil
        }
    }

    func texture(from frame: ImgFile.Frame) -> ClientTexture? {
        SpriteKitClientTexture(makeTexture(from: frame))
    }

    func size(of texture: ClientTexture?) -> (width: Float, height: Float) {
        guard let texture = texture as? SpriteKitClientTexture else { return (0, 0) }
        let size = texture.texture.size()
        return (Float(size.width), Float(size.height))
    }

    /// Removes every sprite node `draw(_:in:tint:)` added last frame —
    /// `GameStateMachine.render()` calls `clear()` once per frame before the
    /// current screen draws anything, mirroring an SDL renderer clear.
    func clear() {
        for node in drawnNodes {
            node.removeFromParent()
        }
        drawnNodes.removeAll(keepingCapacity: true)
    }

    func draw(_ texture: ClientTexture, in rect: Rect, tint: (r: UInt8, g: UInt8, b: UInt8)?, blend: ClientBlendMode, opacity: Float) {
        guard let texture = texture as? SpriteKitClientTexture else { return }
        let node = SKSpriteNode(texture: texture.texture)
        node.blendMode = blend == .additive ? .add : .alpha
        node.alpha = CGFloat(max(0, min(1, opacity)))
        node.anchorPoint = CGPoint(x: 0, y: 1)
        node.size = CGSize(width: CGFloat(rect.width), height: CGFloat(rect.height))
        // Flip from Rect's top-left/y-down convention into SpriteKit's
        // bottom-left/y-up scene space.
        node.position = CGPoint(x: CGFloat(rect.x), y: CGFloat(scene.size.height) - CGFloat(rect.y))
        if let tint {
            node.color = SKColor(red: CGFloat(tint.r) / 255, green: CGFloat(tint.g) / 255, blue: CGFloat(tint.b) / 255, alpha: 1)
            node.colorBlendFactor = 1
        } else {
            node.colorBlendFactor = 0
        }
        scene.addChild(node)
        drawnNodes.append(node)
    }

    /// SpriteKit presents automatically on its own render loop (driven by
    /// `SKView`/`SKScene.update(_:)`) — nothing to do here, unlike an SDL
    /// renderer which needs an explicit present call.
    func present() {}

    /// Builds an `SKTexture` from a decoded `.img` frame's `Pixel` array —
    /// frames are already fully decoded to 8-bit-per-channel RGBA
    /// (`ImgFile.Pixel`), so this just repacks the raw bytes for
    /// `SKTexture(data:size:)`, no image-file loader needed.
    ///
    /// `SKTexture(data:size:)` reads the buffer bottom-up: its *first* pixel
    /// row becomes the *bottom* row of the texture (OpenGL bottom-left
    /// origin). `.img` frames are stored top-down (row 0 = top), so the rows
    /// are emitted in reverse here — otherwise every sprite renders
    /// vertically flipped (upside-down logo/text/panels).
    private func makeTexture(from frame: ImgFile.Frame) -> SKTexture {
        let width = Int(frame.width)
        let height = Int(frame.height)
        var rgba = [UInt8]()
        rgba.reserveCapacity(width * height * 4)
        for y in stride(from: height - 1, through: 0, by: -1) {
            for x in 0..<width {
                let pixel = frame.pixels[y * width + x]
                rgba.append(pixel.red)
                rgba.append(pixel.green)
                rgba.append(pixel.blue)
                rgba.append(pixel.alpha)
            }
        }
        let data = Data(rgba)
        let texture = SKTexture(data: data, size: CGSize(width: width, height: height))
        texture.filteringMode = .nearest
        return texture
    }
}
