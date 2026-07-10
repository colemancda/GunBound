import GunBound
import GunBoundFile

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

    /// Builds a texture from an already-decoded (and possibly
    /// caller-mutated) sprite frame — the terrain-destruction path: the
    /// battle screen punches blast holes into the stage frame's pixels
    /// and rebuilds its texture from them.
    func texture(from frame: ImgFile.Frame) -> ClientTexture?

    /// The texture's pixel size, `(0, 0)` if unavailable.
    func size(of texture: ClientTexture?) -> (width: Float, height: Float)

    /// Clears the window to the backend's default background before a
    /// screen draws anything on top.
    func clear()

    /// Draws `texture` stretched into `rect` (window/logical coordinates),
    /// optionally tinted (used for hover-state highlighting) — `nil` means
    /// draw at the texture's own natural color — composited with `blend`.
    /// `opacity` (`0…1`) scales the whole draw's alpha, for translucent
    /// overlays like the modal dialog's screen dim; `1` is fully opaque.
    func draw(_ texture: ClientTexture, in rect: Rect, tint: (r: UInt8, g: UInt8, b: UInt8)?, blend: ClientBlendMode, opacity: Float)

    /// Presents the frame — called once per frame by the state machine
    /// after the current screen has drawn, not per-screen.
    func present()
}

/// The compositing modes the original renders with — its in-battle scene
/// composer (`State11_InBattle_Render`, `0x4c3020`) caches exactly two
/// D3D blend configurations and flips between them per layer:
/// mode 1 = **normal alpha** (`SRCBLEND=SRCALPHA, DESTBLEND=INVSRCALPHA`),
/// mode 2 = **additive glow** (`SRCBLEND=SRCALPHA, DESTBLEND=ONE`) — used by
/// the Jewel second pass, `SpecialTexture2`, and other glow effects.
public enum ClientBlendMode: Sendable {
    case alpha
    case additive
}

public extension ClientRenderer {
    /// Loads the first frame of a named `.img` resource — the common case
    /// for full-window backgrounds and single-frame button chrome.
    func texture(named name: String, assets: AssetLibrary) -> ClientTexture? {
        texture(named: name, frame: 0, assets: assets)
    }

    /// Blend-composited draw at full opacity — the common overload for
    /// effects layers that pass `.additive`.
    func draw(_ texture: ClientTexture, in rect: Rect, tint: (r: UInt8, g: UInt8, b: UInt8)?, blend: ClientBlendMode) {
        draw(texture, in: rect, tint: tint, blend: blend, opacity: 1)
    }

    /// Alpha-blended, fully-opaque draw — the default for all UI chrome;
    /// effects layers pass `.additive`, overlays pass `opacity`.
    func draw(_ texture: ClientTexture, in rect: Rect, tint: (r: UInt8, g: UInt8, b: UInt8)?) {
        draw(texture, in: rect, tint: tint, blend: .alpha, opacity: 1)
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
