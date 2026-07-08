import Testing
@testable import GunBoundFile

@Suite
struct FntFileTests {

    /// Builds a synthetic ASCII font block: `128` glyphs × `12` bytes, all
    /// zero except the glyphs `configure` sets.
    private func makeFont(_ configure: (inout [UInt8]) -> Void) -> [UInt8] {
        var data = [UInt8](repeating: 0, count: FntFile.asciiGlyphCount * 12)
        configure(&data)
        return data
    }

    @Test func decodesOneFramePerAsciiCode() {
        let glyphs = FntFile.readASCIIGlyphs(makeFont { _ in })
        #expect(glyphs.count == FntFile.asciiGlyphCount)
    }

    @Test func trimsGlyphToUsedWidth() {
        // Glyph 'A' (65): a vertical line in the leftmost column on every row.
        let glyphs = FntFile.readASCIIGlyphs(makeFont { data in
            for row in 0..<12 { data[65 * 12 + row] = 0x80 }
        })
        let a = glyphs[65]
        #expect(a.width == 1)  // only the leftmost column is used
        #expect(a.height == 12)
        #expect(a.pixels.count == 12)
        #expect(a.pixels.allSatisfy { $0.alpha == 255 && $0.red == 255 })
    }

    @Test func usedWidthIsRightmostSetColumn() {
        // Glyph 'B' (66): five leftmost bits set (0b11111000) on one row.
        let glyphs = FntFile.readASCIIGlyphs(makeFont { data in
            data[66 * 12] = 0b1111_1000
        })
        #expect(glyphs[66].width == 5)
    }

    @Test func blankGlyphsBecomeEmptyFixedWidthFrames() {
        let glyphs = FntFile.readASCIIGlyphs(makeFont { _ in })
        // Space (0x20) has no set pixels → a fixed-width transparent frame.
        let space = glyphs[0x20]
        #expect(space.width == FntFile.blankGlyphWidth)
        #expect(space.pixels.allSatisfy { $0.alpha == 0 })
    }

    @Test func toleratesTruncatedData() {
        // Fewer bytes than a full ASCII block — missing glyphs come back blank
        // rather than crashing.
        let glyphs = FntFile.readASCIIGlyphs([UInt8](repeating: 0, count: 100))
        #expect(glyphs.count == FntFile.asciiGlyphCount)
        #expect(glyphs.last?.width == FntFile.blankGlyphWidth)
    }
}
