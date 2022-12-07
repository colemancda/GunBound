//
//  Decoder.swift
//  
//
//  Created by Alsey Coleman Miller on 12/6/22.
//

import Foundation

/// GunBound Packet Decoder
public struct GunBoundDecoder {
    
    // MARK: - Properties
    
    /// Any contextual information set by the user for encoding.
    public var userInfo = [CodingUserInfoKey : Any]()
    
    /// Logger handler
    public var log: ((String) -> ())?
    
    // MARK: - Initialization
    
    public init() { }
    
    // MARK: - Methods
    
    public func decode<T>(_ type: T.Type, from data: Data) throws -> T where T: Decodable, T: GunBoundPacket {
        
        guard let packet = Packet(data: data) else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: [], debugDescription: "Could not decode packet"))
        }
        return try decode(type, from: packet)
    }
    
    public func decode<T>(_ type: T.Type, from packet: Packet) throws -> T where T: Decodable, T: GunBoundPacket {
        
        let opcode = T.opcode
        guard packet.opcode == opcode else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: [], debugDescription: "Cannot decode \(T.opcode) from \(packet.opcode) packet."))
        }
        
        log?("Will decode \(opcode) packet")
        
        let decoder = Decoder(
            userInfo: userInfo,
            log: log,
            data: packet.data
        )
        
        if let decodableType = type as? GunBoundDecodable.Type {
            let container = GunBoundDecodingContainer(referencing: decoder)
            return try decodableType.init(from: container) as! T
        } else {
            return try T.init(from: decoder)
        }
    }
}

// MARK: - Decoder

internal extension GunBoundDecoder {
    
    final class Decoder: Swift.Decoder {
        
        /// The path of coding keys taken to get to this point in decoding.
        fileprivate(set) var codingPath: [CodingKey]
        
        /// Any contextual information set by the user for decoding.
        let userInfo: [CodingUserInfoKey : Any]
        
        /// Logger
        var log: ((String) -> ())?
        
        let data: Data
        
        fileprivate(set) var offset: Int = 0
        
        // MARK: - Initialization
        
        fileprivate init(
            codingPath: [CodingKey] = [],
            userInfo: [CodingUserInfoKey : Any],
            log: ((String) -> ())?,
            data: Data
        ) {
            self.codingPath = codingPath
            self.userInfo = userInfo
            self.log = log
            self.data = data
        }
        
        // MARK: - Methods
        
        func container <Key: CodingKey> (keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> {
            
            log?("Requested container keyed by \(type.sanitizedName) for path \"\(codingPath.path)\"")
            let container = GunBoundKeyedDecodingContainer<Key>(referencing: self)
            return KeyedDecodingContainer(container)
        }
        
        func unkeyedContainer() throws -> UnkeyedDecodingContainer {
            
            log?("Requested unkeyed container for path \"\(codingPath.path)\"")
            let container = try GunBoundUnkeyedDecodingContainer(referencing: self)
            return container
        }
        
        func singleValueContainer() throws -> SingleValueDecodingContainer {
            
            log?("Requested single value container for path \"\(codingPath.path)\"")
            let container = GunBoundSingleValueDecodingContainer(referencing: self)
            return container
        }
    }
}

// MARK: - Unboxing Values

internal extension GunBoundDecoder.Decoder {
    
    func peek() -> UInt8 {
        return self.data[offset]
    }
    
