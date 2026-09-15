import Accessibility
import OhMyDesign
import SwiftUI

/// 雷达图（蛛网图）。多维评分的形状对比。
public struct RadarChart<Value: ChartValue>: View {
    private let values: [Value]
    private let tint: Color
    private let title: LocalizedStringResource
    private let layout: RadarChartLayout

    nonisolated static var minimumAxes: Int { 3 }

    /// - Parameters:
    ///   - values: 各维度。`label` 作轴名、`value` 作长度。
    ///   - title: 图表标题。⚠️ **组件自带的 chrome 文案**，走 `LocalizedStringResource`（公约 §4 A 类 / #43-1）；
    ///     而 `values` 里的 `label` 是**调用方的内容**，是 `String`。
    ///   - layout: 布局形态，见 `RadarChartLayout`。默认 `.polygon`（现状：闭合多边形）。
    public init(
        _ values: [Value],
        title: LocalizedStringResource? = nil,
        tint: Color = .dataAccent,
        layout: RadarChartLayout = .polygon
    ) {
        self.values = values
        self.title = title ?? .chart("Radar chart")
        self.tint = tint
        self.layout = layout
    }

    public var body: some View {
        let raw = self.values.map(\.value)

        switch ChartDegeneracy.of(raw, minimumCount: Self.minimumAxes) {
        case .empty:
            ChartEmptyState(message: .chart("No data"))
        case .insufficientPoints:
            ChartEmptyState(message: .chart("A radar chart needs at least 3 dimensions"))
        case .nonFinite:
            ChartEmptyState(message: .chart("Data contains values that are not finite"))
        default:
            self.chart
        }
    }

    // MARK: - Private

    private var chart: some View {
        GeometryReader { proxy in
            if let plan = self.renderPlan(size: proxy.size) {
                Self.draw(plan: plan, tint: self.tint)
            }
        }
        .accessibilityElement()
        .accessibilityLabel(Text(self.title))
        .accessibilityChartDescriptor(self)
    }

    @ViewBuilder
    private static func draw(plan: RadarChartPlan, tint: Color) -> some View {
        switch plan.layout {
        case .polygon:
            Self.polygonView(normalized: plan.normalized, size: plan.size, tint: tint)
        case .radialBars:
            Self.radialBarsView(normalized: plan.normalized, size: plan.size, tint: tint)
        case .parallel:
            Self.parallelView(normalized: plan.normalized, size: plan.size, tint: tint)
        case .bars:
            Self.barsView(normalized: plan.normalized, size: plan.size, tint: tint)
        }
    }

    private static func polygonView(normalized: [Double], size: CGSize, tint: Color) -> some View {
        let radius = min(size.width, size.height) / 2 * 0.78
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let count = normalized.count

        return ZStack {
            ForEach(1...4, id: \.self) { ring in
                Self.polygon(center: center, radius: radius * Double(ring) / 4, count: count)
                    .stroke(Color.dividerDefault, lineWidth: CoreBorderWidth.hairline)
            }

            Self.polygon(center: center, radius: radius, count: count, scales: normalized)
                .fill(tint.opacity(0.28))

            Self.polygon(center: center, radius: radius, count: count, scales: normalized)
                .stroke(tint, lineWidth: CoreBorderWidth.thin)
        }
    }

    private nonisolated static func polygonPoint(
        center: CGPoint, radius: Double, index: Int, count: Int, scale: Double?
    ) -> CGPoint {
        let angle = -Double.pi / 2 + 2 * .pi * Double(index) / Double(count)
        let r = radius * (scale.map { $0 * 0.85 + 0.15 } ?? 1)
        return CGPoint(x: center.x + cos(angle) * r, y: center.y + sin(angle) * r)
    }

    private static func polygon(
        center: CGPoint, radius: Double, count: Int, scales: [Double]? = nil
    ) -> Path {
        Path { path in
            guard count >= Self.minimumAxes else { return }
            for i in 0..<count {
                let point = Self.polygonPoint(
                    center: center, radius: radius, index: i, count: count, scale: scales?[i]
                )
                i == 0 ? path.move(to: point) : path.addLine(to: point)
            }
            path.closeSubpath()
        }
    }

