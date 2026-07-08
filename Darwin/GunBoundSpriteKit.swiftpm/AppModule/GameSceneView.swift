import SwiftUI
import SpriteKit
import GunBound

/// Hosts `GameScene` once `LoginView` has confirmed the assets directory
/// exists and decodes real data. In its own file (not the Playground's
/// `@main` app file) so the Darwin macOS/tvOS targets can compile it too.
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
