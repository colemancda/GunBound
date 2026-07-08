import GunBound

/// View for the pre-battle Ready Room (state 9) — cancel/start hit-testing
/// logic lives in `ReadyRoomViewModel`; this loads
/// `ready_selectmap.img`/`ready_selectcharacter.img`/
/// `b_ready_startgame.img`/`b_ready_cancel.img` and pushes the button rects.
@MainActor
public final class ReadyRoomScreen: GameScreen {
    private let viewModel: ReadyRoomViewModel
    private var backgroundTexture: ClientTexture?
    private var characterSelectTexture: ClientTexture?
    private var startTexture: ClientTexture?
    private var cancelTexture: ClientTexture?

    public init(viewModel: ReadyRoomViewModel) {
        self.viewModel = viewModel
    }

    public func onEnter(context: ClientContext) throws {
        viewModel.onEnter()
        backgroundTexture = context.renderer.texture(named: viewModel.backgroundImageName, assets: context.assets)
        characterSelectTexture = context.renderer.texture(named: viewModel.characterSelectImageName, assets: context.assets)

        startTexture = context.renderer.texture(named: viewModel.startButtonImageName, assets: context.assets)
        let (startWidth, startHeight) = context.renderer.size(of: startTexture)
        viewModel.startRect = Rect(x: 20, y: 600 - startHeight - 20, width: startWidth, height: startHeight)

        cancelTexture = context.renderer.texture(named: viewModel.cancelButtonImageName, assets: context.assets)
        let (cancelWidth, cancelHeight) = context.renderer.size(of: cancelTexture)
        viewModel.cancelRect = Rect(x: 20, y: 600 - cancelHeight - 60, width: cancelWidth, height: cancelHeight)
    }

    public func onExit() {
        viewModel.onExit()
        backgroundTexture = nil
        characterSelectTexture = nil
        startTexture = nil
        cancelTexture = nil
    }

    public func handleInput(_ event: ScreenInputEvent) {
        viewModel.handle(event)
    }

    public func update(deltaTime: Double) {
        viewModel.update(deltaTime: deltaTime)
    }

    public func render(_ renderer: ClientRenderer) throws {
        renderer.clear()
        drawFullSize(backgroundTexture, using: renderer)
        drawFullSize(characterSelectTexture, using: renderer)
        if let startTexture {
            renderer.draw(startTexture, in: viewModel.startRect, tint: nil)
        }
        if let cancelTexture {
            renderer.draw(cancelTexture, in: viewModel.cancelRect, tint: nil)
        }
    }
}
