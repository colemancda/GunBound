import CSDL3
import SDL3Swift
import GunBound

/// View for Server / Channel select (state 2) — all connect/login logic
/// lives in `ServerSelectViewModel`; this loads/draws
/// `server_back.img`/`server_list.img`/`b_server_choiceserver.img`/
/// `waitmessage.img` and pushes the button's hit-testing rect (computed from
/// the loaded texture's size) into the view model.
@MainActor
final class ServerSelectScreen: GameScreen {
    private let viewModel: ServerSelectViewModel
    private let visuals = ScreenRenderHelper()
    private var panelTexture: SDLTexture?
    private var buttonTexture: SDLTexture?
    private var waitTexture: SDLTexture?

    init(viewModel: ServerSelectViewModel) {
        self.viewModel = viewModel
    }

    func onEnter(context: ScreenContext) throws {
        viewModel.onEnter()
        visuals.loadBackground(named: viewModel.backgroundImageName, context: context)
        if let musicName = viewModel.musicName {
            visuals.playMusic(named: musicName, context: context)
        }

        panelTexture = visuals.loadTexture(named: viewModel.panelImageName, context: context)

        buttonTexture = visuals.loadTexture(named: viewModel.buttonImageName, context: context)
        let (buttonWidth, buttonHeight) = size(of: buttonTexture)
        viewModel.buttonRect = Rect(x: 20, y: 600 - buttonHeight - 20, width: buttonWidth, height: buttonHeight)

        waitTexture = visuals.loadTexture(named: viewModel.waitImageName, context: context)
    }

    func onExit() {
        viewModel.onExit()
        visuals.unloadBackground()
        visuals.stopMusic()
        panelTexture = nil
        buttonTexture = nil
        waitTexture = nil
    }

    func handleEvent(_ event: SDLEvent, context: ScreenContext) {
        guard let input = translate(event) else { return }
        viewModel.handle(input)
    }

    func update(deltaTime: Double, context: ScreenContext) {
        if viewModel.loopMusic {
            visuals.updateMusicLoop()
        }
        viewModel.update(deltaTime: deltaTime)
    }

    func render(_ renderer: SDLRenderer) throws {
        try visuals.clearAndDrawBackground(renderer)
        if let panelTexture {
            try renderer.copy(panelTexture, destination: nativeRect(of: panelTexture))
        }
        if let buttonTexture {
            try renderer.copy(buttonTexture, destination: sdlRect(viewModel.buttonRect))
        }
        if viewModel.isConnecting, let waitTexture {
            let (width, height) = size(of: waitTexture)
            let destination = SDL_FRect(x: (800 - width) / 2, y: (600 - height) / 2, w: width, h: height)
            try renderer.copy(waitTexture, destination: destination)
        }
    }
}
