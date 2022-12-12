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
    case userRequest                = 0x1020
    
    /// User Response
    case userResponse               = 0x1021
        
    /// Server Directory Request
    case serverDirectoryRequest     = 0x1100
    
    /// Server Directory Response
    case serverDirectoryResponse    = 0x1102
    
    /// Cash update
    case cashUpdateNotification     = 0x1032
    
    /// Join Channel Request
    case joinChannelRequest         = 0x2000
    
    /// Join Channel Request
    case joinChannelResponse        = 0x2001
    
    /// Join Channel Notification
    case joinChannelNotification    = 0x200E
    
    case roomListRequest            = 0x2100
    
    case roomListResponse           = 0x2103
    
    case roomDetailRequest          = 0x2104
    
    case roomDetailResponse         = 0x2105
    
    case joinRoomRequest            = 0x2110
    
    case joinRoomResponse           = 0x2111
    
    case joinRoomNotification       = 0x3010
    
    case joinRoomNotificationSelf   = 0x21F5
    
    case channelChatCommand         = 0x2010
    
    case channelChatBroadcast       = 0x201F
    
    case createRoomRequest          = 0x2120
    
    case createRoomResponse         = 0x2121
    
    case roomChangeStageCommand     = 0x3100
    
    case roomChangeOptionCommand    = 0x3101
    
    case roomChangeUseItemCommand   = 0x3102
    
    case roomChangeCapacityCommand  = 0x3103
    
    case roomSetTitleCommand        = 0x3104
        
    case roomUpdateNotification     = 0x3105
    
    case roomSelectTeamRequest      = 0x3210
    
    case roomSelectTeamResponse     = 0x3211
    
    case roomSelectTankRequest      = 0x3200
    
    case roomSelectTankResponse     = 0x3201
    
    case roomUserReadyRequest       = 0x3230
    
    case roomUserReadyResponse      = 0x3231
    
    case roomReturnResultRequest    = 0x3232
    
    case roomReturnResultResponse   = 0x3233
    
    case startGameCommand           = 0x3430
    
    case startGameNotification      = 0x3432
    
    case close                      = 0x3FFF
    
    case endGameJewelCommand        = 0x4200
    
    case userDeadRequest            = 0x4100
    
    case userDeadResponse           = 0x4101
    
    case playResultCommand          = 0x4412
    
    case playResultNotification     = 0x4413
    
    case clientCommand              = 0x5100
    
    case printClient                = 0x5101
    
    case rebroadcast                = 0x4410
    
    case tunnel                     = 0x4500
    
    case getAvatarRequest           = 0x6000
    
    case getAvatarResponse          = 0x6001
    
    case setAvatarRequest           = 0x6004
    
    case setAvatarResponse          = 0x6005
    
    case buyGoldRequest             = 0x6010
    
    case buyCashRequest             = 0x6011
    
    case buyResponse                = 0x6017
    
    case sellRequest                = 0x6020
    
    case sellResponse               = 0x6027
    
    case giftRequest                = 0x6030
    
    case giftResponse               = 0x6037
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
        case .printClient:                          return .notification
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
