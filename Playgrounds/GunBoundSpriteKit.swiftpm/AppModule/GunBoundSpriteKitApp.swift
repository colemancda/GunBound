import SwiftUI
import SpriteKit

@main
struct GunBoundSpriteKitApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    private let scene: GameScene = {
        let scene = GameScene()
        scene.scaleMode = .aspectFit
        return scene
    }()

    var body: some View {
        SpriteView(scene: scene)
            .ignoresSafeArea()
            .statusBarHidden()
    }
}
