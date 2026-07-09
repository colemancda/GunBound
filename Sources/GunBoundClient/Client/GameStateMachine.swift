import GunBound

/// Drives the current screen and swaps to the next one once requested,
/// logging each transition (Logo1 -> Logo2 -> Title -> ServerSelect ->
/// RoomList) so the flow can be verified from the console. Backend-agnostic:
/// callers (e.g. a `GunBoundSDL3` main loop) poll their own input source,
/// translate it into `ScreenInputEvent`s, and drive `update`/`render` each
/// frame.
@MainActor
public final class GameStateMachine {
    private let context: ClientContext
    private let makeScreen: (ClientMode) -> GameScreen?
    public private(set) var current: GameScreen

    /// The custom software pointer, drawn on top of every screen. Off by
    /// default; a backend that hides its OS cursor sets `cursor.isVisible`
    /// (desktop) — touch platforms leave it hidden. The sprite is preloaded
    /// here to mirror the original preloading `cursor.img` on state changes.
    public let cursor = SoftwareCursor()

    /// Drives `cursor` from a gamepad's left stick; a backend polls its pad
    /// each frame and calls `applyGamepad(...)`.
    public let gamepadCursor = GamepadCursor()

    public init(context: ClientContext, initialMode: ClientMode, makeScreen: @escaping (ClientMode) -> GameScreen?) throws {
        self.context = context
        self.makeScreen = makeScreen
        guard let screen = makeScreen(initialMode) else {
            fatalError("No screen registered for initial mode \(initialMode)")
        }
        self.current = screen
        cursor.isVisible = false
        cursor.texture = context.renderer.texture(named: SoftwareCursor.sheetName, frame: 0, assets: context.assets)
        print("[GunBoundClient] entering screen: \(initialMode)")
        try current.onEnter(context: context)
    }

    public func handleInput(_ event: ScreenInputEvent) {
        // Track the pointer so the software cursor follows it.
        switch event {
        case let .pointerMoved(x, y), let .pointerDown(x, y), let .pointerUp(x, y):
            cursor.position = (x, y)
        case .activate, .text, .key, .scroll:
            break
        }
        current.handleInput(event)
    }

    /// Feeds one frame of gamepad state to the virtual cursor: the left-stick
    /// vector (each axis `-1...1`, y downward) moves the pointer and the click
    /// button synthesizes a press. Reveals the software cursor the first time
    /// the stick is used, then routes the synthesized events like real input.
    public func applyGamepad(stickX: Float, stickY: Float, click: Bool, deltaTime: Double) {
        let events = gamepadCursor.update(
            stickX: stickX, stickY: stickY, click: click,
            deltaTime: deltaTime, position: &cursor.position
        )
        if !events.isEmpty {
            cursor.isVisible = true
        }
        for event in events {
            current.handleInput(event)
        }
    }

    public func update(deltaTime: Double) throws {
        current.update(deltaTime: deltaTime)
        if let nextMode = context.consumePendingTransition() {
            guard let nextScreen = makeScreen(nextMode) else {
                print("[GunBoundClient] no screen registered for mode \(nextMode), ignoring transition")
                return
            }
            current.onExit()
            current = nextScreen
            print("[GunBoundClient] entering screen: \(nextMode)")
            try current.onEnter(context: context)
        }
    }

    public func render() throws {
        try current.render(context.renderer)
        // The custom pointer draws last, over all screen content — exactly
        // where the original blits it at the end of each frame.
        cursor.draw(context.renderer)
        context.renderer.present()
    }
}
