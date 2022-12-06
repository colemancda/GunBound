//
//  World.swift
//  
//
//  Created by Alsey Coleman Miller on 12/5/22.
//

import Foundation
import ArgumentParser
import GunBound
import Socket

struct World: AsyncParsableCommand {
    
    @Option(help: "Address to bind server.")
    var address: String?
    
    @Option(help: "Port to bind server.")
    var port: UInt16 = 8370
    
    @Option(help: "Server backlog.")
    var backlog: Int = 10_000
    
    func run() async throws {
        // start server
        let address = address.flatMap { IPv4Address(rawValue: $0) } ?? .any
        let configuration = GunBoundServer.Configuration(
            address: address,
            port: port,
            backlog: backlog
        )
        let server = try await GunBoundServer(configuration: configuration) { address, packet in
            fatalError()
        }
        
        // run indefinitely
        try await Task.sleep(until: .now.advanced(by: Duration(secondsComponent: Int64(Date.distantFuture.timeIntervalSinceNow), attosecondsComponent: .zero)), clock: .suspending)
    }
}
