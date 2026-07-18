/// LZHUF codec (decompressor + compressor).
///
/// GunBound's asset containers (`.xfs` archives and `.dat` data files) are
/// compressed with a codec that static analysis of the original client
/// confirmed, function-by-function, to be a near-verbatim implementation of
/// the classic public-domain `LZHUF.C` (Okumura/Yoshizaki, 1988-1991) — the
/// same lineage used by LHA `.lzh` archives. Both sides are direct ports of
/// that reference algorithm (LZSS sliding-window matches + adaptive Huffman
/// coding): the decoder is verified byte-for-byte against fixtures produced
/// by compiling the original reference `LZHUF.C` source, and the encoder
/// mirrors the client's own embedded compressor, whose functions static
/// analysis identified as the reference's encode side (`EncodeLZHUFBlock`
/// 0x4ea760, `LZHUFPutCode` 0x4ea230, `LZHUFDeleteNode` 0x4ea010,
/// `LZHUFUpdate` 0x4ea580 — used by its XFS write-back path).
///
/// **Note:** The original client's call sites pass a size value alongside
/// the compressed bytes (`0x40` for the XFS table of contents, `0x14c0` for
/// `.dat` files, `0x1000` for individual XFS archive entries). Static
/// analysis did not conclusively determine whether this is the decompressed
/// output size or something else; this decoder treats it as the
/// decompressed size, which is consistent with the classic algorithm
/// (which has no other way to know when to stop emitting output) and with
/// the observed compression ratios of the sample `.dat` files in this repo.
public enum LZHUF {

    private static let N = 4096 // ring buffer size
    private static let F = 60 // lookahead buffer size
    private static let THRESHOLD = 2
    private static let N_CHAR = 256 - THRESHOLD + F // 314
    private static let T = N_CHAR * 2 - 1 // 627, size of Huffman tree table
    private static let R = T - 1 // 626, position of the tree root
    private static let MAX_FREQ: UInt16 = 0x8000

    // Table for encoding/decoding the upper 6 bits of the LZSS back-reference position.
    private static let dCode: [UInt8] = [
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01,
        0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01,
        0x02, 0x02, 0x02, 0x02, 0x02, 0x02, 0x02, 0x02,
        0x02, 0x02, 0x02, 0x02, 0x02, 0x02, 0x02, 0x02,
        0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03,
        0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03,
        0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04,
        0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05,
        0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06,
        0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07,
        0x08, 0x08, 0x08, 0x08, 0x08, 0x08, 0x08, 0x08,
        0x09, 0x09, 0x09, 0x09, 0x09, 0x09, 0x09, 0x09,
        0x0A, 0x0A, 0x0A, 0x0A, 0x0A, 0x0A, 0x0A, 0x0A,
        0x0B, 0x0B, 0x0B, 0x0B, 0x0B, 0x0B, 0x0B, 0x0B,
        0x0C, 0x0C, 0x0C, 0x0C, 0x0D, 0x0D, 0x0D, 0x0D,
        0x0E, 0x0E, 0x0E, 0x0E, 0x0F, 0x0F, 0x0F, 0x0F,
        0x10, 0x10, 0x10, 0x10, 0x11, 0x11, 0x11, 0x11,
        0x12, 0x12, 0x12, 0x12, 0x13, 0x13, 0x13, 0x13,
        0x14, 0x14, 0x14, 0x14, 0x15, 0x15, 0x15, 0x15,
        0x16, 0x16, 0x16, 0x16, 0x17, 0x17, 0x17, 0x17,
        0x18, 0x18, 0x19, 0x19, 0x1A, 0x1A, 0x1B, 0x1B,
        0x1C, 0x1C, 0x1D, 0x1D, 0x1E, 0x1E, 0x1F, 0x1F,
        0x20, 0x20, 0x21, 0x21, 0x22, 0x22, 0x23, 0x23,
        0x24, 0x24, 0x25, 0x25, 0x26, 0x26, 0x27, 0x27,
        0x28, 0x28, 0x29, 0x29, 0x2A, 0x2A, 0x2B, 0x2B,
        0x2C, 0x2C, 0x2D, 0x2D, 0x2E, 0x2E, 0x2F, 0x2F,
        0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37,
        0x38, 0x39, 0x3A, 0x3B, 0x3C, 0x3D, 0x3E, 0x3F,
    ]

