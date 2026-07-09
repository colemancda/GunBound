import GunBound
import GunBoundProtocol

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

    /// The mobile's in-battle sprite sheet (`tank1.img` … `tank16.img`,
    /// 455 frames of 36×40 cells; frame 0 = the idle pose). The sheets are
    /// 1-indexed in raw-value order, with Dragon/Knight (raw `0x11`/`0x12`)
    /// as sheets 15/16; `.random` falls back to Armor's sheet (a started
    /// match should have resolved it).
    var tankImageName: String {
        switch self {
        case .dragon: return "tank15.img"
        case .knight: return "tank16.img"
        case .random: return "tank1.img"
        default: return "tank\(Int(rawValue) + 1).img"
        }
    }
}