    func peek<T>(_ bytes: Int, _ block: (Data) throws -> (T)) throws -> T {
        let start = offset
        let end = start + bytes
        guard self.data.count >= end else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: self.codingPath, debugDescription: "Insufficient bytes (\(self.data.count)), expected \(end) bytes"))
        }
        let data = self.data.subdataNoCopy(in: start ..< end)
        assert(data.count == bytes)
        return try block(data)
    }
    
    func read(_ bytes: Int, copying: Bool = false) throws -> Data {
        let start = offset
        let end = start + bytes
        guard self.data.count >= end else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: self.codingPath, debugDescription: "Insufficient bytes (\(data.count)), expected \(end) bytes"))
        }
        offset = end // new offset
        //defer { log?("Read \(bytes) bytes at \(start)") }
        let data = copying ? self.data.subdata(in: start ..< end) : self.data.subdataNoCopy(in: start ..< end)
        assert(data.count == bytes)
        return data
    }
    
    func read <T: GunBoundRawDecodable> (_ type: T.Type) throws -> T {
        
        let offset = self.offset
        let data = try read(T.binaryLength)
        guard let value = T.init(binaryData: data) else {
            throw DecodingError.typeMismatch(type, DecodingError.Context(codingPath: self.codingPath, debugDescription: "Could not parse \(type) from \(data) at offset \(offset)"))
        }
                
        return value
    }
    
    func readString() throws -> String {
        return try readLengthPrefixString()
    }
    
    func readNumeric <T: GunBoundRawDecodable & FixedWidthInteger> (_ type: T.Type, isLittleEndian: Bool = true) throws -> T {
        let value = try read(type)
        return isLittleEndian ? T.init(littleEndian: value) : T.init(bigEndian: value)
    }
    
    func readDouble(_ data: Data) throws -> Double {
        let bitPattern = try readNumeric(UInt64.self)
        return Double(bitPattern: bitPattern)
    }
    
    func readFloat(_ data: Data) throws -> Float {
        let bitPattern = try readNumeric(UInt32.self)
        return Float(bitPattern: bitPattern)
    }
    
    /// Attempt to decode native value to expected type.
    func readDecodable <T: Decodable> (_ type: T.Type) throws -> T {
                
        // override for native types
        if type == Data.self {
            return try readData() as! T // In this case T is Data
        } else if type == Date.self {
            return try readDate() as! T
        } else if let decodableType = type as? GunBoundDecodable.Type {
            // custom decoding
            let container = GunBoundDecodingContainer(referencing: self)
            return try decodableType.init(from: container) as! T
        } else {
            // decode using Decodable, container should read directly.
            return try T.init(from: self)
        }
    }
}

private extension GunBoundDecoder.Decoder {
    
    func readData() throws -> Data {
        
        let length = try Int(UInt16(bigEndian: read(UInt16.self)))
        let data = try read(length, copying: true)
        return data
    }
    
    func readDate() throws -> Date {
        
        let timeInterval = try readNumeric(Int32.self)
        return Date(timeIntervalSince1970: TimeInterval(timeInterval))
    }
    
    func readNullTerminatedString() throws -> String {
        
        let offset = self.offset
        guard let end = self.data
            .suffixNoCopy(from: offset)
            .firstIndex(of: 0x00) else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: self.codingPath, debugDescription: "Missing null terminator for string starting at offset \(offset)"))
        }
        let length = end
        let data = try read(length)
        self.offset += 1 // for null terminator
        
        // read data and parse string
        guard let string = String(data: data, encoding: .utf8) else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: self.codingPath, debugDescription: "Invalid string at offset \(offset)"))
        }
        
        assert(string.utf8.count == length)
        return string
    }
    
    func readLengthPrefixString() throws -> String {
        
        let offset = self.offset
        let length = try Int(read(UInt8.self))
        let data = try read(length)
        
        // read data and parse string
        guard let string = String(data: data, encoding: .utf8) else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: self.codingPath, debugDescription: "Invalid string at offset \(offset)"))
        }
        
        assert(string.utf8.count == length)
        return string
    }
}

// MARK: - KeyedDecodingContainer

internal struct GunBoundKeyedDecodingContainer <K: CodingKey> : KeyedDecodingContainerProtocol {
    
    typealias Key = K
    
    // MARK: Properties
    
    /// A reference to the encoder we're reading from.
    let decoder: GunBoundDecoder.Decoder
    
    /// The path of coding keys taken to get to this point in decoding.
    let codingPath: [CodingKey]
    
    /// All the keys the Decoder has for this container.
    let allKeys: [Key]
    
