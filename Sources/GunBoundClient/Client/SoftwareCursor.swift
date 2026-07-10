import GunBound

/// The custom in-game pointer, drawn in software. The original hides the OS
/// cursor once at startup (`ShowCursor(0)` in `WinMain`) and blits
/// `cursor.img` at the mouse position at the very end of every frame
/// (`GameTick`, after all screen content), so the pointer always sits on top.
///
/// `cursor.img` is a 22×22 sprite; its tip is the top-left corner and the
/// decomp blits straight at the mouse coordinates with no offset, so the
/// hotspot is (0, 0). The `-1 < frame` draw gate means a frame of `-1` hides
/// the cursor — a sentinel modelled here by `isVisible`.
///
/// The sheet holds **102 frames** — a multi-context pointer set (the arrow,
/// edge-scroll direction arrows, a grab hand, mouse icons). In the art, frames
/// **0–7** read as the normal arrow's idle **shine loop** (a highlight sweeping
/// across the blue arrow), which this port animates.
///
/// **This animation is an intentional cosmetic divergence — the decomp does
/// *not* confirm it.** `GameTick` blits the cursor as
/// `BlitSpriteClipped(g_cursorFrame)`, and `g_cursorFrame` (`0x7a7674`) occurs
/// exactly once in the whole binary (that read), lives in zero-init data, and
/// is **never written — always `0`**. `FindSpriteFrame` is a stateless
/// `(spriteSet, frameIndex)` lookup with no time-advance. So the only
/// recoverable evidence is a **static frame-0 cursor**; whether the sheet ever
/// cycles depends on register setup Ghidra doesn't recover and "can't be
/// determined from the ported code" (the sole confirmed time-based cursor
/// behaviour is the replay-mode blink, not this shine loop). The loop range
/// and rate below are therefore this port's own choice. When `frames` is empty
/// the cursor falls back to the single `texture` (i.e. the faithful frame-0
/// draw).
@MainActor
public final class SoftwareCursor {

    /// The cursor sprite sheet, preloaded by the original on every
    /// `ChangeGameState` via `FindPreloadedTextureByName("cursor")`.
    public static let sheetName = "cursor.img"

    /// The frame range this port animates as the arrow's idle shine sweep.
    /// A cosmetic divergence — the decomp draws frame 0 statically; see the
    /// type doc.
    public static let arrowFrames = 0..<8
    /// Seconds each arrow frame holds (~12.5 fps; ~0.64s per loop).
    public static let frameDuration: Double = 0.08

    /// The current pointer position, in the same logical screen coordinates
    /// (origin top-left) the screens and renderer already use.
    public var position: (x: Float, y: Float) = (0, 0)

    /// When false the cursor isn't drawn (e.g. touch platforms with no
    /// pointer).
    public var isVisible = true

    /// The animated arrow frames (`cursor.img` frames 0–7). Set by whoever
    /// loads the sheet; when empty the cursor draws `texture` instead.
    public var frames: [ClientTexture] = []

    /// A single-frame fallback (frame 0) used when `frames` is empty.
    public var texture: ClientTexture?

    private var elapsed: Double = 0

    public init() {}

    /// The current animation frame, or the single-frame fallback.
    public var currentTexture: ClientTexture? {
        guard !frames.isEmpty else { return texture }
        let index = Int(elapsed / Self.frameDuration) % frames.count
        return frames[index]
    }

    /// Advances the idle animation; call once per frame with the frame's
    /// delta time.
    public func update(deltaTime: Double) {
        guard !frames.isEmpty else { return }
        elapsed += deltaTime
        // Keep `elapsed` bounded so it doesn't lose precision over a long
        // session (one loop's worth is all the modulo needs).
        let loop = Double(frames.count) * Self.frameDuration
        if elapsed >= loop { elapsed -= loop }
    }

    /// Draws the cursor at `position`, hotspot (0, 0). Call last, after the
    /// screen has drawn, so the pointer is always on top.
    public func draw(_ renderer: ClientRenderer) {
        guard isVisible, let texture = currentTexture else { return }
        let (width, height) = renderer.size(of: texture)
        renderer.draw(texture, in: Rect(x: position.x, y: position.y, width: width, height: height), tint: nil)
    }
}
