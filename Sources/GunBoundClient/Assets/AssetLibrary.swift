import Foundation
import GunBoundFile

/// Loads named resources (`.img` sprites, `.mp3`/`.xes` audio) out of the
/// original client's `.xfs` archives, plus the `.dat` game-data files, given
/// a directory containing `graphics.xfs`/`sound.xfs`/`avatar.xfs` (and the
/// `.dat` files) copied straight from a real GunBound install.
public final class AssetLibrary {

    public enum Error: Swift.Error {
        case missingArchive(String)
        case missingEntry(String)
    }

    private struct Archive {
        let data: [UInt8]
        let entriesByName: [String: XFSArchive.Entry]
    }

    private let directory: URL
    private var archives: [String: Archive] = [:]

    /// In-memory caches — these archives are read from disk once and decoded
    /// lazily per resource name, not eagerly for every entry.
    private var imageCache: [String: [ImgFile.Frame]] = [:]
    private var audioPathCache: [String: URL] = [:]

    private lazy var audioCacheDirectory: URL = {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("GunBoundClientAudioCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()

    public init(directory: URL) {
        self.directory = directory
    }

    private func archive(named fileName: String) throws -> Archive {
        if let cached = archives[fileName] {
            return cached
        }
        let url = directory.appendingPathComponent(fileName)
        guard let data = try? Data(contentsOf: url) else {
            throw Error.missingArchive(fileName)
        }
        let bytes = [UInt8](data)
        let entries = try XFSArchive.readEntries(bytes)
        var entriesByName: [String: XFSArchive.Entry] = [:]
        entriesByName.reserveCapacity(entries.count)
        for entry in entries {
            entriesByName[entry.name] = entry
        }
        let archive = Archive(data: bytes, entriesByName: entriesByName)
        archives[fileName] = archive
        return archive
    }

    private func entryData(_ name: String, in fileName: String) throws -> [UInt8] {
        let archive = try archive(named: fileName)
        guard let entry = archive.entriesByName[name] else {
            throw Error.missingEntry(name)
        }
        return try XFSArchive.readEntryData(archive.data, entry: entry)
    }

    /// Decodes every frame of a named entry from `graphics.xfs`. Regular
    /// `.img` sprites decode via `ImgFile`; the `font.fnt` bitmap font decodes
    /// via `FntFile` into one frame per ASCII code (frame index == char code),
    /// so font glyphs flow through the same texture pipeline as any sprite.
    public func image(named name: String) throws -> [ImgFile.Frame] {
        if let cached = imageCache[name] {
            return cached
        }
        let decoded = try entryData(name, in: "graphics.xfs")
        let frames = name.hasSuffix(".fnt") ? FntFile.readASCIIGlyphs(decoded) : try ImgFile.readFrames(decoded)
        imageCache[name] = frames
        return frames
    }

    /// The first (and, for UI chrome, usually only) frame of a named `.img`
    /// entry — the common case for backgrounds/buttons.
    public func firstImageFrame(named name: String) throws -> ImgFile.Frame {
        try imageFrame(named: name, at: 0)
    }

    /// A specific frame of a multi-frame `.img` sprite sheet (e.g. the Game
    /// Room List's room-card states and status icons all live as separate
    /// frames inside `gamelist_back.img`).
    public func imageFrame(named name: String, at index: Int) throws -> ImgFile.Frame {
        let frames = try image(named: name)
        guard frames.indices.contains(index) else {
            throw Error.missingEntry("\(name)#\(index)")
        }
        return frames[index]
    }

    /// A playable file URL for a named `.mp3` track stored in `sound.xfs`.
    /// `.mp3` entries are byte-for-byte standard MPEG data (per
    /// `FILEFORMATS.md`), so this just writes the raw entry bytes to a cache
    /// file once and hands back its path — `SDL3Mixer`'s `SDLAudio` only
    /// loads from a file path, not from memory.
    public func musicPath(named name: String) throws -> URL {
        try cachedAudioPath(named: name, in: "sound.xfs", cacheExtension: "mp3") { $0 }
    }

    /// A playable file URL for a named `.xes` sound effect stored in
    /// `sound.xfs`, wrapped into a standard `.wav` via `XesFile.wav(from:)`.
    public func soundPath(named name: String) throws -> URL {
        try cachedAudioPath(named: name, in: "sound.xfs", cacheExtension: "wav") { try XesFile.wav(from: $0) }
    }

    private func cachedAudioPath(
        named name: String,
        in fileName: String,
        cacheExtension: String,
        transform: ([UInt8]) throws -> [UInt8]
    ) throws -> URL {
        let cacheKey = name + "." + cacheExtension
        if let cached = audioPathCache[cacheKey] {
            return cached
        }
        let cacheURL = audioCacheDirectory.appendingPathComponent(cacheKey)
        if !FileManager.default.fileExists(atPath: cacheURL.path) {
            let raw = try entryData(name, in: fileName)
            let transformed = try transform(raw)
            try Data(transformed).write(to: cacheURL)
        }
        audioPathCache[cacheKey] = cacheURL
        return cacheURL
    }

    /// Decompresses and parses `stage.dat` from the assets directory.
    public func stageData() throws -> [StageDataFile.StageRecord] {
        let url = directory.appendingPathComponent("stage.dat")
        let data = try [UInt8](Data(contentsOf: url))
        let decoded = DatFile.decompress(data, decodedSize: DatFile.stageDataDecodedSize)
        return try StageDataFile.readRecords(decoded)
    }
}