    // MARK: Initialization
    
    /// Initializes `self` by referencing the given decoder and container.
    init(referencing decoder: GunBoundDecoder.Decoder) {
        
        self.decoder = decoder
        self.codingPath = decoder.codingPath
        self.allKeys = [] // FIXME: allKeys
    }
    
    // MARK: KeyedDecodingContainerProtocol
    
    func contains(_ key: Key) -> Bool {
        
        self.decoder.log?("Check whether key \"\(key.stringValue)\" exists")
        return true // FIXME: Contains key
    }
    
    func decodeNil(forKey key: Key) throws -> Bool {
        
        // set coding key context
        self.decoder.codingPath.append(key)
        defer { self.decoder.codingPath.removeLast() }
        
        self.decoder.log?("Check if nil at path \"\(decoder.codingPath.path)\"")
        
        // There is no way to represent nil in GunBound
        return false
    }
    
    func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool {
        return try decodeGunBound(type, forKey: key)
    }
    
    func decode(_ type: Int.Type, forKey key: Key) throws -> Int {
        let value = try decodeNumeric(Int32.self, forKey: key)
        return Int(value)
    }
    
    func decode(_ type: Int8.Type, forKey key: Key) throws -> Int8 {
        return try decodeGunBound(type, forKey: key)
    }
    
    func decode(_ type: Int16.Type, forKey key: Key) throws -> Int16 {
        return try decodeNumeric(type, forKey: key)
    }
    
    func decode(_ type: Int32.Type, forKey key: Key) throws -> Int32 {
        return try decodeNumeric(type, forKey: key)
    }
    
    func decode(_ type: Int64.Type, forKey key: Key) throws -> Int64 {
        return try decodeNumeric(type, forKey: key)
    }
    
    func decode(_ type: UInt.Type, forKey key: Key) throws -> UInt {
        let value = try decodeNumeric(UInt32.self, forKey: key)
        return UInt(value)
    }
    
    func decode(_ type: UInt8.Type, forKey key: Key) throws -> UInt8 {
        return try decodeGunBound(type, forKey: key)
    }
    
    func decode(_ type: UInt16.Type, forKey key: Key) throws -> UInt16 {
        return try decodeNumeric(type, forKey: key)
    }
    
    func decode(_ type: UInt32.Type, forKey key: Key) throws -> UInt32 {
        return try decodeNumeric(type, forKey: key)
    }
    
    func decode(_ type: UInt64.Type, forKey key: Key) throws -> UInt64 {
        return try decodeNumeric(type, forKey: key)
    }
    
    func decode(_ type: Float.Type, forKey key: Key) throws -> Float {
        let bitPattern = try decodeNumeric(UInt32.self, forKey: key)
        return Float(bitPattern: bitPattern)
    }
    
    func decode(_ type: Double.Type, forKey key: Key) throws -> Double {
        let bitPattern = try decodeNumeric(UInt64.self, forKey: key)
        return Double(bitPattern: bitPattern)
    }
    
    func decode(_ type: String.Type, forKey key: Key) throws -> String {
        
        self.decoder.codingPath.append(key)
        defer { self.decoder.codingPath.removeLast() }
        self.decoder.log?("Will read \(type) at path \"\(decoder.codingPath.path)\"")
        return try self.decoder.readString()
    }
    
    func decode <T: Decodable> (_ type: T.Type, forKey key: Key) throws -> T {
        
        self.decoder.codingPath.append(key)
        defer { self.decoder.codingPath.removeLast() }
        self.decoder.log?("Will read \(type) at path \"\(decoder.codingPath.path)\"")
        return try self.decoder.readDecodable(T.self)
    }
    
    func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws -> KeyedDecodingContainer<NestedKey> where NestedKey : CodingKey {
        fatalError()
    }
    
