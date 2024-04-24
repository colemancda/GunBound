//
//  Command.swift
//  
//
//  Created by Alsey Coleman Miller on 12/5/22.
//

import Foundation

/// Gunbound Packet Opcode
public enum Opcode: UInt16, Codable {
    
    /// Keep Alive
    case keepAlive                  = 0x0000
    
    /// Nonce Request
    case nonceRequest               = 0x1000
    
    /// Nonce Response
    case nonceResponse              = 0x1001
    
    /// Login Request
    case authenticationRequest      = 0x1010
    
    /// Login Response
    case authenticationResponse     = 0x1012
    
    /// User Request
    case userRequest                = 0x1020 // SVC_USER_ID
    
    /// User Response
    case userResponse               = 0x1021
    
    /// User Nickname Request
    case userNicknameRequest        = 0x1022 // SVC_USER_NICK
    
    /// Server Directory Request
    case serverDirectoryRequest     = 0x1100
    
    /// Server Directory Response
    case serverDirectoryResponse    = 0x1102
    
    /// Cash update
    case cashUpdateNotification     = 0x1032
    
    /// Join Channel Request
    case joinChannelRequest         = 0x2000 // SVC_CHANNEL_JOIN
    
    /// Join Channel Request
    case joinChannelResponse        = 0x2001
    
    /// Join Channel Notification
    case joinChannelNotification    = 0x200E
    
    case roomListRequest            = 0x2100 // SVC_ROOM_SORTED_LIST
    
    case roomSpecificList           = 0x2101 // SVC_ROOM_SPECIFIC_LIST
    
    case roomListResponse           = 0x2103
    
    case roomDetailRequest          = 0x2104 // SVC_ROOM_DETAIL
    
    case roomDetailResponse         = 0x2105
    
    case joinRoomRequest            = 0x2110 // SVC_ROOM_JOIN
    
    case joinRoomResponse           = 0x2111
    
    case joinRoomNotification       = 0x3010
    
    case joinRoomNotificationSelf   = 0x21F5
    
    case channelChatCommand         = 0x2010 // SVC_CHANNEL_CHAT
    
    case channelChatBroadcast       = 0x201F
    
    case createRoomRequest          = 0x2120 // SVC_ROOM_CREATE
    
    case createRoomResponse         = 0x2121
    
    case roomChangeStageCommand     = 0x3100 // SVC_ROOM_CHANGE_STAGE
    
    case roomChangeOptionCommand    = 0x3101 // SVC_ROOM_CHANGE_OPTION
    
    case roomChangeUseItemCommand   = 0x3102 // SVC_ROOM_CHANGE_USEITEM
    
    case roomChangeCapacityCommand  = 0x3103 // SVC_ROOM_CHANGE_MAXMEN
    
    case roomSetTitleCommand        = 0x3104 // SVC_ROOM_CHANGE_TITLE
        
    case roomUpdateNotification     = 0x3105
    
    case roomSelectTeamRequest      = 0x3210 // SVC_ROOM_SELECT_TEAM
    
    case roomSelectTeamResponse     = 0x3211
    
    case roomKickUserRequest        = 0x3150 // SVC_ROOM_KICK_USER
    
    case roomSelectTankRequest      = 0x3200 // SVC_ROOM_SELECT_TANK
    
    case roomSelectTankResponse     = 0x3201
    
    case roomUserReadyRequest       = 0x3230 // SVC_ROOM_USER_READY
    
    case roomUserReadyResponse      = 0x3231
    
    case roomReturnResultRequest    = 0x3232 // SVC_ROOM_RETURN_RESULT
    
    case roomReturnResultResponse   = 0x3233
    
    case startGameCommand           = 0x3430 // SVC_START_GAME
    
    case startGameNotification      = 0x3432
    
    case close                      = 0x3FFF
    
    case gameDropUserCommand        = 0x4000 // SVC_PLAY_DROP_USER
    
    case endGameJewelCommand        = 0x4200 // SVC_PLAY_END_JEWEL
    
    case userDeadRequest            = 0x4100
    
    case userDeadResponse           = 0x4101 // SVC_PLAY_USER_DEAD
    
    case playResurrect              = 0x4104 // SVC_PLAY_RESURRECT
    
    case playResultCommand          = 0x4412 // SVC_PLAY_RESULT
    
    case playResultNotification     = 0x4413
    
    case policeAccuse               = 0x5000 // SVC_POLICE_ACCUSE
    
    case userInfo                   = 0x5002 // SVC_USER_INFO
    
    case bcm                        = 0x5010 // SVC_BCM
    
    case clientCommand              = 0x5100 // SVC_COMMAND
    
    case clientPrintNotification    = 0x5101
    
    case clientCommandStatus        = 0x5110 // SVC_CMD_STATUS
    
    /// Client Command Message of the Day
    case clientCommandMOTD          = 0x5112 // SVC_CMD_MOTD
    
    case clientCommandBCM           = 0x5114 // SVC_CMD_BCM
     
    case clientCommandSetVersion    = 0x5116 // SVC_CMD_SETVERSION
    
    case clientCommandGradeLimit    = 0x5120 // SVC_CMD_GRADELIMIT
    
    case clientCommandGuildMarkLimit = 0x5122 // SVC_CMD_GUILDLIMIT
    
