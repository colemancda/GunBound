//
//  GunBoundAddress.swift
//  
//
//  Created by Alsey Coleman Miller on 12/6/22.
//

import Foundation
import Socket

/// GunBound Socket Address
public struct GunBoundAddress: Equatable, Hashable, Codable {
    
    /// IP Address
    public var address: String {
        ipAddress.rawValue
    }
    
    /// Port
    public let port: UInt16
    
    internal let ipAddress: IPv4Address
    
    internal init(ipAddress: IPv4Address, port: UInt16) {
        self.ipAddress = ipAddress
        self.port = port
    }
    
    public init?(address: String, port: UInt16) {
        guard let ipAddress = IPv4Address(rawValue: address) else {
            return nil
        }
        self.init(ipAddress: ipAddress, port: port)
    }
}

public extension GunBoundAddress {
    
    static var serverDefault: GunBoundAddress {
        GunBoundAddress(ipAddress: .any, port: 8370)
    }
}

internal extension GunBoundAddress {
    
    init(_ address: IPv4SocketAddress) {
        self.init(ipAddress: address.address, port: address.port)
    }
}

internal extension IPv4SocketAddress {
    
    init(_ address: GunBoundAddress) {
        self.init(address: address.ipAddress, port: address.port)
    }
}

// MARK: - RawRepresentable

extension GunBoundAddress: RawRepresentable {
    
    public init?(rawValue: String) {
        let components = rawValue.components(separatedBy: ":")
        // validate
        guard components.count == 2,
              let ipAddress = IPv4Address(rawValue: components[0]),
              let port = UInt16(components[1]) else {
            return nil
        }
        self.ipAddress = ipAddress
        self.port = port
    }
    
    public var rawValue: String {
        address + ":" + port.description
    }
}

// MARK: - CustomStringConvertible

extension GunBoundAddress: CustomStringConvertible, CustomDebugStringConvertible {
    
    public var description: String {
        rawValue
    }
    
    public var debugDescription: String {
        description
    }
}

// MARK: - GunBoundCodable

extension GunBoundAddress: GunBoundCodable {
    
    enum CodingKeys: String, CodingKey {
        
        case ipAddress
        case port
    }
    
    public init(from container: GunBoundDecodingContainer) throws {
        self.ipAddress = try container.decode(IPv4Address.self, forKey: CodingKeys.ipAddress)
        self.port = try container.decode(UInt16.self, isLittleEndian: false)
    }
    
    public func encode(to container: GunBoundEncodingContainer) throws {
        try container.encode(ipAddress, forKey: CodingKeys.ipAddress)
        try container.encode(port, isLittleEndian: false)
    }
}

extension IPv4Address: GunBoundCodable {
    
    private var binaryData: Data {
        return self.withUnsafeBytes {
            Data(bytes: $0.baseAddress!, count: 4)
        }
    }
    
    public init(from container: GunBoundDecodingContainer) throws {
        self = try container.decode(length: 4) {
            $0.withUnsafeBytes {
                $0.load(as: IPv4Address.self)
            }
        }
    }
    
    public func encode(to container: GunBoundEncodingContainer) throws {
        try container.encode(binaryData)
    }
}

