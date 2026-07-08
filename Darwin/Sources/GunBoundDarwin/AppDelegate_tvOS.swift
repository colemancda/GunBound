#if os(tvOS)
import UIKit

/// tvOS-only: sets `GameViewController` as the window's root view controller
/// directly (no storyboard) — the UIKit counterpart of
/// `AppDelegate_macOS.swift`.
@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = GameViewController()
        window.makeKeyAndVisible()
        self.window = window
        return true
    }
}
#endif
