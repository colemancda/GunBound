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
    public static let magic: [UInt8] = [0x58, 0x46, 0x53, 0x32]

    public enum Error: Swift.Error, Equatable {
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
    public static func readFooter(_ data: [UInt8]) throws(ParsingError) -> Footer {
        try data.withParserSpan { input throws(ParsingError) in
            try readFooter(parsing: &input)
        }
    }

    /// Reads the footer from a `ParserSpan` covering the whole archive file.
    public static func readFooter(parsing input: inout ParserSpan) throws(ParsingError) -> Footer {
        var footerSpan = try input.seeking(toOffsetFromEnd: 4)
        let tocOffset = try UInt32(parsingLittleEndian: &footerSpan)

        var tocSpan = try input.seeking(toAbsoluteOffset: tocOffset)
        let tocCompressedSize = try UInt32(parsingLittleEndian: &tocSpan)
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
        try data.withParserSpan { input in
            try readTableOfContents(parsing: &input, footer: footer, decodedTOCSize: decodedTOCSize)
        }
    }

    /// Decompresses the table-of-contents blob from a `ParserSpan` covering
    /// the whole archive file.
    public static func readTableOfContents(
        parsing input: inout ParserSpan,
        footer: Footer,
        decodedTOCSize: Int
    ) throws -> [UInt8] {
        var tocSpan = try input.seeking(toAbsoluteOffset: footer.tocOffset)
        _ = try UInt32(parsingLittleEndian: &tocSpan) // compressed size, already known from the footer
        var blobSpan = try tocSpan.sliceSpan(byteCount: footer.tocCompressedSize)
        let decoded = LZHUF.decompress(parsing: &blobSpan, decodedSize: decodedTOCSize)
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

    public static func readEntryBlock(_ data: [UInt8], at offset: Int) throws(ParsingError) -> EntryBlock {
        try data.withParserSpan { input throws(ParsingError) in
            var entrySpan = try input.seeking(toAbsoluteOffset: offset)
            return try readEntryBlock(parsing: &entrySpan)
        }
    }

    /// Reads an entry block from a `ParserSpan` positioned at its start.
    public static func readEntryBlock(parsing input: inout ParserSpan) throws(ParsingError) -> EntryBlock {
        let compressedSize = try UInt32(parsingLittleEndian: &input)
        let checksum = try UInt32(parsingLittleEndian: &input)
        let compressedData = try [UInt8](parsing: &input, byteCount: Int(compressedSize))
        return EntryBlock(compressedSize: compressedSize, checksum: checksum, compressedData: compressedData)
    }

    /// Decompresses an archive entry's block.
    ///
    /// - Parameter decodedSize: The entry's expected decompressed size, from
    ///   the (unconfirmed) table-of-contents record for this entry.
    public static func decompressEntry(_ block: EntryBlock, decodedSize: Int) -> [UInt8] {
        LZHUF.decompress(block.compressedData, decodedSize: decodedSize)
    }
}
