import GunBound

/// The "add buddy ID" modal dialog — the port of the decomp's add-buddy dialog
/// (panel `0x557e68`, id 10000, opened from the buddy panel's Add button). Its
/// chrome is `buddy2.img`; it shows a static prompt, a name field, and ADD /
/// CLOSE buttons.
///
/// Layout is runtime-confirmed from a `gbview` dump (panel id 10000 at
/// **(281,206) 242×157**): the `typeId 3` message block at panel-relative
/// (21,45) 200×30, the text field (id 0) at (50,88) 140×12, and the two label
/// buttons — **ADD** (id 0) at (66,107) and **CLOSE** (id 1) at (151,107),
/// both 74×26.
@MainActor
public final class AddBuddyDialogWidget: Widget {

    /// The runtime panel rect (also `buddy2.img`'s size). `nonisolated` (and
    /// computed, not stored) so it stays usable from a nonisolated context,
    /// e.g. as a default parameter value.
    public nonisolated static var defaultFrame: Rect { Rect(x: 281, y: 206, width: 242, height: 157) }

    /// The default prompt (localized id ~`0x2718` in the original); the screen
    /// can pass the `Language.txt` string instead.
    public nonisolated static var defaultMessage: String { "To add your friends' ID, click his/her ID in the channel." }

    public let nameField: TextFieldWidget
    public let addButton: ButtonWidget
    public let closeButton: ButtonWidget

    /// Fired when a non-empty name is submitted (ADD or Enter).
    public var onAdd: ((String) -> Void)?
    /// Fired when CLOSE is clicked.
    public var onClose: (() -> Void)?

    public var backgroundTexture: ClientTexture?
    private let font: LoadedFont?
    private let message: String
    private let messageTint: (r: UInt8, g: UInt8, b: UInt8)

    public init(
        frame: Rect = AddBuddyDialogWidget.defaultFrame,
        font: LoadedFont?,
        background: ClientTexture? = nil,
        addTexture: ClientTexture? = nil,
        closeTexture: ClientTexture? = nil,
        message: String = AddBuddyDialogWidget.defaultMessage,
        messageTint: (r: UInt8, g: UInt8, b: UInt8) = (255, 255, 255)
    ) {
        self.font = font
        self.backgroundTexture = background
        self.message = message
        self.messageTint = messageTint

        nameField = TextFieldWidget(
            frame: Rect(x: frame.x + 50, y: frame.y + 88, width: 140, height: 12),
            font: font
        )
        nameField.maxLength = 12  // Username's fixed wire length
        addButton = ButtonWidget(
            frame: Rect(x: frame.x + 66, y: frame.y + 107, width: 74, height: 26),
            texture: addTexture
        )
        closeButton = ButtonWidget(
            frame: Rect(x: frame.x + 151, y: frame.y + 107, width: 74, height: 26),
            texture: closeTexture
        )

        super.init(frame: frame)
        add(nameField)
        add(addButton)
        add(closeButton)

        addButton.onClick = { [weak self] in self?.submit() }
        nameField.onSubmit = { [weak self] in self?.submit() }
        closeButton.onClick = { [weak self] in self?.onClose?() }
    }

    /// Clears the field and focuses it, ready to type — call when opening.
    public func reset() {
        nameField.setText("")
        nameField.focus()
    }

    private func submit() {
        let name = nameField.text.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        onAdd?(name)
    }

    public override func drawSelf(_ renderer: ClientRenderer) {
        if let backgroundTexture {
            renderer.draw(backgroundTexture, in: frame, tint: nil)
        }
        // The prompt, wrapped across the message band.
        if let font {
            let lines = message.split(separator: "\n", omittingEmptySubsequences: false)
            for (row, line) in lines.enumerated() {
                font.draw(String(line), x: frame.x + 21, y: frame.y + 45 + Float(row) * 14, tint: messageTint, using: renderer)
            }
        }
    }

    public override func handleSelf(_ event: ScreenInputEvent) -> Bool {
        // Modal within its own bounds — swallow presses so they don't fall
        // through to the panel/screen behind.
        switch event {
        case .pointerDown(let x, let y), .scroll(let x, let y, _):
            return frame.contains(x: x, y: y)
        case .pointerMoved, .pointerUp, .activate, .text, .key:
            return false
        }
    }
}
