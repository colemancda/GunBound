//
//  Command.swift
//
//
//  Created by Alsey Coleman Miller on 12/5/22.
//

/// Gunbound Packet Opcode
/// Represents all packet types in the GunBound protocol
public enum Opcode: UInt16, Sendable {

    // MARK: - Connection

    /// Keep Alive - ping/pong to maintain connection
    case keepAlive = 0x0000

    // MARK: - Authentication

    /// Nonce Request - request nonce for authentication
    case nonceRequest = 0x1000

    /// Nonce Response - server returns nonce value
    case nonceResponse = 0x1001

    /// Login Request - authenticate with username and password
    case authenticationRequest = 0x1010

    /// Login Response - authentication result
    case authenticationResponse = 0x1012

    /// Session/Server Handoff Notification - two `uint` fields stored into
    /// session-scoped globals right after channel/server selection; likely a
    /// session token or server address handoff. Exact field meaning not
    /// confirmed. (observed via static analysis of the original client)
    case sessionHandoffNotification = 0x101F

    /// User Request - look up user information by username
    case userRequest = 0x1020  // SVC_USER_ID

    /// User Response - return user information (encrypted)
    case userResponse = 0x1021

    /// User Nickname Request - look up user by nickname
    case userNicknameRequest = 0x1022  // SVC_USER_NICK

    // MARK: - Server Directory

    /// Server Directory Request - get list of available servers
    case serverDirectoryRequest = 0x1100

    /// Server Directory Response - return server list
    case serverDirectoryResponse = 0x1102

    // MARK: - Currency Updates

    /// Cash Update Notification - update player's cash balance
    case cashUpdateNotification = 0x1032

    /// Gold Update Request - request current gold balance
    case goldUpdateRequest = 0x6104

    /// Gold Update Response - return gold balance
    case goldUpdateResponse = 0x6105

    // MARK: - Channel

    /// Join Channel Request
    case joinChannelRequest = 0x2000  // SVC_CHANNEL_JOIN

    /// Join Channel Response
    case joinChannelResponse = 0x2001

    /// Join Channel Notification - broadcast when a user joins the channel
    case joinChannelNotification = 0x200E

    // MARK: - Room List

    /// Room List Request - get list of all rooms (sorted).
    /// Decomp-confirmed as the Game Room List (State 3) command dispatcher's
    /// outgoing room-list request, carrying a channel/tab mode byte and page
    /// (`docs/screens/03_game_room_list.md`).
    case roomListRequest = 0x2100  // SVC_ROOM_SORTED_LIST

    /// Room Specific List Request - get list of specific rooms.
    /// Decomp-confirmed as the lobby's outgoing channel-selector/navigation
    /// opcode (the in-lobby channel switch an earlier incoming-only scan
    /// missed).
    case roomSpecificList = 0x2101  // SVC_ROOM_SPECIFIC_LIST

    /// Room List Response
    case roomListResponse = 0x2103

    /// Room Detail Request - get detailed information about a specific room
    case roomDetailRequest = 0x2104  // SVC_ROOM_DETAIL

    /// Room Detail Response
    case roomDetailResponse = 0x2105

    // MARK: - Room Management

    /// Join Room Request - request to join a game room.
    /// Decomp-confirmed as the lobby dispatcher's "enter room by number"
    /// outgoing opcode (`docs/screens/03_game_room_list.md`).
    case joinRoomRequest = 0x2110  // SVC_ROOM_JOIN

    /// Join Room Response
    case joinRoomResponse = 0x2111

    /// Join Room Notification - broadcast when a player joins the room
    case joinRoomNotification = 0x3010

    /// Join Room Self Notification - sent to the player who just joined
    case joinRoomNotificationSelf = 0x21F5

    /// Room Self Display Update Notification - companion write path to
    /// `roomDetailResponse` (`0x2105`) for the same 128-byte per-slot display
    /// buffer, used when the client itself is the subject of the update
    /// (server resolves "my own slot" rather than a supplied slot index).
    /// (observed via static analysis of the original client)
    case roomSelfDisplayUpdateNotification = 0x21F0

    /// Room Player Left Notification - a player/entity ID identifying who
    /// left the room; removes them from local room-membership tracking.
    /// (observed via static analysis of the original client)
    case roomPlayerLeftNotification = 0x21F1

    /// Room Player Display Update Notification - per-field update to another
    /// player's 128-byte display buffer (see `roomSelfDisplayUpdateNotification`
    /// for the "self" counterpart). (observed via static analysis of the original client)
    case roomPlayerDisplayUpdateNotification = 0x21F2

