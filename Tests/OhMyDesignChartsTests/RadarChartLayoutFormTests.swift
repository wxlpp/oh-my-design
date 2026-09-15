import CoreGraphics
import Foundation
import Testing
@testable import OhMyDesignCharts

// MARK: - 布局形态扩展点（Issue #312 · 形态 D2）

@Suite("RadarChart 的布局形态（#312）")
struct RadarChartLayoutFormTests {
    private nonisolated struct Metric: ChartValue {
        let id = UUID()
        let label: String
        let value: Double
    }

    private static let size = CGSize(width: 300, height: 240)

    private static func sample() -> [Metric] {
        [
            Metric(label: "A", value: 82), Metric(label: "B", value: 61),
            Metric(label: "C", value: 94), Metric(label: "D", value: 47),
            Metric(label: "E", value: 73),
        ]
    }

    @Test("四个形态的 anchors 都给出 n 个落在画布内的点；退化输入（轴数不足 / 画布退化）触发守卫返回空")
    func anchorsCoverAllLayoutsAndGuardDegenerateInput() {
        let normalized = [0.1, 0.9, 0.5, 0.0, 1.0]

        for layout in RadarChartLayout.allCases {
            let points = RadarChart<Metric>.anchors(layout: layout, normalized: normalized, in: Self.size)
            #expect(points.count == 5, "\(layout)：只给出了 \(points.count) 个锚点，期望 5")
            for p in points {
                #expect(p.x.isFinite && p.y.isFinite, "\(layout) 的锚点非有限：\(p)")
                #expect(p.x >= -0.01 && p.x <= Self.size.width + 0.01,
                        "\(layout) 的 x = \(p.x) 落在画布外（宽 \(Self.size.width)）")
                #expect(p.y >= -0.01 && p.y <= Self.size.height + 0.01,
                        "\(layout) 的 y = \(p.y) 落在画布外（高 \(Self.size.height)）")
            }
        }

        for layout in RadarChartLayout.allCases {
            #expect(
                RadarChart<Metric>.anchors(layout: layout, normalized: [0.1, 0.9], in: Self.size).isEmpty,
                "\(layout)：轴数不足 3 时应返回空，而不是继续算出畸形点"
            )
            #expect(
                RadarChart<Metric>.anchors(layout: layout, normalized: normalized, in: .zero).isEmpty,
                "\(layout)：画布尺寸为 0 时应返回空"
            )
            #expect(
                RadarChart<Metric>.anchors(
                    layout: layout, normalized: normalized, in: CGSize(width: Double.nan, height: 240)
                ).isEmpty,
                "\(layout)：画布尺寸含 NaN 时应返回空，不应产出 NaN 锚点"
            )
        }
    }

    @Test("#312：.radialBars 的扫过角对值严格单调、v=1 时占 0.85 圈，各维中线半径严格递减；四种形态的锚点互异")
    func radialBarsAnglesAndRadiiAreConsistent() {
        let normalized = [0.0, 0.2, 0.5, 0.8, 1.0]
        let center = CGPoint(x: Self.size.width / 2, y: Self.size.height / 2)
        let points = RadarChart<Metric>.anchors(layout: .radialBars, normalized: normalized, in: Self.size)

        let radii = points.map { hypot($0.x - center.x, $0.y - center.y) }
        for i in 1..<radii.count {
            #expect(radii[i] < radii[i - 1],
                     "第 \(i) 维中线半径 \(radii[i]) 未严格小于上一维 \(radii[i - 1])——各圈没有同心递减")
        }

        func normalizedAngle(_ a: Double) -> Double {
            let twoPi = 2 * Double.pi
            var r = a.truncatingRemainder(dividingBy: twoPi)
            if r < 0 { r += twoPi }
            return r
        }
        func sweep(_ p: CGPoint) -> Double {
            normalizedAngle(atan2(p.y - center.y, p.x - center.x) + .pi / 2)
        }
        let sweeps = points.map(sweep)
        for i in 1..<sweeps.count {
            #expect(sweeps[i] > sweeps[i - 1], "扫过角对值不是严格单调：\(sweeps)")
        }
        #expect(abs(sweeps.last! - 2 * Double.pi * 0.85) < 0.001,
                "v = 1 时扫过量应为 2π × 0.85，实为 \(sweeps.last!)")

        let polygonPoints = RadarChart<Metric>.anchors(layout: .polygon, normalized: normalized, in: Self.size)
        let parallelPoints = RadarChart<Metric>.anchors(layout: .parallel, normalized: normalized, in: Self.size)
        let barsPoints = RadarChart<Metric>.anchors(layout: .bars, normalized: normalized, in: Self.size)
        #expect(points != polygonPoints, ".radialBars 与 .polygon 的锚点相同——形态没有真的生效")
        #expect(parallelPoints != polygonPoints, ".parallel 与 .polygon 的锚点相同——形态没有真的生效")
        #expect(barsPoints != polygonPoints, ".bars 与 .polygon 的锚点相同——形态没有真的生效")
    }

    @Test("#312：.parallel 的 x 严格递增，值越大 y 越小，v=0 与 v=1 的 y 差为 usableH × 0.85")
    func parallelAxesAreOrderedAndValueDrivesHeight() {
        let normalized = [0.0, 0.3, 0.6, 1.0]
        let points = RadarChart<Metric>.anchors(layout: .parallel, normalized: normalized, in: Self.size)

        for i in 1..<points.count {
            #expect(points[i].x > points[i - 1].x, "第 \(i) 根竖轴的 x 未严格递增：\(points.map(\.x))")
        }
        for i in 1..<points.count {
            #expect(points[i].y < points[i - 1].y,
                     "normalized 严格递增，值更大的维度 y 应更小（更靠上）：\(points.map(\.y))")
        }

        let vInset = Self.size.height * 0.11
        let usableH = Self.size.height - vInset * 2
        let atZero = RadarChart<Metric>.anchors(layout: .parallel, normalized: [0, 0.5, 1, 0.2], in: Self.size)
        let atOne = RadarChart<Metric>.anchors(layout: .parallel, normalized: [1, 0.5, 0, 0.2], in: Self.size)
        #expect(abs((atZero[0].y - atOne[0].y) - usableH * 0.85) < 0.001,
                "v = 0 与 v = 1 的 y 差应为 usableH × 0.85，实为 \(atZero[0].y - atOne[0].y)")
    }

    @Test("#312：.bars 有 n 个不同的行 y，条长随值单调，v = 0 时长度是地板 0.15 × usableW")
    func barsRowsAreDistinctAndLengthFollowsFloor() {
        let normalized = [0.0, 0.3, 1.0]
        let points = RadarChart<Metric>.anchors(layout: .bars, normalized: normalized, in: Self.size)

        let ys = Set(points.map { ($0.y * 1000).rounded() })
        #expect(ys.count == 3, "行 y 应各不相同，实得 \(points.map(\.y))")
        for i in 1..<points.count {
            #expect(points[i].x > points[i - 1].x, "条长（x）未随值单调递增：\(points.map(\.x))")
        }
        let inset = Self.size.width * 0.11
        let usableW = Self.size.width - inset * 2
        #expect(abs(points[0].x - (inset + usableW * 0.15)) < 0.001,
                "v = 0 时条长应为地板 0.15 × usableW（留白后起点在 inset），实为 \(points[0].x)")
    }

    @Test("view 路径：退化输入下 renderPlan 为 nil；同一份 5 维数据在四个形态下给出互异的 plan")
    func renderPlanIsNilForDegenerateInputAndDiffersAcrossLayouts() {
        for layout in RadarChartLayout.allCases {
            let degenerate = RadarChart([Metric(label: "只有一个", value: 10)], layout: layout)
            #expect(degenerate.renderPlan(size: Self.size) == nil,
                     "\(layout)：退化输入（轴数不足）下应走空态，renderPlan 应为 nil")
        }

        let values = Self.sample()
        var plans: [RadarChartPlan] = []
        for layout in RadarChartLayout.allCases {
            guard let plan = RadarChart(values, layout: layout).renderPlan(size: Self.size) else {
                Issue.record("\(layout)：正常输入下 renderPlan 不应为 nil")
                continue
            }
            #expect(plan.layout == layout)
            plans.append(plan)
        }
        #expect(plans.count == RadarChartLayout.allCases.count)
        for i in 0..<plans.count {
            for j in (i + 1)..<plans.count {
                #expect(plans[i] != plans[j],
                         "\(plans[i].layout) 与 \(plans[j].layout) 的 plan 相等——形态没有真的生效")
            }
        }
    }
}
