#if os(tvOS)
import UIKit
import SwiftUI

/// tvOS-only: hosts the shared SwiftUI `LoginView` (username/password/server
/// IP → asset check → `GameSceneView`) as the window's root view controller
/// directly (no storyboard) — the UIKit counterpart of
/// `AppDelegate_macOS.swift`, with the same entry flow as the iOS Playground.
@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = UIHostingController(rootView: LoginView())
        window.makeKeyAndVisible()
        self.window = window
        return true
    }
}
#endif
