import Foundation
import Testing
@testable import GunBound
@testable import GunBoundClient
import GunBoundProtocol

@Suite @MainActor
struct WidgetTests {

    /// A widget that records whether/when it drew and can consume input.
    private final class ProbeWidget: Widget {
        static var drawOrder: [String] = []
        let name: String
        var consumesInput = false
        private(set) var handledEvents = 0

        init(name: String, frame: Rect = .zero) {
            self.name = name
            super.init(frame: frame)
        }

        override func drawSelf(_ renderer: ClientRenderer) {
            Self.drawOrder.append(name)
        }

        override func handleSelf(_ event: ScreenInputEvent) -> Bool {
            handledEvents += 1
            return consumesInput
        }
    }

    private final class NullRenderer: ClientRenderer {
        func texture(named name: String, frame frameIndex: Int, assets: AssetLibrary) -> ClientTexture? { nil }
        func size(of texture: ClientTexture?) -> (width: Float, height: Float) { (0, 0) }
        func clear() {}
        func draw(_ texture: ClientTexture, in rect: Rect, tint: (r: UInt8, g: UInt8, b: UInt8)?, blend: ClientBlendMode) {}
        func present() {}
    }

    @Test func addSetsParentAndDrawRecursesParentFirst() {
        ProbeWidget.drawOrder = []
        let root = ProbeWidget(name: "root")
        let child = ProbeWidget(name: "child")
        let grandchild = ProbeWidget(name: "grandchild")
        root.add(child)
        child.add(grandchild)

        #expect(child.parent === root)
        #expect(grandchild.parent === child)

        root.draw(NullRenderer())
        #expect(ProbeWidget.drawOrder == ["root", "child", "grandchild"])
    }

    @Test func hiddenSubtreeNeitherDrawsNorReceivesInput() {
        ProbeWidget.drawOrder = []
        let root = ProbeWidget(name: "root")
        let child = ProbeWidget(name: "child")
        root.add(child)
        child.isHidden = true

        root.draw(NullRenderer())
        #expect(ProbeWidget.drawOrder == ["root"])

        _ = root.dispatch(.activate)
        #expect(child.handledEvents == 0)
    }

    @Test func dispatchPrefersTopmostChildAndStopsWhenConsumed() {
        let root = ProbeWidget(name: "root")
        let bottom = ProbeWidget(name: "bottom")
        let top = ProbeWidget(name: "top")
        root.add(bottom)
        root.add(top)  // added last = topmost
        top.consumesInput = true

        #expect(root.dispatch(.activate))
        #expect(top.handledEvents == 1)
        #expect(bottom.handledEvents == 0)  // consumed before reaching it
        #expect(root.handledEvents == 0)
    }

    @Test func commandsBubbleToTheNearestHandler() {
        let root = Widget()
        let panel = Widget()
        let leaf = Widget()
        root.add(panel)
        panel.add(leaf)

        var rootCommands: [Widget.Command] = []
        var panelCommands: [Widget.Command] = []
        root.onCommand = { rootCommands.append($0) }
        panel.onCommand = { panelCommands.append($0) }

        leaf.send(Widget.Command(id: 7, value: 42))
        #expect(panelCommands == [Widget.Command(id: 7, value: 42)])
        #expect(rootCommands.isEmpty)  // nearest handler won
    }

    @Test func buttonClicksInsideFrameOnly() {
        let button = ButtonWidget(frame: Rect(x: 10, y: 10, width: 20, height: 20))
        var clicks = 0
        button.onClick = { clicks += 1 }

        #expect(button.dispatch(.pointerDown(x: 15, y: 15)))
        #expect(!button.dispatch(.pointerDown(x: 50, y: 50)))
        #expect(clicks == 1)

        _ = button.dispatch(.pointerMoved(x: 15, y: 15))
        #expect(button.isHovered)
        _ = button.dispatch(.pointerMoved(x: 50, y: 50))
        #expect(!button.isHovered)
    }

