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

    public init(context: ClientContext, initialMode: ClientMode, makeScreen: @escaping (ClientMode) -> GameScreen?) throws {
        self.context = context
        self.makeScreen = makeScreen
        guard let screen = makeScreen(initialMode) else {
            fatalError("No screen registered for initial mode \(initialMode)")
        }
        self.current = screen
        print("[GunBoundClient] entering screen: \(initialMode)")
        try current.onEnter(context: context)
    }

    public func handleInput(_ event: ScreenInputEvent) {
        current.handleInput(event)
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
        context.renderer.present()
    }
}