    func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
        fatalError()
    }
    
    func superDecoder() throws -> Decoder {
        fatalError()
    }
    
    func superDecoder(forKey key: Key) throws -> Decoder {
        fatalError()
    }
    
    // MARK: Private Methods
    
    /// Decode native value type from GunBound data.
    private func decodeGunBound <T: GunBoundRawDecodable> (_ type: T.Type, forKey key: Key) throws -> T {
        
        self.decoder.codingPath.append(key)
        defer { self.decoder.codingPath.removeLast() }
        self.decoder.log?("Will read \(T.self) at path \"\(decoder.codingPath.path)\"")
        return try self.decoder.read(T.self)
    }
    
    private func decodeNumeric <T: GunBoundRawDecodable & FixedWidthInteger> (_ type: T.Type, forKey key: Key) throws -> T {
        
        self.decoder.codingPath.append(key)
        defer { self.decoder.codingPath.removeLast() }
        self.decoder.log?("Will read \(T.self) at path \"\(decoder.codingPath.path)\"")
        return try self.decoder.readNumeric(T.self)
    }
}

// MARK: - Custom Decoding

/// GunBound Decoding Container
public struct GunBoundDecodingContainer {
        
    // MARK: Properties
    
    /// A reference to the encoder we're reading from.
    internal let decoder: GunBoundDecoder.Decoder
    
    /// The path of coding keys taken to get to this point in decoding.
    public let codingPath: [CodingKey]
    
    // MARK: Initialization
    
    /// Initializes `self` by referencing the given decoder and container.
    fileprivate init(referencing decoder: GunBoundDecoder.Decoder) {
        
        self.decoder = decoder
        self.codingPath = decoder.codingPath
    }
    
    // MARK: KeyedDecodingContainerProtocol
    
    public func decode(_ type: Bool.Type) throws -> Bool {
        return try decodeGunBound(type)
    }
    
    public func decode(_ type: Int8.Type) throws -> Int8 {
        return try decodeGunBound(type)
    }
    
    public func decode(_ type: Int16.Type, isLittleEndian: Bool = false) throws -> Int16 {
        return try decodeNumeric(type, isLittleEndian: isLittleEndian)
    }
    
    public func decode(_ type: Int32.Type, isLittleEndian: Bool = false) throws -> Int32 {
        return try decodeNumeric(type, isLittleEndian: isLittleEndian)
    }
    
    public func decode(_ type: Int64.Type, isLittleEndian: Bool = false) throws -> Int64 {
        return try decodeNumeric(type, isLittleEndian: isLittleEndian)
    }
    
    public func decode(_ type: UInt8.Type) throws -> UInt8 {
        return try decodeGunBound(type)
    }
    
    public func decode(_ type: UInt16.Type, isLittleEndian: Bool = false) throws -> UInt16 {
        return try decodeNumeric(type, isLittleEndian: isLittleEndian)
    }
    
    public func decode(_ type: UInt32.Type, isLittleEndian: Bool = false) throws -> UInt32 {
        return try decodeNumeric(type, isLittleEndian: isLittleEndian)
    }
    
    public func decode(_ type: UInt64.Type, isLittleEndian: Bool = false) throws -> UInt64 {
        return try decodeNumeric(type, isLittleEndian: isLittleEndian)
    }
    
    public func decode(_ type: Float.Type, isLittleEndian: Bool = false) throws -> Float {
        let bitPattern = try decodeNumeric(UInt32.self, isLittleEndian: isLittleEndian)
        return Float(bitPattern: bitPattern)
    }
    
    public func decode(_ type: Double.Type, isLittleEndian: Bool = false) throws -> Double {
        let bitPattern = try decodeNumeric(UInt64.self, isLittleEndian: isLittleEndian)
        return Double(bitPattern: bitPattern)
    }
    
    public func decode <T: Decodable> (_ type: T.Type) throws -> T {
        return try self.decoder.readDecodable(T.self)
    }
    
    public func decode <T: Decodable> (_ type: T.Type, forKey key: CodingKey) throws -> T {
        
        self.decoder.codingPath.append(key)
        defer { self.decoder.codingPath.removeLast() }
        self.decoder.log?("Will read \(type) at path \"\(decoder.codingPath.path)\"")
        return try self.decoder.readDecodable(T.self)
    }
    
