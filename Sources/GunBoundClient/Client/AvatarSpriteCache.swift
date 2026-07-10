import GunBoundProtocol
import GunBoundFile

/// Composites and caches avatar outfits — the client-side face of
/// `AvatarComposite` (the `LoadAvatarSprites` port), shared by every screen
/// that draws a dressed character: the Ready Room slots, the Avatar Store's
/// live preview, and eventually the in-battle rider.
///
/// Keyed by the packed `avatarEquipped` value; failures (missing part
/// sprites) are cached too so they aren't retried every frame.
@MainActor
public final class AvatarSpriteCache {

    private var composites: [UInt64: ClientTexture?] = [:]

    public init() {}

    /// The composited texture for an outfit — body/head/glasses/flag part
    /// sprites (frame 0) hotspot-aligned into one texture. `nil` when no
    /// layer could be loaded.
    public func sprite(equipped: UInt64, assets: AssetLibrary, renderer: ClientRenderer) -> ClientTexture? {
        if let cached = composites[equipped] { return cached }
        var layers: [ImgFile.Frame] = []
        let equipment = AvatarEquipment(rawValue: equipped)
        for category in AvatarEquipment.Category.allCases {
            guard let name = equipment.spriteName(category),
                  let frame = try? assets.firstImageFrame(named: name) else { continue }
            layers.append(frame)
        }
        let texture = AvatarComposite.compose(layers).flatMap { renderer.texture(from: $0) }
        composites[equipped] = texture
        return texture
    }

    /// Drops every cached composite (screen exit).
    public func reset() {
        composites = [:]
    }
}
