//
//  RoomPassword.swift
//  
//
//  Created by Alsey Coleman Miller on 12/10/22.
//

import Foundation

public struct RoomPassword: Codable {
    
    internal let bytes: (UInt8, UInt8, UInt8, UInt8)
    
    internal init(bytes: (UInt8, UInt8, UInt8, UInt8)) {
        self.bytes = bytes
    }
    
    public init() {
        self.bytes = (0x00, 0x00, 0x00, 0x00)
    }
}

public extension RoomPassword {
    
    static var length: Int { 4 }
    
    var isEmpty: Bool {
        self == RoomPassword()
    }
}

// MARK: - Equatable

extension RoomPassword: Equatable {
    
    public static func == (lhs: RoomPassword, rhs: RoomPassword) -> Bool {
        return lhs.bytes.0 == rhs.bytes.0 &&
            lhs.bytes.1 == rhs.bytes.1 &&
            lhs.bytes.2 == rhs.bytes.2 &&
            lhs.bytes.3 == rhs.bytes.3
    }
}

// MARK: - Hashable

extension RoomPassword: Hashable {
    
    public func hash(into hasher: inout Hasher) {
        withUnsafeBytes(of: bytes) {
            hasher.combine(bytes: $0)
        }
    }
}

// MARK: - RawRepresentable

extension RoomPassword: RawRepresentable {
    
    public init?(rawValue: String) {
        // initialize empty
        guard rawValue.isEmpty == false else {
            self.init()
            return
        }
        // validate data and length
        guard let data = rawValue.data(using: .ascii), data.count <= Self.length else {
            return nil
        }
        // set bytes
        self.init(bytes: (
            data.count > 0 ? data[0] : 0x00,
            data.count > 1 ? data[1] : 0x00,
            data.count > 2 ? data[2] : 0x00,
            data.count > 3 ? data[3] : 0x00
        ))
    }
    
    public var rawValue: String {
        guard isEmpty == false else {
            return ""
        }
        let data = Data([bytes.0, bytes.1, bytes.2, bytes.3])
        guard let string = String(data: data, encoding: .ascii) else {
            assertionFailure("Invalid bytes \(data.toHexadecimal())")
            return ""
        }
        return string
    }
}

// MARK: - ExpressibleByStringLiteral

extension RoomPassword: ExpressibleByStringLiteral {
    
    public init(stringLiteral value: String) {
        guard let value = Self.init(rawValue: String(value.prefix(Self.length))) else {
            assertionFailure("Invalid string \(value)")
            self.init()
            return
        }
        self = value
    }
}

// MARK: - CustomStringConvertible

extension RoomPassword: CustomStringConvertible, CustomDebugStringConvertible {
    
    public var description: String {
        rawValue
    }
    
    public var debugDescription: String {
        description
    }
}

// MARK: - GunBoundCodable

extension RoomPassword: GunBoundCodable {
    
    public init(from container: GunBoundDecodingContainer) throws {
        let data = try container.decode(Data.self, length: Self.length)
        self.bytes = (data[0], data[1], data[2], data[3])
    }
    
    public func encode(to container: GunBoundEncodingContainer) throws {
        let data = Data([bytes.0, bytes.1, bytes.2, bytes.3])
        try container.encode(data)
    }
}
