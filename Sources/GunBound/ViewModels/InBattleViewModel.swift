import Foundation
import GunBoundProtocol

/// The terrain queries the battle needs — implemented by the client layer's
/// `.lnd` mask parser (the per-pixel stage collision map). A protocol here
/// because the `GunBound` module doesn't depend on the file-format library.
public protocol BattleTerrain: Sendable {
    /// Whether the cell at (x, y) is solid ground (out of bounds = air).
    func isSolid(x: Int, y: Int) -> Bool
    /// The terrain-surface y at column `x` nearest `y` (up out of ground,
    /// or down onto it); `nil` off the map.
    func surfaceLevel(atX x: Int, near y: Int) -> Int?
}

/// Logic for the In-Battle screen (state 11) — the playable slice: the
/// static scene (spawns/camera from the `0x3432` start data, the original's
/// edge-scrolled camera) plus the fire loop — walk with ◀/▶, aim with ▲/▼,
/// charge and release with Enter (the original's control scheme), a
/// parabolic projectile that collides with the `.lnd` terrain, splash
/// damage, and turn cycling. Shots and moves relay to the other players
/// through the server tunnel (`0x4500`), and every client resolves the
/// same deterministic simulation.
///
/// **Documented divergence**: the original client sends only angle+power and
/// the *server* resolves the shot (the `0x8403` payload's eight
/// server-computed shorts — no local ballistics in the client at all). Our
/// server doesn't simulate shots, so the clients run identical local
/// physics off the relayed angle/power instead. Wind, walking, item use,
/// and terrain destruction are later slices.
@MainActor
public final class InBattleViewModel: ScreenViewModel {

    /// The three weapon slots (the original's shot 1 / shot 2 / SS —
    /// selection plays `b_play_weapon1/2/3`, and a fresh room resets the
    /// slot fields to the `0xff` "no weapon" sentinel).
    public enum Weapon: UInt8, CaseIterable, Equatable, Sendable {
        case shot1 = 1
        case shot2 = 2
        case special = 3

        /// The next slot in Tab-cycle order.
        public var next: Weapon {
            switch self {
            case .shot1: return .shot2
            case .shot2: return .special
            case .special: return .shot1
            }
        }
    }

    /// A weapon's blast: the decomp's per-weapon inner/mid/outer
    /// (內/中/外) damage rings plus the hole it carves. Uniform across
    /// mobiles until the per-weapon `characterdata.dat` groups are
    /// decoded; shot 2 and the SS trade a bigger, harder blast for the
    /// original's delay cost (no delay system yet).
    public struct WeaponProfile: Sendable {
        public let damageTiers: [(radius: Float, damage: Int)]
        public let craterRadius: Float
        /// The outermost ring — the splash/visual radius.
        public var blastRadius: Float { damageTiers.last?.radius ?? 0 }
    }

    public static func profile(for weapon: Weapon) -> WeaponProfile {
        switch weapon {
        case .shot1:
            return WeaponProfile(damageTiers: [(18, 320), (36, 220), (55, 120)], craterRadius: 44)
        case .shot2:
            return WeaponProfile(damageTiers: [(20, 420), (40, 300), (60, 170)], craterRadius: 52)
        case .special:
            return WeaponProfile(damageTiers: [(24, 550), (46, 400), (70, 240)], craterRadius: 62)
        }
    }

    /// A mobile's animation pose — the semantic state the view maps onto
    /// the sheet's `.epa` frame runs (`normal`, `move`, the per-weapon
    /// `fire1`/`fire2`/`sfire`, `shock`, `dead`, and the `w`-prefixed
    /// wounded variants at half HP).
    public enum MobilePose: Equatable, Sendable {
        case normal
        case move
        case fire(Weapon)
        case shock
        case dead
    }

    /// One combatant, from the start notification.
    public struct BattlePlayer: Equatable, Sendable {
        public let slot: UInt8
        public let name: String
        public let team: Team
        /// The mobile in play — the primary tank until a Tag-mode swap
        /// brings in the secondary.
        public var mobile: Mobile
        /// Tag mode's backup mobile (the room's secondary tank pick).
        public let secondaryMobile: Mobile
        /// Whether the Tag-mode swap has been spent — the next death is
        /// final.
        public var hasTagged = false
        /// Position in stage-world coordinates — the spawn from the start
        /// notification, then updated by walking (`y` snaps to the terrain
        /// surface once the mask is loaded).
        public var x: Float
        public var y: Float
        /// The original spawn column — where score-mode respawns land.
        public let spawnX: Float
        public let turnOrder: Int
        /// Remaining hit points; the mobile dies at 0. `characterdata.dat`
        /// carries a per-mobile Max HP (and shield) pool — uniform until
        /// those records are decoded.
        public var hp = InBattleViewModel.maxHP
        public var isAlive = true
        /// The current animation pose and the battle-clock time it began
        /// (walking refreshes it every step; transient poses expire back
        /// to `.normal`).
        public var pose: MobilePose = .normal
        public var poseStarted: Double = 0

        public init(slot: UInt8, name: String, team: Team, mobile: Mobile, secondaryMobile: Mobile = .random, x: Float, y: Float, turnOrder: Int) {
            self.slot = slot
            self.name = name
            self.team = team
            self.mobile = mobile
            self.secondaryMobile = secondaryMobile
            self.x = x
            self.y = y
            self.spawnX = x
            self.turnOrder = turnOrder
        }
    }

    /// One entry in the battle's damage ledger — the shape of the decomp's
    /// `0x8404` hit-log record (a numeric value, a target id, and two
    /// bytes, which we map to the attacker slot and the cause).
    public struct DamageEvent: Equatable, Sendable {
        public enum Cause: UInt8, Equatable, Sendable {
            case shot = 0
            /// Fell out of the world through a blown-through column.
            case fallOut = 1
        }
        public let value: Int
        public let targetSlot: UInt8
        public let attackerSlot: UInt8
        public let cause: Cause
    }

