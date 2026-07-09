/// The `.epa` animation table paired with each mobile's sprite sheet
/// (`tank1.img` + `tank1.epa` in `graphics.xfs`, and likewise for effects).
/// It names the sheet's frame runs — which of the 455 frames play for each
/// mobile state. Format confirmed empirically against the real archive
/// (every byte of `tank1.epa` parses, and the runs match the sheet
/// visually — `dead` lands on the white-flag frames):
///
/// ```
/// [u32 animationCount LE]
/// animationCount × {
///     [u32 nameLength LE][nameLength ASCII bytes]
///     [u8 flag]                       // 1 on hold-last/one-shot style runs
///     [u32 frameCount LE]
///     frameCount × [u32 frameIndex LE]
///     frameCount × [u32 duration LE]  // ticks per frame
/// }
/// ```
///
/// The real tables name the runs `normal`, `move`, `fire1`, `fire2`,
/// `shock`, `dead`, `drop`, `item`, `ice`, `emotion1/2`, the `b`-prefixed
/// backward-facing fires, the `t`-prefixed trap poses, and — the decomp's
/// `"normal"`/`"wnormal"` strings in the movement action — the `w`-prefixed
/// **wounded** variants used once the mobile is at half HP.
public struct EpaFile: Equatable, Sendable {

    public enum Error: Swift.Error, Equatable {
        case truncated
        case invalidCount(Int)
    }

    public struct Animation: Equatable, Sendable {
        public let name: String
        public let flag: UInt8
        /// Frame indices into the paired `.img` sheet, in play order.
        public let frames: [Int]
        /// Ticks each frame holds (parallel to `frames`).
        public let durations: [Int]

        public init(name: String, flag: UInt8, frames: [Int], durations: [Int]) {
            self.name = name
            self.flag = flag
            self.frames = frames
            self.durations = durations
        }
    }

    public let animations: [Animation]

    public init(animations: [Animation]) {
        self.animations = animations
    }

    /// The named frame run, `nil` when the table doesn't define it.
    public func animation(named name: String) -> Animation? {
        animations.first { $0.name == name }
    }

    /// Parses a decompressed `.epa` payload.
    public static func read(_ data: [UInt8]) throws -> EpaFile {
        var offset = 0
        func readU32() throws -> Int {
            guard offset + 4 <= data.count else { throw Error.truncated }
            defer { offset += 4 }
            return Int(data[offset])
                | (Int(data[offset + 1]) << 8)
                | (Int(data[offset + 2]) << 16)
                | (Int(data[offset + 3]) << 24)
        }

        let count = try readU32()
        guard count > 0, count <= 512 else { throw Error.invalidCount(count) }
        var animations: [Animation] = []
        animations.reserveCapacity(count)
        for _ in 0..<count {
            let nameLength = try readU32()
            guard nameLength > 0, nameLength <= 64, offset + nameLength + 1 <= data.count else {
                throw Error.truncated
            }
            let name = String(decoding: data[offset..<(offset + nameLength)], as: UTF8.self)
            offset += nameLength
            let flag = data[offset]
            offset += 1
            let frameCount = try readU32()
            guard frameCount > 0, frameCount <= 4096 else { throw Error.truncated }
            var frames: [Int] = []
            frames.reserveCapacity(frameCount)
            for _ in 0..<frameCount { frames.append(try readU32()) }
            var durations: [Int] = []
            durations.reserveCapacity(frameCount)
            for _ in 0..<frameCount { durations.append(try readU32()) }
            animations.append(Animation(name: name, flag: flag, frames: frames, durations: durations))
        }
        return EpaFile(animations: animations)
    }
}
