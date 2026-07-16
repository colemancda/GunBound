/// An opaque avatar-item identifier for `BuyGoldRequest`/`BuyCashRequest`'s
/// `avatar: UInt32` field and the `avatarInventory` list it lands in.
///
/// **This is our own scheme, not a decompiled fact.** The original client's
/// on-wire avatar-purchase item identifier isn't decoded (`itemdata.dat`'s
/// ordinal→item mapping for the *avatar* store, unlike the battle-item
/// shelf's `DAT_0056dc40`, is still unresolved from the client alone). So
/// this packs the two things our own `AvatarEquipment` model already needs
/// to name a part again later — its category and part code — into one
/// `UInt32`: bits 0–15 the `AvatarEquipment.Part` raw value (bit 15 gender,
/// bits 0–14 id), bits 16–17 the category's word index (0 body, 1 head,
/// 2 glasses, 3 flag). Round-trips losslessly for any part this client
/// itself purchases; a code from elsewhere just won't resolve to a name.
public struct AvatarShopItemCode: RawRepresentable, Equatable, Hashable, Sendable {

    public let rawValue: UInt32

    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    public init(category: AvatarEquipment.Category, part: AvatarEquipment.Part) {
        self.rawValue = UInt32(part.rawValue) | (UInt32(category.wordIndex) << 16)
    }

    public var part: AvatarEquipment.Part {
        AvatarEquipment.Part(rawValue: UInt16(rawValue & 0xffff))
    }

    public var category: AvatarEquipment.Category? {
        let index = (rawValue >> 16) & 0xff
        return AvatarEquipment.Category.allCases.first { $0.wordIndex == UInt64(index) }
    }
}
