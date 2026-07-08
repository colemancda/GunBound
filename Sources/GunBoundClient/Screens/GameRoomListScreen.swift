import GunBound

/// View for the Game Room List / channel lobby (state 3) — all routing,
/// room-list networking, and hit-testing live in `GameRoomListViewModel`;
/// this loads the chrome/button/room-card textures and draws them at the
/// rects the view model computes.
///
/// The room cards, their highlighted state, and the waiting/playing/full
/// status icons are all separate frames inside `gamelist_back.img` (frames
/// 1–3 = card base / highlighted / joined; frames 7–9 = status icons), per
/// the decompiled `RenderRoomLabel` (`docs/screens/03_game_room_list.md`).
/// Per-card text (room number, `[players/max]` count) needs a bitmap-font
/// path this client doesn't have yet, so cards render as the sheet's own art
/// plus the status icon — a follow-up can add the text overlay.
@MainActor
public final class GameRoomListScreen: GameScreen {
    private let viewModel: GameRoomListViewModel
    private var backgroundTexture: ClientTexture?
    private var buttonTextures: [ClientTexture?] = []
    private var cardTexture: ClientTexture?
    private var cardHighlightTexture: ClientTexture?
    private var statusTextures: [GameRoomListViewModel.RoomStatus: ClientTexture] = [:]
    private var font: LoadedFont?
    private var textFont: LoadedFont?

    public init(viewModel: GameRoomListViewModel) {
        self.viewModel = viewModel
    }

    public func onEnter(context: ClientContext) throws {
        viewModel.onEnter()
        let renderer = context.renderer
        let assets = context.assets
        backgroundTexture = renderer.texture(named: viewModel.backgroundImageName, assets: assets)

        // Room-card states + status icons live as extra frames of the same
        // background sprite sheet.
        cardTexture = renderer.texture(named: viewModel.backgroundImageName, frame: 1, assets: assets)
        cardHighlightTexture = renderer.texture(named: viewModel.backgroundImageName, frame: 2, assets: assets)
        let statusFrames: [(GameRoomListViewModel.RoomStatus, Int)] = [(.waiting, 7), (.playing, 8), (.full, 9)]
        for (status, frame) in statusFrames {
            statusTextures[status] = renderer.texture(named: viewModel.backgroundImageName, frame: frame, assets: assets)
        }

        font = LoadedFont(.numberFont, renderer: renderer, assets: assets)
        textFont = LoadedFont(.latinFont, renderer: renderer, assets: assets)

        var x: Float = 20
        let y: Float = 540
        buttonTextures = []
        for (index, button) in viewModel.buttons.enumerated() {
            let texture = renderer.texture(named: button.name, assets: assets)
            buttonTextures.append(texture)
            let (width, height) = renderer.size(of: texture)
            viewModel.setRect(Rect(x: x, y: y, width: width, height: height), forButtonAt: index)
            x += width + 10
        }
    }

    public func onExit() {
        viewModel.onExit()
        backgroundTexture = nil
        buttonTextures = []
        cardTexture = nil
        cardHighlightTexture = nil
        statusTextures = [:]
        font = nil
        textFont = nil
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

        for index in 0..<viewModel.visibleRoomCount {
            let rect = viewModel.roomRect(at: index)
            let highlighted = index == viewModel.selectedRoomIndex || index == viewModel.hoveredRoomIndex
            if let card = highlighted ? (cardHighlightTexture ?? cardTexture) : cardTexture {
                renderer.draw(card, in: rect, tint: nil)
            }
            let room = viewModel.rooms[index]
            // Status icon, right-aligned within the card.
            let status = viewModel.status(of: room)
            if let icon = statusTextures[status] {
                let (iconWidth, iconHeight) = renderer.size(of: icon)
                let iconRect = Rect(
                    x: rect.x + rect.width - iconWidth - 8,
                    y: rect.y + (rect.height - iconHeight) / 2,
                    width: iconWidth,
                    height: iconHeight
                )
                renderer.draw(icon, in: iconRect, tint: nil)
            }

            // Bitmap-font text: room number (top-left) and players/max count
            // (bottom-left) — the decomp's `%d` and `%3d/%3d` overlays. Room
            // *name* needs the general `font.fnt`, not decoded yet.
            if let font {
                let numberText = "\(index + 1)"
                font.draw(numberText, x: rect.x + 8, y: rect.y + 6, using: renderer)
                // Room name (Latin bitmap font) to the right of the number.
                textFont?.draw(room.name, x: rect.x + 8 + font.width(of: numberText) + 8, y: rect.y + 6, using: renderer)
                font.draw("\(room.playerCount)/\(room.capacity.rawValue)", x: rect.x + 8, y: rect.y + rect.height - font.lineHeight - 6, using: renderer)
            }
        }

        for (index, button) in viewModel.buttons.enumerated() {
            guard let texture = buttonTextures[index] else { continue }
            let tint: (r: UInt8, g: UInt8, b: UInt8)? = index == viewModel.hoveredButtonIndex ? (200, 200, 255) : nil
            renderer.draw(texture, in: button.rect, tint: tint)
        }
    }
}
