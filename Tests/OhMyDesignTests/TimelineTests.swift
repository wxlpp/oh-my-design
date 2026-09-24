import SwiftUI
import Testing
@testable import OhMyDesign

@Suite("Timeline")
@MainActor
struct TimelineTests {
    // MARK: - 节点状态 → 默认圆点颜色

    @Test(
        "nodeColor：StatusLevel 各档映射到对应 StatusColors token（浅色 warning 取 foreground，其余取 emphasis）",
        arguments: [
            (StatusLevel.info, ColorScheme.light, "status-accent-emphasis"),
            (StatusLevel.success, ColorScheme.light, "status-success-emphasis"),
            (StatusLevel.warning, ColorScheme.light, "status-attention-fg"),
            (StatusLevel.danger, ColorScheme.light, "status-danger-emphasis"),
            (StatusLevel.info, ColorScheme.dark, "status-accent-emphasis"),
            (StatusLevel.success, ColorScheme.dark, "status-success-emphasis"),
            (StatusLevel.warning, ColorScheme.dark, "status-attention-emphasis"),
            (StatusLevel.danger, ColorScheme.dark, "status-danger-emphasis"),
        ]
    )
    func nodeColorMapsToStatusColorsAsset(_ triple: (StatusLevel, ColorScheme, String)) {
        let (status, scheme, expectedAsset) = triple
        #expect(assetName(of: Timeline.nodeColor(for: status, in: scheme)) == expectedAsset)
    }

    // MARK: - 节点状态 → accessibility label 键（Phase 0 预登记）

    @Test(
        "accessibilityLabelKey：StatusLevel 各档映射到 Phase 0 预登记键",
        arguments: [
            (StatusLevel.info, "Info"),
            (StatusLevel.success, "Success"),
            (StatusLevel.warning, "Warning"),
            (StatusLevel.neutral, "Neutral"),
        ]
    )
    func accessibilityLabelKeyMapsDirectly(_ pair: (StatusLevel, String)) {
        let (status, expectedKey) = pair
        #expect(Timeline.accessibilityLabelKey(for: status) == expectedKey)
    }

    @Test("accessibilityLabelKey：danger 映射到 \"Error\"（非字面 \"Danger\"，对 VoiceOver 更清晰）")
    func accessibilityLabelKeyDangerMapsToError() {
        #expect(Timeline.accessibilityLabelKey(for: .danger) == "Error")
        #expect(Timeline.accessibilityLabelKey(for: .danger) != "Danger")
    }

    @Test("nodeColor：neutral 取 contentSecondary，不取资源色")
    func nodeColorNeutralUsesContentToken() {
        for scheme in [ColorScheme.light, .dark] {
            let color = Timeline.nodeColor(for: .neutral, in: scheme)
            #expect(color == Color.contentSecondary)
            #expect(assetName(of: color) == nil)
            var env = EnvironmentValues()
            env.colorScheme = scheme
            #expect(color.resolve(in: env).opacity > 0)
        }
    }

    // MARK: - TimelineItem：四个 init 的存储

    @Test("TimelineItem(status:content:)：默认圆点，status 原样保留，无标题")
    func defaultNodeInitStoresStatus() {
        let item = TimelineItem(status: .success) {
            Text(verbatim: "Done")
        }
        #expect(item.node == nil)
        #expect(item.status == .success)
        #expect(item.title == nil)
        #expect(item.step == nil)
    }

    @Test("TimelineItem(content:)：status 缺省为 .info")
    func defaultNodeInitDefaultsToInfo() {
        let item = TimelineItem {
            Text(verbatim: "Created")
        }
        #expect(item.status == .info)
    }

    @Test("TimelineItem(status:node:content:)：自定义节点非 nil；status 缺省为 nil（不播报）")
    func customNodeInitStoresNode() {
        let item = TimelineItem(status: .danger) {
            Image(systemName: "xmark.circle.fill")
        } content: {
            Text(verbatim: "Failed")
        }
        #expect(item.node != nil)
        #expect(item.status == .danger)
        let silent = TimelineItem {
            Image(systemName: "xmark.circle.fill")
        } content: {
            Text(verbatim: "Failed")
        }
        #expect(silent.status == nil)
    }

    @Test("TimelineItem(_:time:description:step:status:)：结构件与 step 原样保留")
    func structuredInitStoresParts() {
        let item = TimelineItem("Deployed", time: Text(verbatim: "2h"), description: "v2", step: 3, status: .warning)
        #expect(item.title != nil)
        #expect(item.time != nil)
        #expect(item.description != nil)
        #expect(item.step == 3)
        #expect(item.status == .warning)
        #expect(item.node == nil)
        let custom = TimelineItem("Deployed", step: 1) { Circle() } content: {}
        #expect(custom.node != nil)
        #expect(custom.status == nil)
        #expect(custom.step == 1)
    }

