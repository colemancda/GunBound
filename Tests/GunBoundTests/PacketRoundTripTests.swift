import Foundation
import Testing
@testable import GunBoundProtocol

/// Wire-format round trips for every packet that is both encodable and
/// decodable: `decode(encode(value)) == value` exercises each type's
/// `encode(to:)` and `init(parsing:)` in one shot. Packets that only decode
/// from server-crafted bytes (responses/notifications with no public value
/// initializer) are covered separately where they're used.
@Suite struct PacketRoundTripTests {

    /// Encodes `value`, decodes it back, re-encodes the decoded copy, and
    /// asserts the two byte encodings match — exercising both `encode(to:)`
    /// and `init(parsing:)` without requiring the packet be `Equatable`.
    private func roundTrip<T>(
        _ value: T,
        sourceLocation: SourceLocation = #_sourceLocation
    ) where T: GunBoundPacketEncodable & GunBoundPacketDecodable {
        let packet = GunBoundEncoder().encode(value, id: 0x0000)
        guard let decoded = try? GunBoundDecoder().decode(T.self, from: packet) else {
            Issue.record("\(T.self) failed to decode", sourceLocation: sourceLocation)
            return
        }
        let reencoded = GunBoundEncoder().encode(decoded, id: 0x0000)
        #expect(packet.parameters == reencoded.parameters, "\(T.self)", sourceLocation: sourceLocation)
    }

    @Test func buddyAndAccount() {
        roundTrip(Bcm(message: "hi"))
        roundTrip(BuddyAddCommand(username: "admin"))
        roundTrip(BuddyListNotification(buddies: [BuddyEntry(username: "a", isOnline: true)]))
        roundTrip(BuddyListRequest())
        roundTrip(BuddyListResponse(buddies: [BuddyEntry(username: "b", isOnline: false)]))
        roundTrip(BuddyRemoveCommand(username: "admin"))
        roundTrip(CashUpdate(cash: 100))
        roundTrip(CashUpdateRequest())
        roundTrip(GoldUpdateRequest())
        roundTrip(GoldUpdateResponse(gold: 1000))
    }

    @Test func shopAndGift() {
        roundTrip(BuyCashGiftRequest(recipient: "a", avatar: 5))
        roundTrip(BuyCashRequest(avatar: 5))
        roundTrip(BuyGoldGiftRequest(recipient: "a", avatar: 5))
        roundTrip(BuyGoldRequest(avatar: 5))
        roundTrip(BuyResponse())
        roundTrip(GiftGiven(sender: "a", avatar: 5))
        roundTrip(GiftResponse())
        roundTrip(SellGiven(itemPosition: 1, avatar: 5))
        roundTrip(SellRequest(itemPosition: 1, avatar: 5))
        roundTrip(SellResponse())
        roundTrip(SetAvatarRequest(avatarEquipped: 0))
        roundTrip(SetAvatarResponse())
        roundTrip(GetAvatarRequest(sendExtended: true))
        roundTrip(GetAvatarResponse(rtcAndEncryptedData: [1, 2, 3]))
    }

    @Test func serverCommandsAndChat() {
        roundTrip(ChannelChatCommand(message: "hi"))
        roundTrip(ClientCommandAllowedGuild(guilds: ["g1", "g2"]))
        roundTrip(ClientCommandBCM(message: "hi"))
        roundTrip(ClientCommandFunctionRestrict(functionRestrict: FunctionRestrict(rawValue: 0)))
        roundTrip(ClientCommandGradeLimit(gradeLimitFirst: 1, gradeLimitLast: 2))
        roundTrip(ClientCommandGuildMarkLimit(limit: 3))
        roundTrip(ClientCommandMOTD(message: "motd"))
        roundTrip(ClientCommandSetVersion(versionFirst: 280, versionLast: 281))
        roundTrip(ClientCommandStatus(status: 1))
        roundTrip(ClientPrintNotification(message: "hi"))
        roundTrip(ClientSetEventActProb(probability: 50))
        roundTrip(ClientSetPassableAuthority(level: 2))
        roundTrip(CloseNotification())
        roundTrip(PoliceAccuse(accused: "a", reason: 1))
    }

