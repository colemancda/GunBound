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
/// edge-scroll direction arrows, a grab hand, mouse icons). Frames **0–7**
/// are the normal arrow's idle **shine loop**. The decomp confirms the sheet
/// is animated but the frame-selection/time-base lives in an unported blit
/// (`g_cursorTexture`/`DAT_007a7674`), so which-frame/how-fast **isn't
/// recovered** — the loop range and rate below are this port's own choice, a
/// documented divergence. When `frames` is empty the cursor falls back to the
/// single `texture`.
@MainActor
public final class SoftwareCursor {

    /// The cursor sprite sheet, preloaded by the original on every
    /// `ChangeGameState` via `FindPreloadedTextureByName("cursor")`.
    public static let sheetName = "cursor.img"

    /// The normal arrow's idle-animation frame range in `cursor.img` (the
    /// shine sweep). Not decomp-confirmed — see the type doc.
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
