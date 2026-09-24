import SwiftUI
import Testing
@testable import OhMyDesign

// MARK: - 渲染 / Rendering（2x，两腿同一采样密度）

@MainActor
func renderTimelineFixture(_ view: some View, size: CGSize, scheme: ColorScheme) -> HostedPixels {
    let host = HostedWindow(view, size: size, scheme: scheme)
    defer { host.close() }
    #if canImport(UIKit)
    return host.pixels(scale: 2)
    #else
    let bounds = host.root.bounds
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: Int(bounds.width * 2), pixelsHigh: Int(bounds.height * 2),
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    ) else { return HostedPixels(nil, scale: 1) }
    rep.size = bounds.size
    host.root.cacheDisplay(in: bounds, to: rep)
    return HostedPixels(rep.cgImage, scale: 2)
    #endif
}

// MARK: - 纯函数 / Pure geometry

@Suite("Timeline 几何纯函数")
struct TimelineGeometryPureTests {
    private static let badValues: [CGFloat] = [.nan, .infinity, -.infinity, -5]

    @Test("nodeBox：报告尺寸不足 24 取 24、更大的原样；非有限 / 负数取 24")
    func nodeBoxClampsToMinimumExtent() {
        #expect(TimelineStackLayout.nodeBox(reported: CGSize(width: 10, height: 10)) == CGSize(width: 24, height: 24))
        #expect(TimelineStackLayout.nodeBox(reported: CGSize(width: 40, height: 56)) == CGSize(width: 40, height: 56))
        #expect(TimelineStackLayout.nodeBox(reported: CGSize(width: 20, height: 56)) == CGSize(width: 24, height: 56))
        for bad in Self.badValues {
            #expect(TimelineStackLayout.nodeBox(reported: CGSize(width: bad, height: bad)) == CGSize(width: 24, height: 24),
                    "报告尺寸 \(bad) 应落到下限 24")
        }
    }

    @Test("nodeColumnWidth：取最宽的盒；空数组 24；非有限 / 负数不参与，结果恒有限且 ≥ 24")
    func nodeColumnWidthTakesWidestFiniteBox() {
        #expect(TimelineStackLayout.nodeColumnWidth(boxWidths: []) == 24)
        #expect(TimelineStackLayout.nodeColumnWidth(boxWidths: [24, 40, 20]) == 40)
        #expect(TimelineStackLayout.nodeColumnWidth(boxWidths: [.nan, 30]) == 30)
        #expect(TimelineStackLayout.nodeColumnWidth(boxWidths: [30, .nan]) == 30)
        for bad in Self.badValues {
            let width = TimelineStackLayout.nodeColumnWidth(boxWidths: [bad])
            #expect(width == 24, "单个 \(bad) 应得下限 24，实际 \(width)")
        }
    }

    @Test("verticalRowHeight：非末行 max(盒高 + sm, 内容高 + lg)，末行 max(盒高, 内容高)；负数与非有限按 0")
    func verticalRowHeightFormula() {
        #expect(TimelineStackLayout.verticalRowHeight(box: 24, content: 20, isLast: false) == 36)
        #expect(TimelineStackLayout.verticalRowHeight(box: 56, content: 20, isLast: false) == 64)
        #expect(TimelineStackLayout.verticalRowHeight(box: 24, content: 60, isLast: false) == 76)
        #expect(TimelineStackLayout.verticalRowHeight(box: 24, content: 10, isLast: false) == 32)
        #expect(TimelineStackLayout.verticalRowHeight(box: 24, content: 20, isLast: true) == 24)
        #expect(TimelineStackLayout.verticalRowHeight(box: 56, content: 20, isLast: true) == 56)
        for bad in Self.badValues {
            #expect(TimelineStackLayout.verticalRowHeight(box: bad, content: bad, isLast: false) == 16)
            #expect(TimelineStackLayout.verticalRowHeight(box: bad, content: bad, isLast: true) == 0)
        }
    }

    @Test("alternateRowMetrics(forRowWidth:nodeColumnWidth:)：槽宽按实际列宽扣除，中心恒在行中；两个参数都防非有限")
    func alternateMetricsUseColumnWidth() {
        let wide = TimelineStackLayout.alternateRowMetrics(forRowWidth: 300, nodeColumnWidth: 40)
        #expect(wide.slotWidth == 118)
        #expect(wide.nodeCenterX == 150)
        #expect(wide.rowWidth == 300)
        #expect(TimelineStackLayout.alternateRowMetrics(forRowWidth: 300, nodeColumnWidth: 24)
                == Timeline.alternateRowMetrics(forRowWidth: 300))
        for bad in Self.badValues + [10] {
            #expect(TimelineStackLayout.alternateRowMetrics(forRowWidth: 300, nodeColumnWidth: bad)
                    == TimelineStackLayout.alternateRowMetrics(forRowWidth: 300, nodeColumnWidth: 24),
                    "列宽 \(bad) 应按下限 24 处理")
        }
        for bad in Self.badValues {
            let metrics = TimelineStackLayout.alternateRowMetrics(forRowWidth: bad, nodeColumnWidth: 40)
            #expect(metrics.slotWidth.isFinite && metrics.slotWidth >= 0)
            #expect(metrics.nodeCenterX.isFinite)
            #expect(metrics.rowWidth.isFinite && metrics.rowWidth >= 64)
        }
    }

    @Test("horizontalAxis：横轴 = 最高盒 / 2，内容顶 = 最高盒 + sm；空数组与非有限按 24")
    func horizontalAxisFromTallestBox() {
        #expect(TimelineStackLayout.horizontalAxis(boxHeights: [24, 56, 24])
                == TimelineStackLayout.HorizontalAxis(axisY: 28, contentTop: 64))
        #expect(TimelineStackLayout.horizontalAxis(boxHeights: [])
                == TimelineStackLayout.HorizontalAxis(axisY: 12, contentTop: 32))
        for bad in Self.badValues {
            #expect(TimelineStackLayout.horizontalAxis(boxHeights: [bad])
                    == TimelineStackLayout.HorizontalAxis(axisY: 12, contentTop: 32))
        }
    }

    @Test("connectorSpan：两盒相邻边的距离，恒 ≥ 0，非有限得 0")
    func connectorSpanIsNonNegative() {
        #expect(TimelineStackLayout.connectorSpan(from: 24, to: 76) == 52)
        #expect(TimelineStackLayout.connectorSpan(from: 76, to: 24) == 0)
        for bad in Self.badValues where !bad.isFinite {
            #expect(TimelineStackLayout.connectorSpan(from: bad, to: 10) == 0)
            #expect(TimelineStackLayout.connectorSpan(from: 10, to: bad) == 0)
        }
    }
}

