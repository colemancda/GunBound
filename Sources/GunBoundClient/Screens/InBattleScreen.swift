import Foundation
import GunBound
import GunBoundProtocol
import GunBoundFile

/// View for the In-Battle screen (state 11) — the playable slice: the stage
/// scenery and terrain through the camera (frame 1 = the full painted
/// backdrop, frame 0 = the terrain silhouette drawn over it — confirmed
/// visually against the real archive), mobiles animated from their `.epa`
/// runs and grounded on the `.lnd` surface, and the fire loop's visuals —
/// an aim-arc of dots, the power gauge, weapon bullet art, and an
/// **additively-blended** explosion flash (the glow blend the original's
/// scene composer flips to for effect layers). HUD shows the turn, angle,
/// weapon, and turn clock; blast craters carve real holes through the
/// terrain layer into the scenery beneath.
@MainActor
public final class InBattleScreen: GameScreen {
    private let viewModel: InBattleViewModel
    /// The stage's full scenery — the same sheet's frame 1 (confirmed
    /// visually: frame 0 is the terrain silhouette alone, frame 1 is the
    /// complete painted backdrop behind it). Drawn first so carved craters
    /// in the terrain layer reveal it instead of the clear color.
    private var backgroundTexture: ClientTexture?
    private var terrainTexture: ClientTexture?
    /// The stage frame's pixels, kept so blast holes can be punched into
    /// them and the texture rebuilt (real terrain destruction).
    private var terrainFrame: ImgFile.Frame?
    /// How many of the model's craters are already carved into the frame.
    private var carvedCraters = 0
    /// Each mobile's `.epa` animation table — the named frame runs
    /// (`normal`, `move`, `fire1`, `shock`, `dead`, wounded variants) that
    /// map poses onto the 455-frame `tankN.img` sheets.
    private var mobileAnimations: [Mobile: EpaFile] = [:]
    /// Lazily-built textures keyed `"<image>#<frame>"` (the renderers
    /// don't cache; the decoded sheet behind them does).
    private var frameCache: [String: ClientTexture] = [:]
    private var assets: AssetLibrary?

    /// A projectile's loaded art: its frame textures in play order plus
    /// the `.epa` run driving them.
    private struct BulletArt {
        let textures: [ClientTexture]
        let durations: [Int]
    }
    /// Bullet art keyed by `"<mobile>-<weapon>"`; `.some(nil)` records a
    /// known miss so absent art isn't re-probed every frame.
    private var bulletArt: [String: BulletArt?] = [:]
    /// A small round dot (`load_back.img` frame 2) reused for the aim arc,
    /// the projectile, and (scaled, additive) the explosion flash.
    private var dotTexture: ClientTexture?
    /// The bottom HUD chrome (`play_back.img` frame 1, 800×44): item/weapon
    /// slot boxes and the power-charge track. Positions below are measured
    /// empirically against the extracted sprite (not decomp-confirmed
    /// offsets — the vtable only pins which function renders this, not its
    /// pixel layout).
    private var hudBarTexture: ClientTexture?
    /// Item quick-bar icons, parallel to `viewModel.battleItems`.
    private var itemBarTextures: [ClientTexture?] = []
    /// The movement gauge chrome (`play_back.img` frame 6, 485×26): the
    /// "MOVE" label plus its empty track.
    private var moveBarTexture: ClientTexture?
    private var font: LoadedFont?
    private var audio: ClientAudioPlayer?
    /// The three weather-hazard textures (`.xtf` surfaces, not `.img`
    /// sprite sheets — see `AssetLibrary.xtfTexture(named:)`), loaded once
    /// on first use. `.some(nil)` records a load failure so it isn't
    /// retried every frame.
    private var hazardTextures: [InBattleViewModel.WeatherHazardKind: ClientTexture?] = [:]

    public init(viewModel: InBattleViewModel) {
        self.viewModel = viewModel
    }

