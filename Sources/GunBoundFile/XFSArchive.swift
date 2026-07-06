/// The GunBound `.xfs` archive container format (`graphics.xfs`, `sound.xfs`,
/// `Avatar.xfs`).
///
/// **Note:** Reconstructed from static analysis of the original client
/// (`OpenXFSArchive`, `FindXFSEntry`, `ReadXFSEntry`/`ReadXFSEntryByte`,
/// and the entry-insert function `FUN_004f1220`). The container framing
/// (footer, magic, chunked LZHUF-compressed table of contents, 128-byte
/// entry records with all four trailing fields identified) is fully
/// confirmed. The client also contains an archive-writer/insert code path
/// (building the same TOC structure from scratch), so the format isn't
/// strictly read-only/build-time-only — that path isn't implemented here
/// since this library only needs to read existing archives.
public enum XFSArchive {

    /// The container's magic bytes, `"XFS2"`, read from the front of the
    /// decompressed table-of-contents blob.
    public static let magic: [UInt8] = [0x58, 0x46, 0x53, 0x32]

    /// Decompressed size of the table-of-contents header block (magic +
    /// entry count), passed as the LZHUF decode-size parameter (`0x40`,
    /// per static analysis of `OpenXFSArchive`).
    public static let tocHeaderDecodedSize = 0x40

    /// Decompressed size of each table-of-contents entry chunk: exactly
    /// `entriesPerChunk * entryRecordSize` (1024 * 128), per static
    /// analysis of `OpenXFSArchive`'s TOC-loading loop.
    public static let tocChunkDecodedSize = entriesPerChunk * entryRecordSize

    /// Entries are grouped into fixed-size chunks; `entryIndex >> 10`
    /// selects the chunk, `entryIndex & 0x3ff` the entry within it.
    static let entriesPerChunk = 1024

    /// Every table-of-contents entry record is exactly this many bytes.
    static let entryRecordSize = 128

    /// Byte budget for an entry's NUL-terminated filename before the four
    /// trailing `uint32_t` fields (mode flag, file offset, decompressed
    /// size, compressed size).
    static let entryNameFieldSize = 0x70

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
    ///   the table-of-contents record for this entry.
    public static func decompressEntry(_ block: EntryBlock, decodedSize: Int) -> [UInt8] {
        LZHUF.decompress(block.compressedData, decodedSize: decodedSize)
    }

    /// A single table-of-contents entry: one named asset stored in the
    /// archive.
    public struct Entry: Equatable {
        public let name: String
        /// `true` if the entry's bytes are LZHUF-compressed (the
        /// `EntryBlock` format); `false` if stored raw/uncompressed.
        public let isCompressed: Bool
        /// If `isCompressed`, the file offset of the entry's `EntryBlock`
        /// header. Otherwise, the raw file offset of the entry's bytes.
        public let fileOffset: UInt32
        public let decompressedSize: UInt32
        /// On-disk footprint of the entry's compressed data (the
        /// `EntryBlock`'s `compressedData` size). Only meaningful when
        /// `isCompressed`; raw entries redundantly report the same value
        /// as `decompressedSize` here.
        public let compressedSize: UInt32
    }

    /// Enumerates every entry in the archive's table of contents.
    ///
    /// Walks the chunked TOC (a header block giving the total entry count,
    /// followed by one LZHUF-compressed 128 KB chunk per 1024 entries),
    /// per static analysis of `OpenXFSArchive`'s TOC-loading loop.
    public static func readEntries(_ data: [UInt8]) throws -> [Entry] {
        try data.withParserSpan { input in
            try readEntries(parsing: &input)
        }
    }

    /// Enumerates every entry from a `ParserSpan` covering the whole
    /// archive file.
    public static func readEntries(parsing input: inout ParserSpan) throws -> [Entry] {
        let footer = try readFooter(parsing: &input)
        var tocSpan = try input.seeking(toAbsoluteOffset: footer.tocOffset)
        _ = try UInt32(parsingLittleEndian: &tocSpan) // header compressed size, already known from the footer
        var headerBlobSpan = try tocSpan.sliceSpan(byteCount: footer.tocCompressedSize)
        let header = LZHUF.decompress(parsing: &headerBlobSpan, decodedSize: tocHeaderDecodedSize)
        guard header.count >= magic.count + 4, Array(header.prefix(magic.count)) == magic else {
            throw Error.invalidMagic
        }
        let entryCount = try header.withParserSpan { (headerInput: inout ParserSpan) -> Int in
            _ = try [UInt8](parsing: &headerInput, byteCount: magic.count)
            return Int(try UInt32(parsingLittleEndian: &headerInput))
        }

        // `tocSpan` was shrunk by `sliceSpan` above, so it's now positioned
        // right after the header blob — where the entry chunks begin.
        var entries: [Entry] = []
        entries.reserveCapacity(entryCount)
        var remaining = entryCount
        while remaining > 0 {
            let chunkCompressedSize = try UInt32(parsingLittleEndian: &tocSpan)
            var chunkBlobSpan = try tocSpan.sliceSpan(byteCount: chunkCompressedSize)
            let chunkBytes = LZHUF.decompress(parsing: &chunkBlobSpan, decodedSize: tocChunkDecodedSize)
            let entriesInChunk = min(remaining, entriesPerChunk)
            for i in 0..<entriesInChunk {
                let recordStart = i * entryRecordSize
                let record = Array(chunkBytes[recordStart..<recordStart + entryRecordSize])
                entries.append(try parseEntryRecord(record))
            }
            remaining -= entriesInChunk
        }
        return entries
    }

    static func parseEntryRecord(_ record: [UInt8]) throws -> Entry {
        try record.withParserSpan { input in
            var nameSpan = try input.sliceSpan(byteCount: entryNameFieldSize)
            let nameBytes = [UInt8](parsingRemainingBytes: &nameSpan)
            let nulIndex = nameBytes.firstIndex(of: 0) ?? nameBytes.count
            let name = String(decoding: nameBytes[0..<nulIndex], as: UTF8.self)
            let modeFlag = try UInt32(parsingLittleEndian: &input)
            let fileOffset = try UInt32(parsingLittleEndian: &input)
            let decompressedSize = try UInt32(parsingLittleEndian: &input)
            let compressedSize = try UInt32(parsingLittleEndian: &input)
            return Entry(
                name: name,
                isCompressed: modeFlag != 1,
                fileOffset: fileOffset,
                decompressedSize: decompressedSize,
                compressedSize: compressedSize
            )
        }
    }

    /// Reads and decompresses (if needed) a single entry's data.
    public static func readEntryData(_ data: [UInt8], entry: Entry) throws -> [UInt8] {
        try data.withParserSpan { input in
            try readEntryData(parsing: &input, entry: entry)
        }
    }

    /// Reads and decompresses (if needed) a single entry's data from a
    /// `ParserSpan` covering the whole archive file.
    public static func readEntryData(parsing input: inout ParserSpan, entry: Entry) throws -> [UInt8] {
        if entry.isCompressed {
            var entrySpan = try input.seeking(toAbsoluteOffset: entry.fileOffset)
            let block = try readEntryBlock(parsing: &entrySpan)
            return decompressEntry(block, decodedSize: Int(entry.decompressedSize))
        } else {
            var entrySpan = try input.seeking(toAbsoluteOffset: entry.fileOffset)
            return try [UInt8](parsing: &entrySpan, byteCount: Int(entry.decompressedSize))
        }
    }
}
