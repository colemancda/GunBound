//
//  FunctionRestrict.swift
//  
//
//  Created by Alsey Coleman Miller on 12/6/22.
//

///
public struct FunctionRestrict: OptionSet {
    
    public var rawValue: Int
    
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
}
    
public extension FunctionRestrict {

    static let avatarEnabled = FunctionRestrict(rawValue: 1 << 4)
    static let effectForce = FunctionRestrict(rawValue: 1 << 13)
    static let effectTornado = FunctionRestrict(rawValue: 1 << 14)
    static let effectLightning = FunctionRestrict(rawValue: 1 << 15)
    static let effectWind = FunctionRestrict(rawValue: 1 << 16)
    static let effectThor = FunctionRestrict(rawValue: 1 << 17)
    static let effectMoon = FunctionRestrict(rawValue: 1 << 18)
    static let effectEclipse = FunctionRestrict(rawValue: 1 << 19)
    static let event1Enable = FunctionRestrict(rawValue: 1 << 20)
    static let event2Enable = FunctionRestrict(rawValue: 1 << 21)
    static let event3Enable = FunctionRestrict(rawValue: 1 << 22)
    static let event4Enable = FunctionRestrict(rawValue: 1 << 23)
}
