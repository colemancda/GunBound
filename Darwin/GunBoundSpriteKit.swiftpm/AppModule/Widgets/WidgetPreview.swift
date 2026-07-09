//
//  WidgetPreview.swift
//  GunBoundSpriteKit
//
//  Shared plumbing for the per-widget #Previews. `GunBoundClient`'s widgets
//  draw through the backend-agnostic `ClientRenderer`, not SwiftUI, so each
//  preview hosts a single `Widget` in its own SKScene — building it with real
//  textures loaded from the bundled assets, drawing it each frame via
//  `SpriteKitRenderer`, and forwarding mouse/touch/keyboard so the widget is
//  interactive in the canvas (click buttons, type into fields, drag the
//  scrollbar arrows).
//

import SwiftUI
import SpriteKit
import GunBound
import GunBoundClient

/// SwiftUI view that renders one `Widget` via SpriteKit. `build` receives a
/// renderer and asset library so the preview can load the widget's textures
/// (and a `LoadedFont`) exactly as a screen's `onEnter` would.
struct WidgetPreviewView: View {
    private let scene: WidgetPreviewScene

    init(
        width: CGFloat = 800,
        height: CGFloat = 600,
        build: @escaping (ClientRenderer, AssetLibrary) -> GunBoundClient.Widget
    ) {
        let scene = WidgetPreviewScene(size: CGSize(width: width, height: height), build: build)
        scene.scaleMode = .aspectFit
        self.scene = scene
    }

    var body: some View {
        SpriteView(scene: scene)
            .aspectRatio(scene.size, contentMode: .fit)
    }
}

/// Hosts a single `Widget`, driving its `update`/`draw` each frame and routing
/// input into its subtree via `dispatch`.
final class WidgetPreviewScene: SKScene {
    private let build: (ClientRenderer, AssetLibrary) -> GunBoundClient.Widget
    private var widget: GunBoundClient.Widget?
    private var renderer: SpriteKitRenderer?
    private var lastUpdateTime: TimeInterval?

    init(size: CGSize, build: @escaping (ClientRenderer, AssetLibrary) -> GunBoundClient.Widget) {
        self.build = build
        super.init(size: size)
        // A neutral backdrop so transparent widgets read clearly.
        backgroundColor = SKColor(white: 0.22, alpha: 1)
        anchorPoint = .zero
    }

    required init?(coder aDecoder: NSCoder) { fatalError() }

    override func didMove(to view: SKView) {
        super.didMove(to: view)
        let renderer = SpriteKitRenderer(scene: self)
        let assets = AssetLibrary(directory: previewAssetsDirectory())
        self.renderer = renderer
        self.widget = build(renderer, assets)
    }

    override func update(_ currentTime: TimeInterval) {
        defer { lastUpdateTime = currentTime }
        guard let renderer, let widget else { return }
        let deltaTime = lastUpdateTime.map { currentTime - $0 } ?? 0
        widget.update(deltaTime: deltaTime)
        renderer.clear()
        widget.draw(renderer)
        renderer.present()
    }

    /// Scene point (origin bottom-left, y up) → `Rect` convention (origin
    /// top-left, y down) that widgets hit-test in.
    private func point(_ location: CGPoint) -> (x: Float, y: Float) {
        (Float(location.x), Float(size.height - location.y))
    }

    #if canImport(UIKit)
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let location = touches.first?.location(in: self) else { return }
        let p = point(location)
        _ = widget?.dispatch(.pointerDown(x: p.x, y: p.y))
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let location = touches.first?.location(in: self) else { return }
        let p = point(location)
        _ = widget?.dispatch(.pointerMoved(x: p.x, y: p.y))
    }
    #endif

    #if os(macOS)
    override func mouseDown(with event: NSEvent) {
        let p = point(event.location(in: self))
        _ = widget?.dispatch(.pointerDown(x: p.x, y: p.y))
    }

    override func mouseMoved(with event: NSEvent) {
        let p = point(event.location(in: self))
        _ = widget?.dispatch(.pointerMoved(x: p.x, y: p.y))
    }

    override func mouseDragged(with event: NSEvent) {
        let p = point(event.location(in: self))
        _ = widget?.dispatch(.pointerMoved(x: p.x, y: p.y))
    }

    override func keyDown(with event: NSEvent) {
        // Same reduction the game scene makes: Return submits, backspace/
        // arrows edit, other printable input becomes text.
        switch event.keyCode {
        case 36, 76:
            _ = widget?.dispatch(.activate)
        case 51:
            _ = widget?.dispatch(.key(.backspace))
        case 123:
            _ = widget?.dispatch(.key(.left))
        case 124:
            _ = widget?.dispatch(.key(.right))
        default:
            if let characters = event.characters, !characters.isEmpty,
               characters.unicodeScalars.allSatisfy({ $0.value >= 0x20 }) {
                _ = widget?.dispatch(.text(characters))
            }
        }
    }
    #endif
}
