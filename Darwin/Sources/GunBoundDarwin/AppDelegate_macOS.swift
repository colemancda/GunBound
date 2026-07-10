#if os(macOS)
import Cocoa
import SwiftUI

/// macOS-only: creates the window and hosts the shared SwiftUI `LoginView`
/// (username/password/server IP → asset check → `GameSceneView`), the same
/// entry flow as the iOS Playground. See `AppDelegate_tvOS.swift` for the
/// UIKit equivalent.
@main
final class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!

    /// Overrides `NSApplicationDelegate`'s default `@main`-compatible
    /// `static func main()` (which just calls the classic `NSApplicationMain`
    /// C entry point) — that default relies on a storyboard/nib to
    /// instantiate the delegate and assign it to `NSApp.delegate`, and this
    /// project has neither (pure-code app). Without this override
    /// `NSApp.delegate` stays `nil`, `applicationDidFinishLaunching` never
    /// runs, and the app sits in its event loop with zero windows — the same
    /// pitfall junkbot-swift's Darwin port documents from lldb.
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildMainMenu()

        // The decomp-confirmed fixed 800×600 logical canvas, same as every
        // other GunBound front end.
        let contentRect = NSRect(x: 0, y: 0, width: 800, height: 600)
        window = NSWindow(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered, defer: false)
        window.title = "GunBound"
        window.contentMinSize = contentRect.size
        window.center()
        // GameScene's hover highlighting relies on `mouseMoved` events, which
        // windows don't deliver by default.
        window.acceptsMouseMovedEvents = true

        window.contentView = NSHostingView(rootView: LoginView())

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    // MARK: Main menu

    /// Builds the menu bar in code (no storyboard/nib): the app menu with
    /// Quit, and a Sound menu whose Mute item (⇧⌘M) toggles the persisted
    /// mute preference and applies it to everything currently playing.
    private func buildMainMenu() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenu.addItem(
            withTitle: "Quit GunBound",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        appMenuItem.submenu = appMenu

        let soundMenuItem = NSMenuItem()
        mainMenu.addItem(soundMenuItem)
        let soundMenu = NSMenu(title: "Sound")
        let mute = NSMenuItem(title: "Mute", action: #selector(toggleMute(_:)), keyEquivalent: "m")
        mute.keyEquivalentModifierMask = [.command, .shift]
        mute.target = self
        mute.state = SpriteKitAudioPlayer.isMuted ? .on : .off
        soundMenu.addItem(mute)
        soundMenuItem.submenu = soundMenu

        NSApp.mainMenu = mainMenu
    }

    @objc private func toggleMute(_ sender: NSMenuItem) {
        let muted = !SpriteKitAudioPlayer.isMuted
        SpriteKitAudioPlayer.setMuted(muted)
        sender.state = muted ? .on : .off
    }
}
#endif
