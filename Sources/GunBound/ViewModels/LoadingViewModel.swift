import GunBoundProtocol

/// Logic for the Loading screen (state 10) — the interstitial before a match.
/// In the original this is a live per-player ready display: each player's icon
/// flips from "waiting" to "ready" as their load/checksum packet arrives, and
/// the screen advances to In-Battle once everyone is ready
/// (`docs/screens/10_loading.md`).
///
/// There's no live battle server feeding real per-player checksum packets yet,
/// so loading progress is simulated over a fixed duration: each roster slot
/// flips to ready in turn, then the screen advances to the (minimal) In-Battle
/// state — preserving the real screen's staggered-ready behaviour and its
/// map-specific `load_stageNN.img` backdrop.
@MainActor
public final class LoadingViewModel: ScreenViewModel {
    public let backgroundImageName = "load_back.img"

    private let duration: Double = 2.0
    private var elapsed: Double = 0
    private let delegate: ViewModelDelegate

    public init(delegate: ViewModelDelegate) {
        self.delegate = delegate
    }

    /// The stage backdrop for the room's selected map (`load_stage00.img` …
    /// `load_stageNN.img`, two-digit-padded by map id).
    public var stageOverlayImageName: String {
        let id = Int(map.rawValue)
        let padded = id < 10 ? "0\(id)" : "\(id)"
        return "load_stage\(padded).img"
    }

    public var map: GameMap { delegate.session.currentRoom?.map ?? .random }

    /// The roster being loaded (from the joined room), or empty if unknown.
    public var players: [JoinRoomResponse.PlayerSession] {
        delegate.session.currentRoom?.players ?? []
    }

    /// Overall load progress, `0...1`.
    public var progress: Double { min(1, elapsed / duration) }

    /// Whether roster slot `index` has finished loading — slots complete in
    /// turn across the duration, mirroring the staggered per-player ready
    /// flips of the original.
    public func isReady(playerIndex index: Int) -> Bool {
        let count = max(players.count, 1)
        return progress >= Double(index + 1) / Double(count)
    }

    public func onEnter() {
        elapsed = 0
    }

    public func onExit() {}

    public func handle(_ event: ScreenInputEvent) {}

    public func update(deltaTime: Double) {
        elapsed += deltaTime
        if elapsed >= duration {
            delegate.requestTransition(to: .inGameSession)
        }
    }
}