// MARK: - 位图 / Rendered geometry（macOS）

#if os(macOS)
@Suite("Timeline 几何位图")
@MainActor
struct TimelineGeometryRenderTests {
    private struct Canvas {
        let pixels: HostedPixels

        func device(_ x: Int, _ y: Int) -> (r: Int, g: Int, b: Int, a: Int) {
            guard let bytes = self.pixels.bytes, x >= 0, y >= 0, x < self.pixels.width, y < self.pixels.height else {
                return (-1, -1, -1, -1)
            }
            let offset = (y * self.pixels.width + x) * 4
            return (Int(bytes[offset]), Int(bytes[offset + 1]), Int(bytes[offset + 2]), Int(bytes[offset + 3]))
        }

        func deltaFromWhite(device x: Int, _ y: Int) -> Int {
            let p = self.device(x, y)
            return Swift.max(255 - p.r, 255 - p.g, 255 - p.b)
        }

        func isBlack(_ x: Int, _ y: Int) -> Bool {
            let p = self.device(x, y)
            return p.r < 40 && p.g < 40 && p.b < 40
        }

        func isBlue(_ x: Int, _ y: Int) -> Bool {
            let p = self.device(x, y)
            return p.b > 200 && p.r < 60 && p.g < 60
        }

        func firstX(inRow y: CGFloat, from: CGFloat = 0, _ match: (Int, Int) -> Bool) -> CGFloat? {
            let row = Int(y * self.pixels.scale)
            for x in Int(from * self.pixels.scale)..<self.pixels.width where match(x, row) {
                return CGFloat(x) / self.pixels.scale
            }
            return nil
        }

