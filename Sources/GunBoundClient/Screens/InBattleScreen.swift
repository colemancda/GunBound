import Foundation
import GunBound
import GunBoundProtocol
import GunBoundFile

/// View for the In-Battle screen (state 11) — the playable slice: the stage
/// terrain through the camera, mobiles grounded on the `.lnd` surface, and
/// the fire loop's visuals — an aim-arc of dots, the power gauge, the
/// projectile, and an **additively-blended** explosion flash (the glow blend
/// the original's scene composer flips to for effect layers). HUD shows the
/// turn, angle, and power.
///
/// Later slices: the layered scene composer (scenery/background, mobile
/// animation frames), terrain destruction, wind, and battle chat.
@MainActor
public final class InBattleScreen: GameScreen {
    private let viewModel: InBattleViewModel
    private var terrainTexture: ClientTexture?
    /// Each mobile's `.epa` animation table — the named frame runs
    /// (`normal`, `move`, `fire1`, `shock`, `dead`, wounded variants) that
    /// map poses onto the 455-frame `tankN.img` sheets.
    private var mobileAnimations: [Mobile: EpaFile] = [:]
    /// Lazily-built textures keyed `"<image>#<frame>"` (the renderers
    /// don't cache; the decoded sheet behind them does).
    private var frameCache: [String: ClientTexture] = [:]
    private var assets: AssetLibrary?
    /// A small round dot (`load_back.img` frame 2) reused for the aim arc,
    /// the projectile, and (scaled, additive) the explosion flash.
    private var dotTexture: ClientTexture?
    private var font: LoadedFont?
    private var audio: ClientAudioPlayer?

    public init(viewModel: InBattleViewModel) {
        self.viewModel = viewModel
    }

    public func onEnter(context: ClientContext) throws {
        viewModel.onEnter()
        let renderer = context.renderer
        let assets = context.assets

        terrainTexture = renderer.texture(named: viewModel.map.stageImageName, assets: assets)
        let (worldWidth, worldHeight) = renderer.size(of: terrainTexture)
        viewModel.setWorldSize(width: worldWidth, height: worldHeight)

        // The stage's collision mask grounds each mobile at its spawn column.
        if let mask = try? assets.terrainMask(named: viewModel.map.stageLandName) {
            viewModel.setTerrain(mask)
        }

        self.assets = assets
        for mobile in Set(viewModel.players.map(\.mobile)) {
            mobileAnimations[mobile] = try? assets.animationTable(named: mobile.tankAnimationName)
        }
        dotTexture = renderer.texture(named: "load_back.img", frame: 2, assets: assets)
        font = LoadedFont(.latinFont, renderer: renderer, assets: assets)

        // Battle music: `stage%d.mp3` by stage id, or one of the six tracks
        // at random for the random stage — the decompiled `PlayMusicTrack`
        // behaviour (`stage id or rand()%6 + 1`).
        let stageID = Int(viewModel.map.rawValue)
        let track = stageID > 0 ? stageID : Int.random(in: 1...6)
        let audio = context.makeAudioPlayer()
        audio.play(named: "stage\(track).mp3", assets: assets, loop: true)
        self.audio = audio
    }

    public func onExit() {
        viewModel.onExit()
        terrainTexture = nil
        mobileAnimations = [:]
        frameCache = [:]
        assets = nil
        dotTexture = nil
        font = nil
        audio?.stop()
        audio = nil
    }

    public func handleInput(_ event: ScreenInputEvent) {
        viewModel.handle(event)
    }

    public func update(deltaTime: Double) {
        audio?.update(deltaTime: deltaTime)
        viewModel.update(deltaTime: deltaTime)
        playPendingSounds()
    }

    /// Plays the model's queued cues against `sound.xfs`. Effect coverage
    /// is per-mobile and spotty, so each cue walks a candidate chain and
    /// plays the first name that loads.
    private func playPendingSounds() {
        guard let audio, let assets else { return }
        for cue in viewModel.drainSounds() {
            let candidates: [String]
            switch cue {
            case .fire(let mobile, let weapon):
                let n = mobile.sheetNumber
                switch weapon {
                case .shot1: candidates = ["\(n)1fire.xes", "\(n)2fire.xes"]
                case .shot2: candidates = ["\(n)2fire.xes", "\(n)1fire.xes"]
                case .special: candidates = ["\(n)s1fire.xes", "\(n)2fire.xes", "\(n)1fire.xes"]
                }
            case .blast(let mobile, let weapon):
                let n = mobile.sheetNumber
                switch weapon {
                case .shot1: candidates = ["\(n)1blast.xes", "\(n)2blast.xes", "bombblast.xes"]
                case .shot2: candidates = ["\(n)2blast.xes", "\(n)1blast.xes", "bombblast.xes"]
                case .special: candidates = ["\(n)s1blast.xes", "\(n)2blast.xes", "\(n)1blast.xes", "bombblast.xes"]
                }
            case .walk(let mobile):
                let n = mobile.sheetNumber
                candidates = ["\(n)move.xes", "\(n)nmove.xes"]
            case .turnStart:
                candidates = ["turn.xes"]
            case .turnWarning:
                candidates = ["turnwa.xes"]
            }
            for name in candidates where audio.playEffect(named: name, assets: assets) {
                break
            }
        }
    }

