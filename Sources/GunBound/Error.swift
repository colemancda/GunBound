//
//  GunBoundError.swift
//  
//
//  Created by Alsey Coleman Miller on 12/6/22.
//

import Foundation

public enum GunBoundError: Error {
    
    case invalidAddress(String)
    
    case invalidData(Data)
    
    case unexpectedResponse(Data)
    
    case checksumMismatch(UInt32, UInt32)
    
    case unknownUser(String)
}
