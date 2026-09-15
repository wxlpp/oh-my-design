import CoreGraphics
import Foundation
import OhMyDesign
import SwiftUI
import Testing

@testable import OhMyDesignCharts

// MARK: - view 实际走的那条路（位图）——`RingChart` / `RadarChart`
//
// plan 判据碰不到 `body` / `draw(plan:tint:)` 里按 layout 分发的 `switch`，只有位图能抓「分支画错形态」。

@MainActor
private enum ChartRender {
    static func pixels(_ view: some View) -> Data? {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        #if canImport(UIKit)
        guard let cg = renderer.uiImage?.cgImage else { return nil }
        #else
        var rect = CGRect(origin: .zero, size: renderer.nsImage?.size ?? .zero)
        guard let cg = renderer.nsImage?.cgImage(forProposedRect: &rect, context: nil, hints: nil)
        else { return nil }
        #endif
        let w = cg.width, h = cg.height
        guard w > 0, h > 0 else { return nil }
        var buffer = [UInt8](repeating: 0, count: w * h * 4)
        let drawn = buffer.withUnsafeMutableBytes { raw -> Bool in
            guard let base = raw.baseAddress, let ctx = CGContext(
                data: base, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        guard drawn else { return nil }
        return Data(buffer)
    }

    private static let warmUp: Bool = {
        let probe = Rectangle().fill(Color.dataAccent).frame(width: 240, height: 140)
        for _ in 0..<8 { _ = Self.pixels(probe) }
        return true
    }()

    /// 三渲取最后一次——离屏渲染冷缓存的首渲变体与稳定输出之间有噪声（`#317`），
    /// 与 `BeforeAfterLayoutFormTests.Render.stable` 同法。
    static func stable(_ view: some View) -> Data? {
        _ = Self.warmUp
        _ = Self.pixels(view)
        _ = Self.pixels(view)
        return Self.pixels(view)
    }
}

// MARK: - RingChart

@Suite("RingChart 布局形态的位图判据（#312）")
struct RingChartLayoutBitmapTests {
    private struct Metric: ChartValue {
        let id: Int
        let label: String
        let value: Double
    }

    private static let values = [
        Metric(id: 0, label: "a", value: 42), Metric(id: 1, label: "b", value: 78), Metric(id: 2, label: "c", value: 91),
    ]

    @MainActor
    private static func shot(layout: RingChartLayout?) -> Data? {
        let body: AnyView = if let layout {
            AnyView(RingChart(Self.values, goal: 100, layout: layout))
        } else {
            AnyView(RingChart(Self.values, goal: 100))
        }
        return ChartRender.stable(
            body.frame(width: 220, height: 220).environment(\.colorScheme, .light)
        )
    }

    @Test("四个 layout 在同一份数据上两两位图不同")
    @MainActor
    func layoutsRenderDistinctBitmaps() throws {
        let layouts = RingChartLayout.allCases
        var shots: [Data] = []
        for layout in layouts {
            shots.append(try #require(Self.shot(layout: layout), "\(layout) 渲染失败"))
        }
        for i in 0..<layouts.count {
            for j in (i + 1)..<layouts.count {
                expectBitmapsDiffer(
                    shots[i], shots[j],
                    "\(layouts[i]) 与 \(layouts[j]) 的位图逐字节相同 —— 形态没有真的生效"
                )
            }
        }
    }

    @Test(".rings 与「不传 layout」逐像素容差等价——默认行为未变")
    @MainActor
    func ringsMatchesTheDefaultLayout() throws {
        let explicit = try #require(Self.shot(layout: .rings), "渲染失败")
        let implicit = try #require(Self.shot(layout: nil), "渲染失败")
        // 容差比较：macOS 离屏渲染无逐字节确定性（#317）。
        expectBitmapsEquivalent(
            explicit, implicit, maxChannelDelta: 1,
            "显式 .rings 与省略 layout: 的默认行为不再等价"
        )
    }
}

// MARK: - RadarChart

@Suite("RadarChart 布局形态的位图判据（#312）")
struct RadarChartLayoutBitmapTests {
    private nonisolated struct Metric: ChartValue {
        let id = UUID()
        let label: String
        let value: Double
    }

    private static let values = [
        Metric(label: "A", value: 82), Metric(label: "B", value: 61), Metric(label: "C", value: 94),
        Metric(label: "D", value: 47), Metric(label: "E", value: 73),
    ]

    @MainActor
    private static func shot(layout: RadarChartLayout?) -> Data? {
        let body: AnyView = if let layout {
            AnyView(RadarChart(Self.values, layout: layout))
        } else {
            AnyView(RadarChart(Self.values))
        }
        return ChartRender.stable(
            body.frame(width: 240, height: 220).environment(\.colorScheme, .light)
        )
    }

    @Test("四个 layout 在同一份数据上两两位图不同")
    @MainActor
    func layoutsRenderDistinctBitmaps() throws {
        let layouts = RadarChartLayout.allCases
        var shots: [Data] = []
        for layout in layouts {
            shots.append(try #require(Self.shot(layout: layout), "\(layout) 渲染失败"))
        }
        for i in 0..<layouts.count {
            for j in (i + 1)..<layouts.count {
                expectBitmapsDiffer(
                    shots[i], shots[j],
                    "\(layouts[i]) 与 \(layouts[j]) 的位图逐字节相同 —— 形态没有真的生效"
                )
            }
        }
    }

    @Test(".polygon 与「不传 layout」逐像素容差等价——默认行为未变")
    @MainActor
    func polygonMatchesTheDefaultLayout() throws {
        let explicit = try #require(Self.shot(layout: .polygon), "渲染失败")
        let implicit = try #require(Self.shot(layout: nil), "渲染失败")
        expectBitmapsEquivalent(
            explicit, implicit, maxChannelDelta: 1,
            "显式 .polygon 与省略 layout: 的默认行为不再等价"
        )
    }
}
