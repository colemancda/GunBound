import Foundation
import Testing
@testable import GunBound
@testable import GunBoundProtocol

/// An in-memory `GunBoundSocketTCP` that records what was written and replays
/// a queue of canned response packets — no real file descriptor is opened, so
/// (unlike a raw socket) this is safe to drive directly inside the test
/// harness. Responses are handed to the static factory via `queuedResponses`
/// because `NetworkClient` can only be constructed through `.connect(_:)`,
/// which calls `Socket.client(address:destination:)`.
final class MockGunBoundSocket: GunBoundSocketTCP, @unchecked Sendable {

    /// Response payloads (`Packet.data`) the next `MockGunBoundSocket.client`
    /// should replay, in order, one per `recieve(_:)` call.
    nonisolated(unsafe) static var queuedResponses: [[UInt8]] = []

    let address: GunBound.GunBoundAddress
    private let responses: [[UInt8]]
    private var responseIndex = 0
    private(set) var sentPackets: [[UInt8]] = []

    init(address: GunBound.GunBoundAddress, responses: [[UInt8]]) {
        self.address = address
        self.responses = responses
    }

    var event: GunBoundSocketEventStream {
        GunBoundSocketEventStream { $0.finish() }
    }

    func send(_ data: Data) async throws {
        sentPackets.append([UInt8](data))
    }

    func recieve(_ bufferSize: Int) async throws -> Data {
        defer { responseIndex += 1 }
        guard responseIndex < responses.count else { return Data() }
        return Data(responses[responseIndex])
    }

    func accept() async throws -> Self { self }
    func close() async {}

    static func client(address: GunBound.GunBoundAddress, destination: GunBound.GunBoundAddress) async throws -> Self {
        Self(address: address, responses: queuedResponses)
    }

    static func server(address: GunBound.GunBoundAddress, backlog: Int) async throws -> Self {
        Self(address: address, responses: [])
    }
}

@Suite
struct ConfirmConnectTests {

    /// A zero-status `JoinChannelResponse` is the "connection accepted"
    /// acknowledgement (opcode `0x2001`, State 2's confirm-connect) — a
    /// non-zero status is a rejection.
    @Test func joinChannelResponseSuccessStatus() {
        #expect(JoinChannelResponse(status: 0x0000, channel: 2, maxPosition: 0, users: []).isSuccess)
        #expect(!JoinChannelResponse(status: 0x0001, channel: 2, maxPosition: 0, users: []).isSuccess)
    }

    /// `NetworkClient.joinChannel()` sends a `JoinChannelRequest` and decodes
    /// the server's `0x2001` acknowledgement — the confirm-connect handshake,
    /// exercised end-to-end over a canned in-memory socket.
    @Test func joinChannelSendsRequestAndDecodesAck() async throws {
        let ack = JoinChannelResponse(
            status: 0x0000,
            channel: 2,
            maxPosition: 0,
            users: [
                JoinChannelResponse.ChannelUser(
                    id: 1,
                    username: "player",
                    avatarEquipped: 0,
                    guild: "",
                    rankCurrent: 20,
                    rankSeason: 20
                )
            ]
        )
        MockGunBoundSocket.queuedResponses = [GunBoundEncoder().encode(ack, id: 0x0000).data]

        let config = NetworkConfig(username: "player", password: "1234", serverAddress: "127.0.0.1", serverPort: 8370, brokerPort: 8372)
        let client = try await NetworkClient<MockGunBoundSocket>.connect(config)
        let response = try await client.joinChannel(0xFFFF)

        #expect(response.isSuccess)
        #expect(response.channel == 2)
        #expect(response.users.map(\.username) == ["player"])
    }

    /// A non-zero status comes back as `isSuccess == false`, which the view
    /// model uses to refuse the transition into the Game Room List.
    @Test func joinChannelSurfacesRejection() async throws {
        let rejection = JoinChannelResponse(status: 0x0001, channel: 0, maxPosition: 0, users: [])
        MockGunBoundSocket.queuedResponses = [GunBoundEncoder().encode(rejection, id: 0x0000).data]

        let config = NetworkConfig(username: "player", password: "1234", serverAddress: "127.0.0.1", serverPort: 8370, brokerPort: 8372)
        let client = try await NetworkClient<MockGunBoundSocket>.connect(config)
        let response = try await client.joinChannel()

        #expect(!response.isSuccess)
    }
}