        func lastX(inRow y: CGFloat, before: CGFloat, _ match: (Int, Int) -> Bool) -> CGFloat? {
            let row = Int(y * self.pixels.scale)
            for x in stride(from: Int(before * self.pixels.scale) - 1, through: 0, by: -1) where match(x, row) {
                return CGFloat(x + 1) / self.pixels.scale
            }
            return nil
        }

        func firstY(inColumn x: CGFloat, from: CGFloat = 0, _ match: (Int, Int) -> Bool) -> CGFloat? {
            let column = Int(x * self.pixels.scale)
            for y in Int(from * self.pixels.scale)..<self.pixels.height where match(column, y) {
                return CGFloat(y) / self.pixels.scale
            }
            return nil
        }

        func blackCenterX(inRow y: CGFloat) -> CGFloat? {
            guard let first = self.firstX(inRow: y, self.isBlack) else { return nil }
            let row = Int(y * self.pixels.scale)
            var end = Int(first * self.pixels.scale)
            while end < self.pixels.width, self.isBlack(end, row) { end += 1 }
            return (first + CGFloat(end) / self.pixels.scale) / 2
        }

        func blackCenterY(inColumn x: CGFloat) -> CGFloat? {
            guard let first = self.firstY(inColumn: x, self.isBlack) else { return nil }
            let column = Int(x * self.pixels.scale)
            var end = Int(first * self.pixels.scale)
            while end < self.pixels.height, self.isBlack(column, end) { end += 1 }
            return (first + CGFloat(end) / self.pixels.scale) / 2
        }
    }

    private static func render(
        _ view: some View, size: CGSize = CGSize(width: 300, height: 240), direction: LayoutDirection = .leftToRight
    ) -> Canvas {
        Canvas(pixels: renderTimelineFixture(
            view
                .environment(\.coreMotionPresentationOverride, .resting)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(Color.white)
                .environment(\.layoutDirection, direction),
            size: size, scheme: .light
        ))
    }

    private static func block(width: CGFloat = 60, height: CGFloat) -> some View {
        Color(red: 0, green: 0, blue: 1).frame(width: width, height: height)
    }

    private static func tallHollowNode() -> some View {
        Color.clear.frame(width: 40, height: 56).overlay(alignment: .top) {
            Color.black.frame(width: 10, height: 10)
        }
    }

    private static func mixedItems() -> [TimelineItem] {
        [
            TimelineItem(status: .neutral) { Color.black.frame(width: 24, height: 24) } content: { Self.block(height: 60) },
            TimelineItem(status: .neutral) { Self.tallHollowNode() } content: { Self.block(height: 20) },
            TimelineItem(status: .neutral) { Color.black.frame(width: 20, height: 20) } content: { Self.block(height: 20) },
        ]
    }

    private static let rowTops: [CGFloat] = [0, 76, 140]

    @Test("列宽 = 最宽节点：24 / 40×56 / 20 三行，内容左缘都在 40 + md，节点中心都在 20")
    func columnWidthIsWidestNode() {
        let canvas = Self.render(Timeline(items: Self.mixedItems()))
        for (row, top) in Self.rowTops.enumerated() {
            let left = canvas.firstX(inRow: top + 10, canvas.isBlue)
            #expect(left.map { abs($0 - 52) <= 1 } == true, "第 \(row) 行内容左缘 \(String(describing: left))，应为 52")
            let contentTop = canvas.firstY(inColumn: 80, from: top == 0 ? 0 : top - 6, canvas.isBlue)
            #expect(contentTop.map { abs($0 - top) <= 1 } == true, "第 \(row) 行内容顶 \(String(describing: contentTop))，应为 \(top)")
        }
        for y in [CGFloat(12), 80, 152] {
            let center = canvas.blackCenterX(inRow: y)
            #expect(center.map { abs($0 - 20) <= 1 } == true, "y=\(y) 的节点中心 \(String(describing: center))，应在中轴 20")
        }
    }

