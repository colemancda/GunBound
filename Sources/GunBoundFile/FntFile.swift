/// Decoder for the client's `font.fnt` bitmap font.
///
/// `font.fnt` is a raw, headerless 1-bit-per-pixel glyph blob — two
/// consecutive fixed-size blocks (reverse-engineered from the file; matches
/// the two runtime glyph tables in the decompiled client, ASCII stride 12 and
/// DBCS stride 24):
///
/// - **ASCII block**: 128 glyphs, one per byte value `0...127`, `8×12`
///   monochrome, `12` bytes each (one byte per row, MSB = leftmost pixel).
///   Glyph for code `c` is at offset `c * 12`.
/// - **DBCS block** (EUC-KR Korean): 32,768 glyphs, `~16×12`, `24` bytes each
///   (two bytes per row), starting at offset `128 * 12 = 1536`.
///
/// `128 * 12 + 32768 * 24 = 787,968` bytes — exactly the file size.
///
/// Only the ASCII block is decoded here (the Latin text the client's room
/// names / chat / usernames use); the DBCS block is left for later.
public enum FntFile {

    public static let asciiGlyphCount = 128
    public static let glyphHeight = 12
    static let asciiGlyphWidth = 8
    static let asciiGlyphStride = 12  // bytes per glyph (one byte per row)

    /// Width used for glyphs with no set pixels (space and control codes).
    static let blankGlyphWidth: Int32 = 4

    /// Decodes the 128 ASCII glyphs into frames, one per byte value `0...127`
    /// (so frame index == character code). Each frame is trimmed to its
    /// glyph's actual pixel width for proportional rendering; blank glyphs
    /// (space, control codes) become a fixed-width empty frame.
    ///
    /// Set pixels are opaque white (tint at draw time for color); unset
    /// pixels are transparent.
    public static func readASCIIGlyphs(_ data: [UInt8]) -> [ImgFile.Frame] {
        var frames = [ImgFile.Frame]()
        frames.reserveCapacity(asciiGlyphCount)

        for code in 0..<asciiGlyphCount {
            let base = code * asciiGlyphStride
            guard base + asciiGlyphStride <= data.count else {
                frames.append(blankGlyph())
                continue
            }
            let rows = Array(data[base..<base + glyphHeight])

            // Rightmost set column + 1 → the glyph's drawn width.
            var usedWidth = 0
            for row in rows {
                for x in 0..<asciiGlyphWidth where row & (0x80 >> UInt8(x)) != 0 {
                    usedWidth = max(usedWidth, x + 1)
                }
            }
            guard usedWidth > 0 else {
                frames.append(blankGlyph())
                continue
            }

            var pixels = [ImgFile.Pixel]()
            pixels.reserveCapacity(usedWidth * glyphHeight)
            for row in rows {
                for x in 0..<usedWidth {
                    let isSet = row & (0x80 >> UInt8(x)) != 0
                    pixels.append(isSet ? white : .transparent)
                }
            }
            frames.append(ImgFile.Frame(width: Int32(usedWidth), height: Int32(glyphHeight), pixels: pixels))
        }
        return frames
    }

    private static let white = ImgFile.Pixel(red: 255, green: 255, blue: 255, alpha: 255)

    private static func blankGlyph() -> ImgFile.Frame {
        ImgFile.Frame(
            width: blankGlyphWidth,
            height: Int32(glyphHeight),
            pixels: Array(repeating: .transparent, count: Int(blankGlyphWidth) * glyphHeight)
        )
    }
}