    /// The turn/fire state machine (a simplified local stand-in for the
    /// original's `ProcessBattleAction` turn machine).
    public enum TurnPhase: Equatable, Sendable {
        /// Another player's turn (or a remote shot resolving).
        case waiting
        /// Our turn: ◀/▶ walk, ▲/▼ aim, Enter starts the charge.
        case aiming
        /// Power charging; Enter (or a full gauge) fires.
        case charging
        /// A projectile is in flight (ours or a relayed remote shot).
        case projectileInFlight
        /// The explosion is playing; damage + turn advance on completion.
        case impact
    }

    public struct Projectile: Equatable, Sendable {
        public var x: Float
        public var y: Float
        public var vx: Float
        public var vy: Float
    }

    public struct Explosion: Equatable, Sendable {
        public let x: Float
        public let y: Float
        /// The firing weapon's outer blast ring (drives the visual size).
        public let blastRadius: Float
        public var age: Double = 0

        public init(x: Float, y: Float, blastRadius: Float) {
            self.x = x
            self.y = y
            self.blastRadius = blastRadius
        }
    }

    /// A hole blasted out of the terrain — collision is the `.lnd` mask
    /// minus these (the visual crater discs draw from the same list).
    public struct Crater: Equatable, Sendable {
        public let x: Float
        public let y: Float
        public let radius: Float

        public init(x: Float, y: Float, radius: Float) {
            self.x = x
            self.y = y
            self.radius = radius
        }
    }

    // MARK: Tuning

    /// Half the 800×600 view — the original biases world→screen by
    /// (+400, +0x12a) after subtracting the camera.
    public static let halfView = (x: Float(400), y: Float(0x12a))
    /// Decomp-exact edge-scroll trigger band (`State11_InBattle_OnTick`):
    /// the cursor triggers scroll within 5px of the 800×600 screen edge
    /// (`<5` / `>0x31b`=795 for X, `<5` / `>0x253`=595 for Y).
    public static let edgeBand: Float = 5
    public static let edgeScrollSpeed: Float = 480
    /// Elevation limits (degrees) and the per-keypress step.
    public static let aimRange: ClosedRange<Float> = 10...80
    public static let aimStep: Float = 2
    /// Seconds to charge the gauge from empty to full (auto-fires at full).
    public static let chargeDuration: Double = 1.5
    /// Muzzle speed at full power (px/s) and gravity (px/s², y-down world).
    public static let maxShotSpeed: Float = 900
    public static let gravity: Float = 450
    /// The explosion's display time.
    public static let explosionDuration: Double = 0.7
    /// Every mobile's HP pool. `characterdata.dat` stores per-mobile
    /// Max HP/Shield values (the editor dialog's 최대체력/최대쉴드 fields);
    /// a uniform pool stands in until those records are decoded.
    /// (`nonisolated`: it seeds `BattlePlayer.hp`'s default outside the
    /// main actor.)
    public nonisolated static let maxHP = 1000
    /// The turn time limit — the classic 60 seconds (the Loading handler
    /// writes the battle's timer field checked against 60,000 ms).
    public static let turnDuration: Double = 60
    /// Wind range (horizontal acceleration, px/s²) — re-rolled every turn,
    /// carried in the fire payload so remote sims match the shooter's.
    public static let windRange: ClosedRange<Float> = -120...120
    /// Walking: px per ◀/▶ key event (key repeat gives continuous motion),
    /// the per-turn movement budget, and the biggest vertical rise one step
    /// can climb. `characterdata.dat` stores per-mobile move distance
    /// (이동 거리) and max incline (최대등판각) — uniform values stand in
    /// until those records are decoded.
    public static let walkStep: Float = 4
    public static let moveBudgetPerTurn: Float = 120
    public static let maxClimb: Float = 8

    // MARK: State

    public private(set) var players: [BattlePlayer] = []
    public private(set) var map: GameMap = .random
    public private(set) var phase: TurnPhase = .waiting
    public private(set) var aimAngle: Float = 45
    /// Charge level, `0…1`, while `phase == .charging`.
    public private(set) var power: Float = 0
    public private(set) var projectile: Projectile?
    public private(set) var explosion: Explosion?
    public private(set) var terrain: (any BattleTerrain)?
    /// Blast holes carved so far (collision + visuals).
    public private(set) var craters: [Crater] = []
    /// This turn's wind (px/s² horizontal). Positive blows right.
    public private(set) var wind: Float = 0
    /// The wind the in-flight shot was fired under (the shooter's roll).
    private var shotWind: Float = 0
    /// The slot that fired the in-flight shot — credited in the ledger.
    private var shotAttacker: UInt8?
    /// The weapon the in-flight shot was fired with (sets the blast).
    private var shotWeapon: Weapon = .shot1
    /// The in-flight shot's visual identity (the shooter's mobile and
    /// weapon) — what the view picks `bullet<N><n|p|s>.img` art with;
    /// `nil` between shots.
    public private(set) var activeShot: (mobile: Mobile, weapon: Weapon)?
    /// The local player's selected weapon slot (Tab cycles it).
    public private(set) var selectedWeapon: Weapon = .shot1
    /// Seconds left on the acting player's turn; expiry forfeits it.
    public private(set) var turnRemaining: Double = InBattleViewModel.turnDuration

    // MARK: - Battle items (visual only)

    /// One battle-usable item, keyed by its **ordinal** — the 0–63 index
    /// used by the server's ownership bitmask, the Ready Room loadout array,
    /// and the `DAT_0056dc40` icon table alike (decomp `703fd5f`).
    public struct BattleItem: Equatable, Sendable {
        /// The item's ordinal (0–10 for the battle-usable set).
        public let ordinal: Int
        /// Display name, resolved from the catalog.
        public let name: String
        /// The packed shelf-icon code (`DAT_0056dc40[ordinal]`) — decode via
        /// `ItemDataFile.shelfIcon(forCode:)` for its sheet + frame.
        public let iconCode: UInt16
    }