    public func decode<T: Decodable>(_ type: T.Type, forKey key: CodingKey, count: Int) throws -> [T] {
        
        let decoder = self.decoder
        assert(count >= 0)
        guard count > 0 else { return [] }
        decoder.codingPath.append(key)
        defer { decoder.codingPath.removeLast() }
        decoder.log?("Will read \(count) \(T.self) at path \"\(decoder.codingPath.path)\"")
        return try (0 ..< count)
            .lazy
            .map { Index(intValue: $0) }
            .map {
                decoder.codingPath.append($0)
                defer { decoder.codingPath.removeLast() }
                return try decoder.readDecodable(T.self)
        }
    }
    
    public func decode(_ type: Data.Type, length: Int) throws -> Data {
        assert(length >= 0)
        self.decoder.log?("Will read \(Data.self) (\(length) bytes)")
        return try self.decoder.read(length, copying: true)
    }
    
    public func decode<T>(length: Int, map: (Data) throws -> T) throws -> T {
        assert(length >= 0)
        self.decoder.log?("Will read \(T.self) (\(length) bytes)")
        let data = try self.decoder.read(length)
        return try map(data)
    }
    
    public func decode<T>(length: Int, map: (Data) throws -> T?) throws -> T {
        assert(length >= 0)
        self.decoder.log?("Will read \(T.self) (\(length) bytes)")
        let data = try self.decoder.read(length)
        guard let value = try map(data) else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: codingPath, debugDescription: "Invalid data for \(T.self)"))
        }
        return value
    }
    
    public func peek() -> UInt8 {
        return decoder.peek()
    }
    
    public func peek<T>(_ length: Int, _ block: (Data) throws -> (T)) throws -> T {
        return try decoder.peek(length, block)
    }
    
    public func peek<T>(_ length: Int, _ block: (Data) throws -> (T?)) throws -> T {
        guard let value = try decoder.peek(length, block) else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: codingPath, debugDescription: "Invalid data for \(T.self)"))
        }
        return value
    }
        
    // MARK: Private Methods
    
    /// Decode native value type from GunBound data.
    private func decodeGunBound <T: GunBoundRawDecodable> (_ type: T.Type) throws -> T {
        
        self.decoder.log?("Will read \(T.self)")
        return try self.decoder.read(T.self)
    }
    
    private func decodeNumeric <T: GunBoundRawDecodable & FixedWidthInteger> (_ type: T.Type, isLittleEndian: Bool = false) throws -> T {
        
        self.decoder.log?("Will read \(T.self)")
        return try self.decoder.readNumeric(T.self)
    }
}

// MARK: - SingleValueDecodingContainer

internal struct GunBoundSingleValueDecodingContainer: SingleValueDecodingContainer {
    
    // MARK: Properties
    
    /// A reference to the decoder we're reading from.
    let decoder: GunBoundDecoder.Decoder
    
    /// The path of coding keys taken to get to this point in decoding.
    let codingPath: [CodingKey]
    
    // MARK: Initialization
    
    /// Initializes `self` by referencing the given decoder and container.
    init(referencing decoder: GunBoundDecoder.Decoder) {
        self.decoder = decoder
        self.codingPath = decoder.codingPath
    }
    
    // MARK: SingleValueDecodingContainer
    
    func decodeNil() -> Bool {
        return false // FIXME: Decode nil
    }
    
    func decode(_ type: Bool.Type) throws -> Bool {
        return try decoder.read(Bool.self)
    }
    
    func decode(_ type: Int.Type) throws -> Int {
        let value = try decoder.readNumeric(Int32.self)
        return Int(value)
    }
    
    func decode(_ type: Int8.Type) throws -> Int8 {
        return try decoder.read(Int8.self)
    }
    
    func decode(_ type: Int16.Type) throws -> Int16 {
        return try decoder.readNumeric(Int16.self)
    }
    
