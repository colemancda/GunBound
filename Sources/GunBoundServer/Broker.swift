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
    var backlog: Int = 10_000
    
    func run() async throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: path), options: [.mappedIfSafe])
        let decoder = JSONDecoder()
        let directory = try decoder.decode(ServerDirectory.self, from: data)
        print("Starting broker with \(directory.count) servers")
        for (index, server) in directory.enumerated() {
            print("\(index + 1).", server.name)
            print("\(server.address):\(server.port)")
        }
        // Create handler
        let broker = BrokerServer(directory: directory)
        // start server
        let address = address.flatMap { IPv4Address(rawValue: $0) } ?? .any
        let configuration = GunBoundServer.Configuration(
            address: address,
            port: port,
            backlog: backlog
        )
        let server = try await GunBoundServer(configuration: configuration) { address, packet in
            await broker.handle(address: address.address, packet: packet)
        }
        
        // run indefinitely
        try await Task.sleep(until: .now.advanced(by: Duration(secondsComponent: Int64(Date.distantFuture.timeIntervalSinceNow), attosecondsComponent: .zero)), clock: .suspending)
        
        withExtendedLifetime(server, { })
    }
}
