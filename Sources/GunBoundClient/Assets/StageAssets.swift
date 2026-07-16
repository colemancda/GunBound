import GunBound
import GunBoundProtocol
import GunBoundFile

/// The stage-asset naming for each map — the archive stores every battle
/// stage as a codename triple: `<code>.img` (the stage art, ~1600–2000px
/// square, frame 0 = terrain), `<code>.lnd` (the per-pixel terrain/collision
/// mask, width×height bytes + 8-byte header), and `<code>b.*` (the stage's
/// B-side variant).
///
/// The map→codename table was established empirically: `cave` = Random is
/// confirmed by `stage.dat`'s only real record ("Cave(Random)"), and the
/// remaining ten were matched visually — each codename's terrain silhouette
/// against the map-id-indexed `load_stageNN.img` previews (metro's riveted
/// arms = Metropolis, last's bone crab = Dragon, facky's mining platform =
/// Meta Mine, candy's domed islands = Sea Hero, kettle's yellow pods =
/// Dummy Slope, mos's snowfield = Miramo Town, hok's lava = Nirvana,
/// babo's segmented track = Adiumroot, star's ring = Stardust, brick's
/// golden arch = Cozy Tower).
public extension GameMap {

    /// The stage's archive codename.
    var stageCodename: String {
        switch self {
        case .random: return "cave"
        case .miramoTown: return "mos"
        case .nirvana: return "hok"
        case .metropolis: return "metro"
        case .seaHero: return "candy"
        case .adiumroot: return "babo"
        case .dragon: return "last"
        case .cozytower: return "brick"
        case .dummySlope: return "kettle"
        case .stardust: return "star"
        case .metaMine: return "facky"
        }
    }

    /// The stage art (`<code>.img`, frame 0 = the terrain layer).
    var stageImageName: String { "\(stageCodename).img" }

    /// The terrain/collision mask (`<code>.lnd`).
    var stageLandName: String { "\(stageCodename).lnd" }
}

public extension Mobile {

    /// The mobile's asset number — the `N` in the sprite sheet name
    /// (`tankN.img`, 455 frames of 36×40 cells) and in the per-mobile
    /// sound effects (`<N><weapon>fire.xes`, `<N>move.xes`, …). Assets
    /// are 1-indexed in raw-value order, with Dragon/Knight (raw
    /// `0x11`/`0x12`) as 15/16; `.random` falls back to Armor (a started
    /// match should have resolved it).
    var sheetNumber: Int {
        switch self {
        case .dragon: return 15
        case .knight: return 16
        case .random: return 1
        default: return Int(rawValue) + 1
        }
    }

    var tankImageName: String { "tank\(sheetNumber).img" }

    /// The sheet's paired `.epa` animation table (named frame runs:
    /// `normal`, `move`, `fire1`, `shock`, `dead`, the `w`-prefixed
    /// wounded variants, …).
    var tankAnimationName: String {
        String(tankImageName.dropLast(4)) + ".epa"
    }
}

/// The `.lnd` mask satisfies the battle's terrain queries directly.
extension LndFile: GunBound.BattleTerrain {}