    @Test("高节点不被穿过：40×56 盒内部无连线像素，连线从盒下沿起、到下一盒上沿止")
    func tallNodeIsNotCrossed() {
        let canvas = Self.render(Timeline(items: Self.mixedItems()))
        let column = Int(20 * canvas.pixels.scale)
        let d = canvas.deltaFromWhite(device: column, Int(50 * canvas.pixels.scale))
        #expect(d >= 6, "连线在白底上与背景只差 \(d)，无法下结论")
        guard d >= 6 else { return }
        let isLine: (Int, Int) -> Bool = { x, y in
            let delta = canvas.deltaFromWhite(device: x, y)
            return delta >= d / 2 && delta <= d * 2
        }

        for y in Int(87 * canvas.pixels.scale)..<Int(131 * canvas.pixels.scale) {
            #expect(!isLine(column, y), "40×56 盒内部 y=\(CGFloat(y) / canvas.pixels.scale) 出现连线像素")
            if isLine(column, y) { break }
        }
        let firstBelowTall = canvas.firstY(inColumn: CGFloat(column) / canvas.pixels.scale, from: 87, isLine)
        #expect(firstBelowTall.map { abs($0 - 132) <= 1 } == true,
                "高节点下方连线首像素 \(String(describing: firstBelowTall))，应为盒下沿 132")

        var y = Int(50 * canvas.pixels.scale)
        while y < canvas.pixels.height, isLine(column, y) { y += 1 }
        let lastAboveTall = CGFloat(y - 1) / canvas.pixels.scale
        #expect(abs(lastAboveTall - 75) <= 1, "第 0 段连线末像素 \(lastAboveTall)，应为下一盒上沿 76 − 1")

