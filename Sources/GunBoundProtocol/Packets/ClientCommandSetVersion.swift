/// Client Command Set Version (`SVC_CMD_SETVERSION`)
///
/// Sent by the server to push the accepted client version range
/// (mirrors `InMemoryGunBoundServerDataSource.State.versionFirst`/`versionLast`).
///
/// **Note:** This is a best-effort reconstruction from the opcode name alone.
public struct ClientCommandSetVersion: GunBoundPacket, GunBoundPacketEncodable, GunBoundPacketDecodable, Equatable, Hashable, Sendable {

    public static var opcode: Opcode { .clientCommandSetVersion }

    public let versionFirst: ClientVersion

    public let versionLast: ClientVersion

    public init(versionFirst: ClientVersion, versionLast: ClientVersion) {
        self.versionFirst = versionFirst
        self.versionLast = versionLast
    }

    public init(parsing input: inout ParserSpan) throws(ParsingError) {
        self.versionFirst = try ClientVersion(parsing: &input)
        self.versionLast = try ClientVersion(parsing: &input)
    }

    public func encode(to output: inout ByteWriter) {
        versionFirst.encode(to: &output)
        versionLast.encode(to: &output)
    }
}
