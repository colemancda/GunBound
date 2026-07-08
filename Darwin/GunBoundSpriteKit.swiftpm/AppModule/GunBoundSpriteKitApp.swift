import SwiftUI
import SpriteKit
import GunBound

@main
struct GunBoundSpriteKitApp: App {
    var body: some Scene {
        WindowGroup {
            LoginView()
        }
    }
}

/// Hosts `GameScene` once `LoginView` has confirmed the assets directory
/// exists and decodes real data.
struct GameSceneView: View {
    private let scene: GameScene

    init(assetsDirectory: URL, network: NetworkConfig) {
        let scene = GameScene()
        scene.scaleMode = .aspectFit
        scene.assetsDirectory = assetsDirectory
        scene.network = network
        self.scene = scene
    }

    var body: some View {
        SpriteView(scene: scene)
    }
}
