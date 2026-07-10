/// The port of the original's avatar compositor `LoadAvatarSprites`
/// (`0x4141b0`; decomp `FILEFORMATS.md` — "Where it lives / the pipeline"):
/// blits a worn outfit's part sprites (body, head, glasses, flag) into one
/// RGBA frame, the way the original builds each player's composite in a
/// per-player buffer before drawing it to the `AvataTexture1/2` runtime
/// render targets.
///
/// Each layer is placed by its own frame hotspot — a part sprite's
/// `xCenter`/`yCenter` is its top-left offset from the shared character
/// anchor (body ≈ `(-9,-6)`, head ≈ `(0,-24)`, glasses ≈ `(0,-13)`, flag
/// ≈ `(15,-37)` in the real assets, stacking upward from the feet).
/// Layers draw in the given order, later over earlier (source-over).
public enum AvatarComposite {

    /// Composites hotspot-aligned layers into a single `.alpha` frame just
    /// big enough to hold them all; the result's own `xCenter`/`yCenter`
    /// is the union's top-left offset from the same shared anchor, so it
    /// can be placed exactly like any single part. `nil` when `layers` is
    /// empty or degenerate.
    public static func compose(_ layers: [ImgFile.Frame]) -> ImgFile.Frame? {
        // The union of every layer's anchor-relative bounds.
        var minX = Int32.max, minY = Int32.max
        var maxX = Int32.min, maxY = Int32.min
        for layer in layers where layer.width > 0 && layer.height > 0 {
            minX = min(minX, layer.xCenter)
            minY = min(minY, layer.yCenter)
            maxX = max(maxX, layer.xCenter + layer.width)
            maxY = max(maxY, layer.yCenter + layer.height)
        }
        guard minX < maxX, minY < maxY else { return nil }

        let width = Int(maxX - minX)
        let height = Int(maxY - minY)
        var pixels = [ImgFile.Pixel](repeating: .transparent, count: width * height)

        for layer in layers where layer.width > 0 && layer.height > 0 {
            let offsetX = Int(layer.xCenter - minX)
            let offsetY = Int(layer.yCenter - minY)
            for y in 0..<Int(layer.height) {
                let sourceRow = y * Int(layer.width)
                let targetRow = (y + offsetY) * width + offsetX
                for x in 0..<Int(layer.width) {
                    let source = layer.pixels[sourceRow + x]
                    guard source.alpha > 0 else { continue }
                    let index = targetRow + x
                    if source.alpha == 0xff {
                        pixels[index] = source
                    } else {
                        pixels[index] = blend(source, over: pixels[index])
                    }
                }
            }
        }

        return ImgFile.Frame(
            transparencyType: .alpha,
            width: Int32(width),
            height: Int32(height),
            xCenter: minX,
            yCenter: minY,
            pixels: pixels
        )
    }

    /// Standard integer source-over: `out = src + dst·(1 − srcA)`.
    private static func blend(_ source: ImgFile.Pixel, over target: ImgFile.Pixel) -> ImgFile.Pixel {
        let sourceAlpha = Int(source.alpha)
        let inverse = 255 - sourceAlpha
        func channel(_ src: UInt8, _ dst: UInt8, _ dstAlpha: Int) -> Int {
            (Int(src) * sourceAlpha + Int(dst) * dstAlpha * inverse / 255) / 255
        }
        let targetAlpha = Int(target.alpha)
        let outAlpha = sourceAlpha + targetAlpha * inverse / 255
        guard outAlpha > 0 else { return .transparent }
        // Un-premultiplied output: composite premultiplied, then divide out.
        let red = channel(source.red, target.red, targetAlpha) * 255 / outAlpha
        let green = channel(source.green, target.green, targetAlpha) * 255 / outAlpha
        let blue = channel(source.blue, target.blue, targetAlpha) * 255 / outAlpha
        return ImgFile.Pixel(
            red: UInt8(min(255, red)),
            green: UInt8(min(255, green)),
            blue: UInt8(min(255, blue)),
            alpha: UInt8(min(255, outAlpha))
        )
    }
}
