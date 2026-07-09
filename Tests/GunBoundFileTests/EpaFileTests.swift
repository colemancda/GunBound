import Foundation
import Testing
@testable import GunBoundFile

@Suite struct EpaFileTests {

    /// A little-endian u32.
    private func u32(_ value: Int) -> [UInt8] {
        [UInt8(value & 0xff), UInt8((value >> 8) & 0xff), UInt8((value >> 16) & 0xff), UInt8((value >> 24) & 0xff)]
    }

    /// A two-animation table shaped like the real `tank1.epa`:
    /// `normal` (3 frames, 1 tick each) and `move` (2 frames, 2+1 ticks).
    private func makeTable() -> [UInt8] {
        var data = u32(2)
        data += u32(6) + Array("normal".utf8) + [0] + u32(3)
        data += u32(0) + u32(1) + u32(2)       // frames
        data += u32(1) + u32(1) + u32(1)       // durations
        data += u32(4) + Array("move".utf8) + [1] + u32(2)
        data += u32(20) + u32(21)
        data += u32(2) + u32(1)
        return data
    }

    @Test func parsesAnimations() throws {
        let table = try EpaFile.read(makeTable())
        #expect(table.animations.count == 2)

        let normal = try #require(table.animation(named: "normal"))
        #expect(normal.flag == 0)
        #expect(normal.frames == [0, 1, 2])
        #expect(normal.durations == [1, 1, 1])

        let move = try #require(table.animation(named: "move"))
        #expect(move.flag == 1)
        #expect(move.frames == [20, 21])
        #expect(move.durations == [2, 1])

        #expect(table.animation(named: "fire1") == nil)
    }

    @Test func rejectsMalformedPayloads() {
        #expect(throws: EpaFile.Error.truncated) {
            _ = try EpaFile.read([2, 0])  // count cut short
        }
        #expect(throws: EpaFile.Error.invalidCount(0)) {
            _ = try EpaFile.read([0, 0, 0, 0])
        }
        // A frame list that runs past the end of the data.
        var truncated = u32(1) + u32(6) + Array("normal".utf8) + [0] + u32(9)
        truncated += u32(0)
        #expect(throws: EpaFile.Error.truncated) {
            _ = try EpaFile.read(truncated)
        }
    }

    /// The real `tank1.epa` from the game archive parses end to end and
    /// names the known runs (skipped when the archive isn't on disk).
    @Test func parsesTheRealTable() throws {
        let url = URL(fileURLWithPath: NSString(string: "~/Developer/GunBound-Decomp/orig/graphics.xfs").expandingTildeInPath)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        let archive = try [UInt8](Data(contentsOf: url))
        let entries = try XFSArchive.readEntries(archive)
        let entry = try #require(entries.first { $0.name == "tank1.epa" })
        let table = try EpaFile.read(try XFSArchive.readEntryData(archive, entry: entry))

        #expect(table.animations.count == 25)
        #expect(table.animation(named: "normal")?.frames.first == 0)
        #expect(table.animation(named: "move")?.frames.first == 20)
        #expect(table.animation(named: "dead")?.frames.last == 89)
        #expect(table.animation(named: "wnormal") != nil)
    }
}