    @Test func scrollBarArrowsStepAndClamp() {
        let scrollBar = ScrollBarWidget(track: Rect(x: 0, y: 0, width: 20, height: 100), arrowSize: 20)
        scrollBar.contentCount = 8
        scrollBar.pageSize = 6

        var scrolls: [Int] = []
        scrollBar.onScroll = { scrolls.append($0) }

        #expect(scrollBar.maxPosition == 2)

        // Down arrow lives at the track's bottom (y 80..100).
        _ = scrollBar.dispatch(.pointerDown(x: 10, y: 90))
        _ = scrollBar.dispatch(.pointerDown(x: 10, y: 90))
        _ = scrollBar.dispatch(.pointerDown(x: 10, y: 90))  // clamped at 2
        #expect(scrollBar.position == 2)
        #expect(scrolls == [1, 2])

        // Up arrow at the top (y 0..20).
        _ = scrollBar.dispatch(.pointerDown(x: 10, y: 10))
        #expect(scrollBar.position == 1)
        #expect(scrolls == [1, 2, 1])
    }

    @Test func scrollBarFiresTheDecompCommand() {
        let root = Widget()
        let scrollBar = ScrollBarWidget(track: Rect(x: 0, y: 0, width: 20, height: 100))
        root.add(scrollBar)
        scrollBar.contentCount = 10
        scrollBar.pageSize = 6

        var commands: [Widget.Command] = []
        root.onCommand = { commands.append($0) }

        scrollBar.setPosition(3)
        #expect(commands == [Widget.Command(id: ScrollBarWidget.commandBase + 3, value: 3)])
    }

    @Test func scrollBarClampsWhenContentShrinks() {
        let scrollBar = ScrollBarWidget(track: Rect(x: 0, y: 0, width: 20, height: 100))
        scrollBar.contentCount = 10
        scrollBar.pageSize = 6
        scrollBar.setPosition(4)
        #expect(scrollBar.position == 4)

        scrollBar.contentCount = 6  // everything fits now
        #expect(scrollBar.position == 0)
    }

    @Test func dialogConfirmHidesAndFiresCallback() {
        let dialog = DialogWidget(message: "Boom", font: nil)
        var confirmed = 0
        dialog.onConfirm = { confirmed += 1 }

        // Clicking OK confirms.
        _ = dialog.dispatch(.pointerDown(x: dialog.okButton.frame.x + 1, y: dialog.okButton.frame.y + 1))
        #expect(confirmed == 1)
        #expect(dialog.isHidden)
    }

    @Test func dialogEnterConfirms() {
        let dialog = DialogWidget(message: "Boom", font: nil)
        var confirmed = 0
        dialog.onConfirm = { confirmed += 1 }

        #expect(dialog.dispatch(.activate))  // Enter
        #expect(confirmed == 1)
        #expect(dialog.isHidden)
    }

    @Test func dialogIsModalSwallowingClicksOutsideOK() {
        let dialog = DialogWidget(
            frame: Rect(x: 100, y: 100, width: 200, height: 100),
            font: nil,
            confirmFrame: Rect(x: 150, y: 170, width: 40, height: 20)
        )
        // A click anywhere (even outside the panel) is swallowed while modal,
        // so the screen behind never sees it.
        #expect(dialog.dispatch(.pointerDown(x: 500, y: 500)))
    }

    @Test func buddyPanelCloseHidesAndFiresCallback() {
        let panel = BuddyPanelWidget(font: nil)
        var closed = 0
        panel.onClose = { closed += 1 }

        _ = panel.dispatch(.pointerDown(x: panel.closeButton.frame.x + 1, y: panel.closeButton.frame.y + 1))
        #expect(closed == 1)
        #expect(panel.isHidden)
    }

    @Test func buddyPanelSwallowsClicksInsideButNotOutside() {
        let panel = BuddyPanelWidget(
            frame: Rect(x: 100, y: 100, width: 200, height: 200),
            font: nil
        )
        // A click on the panel body (not a button) is swallowed so the screen
        // behind stays inert...
        #expect(panel.dispatch(.pointerDown(x: 150, y: 150)))
        // ...but a click outside the panel passes through.
        #expect(!panel.dispatch(.pointerDown(x: 400, y: 400)))
    }

