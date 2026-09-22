import SwiftUI
import Testing
@testable import OhMyDesign

@Suite("尺寸体系：Badge / Tag / Avatar 跟随 controlSize")
@MainActor
struct SizeSystemTests {
    private static let ladder: [ControlSize] = [.mini, .small, .regular, .large, .extraLarge]

    private func renderedSize(_ view: some View) -> CGSize {
        let renderer = ImageRenderer(content: view.dynamicTypeSize(.large))
        renderer.scale = 1
        guard let image = renderer.cgImage else { return .zero }
        return CGSize(width: image.width, height: image.height)
    }

    private func sizes(_ make: () -> some View) -> [CGSize] {
        let content = make()
        return Self.ladder.map { self.renderedSize(content.controlSize($0)) }
    }

    private func expectStrictlyIncreasing(_ sizes: [CGSize], _ label: String) {
        for (lower, upper) in zip(sizes, sizes.dropFirst()) {
            #expect(upper.width > lower.width, "\(label) 宽度未随档严格递增：\(sizes)")
            #expect(upper.height > lower.height, "\(label) 高度未随档严格递增：\(sizes)")
        }
    }

    // MARK: - Badge / Tag

    @Test("Badge 五档渲染尺寸严格单调递增")
    func badgeScalesWithControlSize() {
        self.expectStrictlyIncreasing(self.sizes { Badge("Beta", variant: .info) }, "Badge")
    }

    @Test("Tag 五档渲染尺寸严格单调递增")
    func tagScalesWithControlSize() {
        self.expectStrictlyIncreasing(self.sizes { Tag("bug", color: .red) }, "Tag")
    }

    @Test("可删除 Tag 五档渲染尺寸严格单调递增，且关闭钮让宽度增量随档变大")
    func removableTagScalesWithControlSize() {
        let removable = self.sizes { Tag("bug", color: .red, removable: true, onRemove: {}) }
        let plain = self.sizes { Tag("bug", color: .red) }
        self.expectStrictlyIncreasing(removable, "removable Tag")
        let buttonWidths = zip(removable, plain).map { $0.width - $1.width }
        for (lower, upper) in zip(buttonWidths, buttonWidths.dropFirst()) {
            #expect(upper > lower, "关闭钮占宽未随档递增：\(buttonWidths)")
        }
    }

    // MARK: - Avatar

    @Test("Avatar .automatic 五档边长等于 avatarDiameter 且严格递增")
    func avatarAutomaticFollowsDiameterTable() {
        let sizes = self.sizes { Avatar(name: "Evan") }
        self.expectStrictlyIncreasing(sizes, "Avatar")
        for (controlSize, size) in zip(Self.ladder, sizes) {
            let diameter = CoreControlMetrics.avatarDiameter(for: controlSize)
            #expect(size == CGSize(width: diameter, height: diameter), "\(controlSize)：\(size)")
        }
    }

    @Test("Avatar .fixed(100) 得到 100pt，且不随 controlSize 变")
    func avatarFixedIgnoresControlSize() {
        let sizes = self.sizes { Avatar(name: "Evan", size: .fixed(100)) }
        for size in sizes {
            #expect(size == CGSize(width: 100, height: 100), "\(sizes)")
        }
    }

    @Test("外部 .frame 不再拉伸 Avatar")
    func avatarIsNotStretchedByOuterFrame() {
        let widened = Avatar(name: "Evan", size: .fixed(40))
            .frame(width: 120)
            .fixedSize(horizontal: false, vertical: true)
        #expect(self.renderedSize(widened) == CGSize(width: 120, height: 40), "外部给 120pt 宽时高度被连带拉伸")
        let inner = self.renderedSize(Avatar(name: "Evan", size: .fixed(40)).fixedSize())
        #expect(inner == CGSize(width: 40, height: 40))
    }

    @Test("AvatarSize 缺省 .automatic；.fixed 负值按 0 处理")
    func avatarSizeDefaultsAndClamping() {
        #expect(Avatar(name: "A").size == .automatic)
        #expect(AvatarSize.fixed(-8).diameter(for: .regular) == 0)
        #expect(AvatarSize.fixed(64).diameter(for: .mini) == 64)
        #expect(AvatarSize.automatic.diameter(for: .large) == CoreControlMetrics.avatarDiameter(for: .large))
    }

