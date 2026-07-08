import CSDL3
import SDL3Swift
import GunBound

/// State 3 — Game Room List / channel lobby (`gamelist_back.img`,
/// `gamelist_create.img`, `b_gamelist_join/ranking/avatar/buddy.img`).
/// "Create" and "Avatar" transition locally to the Ready Room / Avatar Shop
/// screens; "Join"/"Ranking"/"Buddy" have no local-only screen to go to
/// (they're server-driven lists/dialogs) so they just log the click — none
/// of this is wired to any protocol packets yet (no networking here).
///
/// Button screen positions aren't reverse-engineered in the decomp docs, so
/// they're laid out in a simple row along the bottom of the window purely to
/// be visible/clickable, not claimed pixel-accurate to the original layout.
@MainActor
final class GameRoomListScreen: ImageBackgroundScreen {
    private struct Button {
        let name: String
        var texture: SDLTexture?
        var rect: SDL_FRect
    }

    private static let emptyRect = SDL_FRect(x: 0, y: 0, w: 0, h: 0)

    private var buttons: [Button] = [
        Button(name: "gamelist_create.img", texture: nil, rect: emptyRect),
        Button(name: "b_gamelist_join.img", texture: nil, rect: emptyRect),
        Button(name: "b_gamelist_ranking.img", texture: nil, rect: emptyRect),
        Button(name: "b_gamelist_avatar.img", texture: nil, rect: emptyRect),
        Button(name: "b_gamelist_buddy.img", texture: nil, rect: emptyRect),
    ]
    private var hoveredIndex: Int?

    init() {
        super.init(backgroundImageName: "gamelist_back.img", musicName: nil)
    }

    override func onEnter(context: ScreenContext) throws {
        try super.onEnter(context: context)
        var x: Float = 20
        let y: Float = 540
        for i in buttons.indices {
            guard let texture = loadTexture(named: buttons[i].name, context: context) else { continue }
            let attributes = try? texture.attributes()
            let width = Float(attributes?.width ?? 0)
            let height = Float(attributes?.height ?? 0)
            buttons[i].texture = texture
            buttons[i].rect = SDL_FRect(x: x, y: y, w: width, h: height)
            x += width + 10
        }
    }

    override func onExit() {
        for i in buttons.indices {
            buttons[i].texture = nil
        }
        hoveredIndex = nil
        super.onExit()
    }

    override func handleEvent(_ event: SDLEvent, context: ScreenContext) {
        switch event {
        case .mouseMotion(_, let x, let y, _):
            hoveredIndex = buttons.firstIndex { contains($0.rect, x: x, y: y) }

        case .mouseButtonDown(_, let x, let y, _):
            if let index = buttons.firstIndex(where: { contains($0.rect, x: x, y: y) }) {
                let name = buttons[index].name
                print("[GunBoundClient] clicked room-list button: \(name)")
                switch name {
                case "gamelist_create.img":
                    context.requestTransition(to: .readyRoom)
                case "b_gamelist_avatar.img":
                    context.requestTransition(to: .avatarShop)
                default:
                    break
                }
            }

        default:
            break
        }
    }

    override func render(_ renderer: SDLRenderer) throws {
        try super.render(renderer)
        for (index, button) in buttons.enumerated() {
            guard let texture = button.texture else { continue }
            if index == hoveredIndex {
                try texture.setColorModulation(red: 200, green: 200, blue: 255)
            } else {
                try texture.setColorModulation(red: 255, green: 255, blue: 255)
            }
            try renderer.copy(texture, destination: button.rect)
        }
    }
}