    /// The eleven battle-usable items, ordinal-ordered — a **decomp-exact**
    /// table: names + `DAT_0056dc40[0…10]` icon codes from `703fd5f`
    /// (every code cross-checks against the matching `itemdata.dat` record's
    /// `0x30` field).
    public static let allBattleItems: [BattleItem] = [
        BattleItem(ordinal: 0, name: "Dual", iconCode: 0xff01),
        BattleItem(ordinal: 1, name: "Blood", iconCode: 0x0003),
        BattleItem(ordinal: 2, name: "Energy up 2", iconCode: 0xff07),
        BattleItem(ordinal: 3, name: "Energy up 1", iconCode: 0x0007),
        BattleItem(ordinal: 4, name: "Dual+", iconCode: 0xff02),
        BattleItem(ordinal: 5, name: "Change Wind", iconCode: 0x000f),
        BattleItem(ordinal: 6, name: "Team Teleport", iconCode: 0xff0b),
        BattleItem(ordinal: 7, name: "Bunge shot", iconCode: 0x0001),
        BattleItem(ordinal: 8, name: "Power up", iconCode: 0x0002),
        BattleItem(ordinal: 9, name: "Thunder", iconCode: 0xff06),
        BattleItem(ordinal: 10, name: "Teleport", iconCode: 0xff0a),
    ]

    /// The player's owned-item bitmask (bit *i* = owns battle item *i*) — the
    /// real wire shape.
    ///
    /// **Effect-free, and an invented ownership set — both faithful to the
    /// client's actual role.** The decomp (`ba1715b`/`703fd5f`; PROTOCOL.md
    /// "Item availability") confirms there is **no client→server item-use
    /// action**: item effects (Dual, Power-up, Teleport, …) resolve
    /// server-side and are broadcast back (action `0x8400`), so the client
    /// never transmits an item use — selecting one is inherently a display
    /// affordance. Ownership itself arrives as a server-pushed 64-bit
    /// bitmask, which the Ready Room builder packs into its loadout array by
    /// ordinal. Offline there's no server pushing it, so this is a fixed
    /// default set; the item *identities and icons* are decomp-exact.
    public private(set) var ownedItems: UInt64 = (
        1 << 0 | 1 << 4 | 1 << 5 | 1 << 8 | 1 << 9 | 1 << 10   // Dual, Dual+, Change Wind, Power up, Thunder, Teleport
    )

    /// The owned battle items, in ordinal order — what the quick-bar shows
    /// (mirrors the loadout builder scanning the mask low-bit first).
    public var battleItems: [BattleItem] {
        Self.allBattleItems.filter { ownedItems & (1 << $0.ordinal) != 0 }
    }

    /// The highlighted loadout slot, if any — visual selection only.
    public private(set) var selectedItemIndex: Int?

    /// The item quick-bar's slot strip: a left-to-right row above the bottom
    /// HUD bar. Uniform slots (the double-wide items are drawn scaled to fit
    /// by the view); geometry is our own, as the original's bar lives in the
    /// undecodable `.xtf` interface overlay.
    public static let itemBarOrigin = (x: Float(548), y: Float(520))
    public static let itemSlotSize = (width: Float(38), height: Float(33))

    public static func itemSlotRect(at index: Int) -> Rect {
        Rect(
            x: itemBarOrigin.x + Float(index) * itemSlotSize.width,
            y: itemBarOrigin.y,
            width: itemSlotSize.width,
            height: itemSlotSize.height
        )
    }

    /// Toggles the highlighted loadout slot (visual only). Ignites nothing.
    public func selectItem(at index: Int) {
        guard battleItems.indices.contains(index) else { return }
        selectedItemIndex = (selectedItemIndex == index) ? nil : index
    }

    /// The battle's game mode, from the start notification's settings
    /// (the `settings >> 16` mode word). Solo/Tag play as eliminations;
    /// Score adds shared team life pools with respawns. Jewel renders its
    /// identity but plays as an elimination until jewel objects are
    /// modeled (the decomp's JewelTexture layer and the `0x4200` summary
    /// flow are documented but the jewel spawn data isn't).
    public private(set) var gameMode: GunBoundProtocol.GameMode = .solo
    /// Score mode's shared life pools, `nil` in other modes. Every client
    /// derives the pool from the same head-count formula the server uses
    /// and decrements it on each death — deterministic, no score wire
    /// traffic needed.
    public private(set) var teamLives: (a: Int, b: Int)?
    /// How long a score-mode death benches the player before the respawn.
    public static let respawnDelay: Double = 3
    /// Slots waiting to respawn, with their due time on the battle clock.
    private var pendingRespawns: [(slot: UInt8, time: Double)] = []

    /// Score mode's per-team life pool for a head count — the server's
    /// formula (half the players, rounded up to even, plus one).
    public static func scoreLives(forPlayerCount count: Int) -> Int {
        var lives = count / 2
        if lives % 2 != 0 { lives += 1 }
        return lives + 1
    }

    /// The match's winning team once one side is wiped — `nil` while the
    /// match runs, and also `nil` on an everyone-dead draw (check
    /// `isMatchOver` to distinguish). Set by the server's game-end push
    /// online, by the local wipe check offline.
    public private(set) var winner: Team?
    /// Whether the match has ended (the result lingers on screen for
    /// `matchEndDelay`, then the battle returns to the room).
    public private(set) var isMatchOver = false
    /// How long the result banner shows before leaving the battle.
    public static let matchEndDelay: Double = 3
    private var matchEndCountdown: Double?
    /// Every hit so far, in order (the `0x8404` hit log).
    public private(set) var damageLedger: [DamageEvent] = []
    /// The acting remote player's live aim (angle/power/direction), relayed
    /// as they adjust — the decomp's `0x8402`/`0x8406` aim broadcast.
    public private(set) var remoteAim: (angle: Float, power: Float, direction: Float)?
    /// Movement budget left this turn (px of walking).
    public private(set) var moveBudget: Float = InBattleViewModel.moveBudgetPerTurn
    /// The battle clock (seconds since entry) — the timebase for poses and
    /// the view's animation frame selection.
    public private(set) var clock: Double = 0
    /// The battle chat overlay's history — the decomp's fixed rotating
    /// buffer (`AddChatLine` dequeues the oldest line past 8).
    public private(set) var chatLines: [ChatLine] = []
    public static let maxChatLines = 8
    /// The chat composer's draft, `nil` when closed. Typing any printable
    /// character opens it seeded with that character; Enter sends.
    public private(set) var chatDraft: String?
    public static let maxChatDraftLength = 60