        y = Int(133 * canvas.pixels.scale)
        while y < canvas.pixels.height, isLine(column, y) { y += 1 }
        let lastAboveLast = CGFloat(y - 1) / canvas.pixels.scale
        #expect(abs(lastAboveLast - 139) <= 1, "第 1 段连线末像素 \(lastAboveLast)，应为下一盒上沿 140 − 1")
    }

    @Test(".alternate 中轴一致：三行节点中心都在行宽 / 2，两侧内容与中轴等距 = 列宽 / 2 + md")
    func alternateAxisIsShared() {
        let canvas = Self.render(Timeline(items: Self.mixedItems(), layout: .alternate))
        for y in [CGFloat(12), 80, 152] {
            let center = canvas.blackCenterX(inRow: y)
            #expect(center.map { abs($0 - 150) <= 1 } == true, "y=\(y) 的节点中心 \(String(describing: center))，应为 150")
        }
        let leftEdge = canvas.lastX(inRow: 10, before: 150, canvas.isBlue)
        #expect(leftEdge.map { abs($0 - 118) <= 1 } == true, "左侧内容右缘 \(String(describing: leftEdge))，应为 150 − 20 − 12")
        let rightEdge = canvas.firstX(inRow: 86, from: 150, canvas.isBlue)
        #expect(rightEdge.map { abs($0 - 182) <= 1 } == true, "右侧内容左缘 \(String(describing: rightEdge))，应为 150 + 20 + 12")
    }

    @Test(".alternate 内容宽于槽时向外（远离中轴）溢出，不压节点")
    func alternateOverflowGoesOutward() {
        let items = [
            TimelineItem(status: .neutral) { Color.black.frame(width: 24, height: 24) } content: { Self.block(width: 200, height: 24) },
            TimelineItem(status: .neutral) { Color.black.frame(width: 24, height: 24) } content: { Self.block(width: 200, height: 24) },
        ]
        let canvas = Self.render(Timeline(items: items, layout: .alternate))
        let scale = canvas.pixels.scale
        for y in [CGFloat(12), 52] {
            #expect(canvas.isBlack(Int(150 * scale), Int(y * scale)), "y=\(y)：中轴上的节点被宽内容盖住了")
        }
        let leftEdge = canvas.lastX(inRow: 12, before: 150, canvas.isBlue)
        #expect(leftEdge.map { abs($0 - 126) <= 1 } == true, "左槽宽内容右缘 \(String(describing: leftEdge))，应停在槽右沿 126")
        let rightEdge = canvas.firstX(inRow: 52, from: 150, canvas.isBlue)
        #expect(rightEdge.map { abs($0 - 174) <= 1 } == true, "右槽宽内容左缘 \(String(describing: rightEdge))，应从 174 起")
    }

    @Test(".horizontal 横轴与内容顶：盒高 24 / 56 混排，节点中心同一行、内容顶都在 56 + sm，横轴上有连线")
    func horizontalAxisAndContentTop() {
        let items = [
            TimelineItem(status: .neutral) { Color.black.frame(width: 24, height: 24) } content: { Self.block(height: 20) },
            TimelineItem(status: .neutral) { Color.black.frame(width: 20, height: 56) } content: { Self.block(height: 20) },
            TimelineItem(status: .neutral) { Color.black.frame(width: 24, height: 24) } content: { Self.block(height: 20) },
        ]
        let canvas = Self.render(Timeline(items: items, layout: .horizontal))
        for x in [CGFloat(30), 106, 182] {
            let center = canvas.blackCenterY(inColumn: x)
            #expect(center.map { abs($0 - 28) <= 1 } == true, "x=\(x) 的节点中心 \(String(describing: center))，应在横轴 28")
            let top = canvas.firstY(inColumn: x, from: 57, canvas.isBlue)
            #expect(top.map { abs($0 - 64) <= 1 } == true, "x=\(x) 的内容顶 \(String(describing: top))，应为 56 + 8")
        }
        let d = canvas.deltaFromWhite(device: Int(68 * canvas.pixels.scale), Int(28 * canvas.pixels.scale))
        #expect(d >= 6, "横轴 x=68 处应有连线，与背景只差 \(d)")
    }

    private static func oddWidthItems() -> [TimelineItem] {
        [
            TimelineItem(status: .neutral) { Color.black.frame(width: 25, height: 25) } content: { Self.block(height: 60) },
            TimelineItem(status: .neutral) {
                Color.clear.frame(width: 41, height: 56).overlay(alignment: .top) { Color.black.frame(width: 11, height: 11) }
            } content: { Self.block(height: 20) },
            TimelineItem(status: .neutral) { Color.black.frame(width: 21, height: 21) } content: { Self.block(height: 20) },
        ]
    }

    @Test("RTL：.vertical 的 RTL 图 = LTR 图水平翻转（奇数宽节点，使节点与连线落在整点上、不受取整方向影响）")
    func rightToLeftMirrorsLeftToRight() {
        let ltr = Self.render(Timeline(items: Self.oddWidthItems())).pixels
        let rtl = Self.render(Timeline(items: Self.oddWidthItems()), direction: .rightToLeft).pixels
        guard let bytes = ltr.bytes else {
            expectBitmapsEqual(ltr.bytes, rtl.bytes, "LTR 未渲染")
            return
        }
        var mirrored = bytes
        for y in 0..<ltr.height {
            for x in 0..<ltr.width {
                let source = (y * ltr.width + x) * 4
                let target = (y * ltr.width + (ltr.width - 1 - x)) * 4
                for channel in 0..<4 { mirrored[target + channel] = bytes[source + channel] }
            }
        }
        expectBitmapsEquivalent(mirrored, rtl.bytes, maxChannelDelta: 2, "RTL 不是 LTR 的水平翻转")
    }
}
#endif
