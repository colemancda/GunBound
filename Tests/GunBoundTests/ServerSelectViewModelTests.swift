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
    let session = ClientSession()
    private(set) var requestedTransitions: [ClientMode] = []
    private(set) var quitRequested = false

    init(network: NetworkConfig) {
        self.network = network
    }

    func requestTransition(to mode: ClientMode) {
        requestedTransitions.append(mode)
    }

    func requestQuit() {
        quitRequested = true
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

    @Test func fetchDirectoryCapsAtSixteenServers() async throws {
        // The client stores a fixed-size 16-entry structure-of-arrays, so a
        // broker returning more than 16 servers has the overflow dropped.
        let template = try #require(try Self.decodedServerDirectory().first)
        let oversized = (0..<20).map { index in
            ServerDirectoryResponse.Server(
                name: "Server \(index)",
                descriptionText: template.descriptionText,
                address: template.address,
                port: template.port,
                utilization: template.utilization,
                capacity: template.capacity,
                isEnabled: true
            )
        }

        let fetcher = MockServerDirectoryFetcher(servers: oversized)
        let network = NetworkConfig(username: "admin", password: "1234", serverAddress: "127.0.0.1", serverPort: 8370, brokerPort: 8372)
        let delegate = MockViewModelDelegate(network: network)
        let viewModel = ServerSelectViewModel(delegate: delegate, directoryFetcher: fetcher)

        _ = await viewModel.fetchDirectoryAndChooseServer()

        #expect(viewModel.availableServers.count == ServerSelectViewModel.maxServers)
        #expect(viewModel.availableServers.map(\.name) == (0..<16).map { "Server \($0)" })
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

    @Test func fetchDirectorySkipsFullServers() async throws {
        // The client's connect path validates the target is online AND not
        // full before opening a socket, so an enabled-but-full server (like
        // the fixture's "Full Server", utilization == capacity) can't be the
        // chosen one — the first *joinable* server is.
        let template = try #require(try Self.decodedServerDirectory().first)
        func server(name: String, port: UInt16, utilization: UInt16, capacity: UInt16, isEnabled: Bool) -> ServerDirectoryResponse.Server {
            ServerDirectoryResponse.Server(
                name: name,
                descriptionText: template.descriptionText,
                address: template.address,
                port: port,
                utilization: utilization,
                capacity: capacity,
                isEnabled: isEnabled
            )
        }
        let servers = [
            server(name: "Offline", port: 1, utilization: 0, capacity: 100, isEnabled: false),
            server(name: "Full", port: 2, utilization: 100, capacity: 100, isEnabled: true),
            server(name: "Joinable", port: 3, utilization: 50, capacity: 100, isEnabled: true),
        ]

        let network = NetworkConfig(username: "admin", password: "1234", serverAddress: "127.0.0.1", serverPort: 8370, brokerPort: 8372)
        let delegate = MockViewModelDelegate(network: network)
        let viewModel = ServerSelectViewModel(delegate: delegate, directoryFetcher: MockServerDirectoryFetcher(servers: servers))

        let chosen = await viewModel.fetchDirectoryAndChooseServer()

        #expect(chosen.port == 3)  // "Joinable", not "Offline" or "Full"
    }

    /// The wire `serverId` is surfaced as `id` — the row number the world
    /// list draws is `id + 1`.
    @Test func decodesServerIds() throws {
        let servers = try Self.decodedServerDirectory()
        #expect(servers.map(\.id) == [0, 1, 2, 3, 4])
    }

    /// Rows lay out 2-across with the decomp-confirmed pitch: x = (i%2)·247
    /// + 22 + panelX, y = (i/2)·73 + 45 + panelY, 181×65 backgrounds.
    @Test func worldListRowGeometry() {
        let network = NetworkConfig(username: "admin", password: "1234", serverAddress: "127.0.0.1", serverPort: 8370, brokerPort: 8372)
        let viewModel = ServerSelectViewModel(delegate: MockViewModelDelegate(network: network))
        viewModel.panelRect = Rect(x: 11, y: 13, width: 546, height: 530)

        #expect(viewModel.rowRect(at: 0) == Rect(x: 33, y: 58, width: 181, height: 65))
        #expect(viewModel.rowRect(at: 1) == Rect(x: 280, y: 58, width: 181, height: 65))
        #expect(viewModel.rowRect(at: 2) == Rect(x: 33, y: 131, width: 181, height: 65))
        // Gauge sits flush against the row background's right edge.
        #expect(viewModel.gaugeRect(at: 0).x == 33 + 181)
    }

    /// Clicking a row selects it — but only online rows, mirroring
    /// `WorldListRowHitTest` (fullness is only checked at connect time).
    @Test func rowClickSelectsOnlineRowsOnly() async throws {
        let servers = try Self.decodedServerDirectory()
        let network = NetworkConfig(username: "admin", password: "1234", serverAddress: "127.0.0.1", serverPort: 8370, brokerPort: 8372)
        let delegate = MockViewModelDelegate(network: network)
        let viewModel = ServerSelectViewModel(delegate: delegate, directoryFetcher: MockServerDirectoryFetcher(servers: servers))
        viewModel.panelRect = Rect(x: 11, y: 13, width: 546, height: 530)
        _ = await viewModel.fetchDirectoryAndChooseServer()

        #expect(viewModel.selectedIndex == nil)

        // Click the center of row 1 ("Free Play", online).
        let row1 = viewModel.rowRect(at: 1)
        viewModel.handle(.pointerDown(x: row1.x + row1.width / 2, y: row1.y + row1.height / 2))
        #expect(viewModel.selectedIndex == 1)

        // Clicking row 2 ("Disabled Server", offline) leaves the selection.
        let row2 = viewModel.rowRect(at: 2)
        viewModel.handle(.pointerDown(x: row2.x + 5, y: row2.y + 5))
        #expect(viewModel.selectedIndex == 1)
    }

    /// Enter (`.activate`) with nothing selected auto-selects the first
    /// online server and connects, mirroring the decomp keydown handler.
    @Test func enterKeyAutoSelectsFirstOnlineServer() async throws {
        let servers = try Self.decodedServerDirectory()
        let network = NetworkConfig(username: "admin", password: "1234", serverAddress: "127.0.0.1", serverPort: 8370, brokerPort: 8372)
        let delegate = MockViewModelDelegate(network: network)
        let viewModel = ServerSelectViewModel(delegate: delegate, directoryFetcher: MockServerDirectoryFetcher(servers: servers))
        viewModel.panelRect = Rect(x: 11, y: 13, width: 546, height: 530)
        _ = await viewModel.fetchDirectoryAndChooseServer()

        #expect(viewModel.selectedIndex == nil)
        // The first server ("JG Test Broker") is enabled, so Enter picks it.
        viewModel.handle(.activate)
        #expect(viewModel.selectedIndex == 0)
    }

    /// The SERVER button connects to the clicked row; a full selection (or
    /// none) falls back to the first joinable server — the Enter-key
    /// auto-select.
    @Test func connectHonorsSelectedRow() async throws {
        let servers = try Self.decodedServerDirectory()
        let network = NetworkConfig(username: "admin", password: "1234", serverAddress: "127.0.0.1", serverPort: 9999, brokerPort: 8372)
        let delegate = MockViewModelDelegate(network: network)
        let viewModel = ServerSelectViewModel(delegate: delegate, directoryFetcher: MockServerDirectoryFetcher(servers: servers))
        viewModel.panelRect = Rect(x: 11, y: 13, width: 546, height: 530)
        _ = await viewModel.fetchDirectoryAndChooseServer()

        // Select "Free Play" (row 1, port 8361) and connect.
        let row1 = viewModel.rowRect(at: 1)
        viewModel.handle(.pointerDown(x: row1.x + 5, y: row1.y + 5))
        let chosen = await viewModel.fetchDirectoryAndChooseServer()
        #expect(chosen.port == 8361)

        // Select "Full Server" (row 3, enabled but full): connect falls back
        // to the first joinable ("JG Test Broker", port 8370).
        let row3 = viewModel.rowRect(at: 3)
        viewModel.handle(.pointerDown(x: row3.x + 5, y: row3.y + 5))
        #expect(viewModel.selectedIndex == 3)
        let fallback = await viewModel.fetchDirectoryAndChooseServer()
        #expect(fallback.port == 8370)
    }

    /// The SERVER button stays disabled until a row is selected: clicking
    /// it with no selection does nothing, one row click arms it, and then
    /// it connects.
    @Test func serverButtonRequiresASelection() async throws {
        let servers = try Self.decodedServerDirectory()
        let network = NetworkConfig(username: "admin", password: "1234", serverAddress: "127.0.0.1", serverPort: 9999, brokerPort: 8372)
        let delegate = MockViewModelDelegate(network: network)
        let viewModel = ServerSelectViewModel(delegate: delegate, directoryFetcher: MockServerDirectoryFetcher(servers: servers))
        viewModel.panelRect = Rect(x: 11, y: 13, width: 546, height: 530)
        _ = await viewModel.fetchDirectoryAndChooseServer()

        let serverButton = try #require(viewModel.buttons.first { $0.name == "b_server_choiceserver.img" })
        #expect(!viewModel.isConnectEnabled)
        viewModel.handle(.pointerDown(x: serverButton.rect.x + 5, y: serverButton.rect.y + 5))
        #expect(!viewModel.state.isConnecting)  // disabled: nothing happened

        // Selecting a row arms the button; clicking it now connects.
        let row1 = viewModel.rowRect(at: 1)
        viewModel.handle(.pointerDown(x: row1.x + 5, y: row1.y + 5))
        #expect(viewModel.isConnectEnabled)
        viewModel.handle(.pointerDown(x: serverButton.rect.x + 5, y: serverButton.rect.y + 5))
        #expect(viewModel.state.isConnecting)
    }

    /// Double-clicking the selected row connects; a slow second click
    /// (outside the window) just keeps the selection.
    @Test func doubleClickingTheSelectedRowConnects() async throws {
        let servers = try Self.decodedServerDirectory()
        let network = NetworkConfig(username: "admin", password: "1234", serverAddress: "127.0.0.1", serverPort: 9999, brokerPort: 8372)
        let delegate = MockViewModelDelegate(network: network)
        let viewModel = ServerSelectViewModel(delegate: delegate, directoryFetcher: MockServerDirectoryFetcher(servers: servers))
        viewModel.panelRect = Rect(x: 11, y: 13, width: 546, height: 530)
        _ = await viewModel.fetchDirectoryAndChooseServer()

        let row1 = viewModel.rowRect(at: 1)
        // A slow pair: select, wait past the window, click again — still
        // just selected.
        viewModel.handle(.pointerDown(x: row1.x + 5, y: row1.y + 5))
        viewModel.update(deltaTime: ServerSelectViewModel.doubleClickInterval + 0.1)
        viewModel.handle(.pointerDown(x: row1.x + 5, y: row1.y + 5))
        #expect(viewModel.selectedIndex == 1)
        #expect(!viewModel.state.isConnecting)

        // A quick second click inside the window connects.
        viewModel.update(deltaTime: 0.1)
        viewModel.handle(.pointerDown(x: row1.x + 5, y: row1.y + 5))
        #expect(viewModel.state.isConnecting)
    }

    /// The error dialog's OK button quits the client — the same action as
    /// the EXIT button — since the failed connection is already torn down.
    @Test func errorDialogConfirmQuits() async throws {
        let servers = try Self.decodedServerDirectory()
        let network = NetworkConfig(username: "admin", password: "1234", serverAddress: "127.0.0.1", serverPort: 8370, brokerPort: 8372)
        let delegate = MockViewModelDelegate(network: network)
        let viewModel = ServerSelectViewModel(delegate: delegate, directoryFetcher: MockServerDirectoryFetcher(servers: servers))
        _ = await viewModel.fetchDirectoryAndChooseServer()

        #expect(!delegate.quitRequested)
        viewModel.confirmError()
        #expect(delegate.quitRequested)
    }

    /// Network errors map to the localized dialog the original would show —
    /// a request timeout is "access time expired" (id 201), everything else
    /// is "server access error" (id 200) — never the raw error text.
    @Test func networkErrorsMapToLocalizedDialogs() {
        let timeout = NetworkClient<GunBoundSocketIPv4TCP>.Error.timeout(.joinChannelResponse)
        #expect(ServerSelectViewModel.dialogMessage(for: timeout) == .accessTimeExpired)

        let refused = NetworkClient<GunBoundSocketIPv4TCP>.Error.disconnected
        #expect(ServerSelectViewModel.dialogMessage(for: refused) == .serverAccessError)

        struct SomeOtherError: Error {}
        #expect(ServerSelectViewModel.dialogMessage(for: SomeOtherError()) == .serverAccessError)
    }

    /// Scrolling slides a 12-slot window over the fetched list one grid
    /// line (two servers) at a time, and row clicks select the *absolute*
    /// entry under the slot.
    @Test func scrollWindowsTheVisibleServersAndMapsSelection() async throws {
        let template = try #require(try Self.decodedServerDirectory().first)
        let servers = (0..<16).map { index in
            ServerDirectoryResponse.Server(
                id: UInt16(index), name: "Server \(index)", descriptionText: "", address: template.address,
                port: UInt16(9000 + index), utilization: 0, capacity: 100, isEnabled: true
            )
        }
        let network = NetworkConfig(username: "admin", password: "1234", serverAddress: "127.0.0.1", serverPort: 8370, brokerPort: 8372)
        let delegate = MockViewModelDelegate(network: network)
        let viewModel = ServerSelectViewModel(delegate: delegate, directoryFetcher: MockServerDirectoryFetcher(servers: servers))
        viewModel.panelRect = Rect(x: 11, y: 13, width: 546, height: 530)
        _ = await viewModel.fetchDirectoryAndChooseServer()

        // 16 servers = 8 grid lines; 6 lines visible → 2 scrollable lines.
        #expect(viewModel.lineCount == 8)
        #expect(viewModel.maxScrollOffset == 2)
        #expect(viewModel.visibleServers.first?.id == 0)
        #expect(viewModel.visibleServers.count == 12)

        viewModel.setScrollOffset(1)
        #expect(viewModel.visibleServers.first?.id == 2)

        // Clicking the top-left slot now selects entry 2, not entry 0.
        let slot0 = viewModel.rowRect(at: 0)
        viewModel.handle(.pointerDown(x: slot0.x + 5, y: slot0.y + 5))
        #expect(viewModel.selectedIndex == 2)

        // The wheel over the panel steps the window too (positive = down).
        viewModel.handle(.scroll(x: 100, y: 100, steps: 1))
        #expect(viewModel.scrollOffset == 2)
        viewModel.handle(.scroll(x: 100, y: 100, steps: -2))
        #expect(viewModel.scrollOffset == 0)
        // A wheel outside the panel is ignored.
        viewModel.handle(.scroll(x: 700, y: 580, steps: 1))
        #expect(viewModel.scrollOffset == 0)
        viewModel.setScrollOffset(1)

        // Clamped at both ends.
        viewModel.setScrollOffset(99)
        #expect(viewModel.scrollOffset == 2)
        #expect(viewModel.visibleServers.first?.id == 4)
        viewModel.setScrollOffset(-1)
        #expect(viewModel.scrollOffset == 0)
    }

    /// The BUDDY bottom-bar button toggles the shared buddy panel.
    @Test func buddyButtonTogglesThePanel() async throws {
        let servers = try Self.decodedServerDirectory()
        let network = NetworkConfig(username: "admin", password: "1234", serverAddress: "127.0.0.1", serverPort: 8370, brokerPort: 8372)
        let delegate = MockViewModelDelegate(network: network)
        let viewModel = ServerSelectViewModel(delegate: delegate, directoryFetcher: MockServerDirectoryFetcher(servers: servers))
        viewModel.panelRect = Rect(x: 11, y: 13, width: 546, height: 530)
        _ = await viewModel.fetchDirectoryAndChooseServer()

        #expect(!viewModel.isBuddyPanelVisible)
        let buddy = try #require(viewModel.buttons.first { $0.name == "b_server_buddygame.img" })
        viewModel.handle(.pointerDown(x: buddy.rect.x + 5, y: buddy.rect.y + 5))
        #expect(viewModel.isBuddyPanelVisible)
        viewModel.handle(.pointerDown(x: buddy.rect.x + 5, y: buddy.rect.y + 5))
        #expect(!viewModel.isBuddyPanelVisible)

        viewModel.setBuddyPanelVisible(true)
        viewModel.dismissBuddyPanel()
        #expect(!viewModel.isBuddyPanelVisible)
    }

    /// Population gauge levels: currentPlayers·100/maxCapacity in five 20%
    /// buckets.
    @Test func populationGaugeLevels() {
        let network = NetworkConfig(username: "admin", password: "1234", serverAddress: "127.0.0.1", serverPort: 8370, brokerPort: 8372)
        let viewModel = ServerSelectViewModel(delegate: MockViewModelDelegate(network: network))
        func server(_ players: UInt16, of capacity: UInt16) -> ServerDirectoryResponse.Server {
            ServerDirectoryResponse.Server(name: "", descriptionText: "", address: IPv4Address(127, 0, 0, 1), port: 0, utilization: players, capacity: capacity, isEnabled: true)
        }
        #expect(viewModel.populationLevel(of: server(0, of: 100)) == 0)
        #expect(viewModel.populationLevel(of: server(39, of: 100)) == 1)
        #expect(viewModel.populationLevel(of: server(50, of: 100)) == 2)
        #expect(viewModel.populationLevel(of: server(80, of: 100)) == 4)
        #expect(viewModel.populationLevel(of: server(100, of: 100)) == 4)
        #expect(viewModel.populationLevel(of: server(0, of: 0)) == 4)  // no capacity = full
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
