import Foundation

/// Login credentials and server address supplied on the command line (a
/// settings-file-based alternative can replace this later — see
/// `GunBoundClient`'s `--username`/`--password`/`--server` options). Not
/// wired to any actual connection yet; this just carries the values through
/// to wherever the login/authentication flow is implemented.
public struct NetworkConfig: Equatable, Sendable {
    public var username: String
    public var password: String
    public var serverAddress: String
    public var serverPort: UInt16

    public init(username: String, password: String, serverAddress: String, serverPort: UInt16) {
        self.username = username
        self.password = password
        self.serverAddress = serverAddress
        self.serverPort = serverPort
    }
}
