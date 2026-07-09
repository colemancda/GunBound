import Foundation
import Testing
@testable import GunBound
@testable import GunBoundClient

@Suite @MainActor
struct TextFieldWidgetTests {

    private func makeField() -> TextFieldWidget {
        TextFieldWidget(frame: Rect(x: 10, y: 10, width: 100, height: 20), font: nil)
    }

    @Test func focusOnClickInsideBlurOnClickOutside() {
        let field = makeField()
        var focusCount = 0
        field.onFocus = { focusCount += 1 }

        #expect(field.dispatch(.pointerDown(x: 20, y: 15)))  // inside → consume
        #expect(field.isFocused)
        #expect(focusCount == 1)

        #expect(!field.dispatch(.pointerDown(x: 200, y: 200)))  // outside → pass through
        #expect(!field.isFocused)
    }

    @Test func typingInsertsOnlyWhenFocused() {
        let field = makeField()
        // Unfocused: ignored.
        #expect(!field.dispatch(.text("a")))
        #expect(field.text.isEmpty)

        field.focus()
        #expect(field.dispatch(.text("h")))
        _ = field.dispatch(.text("i"))
        #expect(field.text == "hi")
    }

    @Test func backspaceDeletesLastCharacter() {
        let field = makeField()
        field.focus()
        field.setText("abc")
        #expect(field.dispatch(.key(.backspace)))
        #expect(field.text == "ab")
        // Backspacing an empty field is harmless.
        field.setText("")
        _ = field.dispatch(.key(.backspace))
        #expect(field.text.isEmpty)
    }

    @Test func maxLengthCaps() {
        let field = makeField()
        field.maxLength = 3
        field.focus()
        _ = field.dispatch(.text("abcdef"))
        #expect(field.text == "abc")
    }

    @Test func characterFilterRejectsDisallowed() {
        let field = makeField()
        field.characterFilter = { $0.isNumber }
        field.focus()
        _ = field.dispatch(.text("1a2b3"))
        #expect(field.text == "123")
    }

    @Test func newlinesNeverInserted() {
        let field = makeField()
        field.focus()
        _ = field.dispatch(.text("a\nb"))
        #expect(field.text == "ab")
    }

    @Test func enterSubmitsWhenFocused() {
        let field = makeField()
        var submits = 0
        field.onSubmit = { submits += 1 }

        #expect(!field.dispatch(.activate))  // not focused → ignored
        field.focus()
        #expect(field.dispatch(.activate))
        #expect(submits == 1)
    }

    @Test func onChangeFiresForEdits() {
        let field = makeField()
        var lastValue: String?
        field.onChange = { lastValue = $0 }
        field.focus()
        _ = field.dispatch(.text("x"))
        #expect(lastValue == "x")
        _ = field.dispatch(.key(.backspace))
        #expect(lastValue == "")
    }
}