    private static func radialBarsView(normalized: [Double], size: CGSize, tint: Color) -> some View {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let outer = min(size.width, size.height) / 2 * 0.78
        let count = normalized.count

        return ZStack {
            ForEach(0..<count, id: \.self) { i in
                // 轨道分布 `[outer×0.35, outer]`（不是 `[outer/n, outer]`）——n 越大，
                // 旧公式的最内圈半径会缩到与描边线宽同量级，弧退化成一个钩子。
                let midRadius = outer * (1 - Double(i) / Double(count) * 0.65)
                let diameter = midRadius * 2
                let width = outer * 0.65 / Double(count) * 0.6
                let fraction = 0.85 * (normalized[i] * 0.85 + 0.15)

                Circle()
                    .stroke(Color.tertiaryFill, lineWidth: width)
                    .frame(width: diameter, height: diameter)
                    .position(center)

                // `.trim` + `rotationEffect(-90°)`: 把 Circle 参数化起点（3 点钟方向）
                // 转到 12 点钟方向，再随 fraction 顺时针扫——与 `anchors(layout:.radialBars…)`
                // 里 `angle = -π/2 + sweep` 用的是同一个方向约定，两处必须一起改。
                Circle()
                    .trim(from: 0, to: fraction)
                    .stroke(tint, style: StrokeStyle(lineWidth: width, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: diameter, height: diameter)
                    .position(center)
            }
        }
    }

    private static func parallelView(normalized: [Double], size: CGSize, tint: Color) -> some View {
        let count = normalized.count
        let inset = size.width * 0.11
        let usableW = size.width - inset * 2
        let vInset = size.height * 0.11
        let usableH = size.height - vInset * 2
        let bottom = size.height - vInset

        func x(_ i: Int) -> Double {
            count > 1 ? inset + usableW * Double(i) / Double(count - 1) : inset + usableW / 2
        }
        func y(_ v: Double) -> Double { bottom - usableH * (v * 0.85 + 0.15) }

        return ZStack {
            ForEach(0..<count, id: \.self) { i in
                Path { path in
                    path.move(to: CGPoint(x: x(i), y: vInset))
                    path.addLine(to: CGPoint(x: x(i), y: bottom))
                }
                .stroke(Color.dividerDefault, lineWidth: CoreBorderWidth.hairline)
            }

            // `0...4`（不是 `1...4`）：补上 0 那条底部基线。
            ForEach(0...4, id: \.self) { row in
                Path { path in
                    let gy = bottom - usableH * Double(row) / 4
                    path.move(to: CGPoint(x: inset, y: gy))
                    path.addLine(to: CGPoint(x: size.width - inset, y: gy))
                }
                .stroke(Color.dividerDefault, lineWidth: CoreBorderWidth.hairline)
            }

            Path { path in
                for i in 0..<count {
                    let point = CGPoint(x: x(i), y: y(normalized[i]))
                    i == 0 ? path.move(to: point) : path.addLine(to: point)
                }
            }
            .stroke(tint, lineWidth: CoreBorderWidth.thin)

            ForEach(0..<count, id: \.self) { i in
                Circle()
                    .fill(tint)
                    .frame(width: 6, height: 6)
                    .position(CGPoint(x: x(i), y: y(normalized[i])))
            }
        }
    }

    private static func barsView(normalized: [Double], size: CGSize, tint: Color) -> some View {
        // 与 `.parallel` 同款水平留白——网格线贴着画布边缘时，
        // 落在边缘的那条竖线只画出了一半描边宽度，读起来像被裁掉了。
        let count = normalized.count
        let inset = size.width * 0.11
        let usableW = size.width - inset * 2
        let rowHeight = size.height / Double(count)
        let barHeight = min(rowHeight * 0.7, rowHeight)

        return ZStack {
            // `0...4`（不是 `1...4`）：留白后左缘不再是画布边界，需要单独画一条基线。
            ForEach(0...4, id: \.self) { col in
                Path { path in
                    let gx = inset + usableW * Double(col) / 4
                    path.move(to: CGPoint(x: gx, y: 0))
                    path.addLine(to: CGPoint(x: gx, y: size.height))
                }
                .stroke(Color.dividerDefault, lineWidth: CoreBorderWidth.hairline)
            }

            ForEach(0..<count, id: \.self) { i in
                let length = usableW * (normalized[i] * 0.85 + 0.15)
                let y = rowHeight * (Double(i) + 0.5)
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(tint)
                    .frame(width: length, height: barHeight)
                    .position(x: inset + length / 2, y: y)
            }
        }
    }
}

// MARK: - Accessibility

extension RadarChart: AXChartDescriptorRepresentable {
    /// 交出 VoiceOver 的图表描述符——走 `Accessibility` 框架，不需要 `import Charts`。
    public func makeChartDescriptor() -> AXChartDescriptor {
        let raw = self.values.map(\.value).filter(\.isFinite)
        let axis = AXNumericDataAxisDescriptor(
            title: chartAXString("Value"),
            range: safeRange(raw.min() ?? 0, raw.max() ?? 1),
            gridlinePositions: []
        ) { "\($0.formatted())" }

        let category = AXCategoricalDataAxisDescriptor(
            title: chartAXString("Dimension"),
            categoryOrder: self.values.map(\.label)
        )

        let series = AXDataSeriesDescriptor(
            name: "",
            isContinuous: false,
            dataPoints: self.values.map {
                AXDataPoint(x: $0.label, y: $0.value)
            }
        )

        return AXChartDescriptor(
            title: String(localized: self.title),
            summary: nil,
            xAxis: category,
            yAxis: axis,
            additionalAxes: [],
            series: [series]
        )
    }
}

// MARK: - 布局形态（Issue #312 · 形态 D2）

/// `RadarChart` 的布局形态。
///
/// ⚠️ **本枚举是 `#312` 给 `RadarChart` 补的样式扩展点**（形态 D2 配置枚举）——
/// `#299` 步骤 2 枚举出的三个业界替代形态各对应一个 case，来源逐条记在
/// `docs/component-registry.json` 本条的 `notes` 与各 case 的文档注释里。
///
/// ⚠️ **「配置枚举可演进」不是零代价**：本枚举**非 `@frozen`**，加 case 对下游任何
/// 穷举 `switch` 都是 source-breaking（下游要写 `@unknown default` 才免疫）。
/// 它仍比形态 B（public 协议）可撤，但加 case 要走一次 BREAKING-CHANGES 登记。
public nonisolated enum RadarChartLayout: Sendable, Equatable, CaseIterable {
    /// 默认：各轴端点连成闭合轮廓（现状形态）。
    case polygon
    /// 平行坐标：n 条竖轴，值映射到高度。
    /// 业界来源：AntV G2 坐标系总览页的 `parallel`。
    case parallel
    /// 径向柱状：每维一条从圆心向外的同心弧形条，值编码在扫过角上（不是半径）。
    /// 业界来源：AntV G2 坐标系总览页的 `radial`（转置极坐标读法）。
    case radialBars
    /// 笛卡尔并排条形：n 行水平条。
    /// 业界来源：GitLab 设计体系 Pajamas 的 Charts 页。
    case bars
}

/// 单份取点计划——`body` 与判据共用同一份（本仓既有约定），`nil` 表示应走空态。
struct RadarChartPlan: Equatable {
    let layout: RadarChartLayout
    let normalized: [Double]
    let size: CGSize
    let anchors: [CGPoint]
}

extension RadarChart {
    func renderPlan(size: CGSize) -> RadarChartPlan? {
        let raw = self.values.map(\.value)
        switch ChartDegeneracy.of(raw, minimumCount: Self.minimumAxes) {
        case .empty, .insufficientPoints, .nonFinite:
            return nil
        default:
            let normalized = raw.normalizedSafely()
            return RadarChartPlan(
                layout: self.layout,
                normalized: normalized,
                size: size,
                anchors: Self.anchors(layout: self.layout, normalized: normalized, in: size)
            )
        }
    }

