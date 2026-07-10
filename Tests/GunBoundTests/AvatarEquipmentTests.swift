import Testing
@testable import GunBoundProtocol

@Suite struct AvatarEquipmentTests {

    /// The four little-endian u16 words map body / head / glasses / flag
    /// (word 1 = Head, word 3 = Flag per `LoadRoomSlotAvatar` `0x4dc5c0`;
    /// the Head/Flag order is provisional — see `AvatarEquipment`'s note).
    @Test func unpacksTheFourWords() {
        let outfit = AvatarEquipment(rawValue: 0x0001_8001_8000_8005)
        #expect(outfit.body.rawValue == 0x8005)
        #expect(outfit.head.rawValue == 0x8000)
        #expect(outfit.glasses.rawValue == 0x8001)
        #expect(outfit.flag.rawValue == 0x0001)
    }

    /// Bit 15 = gender, bits 0–14 = the catalog record index; `0xffff` is an
    /// empty slot.
    @Test func decodesPartCodes() {
        let male = AvatarEquipment.Part(rawValue: 0x8005)
        #expect(male.isMale)
        #expect(male.id == 5)
        #expect(!male.isEmpty)

        let female = AvatarEquipment.Part(rawValue: 0x0003)
        #expect(!female.isMale)
        #expect(female.id == 3)

        #expect(AvatarEquipment.Part(rawValue: 0xffff).isEmpty)
    }

    /// The doc's own worked example: body code `0x8005` → male body id 5 →
    /// `mb00005.img` ("Roman General"), `mb00005l.img` in battle.
    @Test func buildsSpriteNames() {
        let outfit = AvatarEquipment(rawValue: 0x0001_8001_8000_8005)
        #expect(outfit.spriteName(.body) == "mb00005.img")
        #expect(outfit.spriteName(.body, large: true) == "mb00005l.img")
        #expect(outfit.spriteName(.head) == "mh00000.img")
        #expect(outfit.spriteName(.glasses) == "mg00001.img")
    }

    /// Flag sprites are gender-neutral — always the `mf` namespace, even for
    /// a female (bit-15-clear) code.
    @Test func flagsIgnoreGender() {
        let outfit = AvatarEquipment(rawValue: 0x0002_0000_0000_0000)
        #expect(outfit.spriteName(.flag) == "mf00002.img")
    }

    /// An empty (0xffff) slot yields no sprite; the all-zero default outfit
    /// resolves to the female standard parts.
    @Test func emptyAndDefaultSlots() {
        let bare = AvatarEquipment(rawValue: 0xffff_ffff_ffff_ffff)
        for category in AvatarEquipment.Category.allCases {
            #expect(bare.spriteName(category) == nil)
        }

        let standard = AvatarEquipment(rawValue: 0)
        #expect(standard.spriteName(.body) == "fb00000.img")
        #expect(standard.spriteName(.head) == "fh00000.img")
    }
}
