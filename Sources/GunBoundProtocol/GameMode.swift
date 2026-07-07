/// GunBound game/battle mode, packed into the upper 16 bits of a room's
/// `settings` field (`gameMode = Int16(truncatingIfNeeded: settings >> 16)`).
public enum GameMode: Int16, CaseIterable, Sendable {

    case solo = 0x00
    case score = 0x44
    case tag = 0x08
    case jewel = 0x0C
}

public extension GameMode {

    /// Extracts the game mode from a room `settings` value's upper 16 bits.
    /// `nil` if the value doesn't match a known mode.
    init?(settings: UInt32) {
        self.init(rawValue: Int16(truncatingIfNeeded: Int32(bitPattern: settings) >> 16))
    }
}

// MARK: - CustomStringConvertible

extension GameMode: CustomStringConvertible, CustomDebugStringConvertible {

    public var description: String {
        switch self {
        case .solo:
            return "Solo"
        case .score:
            return "Score"
        case .tag:
            return "Tag"
        case .jewel:
            return "Jewel"
        }
    }

    public var debugDescription: String {
        description
    }
}

#if !GUNBOUND_EMBEDDED
extension GameMode: Codable {}
#endif
