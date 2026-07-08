//
//  ServerSelectScreen.swift
//  GunBoundSpriteKit
//
//  Preview for Server / Channel Select (state 2) — the WORLD LIST panel over
//  `server_back.img` with the three confirmed buttons. No broker is running
//  in a preview, so clicking Server falls back to the configured address and
//  fails quietly; hover states are interactive.
//

import SwiftUI
import GunBound
import GunBoundClient
import GunBoundProtocol

#Preview("Server Select") {
    serverSelectScreenPreview()
}

let mockServers = [
    ServerDirectoryResponse.Server(
        name: "JG Test Broker",
        descriptionText: "Broker description\\n goes here",
        address: IPv4Address(192, 168, 1, 1),
        port: 8370,
        utilization: 0,
        capacity: 100,
        isEnabled: true
    ),
    ServerDirectoryResponse.Server(
        name: "Free Play",
        descriptionText: "Rookie Zone\\nAvatar ON",
        address: IPv4Address(192, 168, 1, 1),
        port: 8361,
        utilization: 50,
        capacity: 100,
        isEnabled: true
    ),
    ServerDirectoryResponse.Server(
        name: "Disabled Server",
        descriptionText: "Rookie Zone\\nAvatar ON",
        address: IPv4Address(192, 168, 1, 1),
        port: 8362,
        utilization: 50,
        capacity: 100,
        isEnabled: false
    ),
    ServerDirectoryResponse.Server(
        name: "Full Server",
        descriptionText: "Rookie Zone\\nAvatar ON",
        address: IPv4Address(192, 168, 1, 1),
        port: 8363,
        utilization: 100,
        capacity: 100,
        isEnabled: true
    ),
    ServerDirectoryResponse.Server(
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
    
    init(error: any Error) {
        self.result = .failure(error)
    }
    
    init(servers: [ServerDirectoryResponse.Server]) {
        self.result = .success(servers)
    }

    func fetchServerDirectory(address: String, brokerPort: UInt16) async throws -> [ServerDirectoryResponse.Server] {
        try await Task.sleep(for: .seconds(1))
        return try result.get()
    }
}

/// Preview body lives in a plain function (not the #Preview closure)
/// because tvOS's #Preview expands to a ViewBuilder closure that
/// rejects the explicit `return` this setup needs.
@MainActor
private func serverSelectScreenPreview() -> some View {
    let delegate = ScreenPreviewDelegate()
    let viewModel = ServerSelectViewModel(
        delegate: delegate,
        directoryFetcher: MockDirectoryFetcher(servers: mockServers)
    )
    return ScreenPreviewView(screen: ServerSelectScreen(viewModel: viewModel))
        .frame(width: 800, height: 600)
}
