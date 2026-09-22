import SwiftUI
import Testing
@testable import OhMyDesign

@Suite("尺寸体系：Badge / Tag / Avatar 跟随 controlSize")
@MainActor
struct SizeSystemTests {
    private static let ladder: [ControlSize] = [.mini, .small, .regular, .large, .extraLarge]

    private func render(_ view: some View) throws -> CGImage {
        let renderer = ImageRenderer(content: view.dynamicTypeSize(.large))
        renderer.scale = 1
        return try #require(renderer.cgImage, "ImageRenderer 未产出位图")
    }

    private func renderedSize(_ view: some View) throws -> CGSize {
        let image = try self.render(view)
        return CGSize(width: image.width, height: image.height)
    }

    private func sizes(_ make: () -> some View) throws -> [CGSize] {
        let content = make()
        return try Self.ladder.map { try self.renderedSize(content.controlSize($0)) }
    }

    private func opaqueBounds(of image: CGImage) -> CGRect? {
        let width = image.width
        let height = image.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let drawn: Bool = pixels.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(
                data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { return nil }
        var minX = width, minY = height, maxX = -1, maxY = -1
        for y in 0..<height {
            for x in 0..<width where pixels[(y * width + x) * 4 + 3] > 0 {
                minX = min(minX, x)
                maxX = max(maxX, x)
                minY = min(minY, y)
                maxY = max(maxY, y)
            }
        }
        guard maxX >= 0 else { return nil }
        return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
    }

    private func expectStrictlyIncreasing(_ sizes: [CGSize], _ label: String) {
        for (lower, upper) in zip(sizes, sizes.dropFirst()) {
            #expect(upper.width > lower.width, "\(label) 宽度未随档严格递增：\(sizes)")
            #expect(upper.height > lower.height, "\(label) 高度未随档严格递增：\(sizes)")
        }
    }

    private func expectEvenHeightRhythm(_ sizes: [CGSize], _ label: String) {
        self.expectStrictlyIncreasing(sizes, label)
        let steps = zip(sizes, sizes.dropFirst()).map { $1.height - $0.height }
        guard let smallest = steps.min(), let largest = steps.max(), smallest > 0 else { return }
        #expect(largest <= smallest * 2, "\(label) 高度步长不均（最大步长超过最小步长的 2 倍）：\(steps)")
    }

    // MARK: - Badge / Tag

    @Test("Badge 五档：宽高严格递增，且高度步长近似等距（最大步长 ≤ 最小步长 × 2）")
    func badgeScalesWithControlSize() throws {
        self.expectEvenHeightRhythm(try self.sizes { Badge("Beta", variant: .info, outlined: true) }, "Badge")
    }

    @Test("Tag 五档：宽高严格递增，且高度步长近似等距")
    func tagScalesWithControlSize() throws {
        self.expectEvenHeightRhythm(try self.sizes { Tag("bug", color: .red) }, "Tag")
    }

    @Test("可删除 Tag 五档：与普通 Tag 等高，且关闭钮占宽随档变大")
    func removableTagScalesWithControlSize() throws {
        let removable = try self.sizes { Tag("bug", color: .red, removable: true, onRemove: {}) }
        let plain = try self.sizes { Tag("bug", color: .red) }
        self.expectEvenHeightRhythm(removable, "removable Tag")
        for (index, controlSize) in Self.ladder.enumerated() {
            #expect(removable[index].height == plain[index].height,
                    "\(controlSize)：可删除 Tag 高 \(removable[index].height) ≠ 普通 Tag 高 \(plain[index].height)")
        }
        let buttonWidths = zip(removable, plain).map { $0.width - $1.width }
        for (lower, upper) in zip(buttonWidths, buttonWidths.dropFirst()) {
            #expect(upper > lower, "关闭钮占宽未随档递增：\(buttonWidths)")
        }
    }