    // MARK: - TimelineLayout（`#60` 形态 D2）

    @Test("Timeline：layout 默认 .vertical")
    func timelineLayoutDefaultsToVertical() {
        let timeline = Timeline { TimelineItem(status: .info) { Text(verbatim: "A") } }
        #expect(timeline.layout == .vertical)
    }

    @Test("Timeline：layout 原样保留")
    func timelineStoresLayout() {
        for layout in [TimelineLayout.vertical, .alternate, .horizontal, .grouped] {
            let timeline = Timeline(layout: layout) { TimelineItem(status: .info) { Text(verbatim: "A") } }
            #expect(timeline.layout == layout)
        }
    }

    @Test("TimelineLayout：四个 case 互不相等（Equatable 不是恒真）")
    func timelineLayoutEquatableIsNotDegenerate() {
        let all: [TimelineLayout] = [.vertical, .alternate, .horizontal, .grouped]
        for (i, lhs) in all.enumerated() {
            for (j, rhs) in all.enumerated() where i != j {
                #expect(lhs != rhs, "\(lhs) 与 \(rhs) 不应相等")
            }
        }
    }

    @Test("Timeline：四种布局都能构造且 body 可求值（不 crash），空内容也可")
    func timelineAllLayoutsRender() {
        for layout in [TimelineLayout.vertical, .alternate, .horizontal, .grouped] {
            _ = Timeline(layout: layout) {
                TimelineItem(status: .info) { Text(verbatim: "A") }
                TimelineItem("B", status: .danger)
                Text(verbatim: "footer")
            }.body
            _ = Timeline(layout: layout) { EmptyView() }.body
        }
    }

    @Test("Timeline.alternateSlotWidth：三列几何的槽宽，且节点中心恰落在行中心")
    func timelineAlternateSlotWidth() {
        let fixed = Timeline.minimumNodeExtent + 2 * CoreSpacing.md

        let w = Timeline.alternateSlotWidth(forRowWidth: 320)
        #expect(w == (320 - fixed) / 2)
        #expect(w * 2 + fixed == 320)

        for rowWidth in [320.0, 390.0, 744.0, 1024.0] as [CGFloat] {
            let metrics = Timeline.alternateRowMetrics(forRowWidth: rowWidth)
            let rowCenter: CGFloat = rowWidth / 2
            #expect(metrics.nodeCenterX == rowCenter,
                    "行宽 \(rowWidth)：节点中心 \(metrics.nodeCenterX) 必须等于行中心 \(rowCenter)")
            let fixed = Timeline.minimumNodeExtent + 2 * CoreSpacing.md
            #expect(metrics.slotWidth * 2 + fixed == rowWidth)
        }

        for bad in [CGFloat.infinity, -CGFloat.infinity, CGFloat.nan] {
            let metrics = Timeline.alternateRowMetrics(forRowWidth: bad)
            #expect(metrics.slotWidth.isFinite, "槽宽必须有限，实际 \(metrics.slotWidth)")
            #expect(metrics.nodeCenterX.isFinite)
            #expect(metrics.rowWidth.isFinite)
            #expect(metrics.slotWidth >= 0)
        }

        #expect(Timeline.alternateSlotWidth(forRowWidth: 0) == 0)
        #expect(Timeline.alternateSlotWidth(forRowWidth: fixed) == 0)
        #expect(Timeline.alternateSlotWidth(forRowWidth: fixed - 1) == 0)
        #expect(Timeline.alternateSlotWidth(forRowWidth: -10) == 0)
        #expect(Timeline.alternateSlotWidth(forRowWidth: fixed + 2) > 0)
    }
}

// MARK: - 默认圆点：对比度与旧实现像素对照

@Suite(
    "Timeline 默认圆点取色",
    .enabled(
        if: assetCatalogIsCompiled,
        """
        跳过：bundle 里没有 Assets.car（SwiftPM native 腿），圆点取自 asset catalog，在这条腿上解析为全透明。\
        本 suite 在 iOS Simulator 腿上跑；native 腿由 nodeColor 的 asset 名映射判据兜。
        """
    )
)
@MainActor
struct TimelineNodeColorRenderTests {
    private static let levels: [StatusLevel] = [.info, .success, .warning, .danger, .neutral]

