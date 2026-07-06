import Testing
import Foundation
@testable import GunBoundFile

@Suite
struct XesFileTests {

    /// `10move.xes` is a real entry extracted from `sound.xfs` (via
    /// `XFSArchive`, stored raw/mode-flag-1 per the confirmed format) and
    /// saved here rather than bundling the full 18.6 MB archive.
    private func loadFixture() throws -> [UInt8] {
        let url = Bundle.module.url(forResource: "10move", withExtension: "xes", subdirectory: "Resources")!
        return try [UInt8](Data(contentsOf: url))
    }

    @Test
    func readHeader() throws {
        let data = try loadFixture()
        let header = try XesFile.readHeader(data)
        #expect(header.audioFormat == 1)
        #expect(header.numChannels == 2)
        #expect(header.sampleRate == 22050)
        #expect(header.byteRate == 88200)
        #expect(header.blockAlign == 4)
        #expect(header.bitsPerSample == 16)
    }

    @Test
    func pcmDataExcludesHeader() throws {
        let data = try loadFixture()
        let pcm = try XesFile.pcmData(data)
        #expect(pcm.count == data.count - 16)
    }

    /// Validates the wrapped RIFF/WAVE output has the correct chunk
    /// structure and byte counts. (End-to-end playability was verified
    /// manually against a real archive entry using the OS's `afinfo`
    /// tool, confirming a valid 2-channel/22050 Hz/Int16 WAVE stream.)
    @Test
    func wavWrapping() throws {
        let data = try loadFixture()
        let wav = try XesFile.wav(from: data)

        #expect(Array(wav[0..<4]) == Array("RIFF".utf8))
        #expect(Array(wav[8..<12]) == Array("WAVE".utf8))
        #expect(Array(wav[12..<16]) == Array("fmt ".utf8))
        #expect(Array(wav[36..<40]) == Array("data".utf8))

        let pcm = try XesFile.pcmData(data)
        let dataChunkSize = UInt32(wav[40]) | (UInt32(wav[41]) << 8) | (UInt32(wav[42]) << 16) | (UInt32(wav[43]) << 24)
        #expect(Int(dataChunkSize) == pcm.count)
        #expect(wav.count == 44 + pcm.count)
        #expect(Array(wav[44...]) == pcm)
    }

    @Test
    func rejectsNonPCMFormat() {
        var bytes = [UInt8](repeating: 0, count: 16)
        bytes[0] = 2 // audioFormat = 2 (not PCM)
        #expect(throws: XesFile.Error.self) {
            _ = try XesFile.wav(from: bytes)
        }
    }
}
