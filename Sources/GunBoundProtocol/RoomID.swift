/// GunBound Room ID
public struct RoomID: RawRepresentable, Equatable, Hashable, Sendable {

    public var rawValue: UInt16

    public init(rawValue: UInt16) {
        self.rawValue = rawValue
    }
}

public extension RoomID {

    static var min: RoomID { RoomID(rawValue: .min) }

    static var max: RoomID { RoomID(rawValue: .max) }
}

// MARK: - Comparable

extension RoomID: Comparable {

    public static func < (lhs: RoomID, rhs: RoomID) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public static func > (lhs: RoomID, rhs: RoomID) -> Bool {
        lhs.rawValue > rhs.rawValue
    }
}

// MARK: - ExpressibleByIntegerLiteral

extension RoomID: ExpressibleByIntegerLiteral {

    public init(integerLiteral value: UInt16) {
        self.rawValue = value
    }
}

// MARK: - CustomStringConvertible

extension RoomID: CustomStringConvertible, CustomDebugStringConvertible {

    public var description: String {
        rawValue.description
    }

    public var debugDescription: String {
        description
    }
}

// MARK: - Parsing / Encoding

extension RoomID {

    public init(parsing input: inout ParserSpan) throws(ParsingError) {
        self.init(rawValue: try UInt16(parsingLittleEndian: &input))
    }

    public func encode(to output: inout ByteWriter) {
        output.write(rawValue, endianness: .little)
    }
}

#if !GUNBOUND_EMBEDDED
extension RoomID: Codable {}
#endif
