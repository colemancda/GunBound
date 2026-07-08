import CSDL3
import SDL3Swift
import GunBound

/// State 7 — Avatar Store / Shop (`store_back.img`, `b_store_buy/cap/
/// cloth/glasse/flag.img`). Reached from the Game Room List's "Avatar"
/// button. Category buttons render and are clickable, but don't wire up to
/// any purchase flow — no networking/inventory logic in this pass.
@MainActor
final class AvatarShopScreen: ImageBackgroundScreen {
    private struct Button {
        let name: String
        var texture: SDLTexture?
        var rect: SDL_FRect
    }

    private static let emptyRect = SDL_FRect(x: 0, y: 0, w: 0, h: 0)

    private var categoryButtons: [Button] = [
        Button(name: "b_store_buy.img", texture: nil, rect: emptyRect),
        Button(name: "b_store_cap.img", texture: nil, rect: emptyRect),
        Button(name: "b_store_cloth.img", texture: nil, rect: emptyRect),
        Button(name: "b_store_glasse.img", texture: nil, rect: emptyRect),
        Button(name: "b_store_flag.img", texture: nil, rect: emptyRect),
    ]
    private var cancelButton: SDLTexture?
    private var cancelRect = SDL_FRect(x: 0, y: 0, w: 0, h: 0)
    private var hoveredIndex: Int?

    init() {
        super.init(backgroundImageName: "store_back.img", musicName: nil)
    }

    override func onEnter(context: ScreenContext) throws {
        try super.onEnter(context: context)
        var x: Float = 20
        let y: Float = 20
        for i in categoryButtons.indices {
            guard let texture = loadTexture(named: categoryButtons[i].name, context: context) else { continue }
            let attributes = try? texture.attributes()
            let width = Float(attributes?.width ?? 0)
            let height = Float(attributes?.height ?? 0)
            categoryButtons[i].texture = texture
            categoryButtons[i].rect = SDL_FRect(x: x, y: y, w: width, h: height)
            x += width + 10
        }
        cancelButton = loadTexture(named: "b_storewindow_cancel.img", context: context)
        if let cancelButton, let attributes = try? cancelButton.attributes() {
            cancelRect = SDL_FRect(x: 20, y: Float(600 - attributes.height - 20), w: Float(attributes.width), h: Float(attributes.height))
        }
    }

    override func onExit() {
        for i in categoryButtons.indices {
            categoryButtons[i].texture = nil
        }
        cancelButton = nil
        hoveredIndex = nil
        super.onExit()
    }

    override func handleEvent(_ event: SDLEvent, context: ScreenContext) {
        switch event {
        case .mouseMotion(_, let x, let y, _):
            hoveredIndex = categoryButtons.firstIndex { contains($0.rect, x: x, y: y) }

        case .mouseButtonDown(_, let x, let y, _):
            if contains(cancelRect, x: x, y: y) {
                context.requestTransition(to: .gameRoomList)
            } else if let index = categoryButtons.firstIndex(where: { contains($0.rect, x: x, y: y) }) {
                print("[GunBoundClient] clicked avatar-shop category: \(categoryButtons[index].name)")
            }

        default:
            break
        }
    }

    override func render(_ renderer: SDLRenderer) throws {
        try super.render(renderer)
        for (index, button) in categoryButtons.enumerated() {
            guard let texture = button.texture else { continue }
            if index == hoveredIndex {
                try texture.setColorModulation(red: 200, green: 200, blue: 255)
            } else {
                try texture.setColorModulation(red: 255, green: 255, blue: 255)
            }
            try renderer.copy(texture, destination: button.rect)
        }
        if let cancelButton {
            try renderer.copy(cancelButton, destination: cancelRect)
        }
    }
}
