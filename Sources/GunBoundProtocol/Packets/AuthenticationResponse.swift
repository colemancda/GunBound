/// Authentication Response
///
/// Sent by the server in response to an AuthenticationRequest.
/// Contains the authentication result and user data if successful.
///
/// **Possible Status Codes:**
/// - `.success` - Authentication successful, user data included
/// - `.badUsername` - Username not found
/// - `.badPassword` - Incorrect password
/// - `.bannedUser` - User account is banned
/// - `.badVersion` - Client version mismatch
///
/// **Usage:**
/// When authentication fails, only the status is sent.
/// When successful, the UserData structure contains all the player's
/// current account information including session ID, rank, gold, GP, etc.
public struct AuthenticationResponse: GunBoundPacket, GunBoundPacketEncodable, Hashable, Sendable {

    public static var opcode: Opcode { .authenticationResponse }

    /// The authentication status/result
    public let status: AuthenticationStatus

    /// User account data (only included when status is `.success`)
    public let userData: UserData?

    private init(status: AuthenticationStatus, userData: UserData?) {
        self.status = status
        self.userData = userData
    }
}

public extension AuthenticationResponse {

    init(userData: UserData) {
        self.init(status: .success, userData: userData)
    }

    static var badUsername: AuthenticationResponse {
        AuthenticationResponse(status: .badUsername, userData: nil)
    }

    static var badPassword: AuthenticationResponse {
        AuthenticationResponse(status: .badPassword, userData: nil)
    }

    static var bannedUser: AuthenticationResponse {
        AuthenticationResponse(status: .bannedUser, userData: nil)
    }

    static var badVersion: AuthenticationResponse {
        AuthenticationResponse(status: .badVersion, userData: nil)
    }
}

extension AuthenticationResponse: GunBoundPacketDecodable {

    public init(parsing input: inout ParserSpan) throws {
        self.status = try AuthenticationStatus(parsing: &input)
        self.userData = status == .success ? try UserData(parsing: &input) : nil
    }

    public func encode(to output: inout ByteWriter) {
        status.encode(to: &output)
        userData?.encode(to: &output)
    }
}

// MARK: - Supporting Types

public extension AuthenticationResponse {

    /// User account data sent on successful authentication
    ///
    /// Contains all the player's current account information needed
    /// to initialize their game session.
    struct UserData: Hashable, Sendable {

        /// Unique session identifier for this connection (big-endian)
        public let session: UInt32

        /// The player's username
        public let username: Username

        /// Bitmask of equipped avatar items (8 bytes)
        /// Format: 0x00, 0x80, 0x00, 0x80, 0x00, 0x80, 0x00, 0x00
        public let avatarEquipped: UInt64

        /// The player's guild information
        public let guild: Guild

        /// Current rank points
        public let rankCurrent: UInt16

        /// Season rank points
        public let rankSeason: UInt16

        /// Number of members in the player's guild
        public let guildMemberCount: UInt16

        /// Current season rank position (leaderboard standing)
        public let rankPositionCurrent: UInt16

        /// Season rank position (leaderboard standing)
        public let rankPositionSeason: UInt16

        /// Rank within the guild
        public let guildRank: UInt16

        /// Current GP (GunBound Points) - lifetime
        public let gpCurrent: UInt32

        /// Season GP points
        public let gpSeason: UInt32

        /// Current gold balance
        public let gold: UInt32

        /// Function restrictions (bitmask of disabled features)
        public let funcRestrict: FunctionRestrict

        public init(
            session: UInt32,
            username: Username,
            avatarEquipped: UInt64,
            guild: Guild,
            rankCurrent: UInt16,
            rankSeason: UInt16,
            guildMemberCount: UInt16,
            rankPositionCurrent: UInt16,
            rankPositionSeason: UInt16,
            guildRank: UInt16,
            gpCurrent: UInt32,
            gpSeason: UInt32,
            gold: UInt32,
            funcRestrict: FunctionRestrict
        ) {
            self.session = session
            self.username = username
            self.avatarEquipped = avatarEquipped
            self.guild = guild
            self.rankCurrent = rankCurrent
            self.rankSeason = rankSeason
            self.guildMemberCount = guildMemberCount
            self.rankPositionCurrent = rankPositionCurrent
            self.rankPositionSeason = rankPositionSeason
            self.guildRank = guildRank
            self.gpCurrent = gpCurrent
            self.gpSeason = gpSeason
            self.gold = gold
            self.funcRestrict = funcRestrict
        }
    }
}

extension AuthenticationResponse.UserData {

    public init(parsing input: inout ParserSpan) throws {
        self.session = try UInt32(parsingBigEndian: &input)
        self.username = try Username(parsing: &input)
        self.avatarEquipped = try UInt64(parsingLittleEndian: &input)
        self.guild = try Guild(parsing: &input)
        self.rankCurrent = try UInt16(parsingLittleEndian: &input)
        self.rankSeason = try UInt16(parsingLittleEndian: &input)
        self.guildMemberCount = try UInt16(parsingLittleEndian: &input)
        self.rankPositionCurrent = try UInt16(parsingLittleEndian: &input)
        _ = try UInt16(parsingLittleEndian: &input)
        self.rankPositionSeason = try UInt16(parsingLittleEndian: &input)
        _ = try UInt16(parsingLittleEndian: &input)
        self.guildRank = try UInt16(parsingLittleEndian: &input)
        _ = try [UInt8](parsing: &input, byteCount: (4 * 4 * 20) + 10)  // shot history?
        self.gpCurrent = try UInt32(parsingLittleEndian: &input)
        self.gpSeason = try UInt32(parsingLittleEndian: &input)
        self.gold = try UInt32(parsingLittleEndian: &input)
        _ = try [UInt8](parsing: &input, byteCount: 17)
        self.funcRestrict = try FunctionRestrict(parsing: &input)
    }

    public func encode(to output: inout ByteWriter) {
        output.write(session, endianness: .big)  // session
        username.encode(to: &output)  // username
        output.write(avatarEquipped, endianness: .little)  // default avatar
        guild.encode(to: &output)  // guild
        output.write(rankCurrent, endianness: .little)  // rank current
        output.write(rankSeason, endianness: .little)  // rank season
        output.write(guildMemberCount, endianness: .little)
        output.write(rankPositionCurrent, endianness: .little)
        output.write(UInt16(0x0000), endianness: .little)
        output.write(rankPositionSeason, endianness: .little)
        output.write(UInt16(0x0000), endianness: .little)
        output.write(guildRank, endianness: .little)
        output.write([UInt8](repeating: 0x00, count: (4 * 4 * 20) + 10))  // shot history?
        output.write(gpCurrent, endianness: .little)
        output.write(gpSeason, endianness: .little)
        output.write(gold, endianness: .little)
        output.write([UInt8](repeating: 0x00, count: 17))
        funcRestrict.encode(to: &output)
    }
}
