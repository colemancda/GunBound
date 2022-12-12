//
//  MapData.swift
//  
//
//  Created by Alsey Coleman Miller on 12/12/22.
//

import Foundation

// Map Metadata
public struct MapData: Equatable, Hashable {
    
    internal private(set) var data = [[[Position]]]()
    
    /// Initialize
    public init() {
        self.data = []
    }
}

public extension MapData {
    
    typealias Key = GameMap
    
    var isEmpty: Bool {
        return data.isEmpty
    }
    
    func position(for player: Room.PlayerSession.ID, in map: GameMap, team: Team) -> Position? {
        let mapIndex = Int(map.rawValue)
        guard mapIndex < data.count else {
            return nil
        }
        let teamIndex = Int(team.rawValue)
        guard teamIndex < data[mapIndex].count else {
            return nil
        }
        let playerIndex = Int(player)
        guard playerIndex < data[mapIndex][teamIndex].count else {
            return nil
        }
        return data[mapIndex][teamIndex][playerIndex]
    }
}

// MARK: - Codable

extension MapData: Codable {
    
    public init(from decoder: Decoder) throws {
        self.data = try [[[Position]]].init(from: decoder)
    }
    
    public func encode(to encoder: Encoder) throws {
        try self.data.encode(to: encoder)
    }
}
/*
// MARK: - ExpressibleByDictionaryLiteral

extension MapData: ExpressibleByDictionaryLiteral {
    
    public init(dictionaryLiteral elements: (GameMap, [Team: [Position]])...) {
        self.init(.init(uniqueKeysWithValues: elements))
    }
    
    public init(_ data: [GameMap: [Team: [Position]]]) {
        
    }
}
*/
// MARK: - Supporting Types

public extension MapData {
    
    struct Position: Codable, Equatable, Hashable {
        
        public var minX: UInt
        
        public var maxX: UInt
        
        public var y: UInt?
        
        public init(
            minX: UInt,
            maxX: UInt,
            y: UInt? = nil
        ) {
            self.minX = minX
            self.maxX = maxX
            self.y = y
        }
    }
}

// MARK: - Default Data

public extension MapData {
    
