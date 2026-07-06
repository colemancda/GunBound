public protocol FixedLengthString: RawRepresentable where RawValue == String {

    static var length: Int { get }
}

public extension FixedLengthString {

    static func validate(_ string: String) -> Bool {
        string.utf8.count <= Self.length
    }

    var isEmpty: Bool {
        return rawValue.isEmpty
    }
}

// MARK: - CustomStringConvertible

extension FixedLengthString where Self: CustomStringConvertible {

    public var description: String {
        rawValue.description
    }
}

extension FixedLengthString where Self: CustomDebugStringConvertible {

    public var debugDescription: String {
        rawValue.debugDescription
    }
}

// MARK: - ExpressibleByStringLiteral

extension FixedLengthString where Self: ExpressibleByStringLiteral {

    public init(stringLiteral value: String) {
        guard let value = Self(rawValue: value) else {
            fatalError("Invalid string \(value)")
        }
        self = value
    }
}

// MARK: - Parsing / Encoding

public extension FixedLengthString {

    init(parsing input: inout ParserSpan) throws {
        let string = try String(parsingFixedLengthASCII: &input, length: Self.length)
        guard let value = Self(rawValue: string) else {
            throw GunBoundProtocolError.invalidValue
        }
        self = value
    }

    func encode(to output: inout ByteWriter) {
        output.write(ascii: rawValue, fixedLength: Self.length)
    }
}