    private static let dLen: [UInt8] = [
        0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03,
        0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03,
        0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03,
        0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03,
        0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04,
        0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04,
        0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04,
        0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04,
        0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04,
        0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04,
        0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05,
        0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05,
        0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05,
        0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05,
        0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05,
        0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05,
        0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05,
        0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05,
        0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06,
        0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06,
        0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06,
        0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06,
        0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06,
        0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06,
        0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07,
        0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07,
        0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07,
        0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07,
        0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07,
        0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07,
        0x08, 0x08, 0x08, 0x08, 0x08, 0x08, 0x08, 0x08,
        0x08, 0x08, 0x08, 0x08, 0x08, 0x08, 0x08, 0x08,
    ]

    private struct BitReader {
        let input: [UInt8]
        var position = 0
        var getBuf: UInt16 = 0
        var getLen: UInt8 = 0

        init(_ input: [UInt8]) {
            self.input = input
        }

        private mutating func nextInputByte() -> UInt16 {
            guard position < input.count else { return 0 }
            defer { position += 1 }
            return UInt16(input[position])
        }

        mutating func getBit() -> Int {
            while getLen <= 8 {
                getBuf |= nextInputByte() << (8 - getLen)
                getLen += 8
            }
            let i = getBuf
            getBuf <<= 1
            getLen -= 1
            return (i & 0x8000) != 0 ? 1 : 0
        }

        mutating func getByte() -> UInt8 {
            while getLen <= 8 {
                getBuf |= nextInputByte() << (8 - getLen)
                getLen += 8
            }
            let i = getBuf
            getBuf <<= 8
            getLen -= 8
            return UInt8(i >> 8)
        }
    }

    /// Adaptive Huffman tree state, ported from `StartHuff`/`reconst`/`update`.
    private struct HuffmanTree {
        var freq = [UInt16](repeating: 0, count: T + 1)
        var prnt = [Int](repeating: 0, count: T + N_CHAR)
        var son = [Int](repeating: 0, count: T)

        init() {
            for i in 0..<N_CHAR {
                freq[i] = 1
                son[i] = i + T
                prnt[i + T] = i
            }
            var i = 0
            var j = N_CHAR
            while j <= R {
                freq[j] = freq[i] + freq[i + 1]
                son[j] = i
                prnt[i] = j
                prnt[i + 1] = j
                i += 2
                j += 1
            }
            freq[T] = 0xffff
            prnt[R] = 0
        }

        mutating func reconst() {
            var j = 0
            for i in 0..<T {
                if son[i] >= T {
                    freq[j] = (freq[i] + 1) / 2
                    son[j] = son[i]
                    j += 1
                }
            }
            var i = 0
            var jj = N_CHAR
            while jj < T {
                let k = i + 1
                let f = freq[i] + freq[k]
                freq[jj] = f
                var kk = jj - 1
                while f < freq[kk] { kk -= 1 }
                kk += 1
                let l = (jj - kk) * 2
                if l > 0 {
                    for idx in stride(from: jj - 1, through: kk, by: -1) {
                        freq[idx + 1] = freq[idx]
                        son[idx + 1] = son[idx]
                    }
                }
                freq[kk] = f
                son[kk] = i
                i += 2
                jj += 1
            }
            for i in 0..<T {
                let k = son[i]
                if k >= T {
                    prnt[k] = i
                } else {
                    prnt[k] = i
                    prnt[k + 1] = i
                }
            }
        }

