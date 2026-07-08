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

Unlike `GunBoundSDL3`, this can't read `graphics.xfs`/`sound.xfs`/etc. from an
arbitrary Mac filesystem path — the Simulator/device sandbox can't reach
`~/Developer/GunBound-Decomp/orig`. Instead, the archives are copied into
`AppModule/Resources/orig/` and bundled as an app resource; `GameScene.swift`
loads them from `Bundle.main.resourceURL` at runtime.

`AppModule/Resources/orig/` is **gitignored** (these are the original game's
binary assets, not something to commit) — after cloning, re-copy them with:

```sh
cp ~/Developer/GunBound-Decomp/orig/{graphics.xfs,sound.xfs,avatar.xfs,characterdata.dat,itemdata.dat,specialdata.dat,stage.dat} \
   Playgrounds/GunBoundSpriteKit.swiftpm/AppModule/Resources/orig/
```

before opening the Playground in Xcode, or the app will fail to find them at
runtime.

## What it doesn't do

Same scope as `GunBoundSDL3`: no in-battle/game-session logic, no settings
UI — just the screen flow through Logo → Title → Server Select → Room List
(and Ready Room / Avatar Shop / Loading / In-Battle stand-in), driven by
touch instead of mouse/keyboard.
