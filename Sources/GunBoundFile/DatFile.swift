/// GunBound's `.dat` game-data files (`characterdata.dat`, `itemdata.dat`,
/// `stage.dat`, `specialdata.dat`).
///
/// **Note:** Static analysis of the original client (`LoadGameDataFiles`)
/// confirmed these files are LZHUF-compressed in full — despite being
/// loaded with plain `fopen`/`fread`, the raw bytes read from disk are the
/// *compressed* blob, not directly-parseable records. The decompressed
/// output is validated in the original client via a packet-checksum-style
/// accumulator, a mechanism this decoder does not reproduce (the exact
/// checksum inputs weren't recovered); the record layout for each file's
/// decompressed content is not documented here either — only the
/// compression container is handled.
public enum DatFile {

    /// Decompresses a `.dat` file's full contents.
    ///
    /// - Parameter decodedSize: The expected decompressed byte count. `.dat`
    ///   files carry no embedded size header — the original client passes a
    ///   constant known ahead of time for each asset type (static analysis
    ///   observed `0x14c0` used across `characterdata.dat`/`itemdata.dat`/
    ///   `stage.dat`/`specialdata.dat`).
    public static func decompress(_ data: [UInt8], decodedSize: Int) -> [UInt8] {
        LZHUF.decompress(data, decodedSize: decodedSize)
    }
}
