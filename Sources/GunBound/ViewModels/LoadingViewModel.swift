import GunBoundProtocol

/// Logic for the Loading screen (state 10) — the interstitial before a match.
/// In the original this is a live per-player ready display
/// (`docs/screens/10_loading.md`): a row of per-player icons at a 44px
/// stride, each flipping from "waiting" to "ready" as that player's
/// load/checksum packet arrives, with the currently-loading player's mobile
/// icon **blinking** on a `(tick/10) & 1` parity; the screen advances to
/// In-Battle once everyone is ready.
///
/// The roster and map come from the `0x3432` start notification the Ready
/// Room stored in `session.battle` (spawn positions, tanks, turn order —
/// the data In-Battle consumes), falling back to the joined room's roster
/// when there's no battle data (offline walkthrough). Our server has no
/// per-player load/checksum opcode yet, so readiness is simulated over a
/// fixed duration — each slot flips in turn, preserving the original's
/// staggered display until a real handshake exists.
@MainActor
public final class LoadingViewModel: ScreenViewModel {
    public let backgroundImageName = "load_back.img"

    /// One roster entry being loaded — unified over the battle players
    /// (preferred) and the room roster (fallback).
    public struct LoadingPlayer: Equatable, Sendable {
        public let name: String
        public let team: Team
        public let mobile: Mobile

        public init(name: String, team: Team, mobile: Mobile) {
            self.name = name
            self.team = team
            self.mobile = mobile
        }
    }

    /// The decomp's per-player icon stride in the ready row.
    public static let readySlotStride: Float = 44
    /// The original tracks up to 16 per-player records.
    public static let maxSlots = 16

    private let duration: Double = 2.0
    private var elapsed: Double = 0
    private let delegate: ViewModelDelegate

    public init(delegate: ViewModelDelegate) {
        self.delegate = delegate
    }

    /// The stage backdrop for the match's map (`load_stage00.img` …
    /// `load_stageNN.img`, two-digit-padded by map id).
    public var stageOverlayImageName: String {
        let id = Int(map.rawValue)
        let padded = id < 10 ? "0\(id)" : "\(id)"
        return "load_stage\(padded).img"
    }

    /// The match's map — from the start notification (which resolves
    /// `.random` server-side), else the joined room.
    public var map: GameMap {
        delegate.session.battle?.map ?? delegate.session.currentRoom?.map ?? .random
    }

    /// The roster being loaded: the battle players when the match has
    /// started (the real path), else the room roster.
    public var players: [LoadingPlayer] {
        if let battle = delegate.session.battle {
            return battle.players.prefix(Self.maxSlots).map {
                LoadingPlayer(name: String(describing: $0.username), team: $0.team, mobile: $0.primaryTank)
            }
        }
        return (delegate.session.currentRoom?.players ?? []).prefix(Self.maxSlots).map {
            LoadingPlayer(name: String(describing: $0.username), team: $0.team, mobile: $0.primaryTank)
        }
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

    /// The slot currently loading (the first not-ready one), whose icon the
    /// original blinks; `nil` once everyone is ready.
    public var loadingSlot: Int? {
        (0..<players.count).first { !isReady(playerIndex: $0) }
    }

    /// The blink phase for the loading slot's icon — the decomp's
    /// `(tickCounter/10) & 1` parity at the original's 60Hz tick.
    public var blinkOn: Bool {
        (Int(elapsed * 60) / 10) & 1 == 0
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
