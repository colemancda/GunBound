/// Server Directory Response
///
/// Sent by the server in response to a ServerDirectoryRequest.
/// Contains a list of available game servers for the client to choose from.
///
/// **Usage:**
/// Sent after the client requests the server directory.
/// The client displays this list to allow the player to select
/// which game server to connect to.
///
/// Each server entry includes:
/// - Server name and description
/// - Network address and port
/// - Current utilization and capacity
/// - Whether the server is enabled/available
public struct ServerDirectoryResponse: GunBoundPacket, GunBoundPacketEncodable, Equatable, Hashable, Sendable {

    public static var opcode: Opcode { .serverDirectoryResponse }

    /// List of available game servers
    public let directory: [Server]

    public init(directory: [Server] = []) {
        self.directory = directory
    }
}

// MARK: - Supporting Types

public extension ServerDirectoryResponse {

    /// A single game server entry in the directory listing.
    struct Server: Equatable, Hashable, Sendable {

        public var name: String

        public var descriptionText: String

        public var address: IPv4Address

        public var port: UInt16

        public var utilization: UInt16

        public var capacity: UInt16

        public var isEnabled: Bool

        public init(
            name: String,
            descriptionText: String,
            address: IPv4Address,
            port: UInt16,
            utilization: UInt16,
            capacity: UInt16,
            isEnabled: Bool
        ) {
            self.name = name
            self.descriptionText = descriptionText
            self.address = address
            self.port = port
            self.utilization = utilization
            self.capacity = capacity
            self.isEnabled = isEnabled
        }
    }
}

extension ServerDirectoryResponse {

    public func encode(to output: inout ByteWriter) {
        // unknown
        output.write(UInt8(0x00))
        output.write(UInt8(0x00))
        output.write(UInt8(0x01))

        // number of servers
        output.write(UInt8(directory.count))

        // encode each
        for (index, server) in directory.enumerated() {
            // Server Index
            output.write(UInt8(index))
            output.write(UInt8(0x00))
            output.write(UInt8(0x00))
            // values
            output.writeLengthPrefixed(ascii: server.name)
            output.writeLengthPrefixed(ascii: server.descriptionText)
            server.address.encode(to: &output)
            output.write(server.port, endianness: .big)
            output.write(server.utilization, endianness: .big)
            output.write(server.utilization, endianness: .big)
            output.write(server.capacity, endianness: .big)
            output.write(server.isEnabled)
        }
    }
}
