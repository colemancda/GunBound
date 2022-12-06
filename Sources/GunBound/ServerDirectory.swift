//
//  ServerDirectory.swift
//  
//
//  Created by Alsey Coleman Miller on 12/6/22.
//

import Foundation
import Socket

/// GunBound Server Directory
public struct ServerDirectory: Equatable, Hashable {
    
    internal var servers: [Element]
    
    public init(_ servers: [Element]) {
        self.servers = servers
    }
}

// MARK: - Sequence

extension ServerDirectory: Sequence {
    
    public func makeIterator() -> IndexingIterator<ServerDirectory> {
        return IndexingIterator(_elements: self)
    }
}

// MARK: - Collection

extension ServerDirectory: MutableCollection {
    
    public var count: Int {
        servers.count
    }
    
    public var isEmpty: Bool {
        servers.isEmpty
    }
    
    public func index(after index: Int) -> Int {
        return servers.index(after: index)
    }
    
    public var startIndex: Int {
        return servers.startIndex
    }
    
    public var endIndex: Int {
        return servers.endIndex
    }
    
    /// Get the byte at the specified index.
    public subscript (index: Int) -> Element {
        get { servers[index] }
        mutating set {
            servers[index] = newValue
        }
    }
}

// MARK: - RandomAccessCollection

extension ServerDirectory: RandomAccessCollection {
    
    public subscript(bounds: Range<Int>) -> Slice<ServerDirectory> {
        return Slice<ServerDirectory>(base: self, bounds: bounds)
    }
}

// MARK: - ExpressibleByArrayLiteral

extension ServerDirectory: ExpressibleByArrayLiteral {
    
    public init(arrayLiteral elements: Element...) {
        self.init(elements)
    }
}

// MARK: - Codable

extension ServerDirectory: Codable {
    
    public init(from decoder: Decoder) throws {
        let elements = try [Element](from: decoder)
        self.init(elements)
    }
    
    public func encode(to encoder: Encoder) throws {
        try servers.encode(to: encoder)
    }
}

// MARK: - Supporting Types

public extension ServerDirectory {
    
    /// Server Directory instance
    struct Element: Equatable, Hashable, Codable {
        
        enum CodingKeys: String, CodingKey {
            case name
            case descriptionText = "description"
            case address
            case port
            case utilization
            case capacity
            case isEnabled = "enabled"
        }
        
        /// Server name
        public var name: String
        
        public var descriptionText: String
        
        public var address: IPv4Address
        
        public var port: UInt16
        
        public var utilization: UInt16
        
        public var capacity: UInt16
        
        public var isEnabled: Bool
    }
}
