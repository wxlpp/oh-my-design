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

    // MARK: - TimelineItem：默认圆点节点 init

    @Test("TimelineItem(status:content:)：node 为 nil，status 原样保留")
    func defaultNodeInitStoresStatus() {
        let item = TimelineItem(status: .success) {
            Text("Done")
        }
        #expect(item.node == nil)
        #expect(item.status == .success)
    }

    @Test("TimelineItem(content:)：status 缺省为 .info")
    func defaultNodeInitDefaultsToInfo() {
        let item = TimelineItem {
            Text("Created")
        }
        #expect(item.status == .info)
    }

    // MARK: - TimelineItem：自定义节点 init

    @Test("TimelineItem(status:node:content:)：node 非 nil（自定义节点覆盖默认圆点）")
    func customNodeInitStoresNode() {
        let item = TimelineItem(status: .danger) {
            Image(systemName: "xmark.circle.fill")
        } content: {
            Text("Failed")
        }
        #expect(item.node != nil)
        #expect(item.status == .danger)
    }

    // MARK: - id：显式传入原样保留

    @Test("TimelineItem：显式传入的 id 原样保留（不被 UUID() 缺省值覆盖）")
    func explicitIDIsPreserved() {
        let id = UUID()
        let item = TimelineItem(id: id, status: .info) {
            Text("Note")
        }
        #expect(item.id == id)
    }

    // MARK: - isLastItem：最后一条不渲染连线的 identity 判定

    @Test("isLastItem：数组末条返回 true")
    func isLastItemTrueForLastElement() {
        let items = [
            TimelineItem { Text("1") },
            TimelineItem { Text("2") },
            TimelineItem { Text("3") },
        ]
        #expect(Timeline.isLastItem(items[2], in: items) == true)
    }

    @Test("isLastItem：非末条返回 false")
    func isLastItemFalseForNonLastElements() {
        let items = [
            TimelineItem { Text("1") },
            TimelineItem { Text("2") },
            TimelineItem { Text("3") },
        ]
        #expect(Timeline.isLastItem(items[0], in: items) == false)
        #expect(Timeline.isLastItem(items[1], in: items) == false)
    }

    @Test("isLastItem：单条数组，唯一元素即末条")
    func isLastItemSingleElementArray() {
        let items = [TimelineItem { Text("only") }]
        #expect(Timeline.isLastItem(items[0], in: items) == true)
    }

    @Test("isLastItem：item 不在 items 中（不同 id）返回 false，不崩溃")
    func isLastItemNotInArrayReturnsFalse() {
        let items = [TimelineItem { Text("1") }]
        let stray = TimelineItem { Text("stray") }
        #expect(Timeline.isLastItem(stray, in: items) == false)
    }

    // MARK: - Timeline：items 原样保留

    @Test("Timeline(items:)：items 数量与顺序原样保留")
    func timelineStoresItemsInOrder() {
        let items = [
            TimelineItem(status: .info) { Text("1") },
            TimelineItem(status: .success) { Text("2") },
        ]
        let timeline = Timeline(items: items)
        #expect(timeline.items.count == 2)
        #expect(timeline.items.map(\.id) == items.map(\.id))
    }

    @Test("Timeline(items:)：空数组不崩溃")
    func timelineEmptyItemsDoesNotCrash() {
        let timeline = Timeline(items: [])
        #expect(timeline.items.isEmpty)
    }
    // MARK: - TimelineLayout（`#60` 形态 D2）

    @Test("Timeline：layout 默认 .vertical —— 现有调用方零影响")
    func timelineLayoutDefaultsToVertical() {
        let timeline = Timeline(items: [TimelineItem(status: .info) { Text(verbatim: "A") }])
        #expect(timeline.layout == .vertical)
    }

    @Test("Timeline：layout 原样保留")
    func timelineStoresLayout() {
        for layout in [TimelineLayout.vertical, .alternate, .horizontal, .grouped] {
            let timeline = Timeline(
                items: [TimelineItem(status: .info) { Text(verbatim: "A") }], layout: layout
            )
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

    @Test("Timeline：.grouped 下 node: 槽仍被原样保留（不生效 ≠ 被改写）")
    func timelineGroupedPreservesNodeSlot() {
        let item = TimelineItem(status: .info) {
            Text(verbatim: "custom-node")
        } content: {
            Text(verbatim: "content")
        }
        let timeline = Timeline(items: [item], layout: .grouped)
        #expect(timeline.items.first?.node != nil, ".grouped 下 node 槽仍应原样保留")
        #expect(timeline.layout == .grouped)
    }

    @Test("Timeline：四种布局都能构造且 body 可求值（不 crash）")
    func timelineAllLayoutsRender() {
        let items = [
            TimelineItem(status: .info) { Text(verbatim: "A") },
            TimelineItem(status: .danger) { Text(verbatim: "B") },
            TimelineItem(status: .success) { Text(verbatim: "C") },
        ]
        for layout in [TimelineLayout.vertical, .alternate, .horizontal, .grouped] {
            _ = Timeline(items: items, layout: layout).body
        }
    }

    @Test("Timeline.alternateSlotWidth：三列几何的槽宽，且节点中心恰落在行中心")
    func timelineAlternateSlotWidth() {
        let fixed = Timeline.nodeColumnWidth + 2 * CoreSpacing.md

        let w = Timeline.alternateSlotWidth(forRowWidth: 320)
        #expect(w == (320 - fixed) / 2)
        #expect(w * 2 + fixed == 320)

        for rowWidth in [320.0, 390.0, 744.0, 1024.0] as [CGFloat] {
            let metrics = Timeline.alternateRowMetrics(forRowWidth: rowWidth)
            let rowCenter: CGFloat = rowWidth / 2
            #expect(metrics.nodeCenterX == rowCenter,
                    "行宽 \(rowWidth)：节点中心 \(metrics.nodeCenterX) 必须等于行中心 \(rowCenter)")
            let fixed = Timeline.nodeColumnWidth + 2 * CoreSpacing.md
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

    @MainActor
    @Test("Timeline：.grouped 删掉节点列后，默认节点项的状态语义经 accessibilityValue 补回")
    func timelineGroupedKeepsDefaultNodeStatusSemantics() {
        let defaultNodeItem = TimelineItem(status: .danger) { Text(verbatim: "失败") }
        #expect(defaultNodeItem.node == nil, "前提：这是默认节点项")
        #expect(Timeline.groupedStatusKey(for: defaultNodeItem) == "Error")

        let infoItem = TimelineItem(status: .info) { Text(verbatim: "已创建") }
        #expect(Timeline.groupedStatusKey(for: infoItem) == "Info")

        let customNodeItem = TimelineItem(status: .danger) {
            Circle()
        } content: {
            Text(verbatim: "失败")
        }
        #expect(customNodeItem.node != nil, "前提：这是自定义节点项")
        #expect(Timeline.groupedStatusKey(for: customNodeItem) == nil,
                "自定义节点项不补状态播报，否则会覆盖调用方自己的语义")

        for status in [StatusLevel.info, .success, .warning, .danger, .neutral] {
            let item = TimelineItem(status: status) { Text(verbatim: "x") }
            #expect(Timeline.groupedStatusKey(for: item) == Timeline.accessibilityLabelKey(for: status))
        }
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

    private static func items(_ levels: [StatusLevel]) -> [TimelineItem] {
        levels.map { level in TimelineItem(status: level) { Text(verbatim: "Event").coreFont(.callout) } }
    }

    @Test("暗色五档与旧实现（原样拷贝）逐像素一致")
    func darkTimelineMatchesLegacy() throws {
        let items = Self.items(Self.levels)
        let now = try self.pixels(Timeline(items: items), scheme: .dark)
        let old = try self.pixels(LegacyTimeline(items: items), scheme: .dark)
        #expect(now.width == old.width && now.height == old.height)
        expectBitmapsEqual(now.bytes, old.bytes, "暗色 Timeline 与旧实现不同")
    }

    @Test("浅色 info / success / danger / neutral 与旧实现逐像素一致")
    func lightNonWarningTimelineMatchesLegacy() throws {
        let items = Self.items([.info, .success, .danger, .neutral])
        let now = try self.pixels(Timeline(items: items), scheme: .light)
        let old = try self.pixels(LegacyTimeline(items: items), scheme: .light)
        #expect(now.width == old.width && now.height == old.height)
        expectBitmapsEqual(now.bytes, old.bytes, "浅色非 warning 档与旧实现不同")
    }

    @Test("浅色 warning 只有圆点方框内的像素变化")
    func lightWarningChangesOnlyTheDot() throws {
        let items = Self.items([.warning])
        let now = try self.pixels(Timeline(items: items), scheme: .light)
        let old = try self.pixels(LegacyTimeline(items: items), scheme: .light)
        #expect(now.width == old.width && now.height == old.height)
        guard now.width == old.width, now.height == old.height else { return }
        let inset = Int((Timeline.nodeColumnWidth - Timeline.nodeDiameter) / 2)
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
        expectBitmapsEqual(a.outside, b.outside, "圆点方框以外与旧实现不同")
        expectBitmapsDiffer(a.inside, b.inside, "浅色 warning 圆点与旧实现相同")
    }
}

// MARK: - LegacyTimeline

private struct LegacyTimeline: View {
    let items: [TimelineItem]

    var body: some View {
        VStack(alignment: .leading, spacing: CoreSpacing.none) {
            ForEach(self.items) { item in
                LegacyTimelineRowView(item: item, isLast: Timeline.isLastItem(item, in: self.items))
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
    let item: TimelineItem

    var body: some View {
        self.nodeContent
            .frame(width: Timeline.nodeColumnWidth, height: Timeline.nodeColumnWidth)
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
    let item: TimelineItem
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
                    .padding(.leading, (Timeline.nodeColumnWidth - CoreBorderWidth.thin) / 2)
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
            .padding(.top, Timeline.nodeColumnWidth)
    }
}
