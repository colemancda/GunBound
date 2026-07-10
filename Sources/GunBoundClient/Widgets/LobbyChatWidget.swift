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

    /// The decomp's fixed lobby panel rect.
    public static let defaultFrame = Rect(x: 23, y: 287, width: 549, height: 259)

    /// The lobby panel's scrollbar page size (rows visible at once). The
    /// Ready Room variant passes 9.
    public static let defaultVisibleRows = 13

    /// History rows visible at once — the panel's scrollbar page size.
    public let visibleRows: Int

    /// Chat lines, oldest first. The view follows the tail as lines arrive
    /// unless the player has scrolled up.
    public var messages: [ChatLine] = [] {
        didSet {
            let wasAtTail = scrollBar.position >= max(0, oldValue.count - visibleRows)
            scrollBar.contentCount = messages.count
            if wasAtTail {
                scrollBar.setPosition(scrollBar.maxPosition)
            }
        }
    }

    public var backgroundTexture: ClientTexture?
    private let font: LoadedFont?

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

    /// - Parameters:
    ///   - frame: the panel rect (lobby default (23,287) 549×259; the Ready
    ///     Room passes its (21,385) 480×160).
    ///   - inputFrame: the input line, panel-relative (lobby default is the
    ///     decomp's (26,235) 484×12).
    ///   - scrollTrack: the scrollbar track, panel-relative (lobby default
    ///     (526,63) 18×154; the Ready Room's is (455,51) 18×69).
    ///   - scrollKnobs: panel-relative hit-zones for the baked knob art,
    ///     which renders *outside* the track (lobby default measured from
    ///     gamelist_chat.img: y 33–60 above, 219–246 below). Pass `nil` for
    ///     chrome without distinct knobs (the Ready Room well) to fall back
    ///     to zones at the track ends.
    ///   - visibleRows: the scrollbar page size (lobby 13, Ready Room 9).
    public init(
        frame: Rect = LobbyChatWidget.defaultFrame,
        font: LoadedFont?,
        background: ClientTexture? = nil,
        inputFrame: Rect = Rect(x: 26, y: 235, width: 484, height: 12),
        scrollTrack: Rect = Rect(x: 526, y: 63, width: 18, height: 154),
        scrollKnobs: (up: Rect, down: Rect)? = (
            up: Rect(x: 526, y: 35, width: 18, height: 18),
            down: Rect(x: 526, y: 227, width: 18, height: 18)
        ),
        visibleRows: Int = LobbyChatWidget.defaultVisibleRows
    ) {
        self.font = font
        self.backgroundTexture = background
        self.visibleRows = visibleRows
        // Lobby decomp: CreateTextEntryWidget(0, 0x1a, 0xeb, 0x1e4, 0xc, 0x50).
        inputField = TextFieldWidget(
            frame: Rect(x: frame.x + inputFrame.x, y: frame.y + inputFrame.y, width: inputFrame.width, height: inputFrame.height),
            font: font
        )
        inputField.maxLength = 80
        inputField.placeholder = ""
        // Lobby decomp: CreateScrollListWidget(mgr, 0x20e, 0x3f, 0x12, 0x9a, 0xd).
        let track = Rect(x: frame.x + scrollTrack.x, y: frame.y + scrollTrack.y, width: scrollTrack.width, height: scrollTrack.height)
        if let knobs = scrollKnobs {
            scrollBar = ScrollBarWidget(
                track: track,
                upArrow: Rect(x: frame.x + knobs.up.x, y: frame.y + knobs.up.y, width: knobs.up.width, height: knobs.up.height),
                downArrow: Rect(x: frame.x + knobs.down.x, y: frame.y + knobs.down.y, width: knobs.down.width, height: knobs.down.height)
            )
        } else {
            scrollBar = ScrollBarWidget(track: track, arrowSize: 18)
        }
        scrollBar.pageSize = visibleRows

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
        for (row, line) in messages.dropFirst(scrollBar.position).prefix(visibleRows).enumerated() {
            let y = originY + Float(row) * linePitch
            let colors = Self.colors(for: line.type)
            var x = originX
            if !line.sender.isEmpty {
                let name = "\(line.sender): "
                font.draw(name, x: x, y: y, tint: colors.name, using: renderer)
                x += font.width(of: name)
            }
            font.draw(line.message, x: x, y: y, tint: colors.message, using: renderer)
        }
    }

    // MARK: Color-coded chat (decomp table)

    /// The name/message color pair for a message type — the decompiled chat
    /// renderer's switch (`RenderReadyRoomChatRow`, `0x50d200`, on the type
    /// byte at `+0x3c4d8`), RGB565 verbatim. Type 0 is normal chat (white on
    /// white), 2 is the yellow system notice; the other cases' semantics
    /// aren't traced but the colors are preserved so any future type byte
    /// renders faithfully. Unknown types fall back to normal.
    public static func colors(for type: ChatLine.MessageType) -> (name: (r: UInt8, g: UInt8, b: UInt8), message: (r: UInt8, g: UInt8, b: UInt8)) {
        let pair: (name: UInt16, message: UInt16)
        switch type.rawValue {
        case 0: pair = (0xffff, 0xffff)
        case 1: pair = (0xc618, 0xffff)
        case 2: pair = (0x0000, 0xffe0)
        case 3: pair = (0xf800, 0xffff)
        case 4: pair = (0x00f0, 0xafff)
        case 5: pair = (0x0000, 0xc7f8)
        case 6, 8: pair = (0x8000, 0xf800)
        case 7: pair = (0xfdb4, 0x78e0)
        case 9: pair = (0x0400, 0xfff2)
        case 10: pair = (0xfebf, 0xf800)
        case 0xb: pair = (0x4880, 0xfc20)
        case 0xc: pair = (0x210a, 0x07e0)
        case 0xd: pair = (0xf6bf, 0x001f)
        case 0xe: pair = (0xfecf, 0xc018)
        case 0xf: pair = (0xffff, 0x0000)
        case 0x10: pair = (0x0000, 0xffff)
        default: pair = (0xffff, 0xffff)
        }
        return (Self.rgb888(pair.name), Self.rgb888(pair.message))
    }

    /// Expands an RGB565 color (the original's 16bpp surface format) to the
    /// 8-bit channels our renderer tints with.
    static func rgb888(_ value: UInt16) -> (r: UInt8, g: UInt8, b: UInt8) {
        let r = UInt8((UInt32(value >> 11) & 0x1f) * 255 / 31)
        let g = UInt8((UInt32(value >> 5) & 0x3f) * 255 / 63)
        let b = UInt8((UInt32(value) & 0x1f) * 255 / 31)
        return (r, g, b)
    }

    public override func handleSelf(_ event: ScreenInputEvent) -> Bool {
        // Screen chrome, not a modal: the input field and scrollbar children
        // consume their own input; a wheel over the panel scrolls the
        // history; everything else falls through.
        if case .scroll(let x, let y, let steps) = event, frame.contains(x: x, y: y) {
            scrollBar.step(steps)
            return true
        }
        return false
    }
}
