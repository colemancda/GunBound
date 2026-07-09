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
    /// `gamelist_back.img` frames keyed by frame index (see `RenderRoomCard`):
    /// 1–6 card backgrounds, 7–9 status icons, 10–13 game-mode labels, 15
    /// padlock. Stored sparse by index so drawing reads them by the frame
    /// number the view model computes.
    private var cardFrames: [Int: ClientTexture] = [:]
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

        // Card backgrounds (1–6), status icons (7–9), game-mode labels
        // (10–13), and the padlock (15) all live as extra frames of the
        // background sheet; load each frame the card renderer can ask for.
        for frame in [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 15] {
            cardFrames[frame] = renderer.texture(named: viewModel.backgroundImageName, frame: frame, assets: assets)
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
        cardFrames = [:]
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
            let rightColumn = index / 3 != 0

            // Card background — frame 1–6 by column, joined, and hover/select
            // state (RenderRoomCard).
            if let card = cardFrames[viewModel.cardFrame(forVisibleSlot: index)] {
                renderer.draw(card, in: rect, tint: nil)
            }

            // Draws a `gamelist_back.img` icon frame at a card-relative offset,
            // at its own natural size.
            func drawIcon(_ frame: Int, atX offsetX: Float, y offsetY: Float) {
                guard let icon = cardFrames[frame] else { return }
                let (w, h) = renderer.size(of: icon)
                renderer.draw(icon, in: Rect(x: rect.x + offsetX, y: rect.y + offsetY, width: w, height: h), tint: nil)
            }

            // Status (PLAY/FULL/WAIT), game-mode label (SOLO…JEWEL), and the
            // padlock when the room is private — all at their decomp offsets.
            drawIcon(viewModel.statusFrame(of: room),
                     atX: GameRoomListViewModel.statusIconOffset.x, y: GameRoomListViewModel.statusIconOffset.y)
            drawIcon(viewModel.modeFrame(of: room),
                     atX: GameRoomListViewModel.modeIconOffset.x, y: GameRoomListViewModel.modeIconOffset.y)
            if room.isLocked {
                drawIcon(15, atX: GameRoomListViewModel.lockIconX(rightColumn: rightColumn),
                         y: GameRoomListViewModel.lockIconOffsetY)
            }

            // Bitmap-font text in the card's top strip: room number + name on
            // the left, and the players/max count flanking the "/" baked into
            // the card art near the right edge (the decomp's `%d` / count
            // overlays).
            if let font {
                let numberText = "\(room.id.rawValue)"
                font.draw(numberText, x: rect.x + 12, y: rect.y + 8, using: renderer)
                textFont?.draw(room.name, x: rect.x + 12 + font.width(of: numberText) + 8, y: rect.y + 8, using: renderer)
                // The baked separator sits at ~x+198; count numbers flank it.
                let players = "\(room.playerCount)"
                font.draw(players, x: rect.x + 194 - font.width(of: players), y: rect.y + 8, using: renderer)
                font.draw("\(room.capacity.rawValue)", x: rect.x + 203, y: rect.y + 8, using: renderer)
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
