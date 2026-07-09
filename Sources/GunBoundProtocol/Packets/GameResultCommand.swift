/// Game Result Command (`SVC_PLAY_RESULT`)
///
/// Sent by a client at the end of a match with the per-slot results (gold
/// and GP earned, plus bonuses). The server acknowledges by broadcasting a
/// `GameResultNotification` (0x4413) to every player in the room and
/// returns the room to the waiting state.
///
/// An empty payload is tolerated (decoded as zero results) since earlier
/// clients sent this purely as a trigger signal.
public struct GameResultCommand: GunBoundPacket, GunBoundPacketEncodable, GunBoundPacketDecodable, Equatable, Hashable, Sendable {

    public static var opcode: Opcode { .playResultCommand }

    /// Per-player results, one entry per occupied slot.
    public let results: [PlayerResult]

    public init(results: [PlayerResult] = []) {
        self.results = results
    }

    public init(parsing input: inout ParserSpan) throws {
        guard input.isEmpty == false else {
            self.results = []
            return
        }
        let count = try UInt8(parsing: &input)
        var results = [PlayerResult]()
        results.reserveCapacity(Int(count))
        for _ in 0..<count {
            results.append(try PlayerResult(parsing: &input))
        }
        self.results = results
        // 8 trailing reserved bytes (ignored; may be absent)
        _ = [UInt8](parsingRemainingBytes: &input)
    }

    public func encode(to output: inout ByteWriter) {
        output.write(UInt8(results.count))
        for result in results {
            result.encode(to: &output)
        }
        output.write([UInt8](repeating: 0, count: 8))
    }
}

// MARK: - Supporting Types

public extension GameResultCommand {

    /// One slot's end-of-match earnings.
    struct PlayerResult: Equatable, Hashable, Sendable {

        /// Reserved leading byte.
        internal let value0: UInt8

        /// Room slot the result belongs to.
        public let slot: UInt8

        /// Base gold earned.
        public let gold: UInt16

        /// Bonus gold earned.
        public let bonusGold: UInt16

        /// Reserved field between the gold and GP groups.
        internal let value1: UInt16

        /// Base GP earned.
        public let gp: UInt16

        /// Bonus GP earned.
        public let bonusGP: UInt16

        /// Reserved trailing fields.
        internal let value2: UInt16
        internal let value3: UInt16
        internal let value4: UInt16

        public init(
            slot: UInt8,
            gold: UInt16,
            bonusGold: UInt16 = 0,
            gp: UInt16,
            bonusGP: UInt16 = 0
        ) {
            self.value0 = 0
            self.slot = slot
            self.gold = gold
            self.bonusGold = bonusGold
            self.value1 = 0
            self.gp = gp
            self.bonusGP = bonusGP
            self.value2 = 0
            self.value3 = 0
            self.value4 = 0
        }
    }
}

extension GameResultCommand.PlayerResult {

    public init(parsing input: inout ParserSpan) throws {
        self.value0 = try UInt8(parsing: &input)
        self.slot = try UInt8(parsing: &input)
        self.gold = try UInt16(parsingLittleEndian: &input)
        self.bonusGold = try UInt16(parsingLittleEndian: &input)
        self.value1 = try UInt16(parsingLittleEndian: &input)
        self.gp = try UInt16(parsingLittleEndian: &input)
        self.bonusGP = try UInt16(parsingLittleEndian: &input)
        self.value2 = try UInt16(parsingLittleEndian: &input)
        self.value3 = try UInt16(parsingLittleEndian: &input)
        self.value4 = try UInt16(parsingLittleEndian: &input)
    }

    public func encode(to output: inout ByteWriter) {
        output.write(value0)
        output.write(slot)
        output.write(gold, endianness: .little)
        output.write(bonusGold, endianness: .little)
        output.write(value1, endianness: .little)
        output.write(gp, endianness: .little)
        output.write(bonusGP, endianness: .little)
        output.write(value2, endianness: .little)
        output.write(value3, endianness: .little)
        output.write(value4, endianness: .little)
    }
}
