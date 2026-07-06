//
//  GunBoundAddress.swift
//
//
//  Created by Alsey Coleman Miller on 12/6/22.
//

import Foundation
import struct Socket.IPv4Address
import struct Socket.IPv4SocketAddress
import GunBoundProtocol

/// GunBound Socket Address
public struct GunBoundAddress: Equatable, Hashable, Codable, Sendable {

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
            let port = UInt16(components[1])
        else {
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

// MARK: - Wire bridging

internal extension GunBoundAddress {

    /// Converts to the packet wire representation used by `GunBoundProtocol`'s packet types.
    var wireAddress: GunBoundProtocol.GunBoundAddress {
        GunBoundProtocol.GunBoundAddress(
            ipAddress: ipAddress.withUnsafeBytes { GunBoundProtocol.IPv4Address($0[0], $0[1], $0[2], $0[3]) },
            port: port
        )
    }
}
