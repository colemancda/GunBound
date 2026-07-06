public struct RoomPassword: Sendable {

    internal let bytes: (UInt8, UInt8, UInt8, UInt8)

    internal init(bytes: (UInt8, UInt8, UInt8, UInt8)) {
        self.bytes = bytes
    }

    public init() {
        self.bytes = (0x00, 0x00, 0x00, 0x00)
    }
}

public extension RoomPassword {

    static var length: Int { 4 }

    var isEmpty: Bool {
        self == RoomPassword()
    }
}

// MARK: - Equatable

extension RoomPassword: Equatable {

    public static func == (lhs: RoomPassword, rhs: RoomPassword) -> Bool {
        return lhs.bytes.0 == rhs.bytes.0 && lhs.bytes.1 == rhs.bytes.1 && lhs.bytes.2 == rhs.bytes.2 && lhs.bytes.3 == rhs.bytes.3
    }
}

// MARK: - Hashable

extension RoomPassword: Hashable {

    public func hash(into hasher: inout Hasher) {
        withUnsafeBytes(of: bytes) {
            hasher.combine(bytes: $0)
        }
    }
}

// MARK: - RawRepresentable

extension RoomPassword: RawRepresentable {

    public init?(rawValue: String) {
        // initialize empty
        guard rawValue.isEmpty == false else {
            self.init()
            return
        }
        // validate length
        let stringBytes = Array(rawValue.utf8)
        guard stringBytes.count <= Self.length else {
            return nil
        }
        // set bytes
        self.init(
            bytes: (
                stringBytes.count > 0 ? stringBytes[0] : 0x00,
                stringBytes.count > 1 ? stringBytes[1] : 0x00,
                stringBytes.count > 2 ? stringBytes[2] : 0x00,
                stringBytes.count > 3 ? stringBytes[3] : 0x00
            ))
    }

    public var rawValue: String {
        guard isEmpty == false else {
            return ""
        }
        let stringBytes = [bytes.0, bytes.1, bytes.2, bytes.3].prefix { $0 != 0 }
        return String(decoding: stringBytes, as: UTF8.self)
    }
}

// MARK: - ExpressibleByStringLiteral

extension RoomPassword: ExpressibleByStringLiteral {

    public init(stringLiteral value: String) {
        guard let value = Self.init(rawValue: String(value.prefix(Self.length))) else {
            assertionFailure("Invalid string \(value)")
            self.init()
            return
        }
        self = value
    }
}

// MARK: - CustomStringConvertible

extension RoomPassword: CustomStringConvertible, CustomDebugStringConvertible {

    public var description: String {
        rawValue
    }

    public var debugDescription: String {
        description
    }
}

// MARK: - Parsing / Encoding

extension RoomPassword {

    public init(parsing input: inout ParserSpan) throws(ParsingError) {
        let data = try [UInt8](parsing: &input, byteCount: Self.length)
        self.bytes = (data[0], data[1], data[2], data[3])
    }

    public func encode(to output: inout ByteWriter) {
        output.write([bytes.0, bytes.1, bytes.2, bytes.3])
    }
}

#if !GUNBOUND_EMBEDDED
extension RoomPassword: Codable {

    public init(from decoder: Swift.Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        guard let value = Self(rawValue: rawValue) else {
            throw Swift.DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid room password")
        }
        self = value
    }

    public func encode(to encoder: Swift.Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
#endif
