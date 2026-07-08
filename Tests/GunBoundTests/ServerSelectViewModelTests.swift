import Foundation
import Testing
@testable import GunBound
@testable import GunBoundProtocol

/// A fake `ViewModelDelegate` that just records what the view model does
/// with it, instead of a real SDL-backed `ClientContext`.
@MainActor
final class MockViewModelDelegate: ViewModelDelegate {
    let network: NetworkConfig
    var client: NetworkClient<GunBoundSocketIPv4TCP>?
    private(set) var requestedTransitions: [ClientMode] = []

    init(network: NetworkConfig) {
        self.network = network
    }

    func requestTransition(to mode: ClientMode) {
        requestedTransitions.append(mode)
    }
}

/// A fake `ServerDirectoryFetching` that just hands back a canned
/// directory instead of opening a real TCP connection to a broker.
struct MockServerDirectoryFetcher: ServerDirectoryFetching {
    let servers: [ServerDirectoryResponse.Server]

    func fetchServerDirectory(address: String, brokerPort: UInt16) async throws -> [ServerDirectoryResponse.Server] {
        servers
    }
}

@Suite @MainActor
struct ServerSelectViewModelTests {

    /// Same real `ServerDirectoryResponse` packet bytes `GunBoundTests`
    /// validates the wire format against (a broker listing 5 world
    /// servers) — reused here as the "mocked TCP data" a
    /// `ServerDirectoryFetching` implementation would otherwise have read
    /// off a real socket, to prove `ServerSelectViewModel` correctly turns
    /// a server-directory response into its `availableServers` list.
    static let serverDirectoryResponseData: [UInt8] = [
        0x18, 0x01, 0xbb, 0x08, 0x02, 0x11, 0x00, 0x00, 0x01, 0x05, 0x00, 0x00, 0x00, 0x0e, 0x4a, 0x47, 0x20, 0x54, 0x65, 0x73, 0x74, 0x20, 0x42, 0x72, 0x6f, 0x6b, 0x65, 0x72, 0x1e, 0x42,
        0x72, 0x6f, 0x6b, 0x65, 0x72, 0x20, 0x64, 0x65, 0x73, 0x63, 0x72, 0x69, 0x70, 0x74, 0x69, 0x6f, 0x6e, 0x5c, 0x6e, 0x20, 0x67, 0x6f, 0x65, 0x73, 0x20, 0x68, 0x65, 0x72, 0x65, 0xc0,
        0xa8, 0x01, 0x01, 0x20, 0xb2, 0x00, 0x00, 0x00, 0x00, 0x00, 0x64, 0x01, 0x01, 0x00, 0x00, 0x09, 0x46, 0x72, 0x65, 0x65, 0x20, 0x50, 0x6c, 0x61, 0x79, 0x16, 0x52, 0x6f, 0x6f, 0x6b,
        0x69, 0x65, 0x20, 0x5a, 0x6f, 0x6e, 0x65, 0x5c, 0x6e, 0x41, 0x76, 0x61, 0x74, 0x61, 0x72, 0x20, 0x4f, 0x4e, 0xc0, 0xa8, 0x01, 0x01, 0x20, 0xa9, 0x00, 0x32, 0x00, 0x32, 0x00, 0x64,
        0x01, 0x02, 0x00, 0x00, 0x0f, 0x44, 0x69, 0x73, 0x61, 0x62, 0x6c, 0x65, 0x64, 0x20, 0x53, 0x65, 0x72, 0x76, 0x65, 0x72, 0x16, 0x52, 0x6f, 0x6f, 0x6b, 0x69, 0x65, 0x20, 0x5a, 0x6f,
        0x6e, 0x65, 0x5c, 0x6e, 0x41, 0x76, 0x61, 0x74, 0x61, 0x72, 0x20, 0x4f, 0x4e, 0xc0, 0xa8, 0x01, 0x01, 0x20, 0xaa, 0x00, 0x32, 0x00, 0x32, 0x00, 0x64, 0x00, 0x03, 0x00, 0x00, 0x0b,
        0x46, 0x75, 0x6c, 0x6c, 0x20, 0x53, 0x65, 0x72, 0x76, 0x65, 0x72, 0x16, 0x52, 0x6f, 0x6f, 0x6b, 0x69, 0x65, 0x20, 0x5a, 0x6f, 0x6e, 0x65, 0x5c, 0x6e, 0x41, 0x76, 0x61, 0x74, 0x61,
        0x72, 0x20, 0x4f, 0x4e, 0xc0, 0xa8, 0x01, 0x01, 0x20, 0xab, 0x00, 0x64, 0x00, 0x64, 0x00, 0x64, 0x01, 0x04, 0x00, 0x00, 0x0f, 0x4c, 0x6f, 0x6f, 0x70, 0x62, 0x61, 0x63, 0x6b, 0x20,
        0x53, 0x65, 0x72, 0x76, 0x65, 0x72, 0x14, 0x6c, 0x6f, 0x63, 0x61, 0x6c, 0x68, 0x6f, 0x73, 0x74, 0x5c, 0x6e, 0x50, 0x6f, 0x72, 0x74, 0x20, 0x38, 0x33, 0x37, 0x30, 0x7f, 0x00, 0x00,
        0x01, 0x20, 0xb2, 0x00, 0x00, 0x00, 0x00, 0x00, 0x64, 0x01
    ]

