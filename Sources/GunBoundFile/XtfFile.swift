/// GunBound's `.xtf` texture surfaces — the raw D3D textures the original
/// binds by name through its texture cache (e.g. `TornadoTexture`,
/// `FirewallTexture`, `LightningTexture`, and the runtime `AvataTexture`/
/// `BulletTexture`/… render targets).
///
/// Unlike `.img`, a `.xtf` is not a sprite sheet: it's a single flat 16-bit
/// surface behind a fixed 9-byte header:
///
///     [width:  u32 little-endian]
///     [height: u32 little-endian]
///     [format: u8]
///
/// followed by a `width × height × 2`-byte pixel body. The format byte
/// selects the encoding — `1` = ARGB4444 (alpha), anything else = flat
/// RGB565. The header layout was confirmed empirically against every `.xtf`
/// shipped in `graphics.xfs` (all 256×256, format 1); dimensions are read
/// from the header, so any size decodes.
public enum XtfFile {

    public enum Error: Swift.Error, Equatable {
        /// Fewer bytes than the 9-byte header, or a body shorter than
        /// `width × height × 2`.
        case truncated
        /// A zero or absurd dimension in the header.
        case invalidDimensions(width: Int, height: Int)
    }

    static let headerSize = 6 + 1 + 2  // two u32 + a format byte (9)

    /// Decodes a `.xtf` surface into an `ImgFile.Frame` — the same pixel
    /// representation `.img` frames use, so it flows through the identical
    /// texture pipeline.
    public static func decode(_ data: [UInt8]) throws -> ImgFile.Frame {
        guard data.count >= 9 else { throw Error.truncated }

        func readUInt32LE(at index: Int) -> Int {
            Int(data[index]) | (Int(data[index + 1]) << 8)
                | (Int(data[index + 2]) << 16) | (Int(data[index + 3]) << 24)
        }
        let width = readUInt32LE(at: 0)
        let height = readUInt32LE(at: 4)
        let format = data[8]

        guard width > 0, height > 0, width <= 0x4000, height <= 0x4000 else {
            throw Error.invalidDimensions(width: width, height: height)
        }
        let pixelCount = width * height
        guard data.count >= 9 + pixelCount * 2 else { throw Error.truncated }

        let isAlpha = format == 1
        var pixels: [ImgFile.Pixel] = []
        pixels.reserveCapacity(pixelCount)
        var offset = 9
        for _ in 0..<pixelCount {
            let raw = UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
            pixels.append(isAlpha ? ImgFile.Pixel(argb4444: raw) : ImgFile.Pixel(rgb565: raw))
            offset += 2
        }
        return ImgFile.Frame(
            transparencyType: isAlpha ? .alpha : .none,
            width: Int32(width), height: Int32(height), pixels: pixels
        )
    }
}