    /// Room Player Flag Update Notification - single-byte per-slot field
    /// update (one of six fields also bulk-populated by `roomDetailResponse`).
    /// (observed via static analysis of the original client)
    case roomPlayerFlagUpdateNotification = 0x21F3

    /// Room Player Value Update Notification - 4-byte per-slot field update.
    /// (observed via static analysis of the original client)
    case roomPlayerValueUpdateNotification = 0x21F4

    /// Room Player Status Update Notification - single-byte per-slot field
    /// update. (observed via static analysis of the original client)
    case roomPlayerStatusUpdateNotification = 0x21F6

    /// Room Player Mode Update Notification - single-byte per-slot field
    /// update. (observed via static analysis of the original client)
    case roomPlayerModeUpdateNotification = 0x21F7

    /// Channel Chat Command - send a chat message to the channel
    case channelChatCommand = 0x2010  // SVC_CHANNEL_CHAT

    /// Channel Chat Broadcast - broadcast a chat message to all users in channel
    case channelChatBroadcast = 0x201F

    // MARK: - Room Creation

    /// Create Room Request - create a new game room
    case createRoomRequest = 0x2120  // SVC_ROOM_CREATE

    /// Create Room Response
    case createRoomResponse = 0x2121

    // MARK: - Room Commands

    /// Room Change Stage Command - change the map/stage (room master only)
    case roomChangeStageCommand = 0x3100  // SVC_ROOM_CHANGE_STAGE

    /// Room Change Option Command - change game options (room master only)
    case roomChangeOptionCommand = 0x3101  // SVC_ROOM_CHANGE_OPTION

    /// Room Change Use Item Command - change item state in room (room master only)
    case roomChangeUseItemCommand = 0x3102  // SVC_ROOM_CHANGE_USEITEM

    /// Room Change Capacity Command - change max players (room master only)
    case roomChangeCapacityCommand = 0x3103  // SVC_ROOM_CHANGE_MAXMEN

    /// Room Set Title Command - change room title (room master only)
    case roomSetTitleCommand = 0x3104  // SVC_ROOM_CHANGE_TITLE

    /// Room Update Notification - broadcast when room settings change
    case roomUpdateNotification = 0x3105

    // MARK: - Room Player Actions

    /// Room Select Team Request - select a team (A or B)
    case roomSelectTeamRequest = 0x3210  // SVC_ROOM_SELECT_TEAM

    /// Room Select Team Response
    case roomSelectTeamResponse = 0x3211

    /// Room Kick User Request - kick a player from room (room master only)
    case roomKickUserRequest = 0x3150  // SVC_ROOM_KICK_USER

    /// Room Select Tank Request - select mobile/tank to play
    case roomSelectTankRequest = 0x3200  // SVC_ROOM_SELECT_TANK

    /// Room Select Tank Response
    case roomSelectTankResponse = 0x3201

    /// Room User Ready Request - toggle ready status
    case roomUserReadyRequest = 0x3230  // SVC_ROOM_USER_READY

    /// Room User Ready Response
    case roomUserReadyResponse = 0x3231

    /// Room Return Result Request - return game result to server
    case roomReturnResultRequest = 0x3232  // SVC_ROOM_RETURN_RESULT

    /// Room Return Result Response
    case roomReturnResultResponse = 0x3233

    /// User Quit Notification - observed with two meanings depending on
    /// screen: a no-payload ready/unready toggle in the Ready Room, and a
    /// player-disconnected-mid-match signal while In-Battle.
    /// (observed via static analysis of the original client)
    case userQuitNotification = 0x3020

    /// Room Change Team Notification (tentative) - single byte team value.
    /// (observed via static analysis of the original client)
    case roomChangeTeamNotification = 0x3151

    /// Room Ready Button Refresh Notification - no payload; tells the client
    /// to redraw its primary action button (Ready vs. Start Game, depending
    /// on room ownership). (observed via static analysis of the original client)
    case roomReadyButtonRefreshNotification = 0x3400

    /// Room Ready Confirmation Notification - no payload; shared confirmation
    /// tail also reachable via team/tank/map-selection opcodes.
    /// (observed via static analysis of the original client)
    case roomReadyConfirmationNotification = 0x3431

    // MARK: - Gameplay

    /// Start Game Command - start the game (room master only)
    case startGameCommand = 0x3430  // SVC_START_GAME

    /// Start Game Notification - broadcast when game starts
    case startGameNotification = 0x3432

    /// Close Connection
    case close = 0x3FFF

