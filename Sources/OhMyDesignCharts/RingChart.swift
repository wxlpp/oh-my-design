import Accessibility
import OhMyDesign
import SwiftUI

/// 活动环。多个同心进度环，每环一个指标的完成度。
public struct RingChart<Value: ChartValue>: View {
    private let values: [Value]
    private let goal: Double
    private let tint: Color
    private let colors: [Color]
    private let title: LocalizedStringResource
    private let layout: RingChartLayout

    /// - Parameters:
    ///   - goal: 满环对应的值。⚠️ **不从数据里推**——活动环的语义是"完成度"，
    ///     目标是外部设定的，用数据最大值当目标会让"全部未达标"看起来像"有人满环"。
    /// - Parameter colors: **逐环**取色，按下标轮转。默认空数组 ⇒ 退回 `tint` 的
    ///   透明度阶梯（每内一环降 0.18）。
    /// - Parameter layout: 布局形态，默认 `.rings`（现状：同心进度环）。见
    ///   `RingChartLayout`（Issue #312 · 形态 D2）。
    public init(
        _ values: [Value],
        goal: Double,
        title: LocalizedStringResource? = nil,
        tint: Color = .dataAccent,
        colors: [Color] = [],
        layout: RingChartLayout = .rings
    ) {
        self.values = values
        self.goal = goal
        self.title = title ?? .chart("Activity rings")
        self.tint = tint
        self.colors = colors
        self.layout = layout
    }

    nonisolated func ringBaseColor(at index: Int) -> Color {
        self.colors.isEmpty ? self.tint : self.colors[index % self.colors.count]
    }

    nonisolated func trackColor(at index: Int) -> Color {
        self.ringBaseColor(at: index).opacity(0.18)
    }

    nonisolated func ringColor(at index: Int) -> Color {
        guard !self.colors.isEmpty else {
            return self.tint.opacity(max(1.0 - Double(index) * 0.18, 0.1))
        }
        return self.ringBaseColor(at: index)
    }

    public var body: some View {
        if self.values.isEmpty {
            ChartEmptyState(message: .chart("No data"))
        } else if !self.goal.isFinite || self.goal <= 0 {
            ChartEmptyState(message: .chart("The goal must be greater than 0"))
        } else {
            self.rings
        }
    }

    /// 同心环的建议上限。**超出即截断**，与 `NetworkGraph` 同一条 FR-20 原则。
    public nonisolated static var recommendedRingLimit: Int { 6 }

    /// `.segmentedRings` 每环切成的段数。⚠️ **固定值，不可配置**——Ant Design 的 `steps`
    /// 属性原本可由调用方指定，这里定死是有意的取舍（保持 `RingChartLayout` 无关联值、
    /// `CaseIterable` 可合成）；改成可配是 source-breaking，须走 BREAKING-CHANGES。
    public nonisolated static var segmentCount: Int { 10 }

    private var effectiveValues: [Value] {
        var seen = Set<Value.ID>()
        var kept: [Value] = []
        kept.reserveCapacity(min(self.values.count, Self.recommendedRingLimit))
        for value in self.values where seen.insert(value.id).inserted {
            kept.append(value)
            if kept.count >= Self.recommendedRingLimit { break }
        }
        return kept
    }

    private static func drawnValue(_ value: Double, goal: Double) -> Double {
        guard value.isFinite else { return value > 0 ? goal : 0 }
        return min(max(value, 0), goal)
    }

    private var rings: some View {
        GeometryReader { proxy in
            if let plan = self.renderPlan(size: proxy.size) {
                switch self.layout {
                case .rings:
                    self.ringsView(plan: plan, size: proxy.size)
                case .bars:
                    self.barsView(plan: plan, size: proxy.size)
                case .segmentedRings:
                    self.segmentedRingsView(plan: plan, size: proxy.size)
                case .stackedBar:
                    self.stackedBarView(plan: plan, size: proxy.size)
                }
            }
        }
        .accessibilityElement()
        .accessibilityLabel(Text(self.title))
        .accessibilityChartDescriptor(self)
    }

