/// GunBound's `.xes` sound-effect format (raw entries inside `sound.xfs`,
/// stored uncompressed — mode flag `1`, no LZHUF).
///
/// **Note:** Reconstructed from static analysis, then verified by
/// converting real entries to standard `.wav` files and confirming they're
/// valid, playable audio (matching amplitude/waveform expectations and
/// accepted by OS audio tooling). A `.xes` file is a "headerless WAV": a
/// 16-byte block with the same fields as a standard WAV `fmt ` chunk,
/// followed immediately by raw PCM samples, with no RIFF/`WAVE`/`fmt `/
/// `data` chunk wrappers. All 85 `.xes` files in the reference archive use
/// the identical format (PCM, 2 channels, 22050 Hz, 16-bit).
///
/// `sound.xfs` also holds 11 `.mp3` music tracks, stored byte-for-byte as
/// standard MPEG audio with no wrapping needed — read those directly via
/// `XFSArchive.readEntryData(_:entry:)`, no dedicated type required.
public enum XesFile {

    /// The 16-byte header, matching a standard WAV `fmt ` chunk's fields.
    public struct Header: Equatable, Sendable {
        /// `1` = PCM (the only value observed; any other value means the
        /// data isn't PCM and `wav(from:)` will refuse to wrap it).
        public let audioFormat: UInt16
        public let numChannels: UInt16
        public let sampleRate: UInt32
        public let byteRate: UInt32
        public let blockAlign: UInt16
        public let bitsPerSample: UInt16
    }

    public enum Error: Swift.Error, Equatable {
        case unsupportedAudioFormat(UInt16)
    }

    public static func readHeader(_ data: [UInt8]) throws -> Header {
        try data.withParserSpan { input in
            try readHeader(parsing: &input)
        }
    }

    public static func readHeader(parsing input: inout ParserSpan) throws -> Header {
        let audioFormat = try UInt16(parsingLittleEndian: &input)
        let numChannels = try UInt16(parsingLittleEndian: &input)
        let sampleRate = try UInt32(parsingLittleEndian: &input)
        let byteRate = try UInt32(parsingLittleEndian: &input)
        let blockAlign = try UInt16(parsingLittleEndian: &input)
        let bitsPerSample = try UInt16(parsingLittleEndian: &input)
        return Header(
            audioFormat: audioFormat,
            numChannels: numChannels,
            sampleRate: sampleRate,
            byteRate: byteRate,
            blockAlign: blockAlign,
            bitsPerSample: bitsPerSample
        )
    }

    /// The raw PCM sample bytes following the 16-byte header.
    public static func pcmData(_ data: [UInt8]) throws -> [UInt8] {
        try data.withParserSpan { input in
            _ = try readHeader(parsing: &input)
            return [UInt8](parsingRemainingBytes: &input)
        }
    }

    /// Wraps a `.xes` entry's bytes into a standard RIFF/WAVE file byte
    /// array (a `.xes` file is exactly a `fmt ` chunk's fields followed by
    /// raw PCM, so this is just adding the `RIFF`/`WAVE`/`fmt `/`data`
    /// chunk wrappers around the existing bytes — no audio data is
    /// transcoded).
    public static func wav(from data: [UInt8]) throws -> [UInt8] {
        let header = try readHeader(data)
        guard header.audioFormat == 1 else {
            throw Error.unsupportedAudioFormat(header.audioFormat)
        }
        let pcm = try pcmData(data)

        var output = [UInt8]()
        output.reserveCapacity(44 + pcm.count)

        func appendASCII(_ string: String) {
            output.append(contentsOf: string.utf8)
        }
        func appendUInt32LE(_ value: UInt32) {
            output.append(UInt8(value & 0xff))
            output.append(UInt8((value >> 8) & 0xff))
            output.append(UInt8((value >> 16) & 0xff))
            output.append(UInt8((value >> 24) & 0xff))
        }
        func appendUInt16LE(_ value: UInt16) {
            output.append(UInt8(value & 0xff))
            output.append(UInt8((value >> 8) & 0xff))
        }

        let dataChunkSize = UInt32(pcm.count)
        let riffChunkSize = 4 + (8 + 16) + (8 + dataChunkSize) // "WAVE" + fmt chunk + data chunk

        appendASCII("RIFF")
        appendUInt32LE(riffChunkSize)
        appendASCII("WAVE")

        appendASCII("fmt ")
        appendUInt32LE(16)
        appendUInt16LE(header.audioFormat)
        appendUInt16LE(header.numChannels)
        appendUInt32LE(header.sampleRate)
        appendUInt32LE(header.byteRate)
        appendUInt16LE(header.blockAlign)
        appendUInt16LE(header.bitsPerSample)

        appendASCII("data")
        appendUInt32LE(dataChunkSize)
        output.append(contentsOf: pcm)

        return output
    }
}
