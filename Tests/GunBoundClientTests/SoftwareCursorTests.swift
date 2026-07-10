import Foundation
import Testing
@testable import GunBound
@testable import GunBoundClient
import GunBoundFile

@Suite @MainActor
struct SoftwareCursorTests {

    private final class Tex: ClientTexture {}

    /// Records draws and reports a fixed 22×22 cursor size.
    private final class RecordingRenderer: ClientRenderer {
        var draws: [Rect] = []
        func texture(named name: String, frame frameIndex: Int, assets: AssetLibrary) -> ClientTexture? { Tex() }
        func texture(from frame: ImgFile.Frame) -> ClientTexture? { Tex() }
        func size(of texture: ClientTexture?) -> (width: Float, height: Float) { texture == nil ? (0, 0) : (22, 22) }
        func clear() {}
        func draw(_ texture: ClientTexture, in rect: Rect, tint: (r: UInt8, g: UInt8, b: UInt8)?, blend: ClientBlendMode, opacity: Float) { draws.append(rect) }
        func present() {}
    }

    @Test func drawsAtPositionWithTopLeftHotspot() {
        let cursor = SoftwareCursor()
        cursor.texture = Tex()
        cursor.position = (120, 80)
        let renderer = RecordingRenderer()

        cursor.draw(renderer)
        // Blitted straight at the mouse position, natural size, no offset.
        #expect(renderer.draws == [Rect(x: 120, y: 80, width: 22, height: 22)])
    }

    @Test func hiddenCursorDrawsNothing() {
        let cursor = SoftwareCursor()
        cursor.texture = Tex()
        cursor.isVisible = false
        let renderer = RecordingRenderer()

        cursor.draw(renderer)
        #expect(renderer.draws.isEmpty)
    }

    @Test func withoutTextureDrawsNothing() {
        let cursor = SoftwareCursor()
        let renderer = RecordingRenderer()
        cursor.draw(renderer)
        #expect(renderer.draws.isEmpty)
    }

    @Test func advancesThroughAnimationFrames() {
        let cursor = SoftwareCursor()
        let frames = (0..<8).map { _ in Tex() }
        cursor.frames = frames

        // Frame 0 at t=0.
        #expect(cursor.currentTexture === frames[0])
        // One frame duration in -> frame 1.
        cursor.update(deltaTime: SoftwareCursor.frameDuration)
        #expect(cursor.currentTexture === frames[1])
        // Halfway into a frame still shows the same frame.
        cursor.update(deltaTime: SoftwareCursor.frameDuration / 2)
        #expect(cursor.currentTexture === frames[1])
    }

    @Test func animationLoops() {
        let cursor = SoftwareCursor()
        let frames = (0..<8).map { _ in Tex() }
        cursor.frames = frames

        // Advance one full loop; it wraps back to frame 0. (One update call —
        // stepwise 0.05 additions accumulate float error below the loop
        // length; a single product matches the wrap threshold exactly.)
        cursor.update(deltaTime: SoftwareCursor.frameDuration * Double(frames.count))
        #expect(cursor.currentTexture === frames[0])
    }

    @Test func fallsBackToSingleTextureWhenNoFrames() {
        let cursor = SoftwareCursor()
        let single = Tex()
        cursor.texture = single
        // update is a no-op with no frames, and currentTexture uses the fallback.
        cursor.update(deltaTime: 1)
        #expect(cursor.currentTexture === single)
    }
}