    public func onEnter(context: ClientContext) throws {
        viewModel.onEnter()
        let renderer = context.renderer
        let assets = context.assets

        backgroundTexture = renderer.texture(named: viewModel.map.stageImageName, frame: 1, assets: assets)
        terrainFrame = try? assets.imageFrame(named: viewModel.map.stageImageName, at: 0)
        carvedCraters = 0
        if let terrainFrame {
            terrainTexture = renderer.texture(from: terrainFrame)
        } else {
            terrainTexture = renderer.texture(named: viewModel.map.stageImageName, assets: assets)
        }
        let (worldWidth, worldHeight) = renderer.size(of: terrainTexture)
        viewModel.setWorldSize(width: worldWidth, height: worldHeight)

        // The stage's collision mask grounds each mobile at its spawn column.
        if let mask = try? assets.terrainMask(named: viewModel.map.stageLandName) {
            viewModel.setTerrain(mask)
        }

        self.assets = assets
        // Primaries and Tag-mode secondaries alike — a mid-match tag swap
        // must find its animation table already loaded.
        for mobile in Set(viewModel.players.flatMap { [$0.mobile, $0.secondaryMobile] }) {
            mobileAnimations[mobile] = try? assets.animationTable(named: mobile.tankAnimationName)
        }
        dotTexture = renderer.texture(named: "load_back.img", frame: 2, assets: assets)
        hudBarTexture = renderer.texture(named: "play_back.img", frame: 1, assets: assets)
        moveBarTexture = renderer.texture(named: "play_back.img", frame: 6, assets: assets)
        font = LoadedFont(.latinFont, renderer: renderer, assets: assets)

        // The item quick-bar icons: each owned item's ordinal icon code
        // (`DAT_0056dc40[ordinal]`) decodes to a frame in the in-battle item
        // sheets (`ready_item1.img` single-slot / `ready_item2.img` double).
        itemBarTextures = viewModel.battleItems.map { item in
            let icon = ItemDataFile.shelfIcon(forCode: item.iconCode)
            let sheet = icon.sheetIndex == 1 ? "ready_item2.img" : "ready_item1.img"
            return renderer.texture(named: sheet, frame: icon.enabledFrame, assets: assets)
        }

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
        backgroundTexture = nil
        terrainTexture = nil
        terrainFrame = nil
        carvedCraters = 0
        mobileAnimations = [:]
        frameCache = [:]
        bulletArt = [:]
        assets = nil
        dotTexture = nil
        hudBarTexture = nil
        itemBarTextures = []
        moveBarTexture = nil
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

        // Carve any newly-blasted craters into the stage frame and rebuild
        // its texture — real holes in the terrain art, matching the
        // collision holes the model already tracks.
        carvePendingCraters(renderer)

        // The stage world, offset by the camera (world → screen is
        // `world − cam + halfView`; drawing the full map at the transformed
        // origin is equivalent). The background scenery draws first so the
        // terrain layer's carved crater holes reveal it underneath.
        let worldOrigin = viewModel.screenPosition(x: 0, y: 0)
        if let backgroundTexture {
            let (width, height) = renderer.size(of: backgroundTexture)
            renderer.draw(backgroundTexture, in: Rect(x: worldOrigin.x, y: worldOrigin.y, width: width, height: height), tint: nil)
        }
        if let terrainTexture {
            let (width, height) = renderer.size(of: terrainTexture)
            renderer.draw(terrainTexture, in: Rect(x: worldOrigin.x, y: worldOrigin.y, width: width, height: height), tint: nil)
        }

        // Terrain hazards, drawn over the stage but under the mobiles —
        // matches `RenderWeatherHazards`'s slot-12 render-tail position in
        // the original's per-frame draw order.
        for hazard in viewModel.weatherHazards {
            guard let texture = hazardTexture(for: hazard.kind, renderer: renderer) else { continue }
            let groundY = viewModel.groundLevel(atX: hazard.x, below: 0) ?? 300
            let position = viewModel.screenPosition(x: hazard.x, y: groundY)
            let span = hazard.width * 2
            let blend: ClientBlendMode = hazard.kind == .lightning ? .additive : .alpha
            renderer.draw(
                texture,
                in: Rect(x: position.x - span / 2, y: position.y - span, width: span, height: span),
                tint: nil,
                blend: blend,
                opacity: 1
            )
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

        // The projectile: the shooter's weapon bullet art (its `.epa` run
        // looping in flight), falling back to the glowing dot when the
        // archive has no art for that mobile/weapon.
        if let shot = viewModel.projectile {
            let position = viewModel.screenPosition(x: shot.x, y: shot.y)
            if let sprite = bulletSprite(renderer: renderer) {
                let (width, height) = renderer.size(of: sprite)
                renderer.draw(
                    sprite,
                    in: Rect(x: position.x - width / 2, y: position.y - height / 2, width: width, height: height),
                    tint: nil
                )
            } else if let dotTexture {
                renderer.draw(dotTexture, in: Rect(x: position.x - 5, y: position.y - 5, width: 10, height: 10), tint: (255, 240, 180))
            }
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

        // The match result banner, centered while the outcome lingers
        // before returning to the room.
        if viewModel.isMatchOver {
            let banner = viewModel.winner.map { "TEAM \("\($0)".uppercased()) WINS!" } ?? "DRAW!"
            let width = font.width(of: banner)
            if let dotTexture {
                renderer.draw(dotTexture, in: Rect(x: 400 - width / 2 - 16, y: 268, width: width + 32, height: 40), tint: (10, 10, 10))
            }
            font.draw(banner, x: 400 - width / 2, y: 282, tint: (255, 220, 120), using: renderer)
        }

        // HUD: map + game mode, whose turn, and the aim/power readout.
        font.draw("\(viewModel.map)  \(viewModel.gameMode)", x: 12, y: 8, using: renderer)

        // Score mode's shared life pools, centered under the wind readout.
        if let lives = viewModel.teamLives {
            let text = "LIVES  A \(max(0, lives.a))  B \(max(0, lives.b))"
            let width = font.width(of: text)
            font.draw(text, x: 400 - width / 2, y: 40, tint: (255, 200, 120), using: renderer)
        }
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

        // The bottom HUD bar: real chrome (item/weapon slot boxes, the
        // power track) instead of placeholder shapes.
        if let hudBarTexture {
            let (width, height) = renderer.size(of: hudBarTexture)
            renderer.draw(hudBarTexture, in: Rect(x: 0, y: 600 - height, width: width, height: height), tint: nil)
        }
        // A soft glow over the acting weapon's slot box (the item-1/item-2/
        // SS boxes baked into the bar art) — additive so it highlights
        // without blotting out the icon underneath.
        if let dotTexture, viewModel.isMyTurn, viewModel.phase == .aiming || viewModel.phase == .charging {
            let box: Rect
            switch viewModel.selectedWeapon {
            case .shot1: box = Rect(x: 6, y: 559, width: 34, height: 35)
            case .shot2: box = Rect(x: 40, y: 559, width: 48, height: 35)
            case .special: box = Rect(x: 88, y: 559, width: 34, height: 35)
            }
            renderer.draw(dotTexture, in: box, tint: (200, 170, 80), blend: .additive)
        }
        // The power gauge fills the bar's baked-in track while charging.
        if let dotTexture, viewModel.phase == .charging {
            let width = 401 * viewModel.power
            renderer.draw(dotTexture, in: Rect(x: 243, y: 568, width: width, height: 23), tint: (255, UInt8(220 - viewModel.power * 160), 80))
        }

        // The item quick-bar: the player's owned items in a strip above the
        // bottom HUD bar, the selected slot lit. Visual only — items have no
        // combat effect (the client has no item-use action; effects resolve
        // server-side — see `InBattleViewModel.ownedItems`).
        for index in viewModel.battleItems.indices {
            let slot = InBattleViewModel.itemSlotRect(at: index)
            if let dotTexture {
                // A dark slot backing, brighter when selected.
                let shade: UInt8 = index == viewModel.selectedItemIndex ? 60 : 25
                renderer.draw(dotTexture, in: slot, tint: (shade, shade, shade))
            }
            if index < itemBarTextures.count, let icon = itemBarTextures[index] {
                let (w, h) = renderer.size(of: icon)
                let scale = min(1, min((slot.width - 2) / max(1, w), (slot.height - 2) / max(1, h)))
                let dw = w * scale, dh = h * scale
                renderer.draw(icon, in: Rect(x: slot.x + (slot.width - dw) / 2, y: slot.y + (slot.height - dh) / 2, width: dw, height: dh), tint: nil)
            }
            if index == viewModel.selectedItemIndex, let dotTexture {
                renderer.draw(dotTexture, in: slot, tint: (255, 220, 120), blend: .additive)
            }
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

        // The chat composer bar while typing (Enter sends) — sits above
        // the movement gauge, clear of the bottom HUD bar.
        if let draft = viewModel.chatDraft {
            if let dotTexture {
                renderer.draw(dotTexture, in: Rect(x: 8, y: 494, width: 500, height: 18), tint: (15, 15, 15))
            }
            font.draw("> \(draft)_", x: 14, y: 497, tint: (255, 255, 255), using: renderer)
        }

        // The movement gauge: the real "MOVE" bar chrome, filled to the
        // turn's remaining walking budget — drawn just above the bottom
        // HUD bar while free to walk.
        if viewModel.isMyTurn, viewModel.phase == .aiming {
            if let moveBarTexture {
                let (width, height) = renderer.size(of: moveBarTexture)
                renderer.draw(moveBarTexture, in: Rect(x: 12, y: 522, width: width, height: height), tint: nil)
            }
            if let dotTexture {
                let ratio = viewModel.moveBudget / InBattleViewModel.moveBudgetPerTurn
                renderer.draw(dotTexture, in: Rect(x: 88, y: 532, width: 402 * ratio, height: 10), tint: (120, 200, 255))
            }
        }
    }

    // MARK: - Projectile art

    /// The current frame of the in-flight shot's bullet art (`bullet<N>n/p/s`
    /// per the shooter's mobile and weapon slot), its `.epa` run looping at
    /// the sheet tick rate. `nil` when the archive has no art to offer.
    /// Loads (and caches) a weather-hazard's texture — a single flat `.xtf`
    /// surface, not a `.epa`-driven sprite sheet (see `AssetLibrary.
    /// xtfTexture(named:)`). Drawn unrotated: `ClientRenderer` has no
    /// rotation parameter, so the decomp's per-frame swirl rotation
    /// ((frame%64)*-6°, `InitTornadoHazard.c`) isn't reproduced — the same
    /// class of approximation as the screen-transition wipe's triangle-via-
    /// rects.
    private func hazardTexture(for kind: InBattleViewModel.WeatherHazardKind, renderer: ClientRenderer) -> ClientTexture? {
        if let cached = hazardTextures[kind] {
            return cached
        }
        guard let assets else { return nil }
        let name: String
        switch kind {
        case .tornado: name = "TornadoTexture.xtf"
        case .firewall: name = "FirewallTexture.xtf"
        case .lightning: name = "LightningTexture.xtf"
        }
        let texture = (try? assets.xtfTexture(named: name)).flatMap { renderer.texture(from: $0) }
        hazardTextures[kind] = texture
        return texture
    }

    private func bulletSprite(renderer: ClientRenderer) -> ClientTexture? {
        guard let shot = viewModel.activeShot else { return nil }
        let key = "\(shot.mobile.rawValue)-\(shot.weapon.rawValue)"
        let art: BulletArt?
        if let cached = bulletArt[key] {
            art = cached
        } else {
            art = loadBulletArt(mobile: shot.mobile, weapon: shot.weapon, renderer: renderer)
            bulletArt[key] = art
        }
        guard let art, !art.textures.isEmpty else { return nil }
        let total = max(1, art.durations.reduce(0, +))
        var tick = Int(viewModel.clock * 15) % total
        for (offset, duration) in art.durations.enumerated() {
            tick -= duration
            if tick < 0 { return art.textures[min(offset, art.textures.count - 1)] }
        }
        return art.textures.last
    }

    /// Loads a weapon's bullet art, preferring its own variant letter and
    /// falling back through the others — the archive's per-mobile coverage
    /// is uneven. The letters are decomp-confirmed (`Mobile00_MainAction`
    /// dispatch): **Shot 1 = `n`** (`SpawnPrimaryShot`, param_4 0), **Shot 2
    /// = `s`** (`SpawnPrimaryShot`, param_4 1 super), **SS = `p`**
    /// (`SpawnSuperShot`).
    private func loadBulletArt(mobile: Mobile, weapon: InBattleViewModel.Weapon, renderer: ClientRenderer) -> BulletArt? {
        guard let assets else { return nil }
        let variants: [String]
        switch weapon {
        case .shot1: variants = ["n", "s", "p"]
        case .shot2: variants = ["s", "n", "p"]
        case .special: variants = ["p", "s", "n"]
        }
        for variant in variants {
            let base = "bullet\(mobile.sheetNumber)\(variant)"
            guard let frames = try? assets.image(named: base + ".img"), !frames.isEmpty else { continue }
            // The paired table's first run drives the flight loop; without
            // one, play every frame at one tick each.
            let run = (try? assets.animationTable(named: base + ".epa"))?.animations.first
            let indices = run?.frames ?? Array(frames.indices)
            var textures: [ClientTexture] = []
            var durations: [Int] = []
            for (offset, index) in indices.enumerated() where frames.indices.contains(index) {
                guard let texture = renderer.texture(named: base + ".img", frame: index, assets: assets) else { continue }
                textures.append(texture)
                durations.append(run?.durations[offset] ?? 1)
            }
            guard !textures.isEmpty else { continue }
            return BulletArt(textures: textures, durations: durations)
        }
        return nil
    }

    // MARK: - Terrain destruction

    /// Punches the model's newly-carved craters through the stage frame's
    /// pixels — a transparent hole ringed by a scorched rim — and rebuilds
    /// the terrain texture.
    private func carvePendingCraters(_ renderer: ClientRenderer) {
        guard let frame = terrainFrame, viewModel.craters.count > carvedCraters else { return }
        let width = Int(frame.width)
        let height = Int(frame.height)
        let hole = ImgFile.Pixel(argb4444: 0)
        let rimWidth = 3
        var pixels = frame.pixels
        for crater in viewModel.craters[carvedCraters...] {
            let centerX = Int(crater.x)
            let centerY = Int(crater.y)
            let radius = Int(crater.radius)
            let outer = radius + rimWidth
            for dy in -outer...outer {
                let y = centerY + dy
                guard y >= 0, y < height else { continue }
                for dx in -outer...outer {
                    let x = centerX + dx
                    guard x >= 0, x < width else { continue }
                    let distanceSquared = dx * dx + dy * dy
                    let index = y * width + x
                    if distanceSquared <= radius * radius {
                        pixels[index] = hole
                    } else if distanceSquared <= outer * outer {
                        // Scorch the rim (skip already-transparent sky).
                        let pixel = pixels[index]
                        guard pixel.alpha > 0 else { continue }
                        pixels[index] = ImgFile.Pixel(
                            red: pixel.red / 3,
                            green: pixel.green / 3,
                            blue: pixel.blue / 3,
                            alpha: pixel.alpha
                        )
                    }
                }
            }
        }
        let carved = ImgFile.Frame(
            transparencyType: frame.transparencyType,
            width: frame.width,
            height: frame.height,
            xCenter: frame.xCenter,
            yCenter: frame.yCenter,
            flippedX: frame.flippedX,
            flippedY: frame.flippedY,
            unknown1: frame.unknown1,
            unknown2: frame.unknown2,
            pixels: pixels
        )
        terrainFrame = carved
        if let rebuilt = renderer.texture(from: carved) {
            terrainTexture = rebuilt
        }
        carvedCraters = viewModel.craters.count
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
