import Testing
import Foundation
@testable import GunBoundFile

@Suite
struct DatFileTests {

    private func loadResource(_ name: String, _ ext: String) throws -> [UInt8] {
        let url = Bundle.module.url(forResource: name, withExtension: ext, subdirectory: "Resources")!
        return try [UInt8](Data(contentsOf: url))
    }

    /// `0x14c0` (5312) is the decompressed size static analysis of the
    /// original client observed being passed to the LZHUF decoder for all
    /// four `.dat` files (see `DatFile`'s doc comment). Decompressing the
    /// real sample files at this size produces a clear repeating
    /// fixed-stride record pattern (small little-endian integers separated
    /// by zero padding, repeated at regular offsets) rather than noise,
    /// which corroborates both the LZHUF port and this size constant.
    @Test(arguments: ["characterdata", "itemdata", "stage", "specialdata"])
    func decompressSampleFile(_ name: String) throws {
        let compressed = try loadResource(name, "dat")
        let decoded = DatFile.decompress(compressed, decodedSize: 0x14c0)
        #expect(decoded.count == 0x14c0)
    }
}
