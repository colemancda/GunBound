import CSDL3
import SDL3Swift
import GunBound

/// View for the pre-battle Ready Room (state 9) — cancel/start hit-testing
/// logic lives in `ReadyRoomViewModel`; this loads
/// `ready_selectmap.img`/`ready_selectcharacter.img`/
/// `b_ready_startgame.img`/`b_ready_cancel.img` and pushes the button rects.
@MainActor
final class ReadyRoomScreen: GameScreen {
    private let viewModel: ReadyRoomViewModel
    private let visuals = ScreenRenderHelper()
    private var characterSelectTexture: SDLTexture?
    private var startTexture: SDLTexture?
    private var cancelTexture: SDLTexture?

    init(viewModel: ReadyRoomViewModel) {
        self.viewModel = viewModel
    }

    func onEnter(context: ScreenContext) throws {
        viewModel.onEnter()
        visuals.loadBackground(named: viewModel.backgroundImageName, context: context)
        characterSelectTexture = visuals.loadTexture(named: viewModel.characterSelectImageName, context: context)

        startTexture = visuals.loadTexture(named: viewModel.startButtonImageName, context: context)
        let (startWidth, startHeight) = size(of: startTexture)
        viewModel.startRect = Rect(x: 20, y: 600 - startHeight - 20, width: startWidth, height: startHeight)

        cancelTexture = visuals.loadTexture(named: viewModel.cancelButtonImageName, context: context)
        let (cancelWidth, cancelHeight) = size(of: cancelTexture)
        viewModel.cancelRect = Rect(x: 20, y: 600 - cancelHeight - 60, width: cancelWidth, height: cancelHeight)
    }

    func onExit() {
        viewModel.onExit()
        visuals.unloadBackground()
        characterSelectTexture = nil
        startTexture = nil
        cancelTexture = nil
    }

    func handleEvent(_ event: SDLEvent, context: ScreenContext) {
        guard let input = translate(event) else { return }
        viewModel.handle(input)
    }

    func update(deltaTime: Double, context: ScreenContext) {
        viewModel.update(deltaTime: deltaTime)
    }

    func render(_ renderer: SDLRenderer) throws {
        try visuals.clearAndDrawBackground(renderer)
        if let characterSelectTexture {
            try renderer.copy(characterSelectTexture, destination: nativeRect(of: characterSelectTexture))
        }
        if let startTexture {
            try renderer.copy(startTexture, destination: sdlRect(viewModel.startRect))
        }
        if let cancelTexture {
            try renderer.copy(cancelTexture, destination: sdlRect(viewModel.cancelRect))
        }
    }
}
