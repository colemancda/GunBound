import GunBound
import GunBoundProtocol

/// The "enter room by number" dialog — the port of the decomp's
/// `BuildEnterRoomNumberDialog` (button `0xf`, `b_gamelist_directgo`; msg
/// `0x2715`): a modal panel with a single numeric field and OK/Cancel buttons,
/// sharing the Create Room dialog's OK/Cancel button class/size. Submitting
/// joins by number (`SendJoinRoomByNumber` → `0x2110`, the typed value clamped
/// 1…1000).
///
/// The decomp doesn't record the number field's exact offset, so it's placed
/// centered in the panel body (OK/Cancel use the confirmed `0x52×0x22` size);
/// the screen supplies the panel frame from the loaded `gamelist_directgo.img`.
@MainActor
public final class EnterRoomNumberDialogWidget: Widget {

    /// Valid room numbers, matching the decomp's `_atol` clamp.
    public static let numberRange = 1...1000

    public let numberField: TextFieldWidget
    public let okButton: ButtonWidget
    public let cancelButton: ButtonWidget

    /// Fired when OK is pressed with a valid number, carrying the parsed value.
    public var onSubmit: ((Int) -> Void)?
    public var onCancel: (() -> Void)?

    public var backgroundTexture: ClientTexture?

    public init(
        frame: Rect,
        font: LoadedFont?,
        background: ClientTexture? = nil,
        okTexture: ClientTexture? = nil,
        cancelTexture: ClientTexture? = nil
    ) {
        self.backgroundTexture = background

        // Number field centered in the panel body; OK/Cancel below it.
        let fieldWidth: Float = 120
        numberField = TextFieldWidget(
            frame: Rect(x: frame.x + (frame.width - fieldWidth) / 2, y: frame.y + frame.height * 0.42, width: fieldWidth, height: 16),
            font: font
        )
        numberField.characterFilter = { $0.isNumber }
        numberField.maxLength = 4
        okButton = ButtonWidget(
            frame: Rect(x: frame.x + frame.width / 2 + 8, y: frame.y + frame.height - 40, width: 82, height: 34),
            texture: okTexture
        )
        cancelButton = ButtonWidget(
            frame: Rect(x: frame.x + frame.width / 2 - 90, y: frame.y + frame.height - 40, width: 82, height: 34),
            texture: cancelTexture
        )

        super.init(frame: frame)
        add(numberField)
        add(okButton)
        add(cancelButton)

        numberField.onSubmit = { [weak self] in self?.submit() }
        okButton.onClick = { [weak self] in self?.submit() }
        cancelButton.onClick = { [weak self] in self?.onCancel?() }
    }

    public func reset() {
        numberField.setText("")
        numberField.focus()  // ready to type immediately
    }

    private func submit() {
        guard let value = Int(numberField.text), Self.numberRange.contains(value) else { return }
        onSubmit?(value)
    }

    public override func drawSelf(_ renderer: ClientRenderer) {
        if let backgroundTexture {
            renderer.draw(backgroundTexture, in: frame, tint: nil)
        }
    }

    public override func handleSelf(_ event: ScreenInputEvent) -> Bool {
        // Modal within its bounds.
        switch event {
        case .pointerDown(let x, let y):
            return frame.contains(x: x, y: y)
        case .scroll(let x, let y, _):
            return frame.contains(x: x, y: y)
        case .pointerMoved, .activate, .text, .key:
            return false
        }
    }
}
