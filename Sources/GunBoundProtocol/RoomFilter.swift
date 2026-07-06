/// Room Filter
public enum RoomFilter: UInt8, Sendable {

    /// All rooms
    case all = 1

    /// Waiting rooms
    case waiting = 2
}

// MARK: - Encoding

extension RoomFilter {

    public func encode(to output: inout ByteWriter) {
        output.write(rawValue)
    }
}

#if !GUNBOUND_EMBEDDED
extension RoomFilter: Codable {}
#endif
