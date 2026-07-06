/// Errors thrown while parsing GunBound protocol values (as opposed to
/// `ParsingError`, which covers raw out-of-data/overflow failures from
/// `swift-binary-parsing`).
public enum GunBoundProtocolError: Error, Equatable, Sendable {

    /// A parsed value did not correspond to a valid instance of the expected type.
    case invalidValue
}
