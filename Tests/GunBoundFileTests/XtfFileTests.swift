import Testing
@testable import GunBoundFile

@Suite struct XtfFileTests {

    /// Builds a `.xtf` byte blob: `[width u32 LE][height u32 LE][format u8]`
    /// then a `width*height` run of 16-bit little-endian pixels.
    private func makeXtf(width: Int, height: Int, format: UInt8, pixels: [UInt16]) -> [UInt8] {
        var bytes: [UInt8] = []
        func appendU32(_ v: Int) {
            bytes.append(UInt8(v & 0xff)); bytes.append(UInt8((v >> 8) & 0xff))
            bytes.append(UInt8((v >> 16) & 0xff)); bytes.append(UInt8((v >> 24) & 0xff))
        }
        appendU32(width); appendU32(height); bytes.append(format)
        for p in pixels { bytes.append(UInt8(p & 0xff)); bytes.append(UInt8(p >> 8)) }
        return bytes
    }

    /// Format 1 decodes as ARGB4444, dimensions come from the header, and the
    /// alpha channel survives.
    @Test func decodesArgb4444() throws {
        // 2×2, one opaque red, one transparent — raw ARGB4444 0xAF00 etc.
        let pixels: [UInt16] = [0xF00F, 0x0F00, 0xFFFF, 0x0000]
        let frame = try XtfFile.decode(makeXtf(width: 2, height: 2, format: 1, pixels: pixels))
        #expect(frame.width == 2)
        #expect(frame.height == 2)
        #expect(frame.transparencyType == .alpha)
        #expect(frame.pixels.count == 4)
        // 0xF00F -> a=15, r=0, g=0, b=15 (all scaled ×17).
        #expect(frame.pixels[0] == ImgFile.Pixel(argb4444: 0xF00F))
        // 0x0F00 -> alpha 0 (transparent).
        #expect(frame.pixels[1].alpha == 0)
    }

    /// A non-1 format byte decodes as opaque RGB565, and non-square
    /// dimensions read straight from the header.
    @Test func decodesRgb565AndNonSquare() throws {
        let pixels: [UInt16] = [0xF800, 0x07E0, 0x001F]  // pure R, G, B in 565
        let frame = try XtfFile.decode(makeXtf(width: 3, height: 1, format: 0, pixels: pixels))
        #expect(frame.width == 3)
        #expect(frame.height == 1)
        #expect(frame.transparencyType == .none)
        #expect(frame.pixels.allSatisfy { $0.alpha == 255 })  // RGB565 is always opaque
        #expect(frame.pixels[0] == ImgFile.Pixel(rgb565: 0xF800))
    }

    @Test func rejectsTruncatedHeaderAndBody() {
        #expect(throws: XtfFile.Error.truncated) { try XtfFile.decode([0, 1, 2]) }
        // Header says 4×4 (32 pixels) but body has only two.
        let short = makeXtf(width: 4, height: 4, format: 1, pixels: [0, 0])
        #expect(throws: XtfFile.Error.truncated) { try XtfFile.decode(short) }
    }

    @Test func rejectsInvalidDimensions() {
        #expect(throws: XtfFile.Error.invalidDimensions(width: 0, height: 0)) {
            try XtfFile.decode(makeXtf(width: 0, height: 0, format: 1, pixels: []))
        }
    }
}
