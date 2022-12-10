//
//  CashUpdate.swift
//  
//
//  Created by Alsey Coleman Miller on 12/8/22.
//

import Foundation

/// Cash Update
public struct CashUpdate: GunBoundPacket, Encodable, Hashable {
    
    public static var opcode: Opcode { .cashUpdateNotification }
    
    public static var isEncrypted: Bool { true }
    
    public let cash: UInt32
    
    public init(cash: UInt32 = 0) {
        self.cash = cash
    }
}