    /// Decodes `serverDirectoryResponseData` exactly as `NetworkClient`
    /// would off a real socket (`GunBoundDecoder.decode(_:from:)`), so the
    /// mock fetcher below hands the view model the same
    /// `[ServerDirectoryResponse.Server]` a real broker round-trip would.
    static func decodedServerDirectory() throws -> [ServerDirectoryResponse.Server] {
        let packet = try #require(Packet(data: serverDirectoryResponseData))
        let response = try GunBoundDecoder().decode(ServerDirectoryResponse.self, from: packet)
        return response.directory
    }

    @Test func fetchDirectoryPopulatesAvailableServerTitles() async throws {
        let servers = try Self.decodedServerDirectory()
        #expect(servers.count == 5)

        let fetcher = MockServerDirectoryFetcher(servers: servers)
        let network = NetworkConfig(username: "admin", password: "1234", serverAddress: "127.0.0.1", serverPort: 8370, brokerPort: 8372)
        let delegate = MockViewModelDelegate(network: network)
        let viewModel = ServerSelectViewModel(delegate: delegate, directoryFetcher: fetcher)

        #expect(viewModel.availableServers.isEmpty)

        _ = await viewModel.fetchDirectoryAndChooseServer()

        #expect(viewModel.availableServers.map(\.name) == [
            "JG Test Broker",
            "Free Play",
            "Disabled Server",
            "Full Server",
            "Loopback Server",
        ])
        #expect(viewModel.availableServers.map(\.isEnabled) == [true, true, false, true, true])
    }

    @Test func fetchDirectoryChoosesFirstEnabledServer() async throws {
        let servers = try Self.decodedServerDirectory()
        let fetcher = MockServerDirectoryFetcher(servers: servers)
        let network = NetworkConfig(username: "admin", password: "1234", serverAddress: "127.0.0.1", serverPort: 8370, brokerPort: 8372)
        let delegate = MockViewModelDelegate(network: network)
        let viewModel = ServerSelectViewModel(delegate: delegate, directoryFetcher: fetcher)

        let chosen = await viewModel.fetchDirectoryAndChooseServer()

        // "JG Test Broker" is the first enabled entry in the fixture.
        #expect(chosen.address == "192.168.1.1")
        #expect(chosen.port == 8370)
    }

    @Test func fetchDirectoryFallsBackToConfiguredServerWhenBrokerUnreachable() async throws {
        struct FailingFetcher: ServerDirectoryFetching {
            struct Failure: Error {}
            func fetchServerDirectory(address: String, brokerPort: UInt16) async throws -> [ServerDirectoryResponse.Server] {
                throw Failure()
            }
        }

        let network = NetworkConfig(username: "admin", password: "1234", serverAddress: "203.0.113.1", serverPort: 9999, brokerPort: 8372)
        let delegate = MockViewModelDelegate(network: network)
        let viewModel = ServerSelectViewModel(delegate: delegate, directoryFetcher: FailingFetcher())

        let chosen = await viewModel.fetchDirectoryAndChooseServer()

        #expect(viewModel.availableServers.isEmpty)
        #expect(chosen.address == "203.0.113.1")
        #expect(chosen.port == 9999)
    }
}
