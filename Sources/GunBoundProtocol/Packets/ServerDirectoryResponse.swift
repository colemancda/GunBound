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
public struct ServerDirectoryResponse: GunBoundPacket, GunBoundPacketEncodable, GunBoundPacketDecodable, Equatable, Hashable, Sendable {

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

        /// Whether the server has no free slots (`currentPlayers >=
        /// maxCapacity`). The decompiled connect handlers
        /// (`FUN_004e1170`/`FUN_004e1430`) refuse to connect to a full
        /// server, comparing `currentPlayers < maxCapacity` for "has room";
        /// `utilization`/`capacity` are those two fields.
        public var isFull: Bool { utilization >= capacity }

        /// Whether this server can actually be connected to right now — the
        /// online-and-not-full check the client's connect path performs
        /// before opening a socket.
        public var isJoinable: Bool { isEnabled && !isFull }
    }
}

extension ServerDirectoryResponse.Server {

    // Wire format confirmed field-by-field in GunBound-Decomp
    // (PROTOCOL.md, opcode 0x1102, from a full Ghidra decompile of
    // State02_ServerSelect_ProcessPacket's parse loop):
    //
    //   u16  serverId
    //   u8   regionOrType     (client forces to 3 when offline)
    //   u8   nameLen; char name[nameLen]     (not NUL-terminated on wire)
    //   u8   descLen; char desc[descLen]     (not NUL-terminated on wire)
    //   u32  serverIp          (packed IPv4 a.b.c.d — confirmed: sprintf'd
    //                           "%d.%d.%d.%d" and fed to the connect helper)
    //   u16  port              (htons/big-endian)
    //   u16  unknownField2     (raw copy, not yet identified)
    //   u16  currentPlayers    (the "is server full" check compares this…
    //   u16  maxCapacity       (…against this, in both button handlers)
    //   u8   onlineFlag        (0 = offline)
    //
    // Our field names map: address = serverIp, utilization = currentPlayers,
    // capacity = maxCapacity, isEnabled = onlineFlag. serverId/regionOrType
    // aren't surfaced yet (only opcode 0x2001's confirm-connect reads
    // serverId back out, which this client doesn't implement), so they're
    // parsed and dropped. Note the real client auto-connects to the first
    // entry with onlineFlag set — the same choice ServerSelectViewModel
    // makes via `directory.first(where: \.isEnabled)`.
    public init(parsing input: inout ParserSpan) throws {
        _ = try UInt16(parsingLittleEndian: &input)  // serverId
        _ = try UInt8(parsing: &input)               // regionOrType
        self.name = try String(parsingLengthPrefixedASCII: &input)
        self.descriptionText = try String(parsingLengthPrefixedASCII: &input)
        self.address = try IPv4Address(parsing: &input)
        self.port = try UInt16(parsingBigEndian: &input)
        _ = try UInt16(parsingBigEndian: &input)  // unknownField2
        self.utilization = try UInt16(parsingBigEndian: &input)  // currentPlayers
        self.capacity = try UInt16(parsingBigEndian: &input)     // maxCapacity
        self.isEnabled = try UInt8(parsing: &input) != 0         // onlineFlag
    }
}

extension ServerDirectoryResponse {

    public init(parsing input: inout ParserSpan) throws {
        // unknown
        _ = try UInt8(parsing: &input)
        _ = try UInt8(parsing: &input)
        _ = try UInt8(parsing: &input)

        // number of servers
        let count = try UInt8(parsing: &input)

        // decode each
        var directory = [Server]()
        directory.reserveCapacity(Int(count))
        for _ in 0..<count {
            directory.append(try Server(parsing: &input))
        }
        self.directory = directory
    }

    public func encode(to output: inout ByteWriter) {
        // unknown
        output.write(UInt8(0x00))
        output.write(UInt8(0x00))
        output.write(UInt8(0x01))

        // number of servers
        output.write(UInt8(directory.count))

        // encode each — see the field-by-field wire format documented on
        // `Server.init(parsing:)`. serverId is written as the entry index
        // (u16, low byte first) and regionOrType as 0; the unidentified
        // `unknownField2` slot is filled with the same value as
        // currentPlayers (our server has no distinct value for it, and this
        // reproduces the real captured fixtures byte-for-byte).
        for (index, server) in directory.enumerated() {
            output.write(UInt8(index))  // serverId (u16, LE low byte)
            output.write(UInt8(0x00))   // serverId high byte
            output.write(UInt8(0x00))   // regionOrType
            output.writeLengthPrefixed(ascii: server.name)
            output.writeLengthPrefixed(ascii: server.descriptionText)
            server.address.encode(to: &output)
            output.write(server.port, endianness: .big)
            output.write(server.utilization, endianness: .big)  // unknownField2
            output.write(server.utilization, endianness: .big)  // currentPlayers
            output.write(server.capacity, endianness: .big)     // maxCapacity
            output.write(server.isEnabled)                      // onlineFlag
        }
    }
}
