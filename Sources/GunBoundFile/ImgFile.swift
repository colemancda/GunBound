/// GunBound's `.img` sprite/texture format (individual entries inside
/// `.xfs` archives, e.g. `tank1.img`, `bullet1n.img`).
///
/// **Note:** Reconstructed from static analysis of the original client,
/// then verified by extracting and visually rendering real sprites from
/// `graphics.xfs` and comparing against a real reference screenshot. Only
/// frame 0's layout is confirmed — multi-frame sheets (e.g. `tank1.img`,
/// which claims 455 frames) have more data following frame 0, but the
/// per-frame repeat structure beyond it hasn't been mapped.
///
/// `BlitRLESprite` (despite its name) turned out, on full decompilation, to
/// be a table-lookup-driven terrain/tile renderer unrelated to `.img`
/// sprites, not this format's decoder — `BlitSprite16bpp` is the relevant
/// one. Frame 0's pixel data is stored in one of two confirmed sub-formats,
/// auto-detected by comparing `pixelByteCount` against `width * height * 2`:
/// a flat row-major pixel array when they're equal, or (when they differ) a
/// sparse per-scanline run list — for each row, a `[stride][runCount]`
/// pair followed by `runCount` spans of `[xOffset][length][length pixels]`;
/// pixels not covered by any run are fully transparent, and a `stride` of
/// `0` terminates the row list early.
public enum ImgFile {

    /// Byte offset where frame 0's pixel data begins.
    public static let frame0HeaderSize = 0x30

    /// A decoded pixel, 8 bits per channel.
    public struct Pixel: Equatable, Sendable {
        public let red: UInt8
        public let green: UInt8
        public let blue: UInt8
        public let alpha: UInt8

        /// Decodes a raw 16-bit **ARGB4444** value (4 bits each for
        /// alpha/red/green/blue, most to least significant nibble).
        /// Confirmed by comparing rendered output against a real reference
        /// screenshot — two earlier guesses (RGB565, then RGB555) both
        /// produced visibly wrong colors before landing on this format;
        /// the giveaway was every common pixel's top hex digit reading
        /// `0xf` (a fully-opaque alpha nibble, not a maxed color channel).
        public init(argb4444 raw: UInt16) {
            func scale(_ nibble: UInt8) -> UInt8 { nibble * 17 } // 0...15 -> 0...255
            self.alpha = scale(UInt8((raw >> 12) & 0xf))
            self.red = scale(UInt8((raw >> 8) & 0xf))
            self.green = scale(UInt8((raw >> 4) & 0xf))
            self.blue = scale(UInt8(raw & 0xf))
        }

        static let transparent = Pixel(argb4444: 0)

        private init(red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8) {
            self.red = red
            self.green = green
            self.blue = blue
            self.alpha = alpha
        }
    }

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

        /// Total pixel-data byte count for this frame at offset `0x2c`.
        /// Equals `width * height * 2` for flat storage; smaller for
        /// sparse (run-list) storage.
        public let pixelByteCount: UInt32

        /// Decoded pixels, row-major, `width * height` entries.
        public let pixels: [Pixel]
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
        let pixelData = [UInt8](parsingRemainingBytes: &input)

        let pixels = decodePixels(
            pixelData,
            width: Int(width),
            height: Int(height),
            pixelByteCount: Int(pixelByteCount)
        )

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

    /// Decodes `pixelData` (the bytes immediately following the frame-0
    /// header) into a row-major pixel buffer, auto-detecting flat vs.
    /// sparse storage.
    static func decodePixels(_ pixelData: [UInt8], width: Int, height: Int, pixelByteCount: Int) -> [Pixel] {
        let flatByteCount = width * height * 2
        if pixelByteCount == flatByteCount, pixelData.count >= flatByteCount {
            return decodeFlatPixels(pixelData, count: width * height)
        }
        return decodeSparsePixels(pixelData, width: width, height: height, pixelByteCount: pixelByteCount)
    }

    private static func decodeFlatPixels(_ pixelData: [UInt8], count: Int) -> [Pixel] {
        var pixels = [Pixel]()
        pixels.reserveCapacity(count)
        for i in 0..<count {
            let offset = i * 2
            let raw = UInt16(pixelData[offset]) | (UInt16(pixelData[offset + 1]) << 8)
            pixels.append(Pixel(argb4444: raw))
        }
        return pixels
    }

    /// Sparse per-scanline run list: for each row, `[stride][runCount]`
    /// followed by `runCount` spans of `[xOffset][length][length pixels]`.
    /// `stride` is the distance (in `uint16` units, from the row's own
    /// start) to the next row; a `stride` of `0` terminates the row list
    /// early (the remaining rows are left fully transparent).
    private static func decodeSparsePixels(
        _ pixelData: [UInt8],
        width: Int,
        height: Int,
        pixelByteCount: Int
    ) -> [Pixel] {
        var pixels = [Pixel](repeating: .transparent, count: width * height)
        let end = min(pixelByteCount, pixelData.count)

        func readUInt16(at offset: Int) -> UInt16? {
            guard offset + 2 <= end else { return nil }
            return UInt16(pixelData[offset]) | (UInt16(pixelData[offset + 1]) << 8)
        }

        var pos = 0
        for y in 0..<height {
            guard let stride = readUInt16(at: pos), let runCount = readUInt16(at: pos + 2) else { break }
            var runPointer = pos + 4
            for _ in 0..<runCount {
                guard let xOffset = readUInt16(at: runPointer), let length = readUInt16(at: runPointer + 2) else {
                    break
                }
                runPointer += 4
                for k in 0..<Int(length) {
                    guard let raw = readUInt16(at: runPointer) else { break }
                    let x = Int(xOffset) + k
                    if x >= 0, x < width {
                        pixels[y * width + x] = Pixel(argb4444: raw)
                    }
                    runPointer += 2
                }
            }
            if stride == 0 {
                break // remaining rows stay fully transparent
            }
            pos += Int(stride) * 2
        }
        return pixels
    }
}
