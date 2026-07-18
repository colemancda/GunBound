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
/// from the header, so any size decodes. (The `.xtf` string never appears in
/// the original binary — these are loaded as generic cache surfaces by name,
/// per `FILEFORMATS.md` — so the header layout is empirical, not
/// decomp-confirmed.)
public enum XtfFile {

    public enum Error: Swift.Error, Equatable {
        /// A zero or absurd dimension in the header.
        case invalidDimensions(width: Int, height: Int)
    }

    /// A dimension bound far beyond any real surface (the originals are all
    /// 256×256) that keeps a corrupt header from driving a huge allocation.
    public static let maxDimension = 0x4000

    /// Decodes a `.xtf` surface into an `ImgFile.Frame` — the same pixel
    /// representation `.img` frames use, so it flows through the identical
    /// texture pipeline.
    public static func decode(_ data: [UInt8]) throws -> ImgFile.Frame {
        try data.withParserSpan { input in
            try decode(parsing: &input)
        }
    }

    /// Decodes a `.xtf` surface from a `ParserSpan` positioned at the start
    /// of the 9-byte header; consumes the header and the pixel body.
    public static func decode(parsing input: inout ParserSpan) throws -> ImgFile.Frame {
        let width = Int(try UInt32(parsingLittleEndian: &input))
        let height = Int(try UInt32(parsingLittleEndian: &input))
        let format = try UInt8(parsing: &input)

        guard width > 0, height > 0, width <= Self.maxDimension, height <= Self.maxDimension else {
            throw Error.invalidDimensions(width: width, height: height)
        }
        let pixelCount = width * height
        let body = try [UInt8](parsing: &input, byteCount: pixelCount * 2)

        let isAlpha = format == 1
        var pixels: [ImgFile.Pixel] = []
        pixels.reserveCapacity(pixelCount)
        for i in 0..<pixelCount {
            let raw = UInt16(body[i * 2]) | (UInt16(body[i * 2 + 1]) << 8)
            pixels.append(isAlpha ? ImgFile.Pixel(argb4444: raw) : ImgFile.Pixel(rgb565: raw))
        }
        return ImgFile.Frame(
            transparencyType: isAlpha ? .alpha : .none,
            width: Int32(width), height: Int32(height), pixels: pixels
        )
    }
}
