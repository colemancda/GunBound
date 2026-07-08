//
//  GameRoomListScreen.swift
//  GunBoundSpriteKit
//
//  Preview for the Game Room List / channel lobby (state 3) — room cards are
//  injected directly (no live server in a preview), showing the 3x2 grid,
//  status icons, and bitmap-font room numbers/counts/names.
//

import SwiftUI
import GunBound
import GunBoundProtocol
import GunBoundClient

#Preview("Game Room List") {
    let delegate = ScreenPreviewDelegate()
    let viewModel = GameRoomListViewModel(delegate: delegate)
    viewModel.rooms = [
        RoomListResponse.Room(id: 1, name: "Rookie zone", map: .metropolis, settings: 0, playerCount: 2, capacity: ._2_2, isPlaying: false, isLocked: false),
        RoomListResponse.Room(id: 2, name: "Avatar ON come in", map: .miramoTown, settings: 0, playerCount: 8, capacity: ._4_4, isPlaying: false, isLocked: false),
        RoomListResponse.Room(id: 3, name: "1 vs 1 pros only", map: .seaHero, settings: 0, playerCount: 1, capacity: ._1_1, isPlaying: true, isLocked: false),
        RoomListResponse.Room(id: 4, name: "password is 1234", map: .dragon, settings: 0, playerCount: 3, capacity: ._4_4, isPlaying: false, isLocked: true),
        RoomListResponse.Room(id: 5, name: "no cheats", map: .nirvana, settings: 0, playerCount: 4, capacity: ._3_3, isPlaying: true, isLocked: false),
        RoomListResponse.Room(id: 6, name: "GG only", map: .random, settings: 0, playerCount: 6, capacity: ._4_4, isPlaying: false, isLocked: false),
    ]
    return ScreenPreviewView(screen: GameRoomListScreen(viewModel: viewModel))
        .frame(width: 800, height: 600)
}
