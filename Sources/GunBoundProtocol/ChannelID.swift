/// GunBound Channel ID
public struct ChannelID: RawRepresentable, Equatable, Hashable, Sendable {

    public var rawValue: UInt16

    public init(rawValue: UInt16) {
        self.rawValue = rawValue
    }
}

// MARK: - ExpressibleByIntegerLiteral

extension ChannelID: ExpressibleByIntegerLiteral {

    public init(integerLiteral value: UInt16) {
        self.rawValue = value
    }
}

// MARK: - CustomStringConvertible

extension ChannelID: CustomStringConvertible, CustomDebugStringConvertible {

    public var description: String {
        rawValue.description
    }

    public var debugDescription: String {
        description
    }
}

// MARK: - Parsing / Encoding

extension ChannelID {

    public init(parsing input: inout ParserSpan) throws(ParsingError) {
        self.init(rawValue: try UInt16(parsingLittleEndian: &input))
    }

    public func encode(to output: inout ByteWriter) {
        output.write(rawValue, endianness: .little)
    }
}

#if !GUNBOUND_EMBEDDED
extension ChannelID: Codable {}
#endif
