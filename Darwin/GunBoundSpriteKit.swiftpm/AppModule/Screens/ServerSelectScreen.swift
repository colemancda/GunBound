//
//  ServerSelectScreen.swift
//  GunBoundSpriteKit
//
//  Preview for Server / Channel Select (state 2) — the WORLD LIST panel over
//  `server_back.img` with the three confirmed buttons and the row grid
//  (backgrounds, numbers, names/descriptions, population gauges) fed by a
//  mock broker. Rows are click-selectable (online ones); SERVER "connects"
//  to the selection and fails quietly with no real server running.
//

import Foundation
import SwiftUI
import GunBound
import GunBoundClient
import GunBoundProtocol

#Preview("Server Select") {
    serverSelectScreenPreview(result: .success(mockServers))
}

#Preview("Server Select Error") {
    serverSelectScreenPreview(result: .failure(URLError(.cannotFindHost)))
}

#Preview("Server Select — Buddy Panel") {
    serverSelectScreenPreview(result: .success(mockServers), showBuddyPanel: true)
}

let mockServers = [
    ServerDirectoryResponse.Server(
        id: 0,
        name: "JG Test Broker",
        descriptionText: "Broker description\\n goes here",
        address: IPv4Address(192, 168, 1, 1),
        port: 8370,
        utilization: 0,
        capacity: 100,
        isEnabled: true
    ),
    ServerDirectoryResponse.Server(
        id: 1,
        name: "Free Play",
        descriptionText: "Rookie Zone\\nAvatar ON",
        address: IPv4Address(192, 168, 1, 1),
        port: 8361,
        utilization: 50,
        capacity: 100,
        isEnabled: true
    ),
    ServerDirectoryResponse.Server(
        id: 2,
        name: "Disabled Server",
        descriptionText: "Rookie Zone\\nAvatar ON",
        address: IPv4Address(192, 168, 1, 1),
        port: 8362,
        utilization: 50,
        capacity: 100,
        isEnabled: false
    ),
    ServerDirectoryResponse.Server(
        id: 3,
        name: "Full Server",
        descriptionText: "Rookie Zone\\nAvatar ON",
        address: IPv4Address(192, 168, 1, 1),
        port: 8363,
        utilization: 100,
        capacity: 100,
        isEnabled: true
    ),
    ServerDirectoryResponse.Server(
        id: 4,
        name: "Loopback Server",
        descriptionText: "localhost\\nPort 8370",
        address: IPv4Address(127, 0, 0, 1),
        port: 8370,
        utilization: 0,
        capacity: 100,
        isEnabled: true
    ),
    ServerDirectoryResponse.Server(
        id: 5,
        name: "Loopback Server",
        descriptionText: "localhost\\nPort 8370",
        address: IPv4Address(127, 0, 0, 1),
        port: 8370,
        utilization: 0,
        capacity: 100,
        isEnabled: true
    ),
    ServerDirectoryResponse.Server(
        id: 6,
        name: "Loopback Server",
        descriptionText: "localhost\\nPort 8370",
        address: IPv4Address(127, 0, 0, 1),
        port: 8370,
        utilization: 0,
        capacity: 100,
        isEnabled: true
    ),
    ServerDirectoryResponse.Server(
        id: 7,
        name: "Loopback Server",
        descriptionText: "localhost\\nPort 8370",
        address: IPv4Address(127, 0, 0, 1),
        port: 8370,
        utilization: 0,
        capacity: 100,
        isEnabled: true
    ),
    ServerDirectoryResponse.Server(
        id: 8,
        name: "Loopback Server",
        descriptionText: "localhost\\nPort 8370",
        address: IPv4Address(127, 0, 0, 1),
        port: 8370,
        utilization: 0,
        capacity: 100,
        isEnabled: true
    ),
    ServerDirectoryResponse.Server(
        id: 9,
        name: "Loopback Server",
        descriptionText: "localhost\\nPort 8370",
        address: IPv4Address(127, 0, 0, 1),
        port: 8370,
        utilization: 0,
        capacity: 100,
        isEnabled: true
    ),
    ServerDirectoryResponse.Server(
        id: 10,
        name: "Loopback Server",
        descriptionText: "localhost\\nPort 8370",
        address: IPv4Address(127, 0, 0, 1),
        port: 8370,
        utilization: 0,
        capacity: 100,
        isEnabled: true
    ),
    ServerDirectoryResponse.Server(
        id: 11,
        name: "Loopback Server",
        descriptionText: "localhost\\nPort 8370",
        address: IPv4Address(127, 0, 0, 1),
        port: 8370,
        utilization: 0,
        capacity: 100,
        isEnabled: true
    ),
    ServerDirectoryResponse.Server(
        id: 12,
        name: "Loopback Server",
        descriptionText: "localhost\\nPort 8370",
        address: IPv4Address(127, 0, 0, 1),
        port: 8370,
        utilization: 0,
        capacity: 100,
        isEnabled: true
    ),
    ServerDirectoryResponse.Server(
        id: 13,
        name: "Loopback Server",
        descriptionText: "localhost\\nPort 8370",
        address: IPv4Address(127, 0, 0, 1),
        port: 8370,
        utilization: 0,
        capacity: 100,
        isEnabled: true
    ),
    ServerDirectoryResponse.Server(
        id: 14,
        name: "Loopback Server",
        descriptionText: "localhost\\nPort 8370",
        address: IPv4Address(127, 0, 0, 1),
        port: 8370,
        utilization: 0,
        capacity: 100,
        isEnabled: true
    ),
]

struct MockDirectoryFetcher: ServerDirectoryFetching {
    
    let result: Result<[ServerDirectoryResponse.Server], Error>
    
    let sleep: UInt = 3
    
    init(error: any Error) {
        self.result = .failure(error)
    }
    
    init(servers: [ServerDirectoryResponse.Server]) {
        self.result = .success(servers)
    }
    
    init(result: Result<[ServerDirectoryResponse.Server], Error>) {
        self.result = result
    }

    func fetchServerDirectory(address: String, brokerPort: UInt16) async throws -> [ServerDirectoryResponse.Server] {
        try await Task.sleep(for: .seconds(sleep))
        return try result.get()
    }
}

/// Preview body lives in a plain function (not the #Preview closure)
/// because tvOS's #Preview expands to a ViewBuilder closure that
/// rejects the explicit `return` this setup needs.
@MainActor
private func serverSelectScreenPreview(result: Result<[ServerDirectoryResponse.Server], Error>, showBuddyPanel: Bool = false) -> some View {
    let delegate = ScreenPreviewDelegate()
    let viewModel = ServerSelectViewModel(
        delegate: delegate,
        directoryFetcher: MockDirectoryFetcher(result: result)
    )
    if showBuddyPanel {
        viewModel.buddies = ["alsey", "boomer", "trico", "mage"]
        viewModel.setBuddyPanelVisible(true)
    }
    return ScreenPreviewView(screen: ServerSelectScreen(viewModel: viewModel))
        .frame(width: 800, height: 600)
}
