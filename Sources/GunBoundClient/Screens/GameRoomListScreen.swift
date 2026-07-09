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
    /// Widget tree — currently just the shared buddy panel, hidden until the
    /// BUDDY button toggles `viewModel.isBuddyPanelVisible`.
    private var rootWidget = Widget()
    private var buddyPanel: BuddyPanelWidget?

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

        // Lay the twelve bottom-bar buttons out left-to-right, wrapping down
        // to a second row when they exceed the window width (the decomp's
        // exact positions aren't recorded; the view model just needs
        // hit-test rects that match what's drawn).
        let margin: Float = 12
        let gap: Float = 6
        var x = margin
        var y: Float = 496
        var rowHeight: Float = 0
        buttonTextures = []
        for (index, button) in viewModel.buttons.enumerated() {
            let texture = renderer.texture(named: button.name, assets: assets)
            buttonTextures.append(texture)
            let (width, height) = renderer.size(of: texture)
            if x + width > 800 - margin {
                x = margin
                y += rowHeight + gap
                rowHeight = 0
            }
            viewModel.setRect(Rect(x: x, y: y, width: width, height: height), forButtonAt: index)
            x += width + gap
            rowHeight = max(rowHeight, height)
        }

        // The shared buddy panel — built once, hidden until BUDDY toggles it.
        let buddyBack = renderer.texture(named: viewModel.buddyBackImageName, assets: assets)
        let (panelWidth, panelHeight) = renderer.size(of: buddyBack)
        let panelFrame = panelWidth > 0
            ? Rect(x: 568, y: 11, width: panelWidth, height: panelHeight)
            : BuddyPanelWidget.defaultFrame
        let buddyPanel = BuddyPanelWidget(
            frame: panelFrame,
            font: textFont,
            background: buddyBack,
            addTexture: renderer.texture(named: viewModel.buddyAddImageName, assets: assets),
            delTexture: renderer.texture(named: viewModel.buddyDelImageName, assets: assets),
            closeTexture: renderer.texture(named: viewModel.buddyCloseImageName, assets: assets)
        )
        buddyPanel.isHidden = true
        buddyPanel.onClose = { [weak viewModel = self.viewModel] in viewModel?.dismissBuddyPanel() }
        rootWidget = Widget(frame: Rect(x: 0, y: 0, width: 800, height: 600))
        rootWidget.add(buddyPanel)
        self.buddyPanel = buddyPanel
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
        rootWidget = Widget()
        buddyPanel = nil
    }

    public func handleInput(_ event: ScreenInputEvent) {
        // The buddy panel (when shown) gets first crack and swallows clicks
        // that land on it; otherwise input falls through to the view model.
        if rootWidget.dispatch(event) {
            return
        }
        viewModel.handle(event)
    }

    public func update(deltaTime: Double) {
        viewModel.update(deltaTime: deltaTime)
        // Mirror the view model's buddy-panel toggle onto the widget.
        if let buddyPanel {
            buddyPanel.isHidden = !viewModel.isBuddyPanelVisible
            buddyPanel.buddies = viewModel.buddies
        }
        rootWidget.update(deltaTime: deltaTime)
    }

    public func render(_ renderer: ClientRenderer) throws {
        renderer.clear()
        drawFullSize(backgroundTexture, using: renderer)

        let visibleRooms = viewModel.visibleRooms
        for (index, room) in visibleRooms.enumerated() {
            let rect = viewModel.roomRect(at: index)
            let highlighted = index == viewModel.selectedRoomIndex || index == viewModel.hoveredRoomIndex
            if let card = highlighted ? (cardHighlightTexture ?? cardTexture) : cardTexture {
                renderer.draw(card, in: rect, tint: nil)
            }
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

        // The buddy panel draws on top of everything when shown.
        rootWidget.draw(renderer)
    }
}