    public func render(_ renderer: ClientRenderer) throws {
        renderer.clear()

        // The stage world, offset by the camera (world → screen is
        // `world − cam + halfView`; drawing the full map at the transformed
        // origin is equivalent).
        if let terrainTexture {
            let (width, height) = renderer.size(of: terrainTexture)
            let origin = viewModel.screenPosition(x: 0, y: 0)
            renderer.draw(terrainTexture, in: Rect(x: origin.x, y: origin.y, width: width, height: height), tint: nil)
        }

        // Blast craters: the collision holes drawn as dark discs over the
        // terrain art (the sky behind the stage draws black, so a black disc
        // reads as a hole — an honest interim until the renderer can carve
        // the stage texture itself).
        if let dotTexture {
            for crater in viewModel.craters {
                let position = viewModel.screenPosition(x: crater.x, y: crater.y)
                renderer.draw(
                    dotTexture,
                    in: Rect(x: position.x - crater.radius, y: position.y - crater.radius,
                             width: crater.radius * 2, height: crater.radius * 2),
                    tint: (1, 1, 1)
                )
            }
        }

        guard let font else { return }

        // Mobiles at their spawns: idle sprite centered on the spawn point,
        // name tag above in team color, dead players grayed.
        for player in viewModel.players {
            let position = viewModel.screenPosition(x: player.x, y: player.y)
            guard position.x > -60, position.x < 860, position.y > -60, position.y < 660 else { continue }
            let teamColor: (r: UInt8, g: UInt8, b: UInt8) = player.team == .a ? (255, 200, 120) : (140, 200, 255)

            if let sprite = mobileSprite(for: player, renderer: renderer) {
                let (width, height) = renderer.size(of: sprite)
                renderer.draw(
                    sprite,
                    in: Rect(x: position.x - width / 2, y: position.y - height, width: width, height: height),
                    tint: nil
                )
            }
            let tagWidth = font.width(of: player.name)
            font.draw(
                player.name,
                x: position.x - tagWidth / 2,
                y: position.y - 58,
                tint: player.isAlive ? teamColor : (110, 110, 110),
                using: renderer
            )
            // HP bar between the name tag and the mobile: a dark backing
            // with a fill that drains and shifts green → red.
            if let dotTexture, player.isAlive {
                let barWidth: Float = 40
                let ratio = Float(player.hp) / Float(InBattleViewModel.maxHP)
                renderer.draw(
                    dotTexture,
                    in: Rect(x: position.x - barWidth / 2, y: position.y - 46, width: barWidth, height: 4),
                    tint: (30, 30, 30)
                )
                renderer.draw(
                    dotTexture,
                    in: Rect(x: position.x - barWidth / 2, y: position.y - 46, width: barWidth * ratio, height: 4),
                    tint: (UInt8(220 - ratio * 140), UInt8(80 + ratio * 140), 80)
                )
            }
        }

        // Aim arc: a dotted preview of the shot's opening trajectory while
        // aiming/charging (the physics constants match the simulation).
        if let dotTexture,
           viewModel.isMyTurn,
           viewModel.phase == .aiming || viewModel.phase == .charging,
           let shooter = viewModel.currentTurnPlayer {
            let radians = viewModel.aimAngle * .pi / 180
            let speed = max(0.35, viewModel.power) * InBattleViewModel.maxShotSpeed
            let direction = viewModel.fireDirection
            var x = shooter.x
            var y = shooter.y - 24
            var vx = cos(radians) * speed * direction
            var vy = -sin(radians) * speed
            _ = vx
            for step in 0..<10 {
                let t: Float = 0.06
                vy += InBattleViewModel.gravity * t
                x += cos(radians) * speed * direction * t
                y += vy * t
                let position = viewModel.screenPosition(x: x, y: y)
                let alphaFade = UInt8(200 - step * 15)
                renderer.draw(dotTexture, in: Rect(x: position.x - 3, y: position.y - 3, width: 6, height: 6), tint: (alphaFade, alphaFade, 120))
            }
        }

        // The acting remote player's relayed aim (the live angle+power
        // broadcast): a short arc from their mobile in enemy red.
        if let dotTexture,
           !viewModel.isMyTurn,
           let aim = viewModel.remoteAim,
           let shooter = viewModel.currentTurnPlayer {
            let radians = aim.angle * .pi / 180
            let speed = max(0.35, aim.power) * InBattleViewModel.maxShotSpeed
            var y = shooter.y - 24
            var x = shooter.x
            var vy = -sin(radians) * speed
            for step in 0..<6 {
                let t: Float = 0.06
                vy += InBattleViewModel.gravity * t
                x += cos(radians) * speed * aim.direction * t
                y += vy * t
                let position = viewModel.screenPosition(x: x, y: y)
                let alphaFade = UInt8(200 - step * 20)
                renderer.draw(dotTexture, in: Rect(x: position.x - 3, y: position.y - 3, width: 6, height: 6), tint: (alphaFade, 90, 90))
            }
        }

        // The projectile.
        if let dotTexture, let shot = viewModel.projectile {
            let position = viewModel.screenPosition(x: shot.x, y: shot.y)
            renderer.draw(dotTexture, in: Rect(x: position.x - 5, y: position.y - 5, width: 10, height: 10), tint: (255, 240, 180))
        }

        // The explosion flash — the additive glow blend, expanding and
        // cooling over its lifetime.
        if let dotTexture, let explosion = viewModel.explosion {
            let progress = Float(min(1, explosion.age / InBattleViewModel.explosionDuration))
            let radius = 14 + progress * explosion.blastRadius
            let position = viewModel.screenPosition(x: explosion.x, y: explosion.y)
            let heat = UInt8(255 - progress * 140)
            renderer.draw(
                dotTexture,
                in: Rect(x: position.x - radius, y: position.y - radius, width: radius * 2, height: radius * 2),
                tint: (255, heat, UInt8(60 + progress * 40)),
                blend: .additive
            )
        }

        // HUD: map, whose turn, and the aim/power readout.
        font.draw("\(viewModel.map)", x: 12, y: 8, using: renderer)
        if let turn = viewModel.currentTurnPlayer {
            let marker = viewModel.isMyTurn ? "YOUR TURN" : "Turn: \(turn.name)"
            font.draw(marker, x: 12, y: 24, tint: (255, 255, 160), using: renderer)
            // The 60-second turn clock, urgent-red in the last ten.
            let seconds = max(0, Int(viewModel.turnRemaining.rounded(.up)))
            let urgent = seconds <= 10
            font.draw("TIME \(seconds)", x: 376, y: 24, tint: urgent ? (255, 90, 70) : (220, 220, 220), using: renderer)
        }
        // Wind readout — direction arrow + strength (the shooter's roll is
        // what the shot flies under).
        let windStrength = Int((abs(viewModel.wind) / 12).rounded())
        let windArrow = viewModel.wind >= 0 ? ">" : "<"
        let windBar = String(repeating: windArrow, count: max(1, min(5, windStrength)))
        font.draw("WIND \(windBar) \(windStrength)", x: 360, y: 8, tint: (160, 220, 255), using: renderer)

        // Hit feed: the ledger's most recent entries, top-right (the
        // damage-log UI fed by the original's 0x8404 records).
        let feed = viewModel.damageLedger.suffix(3)
        for (row, event) in feed.enumerated() {
            let target = viewModel.players.first { $0.slot == event.targetSlot }?.name ?? "slot \(event.targetSlot)"
            let line = event.cause == .fallOut ? "\(target) fell out" : "\(target) -\(event.value)"
            let lineWidth = font.width(of: line)
            font.draw(line, x: 788 - lineWidth, y: 28 + Float(row) * 14, tint: (255, 160, 140), using: renderer)
        }

        if viewModel.isMyTurn, viewModel.phase == .aiming || viewModel.phase == .charging {
            font.draw("Angle \(Int(viewModel.aimAngle))", x: 12, y: 40, using: renderer)
            // The selected weapon slot (Tab cycles it while aiming).
            let weaponLabel: String
            switch viewModel.selectedWeapon {
            case .shot1: weaponLabel = "SHOT 1"
            case .shot2: weaponLabel = "SHOT 2"
            case .special: weaponLabel = "SS"
            }
            font.draw(weaponLabel, x: 110, y: 40, tint: (255, 220, 120), using: renderer)
            if viewModel.phase == .charging {
                font.draw("Power \(Int(viewModel.power * 100))", x: 12, y: 56, tint: (255, 180, 120), using: renderer)
            }
        }

        // The power gauge along the bottom while charging.
        if let dotTexture, viewModel.phase == .charging {
            let width = 300 * viewModel.power
            renderer.draw(dotTexture, in: Rect(x: 250, y: 574, width: width, height: 12), tint: (255, UInt8(220 - viewModel.power * 160), 80))
        }

        // The battle chat overlay: the rotating history drawn over the
        // scene (the original's software-blit HUD pass), color-coded by
        // the per-line message type.
        for (row, line) in viewModel.chatLines.enumerated() {
            let y = 76 + Float(row) * 14
            let colors = LobbyChatWidget.colors(for: line.type)
            var x: Float = 12
            if !line.sender.isEmpty {
                font.draw(line.sender, x: x, y: y, tint: colors.name, using: renderer)
                x += font.width(of: line.sender) + 8
            }
            font.draw(line.message, x: x, y: y, tint: colors.message, using: renderer)
        }

        // The chat composer bar while typing (Enter sends).
        if let draft = viewModel.chatDraft {
            if let dotTexture {
                renderer.draw(dotTexture, in: Rect(x: 8, y: 550, width: 500, height: 18), tint: (15, 15, 15))
            }
            font.draw("> \(draft)_", x: 14, y: 553, tint: (255, 255, 255), using: renderer)
        }

        // The movement gauge (bottom-left) while free to walk — drains as
        // the turn's walking budget is spent.
        if let dotTexture, viewModel.isMyTurn, viewModel.phase == .aiming {
            let ratio = viewModel.moveBudget / InBattleViewModel.moveBudgetPerTurn
            renderer.draw(dotTexture, in: Rect(x: 12, y: 578, width: 120, height: 8), tint: (30, 30, 30))
            renderer.draw(dotTexture, in: Rect(x: 12, y: 578, width: 120 * ratio, height: 8), tint: (120, 200, 255))
        }
    }

