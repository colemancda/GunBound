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
        subcommands: [List.self, Image.self, Raw.self, Montage.self, Glyphs.self, Text.self],
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

extension GunBoundExtract {

    /// Lays out a run of a multi-frame sprite's frames into one grid PNG, one
    /// frame per cell (frames left-aligned in each cell), so a font sheet's
    /// character ordering can be read at a glance.
    struct Montage: ParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Composites a run of frames into a contact-sheet PNG.")

        @Argument(help: "Path to the .xfs archive.")
        var archivePath: String

        @Argument(help: "Entry name (e.g. numfont.img).")
        var entryName: String

        @Argument(help: "Output PNG path.")
        var outputPath: String

        @Option(help: "First frame to include.")
        var start: Int = 0

        @Option(help: "Number of frames to include.")
        var count: Int = 64

        @Option(help: "Frames per row.")
        var columns: Int = 16

        @Option(help: "Cell size in pixels (square).")
        var cell: Int = 20

        func run() throws {
            let data = try [UInt8](Data(contentsOf: URL(fileURLWithPath: archivePath)))
            let entries = try XFSArchive.readEntries(data)
            guard let entry = entries.first(where: { $0.name == entryName }) else {
                throw ExtractError.entryNotFound(entryName)
            }
            let frames = try ImgFile.readFrames(try XFSArchive.readEntryData(data, entry: entry))
            let end = min(start + count, frames.count)
            let rows = (max(0, end - start) + columns - 1) / columns
            let sheetWidth = columns * cell
            let sheetHeight = max(1, rows) * cell
            var rgba = [UInt8](repeating: 0, count: sheetWidth * sheetHeight * 4)

            for (position, frameIndex) in (start..<end).enumerated() {
                let frame = frames[frameIndex]
                let cellX = (position % columns) * cell
                let cellY = (position / columns) * cell
                let w = min(Int(frame.width), cell)
                let h = min(Int(frame.height), cell)
                for y in 0..<h {
                    for x in 0..<w {
                        let pixel = frame.pixels[y * Int(frame.width) + x]
                        let dstX = cellX + x
                        let dstY = cellY + y
                        let dst = (dstY * sheetWidth + dstX) * 4
                        rgba[dst] = pixel.red
                        rgba[dst + 1] = pixel.green
                        rgba[dst + 2] = pixel.blue
                        rgba[dst + 3] = pixel.alpha
                    }
                }
            }

            #if canImport(CoreGraphics)
            try writeRGBA(rgba, width: sheetWidth, height: sheetHeight, to: URL(fileURLWithPath: outputPath))
            print("wrote \(outputPath): frames \(start)..<\(end) in a \(columns)-wide grid, \(cell)px cells")
            #else
            throw ExtractError.pngUnsupported
            #endif
        }
    }
}

extension GunBoundExtract {

    /// Renders a raw 1-bit-per-pixel glyph blob (e.g. `font.fnt`) as a
    /// contact-sheet PNG, treating the file as `count` fixed-size glyphs of
    /// `width`×`height`, MSB-first, rows padded to a byte boundary. Used to
    /// reverse-engineer the glyph geometry by trying candidate sizes.
    struct Glyphs: ParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Renders a raw 1bpp glyph blob to a contact-sheet PNG (for font reversing).")

        @Argument(help: "Path to the .xfs archive.")
        var archivePath: String

        @Argument(help: "Entry name (e.g. font.fnt).")
        var entryName: String

        @Argument(help: "Output PNG path.")
        var outputPath: String

        @Option(help: "Glyph width in pixels.")
        var width: Int = 8

        @Option(help: "Glyph height in pixels (rows).")
        var height: Int = 12

        @Option(help: "First glyph index.")
        var start: Int = 0

        @Option(help: "Number of glyphs to render.")
        var count: Int = 256

        @Option(help: "Glyphs per row in the sheet.")
        var columns: Int = 32

        @Option(help: "Bytes per glyph, if it differs from the packed size (rowBytes×height).")
        var stride: Int?

        @Option(help: "Byte offset into the entry to start reading glyphs from.")
        var offset: Int = 0

