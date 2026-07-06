public extension FixedWidthInteger {

    func toHexadecimal() -> String {

        var string = String(self, radix: 16)
        while string.utf8.count < (MemoryLayout<Self>.size * 2) {
            string = "0" + string
        }
        return string.uppercased()
    }
}

public extension Collection where Element: FixedWidthInteger {

    func toHexadecimal() -> String {
        let length = count * MemoryLayout<Element>.size * 2
        var string = ""
        string.reserveCapacity(length)
        string = reduce(into: string) { $0 += $1.toHexadecimal() }
        assert(string.count == length)
        return string
    }
}

public extension Sequence where Element == UInt8 {

    var hexString: String {
        return "[" + reduce("", { $0 + ($0.isEmpty ? "" : ", ") + "0x" + $1.toHexadecimal().uppercased() }) + "]"
    }
}
