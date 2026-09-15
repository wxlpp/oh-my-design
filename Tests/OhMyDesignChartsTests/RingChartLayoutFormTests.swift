import CoreGraphics
import Testing
@testable import OhMyDesignCharts

// MARK: - 布局形态扩展点（Issue #312 · 形态 D2）

@Suite("RingChart 的布局形态（#312）")
struct RingChartLayoutFormTests {
    private struct Metric: ChartValue {
        let id: Int
        let label: String
        let value: Double
    }

    private static func metrics(_ values: [Double]) -> [Metric] {
        values.enumerated().map { Metric(id: $0.offset, label: "m\($0.offset)", value: $0.element) }
    }

    // MARK: - filledSegments

    @Test("filledSegments：四舍五入，边界钉死")
    func filledSegmentsRoundsToNearest() {
        #expect(RingChart<Metric>.filledSegments(progress: 0, segments: 10) == 0)
        #expect(RingChart<Metric>.filledSegments(progress: 1, segments: 10) == 10)
        #expect(RingChart<Metric>.filledSegments(progress: 0.949, segments: 10) == 9,
                "0.949 应四舍五入到 9（0.949 × 10 = 9.49）")
        #expect(RingChart<Metric>.filledSegments(progress: 0.95, segments: 10) == 10,
                "0.95 应四舍五入到 10（.toNearestOrAwayFromZero 把 9.5 进到 10）")
    }

    @Test("filledSegments：NaN / ∞ / 负数按 drawnValue 的既有非有限规则")
    func filledSegmentsHandlesNonFiniteAndNegative() {
        #expect(RingChart<Metric>.filledSegments(progress: .nan, segments: 10) == 0,
                "NaN：`progress > 0` 为假 ⇒ 0（与 drawnValue 的 NaN 分支同规则）")
        #expect(RingChart<Metric>.filledSegments(progress: .infinity, segments: 10) == 10,
                "+∞：`progress > 0` 为真 ⇒ 满段")
        #expect(RingChart<Metric>.filledSegments(progress: -.infinity, segments: 10) == 0,
                "-∞：`progress > 0` 为假 ⇒ 0")
        #expect(RingChart<Metric>.filledSegments(progress: -0.3, segments: 10) == 0,
                "负的有限值钳到 0 ⇒ 0 段")
    }

    // MARK: - stackedWidths

    @Test("stackedWidths：和 ≤ trackWidth；全 1 时和 == trackWidth；N = 6 时各段 = 1/6")
    func stackedWidthsSumsWithinTrack() {
        let trackWidth: CGFloat = 300
        let mixed = RingChart<Metric>.stackedWidths(progresses: [0.2, 0.5, 0.9], trackWidth: trackWidth)
        #expect(mixed.reduce(0, +) <= trackWidth + 0.001, "各段之和超过了轨道总宽：\(mixed.reduce(0, +))")

        let full = RingChart<Metric>.stackedWidths(progresses: [1, 1, 1, 1], trackWidth: trackWidth)
        #expect(abs(full.reduce(0, +) - trackWidth) < 0.001,
                "全部达标时段宽之和应等于轨道总宽，实为 \(full.reduce(0, +))")

        let six = RingChart<Metric>.stackedWidths(progresses: Array(repeating: 1.0, count: 6), trackWidth: 300)
        for width in six {
            #expect(abs(width - 50) < 0.001, "N = 6 时每段应为 1/6 轨道宽（50pt），实为 \(width)")
        }
    }

    @Test("stackedWidths：空数组 / 非法轨道宽给出安全结果")
    func stackedWidthsHandlesDegenerateInput() {
        #expect(RingChart<Metric>.stackedWidths(progresses: [], trackWidth: 300).isEmpty)
        #expect(RingChart<Metric>.stackedWidths(progresses: [0.5, 0.5], trackWidth: 0) == [0, 0])
        #expect(RingChart<Metric>.stackedWidths(progresses: [0.5], trackWidth: .nan) == [0])
    }

    // MARK: - barRows

    @Test("barRows：count 条、互不重叠、y 递增")
    func barRowsAreDistinctAndOrdered() {
        let rows = RingChart<Metric>.barRows(count: 4, size: CGSize(width: 200, height: 160))
        #expect(rows.count == 4, "行数应为 4，实为 \(rows.count)")
        for (lhs, rhs) in zip(rows, rows.dropFirst()) {
            #expect(rhs.minY > lhs.minY, "行的 y 没有严格递增：\(lhs) → \(rhs)")
            #expect(!lhs.intersects(rhs), "相邻两行重叠：\(lhs) / \(rhs)")
        }
    }

    @Test("barRows：非法尺寸给出空数组")
    func barRowsHandlesDegenerateSize() {
        #expect(RingChart<Metric>.barRows(count: 0, size: CGSize(width: 200, height: 160)).isEmpty)
        #expect(RingChart<Metric>.barRows(count: 3, size: CGSize(width: CGFloat.nan, height: 160)).isEmpty)
    }

    // MARK: - view 路径（renderPlan）

    @Test("renderPlan：goal ≤ 0 或非有限时，四个 layout 全为 nil")
    func renderPlanIsNilOnInvalidGoal() {
        let size = CGSize(width: 300, height: 300)
        for goal in [0.0, -5.0, Double.nan, Double.infinity] {
            for layout in RingChartLayout.allCases {
                let chart = RingChart(Self.metrics([1, 2, 3]), goal: goal, layout: layout)
                #expect(chart.renderPlan(size: size) == nil,
                        "\(layout) 在 goal = \(goal) 下应走空态，却给出了 plan")
            }
        }
    }

    @Test("renderPlan：空数据下四个 layout 全为 nil")
    func renderPlanIsNilOnEmptyValues() {
        let size = CGSize(width: 300, height: 300)
        for layout in RingChartLayout.allCases {
            let chart = RingChart(Self.metrics([]), goal: 100, layout: layout)
            #expect(chart.renderPlan(size: size) == nil, "\(layout) 在空数据下应走空态")
        }
    }

    @Test("renderPlan：7 个值在四个 layout 下都只含 6 条（截断走的是同一条路）")
    func renderPlanTruncatesToRecommendedLimit() {
        let size = CGSize(width: 300, height: 300)
        let limit = RingChart<Metric>.recommendedRingLimit
        let values = Self.metrics([10, 20, 30, 40, 50, 60, 70])
        for layout in RingChartLayout.allCases {
            let chart = RingChart(values, goal: 100, layout: layout)
            guard let plan = chart.renderPlan(size: size) else {
                Issue.record("\(layout) 不应为 nil")
                continue
            }
            #expect(plan.rings.count == limit, "\(layout) 的 rings 数应为 \(limit)，实为 \(plan.rings.count)")
            #expect(plan.filledSegments.count == limit)
            #expect(plan.barRows.count == limit)
            #expect(plan.barProgresses.count == limit)
            #expect(plan.stackedWidths.count == limit)
        }
    }

    @Test("renderPlan：四个 layout 在同一份数据上给出互异的 plan")
    func renderPlanDiffersAcrossLayouts() {
        let size = CGSize(width: 300, height: 300)
        let values = Self.metrics([10, 20, 30])
        let plans = RingChartLayout.allCases.compactMap {
            RingChart(values, goal: 100, layout: $0).renderPlan(size: size)
        }
        #expect(plans.count == RingChartLayout.allCases.count, "应有四个 layout 都给出 plan")
        for i in 0..<plans.count {
            for j in (i + 1)..<plans.count {
                #expect(plans[i] != plans[j], "layout \(plans[i].layout) 与 \(plans[j].layout) 给出了相同的 plan")
            }
        }
    }

    @Test("segmentArc：段间留 4° 角隙，且不越过下一段的起点")
    func segmentArcLeavesGap() {
        let total = RingChart<Metric>.segmentCount
        for segment in 0..<total {
            let arc = RingChart<Metric>.segmentArc(segment: segment, total: total)
            #expect(arc.end > arc.start, "第 \(segment) 段的 end 应大于 start")
            let nextStart = Double(segment + 1) / Double(total)
            #expect(arc.end <= nextStart + 0.0001, "第 \(segment) 段画到了下一段的起点之后：\(arc)")
        }
    }

    @Test("segmentedRings 的几何与 .rings 相同：radius / width 逐环一致，仅填充段数不同")
    func segmentedRingsSharesGeometryWithRings() {
        let size = CGSize(width: 300, height: 300)
        let values = Self.metrics([10, 250, 500])
        let rings = RingChart(values, goal: 500, layout: .rings).renderPlan(size: size)
        let segmented = RingChart(values, goal: 500, layout: .segmentedRings).renderPlan(size: size)
        guard let rings, let segmented else {
            Issue.record("两个 layout 都不应为 nil")
            return
        }
        #expect(rings.rings.map(\.radius) == segmented.rings.map(\.radius))
        #expect(rings.rings.map(\.width) == segmented.rings.map(\.width))
        #expect(rings.rings.map(\.progress) == segmented.rings.map(\.progress))
        #expect(segmented.filledSegments == [0, 5, 10],
                "0 / 250/500 / 500 三个进度对应的填充段数应为 0 / 5 / 10，实为 \(segmented.filledSegments)")
    }

    @Test("RingChartColorsGuard 依赖的取色函数不受 layout 影响")
    func colorFunctionsAreIndependentOfLayout() {
        let values = Self.metrics([10, 20, 30])
        for layout in RingChartLayout.allCases {
            let chart = RingChart(values, goal: 100, tint: .accentColor, layout: layout)
            #expect(chart.ringColor(at: 0) == RingChart(values, goal: 100, tint: .accentColor, layout: .rings).ringColor(at: 0),
                    "\(layout) 的取色函数不应随 layout 变化")
        }
    }
}
