//
//  Codable.swift
//  
//
//  Created by Alsey Coleman Miller on 12/6/22.
//

import Foundation

// MARK: - GunBoundCodable

/// GunBound Codable
public typealias GunBoundCodable = GunBoundEncodable & GunBoundDecodable

/// GunBound Decodable type
public protocol GunBoundDecodable: Decodable {
    
    //init(from container: GunBoundDecodingContainer) throws
}

/// GunBound Encodable type
public protocol GunBoundEncodable: Encodable {
    
    func encode(to container: GunBoundEncodingContainer) throws
}
