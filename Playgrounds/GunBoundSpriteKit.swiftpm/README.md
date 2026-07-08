# GunBoundSpriteKit

An iOS App Playground proving `GunBoundClient`'s screens/view models are
genuinely renderer-agnostic: it implements `ClientRenderer`/`ClientAudioPlayer`
against SpriteKit/AVFoundation instead of SDL3, and reuses every `GameScreen`,
`ScreenViewModel`, and the `makeGameScreen`/`GameStateMachine` flow from
`GunBoundSDL3` completely unchanged.

## Running it (Mac or iPad)

This Playground is **self-contained**: the GunBound library targets and a
macro-free copy of `swift-binary-parsing` are *vendored* into the bundle
(rather than referenced via a `.package(path: "../..")` local dependency,
which can't be reached once the `.swiftpm` is copied to an iPad). Only
`Socket`, `CryptoSwift`, and `swift-argument-parser` are pulled by URL and
resolved over the network.

Before opening it — and before syncing/AirDropping it to an iPad — run the
vendoring script from a checkout of the full repo:

```sh
Playgrounds/copy-dependencies.sh
```

This copies `Sources/{GunBoundProtocol,GunBoundFile,GunBound,GunBoundClient}`,
a macro-stripped `BinaryParsing`, and the game assets into the bundle. All of
those are **gitignored**, so re-run the script after cloning. Then open
`GunBoundSpriteKit.swiftpm` in Swift Playgrounds (Mac or iPad) or Xcode.

> **Why the macro is stripped:** `swift-binary-parsing`'s `BinaryParsing`
> library depends on a `BinaryParsingMacros` swift-syntax *compiler plugin*,
> which Swift Playgrounds can't build (you'd hit
> `missing target … BinaryParsingMacros`). The only macro it provides
> (`#magicNumber`) is unused by both our code and BinaryParsing itself, so the
> script drops the `Macros/` folder and the manifest declares `BinaryParsing`
> as a plain target — the rest is pure Swift and builds on-device.

`.iOSApplication` (in `Package.swift`) needs `AppleProductTypes`, which only
Xcode / Swift Playgrounds provides — command-line `swift build` can't evaluate
this manifest. The vendored library targets were verified to build for the iOS
Simulator via an equivalent plain-package manifest.

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

## Login screen

The app opens on `LoginView` (username/password/server IP, defaulting to
`admin`/`1234`/`127.0.0.1`) instead of going straight into `GameScene`. Its
"Play" button first locates `AppModule/Resources/orig/` (checking both the
flattened-into-bundle-root and `Resources/`-subfolder layouts Xcode might
produce) and decodes `server_back.img` through it as a sanity check that the
whole XFS + LZHUF + `ImgFile` path actually works — only then does it hand
off to `GameSceneView`/`GameScene`. If the directory, `graphics.xfs`, or the
decode itself is missing/broken, it shows an alert with the specific problem
instead of silently failing once inside SpriteKit (where a missing archive
previously just printed to the console with nothing visible on screen).

## What it doesn't do

Same scope as `GunBoundSDL3`: no in-battle/game-session logic, no settings
UI — just the screen flow through Logo → Title → Server Select → Room List
(and Ready Room / Avatar Shop / Loading / In-Battle stand-in), driven by
touch instead of mouse/keyboard.