    @Test(".regular 档 Badge / Tag 与接入尺寸体系前的写法渲染尺寸一致")
    func regularChipsMatchPreviousRecipe() throws {
        let badge = try self.renderedSize(Badge("Beta", variant: .info).controlSize(.regular))
        let oldBadge = try self.renderedSize(
            Text("Beta").coreFont(.footnote)
                .padding(.horizontal, CoreSpacing.sm)
                .padding(.vertical, CoreSpacing.xs)
                .background(Capsule(style: .continuous).fill(Color.contentPrimary))
        )
        #expect(badge == oldBadge)
        let tag = try self.renderedSize(Tag("bug", color: .red).controlSize(.regular))
        let oldTag = try self.renderedSize(
            HStack(spacing: CoreSpacing.xs) { Text("bug").coreFont(.footnote) }
                .padding(.horizontal, CoreSpacing.sm)
                .padding(.vertical, CoreSpacing.xs)
                .background(CoreShape.rounded(CoreRadius.small).fill(Color.red))
        )
        #expect(tag == oldTag)
    }

    // MARK: - Avatar

    @Test("Avatar .automatic 五档边长等于 avatarDiameter 且严格递增")
    func avatarAutomaticFollowsDiameterTable() throws {
        let sizes = try self.sizes { Avatar(name: "Evan") }
        self.expectStrictlyIncreasing(sizes, "Avatar")
        for (controlSize, size) in zip(Self.ladder, sizes) {
            let diameter = CoreControlMetrics.avatarDiameter(for: controlSize)
            #expect(size == CGSize(width: diameter, height: diameter), "\(controlSize)：\(size)")
        }
    }

    @Test("Avatar .fixed(100) 得到 100pt，且不随 controlSize 变")
    func avatarFixedIgnoresControlSize() throws {
        let sizes = try self.sizes { Avatar(name: "Evan", size: .fixed(100)) }
        for size in sizes {
            #expect(size == CGSize(width: 100, height: 100), "\(sizes)")
        }
    }

    @Test("外部 .frame 不再拉伸 Avatar：120pt 画框里只有居中的 40×40 不透明像素")
    func avatarIsNotStretchedByOuterFrame() throws {
        let image = try self.render(Avatar(name: "Evan", size: .fixed(40)).frame(width: 120, height: 120))
        #expect(CGSize(width: image.width, height: image.height) == CGSize(width: 120, height: 120))
        let bounds = try #require(self.opaqueBounds(of: image), "画框内没有任何不透明像素")
        #expect(bounds == CGRect(x: 40, y: 40, width: 40, height: 40), "不透明像素范围：\(bounds)")
    }

    @Test("AvatarSize：缺省 .automatic；.fixed 的 0 / 负值 / 非有限值一律按 0")
    func avatarSizeDefaultsAndSanitizing() {
        #expect(Avatar(name: "A").size == .automatic)
        #expect(AvatarSize.fixed(64).diameter(for: .mini) == 64)
        for value in [0, -8, CGFloat.infinity, -CGFloat.infinity, CGFloat.nan] {
            #expect(AvatarSize.fixed(value).diameter(for: .regular) == 0, "fixed(\(value))")
        }
        #expect(AvatarSize.automatic.diameter(for: .large) == CoreControlMetrics.avatarDiameter(for: .large))
    }

    // MARK: - AvatarGroup

    @Test("AvatarGroup 内 Avatar 与组尺寸同源：五档宽度等于同档独立 Avatar 与 avatarDiameter")
    func avatarGroupSharesDiameterTable() throws {
        for layout in [AvatarGroupLayout.overlapped, .spaced, .grid] {
            let grouped = try self.sizes { AvatarGroup(max: 1, layout: layout) { Avatar(name: "Evan") } }
            let single = try self.sizes { Avatar(name: "Evan") }
            for (index, controlSize) in Self.ladder.enumerated() {
                let diameter = CoreControlMetrics.avatarDiameter(for: controlSize)
                #expect(grouped[index].width == diameter, "\(layout) \(controlSize)：\(grouped[index])")
                #expect(grouped[index] == single[index], "\(layout) \(controlSize)")
            }
        }
    }

