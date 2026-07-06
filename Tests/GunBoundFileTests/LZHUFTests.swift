import Testing
import Foundation
@testable import GunBoundFile

@Suite
struct LZHUFTests {

    /// Fixtures in `Resources/*.lzh` were produced by compiling the original
    /// public-domain `LZHUF.C` reference source (the same algorithm static
    /// analysis confirmed the GunBound client uses) and running its `e`
    /// (encode) command against the paired `Resources/*.orig` file. Each
    /// `.lzh` fixture begins with the classic format's 4-byte little-endian
    /// decompressed-size header, which we strip here since our decoder takes
    /// the decompressed size as an explicit parameter instead.
    private func loadFixture(_ name: String) throws -> (compressed: [UInt8], original: [UInt8]) {
        let lzhURL = Bundle.module.url(forResource: name, withExtension: "lzh", subdirectory: "Resources")!
        let origURL = Bundle.module.url(forResource: name, withExtension: "orig", subdirectory: "Resources")!
        let lzhData = try [UInt8](Data(contentsOf: lzhURL))
        let origData = try [UInt8](Data(contentsOf: origURL))
        // Strip the 4-byte size header the reference CLI tool writes.
        let compressed = Array(lzhData.dropFirst(4))
        return (compressed, origData)
    }

    @Test
    func decompressText() throws {
        let (compressed, original) = try loadFixture("sample1")
        let decoded = LZHUF.decompress(compressed, decodedSize: original.count)
        #expect(decoded == original)
    }

    @Test
    func decompressRandomBinary() throws {
        let (compressed, original) = try loadFixture("sample2")
        let decoded = LZHUF.decompress(compressed, decodedSize: original.count)
        #expect(decoded == original)
    }

    @Test
    func decompressHighlyRepetitive() throws {
        let (compressed, original) = try loadFixture("sample3")
        let decoded = LZHUF.decompress(compressed, decodedSize: original.count)
        #expect(decoded == original)
    }

    @Test
    func decompressEmpty() throws {
        let decoded = LZHUF.decompress([], decodedSize: 0)
        #expect(decoded == [])
    }
}