    /// A sound cue for the view to play — the model names the moment, the
    /// view maps it onto `sound.xfs` entries (`<N><weapon>fire.xes`,
    /// `<N><weapon>blast.xes`, `<N>move.xes`, `turn.xes`, `turnwa.xes`).
    public enum BattleSound: Equatable, Sendable {
        case fire(Mobile, Weapon)
        case blast(Mobile, Weapon)
        case walk(Mobile)
        /// Our turn began.
        case turnStart
        /// Ten seconds left on the turn clock.
        case turnWarning
    }

    /// Cues emitted since the last drain (the view empties this per frame).
    public private(set) var soundQueue: [BattleSound] = []
    /// Walk steps repeat at key-repeat rate; cues are throttled to this gap.
    public static let walkCueInterval: Double = 0.25
    private var lastWalkCue: Double = -1

    /// Hands the pending cues to the view and clears the queue.
    public func drainSounds() -> [BattleSound] {
        defer { soundQueue = [] }
        return soundQueue
    }
    /// How long the transient poses run before reverting to `.normal`
    /// (a walk step refreshes `.move`; the sheet runs are 10–25 frames).
    public static let movePoseLinger: Double = 0.3
    public static let firePoseDuration: Double = 0.9
    public static let shockPoseDuration: Double = 0.9

