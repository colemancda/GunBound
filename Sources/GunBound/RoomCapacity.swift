//
//  RoomCapacity.swift
//  
//
//  Created by Alsey Coleman Miller on 12/10/22.
//

/// Room Capacity
public enum RoomCapacity: UInt8, Codable, CaseIterable {
    
    // 1:1
    case _1_1 = 2
    
    // 2:2
    case _2_2 = 4
    
    // 3:3
    case _3_3 = 6
    
    // 4:4
    case _4_4 = 8
}

// MARK: - CustomStringConvertible

extension RoomCapacity: CustomStringConvertible, CustomDebugStringConvertible {
    
    public var description: String {
        switch self {
        case ._1_1:
            return "1:1"
        case ._2_2:
            return "2:2"
        case ._3_3:
            return "3:3"
        case ._4_4:
            return "4:4"
        }
    }
    
    public var debugDescription: String {
        description
    }
}

// MARK: - ExpressibleByIntegerLiteral

extension RoomCapacity: ExpressibleByIntegerLiteral {
    
    public init(integerLiteral value: UInt8) {
        self.init(rawValue: value)!
    }
}
