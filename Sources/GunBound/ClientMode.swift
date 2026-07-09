//
//  GameMode.swift
//
//
//  Created by Alsey Coleman Miller on 12/6/22.
//

import Foundation

/// Client state
public struct ClientMode: RawRepresentable, Equatable, Hashable, Codable {

    public let rawValue: UInt8

    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }
}

// MARK: - ExpressibleByIntegerLiteral

extension ClientMode: ExpressibleByIntegerLiteral {

    public init(integerLiteral value: RawValue) {
        self.init(rawValue: value)
    }
}

// MARK: - CustomStringConvertible

extension ClientMode: CustomStringConvertible, CustomDebugStringConvertible {

    public var description: String {
        switch self {
        case .title:
            return "Title"
        case .serverSelect:
            return "Server / Channel Select"
        case .gameRoomList:
            return "Game Room List"
        case .logo1:
            return "Logo Screen 1"
        case .logo2:
            return "Logo Screen 2"
        case .avatarShop:
            return "Avatar Shop"
        case .readyRoom:
            return "Ready Room"
        case .loading:
            return "Loading"
        case .inGameSession:
            return "In Game Session"
        case .exitToDesktop:
            return "Exit to Desktop"
        default:
            return "0x" + rawValue.toHexadecimal()
        }
    }

    public var debugDescription: String {
        description
    }
}

// MARK: - Definitions

/// The 16 `CGameState` screens, confirmed by resource strings during static
/// analysis of the original client (see `ARCHITECTURE.md`'s "The 16 game
/// states" table) — `OnEnter` for each state loads a named `.img`/`.mp3`
/// resource set that identifies the screen unambiguously.
public extension ClientMode {

    /// Publisher splash screen 1 (`logomode.img`, `logo.mp3`).
    static var logo1: ClientMode { 5 }
    /// Publisher splash screen 2 (`logomode2.img`, `logo2.mp3`).
    static var logo2: ClientMode { 6 }
    /// Title screen (`titlemode.img`, `title.mp3`).
    static var title: ClientMode { 1 }
    /// Server / channel select (`server_list.img`, `b_server_choiceserver.img`, `channel.mp3`).
    static var serverSelect: ClientMode { 2 }
    /// Channel lobby / game room list (`gamelist_back.img`, `gamelist_create.img`, `b_gamelist_*.img`).
    static var gameRoomList: ClientMode { 3 }
    /// Avatar store / shop (`store_*.img`, `b_store_*.img`).
    static var avatarShop: ClientMode { 7 }
    /// Pre-battle ready room (`ready_selectmap.img`, `ready_selectcharacter.img`, `b_ready_startgame.img`).
    static var readyRoom: ClientMode { 9 }
    /// Loading screen (`loadmode.img`, `loadstage.img`).
    static var loading: ClientMode { 10 }
    /// In-battle / playing (`stage%d.mp3`, `b_play_*.img`).
    static var inGameSession: ClientMode { 11 }
    /// Quit — `ChangeGameState(0xf)` calls `PostQuitMessage(0)` directly.
    static var exitToDesktop: ClientMode { 15 }
}
