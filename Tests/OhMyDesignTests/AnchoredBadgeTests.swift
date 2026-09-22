import SwiftUI
import Testing
@testable import OhMyDesign

@Suite("AnchoredBadge")
@MainActor
struct AnchoredBadgeTests {
    @Test("count 超过 max 显示 max+，未超过显示原值")
    func countCapsAtMax() {
        #expect(AnchoredBadgeContent.count(120, max: 99).displayText == "99+")
        #expect(AnchoredBadgeContent.count(99, max: 99).displayText == "99")
        #expect(AnchoredBadgeContent.count(7, max: 9).displayText == "7")
        #expect(AnchoredBadgeContent.count(10, max: 9).displayText == "9+")
    }

    @Test("count 的 max 默认 99")
    func countDefaultMax() {
        #expect(AnchoredBadgeContent.count(100) == .count(100, max: 99))
        #expect(AnchoredBadgeContent.count(100).displayText == "99+")
    }

    @Test("max 小于 1 时按 1 处理，不渲染出负数或 0+")
    func nonPositiveMaxClampsToOne() {
        #expect(AnchoredBadgeContent.count(5, max: 0).displayText == "1+")
        #expect(AnchoredBadgeContent.count(5, max: -2).displayText == "1+")
        #expect(AnchoredBadgeContent.count(1, max: 0).displayText == "1")
    }

    @Test("count ≤ 0 不显示")
    func nonPositiveCountIsHidden() {
        #expect(AnchoredBadgeContent.count(0, max: 99).isVisible == false)
        #expect(AnchoredBadgeContent.count(-3, max: 99).isVisible == false)
        #expect(AnchoredBadgeContent.count(1, max: 99).isVisible)
    }

    @Test("dot 显示且不带文字")
    func dotIsVisibleWithoutText() {
        #expect(AnchoredBadgeContent.dot.isVisible)
        #expect(AnchoredBadgeContent.dot.displayText == nil)
    }

    @Test("text 原样显示，空串不显示")
    func textIsVerbatimAndEmptyIsHidden() {
        #expect(AnchoredBadgeContent.text("NEW").displayText == "NEW")
        #expect(AnchoredBadgeContent.text("NEW").isVisible)
        #expect(AnchoredBadgeContent.text("").isVisible == false)
    }

    @Test("placement 决定对齐角")
    func placementMapsToAlignment() {
        #expect(AnchoredBadgePlacement.topTrailing.alignment == .topTrailing)
        #expect(AnchoredBadgePlacement.topLeading.alignment == .topLeading)
        #expect(AnchoredBadgePlacement.bottomTrailing.alignment == .bottomTrailing)
        #expect(AnchoredBadgePlacement.bottomLeading.alignment == .bottomLeading)
        #expect(AnchoredBadgePlacement.allCases.count == 4)
    }

    @Test("取色固定为 statusDangerEmphasis + contentOnEmphasis，不跟随 accent")
    func colorsAreFixedDangerEmphasis() {
        #expect(AnchoredBadgeModifier.fill == Color.statusDangerEmphasis)
        #expect(AnchoredBadgeModifier.foreground == Color.contentOnEmphasis)
        #expect(AnchoredBadgeModifier.fill != Color.accent)
    }

    @Test("计数并入宿主可访问值；不显示时不追加")
    func accessibilityValueMergesIntoHost() {
        #expect(AnchoredBadgeContent.count(120, max: 99).accessibilityValueText == "99+")
        #expect(AnchoredBadgeContent.count(3, max: 99).accessibilityValueText == "3")
        #expect(AnchoredBadgeContent.text("NEW").accessibilityValueText == "NEW")
        #expect(AnchoredBadgeContent.count(0, max: 99).accessibilityValueText == nil)
        #expect(AnchoredBadgeContent.text("").accessibilityValueText == nil)
        let dot = AnchoredBadgeContent.dot.accessibilityValueText
        #expect(dot?.isEmpty == false)
    }
}
