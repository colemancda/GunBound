import Foundation
import Testing
@testable import GunBoundFile

@Suite struct AvatarCompositeTests {

    private func frame(
        width: Int32, height: Int32,
        xCenter: Int32, yCenter: Int32,
        pixel: ImgFile.Pixel
    ) -> ImgFile.Frame {
        ImgFile.Frame(
            transparencyType: .alpha,
            width: width,
            height: height,
            xCenter: xCenter,
            yCenter: yCenter,
            pixels: .init(repeating: pixel, count: Int(width * height))
        )
    }

    /// Two hotspot-offset layers produce a frame spanning their union, with
    /// the union's top-left as the composite's own hotspot.
    @Test func alignsLayersByHotspot() throws {
        let body = frame(width: 4, height: 4, xCenter: -2, yCenter: 0, pixel: .init(red: 255, green: 0, blue: 0, alpha: 255))
        let head = frame(width: 2, height: 2, xCenter: 0, yCenter: -2, pixel: .init(red: 0, green: 255, blue: 0, alpha: 255))

        let composite = try #require(AvatarComposite.compose([body, head]))
        #expect(composite.width == 4)   // x: -2..<2
        #expect(composite.height == 6)  // y: -2..<4
        #expect(composite.xCenter == -2)
        #expect(composite.yCenter == -2)

        // The head's opaque green sits at union coordinates (2,0); the body
        // starts at (0,2); the top-left corner stays transparent.
        let width = Int(composite.width)
        #expect(composite.pixels[0 * width + 2].green == 255)
        #expect(composite.pixels[2 * width + 0].red == 255)
        #expect(composite.pixels[0].alpha == 0)
    }

    /// Later layers draw over earlier ones where they overlap; transparent
    /// source pixels leave the lower layer visible.
    @Test func laterLayersDrawOnTop() throws {
        let under = frame(width: 2, height: 2, xCenter: 0, yCenter: 0, pixel: .init(red: 255, green: 0, blue: 0, alpha: 255))
        var overPixels = [ImgFile.Pixel](repeating: .transparent, count: 4)
        overPixels[0] = .init(red: 0, green: 0, blue: 255, alpha: 255)
        let over = ImgFile.Frame(
            transparencyType: .alpha, width: 2, height: 2,
            xCenter: 0, yCenter: 0, pixels: overPixels
        )

        let composite = try #require(AvatarComposite.compose([under, over]))
        #expect(composite.pixels[0].blue == 255)  // covered
        #expect(composite.pixels[1].red == 255)   // transparent over → under shows
    }

    /// A half-transparent source blends source-over onto the layer below.
    @Test func blendsPartialAlpha() throws {
        let under = frame(width: 1, height: 1, xCenter: 0, yCenter: 0, pixel: .init(red: 0, green: 0, blue: 0, alpha: 255))
        let over = frame(width: 1, height: 1, xCenter: 0, yCenter: 0, pixel: .init(red: 255, green: 255, blue: 255, alpha: 128))

        let composite = try #require(AvatarComposite.compose([under, over]))
        let out = composite.pixels[0]
        #expect(out.alpha == 255)
        #expect(out.red > 120 && out.red < 136)  // ≈ half-white over black
    }

    /// Empty input (or nothing drawable) composes to nothing.
    @Test func rejectsEmptyInput() {
        #expect(AvatarComposite.compose([]) == nil)
        let degenerate = frame(width: 0, height: 0, xCenter: 0, yCenter: 0, pixel: .transparent)
        #expect(AvatarComposite.compose([degenerate]) == nil)
    }

    /// The real default male outfit (`mb00000` + `mh00000`) composes to the
    /// expected union geometry (skipped when the archive isn't on disk).
    @Test func composesTheRealStandardOutfit() throws {
        let url = URL(fileURLWithPath: NSString(string: "~/Developer/GunBound-Decomp/orig/graphics.xfs").expandingTildeInPath)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        let archive = try [UInt8](Data(contentsOf: url))
        let entries = try XFSArchive.readEntries(archive)
        func firstFrame(_ name: String) throws -> ImgFile.Frame {
            let entry = try #require(entries.first { $0.name == name })
            return try #require(try ImgFile.readFrames(XFSArchive.readEntryData(archive, entry: entry)).first)
        }

        let body = try firstFrame("mb00000.img")   // 25×26 at (-9,-6)
        let head = try firstFrame("mh00000.img")   // 24×23 at (0,-24)
        let composite = try #require(AvatarComposite.compose([body, head]))
        #expect(composite.width == 33)   // x: -9..<24
        #expect(composite.height == 44)  // y: -24..<20
        #expect(composite.xCenter == -9)
        #expect(composite.yCenter == -24)
        // Something opaque landed in the head band and the body band.
        let width = Int(composite.width)
        #expect(composite.pixels[10 * width..<11 * width].contains { $0.alpha == 255 })
        #expect(composite.pixels[30 * width..<31 * width].contains { $0.alpha == 255 })
    }
}