    /// Game Drop User Command - drop/disconnect a user from game
    case gameDropUserCommand = 0x4000  // SVC_PLAY_DROP_USER

    /// End Game Jewel Command - end jewel mode game
    case endGameJewelCommand = 0x4200  // SVC_PLAY_END_JEWEL

    /// User Dead Request - notify server that player died
    case userDeadRequest = 0x4100

    /// User Dead Response - broadcast when player dies
    case userDeadResponse = 0x4101  // SVC_PLAY_USER_DEAD

    /// Play Resurrect Command - player resurrects in-game
    case playResurrect = 0x4104  // SVC_PLAY_RESURRECT

    /// Play Result Command - send game results
    case playResultCommand = 0x4412  // SVC_PLAY_RESULT

    /// Play Result Notification - broadcast game results
    case playResultNotification = 0x4413

    /// User Disconnect Notification - a second, companion disconnect signal
    /// alongside `userQuitNotification`; payload is a bitmask checked against
    /// `0xf000`, gating a position field and cooldown flag (not fully
    /// disambiguated from `userQuitNotification`'s trigger conditions).
    /// (observed via static analysis of the original client)
    case userDisconnectNotification = 0x4102

    // MARK: - Server/Admin Commands

    /// Police Accuse - report a player (anti-cheat system)
    case policeAccuse = 0x5000  // SVC_POLICE_ACCUSE

    /// User Info - broadcast user information
    case userInfo = 0x5002  // SVC_USER_INFO

    /// BCM (Broadcast Message) - server broadcast message
    case bcm = 0x5010  // SVC_BCM

    /// Client Command - general client command from server
    case clientCommand = 0x5100  // SVC_COMMAND

    /// Client Print Notification - display message to client
    case clientPrintNotification = 0x5101

    /// Client Command Status - update server status
    case clientCommandStatus = 0x5110  // SVC_CMD_STATUS

    /// Client Command Message of the Day
    case clientCommandMOTD = 0x5112  // SVC_CMD_MOTD

    /// Client Command BCM - send broadcast message
    case clientCommandBCM = 0x5114  // SVC_CMD_BCM

    /// Client Command Set Version - set client version requirement
    case clientCommandSetVersion = 0x5116  // SVC_CMD_SETVERSION

    /// Client Command Grade Limit - set rank/grade restrictions
    case clientCommandGradeLimit = 0x5120  // SVC_CMD_GRADELIMIT

    /// Client Command Guild Mark Limit - set guild restrictions
    case clientCommandGuildMarkLimit = 0x5122  // SVC_CMD_GUILDLIMIT

    /// Client Command Function Restrict - restrict specific functions
    case clientCommandFunctionRestrict = 0x5124  // SVC_CMD_FUNCTION_RESTRICT

    /// Client Command Allowed Guild - set allowed guilds
    case clientCommandAllowedGuild = 0x5126  // SVC_CMD_SET_ALLOWEDGUILD

    /// Client Set Event Act Prob - set event activation probability
    case clientSetEventActProb = 0x5128  // SVC_CMD_SET_EVENTACTPROB

    /// Client Set Passable Authority - set passable authority level
    case clientSetPassableAuthority = 0x512a  // SVC_CMD_SET_PASSABLE_AUTH

    /// Rebroadcast - rebroadcast packet to other players
    case rebroadcast = 0x4410

    /// Tunnel - P2P tunneling packet for direct connection
    case tunnel = 0x4500  // SVC_TUNNEL

    // MARK: - Shop/Avatar

    /// Get Avatar Request - get player's avatar list. This is the wire opcode
    /// the Avatar Store's "request inventory" action (the decomp's internal
    /// `0x600f`) actually sends on entering the store — `0x600f` is the local
    /// action label, `0x6000` the empty-payload packet it emits.
    case getAvatarRequest = 0x6000  // SVC_PROP_GET

    /// Get Avatar Response - return player's avatar list
    case getAvatarResponse = 0x6001

    /// Avatar Inventory Response - owned/purchased item inventory list; also
    /// sent in response to `getAvatarRequest`, one packet per owned item.
    /// Each item carries an expiration date (rental-style items).
    /// (observed via static analysis of the original client)
    case avatarInventoryResponse = 0x6002

    /// Set Avatar Request - equip/change avatar
    case setAvatarRequest = 0x6004  // SVC_PROP_SET

    /// Set Avatar Response.
    /// Note: the decomp's Avatar Store table (`docs/screens/07_avatar_store.md`)
    /// reads `0x6005` as the store's price-list/init population instead —
    /// our server uses it as the set-avatar response, so the number is shared
    /// between two meanings depending on the flow (kept as-is for our own
    /// server/client pairing).
    case setAvatarResponse = 0x6005

