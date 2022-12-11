//
//  FixedLengthString.swift
//  
//
//  Created by Alsey Coleman Miller on 12/10/22.
//

import Foundation

public protocol FixedLengthString: RawRepresentable, GunBoundCodable where RawValue == String {
    
    static var length: Int { get }
}

public extension FixedLengthString {
    
    static func validate(_ string: String) -> Bool {
        guard let data = string.data(using: .ascii), data.count <= Self.length else {
            return false
        }
        return true
    }
    
    var isEmpty: Bool {
        return rawValue.isEmpty
    }
}

// MARK: - CustomStringConvertible

extension FixedLengthString where Self: CustomStringConvertible {
    
    public var description: String {
        rawValue.description
    }
}

extension FixedLengthString where Self: CustomDebugStringConvertible {
    
    public var debugDescription: String {
        rawValue.debugDescription
    }
}

// MARK: - ExpressibleByStringLiteral

extension FixedLengthString where Self: ExpressibleByStringLiteral {
    
    public init(stringLiteral value: String) {
        guard let value = Self(rawValue: value) else {
            fatalError("Invalid string \(value)")
        }
        self = value
    }
}

// MARK: - GunBoundCodable

extension FixedLengthString where Self: GunBoundDecodable {
    
    public init(from container: GunBoundDecodingContainer) throws {
        guard let string = try container.decode(length: Self.length, map: { data in
            String(data: Self.removePadding(data), encoding: .ascii)
        }) else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: container.codingPath, debugDescription: "Invalid string bytes"))
        }
        guard let value = Self.init(rawValue: string) else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: container.codingPath, debugDescription: "Invalid string"))
        }
        self = value
    }
    
    internal static func removePadding(_ data: Data) -> Data {
        var padding = 0
        for byte in data.reversed() {
            if byte == 0 {
                padding += 1
            } else {
                break
            }
        }
        let length = data.count - padding
        let stringBytes = padding > 0 ? data.prefix(length) : data
        assert(stringBytes.count == length)
        return stringBytes
    }
}

extension FixedLengthString where Self: GunBoundEncodable {
    
    public func encode(to container: GunBoundEncodingContainer) throws {
        try container.encode(rawValue, fixedLength: UInt(Self.length))
    }
}