    @ViewBuilder
    private func ringsView(plan: RingChartPlan, size: CGSize) -> some View {
        ZStack {
            ForEach(Array(plan.rings.enumerated()), id: \.offset) { index, ring in
                ZStack {
                    Circle()
                        .stroke(self.trackColor(at: index), lineWidth: ring.width)
                    Circle()
                        .trim(from: 0, to: ring.progress)
                        .stroke(
                            self.ringColor(at: index),
                            style: StrokeStyle(lineWidth: ring.width, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                }
                .frame(width: ring.radius * 2, height: ring.radius * 2)
            }
        }
        .frame(width: size.width, height: size.height)
    }

    @ViewBuilder
    private func segmentedRingsView(plan: RingChartPlan, size: CGSize) -> some View {
        ZStack {
            ForEach(Array(plan.rings.enumerated()), id: \.offset) { index, ring in
                let filled = plan.filledSegments[index]
                ZStack {
                    ForEach(0..<Self.segmentCount, id: \.self) { segment in
                        let arc = Self.segmentArc(segment: segment, total: Self.segmentCount)
                        Circle()
                            .trim(from: arc.start, to: arc.end)
                            .stroke(
                                segment < filled ? self.ringColor(at: index) : self.trackColor(at: index),
                                style: StrokeStyle(lineWidth: ring.width, lineCap: .butt)
                            )
                            .rotationEffect(.degrees(-90))
                    }
                }
                .frame(width: ring.radius * 2, height: ring.radius * 2)
            }
        }
        .frame(width: size.width, height: size.height)
    }

    @ViewBuilder
    private func barsView(plan: RingChartPlan, size: CGSize) -> some View {
        ZStack {
            ForEach(Array(plan.barRows.enumerated()), id: \.offset) { index, row in
                let barHeight = min(row.height * 0.6, 24)
                let progress = plan.barProgresses[index]
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(self.trackColor(at: index))
                        .frame(width: row.width, height: barHeight)
                    Capsule()
                        .fill(self.ringColor(at: index))
                        .frame(width: max(row.width * progress, 0), height: barHeight)
                }
                .frame(width: row.width, height: row.height)
                .position(x: row.midX, y: row.midY)
            }
        }
        .frame(width: size.width, height: size.height)
    }

    @ViewBuilder
    private func stackedBarView(plan: RingChartPlan, size: CGSize) -> some View {
        // 条高与 `.bars` 统一为同一上限（24pt），评审 I-3。
        let height = min(size.height.isFinite ? max(size.height, 0) : 0, 24)
        ZStack(alignment: .leading) {
            Capsule()
                .fill(self.trackColor(at: 0))
                .frame(width: max(size.width, 0), height: height)
            HStack(spacing: 0) {
                ForEach(Array(plan.stackedWidths.enumerated()), id: \.offset) { index, width in
                    self.ringColor(at: index)
                        .frame(width: max(width, 0), height: height)
                        // 段间分隔线，读得出段的边界（评审 I-3）；最后一段不画尾缘线。
                        .overlay(alignment: .trailing) {
                            if index < plan.stackedWidths.count - 1 {
                                Rectangle()
                                    .fill(Color.surfaceBase)
                                    .frame(width: CoreBorderWidth.thick)
                            }
                        }
                }
            }
            .clipShape(Capsule())
        }
        .frame(width: size.width, height: size.height)
    }
}

extension RingChart: AXChartDescriptorRepresentable {
    public func makeChartDescriptor() -> AXChartDescriptor {
        let category = AXCategoricalDataAxisDescriptor(
            title: chartAXString("Metric"), categoryOrder: self.effectiveValues.map(\.label)
        )
        let denominator = self.goal.isFinite && self.goal > 0 ? self.goal : 1
        let axis = AXNumericDataAxisDescriptor(
            title: chartAXString("Completion"),
            range: safeRange(0, denominator), gridlinePositions: []
        ) { "\($0.formatted(.percent.scale(100 / denominator)))" }
        let series = AXDataSeriesDescriptor(
            name: "", isContinuous: false,
            dataPoints: self.effectiveValues.map {
                AXDataPoint(x: $0.label, y: Self.drawnValue($0.value, goal: denominator))
            }
        )
        return AXChartDescriptor(
            title: String(localized: self.title), summary: nil,
            xAxis: category, yAxis: axis, additionalAxes: [], series: [series]
        )
    }
}

private nonisolated struct Ring: ChartValue {
    let id = UUID()
    let label: String
    let value: Double
}

#Preview("RingChart") {
    VStack(spacing: 24) {
        RingChart([
            Ring(label: "活动", value: 420),
            Ring(label: "锻炼", value: 28),
            Ring(label: "站立", value: 9),
        ], goal: 500)
        .frame(height: 200)

        RingChart([Ring(label: "x", value: 1)], goal: 0).frame(height: 60)
    }
    .padding()
}

