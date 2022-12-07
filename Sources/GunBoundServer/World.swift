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
    var backlog: Int = 1000
    
    func run() async throws {
        // start server
        let ipAddress = self.address ?? IPv4Address.any.rawValue
        guard let address = GunBoundAddress(address: ipAddress, port: port) else {
            throw GunBoundError.invalidAddress(ipAddress)
        }
        let configuration = GunBoundServerConfiguration(
            address: address,
            backlog: backlog
        )
        let dataSource = InMemoryGunBoundServerDataSource()
        let server = try await GunBoundServer(
            configuration: configuration,
            dataSource: dataSource,
            socket: GunBoundTCPSocket.self
        )
        
        // run indefinitely
        try await Task.sleep(until: .now.advanced(by: Duration(secondsComponent: Int64(Date.distantFuture.timeIntervalSinceNow), attosecondsComponent: .zero)), clock: .suspending)
        
        withExtendedLifetime(server, { })
    }
}
