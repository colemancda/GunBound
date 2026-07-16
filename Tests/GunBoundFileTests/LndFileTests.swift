import Foundation
import Testing
@testable import GunBoundFile

@Suite struct LndFileTests {

    /// A 4×4 world: air above a flat floor at y 2, with a one-column tunnel
    /// at x 3 (all air).
    ///
    /// ```
    /// . . . .
    /// . . . .
    /// # # # .
    /// # # # .
    /// ```
    private func makeTerrain() throws -> LndFile {
        var data: [UInt8] = [4, 0, 0, 0, 4, 0, 0, 0]
        data += [0, 0, 0, 0,
                 0, 0, 0, 0,
                 2, 2, 2, 0,
                 2, 2, 2, 0]
        return try LndFile.read(data)
    }

    @Test func parsesHeaderAndMask() throws {
        let terrain = try makeTerrain()
        #expect(terrain.width == 4)
        #expect(terrain.height == 4)
        #expect(terrain.isSolid(x: 0, y: 2))
        #expect(!terrain.isSolid(x: 0, y: 1))
        #expect(!terrain.isSolid(x: 3, y: 2))   // the tunnel column
        #expect(!terrain.isSolid(x: -1, y: 2))  // out of bounds = air
        #expect(!terrain.isSolid(x: 0, y: 9))
    }

    @Test func groundAndSurfaceQueries() throws {
        let terrain = try makeTerrain()
        // Falling from the sky lands on the floor.
        #expect(terrain.groundLevel(atX: 1, below: 0) == 2)
        // The tunnel column has no ground.
        #expect(terrain.groundLevel(atX: 3, below: 0) == nil)
        // Surface from open air falls to the floor.
        #expect(terrain.surfaceLevel(atX: 1, near: 0) == 2)
        // Surface from inside the ground climbs to the terrain top.
        #expect(terrain.surfaceLevel(atX: 1, near: 3) == 2)
        // Out-of-range column.
        #expect(terrain.surfaceLevel(atX: 8, near: 0) == nil)
    }

    @Test func rejectsMalformedPayloads() {
        #expect(throws: LndFile.Error.truncated) {
            _ = try LndFile.read([4, 0, 0])
        }
        #expect(throws: LndFile.Error.truncated) {
            _ = try LndFile.read([4, 0, 0, 0, 4, 0, 0, 0, 1, 2])  // body too short
        }
        #expect(throws: LndFile.Error.invalidDimensions(width: 0, height: 4)) {
            _ = try LndFile.read([0, 0, 0, 0, 4, 0, 0, 0])
        }
    }
}