// MARK: - 四个布局形态各一个 Preview（Issue #312）

nonisolated enum RingChartPreviewSample {
    fileprivate static let rings = [
        Ring(label: "活动", value: 420),
        Ring(label: "锻炼", value: 28),
        Ring(label: "站立", value: 9),
    ]
}

#Preview("RingChart — .rings") {
    RingChart(RingChartPreviewSample.rings, goal: 500, title: ".rings", layout: .rings)
        .frame(height: 200)
        .padding()
}

#Preview("RingChart — .bars") {
    RingChart(RingChartPreviewSample.rings, goal: 500, title: ".bars", layout: .bars)
        .frame(height: 200)
        .padding()
}

#Preview("RingChart — .segmentedRings") {
    RingChart(RingChartPreviewSample.rings, goal: 500, title: ".segmentedRings", layout: .segmentedRings)
        .frame(height: 200)
        .padding()
}

#Preview("RingChart — .stackedBar") {
    RingChart(RingChartPreviewSample.rings, goal: 500, title: ".stackedBar", layout: .stackedBar)
        .frame(height: 200)
        .padding()
}

// MARK: - 布局形态（Issue #312 · 形态 D2）

/// `RingChart` 的布局形态。
///
/// ⚠️ **本枚举是 `#312` 给 `RingChart` 补的样式扩展点**（形态 D2 配置枚举）——
/// `#299` 步骤 2 枚举出的三个业界替代形态各对应一个 case，来源逐条记在各 case 的文档注释里。
///
/// ⚠️ **「配置枚举可演进」不是零代价**：本枚举**非 `@frozen`**，加 case 对下游任何
/// 穷举 `switch` 都是 source-breaking（下游要写 `@unknown default` 才免疫）。
/// 它仍比形态 B（public 协议）可撤，但加 case 要走一次 BREAKING-CHANGES 登记。
public nonisolated enum RingChartLayout: Sendable, Equatable, CaseIterable {
    /// 默认：同心进度环（现状形态）。
    case rings
    /// 并排线性进度条。业界来源：Ant Design `Progress` 组件 `type="line"`。
    case bars
    /// 分段同心环：几何与 `.rings` 完全相同，只把每环连续的进度弧切成
    /// `RingChart.segmentCount` 段离散段。业界来源：Ant Design `Progress` 组件的 `steps` 属性。
    case segmentedRings
    /// 堆叠条：N 个同心环塌成一条水平堆叠柱，段序 = 值序。
    /// 业界来源：GitLab Pajamas 的 stacked column。语义仍是「完成度」——轨道总长代表 N × goal。
    case stackedBar
}

/// `RingChart` 一次渲染所需的全部几何，四个 `RingChartLayout` 共用同一份退化 / 截断规则算出。
/// ⚠️ **纯函数，生产代码与判据共用同一份**（本仓既有约定）。
nonisolated struct RingChartPlan: Equatable, Sendable {
    /// 单环几何：半径、环宽、进度（0...1）。`.rings` 与 `.segmentedRings` 共用同一份。
    nonisolated struct RingGeometry: Equatable, Sendable {
        let radius: CGFloat
        let width: CGFloat
        let progress: Double
    }

    let layout: RingChartLayout
    let rings: [RingGeometry]
    /// 每环的填充段数（`.segmentedRings` 用），下标与 `rings` 对齐。
    let filledSegments: [Int]
    /// 每行的整行矩形（`.bars` 用）。
    let barRows: [CGRect]
    /// 每行的进度（0...1），下标与 `barRows` 对齐。
    let barProgresses: [Double]
    /// 每段的宽度（`.stackedBar` 用），下标与 `rings` / `barRows` 对齐。
    let stackedWidths: [CGFloat]
}

