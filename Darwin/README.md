# GunBound Darwin port (macOS/tvOS)

`GunBound.xcodeproj` — `GunBound-macOS` and `GunBound-tvOS` app targets, both
rendering through **SpriteKit**, mirroring junkbot-swift's `ports/Darwin`
layout. iOS lives alongside in `GunBoundSpriteKit.swiftpm` (an App Playground
that also runs in Swift Playgrounds on iPad — see its README).

## What's shared vs. Darwin-only

- **Shared with the iOS Playground** (file references pointing directly at
  `GunBoundSpriteKit.swiftpm/AppModule/*.swift`):
  `SpriteKitRenderer.swift`, `SpriteKitAudioPlayer.swift`, `GameScene.swift`
  (which carries both the UIKit touch handlers and the `#if os(macOS)` mouse
  handlers), **`LoginView.swift` + `GameSceneView.swift`** (the SwiftUI entry
  flow — username/password/server IP, asset check, then the game scene; the
  iOS-only modifiers are platform-guarded), and the `Screens/` preview files.
  Only the Playground's `@main` `GunBoundSpriteKitApp.swift` is not shared —
  each Darwin target has its own app delegate instead.
- **Darwin-only** (`Sources/GunBoundDarwin/`): `AppDelegate_macOS.swift`
  (pure-code AppKit window hosting `LoginView` via `NSHostingView`, including
  the `static func main()` override a storyboard-less
  `NSApplicationDelegate` needs) and `AppDelegate_tvOS.swift` (the UIKit
  equivalent, via `UIHostingController`).
- The project consumes `GunBound`/`GunBoundProtocol`/`GunBoundFile`/
  `GunBoundClient` via a **local Swift Package reference to the repo root** —
  no vendoring; edits to `Sources/` show up immediately.

## Assets

Both targets bundle the Playground's `AppModule/Resources` folder (a folder
reference) into the app, so the built `.app` is self-contained on macOS and
tvOS alike. That folder is gitignored — run
`Darwin/copy-dependencies.sh` **before building** or the
resource-copy phase will fail. On macOS, if the bundle copy is somehow absent
at runtime, the app additionally falls back to reading
`~/Developer/GunBound-Decomp/orig` directly (same default as `GunBoundSDL3`).

## Server configuration

Both targets read login/server settings from `UserDefaults` (defaults
`admin`/`1234`/`127.0.0.1`):

```sh
defaults write org.pureswift.GunBound.macos login.serverIP 192.168.1.247
```

## Building from the command line

```sh
xcodebuild -project Darwin/GunBound.xcodeproj -scheme GunBound-macOS build
xcodebuild -project Darwin/GunBound.xcodeproj -scheme GunBound-tvOS \
  -destination 'generic/platform=tvOS Simulator' build
```
