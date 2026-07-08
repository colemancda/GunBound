#if os(macOS)
import Cocoa
import SpriteKit

/// macOS-only: creates the window/`SKView`/`GameScene`. See
/// `AppDelegate_tvOS.swift` + `GameViewController.swift` for the UIKit
/// equivalent.
@main
final class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!

    /// Overrides `NSApplicationDelegate`'s default `@main`-compatible
    /// `static func main()` (which just calls the classic `NSApplicationMain`
    /// C entry point) — that default relies on a storyboard/nib to
    /// instantiate the delegate and assign it to `NSApp.delegate`, and this
    /// project has neither (pure-code SpriteKit app). Without this override
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

        let view = SKView(frame: contentRect)
        view.autoresizingMask = [.width, .height]
        window.contentView = view

        guard let scene = DarwinShell.makeScene() else {
            let alert = NSAlert()
            alert.messageText = "Couldn't load game assets"
            alert.informativeText = "graphics.xfs wasn't found. Place the original archives at ~/Developer/GunBound-Decomp/orig (or bundle them by running Playgrounds/copy-dependencies.sh before building)."
            alert.runModal()
            NSApp.terminate(nil)
            return
        }
        view.presentScene(scene)

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
#endif
