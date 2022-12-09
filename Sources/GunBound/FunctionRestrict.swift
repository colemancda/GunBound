//
//  FunctionRestrict.swift
//  
//
//  Created by Alsey Coleman Miller on 12/6/22.
//

/// GunBound Function Restrict
public struct FunctionRestrict: OptionSet {
    
    public var rawValue: Int32
    
    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }
}

// MARK: - ExpressibleByIntegerLiteral

extension FunctionRestrict: ExpressibleByIntegerLiteral {
    
    public init(integerLiteral value: Int32) {
        self.rawValue = value
    }
}

// MARK: - CustomStringConvertible

extension FunctionRestrict: CustomStringConvertible, CustomDebugStringConvertible {
    
    public var description: String {
        "0x" + rawValue.toHexadecimal() // TODO: print as array
    }
    
    public var debugDescription: String {
        description
    }
}
    
public extension FunctionRestrict {

    static var avatarEnabled: FunctionRestrict      { FunctionRestrict(rawValue: 1 << 4) }
    static var effectForce: FunctionRestrict        { FunctionRestrict(rawValue: 1 << 13) }
    static var effectTornado: FunctionRestrict      { FunctionRestrict(rawValue: 1 << 14) }
    static var effectLightning: FunctionRestrict    { FunctionRestrict(rawValue: 1 << 15) }
    static var effectWind: FunctionRestrict         { FunctionRestrict(rawValue: 1 << 16) }
    static var effectThor: FunctionRestrict         { FunctionRestrict(rawValue: 1 << 17) }
    static var effectMoon: FunctionRestrict         { FunctionRestrict(rawValue: 1 << 18) }
    static var effectEclipse: FunctionRestrict      { FunctionRestrict(rawValue: 1 << 19) }
    static var event1Enable: FunctionRestrict       { FunctionRestrict(rawValue: 1 << 20) }
    static var event2Enable: FunctionRestrict       { FunctionRestrict(rawValue: 1 << 21) }
    static var event3Enable: FunctionRestrict       { FunctionRestrict(rawValue: 1 << 22) }
    static var event4Enable: FunctionRestrict       { FunctionRestrict(rawValue: 1 << 23) }
}