    private static func environment(_ scheme: ColorScheme) -> EnvironmentValues {
        var environment = EnvironmentValues()
        environment.colorScheme = scheme
        return environment
    }

    private static func composite(_ top: Color.Resolved, over bottom: Color.Resolved) -> [Double] {
        let alpha = Double(top.opacity)
        return zip([top.red, top.green, top.blue], [bottom.red, bottom.green, bottom.blue]).map { pair in
            Double(pair.0) * alpha + Double(pair.1) * (1 - alpha)
        }
    }

    private static func relativeLuminance(_ srgb: [Double]) -> Double {
        let linear = srgb.map { $0 <= 0.04045 ? $0 / 12.92 : pow(($0 + 0.055) / 1.055, 2.4) }
        return 0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2]
    }

    static func contrastRatio(of color: Color, on background: Color, in scheme: ColorScheme) -> Double {
        let environment = Self.environment(scheme)
        let backdrop = background.resolve(in: environment)
        let bottom = [Double(backdrop.red), Double(backdrop.green), Double(backdrop.blue)]
        let top = Self.composite(color.resolve(in: environment), over: backdrop)
        let lighter = max(Self.relativeLuminance(top), Self.relativeLuminance(bottom))
        let darker = min(Self.relativeLuminance(top), Self.relativeLuminance(bottom))
        return (lighter + 0.05) / (darker + 0.05)
    }

    private static let backgrounds: [(String, Color)] = [
        ("systemGroupedBackground", .systemGroupedBackground),
        ("systemBackground", .systemBackground),
        ("secondarySystemGroupedBackground", .secondarySystemGroupedBackground),
    ]

    @Test("浅色 warning 圆点对三种常见底色的非文本对比度 ≥ 3:1")
    func lightWarningDotMeetsNonTextContrast() {
        for (name, background) in Self.backgrounds {
            let ratio = Self.contrastRatio(of: Timeline.nodeColor(for: .warning, in: .light), on: background, in: .light)
            print("Timeline warning light on \(name): \(String(format: "%.2f", ratio)):1")
            #expect(ratio >= 3, "浅色 warning 圆点对 \(name) 只有 \(ratio):1")
        }
    }

    @Test("暗色 warning 圆点取色不变（对比度不回退）")
    func darkWarningDotIsUnchanged() {
        let environment = Self.environment(.dark)
        #expect(
            Timeline.nodeColor(for: .warning, in: .dark).resolve(in: environment)
                == Color.statusAttentionEmphasis.resolve(in: environment)
        )
        for (name, background) in Self.backgrounds {
            let ratio = Self.contrastRatio(of: Timeline.nodeColor(for: .warning, in: .dark), on: background, in: .dark)
            print("Timeline warning dark on \(name): \(String(format: "%.2f", ratio)):1")
        }
    }

    private func pixels(_ view: some View, scheme: ColorScheme) throws -> (width: Int, height: Int, bytes: [UInt8]) {
        let renderer = ImageRenderer(content: view.frame(width: 240).environment(\.colorScheme, scheme))
        renderer.scale = 1
        let image = try #require(renderer.cgImage, "ImageRenderer 未产出位图")
        var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
        bytes.withUnsafeMutableBytes { buffer in
            let context = CGContext(
                data: buffer.baseAddress, width: image.width, height: image.height, bitsPerComponent: 8,
                bytesPerRow: image.width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
            context?.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        }
        return (image.width, image.height, bytes)
    }

    private static func timeline(_ levels: [StatusLevel]) -> some View {
        Timeline {
            ForEach(Array(levels.enumerated()), id: \.offset) { _, level in
                TimelineItem(status: level) { Text(verbatim: "Event").coreFont(.callout) }
            }
        }
    }

    private static func legacyItems(_ levels: [StatusLevel]) -> [LegacyTimelineItem] {
        levels.map { level in LegacyTimelineItem(status: level) { Text(verbatim: "Event").coreFont(.callout) } }
    }

    @Test("暗色五档与旧实现（原样拷贝）在光栅化噪声内逐像素一致")
    func darkTimelineMatchesLegacy() throws {
        let levels: [StatusLevel] = Self.levels
        let now = try self.pixels(Self.timeline(levels), scheme: .dark)
        let old = try self.pixels(LegacyTimeline(items: Self.legacyItems(levels)), scheme: .dark)
        #expect(now.width == old.width && now.height == old.height)
        expectBitmapsEquivalent(now.bytes, old.bytes, maxChannelDelta: 1, "暗色 Timeline 与旧实现不同")
    }

    @Test("浅色 info / success / danger / neutral 与旧实现在光栅化噪声内逐像素一致")
    func lightNonWarningTimelineMatchesLegacy() throws {
        let levels: [StatusLevel] = [.info, .success, .danger, .neutral]
        let now = try self.pixels(Self.timeline(levels), scheme: .light)
        let old = try self.pixels(LegacyTimeline(items: Self.legacyItems(levels)), scheme: .light)
        #expect(now.width == old.width && now.height == old.height)
        expectBitmapsEquivalent(now.bytes, old.bytes, maxChannelDelta: 1, "浅色非 warning 档与旧实现不同")
    }

    @Test("浅色 warning 只有圆点方框内的像素变化")
    func lightWarningChangesOnlyTheDot() throws {
        let levels: [StatusLevel] = [.warning]
        let now = try self.pixels(Self.timeline(levels), scheme: .light)
        let old = try self.pixels(LegacyTimeline(items: Self.legacyItems(levels)), scheme: .light)
        #expect(now.width == old.width && now.height == old.height)
        guard now.width == old.width, now.height == old.height else { return }
        let inset = Int((Timeline.minimumNodeExtent - Timeline.nodeDiameter) / 2)
        let antialiasReach = 1
        let dot = (inset - antialiasReach)..<(inset + Int(Timeline.nodeDiameter) + antialiasReach)
        func split(_ bytes: [UInt8]) -> (inside: [UInt8], outside: [UInt8]) {
            var inside: [UInt8] = []
            var outside: [UInt8] = []
            for y in 0..<now.height {
                for x in 0..<now.width {
                    let offset = (y * now.width + x) * 4
                    if dot.contains(x), dot.contains(y) {
                        inside.append(contentsOf: bytes[offset..<offset + 4])
                    } else {
                        outside.append(contentsOf: bytes[offset..<offset + 4])
                    }
                }
            }
            return (inside, outside)
        }
        let a = split(now.bytes)
        let b = split(old.bytes)
        expectBitmapsEquivalent(a.outside, b.outside, maxChannelDelta: 1, "圆点方框以外与旧实现不同")
        expectBitmapsDiffer(a.inside, b.inside, "浅色 warning 圆点与旧实现相同")
    }
}

