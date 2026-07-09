/// The `.lnd` terrain/collision mask paired with each battle stage's art
/// (`<code>.img` + `<code>.lnd` in `graphics.xfs`, plus `<code>b.*` B-side
/// variants). Format confirmed empirically against the real archive:
///
/// ```
/// [u32 width LE][u32 height LE][width × height bytes, row-major]
/// ```
///
/// Each byte is a terrain cell: `0` = empty air, non-zero = solid ground
/// (the real files use `2` for terrain; the non-zero test keeps any other
/// type values solid too). The mask's silhouette matches the stage art's
/// terrain layer pixel-for-pixel — this is the map the original's
/// ballistics, walking, and terrain destruction operate on.
public struct LndFile: Equatable, Sendable {

    public enum Error: Swift.Error, Equatable {
        case truncated
        case invalidDimensions(width: Int, height: Int)
    }

    public let width: Int
    public let height: Int
    /// Row-major terrain cells, `width × height` bytes; `0` = air.
    public let mask: [UInt8]

    public init(width: Int, height: Int, mask: [UInt8]) {
        self.width = width
        self.height = height
        self.mask = mask
    }

    /// Parses a decompressed `.lnd` payload.
    public static func read(_ data: [UInt8]) throws -> LndFile {
        guard data.count >= 8 else { throw Error.truncated }
        let width = Int(data[0]) | (Int(data[1]) << 8) | (Int(data[2]) << 16) | (Int(data[3]) << 24)
        let height = Int(data[4]) | (Int(data[5]) << 8) | (Int(data[6]) << 16) | (Int(data[7]) << 24)
        guard width > 0, height > 0, width <= 8192, height <= 8192 else {
            throw Error.invalidDimensions(width: width, height: height)
        }
        guard data.count >= 8 + width * height else { throw Error.truncated }
        return LndFile(width: width, height: height, mask: Array(data[8..<(8 + width * height)]))
    }

    /// Whether the cell at (x, y) is solid ground. Out-of-bounds is air.
    public func isSolid(x: Int, y: Int) -> Bool {
        guard x >= 0, x < width, y >= 0, y < height else { return false }
        return mask[y * width + x] != 0
    }

    /// The y of the first solid cell at column `x`, scanning down from
    /// `y` (clamped into bounds) — the ground a falling object lands on.
    /// `nil` when the column is all air below `y` (off the map).
    public func groundLevel(atX x: Int, below y: Int) -> Int? {
        guard x >= 0, x < width else { return nil }
        var scan = max(0, min(y, height - 1))
        while scan < height {
            if mask[scan * width + x] != 0 { return scan }
            scan += 1
        }
        return nil
    }

    /// The surface y at column `x` nearest to `y`: if (x, y) is inside
    /// terrain, walks up to the first air cell's boundary; otherwise falls
    /// down to the ground. This is the spawn-snap: mobiles stand on the
    /// terrain surface regardless of which side of it the server's spawn
    /// point landed.
    public func surfaceLevel(atX x: Int, near y: Int) -> Int? {
        guard x >= 0, x < width else { return nil }
        let clamped = max(0, min(y, height - 1))
        if isSolid(x: x, y: clamped) {
            var scan = clamped
            while scan > 0, isSolid(x: x, y: scan - 1) {
                scan -= 1
            }
            return scan
        }
        return groundLevel(atX: x, below: clamped)
    }
}
