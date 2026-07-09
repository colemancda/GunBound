import GunBound

/// The lobby's chat panel — the port of the decomp's `BuildLobbyChatPanel`
/// (`0x509af0`, vtable `0x557cd4`): a 549×259 panel filling the lobby's
/// lower-left, with the chat history drawn by the panel itself, a text-entry
/// input line along the bottom, and a page-13 scroll-list widget down the
/// right edge.
///
/// Geometry is decomp-confirmed from the builder: the panel at **(23, 287)
/// 549×259** (`0x17, 0x11f, 0x225, 0x103`), the input line at panel-relative
/// **(26, 235) 484×12** with max length **80**
/// (`CreateTextEntryWidget(0, 0x1a, 0xeb, 0x1e4, 0xc, 0x50)`), and the
/// scrollbar at **(526, 63) 18×154**, page 13
/// (`CreateScrollListWidget(mgr, 0x20e, 0x3f, 0x12, 0x9a, 0xd)`).
///
/// Enter in the input fires `onSend` and clears the line (focus kept, like
/// the original's chat box); the view stays scrolled to the newest line
/// unless the player has scrolled up to read history.
@MainActor
public final class LobbyChatWidget: Widget {

    /// The decomp's fixed panel rect.
    public static let defaultFrame = Rect(x: 23, y: 287, width: 549, height: 259)

    /// History rows visible at once — the decomp scrollbar's page size.
    public static let visibleRows = 13

    /// Chat lines, oldest first. The view follows the tail as lines arrive
    /// unless the player has scrolled up.
    public var messages: [String] = [] {
        didSet {
            let wasAtTail = scrollBar.position >= max(0, oldValue.count - Self.visibleRows)
            scrollBar.contentCount = messages.count
            if wasAtTail {
                scrollBar.setPosition(scrollBar.maxPosition)
            }
        }
    }

    public var backgroundTexture: ClientTexture?
    private let font: LoadedFont?
    private let textTint: (r: UInt8, g: UInt8, b: UInt8)

    public let inputField: TextFieldWidget
    public let scrollBar: ScrollBarWidget

    /// Fired when the player submits a non-empty chat line.
    public var onSend: ((String) -> Void)?

    /// The history band the lines draw into — below the title strip, left of
    /// the scrollbar, above the input line. The row *origin* isn't decomp-
    /// recorded for this panel (its own row renderer isn't ported), but the
    /// 14px pitch matches the decompiled chat-row idiom: the Ready Room chat
    /// renderer (`RenderReadyRoomChatRow`, `0x50d200`) steps its lines by
    /// exactly `0xe`.
    private var listOrigin: (x: Float, y: Float) { (frame.x + 14, frame.y + 40) }
    /// Chat-line pitch (`0xe`, per the decompiled chat-row renderers).
    private var linePitch: Float { 14 }

    public init(
        frame: Rect = LobbyChatWidget.defaultFrame,
        font: LoadedFont?,
        background: ClientTexture? = nil,
        textTint: (r: UInt8, g: UInt8, b: UInt8) = (255, 255, 255)
    ) {
        self.font = font
        self.backgroundTexture = background
        self.textTint = textTint
        // Decomp: CreateTextEntryWidget(0, 0x1a, 0xeb, 0x1e4, 0xc, 0x50).
        inputField = TextFieldWidget(
            frame: Rect(x: frame.x + 26, y: frame.y + 235, width: 484, height: 12),
            font: font
        )
        inputField.maxLength = 80
        inputField.placeholder = ""
        // Decomp: CreateScrollListWidget(mgr, 0x20e, 0x3f, 0x12, 0x9a, 0xd).
        scrollBar = ScrollBarWidget(
            track: Rect(x: frame.x + 526, y: frame.y + 63, width: 18, height: 154),
            arrowSize: 18
        )
        scrollBar.pageSize = Self.visibleRows

        super.init(frame: frame)
        add(scrollBar)
        add(inputField)

        inputField.onSubmit = { [weak self] in
            guard let self else { return }
            let line = self.inputField.text.trimmingCharacters(in: .whitespaces)
            self.inputField.setText("")
            guard !line.isEmpty else { return }
            self.onSend?(line)
        }
    }

    public override func drawSelf(_ renderer: ClientRenderer) {
        if let backgroundTexture {
            renderer.draw(backgroundTexture, in: frame, tint: nil)
        }
        guard let font else { return }
        let (originX, originY) = listOrigin
        for (row, line) in messages.dropFirst(scrollBar.position).prefix(Self.visibleRows).enumerated() {
            font.draw(line, x: originX, y: originY + Float(row) * linePitch, tint: textTint, using: renderer)
        }
    }

    public override func handleSelf(_ event: ScreenInputEvent) -> Bool {
        // Screen chrome, not a modal: the input field and scrollbar children
        // consume their own input; everything else falls through.
        _ = event
        return false
    }
}
