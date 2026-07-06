/// GunBound Socket Address (wire representation: 4-byte IPv4 address + big-endian port)
public struct GunBoundAddress: Equatable, Hashable, Sendable {

    public var ipAddress: IPv4Address

    public var port: UInt16

    public init(ipAddress: IPv4Address, port: UInt16) {
        self.ipAddress = ipAddress
        self.port = port
    }

    public init?(address: String, port: UInt16) {
        guard let ipAddress = IPv4Address(rawValue: address) else {
            return nil
        }
        self.init(ipAddress: ipAddress, port: port)
    }
}

public extension GunBoundAddress {

    var address: String {
        ipAddress.rawValue
    }
}

// MARK: - RawRepresentable

extension GunBoundAddress: RawRepresentable {

    public init?(rawValue: String) {
        let components = rawValue.split(separator: ":")
        guard components.count == 2,
            let ipAddress = IPv4Address(rawValue: String(components[0])),
            let port = UInt16(components[1])
        else {
            return nil
        }
        self.ipAddress = ipAddress
        self.port = port
    }

    public var rawValue: String {
        address + ":" + port.description
    }
}

// MARK: - CustomStringConvertible

extension GunBoundAddress: CustomStringConvertible, CustomDebugStringConvertible {

    public var description: String {
        rawValue
    }

    public var debugDescription: String {
        description
    }
}

// MARK: - Parsing / Encoding

extension GunBoundAddress {

    public init(parsing input: inout ParserSpan) throws {
        self.ipAddress = try IPv4Address(parsing: &input)
        self.port = try UInt16(parsingBigEndian: &input)
    }

    public func encode(to output: inout ByteWriter) {
        ipAddress.encode(to: &output)
        output.write(port, endianness: .big)
    }
}

#if !GUNBOUND_EMBEDDED
extension GunBoundAddress: Codable {

    private enum CodingKeys: String, CodingKey {
        case ipAddress
        case port
    }
}
#endif
