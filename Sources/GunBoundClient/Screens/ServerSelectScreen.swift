import GunBound

/// View for Server / Channel select (state 2) — all connect/login logic
/// lives in `ServerSelectViewModel`; this loads/draws
/// `server_back.img`/`server_list.img`/`b_server_choiceserver.img`/
/// `waitmessage.img` and pushes the button's hit-testing rect (computed from
/// the loaded texture's size) into the view model.
@MainActor
public final class ServerSelectScreen: GameScreen {
    private let viewModel: ServerSelectViewModel
    private var backgroundTexture: ClientTexture?
    private var panelTexture: ClientTexture?
    private var buttonTexture: ClientTexture?
    private var waitTexture: ClientTexture?
    private var audio: ClientAudioPlayer?

    public init(viewModel: ServerSelectViewModel) {
        self.viewModel = viewModel
    }

    public func onEnter(context: ClientContext) throws {
        viewModel.onEnter()
        backgroundTexture = context.renderer.texture(named: viewModel.backgroundImageName, assets: context.assets)
        if let musicName = viewModel.musicName {
            let audio = context.makeAudioPlayer()
            audio.play(named: musicName, assets: context.assets, loop: viewModel.loopMusic)
            self.audio = audio
        }

        panelTexture = context.renderer.texture(named: viewModel.panelImageName, assets: context.assets)

        buttonTexture = context.renderer.texture(named: viewModel.buttonImageName, assets: context.assets)
        let (buttonWidth, buttonHeight) = context.renderer.size(of: buttonTexture)
        viewModel.buttonRect = Rect(x: 20, y: 600 - buttonHeight - 20, width: buttonWidth, height: buttonHeight)

        waitTexture = context.renderer.texture(named: viewModel.waitImageName, assets: context.assets)
    }

    public func onExit() {
        viewModel.onExit()
        backgroundTexture = nil
        panelTexture = nil
        buttonTexture = nil
        waitTexture = nil
        audio?.stop()
        audio = nil
    }

    public func handleInput(_ event: ScreenInputEvent) {
        viewModel.handle(event)
    }

    public func update(deltaTime: Double) {
        audio?.update(deltaTime: deltaTime)
        viewModel.update(deltaTime: deltaTime)
    }

    public func render(_ renderer: ClientRenderer) throws {
        renderer.clear()
        drawFullSize(backgroundTexture, using: renderer)
        drawFullSize(panelTexture, using: renderer)
        if let buttonTexture {
            renderer.draw(buttonTexture, in: viewModel.buttonRect, tint: nil)
        }
        if viewModel.isConnecting, let waitTexture {
            let (width, height) = renderer.size(of: waitTexture)
            let rect = Rect(x: (800 - width) / 2, y: (600 - height) / 2, width: width, height: height)
            renderer.draw(waitTexture, in: rect, tint: nil)
        }
    }
}
