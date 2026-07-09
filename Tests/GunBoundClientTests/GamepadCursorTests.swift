import Foundation
import Testing
@testable import GunBound
@testable import GunBoundClient

@Suite @MainActor
struct GamepadCursorTests {

    @Test func stickMovesCursorByVelocityTimesDelta() {
        let driver = GamepadCursor()
        driver.speed = 100
        var position: (x: Float, y: Float) = (400, 300)

        // Full right deflection for 0.5s → +50px in x; emits a pointer move.
        let events = driver.update(stickX: 1, stickY: 0, click: false, deltaTime: 0.5, position: &position)
        #expect(position.x == 450)
        #expect(position.y == 300)
        #expect(events == [.pointerMoved(x: 450, y: 300)])
    }

    @Test func deadzoneIgnoresRestingStick() {
        let driver = GamepadCursor()
        driver.deadzone = 0.2
        var position: (x: Float, y: Float) = (400, 300)

        let events = driver.update(stickX: 0.1, stickY: -0.1, click: false, deltaTime: 1, position: &position)
        #expect(position == (400, 300))
        #expect(events.isEmpty)
        #expect(!driver.didMove)
    }

    @Test func movementClampsToBounds() {
        let driver = GamepadCursor()
        driver.speed = 10_000
        driver.bounds = (800, 600)
        var position: (x: Float, y: Float) = (790, 10)

        _ = driver.update(stickX: 1, stickY: -1, click: false, deltaTime: 1, position: &position)
        #expect(position.x == 800)  // clamped at right edge
        #expect(position.y == 0)    // clamped at top edge
    }

    @Test func clickFiresOnPressEdgeOnly() {
        let driver = GamepadCursor()
        var position: (x: Float, y: Float) = (120, 80)

        // Press: one pointer-down at the cursor.
        var events = driver.update(stickX: 0, stickY: 0, click: true, deltaTime: 0.1, position: &position)
        #expect(events == [.pointerDown(x: 120, y: 80)])

        // Held: no repeat.
        events = driver.update(stickX: 0, stickY: 0, click: true, deltaTime: 0.1, position: &position)
        #expect(events.isEmpty)

        // Release then press again: fires once more.
        _ = driver.update(stickX: 0, stickY: 0, click: false, deltaTime: 0.1, position: &position)
        events = driver.update(stickX: 0, stickY: 0, click: true, deltaTime: 0.1, position: &position)
        #expect(events == [.pointerDown(x: 120, y: 80)])
    }

    @Test func moveAndClickComeTogether() {
        let driver = GamepadCursor()
        driver.speed = 100
        var position: (x: Float, y: Float) = (0, 0)

        let events = driver.update(stickX: 0, stickY: 1, click: true, deltaTime: 1, position: &position)
        #expect(position == (0, 100))
        #expect(events == [.pointerMoved(x: 0, y: 100), .pointerDown(x: 0, y: 100)])
    }
}
