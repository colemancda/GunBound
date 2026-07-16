import GunBound

/// The 1-on-1 buddy chat ("whisper") window — the port of the decomp's
/// `CChatLogPanel` (`0x557b94`, id 20001), opened on a buddy to talk privately.
/// Its chrome is `buddy_window_back.img`; it shows the recipient's name, a
/// scrolling message log, a text input, and a close-X.
///
/// Layout is runtime-confirmed from a `gbview` dump (panel id 20001 at
/// **(541,272) 256×291**): the recipient label (`typeId 3`) at panel-relative
/// (87,11) 145×12, the close-X (id 0) at (223,7) 22×20, the text input (id 0)
/// at (19,265) 211×12, and the scroll widget at (227,68) 18×157 with arrows at
/// (227,40)/(227,235).
///
/// The whisper send/receive protocol isn't wired yet, so `onSend` currently
/// just surfaces the typed line; the widget is otherwise complete.
@MainActor
public final class BuddyChatWindowWidget: Widget {

    /// The runtime panel rect (also `buddy_window_back.img`'s size).
    /// `nonisolated` (and computed, not stored) so it stays usable from a
    /// nonisolated context, e.g. as a default parameter value.
    public nonisolated static var defaultFrame: Rect { Rect(x: 541, y: 272, width: 256, height: 291) }

    /// How many log rows are visible at once (page size).
    public static let visibleRows = 15

    /// The buddy this window is talking to — drawn in the title's "TO" box.
    public var recipient: String

    /// The conversation, oldest first; follows the tail as lines arrive.
    public var messages: [ChatLine] = [] {
        didSet {
            let wasAtTail = scrollBar.position >= max(0, oldValue.count - Self.visibleRows)
            scrollBar.contentCount = messages.count
            if wasAtTail { scrollBar.setPosition(scrollBar.maxPosition) }
        }
    }

    public let inputField: TextFieldWidget
    public let scrollBar: ScrollBarWidget
    public let closeButton: ButtonWidget

    /// Fired when the player submits a non-empty line.
    public var onSend: ((String) -> Void)?
    /// Fired when the close-X is clicked (after the window hides itself).
    public var onClose: (() -> Void)?

    public var backgroundTexture: ClientTexture?
    private let font: LoadedFont?
    private let textTint: (r: UInt8, g: UInt8, b: UInt8)

    private var listOrigin: (x: Float, y: Float) { (frame.x + 14, frame.y + 40) }
    private var linePitch: Float { 14 }

    public init(
        recipient: String = "",
        frame: Rect = BuddyChatWindowWidget.defaultFrame,
        font: LoadedFont?,
        background: ClientTexture? = nil,
        closeTexture: ClientTexture? = nil,
        textTint: (r: UInt8, g: UInt8, b: UInt8) = (255, 255, 255)
    ) {
        self.recipient = recipient
        self.font = font
        self.backgroundTexture = background
        self.textTint = textTint

        // Panel-relative rects from the runtime dump.
        inputField = TextFieldWidget(
            frame: Rect(x: frame.x + 19, y: frame.y + 265, width: 211, height: 12),
            font: font
        )
        inputField.maxLength = 80
        closeButton = ButtonWidget(
            frame: Rect(x: frame.x + 223, y: frame.y + 7, width: 22, height: 20),
            texture: closeTexture
        )
        scrollBar = ScrollBarWidget(
            track: Rect(x: frame.x + 227, y: frame.y + 68, width: 18, height: 157),
            upArrow: Rect(x: frame.x + 227, y: frame.y + 40, width: 18, height: 18),
            downArrow: Rect(x: frame.x + 227, y: frame.y + 235, width: 18, height: 18)
        )
        scrollBar.pageSize = Self.visibleRows

        super.init(frame: frame)
        add(scrollBar)
        add(inputField)
        add(closeButton)

        closeButton.onClick = { [weak self] in self?.close() }
        inputField.onSubmit = { [weak self] in
            guard let self else { return }
            let line = self.inputField.text.trimmingCharacters(in: .whitespaces)
            self.inputField.setText("")
            guard !line.isEmpty else { return }
            self.onSend?(line)
        }
    }

    /// Hides the window and fires `onClose`.
    public func close() {
        isHidden = true
        onClose?()
    }

    public override func drawSelf(_ renderer: ClientRenderer) {
        if let backgroundTexture {
            renderer.draw(backgroundTexture, in: frame, tint: nil)
        }
        guard let font else { return }
        // Recipient name in the title's "TO" box.
        font.draw(recipient, x: frame.x + 87, y: frame.y + 11, tint: textTint, using: renderer)
        // The conversation log, scrolled by the bar.
        let (originX, originY) = listOrigin
        for (row, line) in messages.dropFirst(scrollBar.position).prefix(Self.visibleRows).enumerated() {
            let y = originY + Float(row) * linePitch
            let colors = LobbyChatWidget.colors(for: line.type)
            var x = originX
            if !line.sender.isEmpty {
                let name = "\(line.sender): "
                font.draw(name, x: x, y: y, tint: colors.name, using: renderer)
                x += font.width(of: name)
            }
            font.draw(line.message, x: x, y: y, tint: colors.message, using: renderer)
        }
    }

    public override func handleSelf(_ event: ScreenInputEvent) -> Bool {
        // A wheel over the window scrolls the log; other input falls through
        // (the input/scroll/close children consume their own).
        if case .scroll(let x, let y, let steps) = event, frame.contains(x: x, y: y) {
            scrollBar.step(steps)
            return true
        }
        return false
    }
}