    // MARK: - AvatarGroup

    @Test("AvatarGroup 内 Avatar 与组尺寸同源：五档宽度等于同档独立 Avatar 与 avatarDiameter")
    func avatarGroupSharesDiameterTable() {
        for layout in [AvatarGroupLayout.overlapped, .spaced, .grid] {
            let grouped = self.sizes { AvatarGroup(max: 1, layout: layout) { Avatar(name: "Evan") } }
            let single = self.sizes { Avatar(name: "Evan") }
            for (index, controlSize) in Self.ladder.enumerated() {
                let diameter = CoreControlMetrics.avatarDiameter(for: controlSize)
                #expect(grouped[index].width == diameter, "\(layout) \(controlSize)：\(grouped[index])")
                #expect(grouped[index] == single[index], "\(layout) \(controlSize)")
            }
        }
    }

    @Test("AvatarGroup countOnly 徽标直径同表")
    func avatarGroupCountBadgeSharesDiameterTable() {
        let sizes = self.sizes { AvatarGroup(layout: .countOnly) { Avatar(name: "A"); Avatar(name: "B") } }
        for (controlSize, size) in zip(Self.ladder, sizes) {
            let diameter = CoreControlMetrics.avatarDiameter(for: controlSize)
            #expect(size == CGSize(width: diameter, height: diameter), "\(controlSize)：\(size)")
        }
    }
}

@Suite("CoreControlMetrics：紧凑 chip 与头像查询")
struct CoreControlMetricsCompactTests {
    private static let ladder: [ControlSize] = [.mini, .small, .regular, .large, .extraLarge]

    private func expectStrictlyIncreasing(_ values: [CGFloat], _ label: String) {
        for (lower, upper) in zip(values, values.dropFirst()) {
            #expect(upper > lower, "\(label) 未严格递增：\(values)")
        }
    }

    private func expectNonDecreasing(_ values: [CGFloat], _ label: String) {
        for (lower, upper) in zip(values, values.dropFirst()) {
            #expect(upper >= lower, "\(label) 出现递减：\(values)")
        }
    }

    @Test(".regular 档紧凑取值与接入尺寸体系前的 Badge / Tag 一致")
    func regularMatchesPreviousChipMetrics() {
        #expect(CoreControlMetrics.compactFontToken(for: .regular) == .footnote)
        #expect(CoreControlMetrics.compactHorizontalPadding(for: .regular) == CoreSpacing.sm)
        #expect(CoreControlMetrics.compactVerticalPadding(for: .regular) == CoreSpacing.xs)
        #expect(CoreControlMetrics.compactIconSize(for: .regular) == CoreControlMetrics.iconSize(for: .small))
    }

    @Test("紧凑查询五档单调")
    func compactLaddersAreMonotonic() {
        self.expectStrictlyIncreasing(Self.ladder.map(CoreControlMetrics.compactIconSize(for:)), "compactIconSize")
        self.expectStrictlyIncreasing(Self.ladder.map(CoreControlMetrics.compactHorizontalPadding(for:)), "compactHorizontalPadding")
        self.expectNonDecreasing(Self.ladder.map(CoreControlMetrics.compactVerticalPadding(for:)), "compactVerticalPadding")
        let fonts = Self.ladder.map(CoreControlMetrics.compactFontToken(for:))
        #expect(Set(fonts).count == Self.ladder.count, "五档字号须互异：\(fonts)")
    }

    @Test("头像直径表五档严格递增，AvatarGroup 交叠量随档不减")
    func avatarLaddersAreMonotonic() {
        self.expectStrictlyIncreasing(Self.ladder.map(CoreControlMetrics.avatarDiameter(for:)), "avatarDiameter")
        self.expectNonDecreasing(Self.ladder.map { -CoreControlMetrics.avatarGroupOverlap(for: $0) }, "avatarGroupOverlap")
        for controlSize in Self.ladder {
            #expect(CoreControlMetrics.avatarGroupOverlap(for: controlSize) < 0)
        }
    }

    @Test("首字母字号随直径线性缩放")
    func initialFontScalesWithDiameter() {
        let small = CoreControlMetrics.avatarInitialFontSize(forDiameter: 24)
        let large = CoreControlMetrics.avatarInitialFontSize(forDiameter: 48)
        #expect(small > 0 && small < 24)
        #expect(large == small * 2)
    }
}
