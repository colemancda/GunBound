import GunBound

/// A bitmap font backed by a glyph sprite sheet — each character maps to one
/// frame of an `.img`, drawn by stamping that frame (the reusable-asset
/// equivalent of the decompiled client's `BlitRLESprite`, which stamps glyphs
/// from runtime-loaded tables; here the glyphs come straight from the shipped
/// `.img` font sheets instead).
///
/// `numfont.img` is a **number font**: frames 0–9 are the gold digits `0`–`9`,
/// followed by a few punctuation glyphs. It covers the Game Room List's room
/// numbers and `players/max` counts (the decomp's `%d` / `%3d/%3d` text).
/// General text (room names, chat) uses the separate `font.fnt` resource,
/// which isn't decoded yet.
public struct BitmapFont: Sendable {
    /// The `.img` sprite sheet the glyph frames come from.
    public let sheetName: String
    /// Character → frame index within `sheetName`.
    public let glyphs: [Character: Int]
    /// Extra horizontal spacing added after each drawn glyph.
    public let tracking: Float
    /// Advance used for characters not in `glyphs` (e.g. spaces).
    public let spaceWidth: Float

    public init(sheetName: String, glyphs: [Character: Int], tracking: Float = 1, spaceWidth: Float = 4) {
        self.sheetName = sheetName
        self.glyphs = glyphs
        self.tracking = tracking
        self.spaceWidth = spaceWidth
    }

    /// The gold digit band of `numfont.img` (frames 0–9 = `0`–`9`) plus the
    /// `/` separator used in `players/max` counts (frame 11, the thin glyph
    /// right after the digits).
    public static let numberFont = BitmapFont(
        sheetName: "numfont.img",
        glyphs: ["0": 0, "1": 1, "2": 2, "3": 3, "4": 4, "5": 5, "6": 6, "7": 7, "8": 8, "9": 9, "/": 11]
    )

    /// The general Latin font from `font.fnt` — `AssetLibrary` decodes that
    /// file into one frame per ASCII code (frame index == character code), so
    /// every printable ASCII character maps to its own code. Covers room
    /// names, usernames, and chat (non-ASCII/Korean characters fall back to a
    /// space until the DBCS glyph block is decoded).
    public static let latinFont: BitmapFont = {
        var glyphs: [Character: Int] = [:]
        for code in 0x20...0x7E {
            glyphs[Character(UnicodeScalar(UInt8(code)))] = code
        }
        return BitmapFont(sheetName: "font.fnt", glyphs: glyphs, tracking: 1, spaceWidth: 4)
    }()
}

/// A `BitmapFont` with its glyph frames pre-loaded into backend textures for
/// a given renderer — built once (e.g. in a screen's `onEnter`) and reused
/// every frame, so no textures are rebuilt per draw.
@MainActor
public final class LoadedFont {
    private let font: BitmapFont
    private var glyphTextures: [Character: ClientTexture] = [:]
    private var glyphSizes: [Character: (width: Float, height: Float)] = [:]

    public init(_ font: BitmapFont, renderer: ClientRenderer, assets: AssetLibrary) {
        self.font = font
        for (character, frame) in font.glyphs {
            guard let texture = renderer.texture(named: font.sheetName, frame: frame, assets: assets) else { continue }
            glyphTextures[character] = texture
            glyphSizes[character] = renderer.size(of: texture)
        }
    }

    /// Total advance width of `text` when drawn — for right-aligning or
    /// centering.
    public func width(of text: String) -> Float {
        var width: Float = 0
        for character in text {
            if let size = glyphSizes[character] {
                width += size.width + font.tracking
            } else {
                width += font.spaceWidth
            }
        }
        return width
    }

    public var lineHeight: Float {
        glyphSizes.values.map(\.height).max() ?? 0
    }

    /// Draws `text` left-to-right starting at `(x, y)` (top-left). Characters
    /// with no glyph advance by `spaceWidth` without drawing.
    ///
    /// `tint` modulates the glyph color — `font.fnt` glyphs are stamped
    /// white, so tinting reproduces the original's flat text colors (e.g.
    /// the world list's pale-cyan `0xb77f` descriptions); `nil` draws the
    /// glyphs' own color.
    public func draw(_ text: String, x: Float, y: Float, tint: (r: UInt8, g: UInt8, b: UInt8)? = nil, using renderer: ClientRenderer) {
        var cursor = x
        for character in text {
            if let texture = glyphTextures[character], let size = glyphSizes[character] {
                renderer.draw(texture, in: Rect(x: cursor, y: y, width: size.width, height: size.height), tint: tint)
                cursor += size.width + font.tracking
            } else {
                cursor += font.spaceWidth
            }
        }
    }
}
