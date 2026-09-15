import Foundation
import OhMyDesign
import SwiftUI
import Testing

@testable import OhMyDesignEffects

// MARK: - OrbitingLogos 布局形态（Issue #312 · 形态 D2）

@MainActor
@Suite("OrbitingLogos 布局形态的契约")
struct OrbitingLogosLayoutFormTests {
    // MARK: 纯几何

    @Test("point(…) 默认 aspect 与旧签名逐位相同，非默认 aspect 只按比例改变 y")
    func pointAspectMatchesLegacyAtOneAndScalesYElsewhere() {
        let center = CGPoint(x: 50, y: 80)
        for angle in stride(from: 0.0, to: 2 * Double.pi, by: 0.37) {
            for radius in [0.0, 10.0, 120.0] {
                let legacy = CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
                let defaulted = OrbitRing.point(angle: angle, radius: radius, center: center)
                #expect(defaulted.x == legacy.x && defaulted.y == legacy.y, """
                angle=\(angle) radius=\(radius)：默认 aspect 与旧签名不是逐位相同（\(defaulted) vs \(legacy)）
                """)

                let warped = OrbitRing.point(angle: angle, radius: radius, center: center, aspect: 0.55)
                #expect(warped.x == legacy.x, "aspect 不该动 x")
                #expect(abs((warped.y - center.y) - (legacy.y - center.y) * 0.55) < 1e-9,
                        "aspect 没有按比例只改变 y：\(warped.y) vs 期望 \(center.y + (legacy.y - center.y) * 0.55)")
            }
        }
    }

    @Test("ring(forLogo:) 只在 .multiRing 下分圈，.outerRing / .ellipse 恒 0")
    func ringAssignmentOnlyAppliesToMultiRing() {
        for layout in [OrbitingLogosLayout.outerRing, .ellipse] {
            for index in 0..<8 {
                #expect(OrbitRing.ring(forLogo: index, layout: layout) == 0,
                        "layout=\(layout) index=\(index) 不应分圈")
            }
        }

        var buckets: [Int: Int] = [:]
        for index in 0..<8 {
            let ring = OrbitRing.ring(forLogo: index, layout: .multiRing)
            #expect(ring >= 0 && ring < OrbitRing.ringCount, "ring 越界：\(ring)")
            buckets[ring, default: 0] += 1
        }
        #expect(buckets.count == OrbitRing.ringCount, "8 个 logo 没有落满 \(OrbitRing.ringCount) 圈：\(buckets)")
        for (ring, count) in buckets {
            #expect(count == 2, "第 \(ring) 圈落了 \(count) 个 logo，应为 2 个")
        }
    }

    @Test(".ellipse 下全部 logo 点落在同一个椭圆上")
    func ellipseLogosLieOnTheEllipse() {
        let side = 300.0
        let middle = CGPoint(x: 150, y: 150)
        let seats = OrbitRing.seats(particleScale: 1)
        let count = 8
        let rx = OrbitRing.ringRadius(ring: 0, size: side)
        let ry = rx * OrbitRing.ellipseAspect

        for index in 0..<count {
            let ring = OrbitRing.ring(forLogo: index, layout: .ellipse)
            #expect(ring == 0, ".ellipse 下不该分圈")
            let angle = OrbitRing.logoAngle(logoIndex: index, logoCount: count, dotsPerRing: seats, turns: 0)
            let point = OrbitRing.point(
                angle: angle, radius: OrbitRing.ringRadius(ring: ring, size: side), center: middle,
                aspect: OrbitRing.aspect(for: .ellipse)
            )
            let dx = (point.x - middle.x) / rx
            let dy = (point.y - middle.y) / ry
            #expect(abs(dx * dx + dy * dy - 1) < 1e-9,
                    "index=\(index) 的点不在椭圆上：dx²+dy²=\(dx * dx + dy * dy)")
        }
    }

    // MARK: view 路径（位图）

    private static func body(layout: OrbitingLogosLayout, layers: OrbitLayers = .full) -> some View {
        CrossPlatformRenderTests.staged(
            OrbitingLogosBody(
                items: OrbitingLogosPreviewItem.samples,
                colors: [],
                turns: OrbitRing.restingPhase,
                feature: OrbitRing.restingFeature,
                layers: layers,
                layout: layout,
                logo: { item in CrossPlatformRenderTests.orbitLogo(item) },
                center: CrossPlatformRenderTests.orbitCenter
            )
        )
    }

    private static func container(layout: OrbitingLogosLayout) -> some View {
        OrbitingLogos(
            OrbitingLogosPreviewItem.samples, colors: [], rotationPeriod: OrbitRing.rotationPeriod, layout: layout
        ) { item in
            CrossPlatformRenderTests.orbitLogo(item)
        } center: {
            CrossPlatformRenderTests.orbitCenter
        }
    }

    @Test("三个 layout 的静止帧两两不同，.outerRing 与不传 layout 的默认位图等价")
    func layoutsProduceDistinctStillFrames() {
        let outer = CrossPlatformRenderTests.pixels(Self.body(layout: .outerRing))
        let multi = CrossPlatformRenderTests.pixels(Self.body(layout: .multiRing))
        let ellipse = CrossPlatformRenderTests.pixels(Self.body(layout: .ellipse))
        #expect(outer != nil && multi != nil && ellipse != nil, "渲染失败 —— 不得当作通过")
        expectBitmapsDiffer(outer, multi, ".outerRing 与 .multiRing 渲成了同一张图")
        expectBitmapsDiffer(outer, ellipse, ".outerRing 与 .ellipse 渲成了同一张图")
        expectBitmapsDiffer(multi, ellipse, ".multiRing 与 .ellipse 渲成了同一张图")

        let defaulted = CrossPlatformRenderTests.pixels(CrossPlatformRenderTests.staged(CrossPlatformRenderTests.orbitBody()))
        expectBitmapsEquivalent(outer, defaulted, maxChannelDelta: 1,
                                "不传 layout 的默认位图与显式 .outerRing 不同 —— 默认形态被改动了")
    }

    @Test(".background 下三个 layout 都摘掉装饰、只剩各自的内容帧（能耗闸与形态正交）")
    func backgroundStripsDecorationRegardlessOfLayout() {
        for layout in OrbitingLogosLayout.allCases {
            let contentOnly = CrossPlatformRenderTests.pixels(Self.body(layout: layout, layers: .contentOnly))
            #expect(contentOnly != nil, "layout=\(layout) 内容层渲染失败")
            expectBitmapsDiffer(contentOnly, CrossPlatformRenderTests.blank,
                                "layout=\(layout) 内容层自己就画不出东西 —— 下面的相等断言会恒真")

            let backgrounded = CrossPlatformRenderTests.pixels(
                CrossPlatformRenderTests.staged(Self.container(layout: layout), phase: .background)
            )
            #expect(backgrounded != nil, "layout=\(layout) 渲染失败")
            expectBitmapsEquivalent(backgrounded, contentOnly, maxChannelDelta: 1, """
            layout=\(layout) 在 .background 下渲出的不是「只有内容」那一帧 —— 装饰层与形态没有正交。
            """)
        }
    }
}
