/// GunBound Channel User ID
public struct ChannelUserID: RawRepresentable, Equatable, Hashable, Sendable {

    public var rawValue: UInt8

    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }
}

public extension ChannelUserID {

    static var min: ChannelUserID { ChannelUserID(rawValue: .min) }

    static var max: ChannelUserID { ChannelUserID(rawValue: .max) }
}

// MARK: - Comparable

extension ChannelUserID: Comparable {

    public static func < (lhs: ChannelUserID, rhs: ChannelUserID) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public static func > (lhs: ChannelUserID, rhs: ChannelUserID) -> Bool {
        lhs.rawValue > rhs.rawValue
    }
}

// MARK: - ExpressibleByIntegerLiteral

extension ChannelUserID: ExpressibleByIntegerLiteral {

    public init(integerLiteral value: UInt8) {
        self.rawValue = value
    }
}

// MARK: - CustomStringConvertible

extension ChannelUserID: CustomStringConvertible, CustomDebugStringConvertible {

    public var description: String {
        rawValue.description
    }

    public var debugDescription: String {
        description
    }
}

// MARK: - Parsing / Encoding

extension ChannelUserID {

    public init(parsing input: inout ParserSpan) throws(ParsingError) {
        self.init(rawValue: try UInt8(parsing: &input))
    }

    public func encode(to output: inout ByteWriter) {
        output.write(rawValue)
    }
}

#if !GUNBOUND_EMBEDDED
extension ChannelUserID: Codable {}
#endif
