public enum Team: UInt8, CaseIterable, Sendable {

    /// Team A
    case a = 0x00

    /// Team B
    case b = 0x01
}

// MARK: - CustomStringConvertible

extension Team: CustomStringConvertible, CustomDebugStringConvertible {

    public var description: String {
        switch self {
        case .a:
            return "A"
        case .b:
            return "B"
        }
    }

    public var debugDescription: String {
        description
    }
}

// MARK: - Encoding

extension Team {

    public func encode(to output: inout ByteWriter) {
        output.write(rawValue)
    }
}

#if !GUNBOUND_EMBEDDED
extension Team: Codable {}
#endif
