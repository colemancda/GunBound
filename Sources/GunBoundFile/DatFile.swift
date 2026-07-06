/// GunBound's `.dat` game-data files (`characterdata.dat`, `itemdata.dat`,
/// `stage.dat`, `specialdata.dat`).
///
/// **Note:** Static analysis of the original client (`LoadGameDataFiles`)
/// confirmed these files are LZHUF-compressed in full — despite being
/// loaded with plain `fopen`/`fread`, the raw bytes read from disk are the
/// *compressed* blob, not directly-parseable records. The decompressed
/// output is validated in the original client via a packet-checksum-style
/// accumulator, a mechanism this decoder does not reproduce (the exact
/// checksum inputs weren't recovered).
///
/// **Each file has its own decompressed target size** — an earlier pass
/// incorrectly assumed all four `.dat` files shared `characterdata.dat`'s
/// size; decompiling `LoadGameDataFiles` directly corrected this for three
/// of the four files (see the constants below). `specialdata.dat`'s loader
/// wasn't located, so its target size remains unconfirmed.
public enum DatFile {

    /// Confirmed target decompressed size for `characterdata.dat`.
    public static let characterDataDecodedSize = 0x14c0 // 5,312 bytes

    /// Confirmed target decompressed size for `stage.dat`.
    public static let stageDataDecodedSize = 0x3c80 // 15,488 bytes

    /// Confirmed target decompressed size for `itemdata.dat`.
    public static let itemDataDecodedSize = 0x7850 // 30,800 bytes

    /// Decompresses a `.dat` file's full contents.
    ///
    /// - Parameter decodedSize: The expected decompressed byte count. `.dat`
    ///   files carry no embedded size header — the original client passes a
    ///   constant known ahead of time, different per file (see
    ///   `characterDataDecodedSize`/`stageDataDecodedSize`/`itemDataDecodedSize`).
    public static func decompress(_ data: [UInt8], decodedSize: Int) -> [UInt8] {
        LZHUF.decompress(data, decodedSize: decodedSize)
    }

    /// Decompresses a `.dat` file's contents from a `ParserSpan`.
    public static func decompress(parsing input: inout ParserSpan, decodedSize: Int) -> [UInt8] {
        LZHUF.decompress(parsing: &input, decodedSize: decodedSize)
    }
}
