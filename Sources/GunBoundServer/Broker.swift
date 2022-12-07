//
//  Broker.swift
//  
//
//  Created by Alsey Coleman Miller on 12/5/22.
//

import Foundation
import ArgumentParser
import GunBound
import Socket

struct Broker: AsyncParsableCommand {
    
    @Option(help: "Path to server directory file.")
    var path: String
    
    @Option(help: "Address to bind server.")
    var address: String?
    
    @Option(help: "Port to bind server.")
    var port: UInt16 = 8372 //  Port 8372 is the default broker server port
    
    @Option(help: "Server backlog.")
    var backlog: Int = 1000
    
    func run() async throws {
        
        // Load static server list file
        let data = try Data(contentsOf: URL(fileURLWithPath: path), options: [.mappedIfSafe])
        let decoder = JSONDecoder()
        let directory = try decoder.decode(ServerDirectory.self, from: data)
        print("Starting broker with \(directory.count) servers")
        for (index, server) in directory.enumerated() {
            print("\(index + 1).", server.name)
            print("\(server.address):\(server.port)")
        }
        
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
        await dataSource.update {
            $0.serverDirectory = directory
        }
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
