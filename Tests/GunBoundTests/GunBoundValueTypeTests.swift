import Testing
@testable import GunBound
@testable import GunBoundProtocol

/// Unit coverage for GunBound's small value types and helpers: the client-mode
/// enum, the integer byte-conversion helpers, and mobile argument parsing.
@Suite struct GunBoundValueTypeTests {

    @Test func clientModeDescriptionsAndRawValues() {
        let modes: [(ClientMode, UInt8)] = [
            (.logo1, 5), (.logo2, 6), (.title, 1), (.serverSelect, 2),
            (.gameRoomList, 3), (.avatarShop, 7), (.readyRoom, 9),
            (.loading, 10), (.inGameSession, 11), (.exitToDesktop, 15),
        ]
        var descriptions = Set<String>()
        for (mode, raw) in modes {
            #expect(mode.rawValue == raw)
            #expect(ClientMode(rawValue: raw) == mode)
            #expect(!mode.description.isEmpty)
            #expect(mode.debugDescription == mode.description)
            descriptions.insert(mode.description)
        }
        // Every mode has a distinct description (the switch has no fallthrough).
        #expect(descriptions.count == modes.count)

        // Integer-literal init and an unknown raw value.
        let literal: ClientMode = 3
        #expect(literal == .gameRoomList)
        #expect(!ClientMode(rawValue: 200).description.isEmpty)  // unknown falls to default
    }

    @Test func mobileArgumentParsing() {
        #expect(Mobile(argument: "5") == .boomer)
        #expect(Mobile(argument: "0") == .armor)
        #expect(Mobile(argument: "255") == .random)
        #expect(Mobile(argument: "notanumber") == nil)
        #expect(Mobile(argument: "99") == nil)  // valid number, no such mobile
    }
}