    /// Camera center, in stage-world coordinates, clamped to the world.
    public private(set) var camera: (x: Float, y: Float) = (400, 298)
    private var worldSize: (width: Float, height: Float) = (1800, 1800)
    private var pointer: (x: Float, y: Float)?
    /// The turn-order value whose owner is acting now.
    private var turnCursor = 0

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
                secondaryMobile: $0.secondaryTank,
                x: Float($0.xPosition),
                y: Float($0.yPosition),
                turnOrder: Int($0.turnOrder)
            )
        }
        let settings = delegate.session.battle?.settings ?? 0
        gameMode = GunBoundProtocol.GameMode(settings: settings) ?? .solo
        teamLives = gameMode == .score && players.count > 1
            ? (a: Self.scoreLives(forPlayerCount: players.count), b: Self.scoreLives(forPlayerCount: players.count))
            : nil
        pendingRespawns = []
        turnCursor = players.map(\.turnOrder).min() ?? 0
        phase = isMyTurn ? .aiming : .waiting
        aimAngle = 45
        power = 0
        projectile = nil
        explosion = nil
        activeShot = nil
        craters = []
        damageLedger = []
        remoteAim = nil
        shotAttacker = nil
        selectedItemIndex = nil
        moveBudget = Self.moveBudgetPerTurn
        clock = 0
        chatLines = []
        chatDraft = nil
        selectedWeapon = .shot1
        turnRemaining = Self.turnDuration
        soundQueue = []
        lastWalkCue = -1
        winner = nil
        isMatchOver = false
        matchEndCountdown = nil
        wind = Float.random(in: Self.windRange)
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

    /// The stage's terrain mask, once the screen has loaded the `.lnd` —
    /// snapping every mobile onto the terrain surface at its spawn column.
    public func setTerrain(_ terrain: any BattleTerrain) {
        self.terrain = terrain
        for index in players.indices {
            let player = players[index]
            if let surface = terrain.surfaceLevel(atX: Int(player.x), near: Int(player.y)) {
                players[index].y = Float(surface)
            }
        }
        // Re-center on our own (now grounded) mobile.
        if let own = players.first(where: { $0.name == delegate.network.username }) ?? players.first {
            camera = (own.x, own.y)
            clampCamera()
        }
    }

    // MARK: Turn state

    /// The acting player — the owner of the current turn cursor.
    public var currentTurnPlayer: BattlePlayer? {
        players.first { $0.turnOrder == turnCursor && $0.isAlive }
            ?? players.filter(\.isAlive).min { $0.turnOrder < $1.turnOrder }
    }

    /// Whether the local player is acting. Offline (no connection) every
    /// turn is locally controllable, keeping the loop playable solo.
    public var isMyTurn: Bool {
        guard let current = currentTurnPlayer else { return false }
        return delegate.client == nil || current.name == delegate.network.username
    }

    /// Shot damage dealt per attacker, highest first — the live ranking the
    /// decomp maintains by re-sorting after every `0x8404` log append.
    public var damageRanking: [(slot: UInt8, total: Int)] {
        var totals: [UInt8: Int] = [:]
        for event in damageLedger where event.cause == .shot {
            totals[event.attackerSlot, default: 0] += event.value
        }
        return totals.map { (slot: $0.key, total: $0.value) }
            .sorted { $0.total > $1.total }
    }

    private func advanceTurn() {
        let living = players.filter(\.isAlive).map(\.turnOrder).sorted()
        guard !living.isEmpty else { return }
        turnCursor = living.first { $0 > turnCursor } ?? living[0]
        phase = isMyTurn ? .aiming : .waiting
        power = 0
        remoteAim = nil
        activeShot = nil
        moveBudget = Self.moveBudgetPerTurn
        turnRemaining = Self.turnDuration
        if isMyTurn {
            soundQueue.append(.turnStart)
        }
        wind = Float.random(in: Self.windRange)
        // Snap the camera back to the new acting player.
        if let current = currentTurnPlayer {
            camera = (current.x, current.y)
            clampCamera()
        }
    }

    /// World → screen: subtract the camera, bias by half the view (the
    /// original's `world − cam + (400, 0x12a)`).
    public func screenPosition(x: Float, y: Float) -> (x: Float, y: Float) {
        (x - camera.x + Self.halfView.x, y - camera.y + Self.halfView.y)
    }

    /// Solid terrain = the `.lnd` mask minus every carved crater.
    public func isSolidGround(x: Float, y: Float) -> Bool {
        guard terrain?.isSolid(x: Int(x), y: Int(y)) == true else { return false }
        for crater in craters {
            let dx = x - crater.x
            let dy = y - crater.y
            if dx * dx + dy * dy <= crater.radius * crater.radius { return false }
        }
        return true
    }

    /// The first solid cell at column `x` scanning down from `y`, craters
    /// included; `nil` when the column is blown through to the void.
    private func groundLevel(atX x: Float, below y: Float) -> Float? {
        var scan = max(0, y)
        while scan < worldSize.height {
            if isSolidGround(x: x, y: scan) { return scan }
            scan += 1
        }
        return nil
    }

    /// The horizontal facing of the acting player's shot: toward the living
    /// enemies' center (+1 right / −1 left), defaulting right.
    public var fireDirection: Float {
        guard let shooter = currentTurnPlayer else { return 1 }
        let enemies = players.filter { $0.isAlive && $0.team != shooter.team }
        guard !enemies.isEmpty else { return 1 }
        let center = enemies.map(\.x).reduce(0, +) / Float(enemies.count)
        return center >= shooter.x ? 1 : -1
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

    /// The tunnel payload tag for a relayed shot:
    /// `[0x01, angle, power, direction, wind, weapon]` (angle in degrees,
    /// power `0…100`, direction `0` = left / `1` = right, wind biased by
    /// 127 — the shooter's roll — and the weapon slot, so every client
    /// simulates the same flight and blast).
    static let fireTag: UInt8 = 0x01
    /// The tunnel payload tag for a live aim update:
    /// `[0x02, angle, power, direction]` — the decomp's `0x8402`/`0x8406`
    /// angle+power broadcast, sent as the acting player adjusts their aim
    /// so the other clients can render the barrel moving.
    static let aimTag: UInt8 = 0x02
    /// The tunnel payload tag for a walk step:
    /// `[0x03, xLo, xHi, yLo, yHi]` — the mover's absolute post-step
    /// position (u16 LE each), the `0xc304` movement action's analogue.
    /// Absolute so remote positions can't drift from missed steps.
    static let moveTag: UInt8 = 0x03

    /// Applies one server push — split out so tests can drive it directly.
    public func apply(_ push: ServerPush) {
        switch push {
        case .playerDied(let dead):
            if let index = players.firstIndex(where: { $0.slot == dead.slot }) {
                markDead(at: index)
            }
        case .userQuit(let quit):
            players.removeAll { UInt16($0.slot) == quit.slot }
        case .gameEnded(let end):
            endMatch(winner: end.winner)
        case .tunnelReceived(let forward):
            applyTunnel(forward)
        case .chatReceived(let broadcast):
            appendChat(ChatLine(
                sender: String(describing: broadcast.username),
                message: broadcast.message,
                type: .normal
            ))
        case .clientPrint(let notice):
            appendChat(ChatLine(message: notice.message, type: .notice))
        case .roomUpdated, .roomPlayerLeft, .userJoinedChannel, .gameStarted,
             .hostMigrated, .buddyListUpdated, .raw:
            break
        }
    }

    private func applyTunnel(_ forward: TunnelForward) {
        guard let tag = forward.payload.first,
              let shooter = players.first(where: { $0.slot == forward.sourceSlot })
        else { return }
        switch tag {
        case Self.fireTag:
            guard forward.payload.count >= 6 else { return }
            let angle = Float(forward.payload[1])
            let power = Float(forward.payload[2]) / 100
            let direction: Float = forward.payload[3] == 0 ? -1 : 1
            shotWind = Float(Int(forward.payload[4]) - 127)
            shotWeapon = Weapon(rawValue: forward.payload[5]) ?? .shot1
            launch(from: shooter, angle: angle, power: power, direction: direction)
        case Self.aimTag:
            guard forward.payload.count >= 4 else { return }
            remoteAim = (
                angle: Float(forward.payload[1]),
                power: Float(forward.payload[2]) / 100,
                direction: forward.payload[3] == 0 ? -1 : 1
            )
        case Self.moveTag:
            guard forward.payload.count >= 5,
                  let index = players.firstIndex(where: { $0.slot == forward.sourceSlot })
            else { return }
            players[index].x = Float(UInt16(forward.payload[1]) | UInt16(forward.payload[2]) << 8)
            players[index].y = Float(UInt16(forward.payload[3]) | UInt16(forward.payload[4]) << 8)
            setPose(.move, at: index)
            emitWalkCue(for: players[index])
            // Follow the walker (it's the acting player).
            camera = (players[index].x, players[index].y)
            clampCamera()
        default:
            break
        }
    }

    // MARK: - Input

    public func handle(_ event: ScreenInputEvent) {
        switch event {
        case .pointerMoved(let x, let y):
            pointer = (x, y)

        case .key(.up):
            guard isMyTurn, phase == .aiming || phase == .charging else { return }
            aimAngle = min(Self.aimRange.upperBound, aimAngle + Self.aimStep)
            relayAim()
        case .key(.down):
            guard isMyTurn, phase == .aiming || phase == .charging else { return }
            aimAngle = max(Self.aimRange.lowerBound, aimAngle - Self.aimStep)
            relayAim()

        // ◀/▶ walk the mobile (aiming only — the original locks movement
        // once the charge starts).
        case .key(.left):
            guard isMyTurn, phase == .aiming else { return }
            walk(-1)
        case .key(.right):
            guard isMyTurn, phase == .aiming else { return }
            walk(1)

        // Tab cycles the weapon slot before the charge starts.
        case .key(.tab):
            guard isMyTurn, phase == .aiming else { return }
            selectedWeapon = selectedWeapon.next

        // Typing opens the chat composer (or appends to it); while it's
        // open, Enter sends the line instead of charging/firing.
        case .text(let string):
            openOrAppendChat(string)
        case .key(.backspace):
            guard var draft = chatDraft else { return }
            if draft.isEmpty {
                chatDraft = nil
            } else {
                draft.removeLast()
                chatDraft = draft
            }

        case .activate:
            if chatDraft != nil {
                submitChat()
                return
            }
            switch phase {
            case .aiming where isMyTurn:
                phase = .charging
                power = 0
            case .charging:
                fire()
            case .waiting where delegate.client == nil && currentTurnPlayer == nil:
                // Offline with no battle data: the placeholder exit.
                delegate.session.battle = nil
                delegate.requestTransition(to: .gameRoomList)
            default:
                break
            }

        case .scroll(_, _, let steps):
            camera.y += Float(steps) * 40
            clampCamera()

        case .pointerDown(let x, let y):
            // The item quick-bar: click a slot to highlight it (visual only).
            if let index = battleItems.indices.first(where: {
                Self.itemSlotRect(at: $0).contains(x: x, y: y)
            }) {
                selectItem(at: index)
            }

        case .pointerUp, .key:
            break
        }
    }

    // MARK: - Battle chat

    private func openOrAppendChat(_ string: String) {
        var draft = chatDraft ?? ""
        for character in string where draft.count < Self.maxChatDraftLength {
            guard character != "\n", character != "\r" else { continue }
            draft.append(character)
        }
        chatDraft = draft
    }

    /// Sends the draft as a chat line (`0x2010`, like the lobby panels)
    /// and closes the composer. Online the line comes back as the server's
    /// broadcast; offline it echoes straight into the history.
    private func submitChat() {
        let draft = (chatDraft ?? "").trimmingCharacters(in: .whitespaces)
        chatDraft = nil
        guard !draft.isEmpty else { return }
        guard let client = delegate.client else {
            appendChat(ChatLine(sender: delegate.network.username, message: draft))
            return
        }
        Task {
            do {
                try await client.send(ChannelChatCommand(message: draft))
            } catch {
                print("[GunBound] couldn't send chat: \(error)")
            }
        }
    }

    private func appendChat(_ line: ChatLine) {
        chatLines.append(line)
        if chatLines.count > Self.maxChatLines {
            chatLines.removeFirst(chatLines.count - Self.maxChatLines)
        }
    }

    /// Commits the shot: relays it through the tunnel and starts the local
    /// simulation (every client resolves the same deterministic flight).
    private func fire() {
        guard let shooter = currentTurnPlayer else { return }
        let angle = aimAngle
        let strength = power
        let direction = fireDirection
        if let client = delegate.client {
            let payload: [UInt8] = [
                Self.fireTag,
                UInt8(min(255, max(0, angle.rounded()))),
                UInt8(min(100, max(0, (strength * 100).rounded()))),
                direction > 0 ? 1 : 0,
                UInt8(min(255, max(0, (wind + 127).rounded()))),
                selectedWeapon.rawValue,
            ]
            let targets = players.filter { $0.slot != shooter.slot }.map(\.slot)
            Task {
                for slot in targets {
                    try? await client.sendTunnel(to: slot, payload: payload)
                }
            }
        }
        shotWind = wind
        shotWeapon = selectedWeapon
        launch(from: shooter, angle: angle, power: strength, direction: direction)
    }

    /// Broadcasts the local player's current aim to the other clients (the
    /// `0x8402`/`0x8406` live aim relay) so they can animate the barrel.
    private func relayAim() {
        guard let client = delegate.client, let shooter = currentTurnPlayer else { return }
        let payload: [UInt8] = [
            Self.aimTag,
            UInt8(min(255, max(0, aimAngle.rounded()))),
            UInt8(min(100, max(0, (power * 100).rounded()))),
            fireDirection > 0 ? 1 : 0,
        ]
        let targets = players.filter { $0.slot != shooter.slot }.map(\.slot)
        Task {
            for slot in targets {
                try? await client.sendTunnel(to: slot, payload: payload)
            }
        }
    }

    /// One walk step (±1 direction): moves the acting mobile along the
    /// terrain surface, spending the turn's movement budget. A rise steeper
    /// than the climb limit is a wall; a drop lands on the ground below
    /// (craters included); a bottomless column blocks the step.
    private func walk(_ direction: Float) {
        guard moveBudget >= Self.walkStep,
              let shooter = currentTurnPlayer,
              let index = players.firstIndex(where: { $0.slot == shooter.slot })
        else { return }
        let newX = min(max(0, shooter.x + direction * Self.walkStep), worldSize.width)
        guard newX != shooter.x, let newY = walkDestinationY(atX: newX, from: shooter.y) else { return }
        players[index].x = newX
        players[index].y = newY
        moveBudget -= Self.walkStep
        setPose(.move, at: index)
        emitWalkCue(for: players[index])
        camera = (newX, newY)
        clampCamera()
        relayMove(players[index])
    }

    /// Where a step to column `x` puts the mobile's feet, starting from
    /// height `y`; `nil` when the step is blocked (a wall above the climb
    /// limit, or a column blown through to the void).
    private func walkDestinationY(atX x: Float, from y: Float) -> Float? {
        guard terrain != nil else { return y }  // no mask yet: walk flat
        let top = y - Self.maxClimb
        guard !isSolidGround(x: x, y: top) else { return nil }  // wall
        var scan = top + 1
        while scan <= y + Self.maxClimb {
            if isSolidGround(x: x, y: scan) { return scan }
            scan += 1
        }
        // No footing within the climb window — fall to the ground below.
        return groundLevel(atX: x, below: y + Self.maxClimb)
    }

    /// Emits the per-mobile walk cue (the `0xc304` action's
    /// direction-specific movement sound), throttled to key-repeat pace.
    private func emitWalkCue(for player: BattlePlayer) {
        guard clock - lastWalkCue >= Self.walkCueInterval else { return }
        lastWalkCue = clock
        soundQueue.append(.walk(player.mobile))
    }

    /// Broadcasts the walker's post-step position (the `0xc304` movement
    /// action's analogue) so the other clients place the mobile exactly.
    private func relayMove(_ player: BattlePlayer) {
        guard let client = delegate.client else { return }
        let x = UInt16(min(max(0, player.x.rounded()), 65535))
        let y = UInt16(min(max(0, player.y.rounded()), 65535))
        let payload: [UInt8] = [
            Self.moveTag,
            UInt8(x & 0xff), UInt8(x >> 8),
            UInt8(y & 0xff), UInt8(y >> 8),
        ]
        let targets = players.filter { $0.slot != player.slot }.map(\.slot)
        Task {
            for slot in targets {
                try? await client.sendTunnel(to: slot, payload: payload)
            }
        }
    }

    private func launch(from shooter: BattlePlayer, angle: Float, power: Float, direction: Float) {
        let radians = angle * .pi / 180
        let speed = max(0.15, power) * Self.maxShotSpeed
        projectile = Projectile(
            x: shooter.x,
            y: shooter.y - 24,  // muzzle above the mobile
            vx: cos(radians) * speed * direction,
            vy: -sin(radians) * speed
        )
        shotAttacker = shooter.slot
        remoteAim = nil
        if let index = players.firstIndex(where: { $0.slot == shooter.slot }) {
            setPose(.fire(shotWeapon), at: index)
        }
        soundQueue.append(.fire(shooter.mobile, shotWeapon))
        activeShot = (shooter.mobile, shotWeapon)
        phase = .projectileInFlight
    }

    // MARK: - Simulation

    public func update(deltaTime: Double) {
        clock += deltaTime
        expirePoses()
        // The match result lingers, then hands control back to the room.
        if var countdown = matchEndCountdown {
            countdown -= deltaTime
            if countdown <= 0 {
                matchEndCountdown = nil
                finishMatch()
            } else {
                matchEndCountdown = countdown
            }
            return  // play is frozen under the result banner
        }
        processRespawns()
        switch phase {
        case .charging:
            tickTurnTimer(deltaTime)
            guard phase == .charging else { break }  // the clock ran out
            power = min(1, power + Float(deltaTime / Self.chargeDuration))
            if power >= 1 {
                fire()  // a full gauge fires, like the original
            }
        case .projectileInFlight:
            stepProjectile(deltaTime)
        case .impact:
            explosion?.age += deltaTime
            if let explosion, explosion.age >= Self.explosionDuration {
                resolveImpact(at: explosion)
            }
        case .aiming, .waiting:
            tickTurnTimer(deltaTime)
            edgeScroll(deltaTime)
        }
    }

    /// Counts the acting player's window down; hitting zero forfeits the
    /// turn (the `0xc305` timeout: reset the turn phase and post the
    /// "turn's up" message). The clock pauses while a shot resolves.
    private func tickTurnTimer(_ deltaTime: Double) {
        guard currentTurnPlayer != nil else { return }
        let before = turnRemaining
        turnRemaining -= deltaTime
        // The ten-second warning cue, once per turn as the clock crosses it.
        if before > 10, turnRemaining <= 10, turnRemaining > 0 {
            soundQueue.append(.turnWarning)
        }
        guard turnRemaining <= 0 else { return }
        appendChat(ChatLine(message: "Time over!", type: .notice))
        advanceTurn()  // also resets the timer
    }

    private func stepProjectile(_ deltaTime: Double) {
        guard var shot = projectile else { return }
        // Substeps keep fast shots from tunneling through thin terrain.
        let substeps = 4
        let dt = Float(deltaTime) / Float(substeps)
        for _ in 0..<substeps {
            shot.vx += shotWind * dt
            shot.vy += Self.gravity * dt
            shot.x += shot.vx * dt
            shot.y += shot.vy * dt
            let solid = isSolidGround(x: shot.x, y: shot.y)
            let offMap = shot.y > worldSize.height + 200 || shot.x < -400 || shot.x > worldSize.width + 400
            if solid || offMap {
                projectile = nil
                if solid {
                    explosion = Explosion(x: shot.x, y: shot.y, blastRadius: Self.profile(for: shotWeapon).blastRadius)
                    phase = .impact
                } else {
                    // Splashed off the map — no crater, straight to next turn.
                    advanceTurn()
                }
                return
            }
        }
        projectile = shot
        // The camera tracks the shot.
        camera = (shot.x, shot.y)
        clampCamera()
    }

    private func resolveImpact(at explosion: Explosion) {
        let profile = Self.profile(for: shotWeapon)
        // The blast cue is the firing mobile's (`<N><weapon>blast.xes`).
        let attackerMobile = players.first { $0.slot == shotAttacker }?.mobile ?? .armor
        soundQueue.append(.blast(attackerMobile, shotWeapon))
        // Carve the blast hole out of the terrain.
        craters.append(Crater(x: explosion.x, y: explosion.y, radius: profile.craterRadius))
        // Splash damage by blast ring: the innermost tier whose radius
        // covers the target sets the hit's power (local resolution — see
        // the type-level divergence note).
        for index in players.indices where players[index].isAlive {
            let dx = players[index].x - explosion.x
            let dy = players[index].y - explosion.y
            let distance = (dx * dx + dy * dy).squareRoot()
            guard let tier = profile.damageTiers.first(where: { distance <= $0.radius }) else { continue }
            applyDamage(tier.damage, toSlot: players[index].slot, cause: .shot)
        }
        // Survivors above the new hole drop to the remaining ground; a
        // column blown through to the void is a fall-out death.
        for index in players.indices where players[index].isAlive {
            let player = players[index]
            guard !isSolidGround(x: player.x, y: player.y + 1) else { continue }
            if let ground = groundLevel(atX: player.x, below: player.y) {
                players[index].y = ground
            } else {
                applyDamage(player.hp, toSlot: player.slot, cause: .fallOut)
            }
        }
        self.explosion = nil
        checkMatchOver()
        if !isMatchOver {
            advanceTurn()
        }
    }

    /// Offline the client is its own referee: once every living player is
    /// on one team (or nobody's left), show the result and wind down.
    /// Online the server decides (`checkPlayEnd` → the game-end push).
    /// Score mode never ends by wipe — the dead respawn; its life pools
    /// decide instead (see `markDead`).
    private func checkMatchOver() {
        guard delegate.client == nil, !isMatchOver, players.count > 1,
              gameMode != .score else { return }
        let livingTeams = Set(players.filter(\.isAlive).map(\.team))
        guard livingTeams.count <= 1 else { return }
        endMatch(winner: livingTeams.first)
    }

    /// Revives any benched score-mode players whose respawn is due: back
    /// at their spawn column with a full pool, re-entering the turn
    /// rotation. Every client runs the same deterministic timer off the
    /// same death; the local player's own respawn additionally posts the
    /// `0x4104` resurrect so the server's slot bookkeeping matches.
    private func processRespawns() {
        guard !pendingRespawns.isEmpty else { return }
        var remaining: [(slot: UInt8, time: Double)] = []
        for entry in pendingRespawns {
            if entry.time <= clock {
                respawn(slot: entry.slot)
            } else {
                remaining.append(entry)
            }
        }
        pendingRespawns = remaining
    }

    private func respawn(slot: UInt8) {
        guard let index = players.firstIndex(where: { $0.slot == slot }),
              !players[index].isAlive else { return }
        players[index].hp = Self.maxHP
        players[index].isAlive = true
        players[index].x = players[index].spawnX
        if let surface = terrain?.surfaceLevel(atX: Int(players[index].spawnX), near: Int(players[index].y)) {
            players[index].y = Float(surface)
        }
        // Straight to the idle pose (setPose won't leave `.dead`).
        players[index].pose = .normal
        players[index].poseStarted = clock
        appendChat(ChatLine(message: "\(players[index].name) respawned", type: .notice))
        if players[index].name == delegate.network.username, let client = delegate.client {
            Task {
                do {
                    try await client.resurrect()
                } catch {
                    print("[GunBound] couldn't send resurrect: \(error)")
                }
            }
        }
    }

    /// Freezes play and starts the result-banner countdown.
    private func endMatch(winner: Team?) {
        guard !isMatchOver else { return }
        self.winner = winner
        isMatchOver = true
        matchEndCountdown = Self.matchEndDelay
        phase = .waiting
        let message = winner.map { "Team \($0) wins!" } ?? "Draw!"
        appendChat(ChatLine(message: message, type: .notice))
    }

    /// Leaves the battle once the result banner has shown: online, tell
    /// the server we're returning (`0x3040`) and re-enter the Ready Room;
    /// offline, back to the lobby.
    private func finishMatch() {
        delegate.session.battle = nil
        if let client = delegate.client {
            Task {
                do {
                    try await client.returnToRoom()
                } catch {
                    print("[GunBound] couldn't return to room: \(error)")
                }
            }
            delegate.requestTransition(to: .readyRoom)
        } else {
            delegate.requestTransition(to: .gameRoomList)
        }
    }

    /// Deducts HP, logs the hit in the ledger (credited to the in-flight
    /// shot's attacker), and kills the mobile at 0. Internal so tests can
    /// drive the damage path directly.
    func applyDamage(_ amount: Int, toSlot slot: UInt8, cause: DamageEvent.Cause) {
        guard let index = players.firstIndex(where: { $0.slot == slot }) else { return }
        players[index].hp = max(0, players[index].hp - amount)
        damageLedger.append(DamageEvent(
            value: amount,
            targetSlot: slot,
            attackerSlot: shotAttacker ?? slot,
            cause: cause
        ))
        if players[index].hp == 0 {
            markDead(at: index)
            reportOwnDeath(players[index])
        } else {
            setPose(.shock, at: index)
        }
    }

    /// One death, whichever path found it (local damage or the server's
    /// death push — guarded so an echoed push can't double-count). Score
    /// mode charges the team's life pool and benches the player for a
    /// respawn; running the pool dry decides the match (locally when
    /// offline; the server's game-end push confirms it online).
    private func markDead(at index: Int) {
        guard players[index].isAlive else { return }
        // Tag mode: the first knockout tags the secondary mobile in on the
        // spot with a fresh pool — not a death, so nothing is reported and
        // no wipe can trigger. The next knockout is final.
        if gameMode == .tag, !players[index].hasTagged {
            players[index].hasTagged = true
            if players[index].secondaryMobile != .random {
                players[index].mobile = players[index].secondaryMobile
            }
            players[index].hp = Self.maxHP
            players[index].pose = .normal
            players[index].poseStarted = clock
            appendChat(ChatLine(
                message: "\(players[index].name) tagged in \(players[index].mobile)",
                type: .notice
            ))
            return
        }
        players[index].hp = 0
        players[index].isAlive = false
        setPose(.dead, at: index)
        guard gameMode == .score, teamLives != nil else { return }
        switch players[index].team {
        case .a: teamLives?.a -= 1
        case .b: teamLives?.b -= 1
        }
        if let lives = teamLives, lives.a <= 0 || lives.b <= 0 {
            // Pool dry: offline this decides the match; online the
            // server's game-end push carries the same verdict.
            if delegate.client == nil {
                endMatch(winner: lives.a <= 0 ? .b : .a)
            }
        } else {
            pendingRespawns.append((slot: players[index].slot, time: clock + Self.respawnDelay))
        }
    }

    /// The original's death flow is self-reported: each client sends
    /// `0x4100` when its *own* mobile dies (every client resolves the same
    /// deterministic damage, so each one sees its own death locally). The
    /// server broadcasts the `0x4102` death and ends the match on a wipe.
    private func reportOwnDeath(_ player: BattlePlayer) {
        // A Tag-mode swap isn't a death (the player is back alive) —
        // reporting it would let the server end the game on a false wipe.
        guard !player.isAlive,
              let client = delegate.client,
              player.name == delegate.network.username else { return }
        Task {
            do {
                try await client.reportDeath()
            } catch {
                print("[GunBound] couldn't report death: \(error)")
            }
        }
    }

    /// Marks a pose change on the battle clock (dead is final).
    private func setPose(_ pose: MobilePose, at index: Int) {
        guard players[index].pose != .dead else { return }
        players[index].pose = pose
        players[index].poseStarted = clock
    }

    /// Transient poses revert to `.normal` once their run has played.
    private func expirePoses() {
        for index in players.indices {
            let player = players[index]
            let age = clock - player.poseStarted
            let expired: Bool
            switch player.pose {
            case .move: expired = age > Self.movePoseLinger
            case .fire: expired = age > Self.firePoseDuration
            case .shock: expired = age > Self.shockPoseDuration
            case .normal, .dead: expired = false
            }
            if expired {
                setPose(.normal, at: index)
            }
        }
    }

    private func edgeScroll(_ deltaTime: Double) {
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
