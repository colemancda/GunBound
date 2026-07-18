import Foundation
import Testing
@testable import GunBound
@testable import GunBoundClient
import GunBoundFile
import GunBoundProtocol

/// Drives the dialog and panel widgets directly — draw plus a spread of
/// clicks, text, keys, and drags over their frame — so their draw and
/// input-handling branches (buttons, text fields, close/confirm) run.
@Suite @MainActor
struct WidgetInteractionTests {

    private let tex = ScreenHarness.Texture("bg", 0)

    private func drive(_ widget: Widget, over frame: Rect) {
        let renderer = ScreenHarness.Renderer()
        widget.draw(renderer)
        for x in stride(from: frame.x, through: frame.x + frame.width, by: 20) {
            for y in stride(from: frame.y, through: frame.y + frame.height, by: 20) {
                _ = widget.dispatch(.pointerMoved(x: x, y: y))
                _ = widget.dispatch(.pointerDown(x: x, y: y))
                _ = widget.dispatch(.pointerUp(x: x, y: y))
            }
        }
        for text in ["hello", "friend", "12"] {
            _ = widget.dispatch(.text(text))
        }
        for key: ScreenInputEvent.Key in [.backspace, .left, .right] {
            _ = widget.dispatch(.key(key))
        }
        _ = widget.dispatch(.activate)
        widget.draw(renderer)
        #expect(!renderer.draws.isEmpty)
    }

    @Test func dialogWidget() {
        let widget = DialogWidget(message: "An error occurred", font: nil, background: tex, confirmTexture: tex)
        var confirmed = false
        widget.onConfirm = { confirmed = true }
        drive(widget, over: DialogWidget.defaultFrame)
        _ = confirmed  // may or may not fire depending on where the confirm rect is hit
    }

    @Test func createRoomDialogWidget() {
        let frame = Rect(x: 248, y: 158, width: 304, height: 220)
        let widget = CreateRoomDialogWidget(frame: frame, font: nil, background: tex, okTexture: tex, cancelTexture: tex)
        widget.onSubmit = { (_: String, _: String, _: RoomCapacity) in }
        widget.onCancel = {}
        drive(widget, over: frame)
    }

    @Test func buddyChatWindowWidget() {
        let widget = BuddyChatWindowWidget(recipient: "alice", font: nil, background: tex, closeTexture: tex)
        widget.onSend = { _ in }
        widget.onClose = {}
        widget.messages = [ChatLine(message: "hi", type: .normal), ChatLine(sender: "alice", message: "hey", type: .normal)]
        drive(widget, over: BuddyChatWindowWidget.defaultFrame)
    }

    @Test func addBuddyDialogWidget() {
        let widget = AddBuddyDialogWidget(font: nil, background: tex, addTexture: tex, closeTexture: tex)
        widget.onAdd = { _ in }
        widget.onClose = {}
        drive(widget, over: AddBuddyDialogWidget.defaultFrame)
    }

    @Test func buddyPanelWidget() {
        let widget = BuddyPanelWidget(font: nil, background: tex, addTexture: tex, delTexture: tex, closeTexture: tex)
        widget.buddies = ["alice", "bob", "carol"]
        drive(widget, over: BuddyPanelWidget.defaultFrame)
    }
}
