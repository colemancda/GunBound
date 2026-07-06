/// A minimal, Foundation-free byte buffer builder used to encode packets and
/// values, mirroring the conventions of `swift-binary-parsing`'s `ParserSpan`
/// (which only supports decoding).
public struct ByteWriter {

    public private(set) var bytes: [UInt8]

    public init() {
        self.bytes = []
    }
}

public extension ByteWriter {

    mutating func write(_ byte: UInt8) {
        bytes.append(byte)
    }

    mutating func write<C: Collection>(_ newBytes: C) where C.Element == UInt8 {
        bytes.append(contentsOf: newBytes)
    }

    mutating func write(_ value: Bool) {
        write(UInt8(value ? 1 : 0))
    }

    mutating func write<T: FixedWidthInteger>(_ value: T, endianness: Endianness = .little) {
        let stored = endianness.isBigEndian ? value.bigEndian : value.littleEndian
        withUnsafeBytes(of: stored) { write($0) }
    }

    mutating func write(_ value: Float, endianness: Endianness = .little) {
        write(value.bitPattern, endianness: endianness)
    }

    mutating func write(_ value: Double, endianness: Endianness = .little) {
        write(value.bitPattern, endianness: endianness)
    }

    /// Writes fixed-width ASCII bytes, truncating or zero-padding to `fixedLength`.
    mutating func write(ascii string: String, fixedLength: Int) {
        var stringBytes = Array(string.utf8.prefix(fixedLength))
        if stringBytes.count < fixedLength {
            stringBytes.append(contentsOf: repeatElement(0, count: fixedLength - stringBytes.count))
        }
        write(stringBytes)
    }

    /// Writes a 1-byte length prefix followed by the ASCII bytes of `string`.
    mutating func writeLengthPrefixed(ascii string: String) {
        let stringBytes = Array(string.utf8.prefix(Int(UInt8.max)))
        write(UInt8(stringBytes.count))
        write(stringBytes)
    }

    /// Writes a 1-byte count prefix, then encodes each element with `body`.
    mutating func write<C: Collection>(array elements: C, _ body: (inout ByteWriter, C.Element) -> Void) {
        precondition(elements.count <= Int(UInt8.max), "Cannot encode more than \(UInt8.max) elements")
        write(UInt8(elements.count))
        for element in elements {
            body(&self, element)
        }
    }
}
