/// Guild
public struct Guild: RawRepresentable, Equatable, Hashable, CustomStringConvertible, ExpressibleByStringLiteral, Sendable {

    public let rawValue: String

    public init?(rawValue: String) {
        guard Self.validate(rawValue) else {
            return nil
        }
        self.rawValue = rawValue
    }
}

extension Guild: FixedLengthString {

    public static var length: Int { 8 }
}

#if !GUNBOUND_EMBEDDED
extension Guild: Codable {}
#endif
