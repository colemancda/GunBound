#if canImport(UIKit)
import UIKit
import SpriteKit

/// Hosts the `SKView`/`GameScene` — used by the tvOS target's
/// `AppDelegate_tvOS.swift` as the window's root view controller (mirroring
/// junkbot-swift's Darwin port, where the same controller is also reusable
/// from a SwiftUI `UIViewControllerRepresentable` if needed).
final class GameViewController: UIViewController {

    override func loadView() {
        view = SKView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        guard let view = view as? SKView else { return }
        guard let scene = DarwinShell.makeScene() else {
            let label = UILabel()
            label.text = "Couldn't load game assets — run Darwin/copy-dependencies.sh and rebuild."
            label.numberOfLines = 0
            label.textAlignment = .center
            label.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(label)
            NSLayoutConstraint.activate([
                label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
                label.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 40),
                label.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -40),
            ])
            return
        }
        view.presentScene(scene)
    }
}
#endif