extension RingChart {
    /// 按当前 `layout` 与截断规则给出一次渲染所需的全部几何；`nil` = 走空态。
    /// ⚠️ **与 `body` 共用同一份**：view 只消费它，不重算。
    func renderPlan(size: CGSize) -> RingChartPlan? {
        guard !self.values.isEmpty, self.goal.isFinite, self.goal > 0 else { return nil }
        let shown = self.effectiveValues
        guard !shown.isEmpty else { return nil }

        let progresses = shown.map { max(0, min($0.value / self.goal, 1)) }

        let side = size.width.isFinite && size.height.isFinite ? min(size.width, size.height) : 0
        let outer = max(side, 0) / 2 * 0.92
        let ringWidth = max(outer / Double(max(shown.count, 1)) * 0.52, 4)
        let rings = shown.indices.map { index in
            RingChartPlan.RingGeometry(
                radius: max(outer - Double(index) * ringWidth * 1.5, 1),
                width: ringWidth,
                progress: progresses[index]
            )
        }
        let filled = progresses.map { Self.filledSegments(progress: $0, segments: Self.segmentCount) }
        let trackWidth = size.width.isFinite ? max(size.width, 0) : 0
        let stacked = Self.stackedWidths(progresses: progresses, trackWidth: trackWidth)
        let rows = Self.barRows(count: shown.count, size: size)

        return RingChartPlan(
            layout: self.layout,
            rings: rings,
            filledSegments: filled,
            barRows: rows,
            barProgresses: progresses,
            stackedWidths: stacked
        )
    }

    /// `progress`（0...1 语义）应填充的段数。⚠️ **四舍五入**（Ant Design 的 `steps` 按此填），
    /// 非有限输入按 `drawnValue` 的既有非有限规则：`NaN` → 0，`+∞` → `segments`，`-∞` → 0。
    nonisolated static func filledSegments(progress: Double, segments: Int) -> Int {
        guard segments > 0 else { return 0 }
        guard progress.isFinite else {
            return progress > 0 ? segments : 0
        }
        let clamped = min(max(progress, 0), 1)
        let raw = (clamped * Double(segments)).rounded(.toNearestOrAwayFromZero)
        return Int(raw)
    }

    /// `.stackedBar` 里每段的宽度：各 `clamp01(progress) / N × trackWidth`。
    nonisolated static func stackedWidths(progresses: [Double], trackWidth: CGFloat) -> [CGFloat] {
        guard !progresses.isEmpty, trackWidth.isFinite, trackWidth > 0 else {
            return progresses.map { _ in 0 }
        }
        let n = Double(progresses.count)
        return progresses.map { progress in
            let clamped: Double = progress.isFinite ? min(max(progress, 0), 1) : (progress > 0 ? 1 : 0)
            return CGFloat(clamped / n) * trackWidth
        }
    }

    /// `.bars` 的 N 行行矩形：行间距 `CoreSpacing.sm`，行高均分剩余高度。
    nonisolated static func barRows(count: Int, size: CGSize) -> [CGRect] {
        guard count > 0, size.width.isFinite, size.height.isFinite else { return [] }
        let spacing = CoreSpacing.sm
        let totalSpacing = spacing * CGFloat(max(count - 1, 0))
        let rowHeight = max((max(size.height, 0) - totalSpacing) / CGFloat(count), 0)
        var rows: [CGRect] = []
        rows.reserveCapacity(count)
        for index in 0..<count {
            let y = CGFloat(index) * (rowHeight + spacing)
            rows.append(CGRect(x: 0, y: y, width: max(size.width, 0), height: rowHeight))
        }
        return rows
    }

    /// `.segmentedRings` 里第 `segment`（共 `total` 段）在整圈上的 trim 区间（0...1，1 = 360°），
    /// 段间留 4° 角隙（`round` 线帽会吃掉缝隙，画法上改用 `.butt`）。
    nonisolated static func segmentArc(segment: Int, total: Int) -> (start: Double, end: Double) {
        guard total > 0 else { return (0, 0) }
        let full = 360.0
        let gap = 4.0
        let slot = full / Double(total)
        let start = Double(segment) * slot
        let end = start + max(slot - gap, 0)
        return (start / full, end / full)
    }
}
