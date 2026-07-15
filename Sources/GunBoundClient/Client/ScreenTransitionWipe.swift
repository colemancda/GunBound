import GunBound
import GunBoundFile

/// The screen-transition wipe every `ChangeGameState` call triggers in the
/// original (decomp `GameTick.c`/`FUN_004edaa0`, `globals.c`'s
/// `DAT_0056d11c` table): the screen instantly covers in solid black, then
/// two right-triangle wedges — one hinged at the top-left corner, one at
/// the bottom-right — shrink away over 11 steps, revealing the new screen
/// along a diagonal seam.
///
/// **Decoded exactly:** `ChangeGameState` always arms the counter at its
/// maximum (`DAT_0056d108 = 10`, counting down), and the two `DrawPrimitive`
/// calls' vertex coordinates pin the wedge geometry precisely —
/// top-left wedge `(0,0)–(800,0)–(0,W)`, bottom-right wedge
/// `(800,600−W)–(800,600)–(0,600)`, both solid opaque black
/// (`0xff000000`), where `W` is `DAT_0056d11c[tick]` and the table is the
/// compile-time constant `[2,4,8,16,32,64,128,256,512,1024,1024]` walked
/// **backwards** (starting at `W=1024`, which already exceeds the 800×600
/// canvas so the first frame is a full black-out, down to `W=2` just
/// before the wedges vanish). **Not recovered:** the original's per-tick
/// rate (its fixed-timestep Hz isn't decoded), so this drives the same 11
/// steps on a wall-clock duration instead of a frame-locked one.
///
/// Our `ClientRenderer` has no arbitrary-triangle primitive, so each wedge
/// is approximated with a staircase of thin solid-black rects — visually
/// indistinguishable from the true diagonal at the step count used here.
@MainActor
final class ScreenTransitionWipe {

    private static let table: [Float] = [1024, 512, 256, 128, 64, 32, 16, 8, 4, 2, 2]
    /// Tuned for a snappy but clearly visible transition (~0.55s total);
    /// the original's real per-tick rate isn't recovered from the decomp.
    private static let stepDuration = 0.05
    private static let staircaseSteps = 48
    private static let canvasSize = (width: Float(800), height: Float(600))

    private var index: Int?
    private var elapsed: Double = 0
    private var pixelTexture: ClientTexture?

    /// Arms the wipe at full coverage — call on every screen transition.
    func begin() {
        index = 0
        elapsed = 0
    }

    /// Advances at most one table step per call, matching the original's
    /// real semantics (`GameTick` advances its counter by exactly 1 per
    /// tick, never more). This also guards against a stalled frame (e.g.
    /// the new screen's `onEnter` doing synchronous texture loads) reporting
    /// one inflated `deltaTime` that would otherwise fast-forward through
    /// the whole table before a single frame ever got drawn.
    func update(deltaTime: Double) {
        guard let currentIndex = index else { return }
        elapsed += deltaTime
        guard elapsed >= Self.stepDuration else { return }
        elapsed = 0
        let next = currentIndex + 1
        index = next < Self.table.count ? next : nil
    }

    func draw(_ renderer: ClientRenderer) {
        guard let index else { return }
        if pixelTexture == nil {
            pixelTexture = renderer.texture(from: ImgFile.Frame(
                width: 1, height: 1,
                pixels: [ImgFile.Pixel(red: 0, green: 0, blue: 0, alpha: 255)]
            ))
        }
        guard let pixelTexture else { return }

        let width = Self.table[index]
        let (canvasWidth, canvasHeight) = Self.canvasSize
        let steps = Self.staircaseSteps

        // Top-left wedge: right angle at (0,0), hypotenuse (800,0)-(0,width).
        let topExtent = min(width, canvasHeight)
        for i in 0..<steps {
            let y0 = Float(i) / Float(steps) * topExtent
            let y1 = Float(i + 1) / Float(steps) * topExtent
            guard y0 < canvasHeight else { break }
            let rowWidth = min(canvasWidth, max(0, canvasWidth * (1 - y0 / width)))
            guard rowWidth > 0 else { continue }
            renderer.draw(pixelTexture, in: Rect(x: 0, y: y0, width: rowWidth, height: y1 - y0), tint: nil)
        }

        // Bottom-right wedge: right angle at (800,600), hypotenuse (800,600-width)-(0,600).
        let bottomExtent = min(width, canvasHeight)
        let bottomStart = canvasHeight - bottomExtent
        for i in 0..<steps {
            let d0 = Float(i) / Float(steps) * bottomExtent
            let d1 = Float(i + 1) / Float(steps) * bottomExtent
            let y0 = bottomStart + d0
            guard y0 >= 0, y0 < canvasHeight else { continue }
            let rowWidth = min(canvasWidth, max(0, canvasWidth * (d0 / width)))
            guard rowWidth > 0 else { continue }
            renderer.draw(pixelTexture, in: Rect(x: canvasWidth - rowWidth, y: y0, width: rowWidth, height: d1 - d0), tint: nil)
        }
    }
}
