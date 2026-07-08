# GunBoundSpriteKit

An iOS App Playground proving `GunBoundClient`'s screens/view models are
genuinely renderer-agnostic: it implements `ClientRenderer`/`ClientAudioPlayer`
against SpriteKit/AVFoundation instead of SDL3, and reuses every `GameScreen`,
`ScreenViewModel`, and the `makeGameScreen`/`GameStateMachine` flow from
`GunBoundSDL3` completely unchanged.

## Opening it

Open `GunBoundSpriteKit.swiftpm` directly in Xcode (or the Swift Playgrounds
app on a Mac). It depends on the main `GunBound` package via a local path
(`../..`), so it only resolves when this `.swiftpm` bundle stays inside a
checkout of the full repo — it won't resolve standalone.

`.iOSApplication` (in `Package.swift`) is an Xcode-only manifest extension
(`AppleProductTypes`) — `swift build`/`swift package resolve` from the
command line can't evaluate this manifest at all; it has to be opened in
Xcode. The four Swift source files under `AppModule/` were still typechecked
independently against an iOS Simulator SDK build of `GunBound`/
`GunBoundClient` to catch real errors ahead of time.

## Assets

Like `GunBoundSDL3`, this reads `graphics.xfs`/`sound.xfs`/etc. from a
filesystem path — `GameScene.swift` hardcodes
`/Users/coleman/Developer/GunBound-Decomp/orig`. That only resolves when run
in the **iOS Simulator on this Mac** (the Simulator shares the host's real
filesystem); a real device has no such path and would need the assets bundled
into the app instead (out of scope for this proof-of-concept — see the
in-source comment).

## What it doesn't do

Same scope as `GunBoundSDL3`: no in-battle/game-session logic, no settings
UI — just the screen flow through Logo → Title → Server Select → Room List
(and Ready Room / Avatar Shop / Loading / In-Battle stand-in), driven by
touch instead of mouse/keyboard.
