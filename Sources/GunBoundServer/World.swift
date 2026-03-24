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

    @Option(help: "Path to setting.txt (GunBoundServ configuration file).")
    var settingPath: String?

    @Option(help: "Path to channel_ment.txt (channel MOTD).")
    var channelMentPath: String?

    @Option(help: "Path to room_ment.txt (room MOTD).")
    var roomMentPath: String?

    func run() async throws {
        // parse setting.txt if provided
        let settings = settingPath.flatMap { try? WorldSettings(contentsOfFile: $0) }

        // determine bind address and port
        let bindPort = settings.map { UInt16($0.port) } ?? port
        let ipAddress = self.address ?? IPv4Address.any.rawValue
        guard let bindAddress = GunBoundAddress(address: ipAddress, port: bindPort) else {
            throw GunBoundError.invalidAddress(ipAddress)
        }

        // build accept list from setting.txt Accept key (semicolon-separated)
        let acceptList: [String] = settings?.accept
            .components(separatedBy: ";")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            ?? []

        let configuration = GunBoundServerConfiguration(
            address: bindAddress,
            backlog: backlog,
            accept: acceptList
        )

        // configure data source
        let dataSource = InMemoryGunBoundServerDataSource { save($0) }

        // load saved state
        if let savedState = try load() {
            await dataSource.update { $0 = savedState }
        }

        // apply setting.txt values over the loaded state
        if let settings = settings {
            await dataSource.update { state in
                state.versionFirst    = ClientVersion(rawValue: UInt16(max(0, settings.versionFirst)))
                state.versionLast     = ClientVersion(rawValue: UInt16(min(65535, settings.versionLast)))
                state.gradeLimitFirst = Int16(clamping: settings.gradeLimitFirst)
                state.gradeLimitLast  = Int16(clamping: settings.gradeLimitLast)
                state.noRoomCreate    = settings.noRoomCreate
                state.functionRestrict = FunctionRestrict(rawValue: settings.funcRestrict)
            }
        }

        // load channel_ment.txt
        if let mentPath = channelMentPath,
           let message = try? String(contentsOfFile: mentPath, encoding: .utf8) {
            let trimmed = message.trimmingCharacters(in: .newlines)
            await dataSource.update { $0.defaultChannelMessage = trimmed }
        }

        // load room_ment.txt
        if let mentPath = roomMentPath,
           let message = try? String(contentsOfFile: mentPath, encoding: .utf8) {
            let trimmed = message.trimmingCharacters(in: .newlines)
            await dataSource.update { $0.defaultRoomMessage = trimmed }
        }

        // create admin user if absent
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

        withExtendedLifetime(server, {})
    }

    func load() throws -> InMemoryGunBoundServerDataSource.State? {
        guard let path = path else { return nil }
        guard FileManager.default.fileExists(atPath: path) else { return nil }
        let data = try Data(contentsOf: URL(fileURLWithPath: path), options: [.mappedIfSafe])
        return try JSONDecoder().decode(InMemoryGunBoundServerDataSource.State.self, from: data)
    }

    func save(_ state: InMemoryGunBoundServerDataSource.State) {
        guard let path = path else { return }
        let encoder = JSONEncoder()
        #if DEBUG
        encoder.outputFormatting = [.prettyPrinted]
        #endif
        do { try encoder.encode(state).write(to: URL(fileURLWithPath: path), options: [.atomic]) } catch {
            print("Unable to save state: \(error.localizedDescription)")
        }
    }
}

// MARK: - WorldSettings

/// Parsed representation of GunBoundServ's `setting.txt`.
/// Supports the `key=value` format; lines starting with `//` are ignored.
struct WorldSettings {

    var port: Int = 8370
    var versionFirst: Int = 0
    var versionLast: Int = 999
    var gradeLimitFirst: Int = -4
    var gradeLimitLast: Int = 20
    var funcRestrict: UInt32 = 0x000FFFFF
    var noRoomCreate: Bool = false
    var accept: String = ""
    var guildMarkLimit: Int = 0
    var recommendedMan: Int = 1

    init(contentsOfFile path: String) throws {
        let text = try String(contentsOfFile: path, encoding: .utf8)
        for line in text.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("//") else { continue }
            let parts = trimmed.components(separatedBy: "=")
            guard parts.count >= 2 else { continue }
            let key = parts[0].trimmingCharacters(in: .whitespaces)
            let value = parts.dropFirst().joined(separator: "=").trimmingCharacters(in: .whitespaces)
            switch key {
            case "Port":           port            = Int(value) ?? port
            case "VersionFirst":   versionFirst    = Int(value) ?? versionFirst
            case "VersionLast":    versionLast     = Int(value) ?? versionLast
            case "GradeLimitFirst": gradeLimitFirst = Int(value) ?? gradeLimitFirst
            case "GradeLimitLast": gradeLimitLast  = Int(value) ?? gradeLimitLast
            case "FuncRestrict":   funcRestrict    = UInt32(value) ?? funcRestrict
            case "NoRoomCreate":   noRoomCreate    = value != "0"
            case "Accept":         accept          = value
            case "GuildMarkLimit": guildMarkLimit  = Int(value) ?? guildMarkLimit
            case "RecommendedMan": recommendedMan  = Int(value) ?? recommendedMan
            default: break
            }
        }
    }
}