        mutating func update(_ symbol: Int) {
            if freq[R] == MAX_FREQ {
                reconst()
            }
            var c = prnt[symbol + T]
            repeat {
                freq[c] += 1
                let k = freq[c]
                var l = c + 1
                if k > freq[l] {
                    while k > freq[l + 1] { l += 1 }
                    freq[c] = freq[l]
                    freq[l] = k

                    let i = son[c]
                    prnt[i] = l
                    if i < T { prnt[i + 1] = l }

                    let j = son[l]
                    son[l] = i

                    prnt[j] = c
                    if j < T { prnt[j + 1] = c }
                    son[c] = j

                    c = l
                }
                c = prnt[c]
            } while c != 0
        }

        mutating func decodeChar(_ reader: inout BitReader) -> Int {
            var c = son[R]
            while c < T {
                c += reader.getBit()
                c = son[c]
            }
            c -= T
            update(c)
            return c
        }

        func decodePosition(_ reader: inout BitReader) -> Int {
            let i = reader.getByte()
            let c = Int(dCode[Int(i)]) << 6
            var j = Int(dLen[Int(i)])
            var iv = Int(i)
            j -= 2
            while j > 0 {
                iv = (iv << 1) + reader.getBit()
                j -= 1
            }
            return c | (iv & 0x3f)
        }

        /// Emits `symbol`'s current Huffman code (`EncodeChar` in the
        /// reference): climb from the leaf to the root collecting one bit
        /// per level — a node's right-child status is its index parity,
        /// since `StartHuff` and `update` keep sibling pairs at adjacent
        /// even/odd indices — then evolve the tree exactly as `decodeChar`
        /// does, keeping encoder and decoder trees in lock-step.
        mutating func encodeChar(_ symbol: Int, into writer: inout BitWriter) {
            var code: UInt16 = 0
            var length = 0
            var k = prnt[symbol + T]
            repeat {
                code >>= 1
                if k & 1 == 1 { code |= 0x8000 }
                length += 1
                k = prnt[k]
            } while k != R
            writer.putCode(length, code)
            update(symbol)
        }
    }

    /// Decompresses an LZHUF-compressed block read from a `ParserSpan`.
    ///
    /// - Parameters:
    ///   - input: A parser span positioned at the start of the compressed
    ///     bytes. The remainder of the span is consumed.
    ///   - decodedSize: The expected decompressed byte count. The original
    ///     format has no other way to know when to stop decoding (the
    ///     Huffman-coded stream carries no end marker), so this must be
    ///     supplied by the caller (from container metadata or a known
    ///     constant for the asset type).
    /// - Returns: The decompressed bytes.
    public static func decompress(parsing input: inout ParserSpan, decodedSize: Int) -> [UInt8] {
        let bytes = [UInt8](parsingRemainingBytes: &input)
        return decompress(bytes, decodedSize: decodedSize)
    }

    /// Decompresses an LZHUF-compressed block.
    ///
    /// - Parameters:
    ///   - input: The compressed bytes.
    ///   - decodedSize: The expected decompressed byte count. The original
    ///     format has no other way to know when to stop decoding (the
    ///     Huffman-coded stream carries no end marker), so this must be
    ///     supplied by the caller (from container metadata or a known
    ///     constant for the asset type).
    /// - Returns: The decompressed bytes.
    public static func decompress(_ input: [UInt8], decodedSize: Int) -> [UInt8] {
        guard decodedSize > 0 else { return [] }
        var reader = BitReader(input)
        var tree = HuffmanTree()
        var textBuffer = [UInt8](repeating: 0x20, count: N + F - 1)
        var r = N - F
        var output = [UInt8]()
        output.reserveCapacity(decodedSize)
        while output.count < decodedSize {
            let c = tree.decodeChar(&reader)
            if c < 256 {
                output.append(UInt8(c))
                textBuffer[r] = UInt8(c)
                r = (r + 1) & (N - 1)
            } else {
                let position = tree.decodePosition(&reader)
                let i = (r - position - 1) & (N - 1)
                let length = c - 255 + THRESHOLD
                var k = 0
                while k < length && output.count < decodedSize {
                    let byte = textBuffer[(i + k) & (N - 1)]
                    output.append(byte)
                    textBuffer[r] = byte
                    r = (r + 1) & (N - 1)
                    k += 1
                }
            }
        }
        return output
    }

