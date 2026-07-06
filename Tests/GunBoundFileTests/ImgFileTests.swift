import Testing
import Foundation
@testable import GunBoundFile

@Suite
struct ImgFileTests {

    /// `avataimsi.img.decoded` is the real, already-LZHUF-decompressed
    /// bytes of the `avataimsi.img` entry from a real `graphics.xfs`
    /// (extracted once via `XFSArchive`/`LZHUF` and saved here, rather than
    /// bundling the full 206 MB archive as a test resource).
    private func loadDecodedFixture() throws -> [UInt8] {
        let url = Bundle.module.url(forResource: "avataimsi.img", withExtension: "decoded", subdirectory: "Resources")!
        return try [UInt8](Data(contentsOf: url))
    }

    /// Validates the confirmed `.img` frame-0 header layout and flat-storage
    /// ARGB4444 pixel decoding against a real sprite, cross-checked
    /// pixel-for-pixel against the reverse-engineering team's own
    /// independent Python decoder (`tools/lzhuf/decode_img.py` in the
    /// companion decomp repo).
    @Test
    func readFrame0Flat() throws {
        let decoded = try loadDecodedFixture()
        let frame = try ImgFile.readFrame0(decoded)

        #expect(frame.width == 28)
        #expect(frame.height == 25)
        #expect(frame.frameCount == 3)
        #expect(frame.hotspotX == 0)
        #expect(frame.hotspotY == 0)
        #expect(frame.pixelByteCount == frame.width * frame.height * 2)
        #expect(frame.pixels.count == Int(frame.width * frame.height))

        // First 5 pixels, cross-checked against the Python reference decoder
        // (raw value 0xe73c -> RGBA (119, 51, 204, 238)).
        for pixel in frame.pixels.prefix(5) {
            #expect(pixel == ImgFile.Pixel(argb4444: 0xe73c))
        }
    }

    @Test
    func argb4444Conversion() {
        // Cross-checked against the Python reference decoder's
        // _nibble_pixel for the same raw pixel value.
        let pixel = ImgFile.Pixel(argb4444: 0xe73c)
        #expect(pixel.red == 119)
        #expect(pixel.green == 51)
        #expect(pixel.blue == 204)
        #expect(pixel.alpha == 238)
    }

    /// No real sample tested so far exercises sparse (run-list) storage —
    /// the confirmed algorithm (see `ImgFile`'s doc comment) is validated
    /// here against a small hand-built buffer instead: a 4x3 image where
    /// row 0 has one 2-pixel run at x=1, row 1 has no data (stride
    /// terminates early), and row 2 is intentionally unreachable.
    @Test
    func decodeSparsePixels() {
        var pixelData = [UInt8]()
        // Row 0: stride=2 (u16 units to next row), runCount=1.
        pixelData += [2, 0, 1, 0]
        // One run: xOffset=1, length=2, then 2 ARGB4444 pixels.
        pixelData += [1, 0, 2, 0]
        pixelData += [0x3c, 0xe7] // pixel 0: raw 0xe73c (LE)
        pixelData += [0xff, 0xff] // pixel 1: raw 0xffff (opaque white)
        // Row 1: stride=0 terminates the row list early.
        pixelData += [0, 0, 0, 0]

        let pixels = ImgFile.decodePixels(pixelData, width: 4, height: 3, pixelByteCount: pixelData.count)
        #expect(pixels.count == 12)

        // Row 0: x=0 transparent, x=1/x=2 from the run, x=3 transparent.
        #expect(pixels[0] == ImgFile.Pixel.transparent)
        #expect(pixels[1] == ImgFile.Pixel(argb4444: 0xe73c))
        #expect(pixels[2] == ImgFile.Pixel(argb4444: 0xffff))
        #expect(pixels[3] == ImgFile.Pixel.transparent)

        // Rows 1 and 2 are fully transparent (stride==0 terminator).
        for pixel in pixels[4...] {
            #expect(pixel == ImgFile.Pixel.transparent)
        }
    }
}
