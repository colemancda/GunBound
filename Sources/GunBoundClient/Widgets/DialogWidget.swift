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
    public static let defaultFrame = Rect(x: 249, y: 193, width: 304, height: 176)

    /// The OK button's decomp position (`b_error_confirm` at (0x1c6, 0x14b),
    /// size 0x4a×0x1a). Callers usually override the size with the loaded
    /// texture's own dimensions.
    public static let defaultConfirmFrame = Rect(x: 454, y: 331, width: 74, height: 26)

    public var message: String
    public var backgroundTexture: ClientTexture?
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
        if let backgroundTexture {
            renderer.draw(backgroundTexture, in: frame, tint: nil)
        }
        guard let font else { return }

        // Message body: inset inside the panel's dark inner band. The top
        // strip of `error_back.img` is a title bar, so text starts below it.
        let inset: Float = 18
        let bodyTop = frame.y + 40
        let bodyWidth = frame.width - inset * 2
        let lines = wrap(message, within: bodyWidth, font: font)
        var y = bodyTop
        for line in lines {
            // Center each line horizontally within the body.
            let lineWidth = font.width(of: line)
            let x = frame.x + inset + max(0, (bodyWidth - lineWidth) / 2)
            font.draw(line, x: x, y: y, tint: textTint, using: renderer)
            y += font.lineHeight + 4
        }
    }

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
