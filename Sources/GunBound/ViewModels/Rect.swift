/// A platform-agnostic rectangle used by view models for hit-testing/layout
/// state, so that state doesn't need to depend on any rendering framework's
/// own rect type (e.g. SDL's `SDL_FRect`). Views compute these from loaded
/// texture sizes and hand them to the corresponding view model.
public struct Rect: Equatable, Sendable {
    public var x: Float
    public var y: Float
    public var width: Float
    public var height: Float

    public init(x: Float, y: Float, width: Float, height: Float) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    public static let zero = Rect(x: 0, y: 0, width: 0, height: 0)

    public func contains(x px: Float, y py: Float) -> Bool {
        px >= x && px <= x + width && py >= y && py <= y + height
    }
}