    // MARK: - Mobile animation

    /// The sheet frame for a player's current pose: the pose (plus the
    /// half-HP wounded variants) picks the `.epa` run, the battle clock
    /// picks the frame within it. Falls back to frame 0 (the idle pose)
    /// when the table or run is missing.
    private func mobileSprite(for player: InBattleViewModel.BattlePlayer, renderer: ClientRenderer) -> ClientTexture? {
        guard let assets else { return nil }
        let imageName = player.mobile.tankImageName
        var frame = 0
        if let table = mobileAnimations[player.mobile] {
            let wounded = player.hp <= InBattleViewModel.maxHP / 2
            let run: String
            let looping: Bool
            switch player.pose {
            case .normal: run = wounded ? "wnormal" : "normal"; looping = true
            case .move: run = wounded ? "wmove" : "move"; looping = true
            case .fire(.shot1): run = "fire1"; looping = false
            case .fire(.shot2): run = "fire2"; looping = false
            case .fire(.special): run = "sfire"; looping = false
            case .shock: run = "shock"; looping = false
            case .dead: run = "dead"; looping = false
            }
            if let animation = table.animation(named: run) ?? table.animation(named: "normal") {
                frame = frameIndex(in: animation, age: viewModel.clock - player.poseStarted, looping: looping)
            }
        }
        let key = "\(imageName)#\(frame)"
        if let cached = frameCache[key] { return cached }
        let texture = renderer.texture(named: imageName, frame: frame, assets: assets)
        if let texture { frameCache[key] = texture }
        return texture
    }

    /// Plays a run at ~15 ticks/s honoring the per-frame durations —
    /// looping runs wrap, one-shots hold their last frame (dead keeps
    /// its final white-flag frame up).
    private func frameIndex(in animation: EpaFile.Animation, age: Double, looping: Bool) -> Int {
        let total = max(1, animation.durations.reduce(0, +))
        var tick = max(0, Int(age * 15))
        tick = looping ? tick % total : min(tick, total - 1)
        var elapsed = 0
        for (offset, duration) in animation.durations.enumerated() {
            elapsed += duration
            if tick < elapsed { return animation.frames[offset] }
        }
        return animation.frames.last ?? 0
    }
}