    /// Buy Gold Request - purchase avatar with gold
    case buyGoldRequest = 0x6010  // SVC_PROP_BUY

    /// Buy Cash Request - purchase avatar with cash
    case buyCashRequest = 0x6011  // SVC_PROP_BUY_PP

    /// Buy Response - confirmation of purchase
    case buyResponse = 0x6017

    /// Sell Request - sell avatar for gold
    case sellRequest = 0x6020  // SVC_PROP_SELL

    /// Sell Given - notification that item was sold
    case sellGiven = 0x6021  // SVC_PROP_SELL_GIVEN

    /// Sell Response - confirmation of sale
    case sellResponse = 0x6027

    /// Gift Request - gift avatar to another player
    case giftRequest = 0x6030  // SVC_PROP_GIFT

    /// Gift Given - notification that item was gifted
    case giftGiven = 0x6031  // SVC_PROP_GIFT_GIVEN

    /// Buy Gold Gift Request - gift avatar purchased with gold
    case buyGoldGiftRequest = 0x6032  // SVC_PROP_GIFT_BUY

    /// Buy Cash Gift Request - gift avatar purchased with cash
    case buyCashGiftRequest = 0x6033  // SVC_PROP_GIFT_BUY_PP

    /// Gift Response - confirmation of gift
    case giftResponse = 0x6037

    /// User Center Location Request - request user location from user center
    case userCenterLocationRequest = 0xcf02  // RCTS_USER_LOCATION

    /// User Center Record Request - request user record from user center
    case userCenterRecordRequest = 0xc103

    /// Unknown opcode placeholder
    case unknown = 0x9999
}

public extension Opcode {

    /// Specifies the opcode category.
    var type: OpcodeType {

        switch self {
        case .keepAlive: return .command
        case .tunnel: return .command
        case .nonceRequest: return .request
        case .nonceResponse: return .response
        case .authenticationRequest: return .request
        case .authenticationResponse: return .response
        case .sessionHandoffNotification: return .notification
        case .serverDirectoryRequest: return .request
        case .serverDirectoryResponse: return .response
        case .userRequest: return .request
        case .userResponse: return .response
        case .userNicknameRequest: return .request
        case .cashUpdateNotification: return .notification
        case .goldUpdateRequest: return .request
        case .goldUpdateResponse: return .response
        case .joinChannelRequest: return .request
        case .joinChannelResponse: return .response
        case .joinChannelNotification: return .notification
        case .roomListRequest: return .request
        case .roomListResponse: return .response
        case .roomSpecificList: return .request
        case .roomDetailRequest: return .request
        case .roomDetailResponse: return .response
        case .joinRoomRequest: return .request
        case .joinRoomResponse: return .response
        case .joinRoomNotification: return .notification
        case .joinRoomNotificationSelf: return .notification
        case .roomSelfDisplayUpdateNotification: return .notification
        case .roomPlayerLeftNotification: return .notification
        case .roomPlayerDisplayUpdateNotification: return .notification
        case .roomPlayerFlagUpdateNotification: return .notification
        case .roomPlayerValueUpdateNotification: return .notification
        case .roomPlayerStatusUpdateNotification: return .notification
        case .roomPlayerModeUpdateNotification: return .notification
        case .createRoomRequest: return .request
        case .createRoomResponse: return .response
        case .roomSelectTankRequest: return .request
        case .roomSelectTankResponse: return .response
        case .roomSelectTeamRequest: return .request
        case .roomSelectTeamResponse: return .response
        case .roomKickUserRequest: return .request
        case .roomUpdateNotification: return .notification
        case .roomChangeStageCommand: return .command
        case .roomChangeOptionCommand: return .command
        case .roomChangeUseItemCommand: return .command
        case .roomChangeCapacityCommand: return .command
        case .roomSetTitleCommand: return .command
        case .roomUserReadyRequest: return .request
        case .roomUserReadyResponse: return .response
        case .channelChatCommand: return .command
        case .channelChatBroadcast: return .notification
        case .startGameCommand: return .command
        case .startGameNotification: return .notification
        case .userDeadRequest: return .request
        case .userDeadResponse: return .response
        case .playResurrect: return .command
        case .playResultCommand: return .command
        case .playResultNotification: return .notification
        case .clientCommand: return .command
        case .clientPrintNotification: return .notification
        case .clientCommandStatus: return .command
        case .clientCommandMOTD: return .command
        case .clientCommandBCM: return .command
        case .clientCommandSetVersion: return .command
        case .clientCommandGradeLimit: return .command
        case .clientCommandGuildMarkLimit: return .command
        case .clientCommandFunctionRestrict: return .command
        case .clientCommandAllowedGuild: return .command
        case .clientSetEventActProb: return .command
        case .clientSetPassableAuthority: return .command
        case .roomReturnResultRequest: return .request
        case .roomReturnResultResponse: return .response
        case .userQuitNotification: return .notification
        case .roomChangeTeamNotification: return .notification
        case .roomReadyButtonRefreshNotification: return .notification
        case .roomReadyConfirmationNotification: return .notification
        case .userDisconnectNotification: return .notification
        case .gameDropUserCommand: return .command
        case .policeAccuse: return .command
        case .userInfo: return .notification
        case .bcm: return .command
        case .rebroadcast: return .command
        case .close: return .notification
        case .getAvatarRequest: return .request
        case .getAvatarResponse: return .response
        case .avatarInventoryResponse: return .response
        case .setAvatarRequest: return .request
        case .setAvatarResponse: return .response
        case .buyGoldRequest: return .request
        case .buyCashRequest: return .request
        case .buyResponse: return .response
        case .sellRequest: return .request
        case .sellResponse: return .response
        case .sellGiven: return .notification
        case .giftRequest: return .request
        case .giftResponse: return .response
        case .giftGiven: return .notification
        case .buyGoldGiftRequest: return .request
        case .buyCashGiftRequest: return .request
        case .userCenterLocationRequest: return .request
        case .userCenterRecordRequest: return .request
        case .unknown: return .command

        default:
            assertionFailure("Unimplemented \(self)")
            return .request
        }
    }

