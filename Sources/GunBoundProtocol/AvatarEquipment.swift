/// A worn avatar outfit — the decode of the packed `avatarEquipped: UInt64`
/// carried by `AuthenticationResponse` and `JoinRoomResponse.PlayerSession`
/// (decomp `FILEFORMATS.md` — "The avatarEquipped value"): **four
/// little-endian `u16` part codes**, one per outfit slot. Each code packs
/// **bit 15 = gender** (set → male `m`, clear → female `f`) and **bits
/// 0–14 = the part id** (its record index in `avatar.xfs`'s
/// `{gender}{category}.dat` catalog); `0xffff` means nothing is worn in
/// that slot.
///
/// **Word-order caveat:** Body (word 0) and Glasses (word 2) are confirmed;
/// the two in-binary unpackers disagree on whether word 1 is Head and
/// word 3 Flag or the reverse. This follows the state-9-side unpacker
/// (`0x004dc5c0`: word 1 = Head, word 3 = Flag) until a live-client test
/// resolves it.
public struct AvatarEquipment: RawRepresentable, Equatable, Hashable, Sendable {

    public let rawValue: UInt64

    public init(rawValue: UInt64) {
        self.rawValue = rawValue
    }

    /// The four outfit slots, in the compositor's draw order (body under
    /// head under glasses; the flag flies on its own pole).
    public enum Category: CaseIterable, Sendable {

        case body
        case head
        case glasses
        case flag

        /// The slot's letter in `.dat` catalog and sprite entry names.
        public var code: Character {
            switch self {
            case .body: return "b"
            case .head: return "h"
            case .glasses: return "g"
            case .flag: return "f"
            }
        }

        /// The `avatarEquipped` word index holding this slot's part code.
        var wordIndex: UInt64 {
            switch self {
            case .body: return 0
            case .head: return 1
            case .glasses: return 2
            case .flag: return 3
            }
        }
    }

    /// One slot's part code: bit 15 = gender, bits 0–14 = part id.
    public struct Part: RawRepresentable, Equatable, Hashable, Sendable {

        public let rawValue: UInt16

        public init(rawValue: UInt16) {
            self.rawValue = rawValue
        }

        /// `0xffff` — nothing worn in this slot.
        public var isEmpty: Bool { rawValue == 0xffff }

        /// Bit 15: set → male (`m` sprites), clear → female (`f`).
        public var isMale: Bool { rawValue & 0x8000 != 0 }

        /// The part's record index in its `{gender}{category}.dat` catalog.
        public var id: Int { Int(rawValue & 0x7fff) }
    }

    public var body: Part { part(.body) }
    public var head: Part { part(.head) }
    public var glasses: Part { part(.glasses) }
    public var flag: Part { part(.flag) }

    public func part(_ category: Category) -> Part {
        Part(rawValue: UInt16(truncatingIfNeeded: rawValue >> (16 * category.wordIndex)))
    }

    /// The `graphics.xfs` sprite entry for a slot's worn part —
    /// `{gender}{category}{id:05}.img`, or the `…l.img` large (in-battle)
    /// variant. Flag sprites are gender-neutral and always drawn from the
    /// `mf` namespace. `nil` when the slot is empty.
    public func spriteName(_ category: Category, large: Bool = false) -> String? {
        let part = part(category)
        guard !part.isEmpty else { return nil }
        let gender: Character = (category == .flag || part.isMale) ? "m" : "f"
        var digits = String(part.id)
        while digits.count < 5 { digits = "0" + digits }
        return "\(gender)\(category.code)\(digits)\(large ? "l" : "").img"
    }
}
