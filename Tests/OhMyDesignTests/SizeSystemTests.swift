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

    private func pixels(of image: CGImage) -> [UInt8] {
        let width = image.width
        let height = image.height
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        bytes.withUnsafeMutableBytes { buffer in
            let context = CGContext(
                data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                bytesPerRow: width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
            context?.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        return bytes
    }

    private func expectPixelIdentical(_ current: some View, _ legacy: some View, _ label: String) throws {
        for scheme in [ColorScheme.light, .dark] {
            let now = try self.render(current.controlSize(.regular).environment(\.colorScheme, scheme))
            let old = try self.render(legacy.environment(\.colorScheme, scheme))
            #expect(CGSize(width: now.width, height: now.height) == CGSize(width: old.width, height: old.height),
                    "\(label) \(scheme)：尺寸与旧实现不同")
            guard now.width == old.width, now.height == old.height else { continue }
            expectBitmapsEquivalent(self.pixels(of: now), self.pixels(of: old), maxChannelDelta: 1, "\(label) \(scheme)：像素与旧实现不同")
        }
    }

    private static let badgeVariants: [BadgeVariant] = [.info, .success, .warning, .danger, .neutral]

    @Test("可删除 Tag 五档：关闭钮不压住文字——label 区域与普通 Tag 逐像素一致")
    func removeButtonDoesNotOverlapLabel() throws {
        for controlSize in Self.ladder {
            let removable = try self.render(Tag("bug", color: .red, removable: true, onRemove: {}).controlSize(controlSize))
            let plain = try self.render(Tag("bug", color: .red).controlSize(controlSize))
            #expect(removable.height == plain.height, "\(controlSize)：高度不同")
            guard removable.height == plain.height else { continue }
            let untouched = plain.width
                - Int(CoreControlMetrics.compactHorizontalPadding(for: controlSize))
                - Int(CoreControlMetrics.compactCornerRadius(for: controlSize).rounded(.up))
            let removablePixels = self.pixels(of: removable)
            let plainPixels = self.pixels(of: plain)
            var differing = 0
            for y in 0..<plain.height {
                for x in 0..<untouched {
                    for channel in 0..<4 where
                        removablePixels[(y * removable.width + x) * 4 + channel]
                        != plainPixels[(y * plain.width + x) * 4 + channel] {
                        differing += 1
                    }
                }
            }
            #expect(differing == 0, "\(controlSize)：label 区域（前 \(untouched) 列）有 \(differing) 个通道值被关闭钮改写")
        }
    }

    @Test(".regular 档 Badge 与接入尺寸体系前的实现（9a99845 原样拷贝）渲染尺寸一致（两条腿都跑）")
    func regularBadgeMatchesLegacySize() throws {
        for variant in Self.badgeVariants {
            for outlined in [false, true] {
                let now = try self.renderedSize(Badge("Beta", variant: variant, outlined: outlined).controlSize(.regular))
                let old = try self.renderedSize(LegacyBadge("Beta", variant: variant, outlined: outlined))
                #expect(now == old, "\(variant) outlined=\(outlined)：\(now) ≠ \(old)")
            }
        }
    }

    @Test(
        ".regular 档 Badge 与旧实现逐像素一致（light / dark × 5 variant × 描边有无）",
        .enabled(
            if: assetCatalogIsCompiled,
            """
            跳过：bundle 里没有 Assets.car（SwiftPM native 腿），Badge 的 status 底色 / 描边取自 asset catalog，\
            在这条腿上解析为全透明，像素比对判不到颜色。本条在 iOS Simulator 腿 / swiftbuild 腿上跑；\
            native 腿由 regularBadgeMatchesLegacySize 兜尺寸。
            """
        )
    )
    func regularBadgeMatchesLegacyPixels() throws {
        for variant in Self.badgeVariants {
            for outlined in [false, true] {
                try self.expectPixelIdentical(
                    Badge("Beta", variant: variant, outlined: outlined),
                    LegacyBadge("Beta", variant: variant, outlined: outlined),
                    "Badge \(variant) outlined=\(outlined)"
                )
            }
        }
    }

    @Test(".regular 档普通 Tag 与旧实现（9a99845 原样拷贝）逐像素一致（Tag 只用调用方系统色，两条腿都跑）")
    func regularTagMatchesLegacyPixels() throws {
        try self.expectPixelIdentical(Tag("bug", color: .red), LegacyTag("bug", color: .red), "Tag Text")
        try self.expectPixelIdentical(
            Tag(color: .green) { SwiftUI.Label("verified", systemImage: "checkmark.seal.fill") },
            LegacyTag(color: .green) { SwiftUI.Label("verified", systemImage: "checkmark.seal.fill") },
            "Tag Label"
        )
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

// MARK: - 接入尺寸体系前的 Badge / Tag（取自 9a99845，仅改类型名与访问级别，作 .regular 档外观基准）

private struct LegacyBadge<Label: View>: View {
    init(
        variant: BadgeVariant = .neutral,
        outlined: Bool = false,
        @ViewBuilder label: () -> Label
    ) {
        self.variant = variant
        self.outlined = outlined
        self.label = label()
    }

    var body: some View {
        let shape = Capsule(style: .continuous)
        return self.label
            .coreFont(.footnote)
            .padding(.horizontal, CoreSpacing.sm)
            .padding(.vertical, CoreSpacing.xs)
            .background {
                shape.fill(Self.backgroundColor(for: self.variant))
            }
            .overlay {
                if self.outlined {
                    shape.strokeBorder(Self.borderColor(for: self.variant), lineWidth: CoreBorderWidth.thin)
                }
            }
            .accessibilityElement(children: .combine)
            .clipShape(shape)
    }

    let variant: BadgeVariant
    let outlined: Bool
    let label: Label
}

private extension LegacyBadge where Label == Text {
    init(_ text: String, variant: BadgeVariant = .neutral, outlined: Bool = false) {
        self.init(variant: variant, outlined: outlined) {
            Text(text)
        }
    }
}

private extension LegacyBadge {
    static func backgroundColor(for variant: BadgeVariant) -> Color {
        switch variant {
        case .info: .statusAccentSubtle
        case .success: .statusSuccessSubtle
        case .warning: .statusAttentionSubtle
        case .danger: .statusDangerSubtle
        case .neutral: .secondaryFill
        }
    }

    static func borderColor(for variant: BadgeVariant) -> Color {
        switch variant {
        case .info: .statusAccentBorder
        case .success: .statusSuccessBorder
        case .warning: .statusAttentionBorder
        case .danger: .statusDangerBorder
        case .neutral: .borderMuted
        }
    }
}

private struct LegacyTag<Label: View>: View {
    init(
        color: Color,
        removable: Bool = false,
        onRemove: (() -> Void)? = nil,
        @ViewBuilder label: () -> Label
    ) {
        self.color = color
        self.removable = removable
        self.onRemove = onRemove
        self.label = label()
    }

    var body: some View {
        HStack(spacing: CoreSpacing.xs) {
            self.label
                .coreFont(.footnote)
                .foregroundStyle(self.color)

            if self.removable {
                Button {
                    self.onRemove?()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: Self.removeIconSize))
                        .foregroundStyle(self.color)
                }
                .buttonStyle(.plain)
                .disabled(self.onRemove == nil)
                .padding(CoreSpacing.xxs)
                .padding(CoreSpacing.md)
                .contentShape(Rectangle())
                .padding(-CoreSpacing.md)
                .accessibilityLabel(Text("Remove tag", bundle: .module))
            }
        }
        .padding(.horizontal, CoreSpacing.sm)
        .padding(.vertical, CoreSpacing.xs)
        .background(
            CoreShape.rounded(CoreRadius.small)
                .fill(self.color.opacity(Self.backgroundOpacity))
        )
    }

    private static var backgroundOpacity: Double { 0.12 }

    private static var removeIconSize: CGFloat { CoreControlMetrics.iconSize(for: .small) }

    private let color: Color
    private let removable: Bool
    private let onRemove: (() -> Void)?
    private let label: Label
}

private extension LegacyTag where Label == Text {
    init(
        _ text: String,
        color: Color,
        removable: Bool = false,
        onRemove: (() -> Void)? = nil
    ) {
        self.init(color: color, removable: removable, onRemove: onRemove) {
            Text(text)
        }
    }
}
