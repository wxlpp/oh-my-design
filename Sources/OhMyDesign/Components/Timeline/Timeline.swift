import SwiftUI

// MARK: - TimelineLayout

/// `Timeline` 的**整体排布形态**——与 `TimelineItem` 的 `node:` 外观槽**正交**：
/// 本枚举决定「这组节点怎么排」，`node:` 决定「单个节点画成什么」。
public nonisolated enum TimelineLayout: Sendable, Equatable {
    /// 默认：左侧节点列 + 右侧内容，节点间竖向连线（现状形态）。
    case vertical
    /// 左右交替：内容在中轴两侧交替排布。
    /// 业界来源：Ant Design Timeline 的 `mode="alternate"`。
    case alternate
    /// 横向：节点沿水平轴排列，节点间有连线，内容在节点下方。
    /// 业界来源：PowerPoint SmartArt 的 Basic Timeline / Final Cut Pro 的横向事件时间线。
    case horizontal
    /// 无连线的分组列表：删掉节点列与连线，只留内容；本形态下 `TimelineItem.node:` 槽不生效。
    case grouped
}

// MARK: - TimelineProgress / TimelinePhase

/// 带阶段的时间线推进到哪里：与每行的 `step` 一起决定各行阶段与连线着色。
public nonisolated enum TimelineProgress: Sendable, Hashable {
    /// 全部带 `step` 的行处于 `.upcoming`。
    case notStarted
    /// `step` 小于参数的行已完成、等于的行进行中、大于的行未开始；参数不等于任何行的 `step` 时没有进行中的行。
    case inProgress(at: Int)
    /// 全部带 `step` 的行已完成。
    case completed

    /// 给定 `step` 的阶段。
    ///
    /// - Parameter step: 行的步骤号。
    /// - Returns: 该行的阶段。
    public func phase(forStep step: Int) -> TimelinePhase {
        switch self {
        case .notStarted: .upcoming
        case .completed: .completed
        case .inProgress(let current):
            step < current ? .completed : (step == current ? .inProgress : .upcoming)
        }
    }
}

/// 一行在带阶段时间线里的阶段；只决定默认圆点形态、连线着色与无障碍播报，色相仍由 `status` 决定。
public nonisolated enum TimelinePhase: Sendable, Hashable, CaseIterable {
    /// 已完成：实心圆点，通向它的连线着 `.tint`。
    case completed
    /// 进行中：实心圆点 + 同色外环，通向它的连线着 `.tint`。
    case inProgress
    /// 未开始：同色空心圆点，通向它的连线为底线色。
    case upcoming
}

// MARK: - Timeline

/// **材质层**: 内容. **表面角色**: 内容.
///
/// 组合式时间线：直接子视图里的 `TimelineItem` 是行（自己画节点），其余子视图（分组标题、页脚等）
/// 是没有节点的非行子视图。
public struct Timeline<Content: View>: View {
    let layout: TimelineLayout
    let progress: TimelineProgress?
    let content: Content

    /// 构造时间线。
    ///
    /// - Parameters:
    ///   - layout: 整体排布形态，默认 `.vertical`。⚠️ `.grouped` 下 `TimelineItem` 的 `node:` 槽不生效。
    ///   - content: 行（`TimelineItem`）与非行子视图，按声明顺序排布。
    public init(layout: TimelineLayout = .vertical, @ViewBuilder content: () -> Content) {
        self.layout = layout
        self.progress = nil
        self.content = content()
    }

    /// 构造带阶段的时间线：各行阶段由 `progress` 与该行自己的 `step` 决定，`step` 为 `nil` 的行没有阶段。
    ///
    /// 通向已完成 / 进行中行的连线着 `.tint`（未设置时渲染为系统强调色），其余连线为底线色。
    ///
    /// - Parameters:
    ///   - layout: 整体排布形态，默认 `.vertical`。
    ///   - progress: 推进位置。
    ///   - content: 行（`TimelineItem`，按声明顺序写递增的 `step`）与非行子视图。
    public init(layout: TimelineLayout = .vertical, progress: TimelineProgress, @ViewBuilder content: () -> Content) {
        self.layout = layout
        self.progress = progress
        self.content = content()
    }

