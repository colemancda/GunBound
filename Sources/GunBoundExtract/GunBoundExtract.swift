import ArgumentParser
import Foundation
import GunBoundFile
#if canImport(CoreGraphics)
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
#endif

@main
struct GunBoundExtract: ParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "GunBoundExtract",
        abstract: "Extracts and decodes entries from GunBound .xfs archives — a Swift replacement for the decomp repo's Python tools/lzhuf scripts.",
        subcommands: [List.self, Image.self, Raw.self],
        defaultSubcommand: List.self
    )
}

extension GunBoundExtract {

    struct List: ParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Lists every entry in an .xfs archive.")

        @Argument(help: "Path to the .xfs archive (e.g. graphics.xfs).")
        var archivePath: String

        @Option(help: "Only list entries whose name contains this substring.")
        var filter: String?

        func run() throws {
            let data = try [UInt8](Data(contentsOf: URL(fileURLWithPath: archivePath)))
            let entries = try XFSArchive.readEntries(data)
            for entry in entries {
                if let filter, !entry.name.localizedCaseInsensitiveContains(filter) { continue }
                print("\(entry.name)\tdecompressedSize=\(entry.decompressedSize)\tcompressedSize=\(entry.compressedSize)\tcompressed=\(entry.isCompressed)")
            }
            print("(\(entries.count) entries total)")
        }
    }

    struct Raw: ParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Extracts a single entry's raw decompressed bytes to a file.")

        @Argument(help: "Path to the .xfs archive.")
        var archivePath: String

        @Argument(help: "Entry name (e.g. tank1.img, title.mp3).")
        var entryName: String

        @Argument(help: "Output file path.")
        var outputPath: String

        func run() throws {
            let data = try [UInt8](Data(contentsOf: URL(fileURLWithPath: archivePath)))
            let entries = try XFSArchive.readEntries(data)
            guard let entry = entries.first(where: { $0.name == entryName }) else {
                throw ExtractError.entryNotFound(entryName)
            }
            let decoded = try XFSArchive.readEntryData(data, entry: entry)
            try Data(decoded).write(to: URL(fileURLWithPath: outputPath))
            print("wrote \(decoded.count) bytes to \(outputPath)")
        }
    }

    struct Image: ParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Extracts and decodes a .img entry to a PNG.")

        @Argument(help: "Path to the .xfs archive (e.g. graphics.xfs).")
        var archivePath: String

        @Argument(help: "Entry name (e.g. server_back.img).")
        var entryName: String

        @Argument(help: "Output PNG path.")
        var outputPath: String

        @Option(help: "Which frame to decode, for multi-frame sprites.")
        var frame: Int = 0

        func run() throws {
            let data = try [UInt8](Data(contentsOf: URL(fileURLWithPath: archivePath)))
            let entries = try XFSArchive.readEntries(data)
            guard let entry = entries.first(where: { $0.name == entryName }) else {
                throw ExtractError.entryNotFound(entryName)
            }
            let decoded = try XFSArchive.readEntryData(data, entry: entry)
            let frames = try ImgFile.readFrames(decoded)
            guard frames.indices.contains(frame) else {
                throw ExtractError.frameNotFound(frame, frames.count)
            }
            let decodedFrame = frames[frame]
            print("\(entryName): \(decodedFrame.width)x\(decodedFrame.height), frame \(frame) of \(frames.count), transparencyType=\(decodedFrame.transparencyType)")

            #if canImport(CoreGraphics)
            try writePNG(decodedFrame, to: URL(fileURLWithPath: outputPath))
            print("wrote \(outputPath)")
            #else
            throw ExtractError.pngUnsupported
            #endif
        }
    }
}

enum ExtractError: Swift.Error, CustomStringConvertible {
    case entryNotFound(String)
    case frameNotFound(Int, Int)
    case pngUnsupported

    var description: String {
        switch self {
        case .entryNotFound(let name): return "No entry named '\(name)' in this archive."
        case .frameNotFound(let requested, let available): return "Frame \(requested) doesn't exist (this sprite has \(available) frame(s))."
        case .pngUnsupported: return "PNG writing needs CoreGraphics/ImageIO (macOS/iOS only)."
        }
    }
}

#if canImport(CoreGraphics)
/// Builds a `CGImage` from a decoded `.img` frame's `Pixel` array (already
/// fully decoded to 8-bit-per-channel RGBA — see `ImgFile`'s doc comment)
/// and writes it out as a PNG via ImageIO.
func writePNG(_ frame: ImgFile.Frame, to url: URL) throws {
    var rgba = [UInt8]()
    rgba.reserveCapacity(frame.pixels.count * 4)
    for pixel in frame.pixels {
        rgba.append(pixel.red)
        rgba.append(pixel.green)
        rgba.append(pixel.blue)
        rgba.append(pixel.alpha)
    }

    let width = Int(frame.width)
    let height = Int(frame.height)
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    // Straight (non-premultiplied) alpha, matching how ImgFile.Pixel decodes
    // RGB565/ARGB4444 — each channel independently, not premultiplied.
    let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue)

    guard let provider = CGDataProvider(data: Data(rgba) as CFData) else {
        throw ExtractError.pngUnsupported
    }
    guard let image = CGImage(
        width: width,
        height: height,
        bitsPerComponent: 8,
        bitsPerPixel: 32,
        bytesPerRow: width * 4,
        space: colorSpace,
        bitmapInfo: bitmapInfo,
        provider: provider,
        decode: nil,
        shouldInterpolate: false,
        intent: .defaultIntent
    ) else {
        throw ExtractError.pngUnsupported
    }

    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        throw ExtractError.pngUnsupported
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw ExtractError.pngUnsupported
    }
}
#endif
