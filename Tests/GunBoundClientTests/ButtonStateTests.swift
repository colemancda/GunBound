import Foundation
import Testing
@testable import GunBound
@testable import GunBoundClient
import GunBoundFile

@Suite @MainActor
struct ButtonStateTests {

    @Test func statesMapToTheDocumentedFrames() {
        #expect(ButtonState.normal.frame == 0)
        #expect(ButtonState.hovered.frame == 1)
        #expect(ButtonState.pressed.frame == 2)
        #expect(ButtonState.disabled.frame == 3)
        #expect(ButtonState.selected.frame == 4)
    }

    private final class Tex: ClientTexture {
        let frame: Int
        init(_ frame: Int) { self.frame = frame }
    }

    /// A renderer that only has frames `0..<available`, returning `nil` for
    /// any higher frame — mimicking a sheet with fewer than five frames.
    private final class LimitedRenderer: ClientRenderer {
        let available: Int
        init(available: Int) { self.available = available }
        func texture(named name: String, frame frameIndex: Int, assets: AssetLibrary) -> ClientTexture? {
            frameIndex < available ? Tex(frameIndex) : nil
        }
        func texture(from frame: ImgFile.Frame) -> ClientTexture? { nil }
        func size(of texture: ClientTexture?) -> (width: Float, height: Float) { (10, 10) }
        func clear() {}
        func draw(_ texture: ClientTexture, in rect: Rect, tint: (r: UInt8, g: UInt8, b: UInt8)?, blend: ClientBlendMode, opacity: Float) {}
        func present() {}
    }

    private var noAssets: AssetLibrary {
        AssetLibrary(directory: URL(fileURLWithPath: "/nonexistent", isDirectory: true))
    }

    @Test func aFiveFrameSheetResolvesEveryState() {
        let sprite = ButtonSprite(name: "toggle.img", renderer: LimitedRenderer(available: 5), assets: noAssets)
        #expect((sprite.texture(for: .selected) as? Tex)?.frame == 4)
        #expect((sprite.texture(for: .disabled) as? Tex)?.frame == 3)
        #expect((sprite.texture(for: .normal) as? Tex)?.frame == 0)
    }

    @Test func aFourFrameSheetFallsBackToDefaultForSelected() {
        // A plain action button (frames 0…3) asked for `.selected` (frame 4)
        // gets the default frame instead of nothing.
        let sprite = ButtonSprite(name: "action.img", renderer: LimitedRenderer(available: 4), assets: noAssets)
        #expect((sprite.texture(for: .disabled) as? Tex)?.frame == 3)
        #expect((sprite.texture(for: .selected) as? Tex)?.frame == 0)
    }
}