    case clientCommandFunctionRestrict = 0x5124 // SVC_CMD_FUNCTION_RESTRICT
    
    case clientCommandAllowedGuild  = 0x5126 // SVC_CMD_SET_ALLOWEDGUILD
    
    case clientSetEventActProb      = 0x5128 // SVC_CMD_SET_EVENTACTPROB
    
    case clientSetPassableAuthority = 0x512a // SVC_CMD_SET_PASSABLE_AUTH
    
    case rebroadcast                = 0x4410
    
    case tunnel                     = 0x4500 // SVC_TUNNEL
    
    case getAvatarRequest           = 0x6000 // SVC_PROP_GET
    
    case getAvatarResponse          = 0x6001
    
    case setAvatarRequest           = 0x6004 // SVC_PROP_SET
    
    case setAvatarResponse          = 0x6005
    
    case buyGoldRequest             = 0x6010 // SVC_PROP_BUY
    
    case buyCashRequest             = 0x6011 // SVC_PROP_BUY_PP
    
    case buyResponse                = 0x6017
    
    case sellRequest                = 0x6020 // SVC_PROP_SELL
    
    case sellGiven                  = 0x6021 // SVC_PROP_SELL_GIVEN
    
    case sellResponse               = 0x6027
    
    case giftRequest                = 0x6030 // SVC_PROP_GIFT
    
    case giftGiven                  = 0x6031 // SVC_PROP_GIFT_GIVEN
    
    case buyGoldGiftRequest         = 0x6032 // SVC_PROP_GIFT_BUY
    
    case buyCashGiftRequest         = 0x6033 // SVC_PROP_GIFT_BUY_PP
    
    case giftResponse               = 0x6037
    
    case userCenterLocationRequest  = 0xcf02 // RCTS_USER_LOCATION
    
    case userCenterRecordRequest    = 0xc103
    
    case unknown                    = 0x9999
}

public extension Opcode {
    
    /// Specifies the opcode category.
    var type: OpcodeType {
        
        switch self {
        case .keepAlive:                            return .command
        case .tunnel:                               return .command
        case .nonceRequest:                         return .request
        case .nonceResponse:                        return .response
        case .authenticationRequest:                return .request
        case .authenticationResponse:               return .response
        case .serverDirectoryRequest:               return .request
        case .serverDirectoryResponse:              return .response
        case .userRequest:                          return .request
        case .userResponse:                         return .response
        case .cashUpdateNotification:               return .notification
        case .joinChannelRequest:                   return .request
        case .joinChannelResponse:                  return .response
        case .joinChannelNotification:              return .notification
        case .roomListRequest:                      return .request
        case .roomListResponse:                     return .response
        case .joinRoomRequest:                      return .request
        case .joinRoomResponse:                     return .response
        case .joinRoomNotification:                 return .notification
        case .joinRoomNotificationSelf:             return .notification
        case .createRoomRequest:                    return .request
        case .createRoomResponse:                   return .response
        case .roomSelectTankRequest:                return .request
        case .roomSelectTankResponse:               return .response
        case .roomSelectTeamRequest:                return .request
        case .roomSelectTeamResponse:               return .response
        case .roomUpdateNotification:               return .notification
        case .roomChangeStageCommand:               return .command
        case .roomChangeOptionCommand:              return .command
        case .roomChangeCapacityCommand:            return .command
        case .roomSetTitleCommand:                  return .command
        case .roomUserReadyRequest:                 return .request
        case .roomUserReadyResponse:                return .response
        case .channelChatCommand:                   return .command
        case .channelChatBroadcast:                 return .notification
        case .startGameCommand:                     return .command
        case .startGameNotification:                return .notification
        case .userDeadRequest:                      return .request
        case .userDeadResponse:                     return .response
        case .playResultCommand:                    return .command
        case .playResultNotification:               return .notification
        case .clientCommand:                        return .command
        case .clientPrintNotification:              return .notification
        case .roomReturnResultRequest:              return .request
        case .roomReturnResultResponse:             return .response
        case .gameDropUserCommand:                  return .command
        case .close:                                return .notification
        
        default:
            assertionFailure("Unimplemented \(self)")
            return .request
        }
    }
    
    var isEncrypted: Bool {
        switch self {
        case .cashUpdateNotification,
            .startGameNotification,
            .userResponse,
            .channelChatCommand,
            .channelChatBroadcast,
            .endGameJewelCommand,
            .getAvatarResponse:
            return true
        default:
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
    
    static let requestResponseMap: [(request: Opcode,  response: Opcode)] = [
        (.nonceRequest,                  .nonceResponse),
        (.authenticationRequest,         .authenticationResponse),
        (.serverDirectoryRequest,        .serverDirectoryResponse),
        (.userRequest,                   .userResponse),
        (.joinChannelRequest,            .joinChannelResponse),
        (.joinRoomRequest,               .joinRoomResponse),
        (.roomListRequest,               .joinRoomResponse),
        (.createRoomRequest,             .createRoomResponse),
        (.roomSelectTankRequest,         .roomSelectTankResponse),
        (.roomSelectTeamRequest,         .roomSelectTeamResponse),
        (.roomUserReadyRequest,          .roomUserReadyResponse),
        (.userDeadRequest,               .userDeadResponse),
        (.roomReturnResultRequest,       .roomReturnResultResponse),
        
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
