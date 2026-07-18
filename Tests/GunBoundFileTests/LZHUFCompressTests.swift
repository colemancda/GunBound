import Testing
import Foundation
@testable import GunBoundFile

/// Round-trip coverage for the LZHUF compressor — the encode side of the
/// classic `LZHUF.C` the client embeds (`EncodeLZHUFBlock` et al. in the
/// decomp). `decompress(compress(x), decodedSize: x.count) == x` proves the
/// encoder's LZSS matches, position codes, and adaptive-Huffman tree stay in
/// lock-step with the decoder; the reference-fixture test additionally pins
/// the exact output bytes against the original `LZHUF.C` encoder.
@Suite struct LZHUFCompressTests {

    private func loadResource(_ name: String, _ ext: String) throws -> [UInt8] {
        let url = Bundle.module.url(forResource: name, withExtension: ext, subdirectory: "Resources")!
        return try [UInt8](Data(contentsOf: url))
    }

    private func roundTrip(_ data: [UInt8], sourceLocation: SourceLocation = #_sourceLocation) {
        let compressed = LZHUF.compress(data)
        let decoded = LZHUF.decompress(compressed, decodedSize: data.count)
        #expect(decoded == data, sourceLocation: sourceLocation)
    }

    /// Byte-identical to the reference encoder: the `.lzh` fixtures were
    /// produced by the original public-domain `LZHUF.C` `e` command, so a
    /// faithful port must reproduce them exactly (minus the 4-byte size
    /// header that classic CLI writes and GunBound's containers don't).
    @Test(arguments: ["sample1", "sample2", "sample3"])
    func matchesTheReferenceEncoderByteForByte(fixture: String) throws {
        let original = try loadResource(fixture, "orig")
        let reference = Array(try loadResource(fixture, "lzh").dropFirst(4))
        #expect(LZHUF.compress(original) == reference)
    }

    @Test(arguments: ["sample1", "sample2", "sample3"])
    func roundTripsTheSampleFixtures(fixture: String) throws {
        roundTrip(try loadResource(fixture, "orig"))
    }

    /// A real `.dat` payload: decompress the shipped `characterdata.dat`,
    /// recompress it, and decompress again — the data survives, whatever
    /// the intermediate byte stream looks like.
    @Test func roundTripsRealCharacterData() throws {
        let compressed = try loadResource("characterdata", "dat")
        let decoded = DatFile.decompress(compressed, decodedSize: DatFile.characterDataDecodedSize)
        roundTrip(decoded)
    }

    /// Degenerate inputs: empty (encodes to empty, decodes to empty), a
    /// single byte, and all-identical bytes (maximal LZSS matches).
    @Test func roundTripsDegenerateInputs() {
        #expect(LZHUF.compress([]) == [])
        roundTrip([0x42])
        roundTrip([UInt8](repeating: 0xAA, count: 10_000))
    }

    /// Pseudo-random data long enough (> 0x8000 symbols) to force the
    /// adaptive-Huffman `reconst` rebuild on both sides of the round trip.
    @Test func roundTripsPastTheReconstThreshold() {
        var state: UInt32 = 0x1234_5678
        var data = [UInt8]()
        data.reserveCapacity(40_000)
        for _ in 0..<40_000 {
            state = state &* 1_103_515_245 &+ 12345
            data.append(UInt8((state >> 16) & 0xff))
        }
        roundTrip(data)
    }

    /// Structured, repetitive data spanning multiple 4096-byte windows so
    /// back-references at many distances (both position-code bands) occur.
    @Test func roundTripsRepetitiveMultiWindowData() {
        var data = [UInt8]()
        for block in 0..<20 {
            let phrase = "block \(block) of the repeating GunBound asset payload. "
            for _ in 0..<40 { data.append(contentsOf: Array(phrase.utf8)) }
        }
        roundTrip(data)
    }
}