    public var body: some View {
        Group(subviews: self.content
            .environment(\.timelineLayoutContext, self.layout)
            .environment(\.timelineProgressContext, self.progress)
        ) { subviews in
            let slots = TimelineStackLayout.pairParts(roles: subviews.map { $0.containerValues.timelinePart?.role })
            switch self.layout {
            case .vertical, .alternate:
                self.stack(subviews, slots: slots)
            case .horizontal:
                ScrollView(.horizontal, showsIndicators: false) {
                    self.stack(subviews, slots: slots)
                }
            case .grouped:
                VStack(alignment: .leading, spacing: CoreSpacing.md) {
                    ForEach(subviews) { subview in
                        if subview.containerValues.timelinePart?.role != .node {
                            subview.frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
        }
    }

    private func stack(_ subviews: SubviewsCollection, slots: [TimelineStackLayout.Slot]) -> some View {
        let priorities = self.layout == .horizontal
            ? TimelineStackLayout.readingPriorities(slots: slots, partCount: subviews.count)
            : nil
        let fractions = TimelineStackLayout.connectorFractions(
            slots: slots, steps: Self.steps(subviews, slots: slots), progress: self.progress, layout: self.layout
        )
        return TimelineStackLayout(layout: self.layout, slots: slots, partCount: subviews.count) {
            ForEach(fractions.indices, id: \.self) { index in
                TimelineConnector(fraction: fractions[index], axis: self.layout == .horizontal ? .horizontal : .vertical)
            }
            ForEach(Array(subviews.enumerated()), id: \.element.id) { index, subview in
                subview
                    .timelineSortPriority(priorities?[index])
            }
        }
        .timelineContained(priorities != nil)
    }

    private static func steps(_ subviews: SubviewsCollection, slots: [TimelineStackLayout.Slot]) -> [Int?] {
        slots.map { slot in
            guard case .row(let node, _) = slot, subviews.indices.contains(node) else { return nil }
            return subviews[node].containerValues.timelinePart?.step
        }
    }
}

// MARK: - 静态取值 / Static metrics

extension Timeline where Content == EmptyView {
    typealias AlternateRowMetrics = TimelineStackLayout.AlternateRowMetrics

    nonisolated static func alternateRowMetrics(forRowWidth rowWidth: CGFloat) -> AlternateRowMetrics {
        TimelineStackLayout.alternateRowMetrics(forRowWidth: rowWidth, nodeColumnWidth: Self.minimumNodeExtent)
    }

    nonisolated static func alternateSlotWidth(forRowWidth rowWidth: CGFloat) -> CGFloat {
        Self.alternateRowMetrics(forRowWidth: rowWidth).slotWidth
    }

    // MARK: - Layout metrics

    nonisolated static let minimumNodeExtent: CGFloat = 24

    static let nodeDiameter: CGFloat = 10

    static let inProgressRingDiameter: CGFloat = 18

    static let inProgressRingOpacity: Double = 0.4

    // MARK: - Pure logic (unit-testable via `@testable import`)

    @MainActor
    static func nodeColor(for status: StatusLevel, in colorScheme: ColorScheme) -> Color {
        switch status {
        case .info: .statusAccentEmphasis
        case .success: .statusSuccessEmphasis
        case .warning: colorScheme == .light ? .statusAttentionForeground : .statusAttentionEmphasis
        case .danger: .statusDangerEmphasis
        case .neutral: .contentSecondary
        }
    }

    nonisolated static func accessibilityLabelKey(for status: StatusLevel) -> String {
        switch status {
        case .info: "Info"
        case .success: "Success"
        case .warning: "Warning"
        case .danger: "Error"
        case .neutral: "Neutral"
        }
    }

    nonisolated static func accessibilityLabelKey(for phase: TimelinePhase) -> String {
        switch phase {
        case .completed: "Completed"
        case .inProgress: "In Progress"
        case .upcoming: "Upcoming"
        }
    }

    nonisolated static func accessibility(
        status: StatusLevel?, hasCustomNode: Bool, hasTitle: Bool, phase: TimelinePhase?
    ) -> TimelineRowAccessibility {
        let status = hasCustomNode ? status : (status ?? .info)
        let keys = [status.map { Self.accessibilityLabelKey(for: $0) }, phase.map { Self.accessibilityLabelKey(for: $0) }]
            .compactMap { $0 }
        guard !keys.isEmpty else {
            return TimelineRowAccessibility(valueKeys: [], mount: .none, combinesContent: false)
        }
        if hasTitle {
            return TimelineRowAccessibility(valueKeys: keys, mount: .title, combinesContent: false)
        }
        return TimelineRowAccessibility(valueKeys: keys, mount: .content, combinesContent: true)
    }
}

// MARK: - TimelineItem

/// `Timeline` 的一行：自己画节点（默认圆点或 `node:` 槽），节点与内容作为两个子视图交给容器排布。
///
/// ⚠️ 施在行上的修饰会**分别**作用于节点与内容：布局修饰（`.padding` / `.frame`）与行为修饰
/// （`.onAppear` / `.task` / `.onTapGesture` / `.contextMenu`）请写进 `content:`；可点击的行把
/// `Button` / `NavigationLink` 放进 `content:`，不要把整行包进 `Button`。
public struct TimelineItem<Node: View, Content: View>: View {
    let step: Int?
    let status: StatusLevel?
    let title: LocalizedStringKey?
    let time: Text?
    let description: LocalizedStringKey?
    let node: Node?
    let content: Content

    @Environment(\.timelineLayoutContext) private var layoutContext
    @Environment(\.timelineProgressContext) private var progressContext

    /// 富内容 + 默认圆点。
    ///
    /// - Parameters:
    ///   - step: 该行的步骤号，在 `Timeline(progress:)` 内决定本行阶段；纯活动流不写。
    ///   - status: 决定默认圆点色相，并作为状态值播报在行上，缺省 `.info`。
    ///   - content: 行内容；并列的多个视图竖排、左对齐、间距 0。
    public init(
        step: Int? = nil,
        status: StatusLevel = .info,
        @ViewBuilder content: () -> Content
    ) where Node == EmptyView {
        self.init(step: step, status: status, title: nil, time: nil, description: nil, node: nil, content: content())
    }

    /// 富内容 + 自定义节点（图标 / 头像等，替代默认圆点）。
    ///
    /// - Parameters:
    ///   - step: 该行的步骤号，在 `Timeline(progress:)` 内决定本行阶段；纯活动流不写。
    ///   - status: 传了才把状态值播报在行上；节点里自带 label 的图标请由调用方 `.accessibilityHidden(true)`，
    ///     否则同一状态读两遍。不传则不播报状态。
    ///   - node: 自定义节点，收到 24×24pt 的提议；节点盒取它报告的尺寸、下限 24pt，节点列宽取所有节点里最宽的那个。
    ///   - content: 行内容；并列的多个视图竖排、左对齐、间距 0。
    public init(
        step: Int? = nil,
        status: StatusLevel? = nil,
        @ViewBuilder node: () -> Node,
        @ViewBuilder content: () -> Content
    ) {
        self.init(step: step, status: status, title: nil, time: nil, description: nil, node: node(), content: content())
    }

    /// 结构件（标题 → 时间 → 描述 → 富内容）+ 默认圆点。
    ///
    /// - Parameters:
    ///   - title: 标题，`.callout`、作为标题元素（`.isHeader`）并承载状态值。
    ///   - time: 时间，通常是 `Text(date, style: .relative)` 这类格式化文本。
    ///   - description: 描述。
    ///   - step: 该行的步骤号，在 `Timeline(progress:)` 内决定本行阶段；纯活动流不写。
    ///   - status: 决定默认圆点色相，并作为状态值播报在标题上，缺省 `.info`。
    ///   - content: 描述下方的富内容，缺省为空。
    public init(
        _ title: LocalizedStringKey,
        time: Text? = nil,
        description: LocalizedStringKey? = nil,
        step: Int? = nil,
        status: StatusLevel = .info,
        @ViewBuilder content: () -> Content = { EmptyView() }
    ) where Node == EmptyView {
        self.init(step: step, status: status, title: title, time: time, description: description, node: nil, content: content())
    }

    /// 结构件（标题 → 时间 → 描述 → 富内容）+ 自定义节点。无富内容时写 `content: {}`。
    ///
    /// - Parameters:
    ///   - title: 标题，`.callout`、作为标题元素（`.isHeader`）；传了 `status` 时承载状态值。
    ///   - time: 时间，通常是 `Text(date, style: .relative)` 这类格式化文本。
    ///   - description: 描述。
    ///   - step: 该行的步骤号，在 `Timeline(progress:)` 内决定本行阶段；纯活动流不写。
    ///   - status: 传了才把状态值播报在标题上（节点里自带 label 的图标请由调用方隐藏）；不传则不播报状态。
    ///   - node: 自定义节点，尺寸规则同 `init(step:status:node:content:)`。
    ///   - content: 描述下方的富内容。
    public init(
        _ title: LocalizedStringKey,
        time: Text? = nil,
        description: LocalizedStringKey? = nil,
        step: Int? = nil,
        status: StatusLevel? = nil,
        @ViewBuilder node: () -> Node,
        @ViewBuilder content: () -> Content
    ) {
        self.init(step: step, status: status, title: title, time: time, description: description, node: node(), content: content())
    }

    private init(
        step: Int?, status: StatusLevel?, title: LocalizedStringKey?, time: Text?,
        description: LocalizedStringKey?, node: Node?, content: Content
    ) {
        self.step = step
        self.status = status
        self.title = title
        self.time = time
        self.description = description
        self.node = node
        self.content = content
    }

    public var body: some View {
        let phase = self.phase
        TimelineNodeView(status: self.status ?? .info, phase: phase, node: self.node)
            .environment(\.timelinePhase, phase)
            .containerValue(\.timelinePart, TimelinePart(role: .node, step: self.step, status: self.status))
        self.contentSlot
            .environment(\.timelinePhase, phase)
            .containerValue(\.timelinePart, TimelinePart(role: .content, step: self.step, status: self.status))
    }

    private var phase: TimelinePhase? {
        guard let step = self.step, let progress = self.progressContext else { return nil }
        return progress.phase(forStep: step)
    }

    private var accessibility: TimelineRowAccessibility {
        Timeline.accessibility(
            status: self.status, hasCustomNode: self.node != nil, hasTitle: self.title != nil, phase: self.phase
        )
    }

    @ViewBuilder
    private var contentSlot: some View {
        let accessibility = self.accessibility
        if let title = self.title {
            VStack(alignment: .leading, spacing: CoreSpacing.xxs) {
                Text(title)
                    .coreFont(.callout)
                    .foregroundStyle(Color.contentPrimary)
                    .accessibilityAddTraits(.isHeader)
                    .timelineAccessibilityValue(accessibility.mount == .title ? accessibility.valueText : nil)
                if let time = self.time {
                    time
                        .coreFont(.footnote)
                        .foregroundStyle(Color.contentSecondary)
                }
                if let description = self.description {
                    Text(description)
                        .coreFont(.footnote)
                        .foregroundStyle(Color.contentSecondary)
                }
                self.content
            }
            .timelineContained(self.layoutContext == .horizontal)
        } else {
            VStack(alignment: .leading, spacing: CoreSpacing.none) {
                self.content
            }
            .timelineCombined(accessibility.combinesContent)
            .timelineContained(!accessibility.combinesContent && self.layoutContext == .horizontal)
            .timelineAccessibilityValue(accessibility.mount == .content ? accessibility.valueText : nil)
        }
    }
}

// MARK: - 行内部件 / Row parts

nonisolated struct TimelinePart: Hashable, Sendable {
    let role: TimelineStackLayout.Role
    let step: Int?
    let status: StatusLevel?
}

nonisolated struct TimelineRowAccessibility: Equatable, Sendable {
    enum Mount: Equatable, Sendable {
        case title
        case content
        case none
    }

    let valueKeys: [String]
    let mount: Mount
    let combinesContent: Bool

    @MainActor var valueText: String? {
        guard !self.valueKeys.isEmpty else { return nil }
        return self.valueKeys
            .map { String(localized: String.LocalizationValue($0), bundle: .module) }
            .joined(separator: ", ")
    }
}

extension ContainerValues {
    @Entry var timelinePart: TimelinePart? = nil
}

extension EnvironmentValues {
    @Entry var timelineLayoutContext: TimelineLayout? = nil
    @Entry var timelineProgressContext: TimelineProgress? = nil
}

private nonisolated struct TimelinePhaseKey: EnvironmentKey {
    static let defaultValue: TimelinePhase? = nil
}

public extension EnvironmentValues {
    /// 本行阶段：在 `Timeline(progress:)` 内、带 `step` 的 `TimelineItem` 的 `node:` 与 `content:` 两个槽里有值，其余为 `nil`。
    /// 自定义节点据此自行决定阶段外观（默认圆点已按阶段绘制）。
    internal(set) var timelinePhase: TimelinePhase? {
        get { self[TimelinePhaseKey.self] }
        set { self[TimelinePhaseKey.self] = newValue }
    }
}

private extension View {
    @ViewBuilder
    func timelineContained(_ contains: Bool) -> some View {
        if contains {
            self.accessibilityElement(children: .contain)
        } else {
            self
        }
    }

    @ViewBuilder
    func timelineSortPriority(_ priority: Double?) -> some View {
        if let priority {
            self.accessibilitySortPriority(priority)
        } else {
            self
        }
    }

    @ViewBuilder
    func timelineCombined(_ combines: Bool) -> some View {
        if combines {
            self.accessibilityElement(children: .combine)
        } else {
            self
        }
    }

    @ViewBuilder
    func timelineAccessibilityValue(_ value: String?) -> some View {
        if let value {
            self.accessibilityValue(Text(verbatim: value))
        } else {
            self
        }
    }
}

// MARK: - TimelineNodeView

struct TimelineNodeView<Node: View>: View {
    let status: StatusLevel
    let phase: TimelinePhase?
    let node: Node?

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            self.nodeContent
        }
    }

    @ViewBuilder
    private var nodeContent: some View {
        if let node = self.node {
            node
        } else {
            let color = Timeline.nodeColor(for: self.status, in: self.colorScheme)
            switch self.phase {
            case nil, .completed:
                Circle()
                    .fill(color)
                    .frame(width: Timeline.nodeDiameter, height: Timeline.nodeDiameter)
                    .accessibilityHidden(true)
            case .inProgress:
                Circle()
                    .fill(color)
                    .frame(width: Timeline.nodeDiameter, height: Timeline.nodeDiameter)
                    .background {
                        Circle()
                            .strokeBorder(color.opacity(Timeline.inProgressRingOpacity), lineWidth: CoreBorderWidth.thick)
                            .frame(width: Timeline.inProgressRingDiameter, height: Timeline.inProgressRingDiameter)
                    }
                    .accessibilityHidden(true)
            case .upcoming:
                Circle()
                    .strokeBorder(color, lineWidth: CoreBorderWidth.thick)
                    .frame(width: Timeline.nodeDiameter, height: Timeline.nodeDiameter)
                    .accessibilityHidden(true)
            }
        }
    }
}

private struct TimelineConnector: View {
    let fraction: CGFloat
    let axis: Axis

    var body: some View {
        Rectangle()
            .fill(Color.dividerDefault)
            .overlay {
                if self.fraction > 0 {
                    Rectangle()
                        .fill(.tint)
                        .scaleEffect(
                            x: self.axis == .horizontal ? self.fraction : 1,
                            y: self.axis == .vertical ? self.fraction : 1,
                            anchor: self.axis == .horizontal ? .leading : .top
                        )
                }
            }
            .accessibilityHidden(true)
    }
}

// MARK: - Preview

#Preview("Timeline — Light") {
    TimelinePreviewGallery()
        .preferredColorScheme(.light)
}

#Preview("Timeline — Dark") {
    TimelinePreviewGallery()
        .preferredColorScheme(.dark)
}