    // MARK: - Compression

    /// MSB-first bit sink, the reference's `Putcode`/`putbuf` (the client's
    /// `LZHUFPutCode`, 0x4ea230) — the exact mirror of `BitReader`.
    struct BitWriter {
        private(set) var bytes: [UInt8] = []
        private var putBuf: UInt16 = 0
        private var putLen = 0

        mutating func putCode(_ length: Int, _ code: UInt16) {
            putBuf |= code >> putLen
            putLen += length
            if putLen >= 8 {
                bytes.append(UInt8(putBuf >> 8))
                putLen -= 8
                if putLen >= 8 {
                    bytes.append(UInt8(truncatingIfNeeded: putBuf))
                    putLen -= 8
                    putBuf = code << (length - putLen)
                } else {
                    putBuf <<= 8
                }
            }
        }

        /// `EncodeEnd` — flushes the partial trailing byte.
        mutating func flush() {
            if putLen > 0 {
                bytes.append(UInt8(putBuf >> 8))
                putBuf = 0
                putLen = 0
            }
        }
    }

    /// The encoder-side position tables (`p_len`/`p_code`), derived from the
    /// decoder's `dLen`/`dCode` rather than transcribed: for each upper-6-bit
    /// value, the code prefix is the first decode-table index mapping to it
    /// and the bit length is that index's `dLen` — provably the inverse of
    /// `decodePosition`, so the pair can't drift apart.
    private static let pTables: (len: [UInt8], code: [UInt8]) = {
        var len = [UInt8](repeating: 0, count: 64)
        var code = [UInt8](repeating: 0, count: 64)
        var index = 0
        for upper in 0..<64 {
            while Int(dCode[index]) != upper { index += 1 }
            len[upper] = dLen[index]
            code[upper] = UInt8(index)
        }
        return (len, code)
    }()

    /// `EncodePosition`: the upper 6 bits of an LZSS back-reference go out
    /// as their variable-length prefix code, the lower 6 raw.
    private static func encodePosition(_ position: Int, into writer: inout BitWriter) {
        let upper = position >> 6
        writer.putCode(Int(pTables.len[upper]), UInt16(pTables.code[upper]) << 8)
        writer.putCode(6, UInt16(position & 0x3f) << 10)
    }

