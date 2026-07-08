import GunBoundProtocol

/// Fetches the list of available world servers from a broker/directory
/// server — abstracted purely so `ServerSelectViewModel` can be tested
/// against canned/mocked data instead of opening a real TCP connection.
public protocol ServerDirectoryFetching: Sendable {
    func fetchServerDirectory(address: String, brokerPort: UInt16) async throws -> [ServerDirectoryResponse.Server]
}

/// Default production implementation — opens a real TCP connection via
/// `NetworkClient<GunBoundSocketIPv4TCP>`.
public struct LiveServerDirectoryFetcher: ServerDirectoryFetching {
    public init() {}

    public func fetchServerDirectory(address: String, brokerPort: UInt16) async throws -> [ServerDirectoryResponse.Server] {
        try await NetworkClient<GunBoundSocketIPv4TCP>.fetchServerDirectory(address: address, brokerPort: brokerPort)
    }
}