    static var `default`: MapData = {
        var mapData = MapData()
        mapData.data.reserveCapacity(11)
        var mapRandom = [[Position]]()
        mapRandom.reserveCapacity(2)
        var teamARandom = [Position]()
        teamARandom.reserveCapacity(8)
        teamARandom.append(Position(minX: 183, maxX: 358, y: nil))
        teamARandom.append(Position(minX: 476, maxX: 668, y: nil))
        teamARandom.append(Position(minX: 757, maxX: 850, y: nil))
        teamARandom.append(Position(minX: 899, maxX: 1064, y: nil))
        teamARandom.append(Position(minX: 1157, maxX: 1239, y: nil))
        teamARandom.append(Position(minX: 1303, maxX: 1366, y: nil))
        teamARandom.append(Position(minX: 1445, maxX: 1562, y: nil))
        teamARandom.append(Position(minX: 1634, maxX: 1634, y: nil))
        assert(teamARandom.count == 8)
        mapRandom.append(teamARandom)
        var teamBRandom = [Position]()
        teamBRandom.reserveCapacity(8)
        teamBRandom.append(Position(minX: 608, maxX: 682, y: nil))
        teamBRandom.append(Position(minX: 682, maxX: 756, y: nil))
        teamBRandom.append(Position(minX: 756, maxX: 828, y: nil))
        teamBRandom.append(Position(minX: 828, maxX: 902, y: nil))
        teamBRandom.append(Position(minX: 902, maxX: 978, y: nil))
        teamBRandom.append(Position(minX: 978, maxX: 1050, y: nil))
        teamBRandom.append(Position(minX: 1050, maxX: 1122, y: nil))
        teamBRandom.append(Position(minX: 1122, maxX: 1192, y: nil))
        assert(teamBRandom.count == 8)
        mapRandom.append(teamBRandom)
        assert(mapRandom.count == 2)
        mapData.data.append(mapRandom)
        var mapMiramoTown = [[Position]]()
        mapMiramoTown.reserveCapacity(2)
        var teamAMiramoTown = [Position]()
        teamAMiramoTown.reserveCapacity(8)
        teamAMiramoTown.append(Position(minX: 154, maxX: 350, y: nil))
        teamAMiramoTown.append(Position(minX: 350, maxX: 536, y: nil))
        teamAMiramoTown.append(Position(minX: 536, maxX: 722, y: nil))
        teamAMiramoTown.append(Position(minX: 722, maxX: 924, y: nil))
        teamAMiramoTown.append(Position(minX: 924, maxX: 1112, y: nil))
        teamAMiramoTown.append(Position(minX: 1112, maxX: 1304, y: nil))
        teamAMiramoTown.append(Position(minX: 1304, maxX: 1496, y: nil))
        teamAMiramoTown.append(Position(minX: 1496, maxX: 1676, y: nil))
        assert(teamAMiramoTown.count == 8)
        mapMiramoTown.append(teamAMiramoTown)
        var teamBMiramoTown = [Position]()
        teamBMiramoTown.reserveCapacity(8)
        teamBMiramoTown.append(Position(minX: 231, maxX: 231, y: nil))
        teamBMiramoTown.append(Position(minX: 484, maxX: 484, y: nil))
        teamBMiramoTown.append(Position(minX: 776, maxX: 776, y: nil))
        teamBMiramoTown.append(Position(minX: 796, maxX: 796, y: nil))
        teamBMiramoTown.append(Position(minX: 1020, maxX: 1020, y: nil))
        teamBMiramoTown.append(Position(minX: 1235, maxX: 1235, y: nil))
        teamBMiramoTown.append(Position(minX: 1393, maxX: 1393, y: nil))
        teamBMiramoTown.append(Position(minX: 1528, maxX: 1528, y: nil))
        assert(teamBMiramoTown.count == 8)
        mapMiramoTown.append(teamBMiramoTown)
        assert(mapMiramoTown.count == 2)
        mapData.data.append(mapMiramoTown)
        var mapNirvana = [[Position]]()
        mapNirvana.reserveCapacity(2)
        var teamANirvana = [Position]()
        teamANirvana.reserveCapacity(8)
        teamANirvana.append(Position(minX: 52, maxX: 240, y: nil))
        teamANirvana.append(Position(minX: 240, maxX: 424, y: nil))
        teamANirvana.append(Position(minX: 424, maxX: 612, y: nil))
        teamANirvana.append(Position(minX: 612, maxX: 800, y: nil))
        teamANirvana.append(Position(minX: 800, maxX: 988, y: nil))
        teamANirvana.append(Position(minX: 988, maxX: 1174, y: nil))
        teamANirvana.append(Position(minX: 1174, maxX: 1376, y: nil))
        teamANirvana.append(Position(minX: 1376, maxX: 1550, y: nil))
        assert(teamANirvana.count == 8)
        mapNirvana.append(teamANirvana)
        var teamBNirvana = [Position]()
        teamBNirvana.reserveCapacity(8)
        teamBNirvana.append(Position(minX: 475, maxX: 475, y: nil))
        teamBNirvana.append(Position(minX: 866, maxX: 866, y: nil))
        teamBNirvana.append(Position(minX: 1118, maxX: 1118, y: nil))
        teamBNirvana.append(Position(minX: 689, maxX: 689, y: nil))
        teamBNirvana.append(Position(minX: 946, maxX: 946, y: nil))
        teamBNirvana.append(Position(minX: 623, maxX: 623, y: (1000)))
        teamBNirvana.append(Position(minX: 771, maxX: 771, y: (1000)))
        teamBNirvana.append(Position(minX: 1023, maxX: 1100, y: (1053)))
        assert(teamBNirvana.count == 8)
        mapNirvana.append(teamBNirvana)
        assert(mapNirvana.count == 2)
        mapData.data.append(mapNirvana)
        var mapMetropolis = [[Position]]()
        mapMetropolis.reserveCapacity(2)
        var teamAMetropolis = [Position]()
        teamAMetropolis.reserveCapacity(8)
        teamAMetropolis.append(Position(minX: 51, maxX: 219, y: nil))
        teamAMetropolis.append(Position(minX: 219, maxX: 498, y: nil))
        teamAMetropolis.append(Position(minX: 498, maxX: 732, y: nil))
        teamAMetropolis.append(Position(minX: 732, maxX: 897, y: nil))
        teamAMetropolis.append(Position(minX: 897, maxX: 1065, y: nil))
        teamAMetropolis.append(Position(minX: 1065, maxX: 1302, y: nil))
        teamAMetropolis.append(Position(minX: 1302, maxX: 1572, y: nil))
        teamAMetropolis.append(Position(minX: 1572, maxX: 1743, y: nil))
        assert(teamAMetropolis.count == 8)
        mapMetropolis.append(teamAMetropolis)
        var teamBMetropolis = [Position]()
        teamBMetropolis.reserveCapacity(8)
        teamBMetropolis.append(Position(minX: 384, maxX: 384, y: nil))
        teamBMetropolis.append(Position(minX: 532, maxX: 532, y: nil))
        teamBMetropolis.append(Position(minX: 620, maxX: 620, y: nil))
        teamBMetropolis.append(Position(minX: 746, maxX: 746, y: nil))
        teamBMetropolis.append(Position(minX: 985, maxX: 985, y: nil))
        teamBMetropolis.append(Position(minX: 1111, maxX: 1111, y: nil))
        teamBMetropolis.append(Position(minX: 1274, maxX: 1274, y: nil))
        teamBMetropolis.append(Position(minX: 1319, maxX: 1319, y: nil))
        assert(teamBMetropolis.count == 8)
        mapMetropolis.append(teamBMetropolis)
        assert(mapMetropolis.count == 2)
        mapData.data.append(mapMetropolis)
        var mapSeaHero = [[Position]]()
        mapSeaHero.reserveCapacity(2)
        var teamASeaHero = [Position]()
        teamASeaHero.reserveCapacity(8)
        teamASeaHero.append(Position(minX: 26, maxX: 122, y: nil))
        teamASeaHero.append(Position(minX: 190, maxX: 292, y: nil))
        teamASeaHero.append(Position(minX: 462, maxX: 572, y: nil))
        teamASeaHero.append(Position(minX: 608, maxX: 724, y: nil))
        teamASeaHero.append(Position(minX: 880, maxX: 984, y: nil))
        teamASeaHero.append(Position(minX: 1004, maxX: 1118, y: nil))
        teamASeaHero.append(Position(minX: 1268, maxX: 1378, y: nil))
        teamASeaHero.append(Position(minX: 1446, maxX: 1556, y: nil))
        assert(teamASeaHero.count == 8)
        mapSeaHero.append(teamASeaHero)
        var teamBSeaHero = [Position]()
        teamBSeaHero.reserveCapacity(8)
        teamBSeaHero.append(Position(minX: 160, maxX: 160, y: nil))
        teamBSeaHero.append(Position(minX: 352, maxX: 352, y: nil))
        teamBSeaHero.append(Position(minX: 537, maxX: 537, y: nil))
        teamBSeaHero.append(Position(minX: 698, maxX: 698, y: nil))
        teamBSeaHero.append(Position(minX: 898, maxX: 898, y: nil))
        teamBSeaHero.append(Position(minX: 1056, maxX: 1056, y: nil))
        teamBSeaHero.append(Position(minX: 1303, maxX: 1303, y: nil))
        teamBSeaHero.append(Position(minX: 1409, maxX: 1409, y: nil))
        assert(teamBSeaHero.count == 8)
        mapSeaHero.append(teamBSeaHero)
        assert(mapSeaHero.count == 2)
        mapData.data.append(mapSeaHero)
        var mapAdiumroot = [[Position]]()
        mapAdiumroot.reserveCapacity(2)
        var teamAAdiumroot = [Position]()
        teamAAdiumroot.reserveCapacity(8)
        teamAAdiumroot.append(Position(minX: 26, maxX: 230, y: nil))
        teamAAdiumroot.append(Position(minX: 230, maxX: 428, y: nil))
        teamAAdiumroot.append(Position(minX: 428, maxX: 640, y: nil))
        teamAAdiumroot.append(Position(minX: 640, maxX: 874, y: nil))
        teamAAdiumroot.append(Position(minX: 874, maxX: 1108, y: nil))
        teamAAdiumroot.append(Position(minX: 1108, maxX: 1340, y: nil))
        teamAAdiumroot.append(Position(minX: 1340, maxX: 1552, y: nil))
        teamAAdiumroot.append(Position(minX: 1552, maxX: 1760, y: nil))
        assert(teamAAdiumroot.count == 8)
        mapAdiumroot.append(teamAAdiumroot)
        var teamBAdiumroot = [Position]()
        teamBAdiumroot.reserveCapacity(8)
        teamBAdiumroot.append(Position(minX: 939, maxX: 939, y: (771)))
        teamBAdiumroot.append(Position(minX: 1030, maxX: 1030, y: (801)))
        teamBAdiumroot.append(Position(minX: 902, maxX: 902, y: (869)))
        teamBAdiumroot.append(Position(minX: 809, maxX: 809, y: (902)))
        teamBAdiumroot.append(Position(minX: 989, maxX: 989, y: (1008)))
        teamBAdiumroot.append(Position(minX: 1061, maxX: 1061, y: (1030)))
        teamBAdiumroot.append(Position(minX: 856, maxX: 856, y: (1104)))
        teamBAdiumroot.append(Position(minX: 763, maxX: 763, y: (1134)))
        assert(teamBAdiumroot.count == 8)
        mapAdiumroot.append(teamBAdiumroot)
        assert(mapAdiumroot.count == 2)
        mapData.data.append(mapAdiumroot)
        var mapDragon = [[Position]]()
        mapDragon.reserveCapacity(2)
        var teamADragon = [Position]()
        teamADragon.reserveCapacity(8)
        teamADragon.append(Position(minX: 70, maxX: 188, y: nil))
        teamADragon.append(Position(minX: 244, maxX: 334, y: nil))
        teamADragon.append(Position(minX: 378, maxX: 490, y: nil))
        teamADragon.append(Position(minX: 540, maxX: 618, y: nil))
        teamADragon.append(Position(minX: 1182, maxX: 1274, y: nil))
        teamADragon.append(Position(minX: 1328, maxX: 1416, y: nil))
        teamADragon.append(Position(minX: 1472, maxX: 1558, y: nil))
        teamADragon.append(Position(minX: 1622, maxX: 1718, y: nil))
        assert(teamADragon.count == 8)
        mapDragon.append(teamADragon)
        var teamBDragon = [Position]()
        teamBDragon.reserveCapacity(8)
        teamBDragon.append(Position(minX: 434, maxX: 434, y: nil))
        teamBDragon.append(Position(minX: 521, maxX: 521, y: nil))
        teamBDragon.append(Position(minX: 591, maxX: 591, y: nil))
        teamBDragon.append(Position(minX: 860, maxX: 860, y: nil))
        teamBDragon.append(Position(minX: 975, maxX: 975, y: nil))
        teamBDragon.append(Position(minX: 1055, maxX: 1055, y: nil))
        teamBDragon.append(Position(minX: 1289, maxX: 1289, y: nil))
        teamBDragon.append(Position(minX: 1440, maxX: 1440, y: nil))
        assert(teamBDragon.count == 8)
        mapDragon.append(teamBDragon)
        assert(mapDragon.count == 2)
        mapData.data.append(mapDragon)
        var mapCozytower = [[Position]]()
        mapCozytower.reserveCapacity(2)
        var teamACozytower = [Position]()
        teamACozytower.reserveCapacity(8)
        teamACozytower.append(Position(minX: 120, maxX: 222, y: nil))
        teamACozytower.append(Position(minX: 222, maxX: 324, y: nil))
        teamACozytower.append(Position(minX: 428, maxX: 570, y: nil))
        teamACozytower.append(Position(minX: 614, maxX: 902, y: nil))
        teamACozytower.append(Position(minX: 902, maxX: 1192, y: nil))
        teamACozytower.append(Position(minX: 1230, maxX: 1378, y: nil))
        teamACozytower.append(Position(minX: 1484, maxX: 1590, y: nil))
        teamACozytower.append(Position(minX: 1590, maxX: 1688, y: nil))
        assert(teamACozytower.count == 8)
        mapCozytower.append(teamACozytower)
        var teamBCozytower = [Position]()
        teamBCozytower.reserveCapacity(8)
        teamBCozytower.append(Position(minX: 203, maxX: 203, y: nil))
        teamBCozytower.append(Position(minX: 411, maxX: 411, y: nil))
        teamBCozytower.append(Position(minX: 611, maxX: 611, y: nil))
        teamBCozytower.append(Position(minX: 810, maxX: 810, y: nil))
        teamBCozytower.append(Position(minX: 996, maxX: 996, y: nil))
        teamBCozytower.append(Position(minX: 1193, maxX: 1193, y: nil))
        teamBCozytower.append(Position(minX: 1394, maxX: 1394, y: nil))
        teamBCozytower.append(Position(minX: 1592, maxX: 1592, y: nil))
        assert(teamBCozytower.count == 8)
        mapCozytower.append(teamBCozytower)
        assert(mapCozytower.count == 2)
        mapData.data.append(mapCozytower)
        var mapDummySlope = [[Position]]()
        mapDummySlope.reserveCapacity(2)
        var teamADummySlope = [Position]()
        teamADummySlope.reserveCapacity(8)
        teamADummySlope.append(Position(minX: 120, maxX: 208, y: nil))
        teamADummySlope.append(Position(minX: 234, maxX: 334, y: nil))
        teamADummySlope.append(Position(minX: 442, maxX: 570, y: nil))
        teamADummySlope.append(Position(minX: 600, maxX: 722, y: nil))
        teamADummySlope.append(Position(minX: 876, maxX: 986, y: nil))
        teamADummySlope.append(Position(minX: 1004, maxX: 1106, y: nil))
        teamADummySlope.append(Position(minX: 1230, maxX: 1324, y: nil))
        teamADummySlope.append(Position(minX: 1346, maxX: 1472, y: nil))
        assert(teamADummySlope.count == 8)
        mapDummySlope.append(teamADummySlope)
        var teamBDummySlope = [Position]()
        teamBDummySlope.reserveCapacity(8)
        teamBDummySlope.append(Position(minX: 308, maxX: 308, y: (971)))
        teamBDummySlope.append(Position(minX: 250, maxX: 250, y: (1081)))
        teamBDummySlope.append(Position(minX: 379, maxX: 379, y: (1176)))
        teamBDummySlope.append(Position(minX: 619, maxX: 619, y: (1191)))
        teamBDummySlope.append(Position(minX: 1257, maxX: 1257, y: (976)))
        teamBDummySlope.append(Position(minX: 1384, maxX: 1384, y: (1086)))
        teamBDummySlope.append(Position(minX: 1140, maxX: 1140, y: (1176)))
        teamBDummySlope.append(Position(minX: 962, maxX: 962, y: (1193)))
        assert(teamBDummySlope.count == 8)
        mapDummySlope.append(teamBDummySlope)
        assert(mapDummySlope.count == 2)
        mapData.data.append(mapDummySlope)
        var mapStardust = [[Position]]()
        mapStardust.reserveCapacity(2)
        var teamAStardust = [Position]()
        teamAStardust.reserveCapacity(8)
        teamAStardust.append(Position(minX: 297, maxX: 451, y: nil))
        teamAStardust.append(Position(minX: 451, maxX: 592, y: nil))
        teamAStardust.append(Position(minX: 592, maxX: 741, y: nil))
        teamAStardust.append(Position(minX: 741, maxX: 903, y: nil))
        teamAStardust.append(Position(minX: 903, maxX: 1066, y: nil))
        teamAStardust.append(Position(minX: 1066, maxX: 1210, y: nil))
        teamAStardust.append(Position(minX: 1210, maxX: 1357, y: nil))
        teamAStardust.append(Position(minX: 1357, maxX: 1507, y: nil))
        assert(teamAStardust.count == 8)
        mapStardust.append(teamAStardust)
        var teamBStardust = [Position]()
        teamBStardust.reserveCapacity(8)
        teamBStardust.append(Position(minX: 210, maxX: 210, y: nil))
        teamBStardust.append(Position(minX: 297, maxX: 297, y: nil))
        teamBStardust.append(Position(minX: 774, maxX: 774, y: nil))
        teamBStardust.append(Position(minX: 765, maxX: 765, y: nil))
        teamBStardust.append(Position(minX: 1053, maxX: 1053, y: nil))
        teamBStardust.append(Position(minX: 1100, maxX: 1100, y: nil))
        teamBStardust.append(Position(minX: 1458, maxX: 1458, y: nil))
        teamBStardust.append(Position(minX: 1496, maxX: 1496, y: nil))
        assert(teamBStardust.count == 8)
        mapStardust.append(teamBStardust)
        assert(mapStardust.count == 2)
        mapData.data.append(mapStardust)
        var mapMetaMine = [[Position]]()
        mapMetaMine.reserveCapacity(2)
        var teamAMetaMine = [Position]()
        teamAMetaMine.reserveCapacity(8)
        teamAMetaMine.append(Position(minX: 222, maxX: 408, y: nil))
        teamAMetaMine.append(Position(minX: 408, maxX: 568, y: nil))
        teamAMetaMine.append(Position(minX: 568, maxX: 728, y: nil))
        teamAMetaMine.append(Position(minX: 728, maxX: 900, y: nil))
        teamAMetaMine.append(Position(minX: 900, maxX: 1066, y: nil))
        teamAMetaMine.append(Position(minX: 1066, maxX: 1230, y: nil))
        teamAMetaMine.append(Position(minX: 1230, maxX: 1390, y: nil))
        teamAMetaMine.append(Position(minX: 1390, maxX: 1576, y: nil))
        assert(teamAMetaMine.count == 8)
        mapMetaMine.append(teamAMetaMine)
        var teamBMetaMine = [Position]()
        teamBMetaMine.reserveCapacity(8)
        teamBMetaMine.append(Position(minX: 347, maxX: 347, y: nil))
        teamBMetaMine.append(Position(minX: 655, maxX: 655, y: nil))
        teamBMetaMine.append(Position(minX: 899, maxX: 899, y: nil))
        teamBMetaMine.append(Position(minX: 1099, maxX: 1099, y: nil))
        teamBMetaMine.append(Position(minX: 1456, maxX: 1456, y: nil))
        teamBMetaMine.append(Position(minX: 452, maxX: 452, y: (1000)))
        teamBMetaMine.append(Position(minX: 821, maxX: 821, y: (1000)))
        teamBMetaMine.append(Position(minX: 1320, maxX: 1320, y: (1000)))
        assert(teamBMetaMine.count == 8)
        mapMetaMine.append(teamBMetaMine)
        assert(mapMetaMine.count == 2)
        mapData.data.append(mapMetaMine)
        assert(mapData.data.count == 11)
        return mapData
    }()
}
