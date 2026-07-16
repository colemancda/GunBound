import GunBound

/// View for the Loading screen (state 10). Draws the match's map-specific
/// `load_stageNN.img` stage preview with `load_back.img`'s bottom strip
/// (frame 0, 800×244) over it, then the live per-player display the decomp
/// describes: a ready row whose entries flip as players finish loading, a
/// ready-icon row at the confirmed 44px slot stride, the currently-loading
/// player's entry **blinking** on the original's `(tick/10) & 1` parity, and
/// a progress fill (frame 1).
///
/// The strip's interior element positions aren't decomp-recorded
/// (`FUN_00442280`'s coordinates aren't extracted), so rows are laid out
/// inside the strip by eye; the slot stride and blink cadence are the
/// confirmed parts.
@MainActor
public final class LoadingScreen: GameScreen {
    private let viewModel: LoadingViewModel
    private var stripTexture: ClientTexture?
    private var progressFillTexture: ClientTexture?
    private var readyDotTexture: ClientTexture?
    private var stageOverlayTexture: ClientTexture?
    private var font: LoadedFont?

    /// The bottom strip's origin (frame 0 is 800×244, anchored to the
    /// window bottom).
    private let stripTop: Float = 600 - 244

    public init(viewModel: LoadingViewModel) {
        self.viewModel = viewModel
    }

    public func onEnter(context: ClientContext) throws {
        viewModel.onEnter()
        let renderer = context.renderer
        let assets = context.assets
        stripTexture = renderer.texture(named: viewModel.backgroundImageName, assets: assets)
        progressFillTexture = renderer.texture(named: viewModel.backgroundImageName, frame: 1, assets: assets)
        readyDotTexture = renderer.texture(named: viewModel.backgroundImageName, frame: 2, assets: assets)
        stageOverlayTexture = renderer.texture(named: viewModel.stageOverlayImageName, assets: assets)
        font = LoadedFont(.latinFont, renderer: renderer, assets: assets)
    }

    public func onExit() {
        viewModel.onExit()
        stripTexture = nil
        progressFillTexture = nil
        readyDotTexture = nil
        stageOverlayTexture = nil
        font = nil
    }

    public func handleInput(_ event: ScreenInputEvent) {
        viewModel.handle(event)
    }

    public func update(deltaTime: Double) {
        viewModel.update(deltaTime: deltaTime)
    }

    public func render(_ renderer: ClientRenderer) throws {
        renderer.clear()
        // Stage preview above; the strip anchored to the bottom.
        drawFullSize(stageOverlayTexture, using: renderer)
        if let stripTexture {
            renderer.draw(stripTexture, in: Rect(x: 0, y: stripTop, width: 800, height: 244), tint: nil)
        }

        // Progress fill (frame 1, 156×14) in the strip's top-left well,
        // clipped to the current progress by scaling its width.
        if let progressFillTexture {
            let width = 156 * Float(viewModel.progress)
            if width > 1 {
                renderer.draw(progressFillTexture, in: Rect(x: 74, y: stripTop + 11, width: width, height: 14), tint: nil)
            }
        }

        guard let font else { return }

        // Per-player rows inside the strip's body — name/mobile/team, each
        // flipping to READY; the currently-loading player's entry blinks.
        let rowTop = stripTop + 52
        for (index, player) in viewModel.players.enumerated() {
            let ready = viewModel.isReady(playerIndex: index)
            let blinkOff = viewModel.loadingSlot == index && !viewModel.blinkOn
            let y = rowTop + Float(index) * 20

            if let dot = readyDotTexture {
                let tint: (r: UInt8, g: UInt8, b: UInt8) = ready ? (120, 255, 120) : (110, 110, 110)
                renderer.draw(dot, in: Rect(x: 40, y: y + 2, width: 12, height: 12), tint: tint)
            }
            if !blinkOff {
                let tint: (r: UInt8, g: UInt8, b: UInt8)? = ready ? nil : (150, 150, 150)
                font.draw(player.name, x: 60, y: y, tint: tint, using: renderer)
                font.draw("\(player.mobile)", x: 220, y: y, tint: tint, using: renderer)
                font.draw("Team \(player.team)", x: 330, y: y, tint: tint, using: renderer)
            }
            if ready {
                font.draw("READY", x: 430, y: y, tint: (120, 255, 120), using: renderer)
            }
        }

        // The ready-icon row at the decomp's 44px stride along the strip's
        // lower band — one icon per slot, flipping as players come ready,
        // the loading slot blinking.
        if let dot = readyDotTexture {
            let iconY = stripTop + 208
            for index in 0..<viewModel.players.count {
                let ready = viewModel.isReady(playerIndex: index)
                let blinkOff = viewModel.loadingSlot == index && !viewModel.blinkOn
                guard !blinkOff else { continue }
                let tint: (r: UInt8, g: UInt8, b: UInt8) = ready ? (120, 255, 120) : (110, 110, 110)
                renderer.draw(
                    dot,
                    in: Rect(x: 40 + Float(index) * LoadingViewModel.readySlotStride, y: iconY, width: 12, height: 12),
                    tint: tint
                )
            }
        }
    }
}
