/// GunBound's `.img` sprite/texture format (individual entries inside
/// `.xfs` archives, e.g. `tank1.img`, `bullet1n.img`).
///
/// **Note:** Reconstructed from static analysis of the original client,
/// then verified by extracting and visually rendering three real sprites
/// from `graphics.xfs` and comparing against a real reference screenshot.
/// Only frame 0's layout is confirmed — multi-frame sheets (e.g.
/// `tank1.img`, which claims 455 frames) have more data following frame 0,
/// but the per-frame repeat structure beyond it hasn't been mapped.
///
/// `BlitRLESprite` (despite its name) turned out, on full decompilation,
/// to be a table-lookup-driven terrain/tile renderer unrelated to `.img`
/// sprites, not this format's decoder — `BlitSprite16bpp` is the relevant
/// one, and its real internal format is a sparse per-scanline run-length
/// scheme, not a flat pixel array. None of that sparse encoding was needed
/// for the three real samples tested (their byte counts matched
/// `width * height * 2` exactly, i.e. flat storage), so it isn't
/// implemented here — a larger sheet may exercise it.
public enum ImgFile {

    /// Byte offset where frame 0's pixel data begins.
    public static let frame0HeaderSize = 0x30

    /// One decoded `.img` entry's frame 0.
    public struct Frame0: Equatable, Sendable {

        /// `uint32` at offset `0x00`. `0` in every sample tested; purpose
        /// unconfirmed.
        public let flags: UInt32

        /// `uint32` at offset `0x04`: total frame count in the entry (only
        /// frame 0 is decoded by this type).
        public let frameCount: UInt32

        /// `uint32` at offset `0x08`. Varies per file; purpose unconfirmed.
        public let unknown0x08: UInt32

        /// Frame width in pixels, confirmed exactly (matches `pixelByteCount`).
        public let width: UInt32

        /// Frame height in pixels, confirmed exactly (matches `pixelByteCount`).
        public let height: UInt32

        /// Signed `int` at offset `0x14`, likely an X hotspot/origin offset
        /// (e.g. `-12` observed for a projectile sprite that rotates in
        /// flight) — not confirmed against rendering code.
        public let hotspotX: Int32

        /// Signed `int` at offset `0x18`, likely a Y hotspot/origin offset.
        public let hotspotY: Int32

        /// 16 unidentified bytes at offset `0x1c`.
        public let unidentified: [UInt8]

        /// Pixel data byte count for this frame at offset `0x2c`. Always
        /// exactly `width * height * 2` in every sample tested, confirming
        /// 16 bits per pixel.
        public let pixelByteCount: UInt32

        /// Raw pixel values, row-major, `width * height` entries, each a
        /// 16-bit **ARGB4444** value (4 bits each for alpha/red/green/blue).
        /// Confirmed by comparing rendered output against a real reference
        /// screenshot — two earlier guesses (RGB565, then RGB555) both
        /// produced visibly wrong colors before landing on this format; the
        /// giveaway was every common pixel's top hex digit reading `0xf`
        /// (a fully-opaque alpha nibble, not a maxed color channel). Use
        /// `ImgFile.rgba8888(fromARGB4444:)` to convert a pixel to
        /// 8-bit-per-channel components.
        public let pixels: [UInt16]
    }

    public static func readFrame0(_ decodedData: [UInt8]) throws -> Frame0 {
        try decodedData.withParserSpan { input in
            try readFrame0(parsing: &input)
        }
    }

    public static func readFrame0(parsing input: inout ParserSpan) throws -> Frame0 {
        let flags = try UInt32(parsingLittleEndian: &input)
        let frameCount = try UInt32(parsingLittleEndian: &input)
        let unknown0x08 = try UInt32(parsingLittleEndian: &input)
        let width = try UInt32(parsingLittleEndian: &input)
        let height = try UInt32(parsingLittleEndian: &input)
        let hotspotX = try Int32(parsingLittleEndian: &input)
        let hotspotY = try Int32(parsingLittleEndian: &input)
        let unidentified = try [UInt8](parsing: &input, byteCount: 16)
        let pixelByteCount = try UInt32(parsingLittleEndian: &input)

        let pixelCount = Int(width) * Int(height)
        var pixels = [UInt16]()
        pixels.reserveCapacity(pixelCount)
        for _ in 0..<pixelCount {
            pixels.append(try UInt16(parsingLittleEndian: &input))
        }

        return Frame0(
            flags: flags,
            frameCount: frameCount,
            unknown0x08: unknown0x08,
            width: width,
            height: height,
            hotspotX: hotspotX,
            hotspotY: hotspotY,
            unidentified: unidentified,
            pixelByteCount: pixelByteCount,
            pixels: pixels
        )
    }

    /// Converts a raw ARGB4444 pixel value (4 bits each for alpha, red,
    /// green, blue, in that nibble order from most to least significant)
    /// into 8-bit-per-channel RGBA components.
    public static func rgba8888(
        fromARGB4444 pixel: UInt16
    ) -> (red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8) {
        let alpha4 = UInt8((pixel >> 12) & 0xf)
        let red4 = UInt8((pixel >> 8) & 0xf)
        let green4 = UInt8((pixel >> 4) & 0xf)
        let blue4 = UInt8(pixel & 0xf)
        func scale(_ component: UInt8) -> UInt8 {
            component * 17 // 0...15 -> 0...255 (17 * 15 == 255)
        }
        return (scale(red4), scale(green4), scale(blue4), scale(alpha4))
    }
}
