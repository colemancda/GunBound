import GunBound

/// Base class of the composite UI-widget tree — the Swift counterpart of the
/// original client's `CWidget` (see GunBound-Decomp `docs/widgets.md` and the
/// reconstructed base methods in `src/cxx/Widget.cpp`): every widget, leaf or
/// container, shares one interface; containers broadcast draw/update/input
/// *down* to their children, and results bubble *up* as `Command`s to the
/// nearest ancestor with a handler (the decomp's `OnCommand(evt, id, arg) →
/// m_parent` channel).
///
/// Screens compose a root `Widget`, route events through
/// `dispatch(_:)` before their own handling, and call `draw`/`update` once —
/// the tree recurses. Frames are **absolute screen coordinates** (matching
/// how every existing screen already positions things), not parent-relative.
///
/// Two deliberate divergences from the decompiled base
/// (`Widget_DispatchMouseToChildren` `0x50eab0` / `Widget_DrawChildren`
/// `0x50e520`), both because the original's top-level panels are siblings in
/// a global *panel manager* rather than one root widget (its z-order is a
/// linked list `PanelManager_Register` inserts into front-or-back by a
/// panel flag, re-headed by `PanelManager_BringToFront` — reconstructed in
/// the decomp's `src/cxx/Panel.cpp`):
/// - **Dispatch order**: the original iterates children first-added-first;
///   ours goes last-added-first so a widget added later (a modal dialog)
///   shadows earlier siblings — the stacking the panel manager provided.
/// - **Hiding**: the original's `m_hidden` short-circuits only the
///   hit-test/input paths (the draw broadcast has no hidden check; visual
///   hiding happened at the panel-manager level); ours hides both, since
///   our root owns drawing too.
/// Confirmed matches: a child hit counts even when the point misses the
/// parent's own rect; a hidden subtree receives no input; children live in
/// **absolute** coordinates (`Widget_AddChild` `0x50e670` shifts a new
/// child by the parent's origin on insert — the convention our screens
/// already used); and pointer-*up* is a real widget event
/// (`Widget_MouseUpChildren`, vtable slot 3 — our `.pointerUp`).
@MainActor
open class Widget {

    /// A result bubbling up the tree — the decomp's `OnCommand` argument
    /// pair (e.g. its scroll widget fires `0x2000 + newPosition`).
    public struct Command: Equatable, Sendable {
        public let id: Int
        public let value: Int

        public init(id: Int, value: Int = 0) {
            self.id = id
            self.value = value
        }
    }

    public private(set) weak var parent: Widget?
    public private(set) var children: [Widget] = []

    /// Absolute screen-space bounds.
    public var frame: Rect

    /// Hidden widgets neither draw nor receive input (their subtree
    /// included).
    public var isHidden = false

    /// The upward channel: set on a container to receive commands sent by
    /// any descendant (nearest handler wins).
    public var onCommand: ((Command) -> Void)?

    public init(frame: Rect = .zero) {
        self.frame = frame
    }

    public func add(_ child: Widget) {
        child.parent = self
        children.append(child)
    }

    /// Bubbles a command up from this widget to the nearest ancestor (or
    /// self) with an `onCommand` handler.
    public func send(_ command: Command) {
        var node: Widget? = self
        while let current = node {
            if let handler = current.onCommand {
                handler(command)
                return
            }
            node = current.parent
        }
    }

    // MARK: Composite traversal

    /// Draws this widget then its children (later children on top). Override
    /// `drawSelf` for the widget's own appearance, not this.
    public func draw(_ renderer: ClientRenderer) {
        guard !isHidden else { return }
        drawSelf(renderer)
        for child in children {
            child.draw(renderer)
        }
    }

    open func drawSelf(_ renderer: ClientRenderer) {}

    open func update(deltaTime: Double) {
        for child in children {
            child.update(deltaTime: deltaTime)
        }
    }

    /// Routes an input event down the tree — children first (topmost, i.e.
    /// last-added, wins), then this widget's own `handleSelf`. Returns
    /// whether the event was consumed.
    @discardableResult
    public func dispatch(_ event: ScreenInputEvent) -> Bool {
        guard !isHidden else { return false }
        for child in children.reversed() where child.dispatch(event) {
            return true
        }
        return handleSelf(event)
    }

    /// A leaf's own input handling; return `true` to consume the event.
    open func handleSelf(_ event: ScreenInputEvent) -> Bool { false }

    /// The deepest visible widget containing the point (children searched
    /// topmost-first), or `nil`.
    public func hitTest(x: Float, y: Float) -> Widget? {
        guard !isHidden else { return nil }
        for child in children.reversed() {
            if let hit = child.hitTest(x: x, y: y) {
                return hit
            }
        }
        return frame.contains(x: x, y: y) ? self : nil
    }
}
