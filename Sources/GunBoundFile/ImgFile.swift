/// GunBound's `.img` sprite/texture format (individual entries inside
/// `.xfs` archives, e.g. `tank1.img`, `bullet1n.img`).
///
/// **Note:** Reconstructed from static analysis of the original client. An
/// earlier pass had concluded pixel data was always ARGB4444 — **this was
/// wrong for some files**: the pixel format is actually selected **per
/// frame** by the frame's own `transparencyType` field (confirmed
/// empirically: `avataimsi.img`'s real frame 0 has `transparencyType == 0`,
/// i.e. flat RGB565, not ARGB4444 — decoding it as ARGB4444 had silently
/// produced a plausible-looking but wrong purple tint instead of the
/// correct light-gray background).
public enum ImgFile {

    /// A frame's pixel storage/format selector.
    public enum TransparencyType: Int32, Equatable, Sendable {
        /// Flat, row-major RGB565 pixels, always fully opaque.
        case none = 0
        /// Sparse per-scanline run list of RGB565 pixels; pixels not
        /// covered by any run are fully transparent.
        case simple = 1
        /// Flat, row-major ARGB4444 pixels (alpha channel included).
        case alpha = 2
    }

    /// A decoded pixel, 8 bits per channel.
    public struct Pixel: Equatable, Sendable {
        public let red: UInt8
        public let green: UInt8
        public let blue: UInt8
        public let alpha: UInt8

        /// Decodes a raw 16-bit RGB565 value (5/6/5 bits), always opaque.
        public init(rgb565 raw: UInt16) {
            self.red = UInt8((Int(raw >> 11) & 0x1f) * 0xff / 0x1f)
            self.green = UInt8((Int(raw >> 5) & 0x3f) * 0xff / 0x3f)
            self.blue = UInt8((Int(raw) & 0x1f) * 0xff / 0x1f)
            self.alpha = 0xff
        }

        /// Decodes a raw 16-bit ARGB4444 value (4 bits each for
        /// alpha/red/green/blue, most to least significant nibble).
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

    /// One decoded `.img` frame.
    public struct Frame: Equatable, Sendable {

        public let transparencyType: TransparencyType

        public let width: Int32
        public let height: Int32

        /// Likely hotspot/origin offset (not confirmed against rendering code).
        public let xCenter: Int32
        public let yCenter: Int32

        /// `1` when this frame has a second, currently-unused trailing
        /// data blob (see the type-level note on `readFrames`'s decoding
        /// of it); `0` otherwise.
        public let flippedX: Int32

        /// Companion to `flippedX`; the second blob is only present when
        /// `flippedX == 1 && flippedY == 0`.
        public let flippedY: Int32

        /// Purpose unconfirmed.
        public let unknown1: Int32

        /// Purpose unconfirmed.
        public let unknown2: Int32

        /// Decoded pixels, row-major, `width * height` entries.
        public let pixels: [Pixel]
    }

    /// Parses every frame in a decompressed `.img` entry's bytes.
    ///
    /// Layout: 4 unidentified bytes, then a `uint32` frame count, then that
    /// many frame records back-to-back. Each frame record is 10 `int32`
    /// fields (`transparencyType`, `width`, `height`, `xCenter`, `yCenter`,
    /// `flippedX`, `flippedY`, `unknown1`, `unknown2`, `length`) followed by
    /// `length` bytes of primary pixel data — and, **only when
    /// `flippedX == 1 && flippedY == 0`**, a second `uint32` length field
    /// and that many bytes of a second data blob. That second blob is
    /// present in the file but not used by rendering (the reference
    /// decoder's own flip-handling for this case is a no-op transform), so
    /// it's read here only to correctly advance to the next frame, not
    /// exposed or decoded.
    ///
    /// **Known limitation**: this record shape is fully confirmed and
    /// decodes correctly for the vast majority of real `.img` files (icons,
    /// buttons, projectiles, multi-frame UI elements), but large
    /// multi-rotation-frame animation sheets (e.g. a 455-frame vehicle
    /// sheet) desync after the first couple of frames — the true cause
    /// isn't identified yet. Rather than throwing on that desync, this
    /// function stops and returns every frame successfully parsed before
    /// it (detected either by a `ParsingError` — ran out of data — or
    /// implausible width/height once desynced).
    public static func readFrames(_ decodedData: [UInt8]) throws -> [Frame] {
        try decodedData.withParserSpan { input in
            try readFrames(parsing: &input)
        }
    }

    /// Maximum plausible frame dimension, used to detect desync/corruption
    /// and stop early rather than crash or return garbage. See the note on
    /// `readFrames` about very large multi-frame sheets.
    private static let maxPlausibleDimension: Int32 = 4096

    public static func readFrames(parsing input: inout ParserSpan) throws -> [Frame] {
        _ = try [UInt8](parsing: &input, byteCount: 4) // unidentified
        let frameCount = try Int32(parsingLittleEndian: &input)
        var frames = [Frame]()
        frames.reserveCapacity(Int(max(frameCount, 0)))
        for _ in 0..<max(frameCount, 0) {
            let frame: Frame?
            do {
                frame = try readFrame(parsing: &input)
            } catch {
                // Ran out of data or hit an implausible byte count while
                // reading — stop and return whatever parsed successfully.
                break
            }
            guard let frame else { break }
            frames.append(frame)
        }
        return frames
    }

