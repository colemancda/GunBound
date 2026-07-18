import Foundation
import Testing
@testable import GunBound
@testable import GunBoundClient

/// Covers `AssetLibrary`'s failure paths: with no archives on disk, every
/// loader surfaces a `missingArchive`/`missingEntry` error rather than
/// crashing, and the non-throwing `localizedString` degrades to `nil`.
@Suite struct AssetLibraryTests {

    private func emptyLibrary() -> AssetLibrary {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("AssetLibraryTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return AssetLibrary(directory: dir)
    }

    @Test func loadersThrowWhenArchivesAreMissing() {
        let assets = emptyLibrary()
        #expect(throws: (any Error).self) { try assets.image(named: "x.img") }
        #expect(throws: (any Error).self) { try assets.firstImageFrame(named: "x.img") }
        #expect(throws: (any Error).self) { try assets.imageFrame(named: "x.img", at: 0) }
        #expect(throws: (any Error).self) { try assets.xtfTexture(named: "x.xtf") }
        #expect(throws: (any Error).self) { try assets.musicPath(named: "x.mp3") }
        #expect(throws: (any Error).self) { try assets.soundPath(named: "x.wav") }
        #expect(throws: (any Error).self) { try assets.stageData() }
        #expect(throws: (any Error).self) { try assets.itemData() }
        #expect(throws: (any Error).self) { try assets.terrainMask(named: "x.lnd") }
        #expect(throws: (any Error).self) { try assets.animationTable(named: "x.epa") }
        #expect(throws: (any Error).self) { try assets.avatarCatalog(named: "x") }
        #expect(throws: (any Error).self) { try assets.language() }
    }

    @Test func localizedStringReturnsNilWithoutALanguageTable() {
        let assets = emptyLibrary()
        #expect(assets.localizedString(LocalizedStringID(rawValue: 200)) == nil)
    }
}
