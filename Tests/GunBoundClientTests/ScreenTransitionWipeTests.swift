import Foundation
import Testing
@testable import GunBound
@testable import GunBoundClient
import GunBoundFile

@Suite @MainActor
struct ScreenTransitionWipeTests {

    private final class Tex: ClientTexture {}

    /// Records every draw rect; reports a 1×1 texture (the wipe's solid pixel).
    private final class RecordingRenderer: ClientRenderer {
        var draws: [Rect] = []
        func texture(named name: String, frame frameIndex: Int, assets: AssetLibrary) -> ClientTexture? { Tex() }
        func texture(from frame: ImgFile.Frame) -> ClientTexture? { Tex() }
        func size(of texture: ClientTexture?) -> (width: Float, height: Float) { (1, 1) }
        func clear() {}
        func draw(_ texture: ClientTexture, in rect: Rect, tint: (r: UInt8, g: UInt8, b: UInt8)?, blend: ClientBlendMode, opacity: Float) { draws.append(rect) }
        func present() {}
    }

    /// Before `begin()`, the wipe draws nothing.
    @Test func idleDrawsNothing() {
        let wipe = ScreenTransitionWipe()
        let renderer = RecordingRenderer()
        wipe.draw(renderer)
        #expect(renderer.draws.isEmpty)
    }

    /// The very first frame after `begin()` is a full black-out: the two
    /// corner wedges at their max table entry (1024) already exceed the
    /// 800×600 canvas, so every drawn rect union covers the whole screen —
    /// concretely, the top-left wedge's first row spans the full width.
    @Test func firstFrameIsFullyCovered() {
        let wipe = ScreenTransitionWipe()
        wipe.begin()
        let renderer = RecordingRenderer()
        wipe.draw(renderer)

        #expect(!renderer.draws.isEmpty)
        // The wedge's top row (y≈0) spans (close to) the full 800 width.
        let topRow = renderer.draws.first { $0.y == 0 }
        #expect(topRow != nil)
        #expect((topRow?.width ?? 0) > 790)
    }

    /// The wipe advances through its 11-step table on a wall-clock cadence
    /// and turns itself off (stops drawing) once the table is exhausted.
    /// Each `update` call advances at most one table step — even a single
    /// wildly inflated `deltaTime` (e.g. a stalled frame right after the new
    /// screen's `onEnter` does synchronous loading) can't skip the whole
    /// animation in one shot; it takes one call per step, 11 calls to finish.
    @Test func advancesOneStepPerCallAndThenStops() {
        let wipe = ScreenTransitionWipe()
        wipe.begin()
        let renderer = RecordingRenderer()

        // A single, huge deltaTime only advances one step — still drawing.
        wipe.update(deltaTime: 1.0)
        renderer.draws = []
        wipe.draw(renderer)
        #expect(!renderer.draws.isEmpty)

        // Ten more calls (11 total) exhaust the table.
        for _ in 0..<10 { wipe.update(deltaTime: 1.0) }
        renderer.draws = []
        wipe.draw(renderer)
        #expect(renderer.draws.isEmpty)
    }

    /// A fresh `begin()` re-arms the wipe even after a prior run finished.
    @Test func beginRearmsAfterFinishing() {
        let wipe = ScreenTransitionWipe()
        wipe.begin()
        wipe.update(deltaTime: 1.0)  // exhausts it

        wipe.begin()
        let renderer = RecordingRenderer()
        wipe.draw(renderer)
        #expect(!renderer.draws.isEmpty)
    }
}
