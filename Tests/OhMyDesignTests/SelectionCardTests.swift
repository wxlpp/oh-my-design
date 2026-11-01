@testable import OhMyDesign
import SwiftUI
import Testing

@MainActor
struct SelectionCardTests {
    @Test func selectionReplacesValueWithoutClearingOnRepeat() {
        var value = "inspiration"
        var writes = 0
        let binding = Binding(get: { value }, set: { value = $0; writes += 1 })
        SelectionCardAction.select("focus", selection: binding, isEnabled: true)
        #expect(value == "focus")
        SelectionCardAction.select("focus", selection: binding, isEnabled: true)
        #expect(value == "focus")
        #expect(writes == 1)
    }

    @Test func disabledSelectionPreservesBinding() {
        var value = "inspiration"
        let binding = Binding(get: { value }, set: { value = $0 })
        SelectionCardAction.select("focus", selection: binding, isEnabled: false)
        #expect(value == "inspiration")
    }
}
