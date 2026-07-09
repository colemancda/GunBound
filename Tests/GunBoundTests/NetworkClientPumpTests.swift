import Foundation
import Testing
@testable import GunBound
@testable import GunBoundProtocol

/// The inbound packet pump: the background read loop that reassembles
/// packets off the byte stream, resolves waiting `request()` calls, delivers
/// notifications on `pushes`, and parks early replies in the mailbox.
/// Serialized for the same reason as `ConfirmConnectTests` — the mock
/// socket's canned responses are shared static state.
@Suite(.serialized)
struct NetworkClientPumpTests {

    private static let config = NetworkConfig(
        username: "player", password: "1234",
        serverAddress: "127.0.0.1", serverPort: 8370, brokerPort: 8372
    )

    private static func encode<T: GunBoundPacketEncodable>(_ value: T) -> [UInt8] {
        GunBoundEncoder().encode(value, id: 0x0000).data
    }

    private static let channelAck = JoinChannelResponse(status: 0, channel: 1, maxPosition: 0, users: [])

    /// A notification interleaved *before* the awaited reply still reaches
    /// `pushes`, and the request resolves on its own opcode regardless of
    /// arrival order.
    @Test func notificationsRouteAroundPendingRequests() async throws {
        MockGunBoundSocket.queuedResponses = [
            Self.encode(RoomUpdateNotification()),           // push first...
            Self.encode(Self.channelAck),                    // ...then the reply
            Self.encode(RoomPlayerLeftNotification(playerID: 7)),
        ]
        let client = try await NetworkClient<MockGunBoundSocket>.connect(Self.config)

        let response = try await client.joinChannel()
        #expect(response.isSuccess)

        var received: [ServerPush] = []
        for await push in await client.pushes {
            received.append(push)
        }
        #expect(received == [
            .roomUpdated(RoomUpdateNotification()),
            .roomPlayerLeft(RoomPlayerLeftNotification(playerID: 7)),
        ])
    }

    /// Two packets coalesced into one TCP read are both extracted, and a
    /// packet split across two reads is reassembled.
    @Test func reassemblyHandlesCoalescedAndSplitPackets() async throws {
        let ack = Self.encode(Self.channelAck)
        let push = Self.encode(RoomPlayerLeftNotification(playerID: 3))
        // One blob holding both packets, then a packet cut in half.
        let second = Self.encode(RoomUpdateNotification())
        MockGunBoundSocket.queuedResponses = [
            ack + push,
            Array(second[0..<3]),
            Array(second[3...]),
        ]
        let client = try await NetworkClient<MockGunBoundSocket>.connect(Self.config)

        let response = try await client.joinChannel()
        #expect(response.isSuccess)

        var received: [ServerPush] = []
        for await pushValue in await client.pushes {
            received.append(pushValue)
        }
        #expect(received == [
            .roomPlayerLeft(RoomPlayerLeftNotification(playerID: 3)),
            .roomUpdated(RoomUpdateNotification()),
        ])
    }

    /// A request whose reply never comes fails with `.disconnected` once the
    /// stream ends, instead of hanging or mis-decoding empty data.
    @Test func eofFailsWaitingRequests() async throws {
        MockGunBoundSocket.queuedResponses = []
        let client = try await NetworkClient<MockGunBoundSocket>.connect(Self.config)
        await #expect(throws: NetworkClient<MockGunBoundSocket>.Error.disconnected) {
            _ = try await client.joinChannel()
        }
    }

    /// An unknown notification opcode surfaces as `.raw` rather than being
    /// dropped — screens can decode packet types this layer doesn't model.
    @Test func unmodeledNotificationsArriveRaw() async throws {
        let packet = Packet(opcode: .roomReadyButtonRefreshNotification, parameters: [0x00, 0x00])
        MockGunBoundSocket.queuedResponses = [packet.data]
        let client = try await NetworkClient<MockGunBoundSocket>.connect(Self.config)

        var received: [ServerPush] = []
        for await push in await client.pushes {
            received.append(push)
        }
        #expect(received == [.raw(packet)])
    }

    /// `send(_:)` writes the encoded packet and doesn't consume any inbound
    /// packet — the next `request()` still gets the queued reply.
    @Test func sendIsFireAndForget() async throws {
        MockGunBoundSocket.queuedResponses = [Self.encode(Self.channelAck)]
        let client = try await NetworkClient<MockGunBoundSocket>.connect(Self.config)

        try await client.send(RoomListRequest(filter: .all))
        let response = try await client.joinChannel()
        #expect(response.isSuccess)
    }
}
