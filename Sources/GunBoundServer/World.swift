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
    
    @Option(help: "Path to JSON file of persistent data.")
    var path: String?
    
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
        // configure data source
        let dataSource = InMemoryGunBoundServerDataSource { save($0) } // save on changed data
        // load saved state
        if let savedState = try load() {
            await dataSource.update {
               $0 = savedState
           }
        }
        // create admin user
        if await dataSource.state.users["admin"] == nil {
            await dataSource.update {
                $0.passwords["admin"] = "1234"
                $0.users["admin"] = User(
                    id: "admin",
                    isBanned: false,
                    rank: .administrator,
                    gold: 99_9999,
                    cash: 99_9999
                )
            }
        }
        // start server
        let server = try await GunBoundServer(
            configuration: configuration,
            dataSource: dataSource,
            socket: (GunBoundSocketIPv4TCP.self, GunBoundSocketIPv4UDP.self)
        )
        
        // run indefinitely
        try await Task.sleep(until: .now.advanced(by: Duration(secondsComponent: Int64(Date.distantFuture.timeIntervalSinceNow), attosecondsComponent: .zero)), clock: .suspending)
        
        withExtendedLifetime(server, { })
    }
    
    func load() throws -> InMemoryGunBoundServerDataSource.State? {
        guard let path = path else {
            return nil
        }
        guard FileManager.default.fileExists(atPath: path) else {
            return nil
        }
        let data = try Data(contentsOf: URL(fileURLWithPath: path), options: [.mappedIfSafe])
        return try JSONDecoder().decode(InMemoryGunBoundServerDataSource.State.self, from: data)
    }
    
    func save(_ state: InMemoryGunBoundServerDataSource.State) {
        guard let path = path else {
            return
        }
        let encoder = JSONEncoder()
        #if DEBUG
        encoder.outputFormatting = [.prettyPrinted]
        #endif
        do { try encoder.encode(state).write(to: URL(fileURLWithPath: path), options: [.atomic]) }
        catch {
            print("Unable to save state: \(error.localizedDescription)")
        }
    }
}
