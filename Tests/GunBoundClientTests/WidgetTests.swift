import Foundation
import Testing
@testable import GunBound
@testable import GunBoundClient

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
        func draw(_ texture: ClientTexture, in rect: Rect, tint: (r: UInt8, g: UInt8, b: UInt8)?) {}
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
}