        func run() throws {
            let data = try [UInt8](Data(contentsOf: URL(fileURLWithPath: archivePath)))
            let entries = try XFSArchive.readEntries(data)
            guard let entry = entries.first(where: { $0.name == entryName }) else {
                throw ExtractError.entryNotFound(entryName)
            }
            let glyphData = try XFSArchive.readEntryData(data, entry: entry)

            let rowBytes = (width + 7) / 8
            let glyphSize = stride ?? (rowBytes * height)
            let cellW = width + 2
            let cellH = height + 2
            let rows = (count + columns - 1) / columns
            let sheetW = columns * cellW
            let sheetH = rows * cellH
            // Opaque dark-blue background so the white glyph pixels are visible.
            var rgba = [UInt8](repeating: 0, count: sheetW * sheetH * 4)
            for pixelIndex in 0..<(sheetW * sheetH) {
                let base = pixelIndex * 4
                rgba[base] = 20; rgba[base + 1] = 20; rgba[base + 2] = 40; rgba[base + 3] = 255
            }

            for i in 0..<count {
                let glyphIndex = start + i
                let base = offset + glyphIndex * glyphSize
                guard base + glyphSize <= glyphData.count else { break }
                let cellX = (i % columns) * cellW
                let cellY = (i / columns) * cellH
                for y in 0..<height {
                    for x in 0..<width {
                        let byte = glyphData[base + y * rowBytes + x / 8]
                        guard byte & (0x80 >> (x % 8)) != 0 else { continue }
                        let dst = ((cellY + y) * sheetW + (cellX + x)) * 4
                        rgba[dst] = 255; rgba[dst + 1] = 255; rgba[dst + 2] = 255; rgba[dst + 3] = 255
                    }
                }
            }

            #if canImport(CoreGraphics)
            try writeRGBA(rgba, width: sheetW, height: sheetH, to: URL(fileURLWithPath: outputPath))
            print("wrote \(outputPath): \(count) glyphs at \(width)x\(height) (stride \(glyphSize)B), from index \(start)")
            #else
            throw ExtractError.pngUnsupported
            #endif
        }
    }
}

extension GunBoundExtract {

    /// Renders a text string using `font.fnt`'s ASCII glyphs (the same
    /// proportional, trimmed glyphs the client draws) to a PNG — a direct
    /// preview of the in-game bitmap-font rendering.
    struct Text: ParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Renders a string with font.fnt to a PNG.")

        @Argument(help: "Path to the .xfs archive (graphics.xfs).")
        var archivePath: String

        @Argument(help: "The text to render.")
        var string: String

        @Argument(help: "Output PNG path.")
        var outputPath: String

        @Option(help: "Integer pixel scale.")
        var scale: Int = 3

        @Option(help: "Pixels between glyphs (before scaling).")
        var tracking: Int = 1

        func run() throws {
            let data = try [UInt8](Data(contentsOf: URL(fileURLWithPath: archivePath)))
            let entries = try XFSArchive.readEntries(data)
            guard let entry = entries.first(where: { $0.name == "font.fnt" }) else {
                throw ExtractError.entryNotFound("font.fnt")
            }
            let glyphs = FntFile.readASCIIGlyphs(try XFSArchive.readEntryData(data, entry: entry))
            let height = FntFile.glyphHeight

            // Lay glyphs out left-to-right to get the total width.
            var runs: [(frame: ImgFile.Frame, x: Int)] = []
            var cursor = 0
            for character in string.unicodeScalars {
                let code = Int(character.value)
                guard code < glyphs.count else { cursor += 4 + tracking; continue }
                let frame = glyphs[code]
                runs.append((frame, cursor))
                cursor += Int(frame.width) + tracking
            }
            let totalWidth = max(1, cursor)

            var rgba = [UInt8](repeating: 0, count: totalWidth * height * 4)
            for pixelIndex in 0..<(totalWidth * height) {
                let base = pixelIndex * 4
                rgba[base] = 20; rgba[base + 1] = 20; rgba[base + 2] = 40; rgba[base + 3] = 255
            }
            for run in runs {
                let frame = run.frame
                for y in 0..<Int(frame.height) {
                    for x in 0..<Int(frame.width) {
                        let pixel = frame.pixels[y * Int(frame.width) + x]
                        guard pixel.alpha > 0 else { continue }
                        let dst = (y * totalWidth + run.x + x) * 4
                        rgba[dst] = pixel.red; rgba[dst + 1] = pixel.green; rgba[dst + 2] = pixel.blue; rgba[dst + 3] = 255
                    }
                }
            }

            // Nearest-neighbor upscale for legibility.
            let outW = totalWidth * scale
            let outH = height * scale
            var scaled = [UInt8](repeating: 0, count: outW * outH * 4)
            for y in 0..<outH {
                for x in 0..<outW {
                    let src = ((y / scale) * totalWidth + (x / scale)) * 4
                    let dst = (y * outW + x) * 4
                    scaled[dst] = rgba[src]; scaled[dst + 1] = rgba[src + 1]; scaled[dst + 2] = rgba[src + 2]; scaled[dst + 3] = rgba[src + 3]
                }
            }

            #if canImport(CoreGraphics)
            try writeRGBA(scaled, width: outW, height: outH, to: URL(fileURLWithPath: outputPath))
            print("wrote \(outputPath): \"\(string)\" at \(scale)x")
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
    try writeRGBA(rgba, width: Int(frame.width), height: Int(frame.height), to: url)
}

/// Writes a straight-RGBA (non-premultiplied, 8-bit/channel) pixel buffer to
/// a PNG via ImageIO.
func writeRGBA(_ rgba: [UInt8], width: Int, height: Int, to url: URL) throws {
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
