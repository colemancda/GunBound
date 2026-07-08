import CSDL2
import SDL2Swift
import GunBound
import GunBoundClient

/// Wraps an `SDLTexture` to satisfy the backend-agnostic `ClientTexture`
/// marker protocol.
final class SDL2ClientTexture: ClientTexture {
    let texture: SDLTexture

    init(_ texture: SDLTexture) {
        self.texture = texture
    }
}

/// `ClientRenderer` implemented against SDL2 (`SDLRenderer`/`SDLTexture`).
/// Textures are built directly from decoded `.img` pixel data (`FrameTexture`)
/// rather than an image-file loader, mirroring `GunBoundSDL3`'s `SDL3Renderer`.
@MainActor
final class SDL2Renderer: ClientRenderer {
    let renderer: SDLRenderer

    init(renderer: SDLRenderer) {
        self.renderer = renderer
    }

    func texture(named name: String, assets: AssetLibrary) -> ClientTexture? {
        do {
            let frame = try assets.firstImageFrame(named: name)
            let texture = try FrameTexture.make(renderer: renderer, frame: frame)
            return SDL2ClientTexture(texture)
        } catch {
            print("[GunBoundSDL2] warning: couldn't load image '\(name)': \(error)")
            return nil
        }
    }

    func size(of texture: ClientTexture?) -> (width: Float, height: Float) {
        guard let texture = texture as? SDL2ClientTexture, let attributes = try? texture.texture.attributes() else {
            return (0, 0)
        }
        return (Float(attributes.width), Float(attributes.height))
    }

    func clear() {
        try? renderer.setDrawColor(red: 0, green: 0, blue: 0)
        try? renderer.clear()
    }

    func draw(_ texture: ClientTexture, in rect: Rect, tint: (r: UInt8, g: UInt8, b: UInt8)?) {
        guard let texture = texture as? SDL2ClientTexture else { return }
        if let tint {
            try? texture.texture.setColorModulation(red: tint.r, green: tint.g, blue: tint.b)
        } else {
            try? texture.texture.setColorModulation(red: 255, green: 255, blue: 255)
        }
        // SDL2's simple (non-rotated) `copy(_:destination:)` overload only
        // takes an integer `SDL_Rect` — unlike SDL3's `SDL_FRect`-based one —
        // so the float `Rect` is rounded here rather than passed through.
        let destination = SDL_Rect(
            x: Int32(rect.x.rounded()),
            y: Int32(rect.y.rounded()),
            w: Int32(rect.width.rounded()),
            h: Int32(rect.height.rounded())
        )
        try? renderer.copy(texture.texture, destination: destination)
    }

    func present() {
        renderer.present()
    }
}
