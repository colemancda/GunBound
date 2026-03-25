//
//  UserIdRequest.swift
//
//
//  Created by Coleman on 3/24/26.
//

import Foundation

/// User ID Request
/// Request to look up another user's information by username
public struct UserIdRequest: GunBoundPacket, Codable, Equatable, Hashable {

    public static var opcode: Opcode { .userRequest }

    public var unknown: UInt16
    public var username: FixedLengthString<12>

    public init(unknown: UInt16 = 0, username: String) {
        self.unknown = unknown
        self.username = FixedLengthString(username)
    }
}
