import GunBound

/// The custom in-game pointer, drawn in software. The original hides the OS
/// cursor once at startup (`ShowCursor(0)` in `WinMain`) and blits
/// `cursor.img` at the mouse position at the very end of every frame
/// (`GameTick`, after all screen content), so the pointer always sits on top.
///
/// `cursor.img` is a 22×22 sprite whose frame 0 is the arrow; its tip is the
/// top-left corner, and the decomp blits straight at the mouse coordinates
/// with no offset, so the hotspot is (0, 0). The sheet holds 102 frames, but
/// the base client's mouse pointer is *always* frame 0: the frame index
/// (`DAT_007a7674`) is never written anywhere in the decompiled game, only
/// read in `GameTick`. Its `-1 < frame` draw gate means a frame of `-1` hides
/// the cursor — a sentinel that's never actually set, modelled here by
/// `isVisible`. (The only direction-dependent pointer is the in-battle
/// edge-scroll cursor, a separate OS-`HCURSOR` system, not this sprite.)
/// `texture` is still exposed so a caller could swap frames if a later screen
/// ever needs to.
@MainActor
public final class SoftwareCursor {

    /// The cursor sprite sheet, preloaded by the original on every
    /// `ChangeGameState` via `FindPreloadedTextureByName("cursor")`.
    public static let sheetName = "cursor.img"

    /// The current pointer position, in the same logical screen coordinates
    /// (origin top-left) the screens and renderer already use.
    public var position: (x: Float, y: Float) = (0, 0)

    /// When false the cursor isn't drawn (e.g. touch platforms with no
    /// pointer).
    public var isVisible = true

    /// The cursor artwork (frame 0 = arrow by default). Set by whoever loads
    /// it, since `SoftwareCursor` stays renderer-agnostic and holds no
    /// `AssetLibrary`.
    public var texture: ClientTexture?

    public init() {}

    /// Draws the cursor at `position`, hotspot (0, 0). Call last, after the
    /// screen has drawn, so the pointer is always on top.
    public func draw(_ renderer: ClientRenderer) {
        guard isVisible, let texture else { return }
        let (width, height) = renderer.size(of: texture)
        renderer.draw(texture, in: Rect(x: position.x, y: position.y, width: width, height: height), tint: nil)
    }
}
