import GunBound

/// A modal message dialog — the port of the original's shared `ShowErrorDialog`
/// popup (GunBound-Decomp `docs/screens/README.md`, "Error / message dialog"):
/// an `error_back.img` panel with a word-wrapped message and a single
/// `b_error_confirm` OK button that dismisses it. Every screen's error/notice
/// path funnels through this one widget, exactly as the decomp routes all
/// errors through one popup rather than per-screen code.
///
/// The default frame is the decomp's fixed dialog rect
/// (`{left 0xf9, right 0x229, top 0xc1, bottom 0x171}` → (249, 193) 304×176),
/// which is also `error_back.img`'s natural size. While visible the dialog is
/// modal: it consumes every pointer-down so the screen behind it stays inert,
/// and Enter (`.activate`) confirms, like clicking OK.
@MainActor
public final class DialogWidget: Widget {

    /// The decomp's fixed dialog rect — also `error_back.img`'s natural size.
    /// `nonisolated` (and computed, not stored) so it stays usable from a
    /// nonisolated context, e.g. as a default parameter value.
    public nonisolated static var defaultFrame: Rect { Rect(x: 249, y: 193, width: 304, height: 176) }

    /// The OK button's decomp position (`b_error_confirm` at (0x1c6, 0x14b),
    /// size 0x4a×0x1a). Callers usually override the size with the loaded
    /// texture's own dimensions.
    public nonisolated static var defaultConfirmFrame: Rect { Rect(x: 454, y: 331, width: 74, height: 26) }

    /// The full message. Following the original (`ShowErrorDialog` renders
    /// one wrapped string, `GameTick` blits its first line into the title
    /// strip and the rest into the body), this widget has **no separate
    /// title**: the first wrapped line is drawn in the strip and the
    /// remaining lines in the body. The localized error strings are authored
    /// as `Title\n\nDetail`, so the first line naturally becomes the title
    /// and the blank line becomes the gap beneath it.
    public var message: String
    public var backgroundTexture: ClientTexture?
    /// A solid texture drawn full-screen behind the panel to dim what's
    /// underneath — the original's modal shade (a 50%-alpha black fill; the
    /// decomp's `FUN_004ed5a0(…, 0x80000000)`). `nil` draws no dim.
    public var dimTexture: ClientTexture?
    /// The area the dim covers — the client's logical 800×600 canvas.
    public var dimBounds = Rect(x: 0, y: 0, width: 800, height: 600)
    /// The dim's opacity (0x80/0xff ≈ 0.5, matching the original's fill).
    public static let dimOpacity: Float = 0.5
    private let font: LoadedFont?
    private let textTint: (r: UInt8, g: UInt8, b: UInt8)
    public let okButton: ButtonWidget

    /// Called when the dialog is confirmed (OK clicked or Enter pressed),
    /// after it hides itself.
    public var onConfirm: (() -> Void)?

    /// - Parameters:
    ///   - frame: the dialog panel's rect; `background` is drawn to fill it.
    ///   - message: the text shown, word-wrapped into the panel body (honors
    ///     explicit `\n` breaks).
    ///   - font: the bitmap font the message is drawn with.
    ///   - background: the panel chrome (`error_back.img`); `nil` draws none.
    ///   - confirmFrame: the OK button's rect (usually the loaded confirm
    ///     texture placed at the decomp origin).
    ///   - confirmTexture: the OK button artwork (`b_error_confirm.img`).
    ///   - textTint: the message color (defaults to white).
    public init(
        frame: Rect = DialogWidget.defaultFrame,
        message: String = "",
        font: LoadedFont?,
        background: ClientTexture? = nil,
        confirmFrame: Rect = DialogWidget.defaultConfirmFrame,
        confirmTexture: ClientTexture? = nil,
        textTint: (r: UInt8, g: UInt8, b: UInt8) = (255, 255, 255)
    ) {
        self.message = message
        self.font = font
        self.backgroundTexture = background
        self.textTint = textTint
        self.okButton = ButtonWidget(frame: confirmFrame, texture: confirmTexture)
        super.init(frame: frame)
        add(okButton)
        okButton.onClick = { [weak self] in self?.confirm() }
    }

    /// Hides the dialog and fires `onConfirm`.
    public func confirm() {
        isHidden = true
        onConfirm?()
    }

    public override func drawSelf(_ renderer: ClientRenderer) {
        // Modal shade: dim the whole screen behind the panel first (the
        // original darkens the background while a dialog is up).
        if let dimTexture {
            renderer.draw(dimTexture, in: dimBounds, tint: (0, 0, 0), blend: .alpha, opacity: Self.dimOpacity)
        }
        if let backgroundTexture {
            renderer.draw(backgroundTexture, in: frame, tint: nil)
        }
        guard let font else { return }

        let lines = wrap(message, within: frame.width - Self.bodyInset * 2, font: font)

        // First wrapped line → the title strip (the decomp blits it at
        // panel-relative y 14: BlitRLESprite y 0xcf = 207, panel top
        // 0xc1 = 193). Centered in the strip.
        if let titleLine = lines.first, !titleLine.isEmpty {
            let titleWidth = font.width(of: titleLine)
            font.draw(
                titleLine,
                x: frame.x + max(Self.bodyInset, (frame.width - titleWidth) / 2),
                y: frame.y + 14,
                tint: textTint,
                using: renderer
            )
        }

        // Remaining lines → the body, left-aligned (the original blits them
        // from y 236 = panel-relative 43). The message's blank line after
        // the title keeps a slot here, forming the gap beneath the title.
        var y = frame.y + Self.bodyTop
        for line in lines.dropFirst() {
            font.draw(line, x: frame.x + Self.bodyInset, y: y, tint: textTint, using: renderer)
            y += font.lineHeight + 4
        }
    }

    /// Body-text layout, panel-relative. The decomp blits the body lines
    /// starting at y 236 (0xec) with the panel top at y 193 (0xc1), i.e.
    /// panel-relative **43** — matching `RenderWrappedText`'s y arg (0x2b);
    /// lines step 14px (0xe). The left inset isn't cleanly recoverable (the
    /// wrapped-text buffer uses its own layout space, wrap width 0x15e), so
    /// it stays a visual estimate.
    private static let bodyInset: Float = 18
    private static let bodyTop: Float = 43

    public override func handleSelf(_ event: ScreenInputEvent) -> Bool {
        switch event {
        case .activate:
            confirm()
            return true
        case .pointerDown, .pointerUp:
            // Modal: swallow clicks anywhere so the screen behind stays inert
            // (the OK button already had its chance as a child).
            return true
        case .pointerMoved, .text, .key:
            return false
        case .scroll:
            return true  // modal: nothing behind may scroll
        }
    }

    /// Greedy word-wrap honoring explicit `\n` breaks — mirrors the decomp's
    /// `RenderWrappedText`, just measured with our bitmap font's advances.
    private func wrap(_ text: String, within maxWidth: Float, font: LoadedFont) -> [String] {
        var lines: [String] = []
        for paragraph in text.split(separator: "\n", omittingEmptySubsequences: false) {
            var current = ""
            for word in paragraph.split(separator: " ", omittingEmptySubsequences: true) {
                let candidate = current.isEmpty ? String(word) : current + " " + word
                if font.width(of: candidate) <= maxWidth || current.isEmpty {
                    current = candidate
                } else {
                    lines.append(current)
                    current = String(word)
                }
            }
            lines.append(current)
        }
        return lines
    }
}
