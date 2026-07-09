import Foundation
import Testing
@testable import GunBound
import GunBoundProtocol

@Suite struct RoomSettingsTests {

    /// Each radio group reads/writes only its own decomp-confirmed bit range.
    @Test func groupsAreIsolated() {
        var settings: RoomSettings = 0
        settings.optionA = 0xf
        settings.optionB = 0xf
        settings.optionC = 3
        settings.optionD = 3
        #expect(settings.rawValue == 0x0000_ff0f)

        // Overwriting one group leaves the others untouched.
        settings.optionB = 0x2
        #expect(settings.optionA == 0xf)
        #expect(settings.optionB == 0x2)
        #expect(settings.rawValue == 0x0000_f20f)

        // Values wider than the group are masked, not smeared.
        settings.optionC = 0xff
        #expect(settings.optionC == 3)
    }

    /// Bits 18–19 drive the SOLO/SCORE/TAG/JEWEL card label —
    /// `RenderRoomCard`'s `(settings >> 0x12) & 3`.
    @Test func modeLabelIndexReadsBits18to19() {
        #expect(RoomSettings(rawValue: 0).modeLabelIndex == 0)          // SOLO
        #expect(RoomSettings(rawValue: 1 << 18).modeLabelIndex == 1)    // SCORE
        #expect(RoomSettings(rawValue: 2 << 18).modeLabelIndex == 2)    // TAG
        #expect(RoomSettings(rawValue: 3 << 18).modeLabelIndex == 3)    // JEWEL
        // Bits outside the label don't leak in.
        #expect(RoomSettings(rawValue: 0xffff_ffff).modeLabelIndex == 3)
    }

    /// Composing with a `GameMode` produces the observed wire packings, and
    /// they round-trip back through the upper-16-bits view.
    @Test func gameModeRoundTrips() {
        for mode in GunBoundProtocol.GameMode.allCases {
            let settings = RoomSettings(gameMode: mode)
            #expect(settings.gameMode == mode, "\(mode)")
            // The packing stays inside group E (bits 18–23).
            #expect(settings.rawValue & ~RoomSettings.Mask.groupE == 0, "\(mode)")
        }
        // Score's observed wire value (0x44 in the upper-16 view) sets bit 22
        // in addition to the label bits.
        #expect(RoomSettings(gameMode: .score).rawValue == 0x0044_0000)
        #expect(RoomSettings(gameMode: .score).modeLabelIndex == 1)
        #expect(RoomSettings(gameMode: .jewel).modeLabelIndex == 3)
    }

    /// The typed accessor on a wire room matches the raw dword.
    @Test func roomExposesTypedSettings() {
        let room = RoomListResponse.Room(
            id: 1, name: "R", map: .random, settings: RoomSettings(gameMode: .tag).rawValue,
            playerCount: 1, capacity: ._4_4, isPlaying: false, isLocked: false
        )
        #expect(room.roomSettings.gameMode == .tag)
        #expect(room.roomSettings.modeLabelIndex == 2)
    }
}
