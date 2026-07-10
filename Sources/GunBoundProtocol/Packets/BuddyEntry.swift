/// One roster entry in a buddy-list response: a friend's username and
/// whether they're currently online (connected to this server).
///
/// **Note:** the decomp confirms a buddy/friend feature exists (the
/// `b_gamelist_friend` "Find Friend" button, `0xe`, triggering opcode
/// `0x2101` — see PROTOCOL.md), but its exact record layout isn't pinned
/// down: `FindBuddyRoomsForServer`'s filtering parameter is passed through
/// an uncaptured register, and the 12-byte record's field meanings are
/// unconfirmed. This project's buddy list is a documented divergence — a
/// straightforward add/remove/list roster with online status, not the
/// decomp's room-locate flow.
public struct BuddyEntry: Equatable, Hashable, Sendable {

    public let username: Username

    public let isOnline: Bool

    public init(username: Username, isOnline: Bool) {
        self.username = username
        self.isOnline = isOnline
    }

    public init(parsing input: inout ParserSpan) throws {
        self.username = try Username(parsing: &input)
        self.isOnline = try UInt8(parsing: &input) != 0
    }

    public func encode(to output: inout ByteWriter) {
        username.encode(to: &output)
        output.write(isOnline)
    }
}