    @Test func buddyPanelRosterDrivesTheScrollbar() {
        let panel = BuddyPanelWidget(font: nil)
        #expect(panel.scrollBar.contentCount == 0)
        panel.buddies = (0..<20).map { "buddy\($0)" }
        #expect(panel.scrollBar.contentCount == 20)
        // 20 buddies, 11 visible → 9 scroll steps.
        #expect(panel.scrollBar.maxPosition == 20 - BuddyPanelWidget.visibleRows)
    }

    @Test func createRoomDialogSubmitCarriesFields() {
        let dialog = CreateRoomDialogWidget(frame: Rect(x: 200, y: 150, width: 300, height: 220), font: nil)
        var submitted: (name: String, password: String, capacity: RoomCapacity)?
        dialog.onSubmit = { submitted = ($0, $1, $2) }

        dialog.nameField.focus()
        _ = dialog.nameField.dispatch(.text("my room"))
        dialog.passwordField.focus()
        _ = dialog.passwordField.dispatch(.text("1234"))
        dialog.okButton.onClick?()

        #expect(submitted?.name == "my room")
        #expect(submitted?.password == "1234")
    }

    @Test func createRoomDialogCapacityCycles() {
        let dialog = CreateRoomDialogWidget(frame: .zero, font: nil)
        #expect(dialog.capacity == ._4_4)
        dialog.cycleCapacity()
        #expect(dialog.capacity == ._1_1)   // wraps past the end
        dialog.cycleCapacity()
        #expect(dialog.capacity == ._2_2)
    }

    @Test func createRoomDialogFieldsAreMutuallyExclusive() {
        let dialog = CreateRoomDialogWidget(frame: Rect(x: 0, y: 0, width: 300, height: 220), font: nil)
        dialog.nameField.focus()
        #expect(dialog.nameField.isFocused)
        dialog.passwordField.focus()
        #expect(dialog.passwordField.isFocused)
        #expect(!dialog.nameField.isFocused)   // focusing password blurred name
    }

    @Test func enterNumberDialogSubmitsValidNumbersOnly() {
        let dialog = EnterRoomNumberDialogWidget(frame: Rect(x: 250, y: 200, width: 300, height: 180), font: nil)
        var joined: Int?
        dialog.onSubmit = { joined = $0 }

        dialog.numberField.focus()
        _ = dialog.numberField.dispatch(.text("42"))
        dialog.okButton.onClick?()
        #expect(joined == 42)

        // Out of range → no submit.
        joined = nil
        dialog.numberField.setText("0")
        dialog.okButton.onClick?()
        #expect(joined == nil)
    }

    @Test func enterNumberDialogRejectsNonDigits() {
        let dialog = EnterRoomNumberDialogWidget(frame: .zero, font: nil)
        dialog.numberField.focus()
        _ = dialog.numberField.dispatch(.text("1a2b"))
        #expect(dialog.numberField.text == "12")
    }

    @Test func channelUserListScrollsItsRoster() {
        let panel = ChannelUserListWidget(font: nil)
        #expect(panel.frame == Rect(x: 572, y: 287, width: 209, height: 259))
        panel.users = (0..<10).map { "user\($0)" }
        #expect(panel.scrollBar.contentCount == 10)
        // 10 users over 7 visible rows → 3 scroll steps.
        #expect(panel.scrollBar.maxPosition == 3)
        // Down knob (the baked circle below the track — measured at
        // panel-relative (174, 219) 28×28).
        _ = panel.dispatch(.pointerDown(x: 572 + 174 + 14, y: 287 + 219 + 14))
        #expect(panel.scrollBar.position == 1)
        // Clicks on the panel body fall through (not modal chrome).
        #expect(!panel.dispatch(.pointerDown(x: 600, y: 400)))
    }

