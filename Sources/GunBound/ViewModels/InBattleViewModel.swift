import GunBoundProtocol

/// Logic for the In-Battle screen (state 11) — the first real slice of the
/// battle: the static scene. Consumes the `0x3432` start data stored in
/// `session.battle` (map + per-player spawns/tanks/turn order), drives a
/// camera over the stage world with the original's screen-edge scrolling
/// (`State11_InBattle` slot 9's 8-direction edge-scroll logic), and reacts
/// to the battle pushes: `playerDied` grays a slot, `userQuit` removes one,
/// and `gameEnded` returns everyone to the lobby.
///
/// The turn state machine, aiming/firing, ballistics, terrain destruction,
/// and the layered effect rendering are later slices — `.activate` returns
/// to the lobby as a placeholder exit until the match flow ends games
/// properly.
@MainActor
public final class InBattleViewModel: ScreenViewModel {

    /// One combatant, from the start notification.
    public struct BattlePlayer: Equatable, Sendable {
        public let slot: UInt8
        public let name: String
        public let team: Team
        public let mobile: Mobile
        /// Spawn position in stage-world coordinates.
        public let x: Float
        public let y: Float
        public let turnOrder: Int
        public var isAlive = true

        public init(slot: UInt8, name: String, team: Team, mobile: Mobile, x: Float, y: Float, turnOrder: Int) {
            self.slot = slot
            self.name = name
            self.team = team
            self.mobile = mobile
            self.x = x
            self.y = y
            self.turnOrder = turnOrder
        }
    }

    /// Half the 800×600 view — the original biases world→screen by
    /// (+400, +0x12a) after subtracting the camera.
    public static let halfView = (x: Float(400), y: Float(0x12a))

    /// Edge-scroll: the band width at each screen edge that pans the camera,
    /// and the pan speed (the original's slot-9 edge-scroll logic; the speed
    /// is approximated — not extracted from the decomp).
    public static let edgeBand: Float = 24
    public static let edgeScrollSpeed: Float = 480

    public private(set) var players: [BattlePlayer] = []
    public private(set) var map: GameMap = .random

    /// Camera center, in stage-world coordinates, clamped to the world.
    public private(set) var camera: (x: Float, y: Float) = (400, 298)
    private var worldSize: (width: Float, height: Float) = (1800, 1800)
    private var pointer: (x: Float, y: Float)?

    private var pushTask: Task<Void, Never>?
    private let delegate: ViewModelDelegate

    public init(delegate: ViewModelDelegate) {
        self.delegate = delegate
    }

    public func onEnter() {
        map = delegate.session.battle?.map ?? delegate.session.currentRoom?.map ?? .random
        players = (delegate.session.battle?.players ?? []).map {
            BattlePlayer(
                slot: $0.id,
                name: String(describing: $0.username),
                team: $0.team,
                mobile: $0.primaryTank,
                x: Float($0.xPosition),
                y: Float($0.yPosition),
                turnOrder: Int($0.turnOrder)
            )
        }
        // Start centered on our own mobile (else the first player).
        let own = players.first { $0.name == delegate.network.username } ?? players.first
        camera = (own?.x ?? Self.halfView.x, own?.y ?? Self.halfView.y)
        clampCamera()
        startObservingPushes()
    }

    public func onExit() {
        pushTask?.cancel()
        pushTask = nil
    }

    /// The screen reports the loaded stage texture's size so camera clamping
    /// matches the real world bounds (stages are 1600–2000px square).
    public func setWorldSize(width: Float, height: Float) {
        guard width > 0, height > 0 else { return }
        worldSize = (width, height)
        clampCamera()
    }

    /// The player whose turn it is (lowest turn order among the living) —
    /// display-only until the turn machine exists.
    public var currentTurnPlayer: BattlePlayer? {
        players.filter(\.isAlive).min { $0.turnOrder < $1.turnOrder }
    }

    /// World → screen: subtract the camera, bias by half the view (the
    /// original's `world − cam + (400, 0x12a)`).
    public func screenPosition(x: Float, y: Float) -> (x: Float, y: Float) {
        (x - camera.x + Self.halfView.x, y - camera.y + Self.halfView.y)
    }

    // MARK: - Server pushes

    private func startObservingPushes() {
        guard pushTask == nil, let client = delegate.client else { return }
        pushTask = Task { [weak self] in
            for await push in await client.pushes {
                guard let self, !Task.isCancelled else { return }
                self.apply(push)
            }
        }
    }

    /// Applies one battle push — split out so tests can drive it directly.
    public func apply(_ push: ServerPush) {
        switch push {
        case .playerDied(let dead):
            if let index = players.firstIndex(where: { $0.slot == dead.slot }) {
                players[index].isAlive = false
            }
        case .userQuit(let quit):
            players.removeAll { UInt16($0.slot) == quit.slot }
        case .gameEnded:
            delegate.session.battle = nil
            delegate.requestTransition(to: .gameRoomList)
        case .chatReceived, .clientPrint, .roomUpdated, .roomPlayerLeft,
             .userJoinedChannel, .gameStarted, .hostMigrated, .tunnelReceived, .raw:
            break
        }
    }

    // MARK: - Input / camera

    public func handle(_ event: ScreenInputEvent) {
        switch event {
        case .pointerMoved(let x, let y):
            pointer = (x, y)
        case .scroll(_, _, let steps):
            camera.y += Float(steps) * 40
            clampCamera()
        case .activate:
            // Placeholder exit until the match flow ends games properly.
            delegate.session.battle = nil
            delegate.requestTransition(to: .gameRoomList)
        case .pointerDown, .text, .key:
            break
        }
    }

    public func update(deltaTime: Double) {
        // The original's screen-edge camera scroll: pan while the pointer
        // sits in the edge bands (8-directional — corners pan diagonally).
        guard let pointer else { return }
        let dt = Float(deltaTime)
        var dx: Float = 0
        var dy: Float = 0
        if pointer.x < Self.edgeBand { dx = -1 } else if pointer.x > 800 - Self.edgeBand { dx = 1 }
        if pointer.y < Self.edgeBand { dy = -1 } else if pointer.y > 600 - Self.edgeBand { dy = 1 }
        guard dx != 0 || dy != 0 else { return }
        camera.x += dx * Self.edgeScrollSpeed * dt
        camera.y += dy * Self.edgeScrollSpeed * dt
        clampCamera()
    }

    private func clampCamera() {
        camera.x = min(max(Self.halfView.x, camera.x), max(Self.halfView.x, worldSize.width - Self.halfView.x))
        camera.y = min(max(Self.halfView.y, camera.y), max(Self.halfView.y, worldSize.height - Self.halfView.y))
    }
}
