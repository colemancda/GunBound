import CSDL3
import SDL3Swift
import GunBound
import GunBoundClient

/// Wraps an `SDLTexture` to satisfy the backend-agnostic `ClientTexture`
/// marker protocol.
final class SDL3ClientTexture: ClientTexture {
    let texture: SDLTexture

    init(_ texture: SDLTexture) {
        self.texture = texture
    }
}

/// `ClientRenderer` implemented against SDL3 (`SDLRenderer`/`SDLTexture`).
/// Textures are built directly from decoded `.img` pixel data (`FrameTexture`)
/// rather than an image-file loader, since `.img` frames are already fully
/// decoded to raw RGBA (`ImgFile.Pixel`) — see `FrameTexture`'s doc comment.
@MainActor
final class SDL3Renderer: ClientRenderer {
    let renderer: SDLRenderer

    init(renderer: SDLRenderer) {
        self.renderer = renderer
    }

    func texture(named name: String, frame frameIndex: Int, assets: AssetLibrary) -> ClientTexture? {
        do {
            let frame = try assets.imageFrame(named: name, at: frameIndex)
            let texture = try FrameTexture.make(renderer: renderer, frame: frame)
            return SDL3ClientTexture(texture)
        } catch {
            print("[GunBoundSDL3] warning: couldn't load image '\(name)#\(frameIndex)': \(error)")
            return nil
        }
    }

    func size(of texture: ClientTexture?) -> (width: Float, height: Float) {
        guard let texture = texture as? SDL3ClientTexture, let attributes = try? texture.texture.attributes() else {
            return (0, 0)
        }
        return (Float(attributes.width), Float(attributes.height))
    }

    func clear() {
        try? renderer.setDrawColor(red: 0, green: 0, blue: 0)
        try? renderer.clear()
    }

    func draw(_ texture: ClientTexture, in rect: Rect, tint: (r: UInt8, g: UInt8, b: UInt8)?, blend: ClientBlendMode) {
        guard let texture = texture as? SDL3ClientTexture else { return }
        try? texture.texture.setBlendMode([blend == .additive ? .additive : .alpha])
        if let tint {
            try? texture.texture.setColorModulation(red: tint.r, green: tint.g, blue: tint.b)
        } else {
            try? texture.texture.setColorModulation(red: 255, green: 255, blue: 255)
        }
        let destination = SDL_FRect(x: rect.x, y: rect.y, w: rect.width, h: rect.height)
        try? renderer.copy(texture.texture, destination: destination)
    }

    func present() {
        renderer.present()
    }
}
