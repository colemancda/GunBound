import GunBound

/// The interaction state of a GunBound bottom-bar / toggle button, mapped to
/// the frame index inside its `.img` sheet. The original art packs each
/// button's states as consecutive frames in a fixed order:
///
/// | frame | state      |
/// |-------|------------|
/// | 0     | default    |
/// | 1     | hovered    |
/// | 2     | pressed    |
/// | 3     | disabled   |
/// | 4     | selected   |
///
/// Plain action buttons ship the first four frames; toggle buttons (the room
/// list's View All / Waiting filters, the store's category tabs) add the 5th
/// `selected` frame. This replaces the earlier hand-tinted state fakery
/// (dimming/blue-shifting frame 0) with the real per-state artwork.
public enum ButtonState: Equatable, Sendable {
    /// Frame 0 — the resting state.
    case normal
    /// Frame 1 — the pointer is over the button.
    case hovered
    /// Frame 2 — the button is held down.
    case pressed
    /// Frame 3 — the button can't be actioned.
    case disabled
    /// Frame 4 — a toggle button that is the current selection.
    case selected

    /// The number of distinct button-state frames (frames 0…4).
    public static let stateCount = 5

    /// The frame index this state draws from a button sheet.
    public var frame: Int {
        switch self {
        case .normal: return 0
        case .hovered: return 1
        case .pressed: return 2
        case .disabled: return 3
        case .selected: return 4
        }
    }
}

/// A button's state artwork: the frames of its `.img` sheet, addressed by
/// `ButtonState`. Loads only the frames the sheet actually contains (four for
/// plain buttons, five for toggles) so a state with no dedicated frame falls
/// back to the default frame instead of failing.
@MainActor
public struct ButtonSprite {

    /// The loaded frames, index 0…count-1. `nil` entries are frames that
    /// failed to decode.
    private let frames: [ClientTexture?]

    public init(name: String, renderer: ClientRenderer, assets: AssetLibrary) {
        // Query the real frame count so we never ask the renderer for a frame
        // the sheet lacks (which would log a spurious load warning), capped at
        // the five button states. When the count can't be read (e.g. a test
        // with no on-disk assets) default to all five state frames.
        let available = (try? assets.image(named: name).count) ?? ButtonState.stateCount
        let count = max(1, min(available, ButtonState.stateCount))
        self.frames = (0..<count).map { renderer.texture(named: name, frame: $0, assets: assets) }
    }

    /// The texture for `state`, or the default frame when the sheet has no
    /// frame for that state (e.g. asking a 4-frame action button for
    /// `.selected`).
    public func texture(for state: ButtonState) -> ClientTexture? {
        if frames.indices.contains(state.frame), let texture = frames[state.frame] {
            return texture
        }
        return frames.first ?? nil
    }
}
