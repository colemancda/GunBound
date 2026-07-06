/// A minimal, Foundation-free IPv4 address (4 raw bytes), used for packet wire
/// fields. Networking code bridges this to a socket library's own address type.
public struct IPv4Address: RawRepresentable, Equatable, Hashable, Sendable {

    public var bytes: (UInt8, UInt8, UInt8, UInt8)

    public init(_ byte0: UInt8, _ byte1: UInt8, _ byte2: UInt8, _ byte3: UInt8) {
        self.bytes = (byte0, byte1, byte2, byte3)
    }
}

public extension IPv4Address {

    static var any: IPv4Address { IPv4Address(0, 0, 0, 0) }
}

// MARK: - Equatable / Hashable

extension IPv4Address {

    public static func == (lhs: IPv4Address, rhs: IPv4Address) -> Bool {
        lhs.bytes.0 == rhs.bytes.0 && lhs.bytes.1 == rhs.bytes.1
            && lhs.bytes.2 == rhs.bytes.2 && lhs.bytes.3 == rhs.bytes.3
    }

    public func hash(into hasher: inout Hasher) {
        withUnsafeBytes(of: bytes) { hasher.combine(bytes: $0) }
    }
}

// MARK: - RawRepresentable

extension IPv4Address {

    public init?(rawValue: String) {
        let components = rawValue.split(separator: ".")
        guard components.count == 4 else { return nil }
        var bytes = [UInt8]()
        bytes.reserveCapacity(4)
        for component in components {
            guard let byte = UInt8(component) else { return nil }
            bytes.append(byte)
        }
        self.init(bytes[0], bytes[1], bytes[2], bytes[3])
    }

    public var rawValue: String {
        "\(bytes.0).\(bytes.1).\(bytes.2).\(bytes.3)"
    }
}

// MARK: - CustomStringConvertible

extension IPv4Address: CustomStringConvertible, CustomDebugStringConvertible {

    public var description: String {
        rawValue
    }

    public var debugDescription: String {
        description
    }
}

// MARK: - Parsing / Encoding

extension IPv4Address {

    public init(parsing input: inout ParserSpan) throws(ParsingError) {
        let data = try [UInt8](parsing: &input, byteCount: 4)
        self.init(data[0], data[1], data[2], data[3])
    }

    public func encode(to output: inout ByteWriter) {
        output.write([bytes.0, bytes.1, bytes.2, bytes.3])
    }
}

#if !GUNBOUND_EMBEDDED
extension IPv4Address: Codable {

    public init(from decoder: Swift.Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        guard let value = Self(rawValue: rawValue) else {
            throw Swift.DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid IPv4 address")
        }
        self = value
    }

    public func encode(to encoder: Swift.Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
#endif