    var isEncrypted: Bool {
        switch self {
        case .cashUpdateNotification,
            .goldUpdateResponse,
            .startGameNotification,
            .userResponse,
            .channelChatCommand,
            .channelChatBroadcast,
            .endGameJewelCommand,
            .playResurrect,
            // incoming avatar shop requests are encrypted
            .setAvatarRequest,
            .buyGoldRequest,
            .buyCashRequest,
            .sellRequest,
            .giftRequest:
            return true
        default:
            // getAvatarResponse is pre-encrypted by the handler (RTC prefix must stay outside AES)
            return false
        }
    }

    /// Get the equivalent request for the current response opcode (if applicable).
    var request: Opcode? {
        return Opcode.requestsByResponse[self]
    }

    /// Get the equivalent response for the current request opcode (if applicable).
    var response: Opcode? {
        return Opcode.responsesByRequest[self]
    }
}

private extension Opcode {

    static let requestResponseMap: [(request: Opcode, response: Opcode)] = [
        (.nonceRequest, .nonceResponse),
        (.authenticationRequest, .authenticationResponse),
        (.serverDirectoryRequest, .serverDirectoryResponse),
        (.userRequest, .userResponse),
        (.joinChannelRequest, .joinChannelResponse),
        (.joinRoomRequest, .joinRoomResponse),
        (.roomListRequest, .roomListResponse),
        (.roomDetailRequest, .roomDetailResponse),
        (.createRoomRequest, .createRoomResponse),
        (.roomSelectTankRequest, .roomSelectTankResponse),
        (.roomSelectTeamRequest, .roomSelectTeamResponse),
        (.roomUserReadyRequest, .roomUserReadyResponse),
        (.userDeadRequest, .userDeadResponse),
        (.roomReturnResultRequest, .roomReturnResultResponse),
        (.getAvatarRequest, .getAvatarResponse),
        (.setAvatarRequest, .setAvatarResponse),
        (.buyGoldRequest, .buyResponse),
        (.buyCashRequest, .buyResponse),
        (.sellRequest, .sellResponse),
        (.giftRequest, .giftResponse),
        (.goldUpdateRequest, .goldUpdateResponse)
    ]

    static let responsesByRequest: [Opcode: Opcode] = {
        var dictionary = [Opcode: Opcode](minimumCapacity: requestResponseMap.count)
        requestResponseMap.forEach { dictionary[$0.request] = $0.response }
        return dictionary
    }()

    static let requestsByResponse: [Opcode: Opcode] = {
        var dictionary = [Opcode: Opcode](minimumCapacity: requestResponseMap.count)
        requestResponseMap.forEach { dictionary[$0.response] = $0.request }
        return dictionary
    }()
}

// MARK: - Supporting Types

public enum OpcodeType {

    case request
    case response
    case command
    case notification
}
