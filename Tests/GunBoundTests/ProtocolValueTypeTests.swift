import Foundation
import Testing
@testable import GunBoundProtocol

/// Unit coverage for the protocol's small value types — the string/byte
/// conversions, option sets, enum descriptions, and parse/encode round trips
/// that the packet tests only touch incidentally.
@Suite struct ProtocolValueTypeTests {

    private func encoded<T>(_ value: T, _ encode: (T, inout ByteWriter) -> Void) -> [UInt8] {
        var writer = ByteWriter()
        encode(value, &writer)
        return writer.bytes
    }

    // MARK: RoomPassword

    @Test func roomPassword() throws {
        #expect(RoomPassword().isEmpty)
        #expect(RoomPassword().rawValue == "")
        #expect(RoomPassword.length == 4)

        let pw = RoomPassword(rawValue: "abcd")
        #expect(pw?.rawValue == "abcd")
        #expect(pw?.isEmpty == false)
        #expect(RoomPassword(rawValue: "") == RoomPassword())
        #expect(RoomPassword(rawValue: "toolong") == nil)  // > 4 bytes

        let literal: RoomPassword = "pw"
        #expect(literal.rawValue == "pw")
        #expect(literal.description == "pw")
        #expect(Set([literal, literal]).count == 1)  // Hashable

        // Parse / encode round trip.
        var bytes = [UInt8]("abcd".utf8)
        let parsed = try bytes.withParserSpan { try RoomPassword(parsing: &$0) }
        #expect(parsed.rawValue == "abcd")
        #expect(encoded(parsed) { $0.encode(to: &$1) } == [UInt8]("abcd".utf8))
        _ = bytes

        // Codable round trip.
        let data = try JSONEncoder().encode(literal)
        #expect(try JSONDecoder().decode(RoomPassword.self, from: data) == literal)
    }

    // MARK: IPv4Address

    @Test func ipv4Address() throws {
        let addr = IPv4Address(1, 2, 3, 4)
        #expect(addr.rawValue == "1.2.3.4")
        #expect(addr.description == "1.2.3.4")
        #expect(IPv4Address(rawValue: "1.2.3.4") == addr)
        #expect(IPv4Address.any == IPv4Address(0, 0, 0, 0))
        #expect(IPv4Address(rawValue: "1.2.3") == nil)       // too few components
        #expect(IPv4Address(rawValue: "1.2.3.999") == nil)   // 999 > UInt8.max
        #expect(IPv4Address(rawValue: "a.b.c.d") == nil)     // non-numeric
        #expect(Set([addr, addr]).count == 1)                // Hashable

        var bytes: [UInt8] = [10, 0, 0, 1]
        let parsed = try bytes.withParserSpan { try IPv4Address(parsing: &$0) }
        #expect(parsed.rawValue == "10.0.0.1")
        #expect(encoded(parsed) { $0.encode(to: &$1) } == [10, 0, 0, 1])
        _ = bytes

        let data = try JSONEncoder().encode(addr)
        #expect(try JSONDecoder().decode(IPv4Address.self, from: data) == addr)
    }

    // MARK: Mobile

    @Test func mobile() {
        // Every case has a non-empty description (covers the full switch).
        for mobile in Mobile.allCases {
            #expect(!mobile.description.isEmpty)
            #expect(mobile.debugDescription == mobile.description)
        }
        #expect(Mobile.random.description == "Random")
        #expect(Mobile(rawValue: 0x00) == .armor)
        // validMobiles excludes .random; a drawn mobile is always valid.
        #expect(!Mobile.validMobiles.contains(.random))
        #expect(Mobile.validMobiles.contains(.armor))
        var generator = SystemRandomNumberGenerator()
        #expect(Mobile.random(using: &generator) != .random)
        #expect(Mobile.randomMobile != .random)
        #expect(encoded(Mobile.knight) { $0.encode(to: &$1) } == [0x12])
    }

    // MARK: FunctionRestrict

    @Test func functionRestrict() throws {
        let restrict: FunctionRestrict = [.effectTornado, .effectLightning]
        #expect(restrict.contains(.effectTornado))
        #expect(!restrict.contains(.effectForce))
        #expect(restrict.rawValue == (1 << 14 | 1 << 15))

        let literal: FunctionRestrict = 0x10
        #expect(literal == .avatarEnabled)
        #expect(literal.description.hasPrefix("0x"))

        var bytes = encoded(restrict) { $0.encode(to: &$1) }
        let parsed = try bytes.withParserSpan { try FunctionRestrict(parsing: &$0) }
        #expect(parsed == restrict)
        _ = bytes
    }

    // MARK: Integer byte conversions

    @Test func integerByteConversions() {
        #expect(UInt16(bytes: UInt16(0x1234).bytes) == 0x1234)
        #expect(UInt32(bytes: UInt32(0x12345678).bytes) == 0x12345678)
        #expect(Int32(bytes: Int32(-1).bytes) == -1)
        #expect(UInt64(bytes: UInt64(0x0123456789ABCDEF).bytes) == 0x0123456789ABCDEF)
    }
}
