/// Client version
public struct ClientVersion: RawRepresentable, Equatable, Hashable, Sendable {

    public let rawValue: UInt16

    public init(rawValue: UInt16) {
        self.rawValue = rawValue
    }
}

// MARK: - Comparable

extension ClientVersion: Comparable {

    public static func < (lhs: ClientVersion, rhs: ClientVersion) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - ExpressibleByIntegerLiteral

extension ClientVersion: ExpressibleByIntegerLiteral {

    public init(integerLiteral value: UInt16) {
        self.init(rawValue: value)
    }
}

// MARK: - CustomStringConvertible

extension ClientVersion: CustomStringConvertible, CustomDebugStringConvertible {

    public var description: String {
        rawValue.description
    }

    public var debugDescription: String {
        description
    }
}

// MARK: - Parsing / Encoding

extension ClientVersion {

    public init(parsing input: inout ParserSpan) throws(ParsingError) {
        self.init(rawValue: try UInt16(parsingLittleEndian: &input))
    }

    public func encode(to output: inout ByteWriter) {
        output.write(rawValue, endianness: .little)
    }
}

#if !GUNBOUND_EMBEDDED
extension ClientVersion: Codable {}
#endif