private struct TimelinePreviewGallery: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CoreSpacing.xl) {
                self.section("默认圆点节点（5 种 StatusLevel 状态色）") {
                    Timeline {
                        TimelineItem("已创建", time: Text(verbatim: "2026-07-20 10:00"), status: .info)
                        TimelineItem("审核通过", time: Text(verbatim: "2026-07-21 14:30"), status: .success)
                        TimelineItem("即将过期提醒", time: Text(verbatim: "2026-07-23 09:15"), status: .warning)
                        TimelineItem("处理失败", time: Text(verbatim: "2026-07-24 18:45"), status: .danger)
                        TimelineItem("已归档", time: Text(verbatim: "2026-07-25 08:00"), status: .neutral)
                    }
                }

                self.section("自定义节点（图标 / 头像替代默认圆点）") {
                    Timeline {
                        TimelineItem("订单已发货", status: .success) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.statusSuccessEmphasis)
                                .accessibilityHidden(true)
                        } content: {}
                        TimelineItem("客服已接入", description: "由「小 A」跟进处理，预计 30 分钟内响应。") {
                            Circle()
                                .fill(.blue)
                                .frame(width: 20, height: 20)
                        } content: {}
                        TimelineItem("配送异常", status: .danger) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(Color.statusDangerEmphasis)
                                .accessibilityHidden(true)
                        } content: {}
                    }
                }

                // MARK: `#60` 形态 D2 新增的三种排布

                self.section("交替 · alternate（节点须在**同一条中轴**上，连线贯穿）") {
                    Timeline(layout: .alternate) { Self.statusRows }
                }

                self.section("交替 · 单条（无连线）") {
                    Timeline(layout: .alternate) {
                        TimelineItem(status: .info) { Text("已创建").coreFont(.callout) }
                    }
                }

                self.section("横向 · horizontal（可横向滚动，节点间有连线）") {
                    Timeline(layout: .horizontal) { Self.statusRows }
                }

                self.section("分组 · grouped（无节点列；默认节点项仍播报状态）") {
                    Timeline(layout: .grouped) { Self.statusRows }
                }

                self.section("阶段 · 订单进度（已完成实心、进行中外环、未开始空心；已到达连线着 .tint）") {
                    Timeline(progress: .inProgress(at: 2)) {
                        TimelineItem("已下单", time: Text(verbatim: "09:00"), step: 0)
                        TimelineItem("已付款", time: Text(verbatim: "09:02"), step: 1)
                        TimelineItem("配送中", description: "预计今天 18:00 前送达", step: 2)
                        TimelineItem("已签收", step: 3)
                    }
                }

                self.section("阶段 · 横向路线图") {
                    Timeline(layout: .horizontal, progress: .inProgress(at: 1)) {
                        TimelineItem("Q1 Alpha", step: 0, status: .success)
                        TimelineItem("Q2 Beta", step: 1, status: .warning)
                        TimelineItem("Q3 GA", step: 2, status: .danger)
                    }
                }

                self.section("分组 · 自定义节点项（不传 status 不播报状态）") {
                    Timeline(layout: .grouped) {
                        TimelineItem {
                            Image(systemName: "checkmark.circle.fill")
                        } content: {
                            Text("订单已发货").coreFont(.callout)
                        }
                    }
                }
            }
            .padding()
        }
        .background(Color.surfaceCanvas)
    }

    @ViewBuilder
    private static var statusRows: some View {
        TimelineItem(status: .info) { Text("已创建").coreFont(.callout) }
        TimelineItem(status: .success) { Text("审核通过").coreFont(.callout) }
        TimelineItem(status: .warning) { Text("即将过期提醒").coreFont(.callout) }
        TimelineItem(status: .danger) { Text("处理失败").coreFont(.callout) }
    }

    @ViewBuilder
    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: CoreSpacing.sm) {
            Text(verbatim: title)
                .coreFont(.footnote)
                .foregroundStyle(.secondary)
            content()
        }
    }
}