    @Test func lobbyAndSession() {
        roundTrip(JoinChannelRequest(channel: 0))
        roundTrip(KeepAlive())
        roundTrip(NonceRequest())
        roundTrip(NonceResponse(nonce: Nonce()))
        roundTrip(ServerDirectoryRequest())
        roundTrip(ServerDirectoryResponse(directory: []))
        roundTrip(SessionHandoffNotification(value0: 1, value1: 2))
        roundTrip(UserCenterLocationRequest(username: "a"))
        roundTrip(UserCenterRecordRequest(username: "a"))
        roundTrip(UserIdRequest(unknown: 0, username: "a"))
        roundTrip(UserInfo(username: "a", status: 1))
        roundTrip(UserNicknameRequest(unknown: 0, nickname: "a"))
    }

    @Test func rooms() {
        roundTrip(RoomChangeCapacityCommand(capacity: ._2_2))
        roundTrip(RoomChangeItemCommand(itemState: 1))
        roundTrip(RoomChangeOptionCommand(settings: 0))
        roundTrip(RoomChangeStageCommand(map: .random))
        roundTrip(RoomChangeTeamNotification(team: .a))
        roundTrip(RoomDetailRequest(room: 0))
        roundTrip(RoomKickUserRequest(playerID: 2))
        roundTrip(RoomListRequest(filter: .all, startIndex: nil))
        roundTrip(RoomListResponse(rooms: []))
        roundTrip(RoomPlayerDisplayUpdateNotification(displayBuffer: [1, 2, 3]))
        roundTrip(RoomPlayerFlagUpdateNotification(value: 1))
        roundTrip(RoomPlayerLeftNotification(playerID: 2))
        roundTrip(RoomPlayerModeUpdateNotification(value: 1))
        roundTrip(RoomPlayerStatusUpdateNotification(value: 1))
        roundTrip(RoomPlayerValueUpdateNotification(value: 1))
        roundTrip(RoomReadyConfirmationNotification())
        roundTrip(RoomReturnResultRequest())
        roundTrip(RoomReturnResultResponse())
        roundTrip(RoomSelectTankResponse())
        roundTrip(RoomSelectTeamRequest(team: .a))
        roundTrip(RoomSelectTeamResponse())
        roundTrip(RoomSelfDisplayUpdateNotification(displayBuffer: "x"))
        roundTrip(RoomSetTitleCommand(title: "t"))
        roundTrip(RoomSpecificList(rooms: [RoomID(rawValue: 1)]))
        roundTrip(RoomUpdateNotification())
    }

    @Test func inGame() {
        roundTrip(EndGameJewelCommand(payload: [1, 2]))
        roundTrip(GameDropUserCommand(playerID: 3))
        roundTrip(GameEndNotification(payload: [1, 2, 3]))
        roundTrip(GameResultCommand(results: []))
        roundTrip(GameResultNotification())
        roundTrip(JoinRoomNotificationSelf())
        roundTrip(PlayerDeadNotification(slot: 1, team: .a))
        roundTrip(PlayerResurrectCommand())
        roundTrip(StartGameCommand(payload: [1, 2]))
        roundTrip(Tunnel(value0: 0, destinationSlot: 1, payload: [1, 2]))
        roundTrip(TunnelForward(sourceSlot: 1, payload: [1, 2]))
        roundTrip(UserDeathRequest(value0: 0, value1: 0))
        roundTrip(UserDeathResponse())
        roundTrip(UserQuitNotification(slot: 1))
        roundTrip(UserReadyRequest(isReady: true))
        roundTrip(UserReadyResponse())
    }

    @Test func packetsWithValueInitializers() {
        roundTrip(GiftRequest(recipient: "a", unknown: 0, itemPosition: 1, avatar: 5, message: "m"))
        roundTrip(UserIdResponse(nickname1: "a", nickname2: "b", guild: "g", rankCurrent: 1, rankSeason: 2))
        roundTrip(AvatarInventoryResponse(id: 1, name: "item", expirationDate: 2, field: 3, description: "d"))
        roundTrip(ChannelChatBroadcast(position: 0, username: "a", message: "hi"))
        roundTrip(RoomSelectTankRequest(primary: .random, secondary: .random))
    }
}