    @Test func lobbyChatSubmitsAndClearsTheInput() {
        let panel = LobbyChatWidget(font: nil)
        #expect(panel.frame == Rect(x: 23, y: 287, width: 549, height: 259))
        var sent: [String] = []
        panel.onSend = { sent.append($0) }

        panel.inputField.focus()
        _ = panel.inputField.dispatch(.text("hello"))
        _ = panel.dispatch(.activate)
        #expect(sent == ["hello"])
        #expect(panel.inputField.text.isEmpty)
        #expect(panel.inputField.isFocused)  // keeps focus for the next line

        // Blank lines don't send.
        _ = panel.inputField.dispatch(.text("   "))
        _ = panel.dispatch(.activate)
        #expect(sent == ["hello"])
    }

    @Test func lobbyChatFollowsTheTailUnlessScrolledUp() {
        let panel = LobbyChatWidget(font: nil)
        panel.messages = (1...20).map { ChatLine(message: "line \($0)") }
        // 20 lines over 13 rows → tail position 7, followed automatically.
        #expect(panel.scrollBar.position == 7)

        // Player scrolls up to read history; new lines stop yanking the view.
        panel.scrollBar.setPosition(2)
        panel.messages.append(ChatLine(message: "line 21"))
        #expect(panel.scrollBar.position == 2)

        // Back at the tail, following resumes.
        panel.scrollBar.setPosition(panel.scrollBar.maxPosition)
        panel.messages.append(ChatLine(message: "line 22"))
        #expect(panel.scrollBar.position == panel.scrollBar.maxPosition)
    }

    /// The color table matches the decompiled renderer's switch: normal chat
    /// is white on white, the type-2 notice draws its message in RGB565
    /// 0xffe0 (pure yellow), and unknown types fall back to normal.
    @Test func chatColorsFollowTheDecompTable() {
        let normal = LobbyChatWidget.colors(for: .normal)
        #expect(normal.name == (255, 255, 255))
        #expect(normal.message == (255, 255, 255))

        let notice = LobbyChatWidget.colors(for: .notice)
        #expect(notice.message == (255, 255, 0))   // 0xffe0 → yellow

        let type3 = LobbyChatWidget.colors(for: .init(rawValue: 3))
        #expect(type3.name == (255, 0, 0))         // 0xf800 → red

        let unknown = LobbyChatWidget.colors(for: .init(rawValue: 0x40))
        #expect(unknown.message == (255, 255, 255))
    }

    /// A wheel over a scroll panel steps its scrollbar (positive = down) and
    /// is consumed; outside the panel it falls through. Modal dialogs swallow
    /// wheel events so nothing scrolls behind them.
    @Test func wheelScrollsPanelsAndRespectsModals() {
        let chat = LobbyChatWidget(font: nil)
        chat.messages = (1...30).map { ChatLine(message: "line \($0)") }
        chat.scrollBar.setPosition(0)

        // Inside the panel: scroll down two steps, then back up one.
        #expect(chat.dispatch(.scroll(x: 100, y: 400, steps: 2)))
        #expect(chat.scrollBar.position == 2)
        #expect(chat.dispatch(.scroll(x: 100, y: 400, steps: -1)))
        #expect(chat.scrollBar.position == 1)

        // Outside: passes through, position unchanged.
        #expect(!chat.dispatch(.scroll(x: 700, y: 100, steps: 1)))
        #expect(chat.scrollBar.position == 1)

        // A modal dialog swallows the wheel.
        let dialog = DialogWidget(font: nil)
        #expect(dialog.dispatch(.scroll(x: 400, y: 300, steps: 1)))
    }

    @Test func hiddenDialogLetsInputThroughToSiblings() {
        // A hidden dialog must not shadow the widgets behind it.
        let root = ProbeWidget(name: "root")
        let behind = ProbeWidget(name: "behind")
        behind.consumesInput = true
        let dialog = DialogWidget(message: "x", font: nil)
        dialog.isHidden = true
        root.add(behind)
        root.add(dialog)  // topmost, but hidden

        #expect(root.dispatch(.pointerDown(x: 0, y: 0)))
        #expect(behind.handledEvents == 1)
    }
}
