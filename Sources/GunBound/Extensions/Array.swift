//
//  Array.swift
//
//
//  Created by Alsey Coleman Miller on 12/6/22.
//


internal extension Array {
    
    mutating func popFirst() -> Element? {
        guard let first = self.first else { return nil }
        self.removeFirst()
        return first
    }
}