    /// 按形态给出每个维度的「值锚点」。⚠️ **纯函数，生产代码与判据共用同一份**（本仓既有约定）。
    nonisolated static func anchors(
        layout: RadarChartLayout, normalized: [Double], in size: CGSize
    ) -> [CGPoint] {
        let count = normalized.count
        guard count >= Self.minimumAxes,
              size.width.isFinite, size.height.isFinite,
              size.width > 0, size.height > 0
        else { return [] }

        switch layout {
        case .polygon:
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) / 2 * 0.78
            return (0..<count).map {
                Self.polygonPoint(
                    center: center, radius: radius, index: $0, count: count, scale: normalized[$0]
                )
            }
        case .radialBars:
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let outer = min(size.width, size.height) / 2 * 0.78
            return (0..<count).map { i in
                let midRadius = outer * (1 - Double(i) / Double(count) * 0.65)
                let sweep = 2 * Double.pi * 0.85 * (normalized[i] * 0.85 + 0.15)
                let angle = -Double.pi / 2 + sweep
                return CGPoint(
                    x: center.x + cos(angle) * midRadius, y: center.y + sin(angle) * midRadius
                )
            }
        case .parallel:
            let inset = size.width * 0.11
            let usableW = size.width - inset * 2
            let vInset = size.height * 0.11
            let usableH = size.height - vInset * 2
            let bottom = size.height - vInset
            return (0..<count).map { i in
                let x = count > 1
                    ? inset + usableW * Double(i) / Double(count - 1)
                    : inset + usableW / 2
                let y = bottom - usableH * (normalized[i] * 0.85 + 0.15)
                return CGPoint(x: x, y: y)
            }
        case .bars:
            let inset = size.width * 0.11
            let usableW = size.width - inset * 2
            let rowHeight = size.height / Double(count)
            return (0..<count).map { i in
                let x = inset + usableW * (normalized[i] * 0.85 + 0.15)
                let y = rowHeight * (Double(i) + 0.5)
                return CGPoint(x: x, y: y)
            }
        }
    }
}