    func decode(_ type: Int32.Type) throws -> Int32 {
        return try decoder.readNumeric(Int32.self)
    }
    
    func decode(_ type: Int64.Type) throws -> Int64 {
        return try decoder.readNumeric(Int64.self)
    }
    
    func decode(_ type: UInt.Type) throws -> UInt {
        let value = try decoder.readNumeric(UInt32.self)
        return UInt(value)
    }
    
    func decode(_ type: UInt8.Type) throws -> UInt8 {
        return try decoder.read(UInt8.self)
    }
    
    func decode(_ type: UInt16.Type) throws -> UInt16 {
        return try decoder.readNumeric(UInt16.self)
    }
    
    func decode(_ type: UInt32.Type) throws -> UInt32 {
        return try decoder.readNumeric(UInt32.self)
    }
    
    func decode(_ type: UInt64.Type) throws -> UInt64 {
        return try decoder.readNumeric(UInt64.self)
    }
    
    func decode(_ type: Float.Type) throws -> Float {
        let value = try decoder.readNumeric(UInt32.self)
        return Float(bitPattern: value)
    }
    
    func decode(_ type: Double.Type) throws -> Double {
        let value = try decoder.readNumeric(UInt64.self)
        return Double(bitPattern: value)
    }
    
    func decode(_ type: String.Type) throws -> String {
        return try decoder.readString()
    }
    
    func decode <T : Decodable> (_ type: T.Type) throws -> T {
        return try decoder.readDecodable(type)
    }
}

// MARK: - UnkeyedDecodingContainer

internal struct GunBoundUnkeyedDecodingContainer: UnkeyedDecodingContainer {
    
    // MARK: Properties
    
    /// A reference to the encoder we're reading from.
    let decoder: GunBoundDecoder.Decoder
    
    /// The path of coding keys taken to get to this point in decoding.
    let codingPath: [CodingKey]
    
    private(set) var currentIndex: Int = 0
    
    // MARK: Initialization
    
    /// Initializes `self` by referencing the given decoder and container.
    init(referencing decoder: GunBoundDecoder.Decoder) throws {
        
        self.decoder = decoder
        self.codingPath = decoder.codingPath
        self.count = try Int(self.decoder.readNumeric(UInt8.self))
    }
    
    // MARK: UnkeyedDecodingContainer
    
    let count: Int?
        
    var isAtEnd: Bool {
        if let count = self.count {
            return currentIndex >= count
        } else {
            return decoder.data.count <= decoder.offset
        }
    }
    
    mutating func decodeNil() throws -> Bool {
        
        try assertNotEnd()
        
        // never optional, decode
        return false
    }
    
    mutating func decode(_ type: Bool.Type) throws -> Bool { fatalError("stub") }
    mutating func decode(_ type: Int.Type) throws -> Int { fatalError("stub") }
    mutating func decode(_ type: Int8.Type) throws -> Int8 { fatalError("stub") }
    mutating func decode(_ type: Int16.Type) throws -> Int16 { fatalError("stub") }
    mutating func decode(_ type: Int32.Type) throws -> Int32 { fatalError("stub") }
    mutating func decode(_ type: Int64.Type) throws -> Int64 { fatalError("stub") }
    mutating func decode(_ type: UInt.Type) throws -> UInt { fatalError("stub") }
    mutating func decode(_ type: UInt8.Type) throws -> UInt8 { fatalError("stub") }
    mutating func decode(_ type: UInt16.Type) throws -> UInt16 { fatalError("stub") }
    mutating func decode(_ type: UInt32.Type) throws -> UInt32 { fatalError("stub") }
    mutating func decode(_ type: UInt64.Type) throws -> UInt64 { fatalError("stub") }
    mutating func decode(_ type: Float.Type) throws -> Float { fatalError("stub") }
    mutating func decode(_ type: Double.Type) throws -> Double { fatalError("stub") }
    mutating func decode(_ type: String.Type) throws -> String { fatalError("stub") }
    