// MARK: - LegacyTimeline

private struct LegacyTimelineItem: Identifiable {
    let id = UUID()
    let status: StatusLevel
    let node: AnyView? = nil
    let content: AnyView

    init(status: StatusLevel, @ViewBuilder content: () -> some View) {
        self.status = status
        self.content = AnyView(content())
    }
}

private struct LegacyTimeline: View {
    let items: [LegacyTimelineItem]

    var body: some View {
        VStack(alignment: .leading, spacing: CoreSpacing.none) {
            ForEach(self.items) { item in
                LegacyTimelineRowView(item: item, isLast: item.id == self.items.last?.id)
            }
        }
    }

    static func nodeColor(for status: StatusLevel) -> Color {
        switch status {
        case .info: .statusAccentEmphasis
        case .success: .statusSuccessEmphasis
        case .warning: .statusAttentionEmphasis
        case .danger: .statusDangerEmphasis
        case .neutral: .contentSecondary
        }
    }
}

private struct LegacyTimelineNodeView: View {
    let item: LegacyTimelineItem

    var body: some View {
        self.nodeContent
            .frame(width: 24, height: 24)
    }

    @ViewBuilder
    private var nodeContent: some View {
        if let node = self.item.node {
            node
        } else {
            Circle()
                .fill(LegacyTimeline.nodeColor(for: self.item.status))
                .frame(width: Timeline.nodeDiameter, height: Timeline.nodeDiameter)
                .accessibilityLabel(
                    Text(LocalizedStringKey(Timeline.accessibilityLabelKey(for: self.item.status)), bundle: .module)
                )
        }
    }
}

private struct LegacyTimelineRowView: View {
    let item: LegacyTimelineItem
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: CoreSpacing.md) {
            LegacyTimelineNodeView(item: self.item)

            self.item.content
                .padding(.bottom, self.isLast ? CoreSpacing.none : CoreSpacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(alignment: .topLeading) {
            if !self.isLast {
                LegacyTimelineConnector()
                    .padding(.leading, (24 - CoreBorderWidth.thin) / 2)
            }
        }
    }
}

private struct LegacyTimelineConnector: View {
    var body: some View {
        Rectangle()
            .fill(Color.dividerDefault)
            .frame(width: CoreBorderWidth.thin)
            .frame(maxHeight: .infinity)
            .padding(.top, 24)
    }
}
