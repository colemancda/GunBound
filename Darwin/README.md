# GunBound Darwin port (macOS/tvOS)

`GunBound.xcodeproj` — `GunBound-macOS` and `GunBound-tvOS` app targets, both
rendering through **SpriteKit**, mirroring junkbot-swift's `ports/Darwin`
layout. iOS lives separately in `../Playgrounds/GunBoundSpriteKit.swiftpm` (an
App Playground that also runs in Swift Playgrounds on iPad — see its README).

## What's shared vs. Darwin-only

- **Shared with the iOS Playground** (file references pointing directly at
  `../Playgrounds/GunBoundSpriteKit.swiftpm/AppModule/*.swift`):
  `SpriteKitRenderer.swift`, `SpriteKitAudioPlayer.swift`, and
  `GameScene.swift` (which carries both the UIKit touch handlers and the
  `#if os(macOS)` mouse handlers). The SwiftUI pieces (`LoginView.swift`,
  `GunBoundSpriteKitApp.swift`) are **not** shared — they're iOS-flavored
  SwiftUI; the Darwin targets use pure-code app delegates instead.
- **Darwin-only** (`Sources/GunBoundDarwin/`): `DarwinShell.swift` (asset
  location + `UserDefaults`-backed network config, same `login.*` keys the
  Playground's `LoginView` persists), `AppDelegate_macOS.swift` (pure-code
  AppKit window/`SKView`, including the `static func main()` override a
  storyboard-less `NSApplicationDelegate` needs), `AppDelegate_tvOS.swift` +
  `GameViewController.swift` (the UIKit equivalent).
- The project consumes `GunBound`/`GunBoundProtocol`/`GunBoundFile`/
  `GunBoundClient` via a **local Swift Package reference to the repo root** —
  no vendoring; edits to `Sources/` show up immediately.

## Assets

- **macOS** reads `~/Developer/GunBound-Decomp/orig` directly (same default as
  `GunBoundSDL3`), falling back to bundled resources if present. Nothing to
  copy for local dev.
- **tvOS** has no filesystem to read from, so its target bundles the
  Playground's `AppModule/Resources` folder (a folder reference). That folder
  is gitignored — run `../Playgrounds/copy-dependencies.sh` **before building
  the tvOS target** or the resource-copy phase will fail.

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