    mutating func decode <T : Decodable> (_ type: T.Type) throws -> T {
        
        try assertNotEnd()
        
        self.decoder.codingPath.append(Index(intValue: self.currentIndex))
        defer { self.decoder.codingPath.removeLast() }
        
        let decoded = try self.decoder.readDecodable(type)
        self.currentIndex += 1
        return decoded
    }
    
    mutating func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type) throws -> KeyedDecodingContainer<NestedKey> where NestedKey : CodingKey {
        throw DecodingError.typeMismatch(type, DecodingError.Context(codingPath: codingPath, debugDescription: "Cannot decode \(type)"))
    }
    
    mutating func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
        throw DecodingError.typeMismatch([Any].self, DecodingError.Context(codingPath: codingPath, debugDescription: "Cannot decode unkeyed container."))
    }
    
    mutating func superDecoder() throws -> Decoder {
        /*
        // set coding key context
        self.decoder.codingPath.append(Index(intValue: currentIndex))
        defer { self.decoder.codingPath.removeLast() }
        
        // log
        self.decoder.log?("Requested super decoder for path \"\(self.decoder.codingPath.path)\"")
        
        // check for end of array
        try assertNotEnd()
        
        // get item
        let item = container[currentIndex]
        
        // increment counter
        self.currentIndex += 1
        
        // create new decoder
        let decoder = GunBoundDecoder.Decoder(referencing: .item(item),
                                            at: self.decoder.codingPath,
                                            userInfo: self.decoder.userInfo,
                                            log: self.decoder.log,
                                            options: self.decoder.options)
        
        return decoder*/
        fatalError()
    }
    
    // MARK: Private Methods
    
    @inline(__always)
    private func assertNotEnd() throws {
        
        guard isAtEnd == false else {
            
            throw DecodingError.valueNotFound(Any?.self, DecodingError.Context(codingPath: self.decoder.codingPath + [Index(intValue: self.currentIndex)], debugDescription: "Unkeyed container is at end."))
        }
    }
}

internal extension GunBoundUnkeyedDecodingContainer {
    
    typealias Index = GunBoundIndexKey
}

internal extension GunBoundDecodingContainer {
    
    typealias Index = GunBoundIndexKey
}

internal struct GunBoundIndexKey: CodingKey {
    
    public let index: Int
    
    public init(intValue: Int) {
        self.index = intValue
    }
    
    public var intValue: Int? {
        return index
    }
        
    public init?(stringValue: String) {
        guard let index = Int(stringValue)
            else { return nil }
        self.init(intValue: index)
    }
    
    public var stringValue: String {
        return index.description
    }
}

// MARK: - Decodable Types

/// Private protocol for decoding GunBound values into raw data.
internal protocol GunBoundRawDecodable {
    
    init?(binaryData data: Data)
    
    static var binaryLength: Int { get }
}

internal extension GunBoundRawDecodable {
    
    init?(binaryData data: Data) {
        
        guard data.count == Self.binaryLength
            else { return nil }
        
        self = data.withUnsafeBytes { $0.load(as: Self.self) }
    }
    
    static var binaryLength: Int { return MemoryLayout<Self>.size }
}

extension Bool: GunBoundRawDecodable {
    
    public init?(binaryData data: Data) {
        
        guard let byte = UInt8(binaryData: data)
            else { return nil }
        
        switch byte {
        case 0:
            self = false
        case 1:
            self = true
        default:
            return nil
        }
    }
    
    public static var binaryLength: Int { return UInt8.binaryLength }
}

extension UInt8: GunBoundRawDecodable { }

extension UInt16: GunBoundRawDecodable { }

extension UInt32: GunBoundRawDecodable { }

extension UInt64: GunBoundRawDecodable { }

extension Int8: GunBoundRawDecodable { }

extension Int16: GunBoundRawDecodable { }

extension Int32: GunBoundRawDecodable { }

extension Int64: GunBoundRawDecodable { }
