import CSDL2
import SDL2Swift
import GunBoundFile

/// Builds an `SDLTexture` from a decoded `.img` frame's `Pixel` array.
///
/// `.img` frames are already fully decoded to 8-bit-per-channel RGBA
/// (`ImgFile.Pixel`), so no image-file loader (`SDL2Image`) is needed here —
/// this just repacks each pixel into a native-endian `ARGB8888` word (as
/// `SDL_PIXELFORMAT_ARGB8888` expects) and uploads it directly, mirroring
/// `GunBoundSDL3`'s `FrameTexture`.
enum FrameTexture {

    static func make(renderer: SDLRenderer, frame: ImgFile.Frame) throws -> SDLTexture {
        let width = Int(frame.width)
        let height = Int(frame.height)
        let texture = try SDLTexture(
            renderer: renderer,
            format: .argb8888,
            access: .static,
            width: width,
            height: height
        )
        try texture.setBlendMode([.alpha])

        var packed = [UInt32]()
        packed.reserveCapacity(frame.pixels.count)
        for pixel in frame.pixels {
            let value =
                (UInt32(pixel.alpha) << 24)
                | (UInt32(pixel.red) << 16)
                | (UInt32(pixel.green) << 8)
                | UInt32(pixel.blue)
            packed.append(value)
        }

        try packed.withUnsafeMutableBytes { buffer in
            try texture.update(pixels: buffer.baseAddress!, pitch: width * 4)
        }

        return texture
    }
}
