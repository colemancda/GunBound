import ArgumentParser
import Foundation
import CSDL3
import SDL3Swift
import SDL3Mixer
import GunBound
import GunBoundClient
#if canImport(AppKit)
import AppKit
#endif

/// The fixed logical canvas — matches the decomp's confirmed fullscreen
/// exclusive resolution (`ARCHITECTURE.md`: "fullscreen = hardcoded 800×600").
let windowWidth: Int32 = 800
let windowHeight: Int32 = 600

@main
struct GunBoundSDL3: ParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "GunBoundSDL3",
        abstract: "Native SDL3 GunBound client"
    )

    @Option(help: "Directory containing graphics.xfs, sound.xfs, avatar.xfs, and the .dat game-data files.")
    var assetsPath: String?

    @Flag(help: "Run in fullscreen instead of a window.")
    var fullscreen: Bool = false

    @Option(help: "Username to log in with. (Will move to a settings file in the future.)")
    var username: String = "admin"

    @Option(help: "Password to log in with. (Will move to a settings file in the future.)")
    var password: String = "admin"

    @Option(help: "GunBound world server address to connect to.")
    var server: String = "127.0.0.1"

    @Option(help: "GunBound world server port to connect to (used directly if the broker can't be reached).")
    var port: UInt16 = 8370

    @Option(help: "GunBound broker/directory server port — looked up first for the list of world servers.")
    var brokerPort: UInt16 = 8372

    mutating func run() throws {
        let assetsPath = assetsPath ?? FileManager.default.currentDirectoryPath
        let network = NetworkConfig(username: username, password: password, serverAddress: server, serverPort: port, brokerPort: brokerPort)
        try MainActor.assumeIsolated {
            try runClient(assetsDirectory: URL(fileURLWithPath: assetsPath, isDirectory: true), fullscreen: fullscreen, network: network)
        }
    }
}

@MainActor
func runClient(assetsDirectory: URL, fullscreen: Bool, network: NetworkConfig) throws {
    try SDL.initialize(subSystems: [.video, .audio, .events, .gamepad])
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
    let sdlRenderer = try SDLRenderer(window: window)
    try sdlRenderer.setLogicalSize(width: windowWidth, height: windowHeight, presentation: .letterbox)

    // A bare (non-bundled) executable launched under a debugger (e.g. Xcode's
    // "Run") doesn't reliably become the frontmost/key app the way it does
    // when double-clicked or run from Terminal — without this, the window
    // appears but never receives mouse/keyboard events, which looks exactly
    // like the app being "stuck" on the first screen that requires input
    // (Title, since Logo1/Logo2 auto-advance on a timer regardless).
    #if canImport(AppKit)
    NSApp.setActivationPolicy(.regular)
    NSApp.activate(ignoringOtherApps: true)
    #endif
    window.raise()

    let mixer = try SDLMixer()
    let assets = AssetLibrary(directory: assetsDirectory)
    let renderer = SDL3Renderer(renderer: sdlRenderer)
    let context = ClientContext(assets: assets, renderer: renderer, network: network) {
        SDL3AudioPlayer(mixer: mixer)
    }

    let stateMachine = try GameStateMachine(context: context, initialMode: .logo1) { [unowned context] mode in
        makeGameScreen(for: mode, delegate: context)
    }

    // Hide the OS cursor and draw the game's own `cursor.img` pointer instead
    // (matching the original's `ShowCursor(0)` + software-blitted cursor).
    SDL.isCursorVisible = false
    stateMachine.cursor.isVisible = true

    // The first connected gamepad drives the virtual cursor (left stick +
    // South/"A" to click). Opened on connect, released on disconnect.
    var gamepad: SDLGamepad?

    var running = true
    var lastTicks = SDL.ticks
    while running {
        while let event = SDL.pollEvent() {
            switch event {
            case .quit:
                running = false
            case .keyDown(let scancode, _) where scancode.rawValue == SDL_SCANCODE_ESCAPE.rawValue:
                running = false
            case .gamepadAdded(let which):
                if gamepad == nil {
                    gamepad = try? SDLGamepad(joystickID: which)
                }
            case .gamepadRemoved:
                gamepad = nil
            default:
                if let input = translate(event) {
                    stateMachine.handleInput(input)
                }
            }
        }

        let now = SDL.ticks
        let deltaTime = Double(now - lastTicks) / 1_000_000_000
        lastTicks = now

        // Feed the left stick to the virtual cursor. Axes are Int16; the
        // South face button ("A" / cross) is the click.
        if let gamepad {
            let scale: Float = 1.0 / 32767
            stateMachine.applyGamepad(
                stickX: Float(gamepad.axis(.leftX)) * scale,
                stickY: Float(gamepad.axis(.leftY)) * scale,
                click: gamepad.isPressed(.south),
                deltaTime: deltaTime
            )
        }

        try stateMachine.update(deltaTime: deltaTime)
        try stateMachine.render()

        // Screens request quitting through the context (e.g. Server
        // Select's EXIT button).
        if context.quitRequested {
            running = false
        }
    }
}