    @Test("AvatarGroup 多头像 + 溢出徽标：交叠量 = 直径 / 4，徽标直径同表")
    func avatarGroupMultiAvatarGeometry() throws {
        let overlapped = try self.sizes {
            AvatarGroup(max: 2) { Avatar(name: "A"); Avatar(name: "B"); Avatar(name: "C") }
        }
        let spaced = try self.sizes {
            AvatarGroup(max: 2, layout: .spaced) { Avatar(name: "A"); Avatar(name: "B"); Avatar(name: "C") }
        }
        for (index, controlSize) in Self.ladder.enumerated() {
            let diameter = CoreControlMetrics.avatarDiameter(for: controlSize)
            #expect(overlapped[index] == CGSize(width: diameter * 3 - diameter / 2, height: diameter),
                    "overlapped \(controlSize)：\(overlapped[index])")
            #expect(spaced[index] == CGSize(width: diameter * 3 + CoreSpacing.xxs * 2, height: diameter),
                    "spaced \(controlSize)：\(spaced[index])")
        }
    }

    @Test("AvatarGroup 不改写传入子视图：.fixed(64) 头像与非正方形自定义子视图保持原尺寸")
    func avatarGroupLeavesChildrenUntouched() throws {
        for controlSize in Self.ladder {
            let size = try self.renderedSize(
                AvatarGroup(max: 3, layout: .spaced) {
                    Avatar(name: "Evan", size: .fixed(64))
                    Rectangle().fill(Color.contentPrimary).frame(width: 30, height: 10)
                }
                .controlSize(controlSize)
            )
            #expect(size == CGSize(width: 64 + CoreSpacing.xxs + 30, height: 64), "\(controlSize)：\(size)")
        }
    }

    @Test("AvatarGroup countOnly 徽标直径同表")
    func avatarGroupCountBadgeSharesDiameterTable() throws {
        let sizes = try self.sizes { AvatarGroup(layout: .countOnly) { Avatar(name: "A"); Avatar(name: "B") } }
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

    @Test(".regular 档紧凑取值与接入尺寸体系前的 Badge / Tag / AvatarGroup 一致")
    func regularMatchesPreviousChipMetrics() {
        #expect(CoreControlMetrics.compactFontToken(for: .regular) == .footnote)
        #expect(CoreControlMetrics.compactHorizontalPadding(for: .regular) == CoreSpacing.sm)
        #expect(CoreControlMetrics.compactVerticalPadding(for: .regular) == CoreSpacing.xs)
        #expect(CoreControlMetrics.compactIconSize(for: .regular) == CoreControlMetrics.iconSize(for: .small))
        #expect(CoreControlMetrics.compactMinHeight(for: .regular) == nil)
        #expect(CoreControlMetrics.compactCornerRadius(for: .regular) == CoreRadius.small)
        #expect(CoreControlMetrics.avatarCountFontToken(for: .regular) == .caption)
        #expect(CoreControlMetrics.avatarGroupOverlap(forDiameter: CoreControlMetrics.avatarDiameter(for: .regular)) == -8)
    }

    @Test("紧凑查询五档单调；mini 纵向 padding 非 0（outlined Badge 不贴描边）")
    func compactLaddersAreMonotonic() {
        self.expectStrictlyIncreasing(Self.ladder.map(CoreControlMetrics.compactIconSize(for:)), "compactIconSize")
        self.expectStrictlyIncreasing(Self.ladder.map(CoreControlMetrics.compactHorizontalPadding(for:)), "compactHorizontalPadding")
        self.expectStrictlyIncreasing(Self.ladder.map(CoreControlMetrics.compactCornerRadius(for:)), "compactCornerRadius")
        self.expectNonDecreasing(Self.ladder.map(CoreControlMetrics.compactVerticalPadding(for:)), "compactVerticalPadding")
        #expect(CoreControlMetrics.compactVerticalPadding(for: .mini) > 0)
        let minHeights = Self.ladder.compactMap(CoreControlMetrics.compactMinHeight(for:))
        #expect(minHeights.count == 4, "除 .regular 外四档都应有最小高度：\(minHeights)")
        self.expectStrictlyIncreasing(minHeights, "compactMinHeight")
        let fonts = Self.ladder.map(CoreControlMetrics.compactFontToken(for:))
        #expect(Set(fonts).count == Self.ladder.count, "五档字号须互异：\(fonts)")
    }

    @Test("头像直径表五档严格递增；交叠量为直径的 1/4")
    func avatarLaddersAreMonotonic() {
        let diameters = Self.ladder.map(CoreControlMetrics.avatarDiameter(for:))
        self.expectStrictlyIncreasing(diameters, "avatarDiameter")
        for diameter in diameters {
            #expect(CoreControlMetrics.avatarGroupOverlap(forDiameter: diameter) == -diameter / 4)
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
