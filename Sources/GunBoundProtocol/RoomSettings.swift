/// A room's settings dword as a typed bitmask — the packed radio-group
/// bitfield the host's room-option controls write (decomp `0x3101` handler,
/// `State09_ReadyRoom_OnCommand` cases `0xb`–`0x3e`; GunBound-Decomp
/// `docs/screens/09_ready_room.md` "Room-option controls").
///
/// The decompiled layout is five radio *groups*, each clearing its own bit
/// range and setting a chosen value (not independent flags, so this is a
/// field-accessor struct rather than an `OptionSet`):
///
/// | Bits  | Mask         | Group |
/// |-------|--------------|-------|
/// | 0–3   | `0x0000000f` | option group A (cases `0x28`–`0x2a`) |
/// | 8–11  | `0x00000f00` | option group B (cases `0x1e`–`0x21`) |
/// | 12–13 | `0x00003000` | option group C (cases `0x32`–`0x35`) |
/// | 14–15 | `0x0000c000` | option group D (cases `0x3c`–`0x3e`) |
/// | 18–23 | `0x00fc0000` | option group E (cases `0xb`–`0xd`) — the game mode |
///
/// The per-group option *labels* aren't decoded, so groups A–D are exposed as
/// raw sub-values. Group E is the game mode: the lobby's card renderer
/// (`RenderRoomCard`) picks the SOLO/SCORE/TAG/JEWEL label from **bits 18–19**
/// (`(settings >> 0x12) & 3`), and the full group matches `GameMode`'s
/// observed wire values in the dword's upper 16 bits (score `0x44` also sets
/// bit 22).
public struct RoomSettings: RawRepresentable, Equatable, Hashable, Sendable {

    public var rawValue: UInt32

    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }
}

public extension RoomSettings {

    /// The decomp-confirmed radio-group masks.
    enum Mask {
        public static let groupA: UInt32 = 0x0000_000f
        public static let groupB: UInt32 = 0x0000_0f00
        public static let groupC: UInt32 = 0x0000_3000
        public static let groupD: UInt32 = 0x0000_c000
        public static let groupE: UInt32 = 0x00fc_0000
        /// Bits 18–19 within group E — the mode-label selector the room-card
        /// renderer reads (frames 10–13: SOLO / SCORE / TAG / JEWEL).
        public static let modeLabel: UInt32 = 0x000c_0000
    }

    private func field(_ mask: UInt32) -> UInt32 {
        (rawValue & mask) >> mask.trailingZeroBitCount
    }

    private mutating func setField(_ mask: UInt32, to value: UInt32) {
        rawValue = (rawValue & ~mask) | ((value << mask.trailingZeroBitCount) & mask)
    }

    /// Option group A (bits 0–3). Semantics undecoded.
    var optionA: UInt32 {
        get { field(Mask.groupA) }
        set { setField(Mask.groupA, to: newValue) }
    }

    /// Option group B (bits 8–11). Semantics undecoded.
    var optionB: UInt32 {
        get { field(Mask.groupB) }
        set { setField(Mask.groupB, to: newValue) }
    }

    /// Option group C (bits 12–13). Semantics undecoded.
    var optionC: UInt32 {
        get { field(Mask.groupC) }
        set { setField(Mask.groupC, to: newValue) }
    }

    /// Option group D (bits 14–15). Semantics undecoded.
    var optionD: UInt32 {
        get { field(Mask.groupD) }
        set { setField(Mask.groupD, to: newValue) }
    }

    /// The mode-label index (bits 18–19): 0 SOLO, 1 SCORE, 2 TAG, 3 JEWEL —
    /// exactly what `RenderRoomCard` blits (`10 + index`). The value order is
    /// decomp-confirmed at the top end: `State11_InBattle_Render` draws the
    /// `JewelTexture` layer only when the (checksum-guarded) in-battle mode
    /// value equals **3**.
    var modeLabelIndex: Int {
        get { Int(field(Mask.modeLabel)) }
        set { setField(Mask.modeLabel, to: UInt32(newValue)) }
    }

    /// The full game mode from group E's upper-16-bits view, matching
    /// `GameMode`'s observed wire values. `nil` for unrecognized packings.
    var gameMode: GameMode? {
        get { GameMode(settings: rawValue) }
        set {
            rawValue &= ~Mask.groupE
            if let newValue {
                rawValue |= (UInt32(UInt16(bitPattern: newValue.rawValue)) << 16) & Mask.groupE
            }
        }
    }

    /// Composes settings for a new room with the given mode (Create Room).
    init(gameMode: GameMode) {
        self.rawValue = 0
        self.gameMode = gameMode
    }
}

// MARK: - ExpressibleByIntegerLiteral

extension RoomSettings: ExpressibleByIntegerLiteral {

    public init(integerLiteral value: UInt32) {
        self.rawValue = value
    }
}

// MARK: - CustomStringConvertible

extension RoomSettings: CustomStringConvertible, CustomDebugStringConvertible {

    public var description: String {
        let mode = gameMode.map(String.init(describing:)) ?? "mode[\(modeLabelIndex)]"
        return "RoomSettings(0x\(String(rawValue, radix: 16)), \(mode))"
    }

    public var debugDescription: String {
        description
    }
}

#if !GUNBOUND_EMBEDDED
extension RoomSettings: Codable {}
#endif
