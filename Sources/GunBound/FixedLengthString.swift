//
//  FixedLengthString.swift
//  
//
//  Created by Alsey Coleman Miller on 12/10/22.
//

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
        rawValue
    }
}

extension FixedLengthString where Self: CustomDebugStringConvertible {
    
    public var debugDescription: String {
        rawValue
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
        guard let string = try container.decode(length: Self.length, map: {
            String(data: $0, encoding: .ascii)
        }) else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: container.codingPath, debugDescription: "Invalid string bytes"))
        }
        guard let value = Self.init(rawValue: string) else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: container.codingPath, debugDescription: "Invalid string"))
        }
        self = value
    }
}

extension FixedLengthString where Self: GunBoundEncodable {
    
    public func encode(to container: GunBoundEncodingContainer) throws {
        try container.encode(rawValue, fixedLength: UInt(Self.length))
    }
}
