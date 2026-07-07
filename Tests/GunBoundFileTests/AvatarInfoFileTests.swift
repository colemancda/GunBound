import Testing
import Foundation
@testable import GunBoundFile

@Suite
struct AvatarInfoFileTests {

    /// Decodes `mb.dat` from the real bundled `avatar.xfs` sample and
    /// validates against exact known costume names/descriptions/prices.
    @Test
    func readItems() throws {
        let url = Bundle.module.url(forResource: "avatar", withExtension: "xfs", subdirectory: "Resources")!
        let data = try [UInt8](Data(contentsOf: url))
        let entries = try XFSArchive.readEntries(data)
        let entry = try #require(entries.first { $0.name == "mb.dat" })
        let decoded = try XFSArchive.readEntryData(data, entry: entry)

        let items = try AvatarInfoFile.readItems(decoded)
        #expect(items.count == 721)

        let standard = try #require(items.first)
        #expect(standard.index == 0)
        #expect(standard.name == "STANDARD")
        #expect(standard.buyable == false)
        #expect(standard.gold == 0)
        #expect(standard.cash == 0)
        #expect(standard.description == "Standard clothing")

        let spaceMarine = items[1]
        #expect(spaceMarine.name == "Space Marine")
        #expect(spaceMarine.buyable == true)
        #expect(spaceMarine.gold == 7500)
        #expect(spaceMarine.cash == 1500)
        #expect(spaceMarine.attack == 3)
        #expect(spaceMarine.defense == 3)
        #expect(spaceMarine.description == "Space marine uniform")

        let schoolUniform = items[2]
        #expect(schoolUniform.name == "School Uniform")
        #expect(schoolUniform.gold == 4000)
        #expect(schoolUniform.cash == 800)
        #expect(schoolUniform.popularity == 6)
        #expect(schoolUniform.description == "Cute and pretty school uniform")
    }
}