    /// Compresses a block — the encode side of the same classic `LZHUF.C`
    /// the client embeds (its copy is `EncodeLZHUFBlock`, 0x4ea760, with
    /// `LZHUFPutCode`/`LZHUFDeleteNode`/`LZHUFUpdate` as the reference's
    /// `Putcode`/`DeleteNode`/`update`): greedy LZSS matching over a
    /// 4096-byte ring via a per-first-byte binary search tree, each literal
    /// or (length, position) pair adaptive-Huffman coded with the identical
    /// tree `decompress` evolves.
    ///
    /// The output carries no size header (matching every GunBound container,
    /// which store the decoded size out of band) — decompress with
    /// `decompress(_:decodedSize: input.count)`.
    public static func compress(_ input: [UInt8]) -> [UInt8] {
        guard !input.isEmpty else { return [] }
        let nilNode = N  // the reference's NIL tree sentinel

        var writer = BitWriter()
        var tree = HuffmanTree()
        var textBuf = [UInt8](repeating: 0x20, count: N + F - 1)
        // LZSS binary search tree: `rson[N+1...N+256]` are the 256
        // per-first-byte roots, `dad[N]` absorbs writes through NIL links.
        var lson = [Int](repeating: nilNode, count: N + 1)
        var rson = [Int](repeating: nilNode, count: N + 257)
        var dad = [Int](repeating: nilNode, count: N + 1)
        var matchPosition = 0
        var matchLength = 0

        // `InsertNode(r)`: adds the F-byte string at `r` to the tree and
        // records the longest (position-lowest on ties) match found on the
        // way down; on a full-length match the old node is replaced.
        func insertNode(_ r: Int) {
            var cmp = 1
            var p = N + 1 + Int(textBuf[r])
            lson[r] = nilNode
            rson[r] = nilNode
            matchLength = 0
            while true {
                if cmp >= 0 {
                    if rson[p] != nilNode {
                        p = rson[p]
                    } else {
                        rson[p] = r
                        dad[r] = p
                        return
                    }
                } else {
                    if lson[p] != nilNode {
                        p = lson[p]
                    } else {
                        lson[p] = r
                        dad[r] = p
                        return
                    }
                }
                var i = 1
                while i < F {
                    cmp = Int(textBuf[r + i]) - Int(textBuf[p + i])
                    if cmp != 0 { break }
                    i += 1
                }
                if i > THRESHOLD {
                    if i > matchLength {
                        matchPosition = ((r - p) & (N - 1)) - 1
                        matchLength = i
                        if matchLength >= F { break }
                    } else if i == matchLength {
                        let candidate = ((r - p) & (N - 1)) - 1
                        if candidate < matchPosition { matchPosition = candidate }
                    }
                }
            }
            // Full-length match: `r` takes over `p`'s place in the tree.
            dad[r] = dad[p]
            lson[r] = lson[p]
            rson[r] = rson[p]
            dad[lson[p]] = r
            dad[rson[p]] = r
            if rson[dad[p]] == p {
                rson[dad[p]] = r
            } else {
                lson[dad[p]] = r
            }
            dad[p] = nilNode
        }

        // `DeleteNode(p)` (the client's `LZHUFDeleteNode`, 0x4ea010).
        func deleteNode(_ p: Int) {
            guard dad[p] != nilNode else { return }
            let q: Int
            if rson[p] == nilNode {
                q = lson[p]
            } else if lson[p] == nilNode {
                q = rson[p]
            } else {
                var candidate = lson[p]
                if rson[candidate] != nilNode {
                    repeat {
                        candidate = rson[candidate]
                    } while rson[candidate] != nilNode
                    rson[dad[candidate]] = lson[candidate]
                    dad[lson[candidate]] = dad[candidate]
                    lson[candidate] = lson[p]
                    dad[lson[p]] = candidate
                }
                rson[candidate] = rson[p]
                dad[rson[p]] = candidate
                q = candidate
            }
            dad[q] = dad[p]
            if rson[dad[p]] == p {
                rson[dad[p]] = q
            } else {
                lson[dad[p]] = q
            }
            dad[p] = nilNode
        }

        var inputIndex = 0
        var s = 0
        var r = N - F
        var len = 0
        while len < F && inputIndex < input.count {
            textBuf[r + len] = input[inputIndex]
            inputIndex += 1
            len += 1
        }
        for i in 1...F { insertNode(r - i) }
        insertNode(r)

        repeat {
            if matchLength > len { matchLength = len }
            if matchLength <= THRESHOLD {
                matchLength = 1
                tree.encodeChar(Int(textBuf[r]), into: &writer)
            } else {
                tree.encodeChar(255 - THRESHOLD + matchLength, into: &writer)
                encodePosition(matchPosition, into: &writer)
            }
            let lastMatchLength = matchLength
            var i = 0
            while i < lastMatchLength && inputIndex < input.count {
                let c = input[inputIndex]
                inputIndex += 1
                deleteNode(s)
                textBuf[s] = c
                if s < F - 1 { textBuf[s + N] = c }
                s = (s + 1) & (N - 1)
                r = (r + 1) & (N - 1)
                insertNode(r)
                i += 1
            }
            while i < lastMatchLength {
                i += 1
                deleteNode(s)
                s = (s + 1) & (N - 1)
                r = (r + 1) & (N - 1)
                len -= 1
                if len > 0 { insertNode(r) }
            }
        } while len > 0

        writer.flush()
        return writer.bytes
    }
}
