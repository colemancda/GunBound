import GunBound

/// An opaque handle to a loaded texture — a marker protocol rather than a
/// concrete type so each rendering backend (SDL3, SpriteKit, ...) can wrap
/// whatever its own texture/image type is (`SDLTexture`, `SKTexture`, etc.)
/// without `GameScreen`s ever needing to know which backend is in use.
@MainActor
public protocol ClientTexture: AnyObject {}

/// What a screen needs from a rendering backend: load a named `.img`
/// resource into a texture, query its size, and draw it — everything a
/// `GameScreen` does is expressed in terms of this protocol plus `Rect`, so
/// the same screen implementation works unmodified against SDL3, SpriteKit,
/// or any other backend that implements it.
@MainActor
public protocol ClientRenderer: AnyObject {
    /// Loads (decoding via `AssetLibrary` as needed) a texture for a specific
    /// frame of a named `.img` sprite sheet, or `nil` if it couldn't be
    /// loaded (logged by the implementation — screens treat a missing asset
    /// as "just don't draw it" rather than a fatal error).
    func texture(named name: String, frame frameIndex: Int, assets: AssetLibrary) -> ClientTexture?

    /// The texture's pixel size, `(0, 0)` if unavailable.
    func size(of texture: ClientTexture?) -> (width: Float, height: Float)

    /// Clears the window to the backend's default background before a
    /// screen draws anything on top.
    func clear()

    /// Draws `texture` stretched into `rect` (window/logical coordinates),
    /// optionally tinted (used for hover-state highlighting) — `nil` means
    /// draw at the texture's own natural color.
    func draw(_ texture: ClientTexture, in rect: Rect, tint: (r: UInt8, g: UInt8, b: UInt8)?)

    /// Presents the frame — called once per frame by the state machine
    /// after the current screen has drawn, not per-screen.
    func present()
}

public extension ClientRenderer {
    /// Loads the first frame of a named `.img` resource — the common case
    /// for full-window backgrounds and single-frame button chrome.
    func texture(named name: String, assets: AssetLibrary) -> ClientTexture? {
        texture(named: name, frame: 0, assets: assets)
    }
}

/// Draws `texture` at the origin, at its own native pixel size — the common
/// case for full-window backgrounds/overlays.
@MainActor
public func drawFullSize(_ texture: ClientTexture?, using renderer: ClientRenderer) {
    guard let texture else { return }
    let (width, height) = renderer.size(of: texture)
    renderer.draw(texture, in: Rect(x: 0, y: 0, width: width, height: height), tint: nil)
}