    private static func readFrame(parsing input: inout ParserSpan) throws -> Frame? {
        let transparencyTypeRaw = try Int32(parsingLittleEndian: &input)
        let transparencyType = TransparencyType(rawValue: transparencyTypeRaw & 0xff) ?? .none
        let width = try Int32(parsingLittleEndian: &input)
        let height = try Int32(parsingLittleEndian: &input)
        let xCenter = try Int32(parsingLittleEndian: &input)
        let yCenter = try Int32(parsingLittleEndian: &input)
        let flippedXRaw = try Int32(parsingLittleEndian: &input)
        let flippedYRaw = try Int32(parsingLittleEndian: &input)
        let flippedX = flippedXRaw & 0xff
        let flippedY = flippedYRaw & 0xff
        let unknown1 = try Int32(parsingLittleEndian: &input)
        let unknown2 = try Int32(parsingLittleEndian: &input)
        let length = try Int32(parsingLittleEndian: &input)

        guard width > 0, width <= maxPlausibleDimension, height > 0, height <= maxPlausibleDimension, length >= 0 else {
            return nil
        }

        let primaryData = try [UInt8](parsing: &input, byteCount: Int(length))

        if flippedX == 1, flippedY == 0 {
            let secondLength = try Int32(parsingLittleEndian: &input)
            guard secondLength >= 0 else { return nil }
            _ = try [UInt8](parsing: &input, byteCount: Int(secondLength))
        }

        let pixels = decodePixels(
            primaryData,
            width: Int(width),
            height: Int(height),
            transparencyType: transparencyType
        )

        return Frame(
            transparencyType: transparencyType,
            width: width,
            height: height,
            xCenter: xCenter,
            yCenter: yCenter,
            flippedX: flippedX,
            flippedY: flippedY,
            unknown1: unknown1,
            unknown2: unknown2,
            pixels: pixels
        )
    }

    static func decodePixels(_ data: [UInt8], width: Int, height: Int, transparencyType: TransparencyType) -> [Pixel] {
        switch transparencyType {
        case .none:
            return decodeFlatRGB565(data, count: width * height)
        case .alpha:
            return decodeFlatARGB4444(data, count: width * height)
        case .simple:
            return decodeSparseRGB565(data, width: width, height: height)
        }
    }

    private static func decodeFlatRGB565(_ data: [UInt8], count: Int) -> [Pixel] {
        var pixels = [Pixel]()
        pixels.reserveCapacity(count)
        for i in 0..<count {
            let offset = i * 2
            guard offset + 2 <= data.count else { break }
            let raw = UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
            pixels.append(Pixel(rgb565: raw))
        }
        return pixels
    }

    private static func decodeFlatARGB4444(_ data: [UInt8], count: Int) -> [Pixel] {
        var pixels = [Pixel]()
        pixels.reserveCapacity(count)
        for i in 0..<count {
            let offset = i * 2
            guard offset + 2 <= data.count else { break }
            let raw = UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
            pixels.append(Pixel(argb4444: raw))
        }
        return pixels
    }

    /// Sparse per-scanline format. Per row: a `[totalBytes:i16][allLine:i16]` pair (in 16-bit-word
    /// units), where `totalBytes == 2 && allLine == 0` means the whole row
    /// is transparent. Otherwise, a sequence of `[alphaCount:i16]
    /// [colorCount:i16]` pairs: the *first* pair gives a literal transparent
    /// run length (`alphaCount`) followed by an opaque run of `colorCount`
    /// RGB565 pixels; every *subsequent* pair's `alphaCount` is instead a
    /// running cumulative pixel-position marker (the format
    /// computes the actual transparent-run length as `alphaCount - (previous
    /// alphaCount + previous colorCount)`), again followed by `colorCount`
    /// opaque pixels — continuing until `totalBytes` 16-bit words have been
    /// consumed for the row. Any width remaining after that is padded
    /// transparent.
    private static func decodeSparseRGB565(_ data: [UInt8], width: Int, height: Int) -> [Pixel] {
        var pixels = [Pixel](repeating: .transparent, count: width * height)
        var pos = 0

        func readInt16(at offset: Int) -> Int? {
            guard offset + 2 <= data.count else { return nil }
            return Int(Int16(bitPattern: UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)))
        }
        func readUInt16(at offset: Int) -> UInt16? {
            guard offset + 2 <= data.count else { return nil }
            return UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
        }

        for y in 0..<height {
            guard let totalBytes = readInt16(at: pos), let allLine = readInt16(at: pos + 2) else { break }
            pos += 4
            var countBytes = 2
            var sum = 0
            let rowStart = y * width

            func writeTransparent() {
                if sum < width { pixels[rowStart + sum] = .transparent }
                sum += 1
            }
            func writeOpaque() {
                guard let raw = readUInt16(at: pos) else { return }
                pos += 2
                countBytes += 1
                if sum < width { pixels[rowStart + sum] = Pixel(rgb565: raw) }
                sum += 1
            }

            if totalBytes == 2, allLine == 0 {
                for _ in 0..<width { writeTransparent() }
                continue
            }

            guard var alphaCount = readInt16(at: pos), var colorCount = readInt16(at: pos + 2) else { continue }
            pos += 4
            countBytes += 2

            for _ in 0..<max(alphaCount, 0) { writeTransparent() }
            for _ in 0..<max(colorCount, 0) { writeOpaque() }

            while countBytes < totalBytes {
                let sumaColor = alphaCount + colorCount
                guard let newAlphaCount = readInt16(at: pos), let newColorCount = readInt16(at: pos + 2) else { break }
                pos += 4
                countBytes += 2
                alphaCount = newAlphaCount - sumaColor
                colorCount = newColorCount

                for _ in 0..<max(alphaCount, 0) { writeTransparent() }
                for _ in 0..<max(colorCount, 0) { writeOpaque() }
            }

            if sum < width {
                for _ in sum..<width { writeTransparent() }
            }
        }
        return pixels
    }
}
