import Testing
import Foundation
@testable import GunBoundFile

@Suite
struct ImgFileTests {

    private func loadDecodedFixture(_ name: String, _ ext: String) throws -> [UInt8] {
        let url = Bundle.module.url(forResource: name, withExtension: ext, subdirectory: "Resources")!
        return try [UInt8](Data(contentsOf: url))
    }

    /// `avataimsi.img.decoded` is the real, already-LZHUF-decompressed
    /// bytes of the `avataimsi.img` entry from a real `graphics.xfs`.
    /// Its frame 0 is `.none` (flat RGB565) — an earlier pass had wrongly
    /// assumed every `.img` frame was ARGB4444, which for this file
    /// produced a plausible-looking but wrong purple tint instead of the
    /// correct light-gray background (confirmed by cross-checking the
    /// frame's own `transparencyType` field, which this file sets to `0`).
    /// All 3 of its declared frames now decode (previously only frame 0
    /// was ever read at all).
    @Test
    func readFramesFlatRGB565() throws {
        let decoded = try loadDecodedFixture("avataimsi.img", "decoded")
        let frames = try ImgFile.readFrames(decoded)
        #expect(frames.count == 3)

        let first = try #require(frames.first)
        #expect(first.transparencyType == .none)
        #expect(first.width == 28)
        #expect(first.height == 25)
        #expect(first.pixels.count == 28 * 25)
        #expect(first.pixels.first == ImgFile.Pixel(rgb565: 0xe73c))
        #expect(first.pixels.first?.red == 230)
        #expect(first.pixels.first?.green == 230)
        #expect(first.pixels.first?.blue == 230)
        #expect(first.pixels.first?.alpha == 255)
    }

    @Test
    func rgb565Conversion() {
        let pixel = ImgFile.Pixel(rgb565: 0xe73c)
        #expect(pixel.red == 230)
        #expect(pixel.green == 230)
        #expect(pixel.blue == 230)
        #expect(pixel.alpha == 255)
    }

    @Test
    func argb4444Conversion() {
        let pixel = ImgFile.Pixel(argb4444: 0xe73c)
        #expect(pixel.red == 119)
        #expect(pixel.green == 51)
        #expect(pixel.blue == 204)
        #expect(pixel.alpha == 238)
    }

    /// `b_ready_nextmap.img.decoded` is a real entry using the sparse
    /// (`.simple`) per-scanline run-list pixel format across all 4 of its
    /// declared frames — extracted from a real `graphics.xfs` and saved
    /// here.
    @Test
    func readFramesSparse() throws {
        let decoded = try loadDecodedFixture("b_ready_nextmap.img", "decoded")
        let frames = try ImgFile.readFrames(decoded)
        #expect(frames.count == 4)
        for frame in frames {
            #expect(frame.transparencyType == .simple)
            #expect(frame.width == 19)
            #expect(frame.height == 19)
            #expect(frame.pixels.count == 19 * 19)
        }
    }

    /// Hand-built sparse-format buffer, verifying the exact run-list
    /// algorithm against a case simple enough to trace by hand: a 4x3
    /// image where row 0 has a
    /// 2-pixel opaque run at x=1, row 1 has no run data (falls through to
    /// the trailing-pad case), and row 2 is never reached because the
    /// buffer ends after row 1.
    @Test
    func decodeSparsePixelsHandBuilt() {
        var pixelData = [UInt8]()
        // Row 0: totalBytes=6 (2 header words + 2 alphaCount/colorCount words + 2 pixel words...
        // matches: header(2 words) + [alphaCount,colorCount](2 words) + 2 color pixels(2 words) = 6 words consumed after the header pair).
        pixelData += [6, 0, 1, 0] // totalBytes=6, allLine=1
        pixelData += [1, 0, 2, 0] // alphaCount=1, colorCount=2
        pixelData += [0x3c, 0xe7] // pixel: raw 0xe73c (LE)
        pixelData += [0xff, 0xff] // pixel: raw 0xffff (opaque white)
        // Row 1: totalBytes=2, allLine=0 -> entire row transparent.
        pixelData += [2, 0, 0, 0]

        let pixels = ImgFile.decodePixels(pixelData, width: 4, height: 3, transparencyType: .simple)
        #expect(pixels.count == 12)

        // Row 0: x=0 transparent (alphaCount=1), x=1/x=2 from the color run, x=3 padded transparent.
        #expect(pixels[0] == ImgFile.Pixel.transparent)
        #expect(pixels[1] == ImgFile.Pixel(rgb565: 0xe73c))
        #expect(pixels[2] == ImgFile.Pixel(rgb565: 0xffff))
        #expect(pixels[3] == ImgFile.Pixel.transparent)

        // Row 1: explicit all-transparent row.
        for pixel in pixels[4..<8] {
            #expect(pixel == ImgFile.Pixel.transparent)
        }

        // Row 2: no data left, stays at the default-transparent fill.
        for pixel in pixels[8...] {
            #expect(pixel == ImgFile.Pixel.transparent)
        }
    }

    /// A frame whose second blob is present (`flippedX == 1 && flippedY == 0`)
    /// but whose declared frame count only covers itself — validates the
    /// second-blob-skip doesn't consume bytes belonging to a subsequent
    /// frame that doesn't exist.
    @Test
    func readFramesSkipsSecondBlob() throws {
        var bytes = [UInt8]()
        bytes += [0, 0, 0, 0] // unidentified
        bytes += [1, 0, 0, 0] // frameCount = 1
        bytes += [2, 0, 0, 0] // transparencyType = 2 (alpha)
        bytes += [1, 0, 0, 0] // width = 1
        bytes += [1, 0, 0, 0] // height = 1
        bytes += [0, 0, 0, 0] // xCenter
        bytes += [0, 0, 0, 0] // yCenter
        bytes += [1, 0, 0, 0] // flippedX = 1
        bytes += [0, 0, 0, 0] // flippedY = 0 -> triggers second blob
        bytes += [0, 0, 0, 0] // unknown1
        bytes += [0, 0, 0, 0] // unknown2
        bytes += [2, 0, 0, 0] // length = 2 (one pixel, 1x1)
        bytes += [0xff, 0xff] // primary pixel data
        bytes += [4, 0, 0, 0] // second blob length = 4
        bytes += [0xaa, 0xbb, 0xcc, 0xdd] // second blob (unused/skipped)

        let frames = try ImgFile.readFrames(bytes)
        #expect(frames.count == 1)
        #expect(frames.first?.pixels.first == ImgFile.Pixel(argb4444: 0xffff))
    }
}
