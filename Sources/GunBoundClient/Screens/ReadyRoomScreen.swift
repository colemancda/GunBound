import CSDL3
import SDL3Swift
import GunBound

/// State 9 — Pre-battle Ready Room (`ready_selectmap.img`,
/// `ready_selectcharacter.img`, `b_ready_startgame.img`). Reached from the
/// Game Room List's "Create" button. No battle/session logic here — just
/// the map/character-select chrome plus a cancel button back to the room
/// list, matching the scope boundary (game session is out of scope).
@MainActor
final class ReadyRoomScreen: ImageBackgroundScreen {
    private var characterSelectTexture: SDLTexture?
    private var startButton: SDLTexture?
    private var cancelButton: SDLTexture?
    private var startRect = SDL_FRect(x: 0, y: 0, w: 0, h: 0)
    private var cancelRect = SDL_FRect(x: 0, y: 0, w: 0, h: 0)

    init() {
        super.init(backgroundImageName: "ready_selectmap.img", musicName: nil)
    }

    override func onEnter(context: ScreenContext) throws {
        try super.onEnter(context: context)
        characterSelectTexture = loadTexture(named: "ready_selectcharacter.img", context: context)
        startButton = loadTexture(named: "b_ready_startgame.img", context: context)
        cancelButton = loadTexture(named: "b_ready_cancel.img", context: context)

        if let startButton, let attributes = try? startButton.attributes() {
            startRect = SDL_FRect(x: 20, y: Float(600 - attributes.height - 20), w: Float(attributes.width), h: Float(attributes.height))
        }
        if let cancelButton, let attributes = try? cancelButton.attributes() {
            cancelRect = SDL_FRect(x: 20, y: Float(600 - attributes.height - 60), w: Float(attributes.width), h: Float(attributes.height))
        }
    }

    override func onExit() {
        characterSelectTexture = nil
        startButton = nil
        cancelButton = nil
        super.onExit()
    }

    override func handleEvent(_ event: SDLEvent, context: ScreenContext) {
        guard case .mouseButtonDown(_, let x, let y, _) = event else { return }
        if contains(cancelRect, x: x, y: y) {
            context.requestTransition(to: .gameRoomList)
        } else if contains(startRect, x: x, y: y) {
            context.requestTransition(to: .loading)
        }
    }

    override func render(_ renderer: SDLRenderer) throws {
        try super.render(renderer)
        if let characterSelectTexture {
            let attributes = try characterSelectTexture.attributes()
            try renderer.copy(characterSelectTexture, destination: SDL_FRect(x: 0, y: 0, w: Float(attributes.width), h: Float(attributes.height)))
        }
        if let startButton {
            try renderer.copy(startButton, destination: startRect)
        }
        if let cancelButton {
            try renderer.copy(cancelButton, destination: cancelRect)
        }
    }
}
