import SwiftUI
import Testing
@testable import OhMyDesign

@Suite("AnchoredBadge")
@MainActor
struct AnchoredBadgeTests {
    @Test("count 超过 max 显示 max+，未超过显示原值")
    func countCapsAtMax() {
        #expect(AnchoredBadgeContent.count(120, max: 99).countText == "99+")
        #expect(AnchoredBadgeContent.count(99, max: 99).countText == "99")
        #expect(AnchoredBadgeContent.count(7, max: 9).countText == "7")
        #expect(AnchoredBadgeContent.count(10, max: 9).countText == "9+")
    }

    @Test("count 的 max 默认 99")
    func countDefaultMax() {
        #expect(AnchoredBadgeContent.count(100) == .count(100, max: 99))
        #expect(AnchoredBadgeContent.count(100).countText == "99+")
    }

    @Test("max 小于 1 时按 1 处理，不渲染出负数或 0+")
    func nonPositiveMaxClampsToOne() {
        #expect(AnchoredBadgeContent.count(5, max: 0).countText == "1+")
        #expect(AnchoredBadgeContent.count(5, max: -2).countText == "1+")
        #expect(AnchoredBadgeContent.count(1, max: 0).countText == "1")
    }

    @Test("count ≤ 0 不显示")
    func nonPositiveCountIsHidden() {
        #expect(AnchoredBadgeContent.count(0, max: 99).isVisible == false)
        #expect(AnchoredBadgeContent.count(-3, max: 99).isVisible == false)
        #expect(AnchoredBadgeContent.count(1, max: 99).isVisible)
    }

    @Test("dot 显示且不带计数文字")
    func dotIsVisibleWithoutText() {
        #expect(AnchoredBadgeContent.dot.isVisible)
        #expect(AnchoredBadgeContent.dot.countText == nil)
    }

    @Test("text 以本地化键承载，空键不显示")
    func textIsLocalizedKeyAndEmptyIsHidden() {
        #expect(AnchoredBadgeContent.text("NEW").isVisible)
        #expect(AnchoredBadgeContent.text("").isVisible == false)
        #expect(AnchoredBadgeContent.text("NEW") == .text(LocalizedStringKey("NEW")))
    }

    @Test("矩形宿主：纵向中心落在角上，横向只伸进半个徽标高度，宽度增长朝外")
    func rectangleGeometryGrowsOutward() {
        let host = CGSize(width: 40, height: 40)
        let pill = CGSize(width: 36, height: 20)
        let topTrailing = AnchoredBadgeModifier.badgeOrigin(
            hostSize: host, badgeSize: pill, placement: .topTrailing, hostShape: .rectangle
        )
        #expect(topTrailing == CGPoint(x: 30, y: -10))
        let wider = AnchoredBadgeModifier.badgeOrigin(
            hostSize: host, badgeSize: CGSize(width: 60, height: 20), placement: .topTrailing, hostShape: .rectangle
        )
        #expect(wider.x == topTrailing.x)

        let topLeading = AnchoredBadgeModifier.badgeOrigin(
            hostSize: host, badgeSize: pill, placement: .topLeading, hostShape: .rectangle
        )
        #expect(topLeading == CGPoint(x: -26, y: -10))
        #expect(topLeading.x + pill.width == 10)

        let bottomTrailing = AnchoredBadgeModifier.badgeOrigin(
            hostSize: host, badgeSize: pill, placement: .bottomTrailing, hostShape: .rectangle
        )
        #expect(bottomTrailing == CGPoint(x: 30, y: 30))
    }

    @Test("dot（宽 = 高）在矩形宿主上中心恰落在角上")
    func dotCenterSitsOnCorner() {
        let origin = AnchoredBadgeModifier.badgeOrigin(
            hostSize: CGSize(width: 40, height: 30),
            badgeSize: CGSize(width: 10, height: 10),
            placement: .bottomLeading,
            hostShape: .rectangle
        )
        #expect(origin.x + 5 == 0)
        #expect(origin.y + 5 == 30)
    }

    @Test("圆形宿主：锚点在内切圆 45° 点，距边框角 ≈ 0.146·d")
    func circleAnchorsAtFortyFiveDegrees() {
        let inset = AnchoredBadgeHostShape.circle.cornerInset(hostSize: CGSize(width: 100, height: 100))
        #expect(abs(inset.width - 14.6447) < 0.001)
        #expect(abs(inset.height - 14.6447) < 0.001)

        let offCenter = AnchoredBadgeHostShape.circle.cornerInset(hostSize: CGSize(width: 120, height: 100))
        #expect(abs(offCenter.width - (10 + 14.6447)) < 0.001)
        #expect(abs(offCenter.height - 14.6447) < 0.001)

        #expect(AnchoredBadgeHostShape.rectangle.cornerInset(hostSize: CGSize(width: 100, height: 100)) == .zero)

        let dot = AnchoredBadgeModifier.badgeOrigin(
            hostSize: CGSize(width: 100, height: 100),
            badgeSize: CGSize(width: 10, height: 10),
            placement: .topTrailing,
            hostShape: .circle
        )
        let center = CGPoint(x: dot.x + 5, y: dot.y + 5)
        let radius = ((center.x - 50) * (center.x - 50) + (center.y - 50) * (center.y - 50)).squareRoot()
        #expect(abs(radius - 50) < 0.001)
    }

    @Test("取色：badgeFill 底 + contentOnEmphasis 前景，badgeFill 解析为不透明的系统红")
    func colorsAreSystemRedBadgeFill() {
        #expect(AnchoredBadgeModifier.fill == Color.badgeFill)
        #expect(AnchoredBadgeModifier.foreground == Color.contentOnEmphasis)
        #expect(AnchoredBadgeModifier.fill != Color.accent)

        let environment = EnvironmentValues()
        let resolved = Color.badgeFill.resolve(in: environment)
        let systemRed = Color.systemRed.resolve(in: environment)
        #expect(resolved == systemRed)
        #expect(resolved.opacity == 1)
        #expect(resolved.red > 0.8)
        #expect(resolved.green < 0.4)
        #expect(resolved.blue < 0.4)
    }

    @Test("accessibilityText：显示时给出朗读文本，不显示时为 nil")
    func accessibilityTextOnlyWhenVisible() {
        #expect(AnchoredBadgeContent.count(120, max: 99).accessibilityText == Text(verbatim: "99+"))
        #expect(AnchoredBadgeContent.count(3, max: 99).accessibilityText == Text(verbatim: "3"))
        #expect(AnchoredBadgeContent.text("NEW").accessibilityText == Text("NEW"))
        #expect(AnchoredBadgeContent.dot.accessibilityText == Text(AnchoredBadgeContent.newChrome))
        #expect(AnchoredBadgeContent.count(0, max: 99).accessibilityText == nil)
        #expect(AnchoredBadgeContent.text("").accessibilityText == nil)
    }

    @Test("红点的 chrome 文案走模块 bundle 的 LocalizedStringResource")
    func dotChromeResolvesFromModuleBundle() {
        #expect(AnchoredBadgeContent.newChrome.key == "New")
        #expect(Bundle.module.localizedString(forKey: "New", value: "<missing>", table: nil) == "New")
        #expect(String(localized: AnchoredBadgeContent.newChrome) == "New")
    }
}
