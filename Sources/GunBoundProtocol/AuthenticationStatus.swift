/// Authentication Status
public enum AuthenticationStatus: UInt16, Sendable {

    case success = 0x0000
    case badUsername = 0x0010
    case badPassword = 0x0011
    case bannedUser = 0x0030
    case badVersion = 0x0060
}

// MARK: - Parsing / Encoding

extension AuthenticationStatus {

    public init(parsing input: inout ParserSpan) throws {
        let rawValue = try UInt16(parsingLittleEndian: &input)
        guard let value = Self(rawValue: rawValue) else {
            throw GunBoundProtocolError.invalidValue
        }
        self = value
    }

    public func encode(to output: inout ByteWriter) {
        output.write(rawValue, endianness: .little)
    }
}

#if !GUNBOUND_EMBEDDED
extension AuthenticationStatus: Codable {}
#endif