// MARK: - Preview

private nonisolated struct Metric: ChartValue {
    let id = UUID()
    let label: String
    let value: Double
}

#Preview("RadarChart") {
    VStack(spacing: 24) {
        RadarChart([
            Metric(label: "速度", value: 82),
            Metric(label: "力量", value: 61),
            Metric(label: "耐力", value: 94),
            Metric(label: "技巧", value: 47),
            Metric(label: "智力", value: 73),
        ])
        .frame(height: 220)

        RadarChart([
            Metric(label: "A", value: 50),
            Metric(label: "B", value: 50),
            Metric(label: "C", value: 50),
        ])
        .frame(height: 160)

        RadarChart([Metric(label: "只有一个", value: 10)])
            .frame(height: 60)
    }
    .padding()
}

// MARK: - 四个布局形态各一个 Preview（Issue #312）

private nonisolated enum RadarChartPreviewSample {
    static let values: [Metric] = [
        Metric(label: "速度", value: 82),
        Metric(label: "力量", value: 61),
        Metric(label: "耐力", value: 94),
        Metric(label: "技巧", value: 47),
        Metric(label: "智力", value: 73),
    ]
}

#Preview("RadarChart — .polygon") {
    RadarChart(RadarChartPreviewSample.values, title: ".polygon", layout: .polygon)
        .frame(height: 220)
        .padding()
}

#Preview("RadarChart — .parallel") {
    RadarChart(RadarChartPreviewSample.values, title: ".parallel", layout: .parallel)
        .frame(height: 220)
        .padding()
}

#Preview("RadarChart — .radialBars") {
    RadarChart(RadarChartPreviewSample.values, title: ".radialBars", layout: .radialBars)
        .frame(height: 220)
        .padding()
}

#Preview("RadarChart — .bars") {
    RadarChart(RadarChartPreviewSample.values, title: ".bars", layout: .bars)
        .frame(height: 220)
        .padding()
}
