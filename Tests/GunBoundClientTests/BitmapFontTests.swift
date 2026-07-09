import Foundation
import Testing
@testable import GunBound
@testable import GunBoundClient

/// A `ClientTexture` that just remembers which glyph frame it stands for.
@MainActor
final class StubTexture: ClientTexture {
    let frame: Int
    init(frame: Int) { self.frame = frame }
}

/// A `ClientRenderer` that hands back stub textures (one per requested frame),
/// reports a fixed glyph size, and records every `draw` — no real graphics, so
/// the font's layout math can be asserted directly.
@MainActor
final class RecordingRenderer: ClientRenderer {
    /// Every mapped glyph is this size, keeping the advance math easy to check.
    static let glyphSize: (width: Float, height: Float) = (5, 9)

    private(set) var drawCalls: [(frame: Int, rect: Rect)] = []

    func texture(named name: String, frame frameIndex: Int, assets: AssetLibrary) -> ClientTexture? {
        StubTexture(frame: frameIndex)
    }

    func size(of texture: ClientTexture?) -> (width: Float, height: Float) {
        texture is StubTexture ? Self.glyphSize : (0, 0)
    }

    func clear() {}

    func draw(_ texture: ClientTexture, in rect: Rect, tint: (r: UInt8, g: UInt8, b: UInt8)?, blend: ClientBlendMode) {
        guard let texture = texture as? StubTexture else { return }
        drawCalls.append((texture.frame, rect))
    }

    func present() {}
}

@Suite @MainActor
struct BitmapFontTests {

    private func makeLoadedFont() -> (LoadedFont, RecordingRenderer) {
        let renderer = RecordingRenderer()
        let assets = AssetLibrary(directory: URL(fileURLWithPath: "/nonexistent"))
        return (LoadedFont(.numberFont, renderer: renderer, assets: assets), renderer)
    }

    @Test func numberFontMapsDigitsToFrames() {
        let font = BitmapFont.numberFont
        #expect(font.sheetName == "numfont.img")
        for digit in 0...9 {
            #expect(font.glyphs[Character("\(digit)")] == digit)
        }
        #expect(font.glyphs["/"] == 11)
        #expect(font.glyphs["A"] == nil)
    }

    @Test func widthSumsGlyphAdvances() {
        let (font, _) = makeLoadedFont()
        let glyph = RecordingRenderer.glyphSize.width
        let tracking = BitmapFont.numberFont.tracking
        // "42" = two glyphs, each width + tracking.
        #expect(font.width(of: "42") == (glyph + tracking) * 2)
    }

    @Test func widthUsesSpaceAdvanceForUnmappedCharacters() {
        let (font, _) = makeLoadedFont()
        let glyph = RecordingRenderer.glyphSize.width
        let tracking = BitmapFont.numberFont.tracking
        let space = BitmapFont.numberFont.spaceWidth
        // 'A' is unmapped, so it advances by spaceWidth without drawing.
        #expect(font.width(of: "4A2") == (glyph + tracking) + space + (glyph + tracking))
    }

    @Test func drawStampsEachGlyphLeftToRight() {
        let (font, renderer) = makeLoadedFont()
        font.draw("42", x: 10, y: 20, shadow: false, using: renderer)

        #expect(renderer.drawCalls.count == 2)
        // First glyph '4' → frame 4 at the origin.
        #expect(renderer.drawCalls[0].frame == 4)
        #expect(renderer.drawCalls[0].rect == Rect(x: 10, y: 20, width: 5, height: 9))
        // Second glyph '2' → frame 2, advanced by width + tracking.
        #expect(renderer.drawCalls[1].frame == 2)
        #expect(renderer.drawCalls[1].rect == Rect(x: 16, y: 20, width: 5, height: 9))
    }

    @Test func drawSkipsUnmappedCharactersButStillAdvances() {
        let (font, renderer) = makeLoadedFont()
        font.draw("4 2", x: 0, y: 0, shadow: false, using: renderer)

        // Only the two digits draw; the space draws nothing.
        #expect(renderer.drawCalls.map(\.frame) == [4, 2])
        // '2' sits after '4' (width + tracking) plus the space advance.
        let expectedX = (5 + BitmapFont.numberFont.tracking) + BitmapFont.numberFont.spaceWidth
        #expect(renderer.drawCalls[1].rect.x == expectedX)
    }

    /// The default shadow pass stamps the text once in black at (+1, +1)
    /// before the main pass — the original's double-draw legibility idiom.
    @Test func drawShadowDoubleDrawsOffsetInBlack() {
        let (font, renderer) = makeLoadedFont()
        font.draw("4", x: 10, y: 20, using: renderer)

        #expect(renderer.drawCalls.count == 2)
        #expect(renderer.drawCalls[0].rect == Rect(x: 11, y: 21, width: 5, height: 9))
        #expect(renderer.drawCalls[1].rect == Rect(x: 10, y: 20, width: 5, height: 9))
    }

    @Test func lineHeightIsTallestGlyph() {
        let (font, _) = makeLoadedFont()
        #expect(font.lineHeight == RecordingRenderer.glyphSize.height)
    }
}
