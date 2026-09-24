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

    @Test("pairRows：按行号配对；缺节点或缺内容的行照样成行（缺的一格为 nil），不丢行、不串行；同一行重复的部件取先到的")
    func pairRowsKeepsIncompleteRows() {
        typealias Part = TimelineStackLayout.Part
        typealias Row = TimelineStackLayout.Row
        let parts: [Part?] = [.connector(0), .connector(1), .node(0), .content(0), .content(1), .node(2), .content(2), nil]
        let paired = TimelineStackLayout.pairRows(parts: parts)
        #expect(paired.rows == [Row(node: 2, content: 3), Row(node: nil, content: 4), Row(node: 5, content: 6)])
        #expect(paired.connectors == [0: 0, 1: 1])
        #expect(TimelineStackLayout.pairRows(parts: [.node(0)]).rows == [Row(node: 0, content: nil)])
        #expect(TimelineStackLayout.pairRows(parts: [.node(0), .node(0), .content(0)]).rows == [Row(node: 0, content: 2)])
        #expect(TimelineStackLayout.pairRows(parts: []).rows.isEmpty)
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

        func isRed(_ x: Int, _ y: Int) -> Bool {
            let p = self.device(x, y)
            return p.r > 200 && p.g < 60 && p.b < 60
        }

        func isDark(_ x: Int, _ y: Int) -> Bool {
            let p = self.device(x, y)
            return p.r >= 0 && p.r < 128 && p.g < 128 && p.b < 128
        }

        func bounds(x: ClosedRange<CGFloat>, y: ClosedRange<CGFloat>, _ match: (Int, Int) -> Bool) -> CGRect? {
            let scale = self.pixels.scale
            var minX = Int.max, minY = Int.max, maxX = Int.min, maxY = Int.min
            for py in Int(y.lowerBound * scale)..<Swift.min(Int(y.upperBound * scale), self.pixels.height) {
                for px in Int(x.lowerBound * scale)..<Swift.min(Int(x.upperBound * scale), self.pixels.width) where match(px, py) {
                    minX = Swift.min(minX, px); maxX = Swift.max(maxX, px)
                    minY = Swift.min(minY, py); maxY = Swift.max(maxY, py)
                }
            }
            guard maxX >= minX else { return nil }
            return CGRect(
                x: CGFloat(minX) / scale, y: CGFloat(minY) / scale,
                width: CGFloat(maxX + 1 - minX) / scale, height: CGFloat(maxY + 1 - minY) / scale
            )
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

    private static let nodeIsShown = false

    @Test("空节点（if 不成立）：本行照常成行、节点盒取下限 24，内容不落到容器中心，后续行不错位")
    func emptyNodeKeepsItsRow() {
        let items = [
            TimelineItem(status: .neutral) { Color.black.frame(width: 10, height: 10) } content: { Self.block(height: 20) },
            TimelineItem(status: .neutral) {
                if Self.nodeIsShown { Color.black.frame(width: 10, height: 10) }
            } content: { Self.block(width: 40, height: 20) },
            TimelineItem(status: .neutral) { Color.black.frame(width: 10, height: 10) } content: { Self.block(height: 20) },
        ]
        let canvas = Self.render(Timeline(items: items))
        for (row, top) in [CGFloat(0), 36, 72].enumerated() {
            let blue = canvas.bounds(x: 0...300, y: top...(top + 20), canvas.isBlue)
            #expect(blue.map { abs($0.minX - 36) <= 1 && abs($0.minY - top) <= 1 } == true,
                    "第 \(row) 行内容 \(String(describing: blue))，应左缘 36、顶 \(top)")
        }
        let stray = canvas.bounds(x: 100...300, y: 0...240, canvas.isBlue)
        #expect(stray == nil, "内容落到了行外 \(String(describing: stray))")
        let node = canvas.bounds(x: 0...36, y: 36...72, canvas.isBlack)
        #expect(node == nil, "空节点行出现了节点像素 \(String(describing: node))")
    }

    @Test("多视图节点：两个视图叠在同一个节点盒里（居中），不拆成两格、不落到容器中心")
    func multiViewNodeSharesOneBox() {
        let items = [
            TimelineItem(status: .neutral) {
                Color.black.frame(width: 16, height: 4)
                Color.black.frame(width: 4, height: 16)
            } content: { Self.block(height: 20) },
            TimelineItem(status: .neutral) { Color.black.frame(width: 10, height: 10) } content: { Self.block(height: 20) },
        ]
        let canvas = Self.render(Timeline(items: items))
        let node = canvas.bounds(x: 0...300, y: 0...30, canvas.isBlack)
        #expect(node.map { abs($0.midX - 12) <= 1 && abs($0.midY - 12) <= 1 && abs($0.width - 16) <= 1 && abs($0.height - 16) <= 1 } == true,
                "多视图节点像素 \(String(describing: node))，应是以 (12, 12) 为中心的 16×16 十字")
        let blue = canvas.bounds(x: 0...300, y: 0...20, canvas.isBlue)
        #expect(blue.map { abs($0.minX - 36) <= 1 } == true, "内容 \(String(describing: blue))，应左缘 36")
        let stray = canvas.bounds(x: 30...300, y: 0...240, canvas.isBlack)
        #expect(stray == nil, "节点列以外出现节点像素 \(String(describing: stray))")
    }

    @Test("多视图内容：竖排在同一内容格里（左缘相等、间距 0），行高按两者之和算")
    func multiViewContentStacks() {
        let items = [
            TimelineItem(status: .neutral) { Color.black.frame(width: 10, height: 10) } content: {
                Self.block(height: 20)
                Color(red: 1, green: 0, blue: 0).frame(width: 40, height: 20)
            },
            TimelineItem(status: .neutral) { Color.black.frame(width: 10, height: 10) } content: { Self.block(height: 20) },
        ]
        let canvas = Self.render(Timeline(items: items))
        let first = canvas.bounds(x: 0...300, y: 0...40, canvas.isBlue)
        let second = canvas.bounds(x: 0...300, y: 0...40, canvas.isRed)
        #expect(first.map { abs($0.minX - 36) <= 1 && abs($0.minY) <= 1 } == true, "第一个内容视图 \(String(describing: first))")
        #expect(second.map { abs($0.minX - 36) <= 1 && abs($0.minY - 20) <= 1 } == true,
                "第二个内容视图 \(String(describing: second))，应左缘 36、顶 20（紧贴第一个下方）")
        let next = canvas.firstY(inColumn: 50, from: 41, canvas.isBlue)
        #expect(next.map { abs($0 - 56) <= 1 } == true, "下一行内容顶 \(String(describing: next))，应为 40 + lg = 56")
    }

    @Test("内容高 10 的非末行：行高 = 盒高 24 + sm = 32（旧实现为 max(24, 10 + lg) = 26）")
    func shortContentRowIsBoxPlusGap() {
        let items = [
            TimelineItem(status: .neutral) { Color.black.frame(width: 10, height: 10) } content: { Self.block(height: 10) },
            TimelineItem(status: .neutral) { Color.black.frame(width: 10, height: 10) } content: { Self.block(height: 10) },
        ]
        let canvas = Self.render(Timeline(items: items))
        let second = canvas.firstY(inColumn: 50, from: 11, canvas.isBlue)
        #expect(second.map { abs($0 - 32) <= 1 } == true, "第 1 行内容顶 \(String(describing: second))，应为 32")
    }

    private static let longText = "A fairly long description line that has to wrap inside the slot width"

    private static func slotted(_ view: some View) -> some View {
        view.frame(width: 300).padding(.horizontal, 50)
    }

    private static func textItems(longRow: Int) -> [TimelineItem] {
        (0..<2).map { row in
            TimelineItem(status: .neutral) {
                Color(red: 1, green: 0, blue: 0).frame(width: 10, height: 10)
            } content: {
                Text(verbatim: row == longRow ? Self.longText : "b")
            }
        }
    }

    @Test(".alternate 长文本：按槽宽换行，落在本槽内、不越过槽外缘（左右槽、RTL 同一规则）",
          arguments: [LayoutDirection.leftToRight, .rightToLeft], [0, 1])
    func alternateTextWrapsInsideSlot(direction: LayoutDirection, longRow: Int) {
        let canvas = Self.render(
            Self.slotted(Timeline(items: Self.textItems(longRow: longRow), layout: .alternate)),
            size: CGSize(width: 400, height: 240), direction: direction
        )
        let onLeading = longRow.isMultiple(of: 2)
        let onLeft = onLeading == (direction == .leftToRight)
        let slot: ClosedRange<CGFloat> = onLeft ? 50...176 : 224...350
        let search: ClosedRange<CGFloat> = onLeft ? 0...190 : 210...400
        let text = canvas.bounds(x: search, y: 0...240, canvas.isDark)
        #expect(text.map { $0.minX >= slot.lowerBound - 1 && $0.maxX <= slot.upperBound + 1 } == true,
                "长文本横向范围 \(String(describing: text))，应落在槽 \(slot) 内")
        #expect(text.map { $0.height >= 30 } == true, "长文本高 \(String(describing: text?.height))，应已换成多行")
    }

    @Test(".alternate 220pt 固定宽色块：宽于槽时越过槽外缘向外溢出，不压节点（左右槽、RTL 同一规则）",
          arguments: [LayoutDirection.leftToRight, .rightToLeft])
    func alternateFixedWidthOverflowsOutward(direction: LayoutDirection) {
        let items = (0..<2).map { _ in
            TimelineItem(status: .neutral) {
                Color(red: 1, green: 0, blue: 0).frame(width: 10, height: 10)
            } content: { Self.block(width: 220, height: 24) }
        }
        let canvas = Self.render(
            Self.slotted(Timeline(items: items, layout: .alternate)), size: CGSize(width: 400, height: 240), direction: direction
        )
        let scale = canvas.pixels.scale
        for y in [CGFloat(12), 52] {
            #expect(canvas.isRed(Int(200 * scale), Int(y * scale)), "y=\(y)：中轴上的节点被宽内容盖住了")
        }
        let firstRowOnLeft = direction == .leftToRight
        for (y, onLeft) in [(CGFloat(12), firstRowOnLeft), (52, !firstRowOnLeft)] {
            let block = canvas.bounds(x: 0...400, y: y...(y + 1), canvas.isBlue)
            let expected: (CGFloat, CGFloat) = onLeft ? (0, 176) : (224, 400)
            #expect(block.map { abs($0.minX - expected.0) <= 1 && abs($0.maxX - expected.1) <= 1 } == true,
                    "y=\(y) 的色块 \(String(describing: block))，应占 \(expected)（内缘贴槽内缘、外侧越过槽外缘到画布边）")
        }
    }

    @Test(".alternate RTL 图 = LTR 图水平翻转（220pt 溢出色块 + 节点 + 连线）")
    func alternateRightToLeftMirrors() {
        let items = (0..<3).map { row in
            TimelineItem(status: .neutral) {
                Color(red: 1, green: 0, blue: 0).frame(width: 10, height: 10)
            } content: { Self.block(width: row == 1 ? 60 : 220, height: 24) }
        }
        let size = CGSize(width: 400, height: 240)
        let ltr = Self.render(Self.slotted(Timeline(items: items, layout: .alternate)), size: size).pixels
        let rtl = Self.render(
            Self.slotted(Timeline(items: items, layout: .alternate)), size: size, direction: .rightToLeft
        ).pixels
        let axis = Int(200 * ltr.scale)
        let band = (axis - 2)...(axis + 1)
        expectBitmapsEquivalent(
            Self.masking(columns: band, in: Self.mirrored(ltr), width: ltr.width),
            Self.masking(columns: band, in: rtl.bytes, width: rtl.width),
            maxChannelDelta: 2, ".alternate RTL（中轴连线列以外）不是 LTR 的水平翻转：1pt 连线跨在两个设备像素上，镜像后取整方向不同"
        )
        let red = Self.render(Self.slotted(Timeline(items: items, layout: .alternate)), size: size, direction: .rightToLeft)
        #expect(red.isRed(Int(200 * ltr.scale), Int(12 * ltr.scale)), "RTL 中轴上的节点被遮住或不在中轴")
    }

    private static func masking(columns: ClosedRange<Int>, in bytes: [UInt8]?, width: Int) -> [UInt8]? {
        guard var bytes else { return nil }
        for offset in stride(from: 0, to: bytes.count, by: 4) where columns.contains((offset / 4) % width) {
            for channel in 0..<4 { bytes[offset + channel] = 0 }
        }
        return bytes
    }

    private static func mirrored(_ pixels: HostedPixels) -> [UInt8]? {
        guard let bytes = pixels.bytes else { return nil }
        var mirrored = bytes
        for y in 0..<pixels.height {
            for x in 0..<pixels.width {
                let source = (y * pixels.width + x) * 4
                let target = (y * pixels.width + (pixels.width - 1 - x)) * 4
                for channel in 0..<4 { mirrored[target + channel] = bytes[source + channel] }
            }
        }
        return mirrored
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
