/// The GunBound `.xfs` archive container format (`graphics.xfs`, `sound.xfs`,
/// `Avatar.xfs`).
///
/// **Note:** Reconstructed from static analysis of the original client
/// (`OpenXFSArchive`), not a live parse of a real archive's internal table
/// of contents — the confirmed part is the container framing (footer,
/// magic, LZHUF-compressed blob); the table of contents' internal
/// filename/offset record layout was not recovered by that analysis, so
/// named-entry lookup isn't implemented here.
public enum XFSArchive {

    /// The container's magic bytes, `"XFS2"`, read from the front of the
    /// decompressed table-of-contents blob.
    public static let magic: [UInt8] = Array("XFS2".utf8)

    public enum Error: Swift.Error, Equatable {
        case fileTooSmall
        case invalidTOCOffset
        case invalidMagic
    }

    /// The on-disk footer: a 4-byte offset (from the start of the file) to
    /// the table-of-contents blob, followed at that offset by a 4-byte
    /// compressed size and then the LZHUF-compressed TOC bytes.
    public struct Footer: Equatable {
        public let tocOffset: UInt32
        public let tocCompressedSize: UInt32
    }

    /// Reads the footer (TOC offset + compressed size) from the end of an
    /// archive file's raw bytes.
    public static func readFooter(_ data: [UInt8]) throws -> Footer {
        guard data.count >= 4 else { throw Error.fileTooSmall }
        let tocOffset = UInt32(data[data.count - 4])
            | (UInt32(data[data.count - 3]) << 8)
            | (UInt32(data[data.count - 2]) << 16)
            | (UInt32(data[data.count - 1]) << 24)
        guard tocOffset >= 4, Int(tocOffset) + 4 <= data.count else {
            throw Error.invalidTOCOffset
        }
        let sizeOffset = Int(tocOffset)
        let tocCompressedSize = UInt32(data[sizeOffset])
            | (UInt32(data[sizeOffset + 1]) << 8)
            | (UInt32(data[sizeOffset + 2]) << 16)
            | (UInt32(data[sizeOffset + 3]) << 24)
        return Footer(tocOffset: tocOffset, tocCompressedSize: tocCompressedSize)
    }

    /// Decompresses the table-of-contents blob and validates its `"XFS2"`
    /// magic, returning the decompressed TOC bytes.
    ///
    /// - Parameter decodedTOCSize: The expected decompressed size of the TOC
    ///   blob. Not recoverable from the archive itself (see the type-level
    ///   note); must be supplied by the caller.
    public static func readTableOfContents(
        _ data: [UInt8],
        footer: Footer,
        decodedTOCSize: Int
    ) throws -> [UInt8] {
        let start = Int(footer.tocOffset) + 4
        let end = start + Int(footer.tocCompressedSize)
        guard end <= data.count else { throw Error.fileTooSmall }
        let compressed = Array(data[start..<end])
        let decoded = LZHUF.decompress(compressed, decodedSize: decodedTOCSize)
        guard decoded.count >= magic.count, Array(decoded.prefix(magic.count)) == magic else {
            throw Error.invalidMagic
        }
        return decoded
    }

    /// The on-disk shape of a single archive entry's compressed block, found
    /// at the file offset recorded for that entry in the table of contents.
    ///
    /// ```
    /// struct XFSEntryBlock {
    ///     uint32_t compressedSize;
    ///     uint32_t checksum;       // not validated here; convention unconfirmed
    ///     uint8_t  compressedData[compressedSize];
    /// };
    /// ```
    public struct EntryBlock: Equatable {
        public let compressedSize: UInt32
        public let checksum: UInt32
        public let compressedData: [UInt8]
    }

    public static func readEntryBlock(_ data: [UInt8], at offset: Int) throws -> EntryBlock {
        guard offset + 8 <= data.count else { throw Error.fileTooSmall }
        let compressedSize = UInt32(data[offset])
            | (UInt32(data[offset + 1]) << 8)
            | (UInt32(data[offset + 2]) << 16)
            | (UInt32(data[offset + 3]) << 24)
        let checksum = UInt32(data[offset + 4])
            | (UInt32(data[offset + 5]) << 8)
            | (UInt32(data[offset + 6]) << 16)
            | (UInt32(data[offset + 7]) << 24)
        let dataStart = offset + 8
        let dataEnd = dataStart + Int(compressedSize)
        guard dataEnd <= data.count else { throw Error.fileTooSmall }
        return EntryBlock(
            compressedSize: compressedSize,
            checksum: checksum,
            compressedData: Array(data[dataStart..<dataEnd])
        )
    }

    /// Decompresses an archive entry's block.
    ///
    /// - Parameter decodedSize: The entry's expected decompressed size, from
    ///   the (unconfirmed) table-of-contents record for this entry.
    public static func decompressEntry(_ block: EntryBlock, decodedSize: Int) -> [UInt8] {
        LZHUF.decompress(block.compressedData, decodedSize: decodedSize)
    }
}
