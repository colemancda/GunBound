import Testing
import Foundation
@testable import GunBoundFile

/// Exercises the adaptive-Huffman tree rebuild (`reconst`) that only fires
/// once a stream has decoded `MAX_FREQ` (0x8000) symbols — a path none of the
/// real `.dat`/`.lzh` fixtures are large enough to reach.
///
/// There is no LZHUF *encoder* in the package (assets ship pre-compressed), so
/// this suite carries a minimal literal-only encoder that mirrors the
/// decoder's own `StartHuff`/`update`/`reconst` tree evolution. Because both
/// sides run identical tree logic, the code words stay in lock-step; the
/// round-trip assertion (`decompress(encode(x)) == x`) is what proves the
/// mirror faithful — if it drifted from the production tree by even one
/// update, decoding would desync and the bytes wouldn't match. Feeding it
/// >0x8000 symbols drives the production decoder through `reconst`.
@Suite
struct LZHUFReconstTests {

    // Mirrors LZHUF's private constants.
    private static let N = 4096
    private static let F = 60
    private static let THRESHOLD = 2
    private static let N_CHAR = 256 - THRESHOLD + F // 314
    private static let T = N_CHAR * 2 - 1 // 627
    private static let R = T - 1 // 626
    private static let MAX_FREQ: UInt16 = 0x8000

    /// A literal-only adaptive-Huffman encoder — a faithful inverse of
    /// `LZHUF.HuffmanTree` restricted to literal symbols (0…255), which is
    /// all that's needed to produce a long stream. It never emits an LZSS
    /// match, so `decodePosition` isn't involved.
    private struct LiteralEncoder {
        typealias P = LZHUFReconstTests
        var freq = [UInt16](repeating: 0, count: P.T + 1)
        var prnt = [Int](repeating: 0, count: P.T + P.N_CHAR)
        var son = [Int](repeating: 0, count: P.T)

        // MSB-first bit sink, symmetric with LZHUF.BitReader.getBit.
        private var bytes: [UInt8] = []
        private var bitBuffer: UInt8 = 0
        private var bitCount = 0

        init() {
            for i in 0..<P.N_CHAR {
                freq[i] = 1
                son[i] = i + P.T
                prnt[i + P.T] = i
            }
            var i = 0
            var j = P.N_CHAR
            while j <= P.R {
                freq[j] = freq[i] + freq[i + 1]
                son[j] = i
                prnt[i] = j
                prnt[i + 1] = j
                i += 2
                j += 1
            }
            freq[P.T] = 0xffff
            prnt[P.R] = 0
        }

        private mutating func reconst() {
            var j = 0
            for i in 0..<P.T where son[i] >= P.T {
                freq[j] = (freq[i] + 1) / 2
                son[j] = son[i]
                j += 1
            }
            var i = 0
            var jj = P.N_CHAR
            while jj < P.T {
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
            for i in 0..<P.T {
                let k = son[i]
                prnt[k] = i
                if k < P.T { prnt[k + 1] = i }
            }
        }

        private mutating func update(_ symbol: Int) {
            if freq[P.R] == P.MAX_FREQ { reconst() }
            var c = prnt[symbol + P.T]
            repeat {
                freq[c] += 1
                let k = freq[c]
                var l = c + 1
                if k > freq[l] {
                    while k > freq[l + 1] { l += 1 }
                    freq[c] = freq[l]
                    freq[l] = k
                    let ii = son[c]
                    prnt[ii] = l
                    if ii < P.T { prnt[ii + 1] = l }
                    let jj = son[l]
                    son[l] = ii
                    prnt[jj] = c
                    if jj < P.T { prnt[jj + 1] = c }
                    son[c] = jj
                    c = l
                }
                c = prnt[c]
            } while c != 0
        }

        private mutating func putBit(_ bit: Int) {
            bitBuffer = (bitBuffer << 1) | UInt8(bit)
            bitCount += 1
            if bitCount == 8 {
                bytes.append(bitBuffer)
                bitBuffer = 0
                bitCount = 0
            }
        }

        /// Encodes one literal symbol, then evolves the tree exactly as the
        /// decoder's `decodeChar` does after it reads the same symbol.
        mutating func encode(_ symbol: Int) {
            var node = prnt[symbol + P.T]
            var bits: [Int] = []
            while node != P.R {
                let parent = prnt[node]
                bits.append(node == son[parent] ? 0 : 1)
                node = parent
            }
            for bit in bits.reversed() { putBit(bit) }
            update(symbol)
        }

        mutating func finish() -> [UInt8] {
            if bitCount > 0 {
                bitBuffer <<= UInt8(8 - bitCount)
                bytes.append(bitBuffer)
                bitBuffer = 0
                bitCount = 0
            }
            return bytes
        }
    }

    /// A stream longer than `MAX_FREQ` symbols round-trips exactly, forcing
    /// the production decoder's `reconst` rebuild at least once.
    @Test
    func decompressStreamLongEnoughToTriggerReconst() {
        // > 0x8000 (32768) literals so the decoder's freq[R] saturates and
        // reconst fires. Pseudo-random bytes (a plain LCG — deterministic,
        // no reliance on any RNG import) keep the symbol distribution wide.
        let count = 40000
        var data = [UInt8]()
        data.reserveCapacity(count)
        var state: UInt32 = 0x1234_5678
        for _ in 0..<count {
            state = state &* 1_103_515_245 &+ 12345
            data.append(UInt8((state >> 16) & 0xff))
        }

        var encoder = LiteralEncoder()
        for byte in data { encoder.encode(Int(byte)) }
        let compressed = encoder.finish()

        let decoded = LZHUF.decompress(compressed, decodedSize: data.count)
        #expect(decoded == data)
    }
}
