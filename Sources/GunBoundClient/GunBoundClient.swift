import ArgumentParser
import Foundation
import CSDL3
import SDL3Swift
import SDL3Mixer
import GunBound

/// The fixed logical canvas — matches the decomp's confirmed fullscreen
/// exclusive resolution (`ARCHITECTURE.md`: "fullscreen = hardcoded 800×600").
let windowWidth: Int32 = 800
let windowHeight: Int32 = 600

@main
struct GunBoundClient: ParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "GunBoundClient",
        abstract: "Native SDL3 GunBound client (GUI shell + asset loading; no game session yet)."
    )

    @Option(help: "Directory containing graphics.xfs, sound.xfs, avatar.xfs, and the .dat game-data files.")
    var assetsPath: String = ("~/Developer/GunBound-Decomp/orig" as NSString).expandingTildeInPath

    @Flag(help: "Run in fullscreen instead of a window.")
    var fullscreen: Bool = false

    mutating func run() throws {
        try MainActor.assumeIsolated {
            try runClient(assetsDirectory: URL(fileURLWithPath: assetsPath, isDirectory: true), fullscreen: fullscreen)
        }
    }
}

@MainActor
func runClient(assetsDirectory: URL, fullscreen: Bool) throws {
    try SDL.initialize(subSystems: [.video, .audio, .events])
    defer { SDL.quit() }
    try SDL.initializeMixer()
    defer { SDL.quitMixer() }

    var windowOptions: BitMaskOptionSet<SDLWindow.Option> = [.highPixelDensity]
    if fullscreen { windowOptions.insert(.fullscreen) }

    let window = try SDLWindow(
        title: "GunBound",
        frame: (x: .centered, y: .centered, width: Int(windowWidth), height: Int(windowHeight)),
        options: windowOptions
    )
    let renderer = try SDLRenderer(window: window)
    try renderer.setLogicalSize(width: windowWidth, height: windowHeight, presentation: .letterbox)

    let mixer = try SDLMixer()
    let assets = AssetLibrary(directory: assetsDirectory)
    let context = ScreenContext(assets: assets, renderer: renderer, mixer: mixer)

    let stateMachine = try GameStateMachine(context: context, initialMode: .logo1) { mode in
        switch mode {
        case .logo1:
            return LogoScreen(imageName: "logomode.img", musicName: "logo.mp3", next: .logo2)
        case .logo2:
            return LogoScreen(imageName: "logomode2.img", musicName: "logo2.mp3", next: .title)
        case .title:
            return TitleScreen()
        case .serverSelect:
            return ServerSelectScreen()
        case .gameRoomList:
            return GameRoomListScreen()
        default:
            return nil
        }
    }

    var running = true
    var lastTicks = SDL.ticks
    while running {
        while let event = SDL.pollEvent() {
            switch event {
            case .quit:
                running = false
            case .keyDown(let scancode, _) where scancode.rawValue == SDL_SCANCODE_ESCAPE.rawValue:
                running = false
            default:
                stateMachine.handleEvent(event)
            }
        }

        let now = SDL.ticks
        let deltaTime = Double(now - lastTicks) / 1_000_000_000
        lastTicks = now

        try stateMachine.update(deltaTime: deltaTime)
        try stateMachine.render()
    }
}
