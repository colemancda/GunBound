#if canImport(CoreGraphics)
import CoreGraphics
import GunBoundFile

extension ImgFile.Frame {

    /// A `CGImage` of this decoded frame, for UI layers (SwiftUI/AppKit/
    /// UIKit) that want the sprite outside a game renderer — e.g. the login
    /// screen backdrop. Uses straight (non-premultiplied) alpha, matching
    /// how `ImgFile.Pixel` decodes RGB565/ARGB4444 — each channel
    /// independently, not premultiplied.
    public var cgImage: CGImage? {
        var rgba = [UInt8]()
        rgba.reserveCapacity(pixels.count * 4)
        for pixel in pixels {
            rgba.append(pixel.red)
            rgba.append(pixel.green)
            rgba.append(pixel.blue)
            rgba.append(pixel.alpha)
        }
        guard let provider = CGDataProvider(data: CFDataCreate(nil, rgba, rgba.count)) else {
            return nil
        }
        return CGImage(
            width: Int(width),
            height: Int(height),
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: Int(width) * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    }
}
#endif
