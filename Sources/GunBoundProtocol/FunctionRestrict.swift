/// GunBound Function Restrict
public struct FunctionRestrict: OptionSet, Equatable, Hashable, Sendable {

    public var rawValue: UInt32

    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }
}

// MARK: - ExpressibleByIntegerLiteral

extension FunctionRestrict: ExpressibleByIntegerLiteral {

    public init(integerLiteral value: UInt32) {
        self.rawValue = value
    }
}

// MARK: - CustomStringConvertible

extension FunctionRestrict: CustomStringConvertible, CustomDebugStringConvertible {

    public var description: String {
        "0x" + rawValue.toHexadecimal()  // TODO: print as array
    }

    public var debugDescription: String {
        description
    }
}

public extension FunctionRestrict {

    static var avatarEnabled: FunctionRestrict { FunctionRestrict(rawValue: 1 << 4) }
    static var effectForce: FunctionRestrict { FunctionRestrict(rawValue: 1 << 13) }
    static var effectTornado: FunctionRestrict { FunctionRestrict(rawValue: 1 << 14) }
    static var effectLightning: FunctionRestrict { FunctionRestrict(rawValue: 1 << 15) }
    static var effectWind: FunctionRestrict { FunctionRestrict(rawValue: 1 << 16) }
    static var effectThor: FunctionRestrict { FunctionRestrict(rawValue: 1 << 17) }
    static var effectMoon: FunctionRestrict { FunctionRestrict(rawValue: 1 << 18) }
    static var effectEclipse: FunctionRestrict { FunctionRestrict(rawValue: 1 << 19) }
    static var event1Enable: FunctionRestrict { FunctionRestrict(rawValue: 1 << 20) }
    static var event2Enable: FunctionRestrict { FunctionRestrict(rawValue: 1 << 21) }
    static var event3Enable: FunctionRestrict { FunctionRestrict(rawValue: 1 << 22) }
    static var event4Enable: FunctionRestrict { FunctionRestrict(rawValue: 1 << 23) }
}

// MARK: - Parsing / Encoding

extension FunctionRestrict {

    public init(parsing input: inout ParserSpan) throws(ParsingError) {
        self.init(rawValue: try UInt32(parsingLittleEndian: &input))
    }

    public func encode(to output: inout ByteWriter) {
        output.write(rawValue, endianness: .little)
    }
}

#if !GUNBOUND_EMBEDDED
extension FunctionRestrict: Codable {}
#endif
