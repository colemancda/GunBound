public extension String {

    /// Parses a 1-byte length-prefixed ASCII/UTF-8 string.
    init(parsingLengthPrefixedASCII input: inout ParserSpan) throws(ParsingError) {
        let length = try Int(UInt8(parsing: &input))
        try self.init(parsingUTF8: &input, count: length)
    }

    /// Parses a fixed-length, zero-padded ASCII/UTF-8 string, stripping trailing
    /// NUL padding.
    init(parsingFixedLengthASCII input: inout ParserSpan, length: Int) throws(ParsingError) {
        let stringBytes = try [UInt8](parsing: &input, byteCount: length)
        let trimmed = stringBytes.suffix(while: { $0 == 0 })
        self = String(decoding: stringBytes.prefix(stringBytes.count - trimmed.count), as: UTF8.self)
    }
}

private extension Array where Element == UInt8 {

    /// Trailing elements equal to `predicate`, mirroring the old
    /// `FixedLengthString.removePadding` behavior of trimming trailing zero bytes.
    func suffix(while predicate: (Element) -> Bool) -> [Element] {
        var count = 0
        for byte in self.reversed() {
            guard predicate(byte) else { break }
            count += 1
        }
        return Array(suffix(count))
    }
}
