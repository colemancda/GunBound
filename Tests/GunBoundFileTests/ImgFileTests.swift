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

    /// Validates the confirmed `.img` frame-0 header layout and ARGB4444
    /// pixel decoding against a real sprite, cross-checked pixel-for-pixel
    /// against the reverse-engineering team's own independent Python
    /// decoder (`tools/lzhuf/decode_img.py` in the companion decomp repo).
    @Test
    func readFrame0() throws {
        let decoded = try loadDecodedFixture()
        let frame = try ImgFile.readFrame0(decoded)

        #expect(frame.width == 28)
        #expect(frame.height == 25)
        #expect(frame.frameCount == 3)
        #expect(frame.hotspotX == 0)
        #expect(frame.hotspotY == 0)
        #expect(frame.pixelByteCount == frame.width * frame.height * 2)
        #expect(frame.pixels.count == Int(frame.width * frame.height))

        // First 5 pixels, cross-checked against the Python reference decoder.
        for pixel in frame.pixels.prefix(5) {
            #expect(pixel == 0xe73c)
        }
    }

    @Test
    func argb4444Conversion() {
        // Cross-checked against the Python reference decoder's
        // argb4444_to_rgba8888 for the same raw pixel value (0xe73c).
        let (red, green, blue, alpha) = ImgFile.rgba8888(fromARGB4444: 0xe73c)
        #expect(red == 119)
        #expect(green == 51)
        #expect(blue == 204)
        #expect(alpha == 238)
    }
}
