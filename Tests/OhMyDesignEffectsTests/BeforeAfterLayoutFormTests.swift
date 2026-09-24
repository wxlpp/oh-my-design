import CoreGraphics
import Foundation
import OhMyDesign
import SwiftUI
import Testing

@testable import OhMyDesignEffects

// MARK: - 布局形态扩展点（Issue #312 · 形态 D2）

@Suite("BeforeAfterSlider 的布局形态（#312）")
struct BeforeAfterLayoutFormTests {
    // MARK: - paneExtents

    @Test("两窗格长度之和等于钳位后的 extent")
    func paneExtentsSumMatchesClampedExtent() {
        for extent: CGFloat in [0, 1, 50, 240, 1000] {
            for fraction: CGFloat in [0, 0.25, 0.5, 0.75, 1] {
                let extents = BeforeAfterSweep.paneExtents(fraction: fraction, extent: extent)
                #expect(
                    abs((extents.first + extents.second) - extent) < 0.0001,
                    "extent=\(extent) fraction=\(fraction)：first+second=\(extents.first + extents.second)"
                )
            }
        }
    }

    @Test("fraction 越界被钳到 0...1")
    func paneExtentsClampsOutOfRangeFraction() {
        let extent: CGFloat = 200
        let below = BeforeAfterSweep.paneExtents(fraction: -3, extent: extent)
        let above = BeforeAfterSweep.paneExtents(fraction: 5, extent: extent)
        #expect(below.first == 0 && below.second == extent, "fraction < 0 应等同于 0：\(below)")
        #expect(above.first == extent && above.second == 0, "fraction > 1 应等同于 1：\(above)")
    }

    @Test("fraction = 0.5 均分")
    func paneExtentsSplitsEvenlyAtHalf() {
        let extents = BeforeAfterSweep.paneExtents(fraction: 0.5, extent: 240)
        #expect(extents.first == 120 && extents.second == 120, "0.5 应均分，实为 \(extents)")
    }

    @Test("extent <= 0 时两个窗格都为 0")
    func paneExtentsAreZeroForNonPositiveExtent() {
        for extent: CGFloat in [0, -1, -100] {
            let extents = BeforeAfterSweep.paneExtents(fraction: 0.5, extent: extent)
            #expect(extents.first == 0 && extents.second == 0, "extent=\(extent) 应给出 (0, 0)，实为 \(extents)")
        }
    }

    // MARK: - fraction(dragCoordinate:extent:) 与既有 fraction(dragX:width:) 的回归

    @Test("fraction(dragCoordinate:extent:) 在同输入上与既有 fraction(dragX:width:) 相等")
    func dragCoordinateFractionMatchesLegacyDragXFraction() {
        let cases: [(CGFloat, CGFloat)] = [(-50, 200), (0, 200), (50, 200), (200, 200), (500, 200), (10, 0)]
        for (coordinate, extent) in cases {
            let legacy = BeforeAfterSweep.fraction(dragX: coordinate, width: extent)
            let renamed = BeforeAfterSweep.fraction(dragCoordinate: coordinate, extent: extent)
            #expect(legacy == renamed, "coordinate=\(coordinate) extent=\(extent)：legacy=\(legacy) renamed=\(renamed)")
        }
    }

    // MARK: - axis(for:)

    @Test("axis(for:) 的三 case 映射钉死——只有 .stacked 是竖轴")
    func axisMappingIsPinned() {
        #expect(BeforeAfterSweep.axis(for: .overlay) == .horizontal)
        #expect(BeforeAfterSweep.axis(for: .sideBySide) == .horizontal)
        #expect(BeforeAfterSweep.axis(for: .stacked) == .vertical)
    }

    // MARK: - view 实际走的路径（位图）

    @MainActor
    private enum Render {
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
            let probe = Rectangle().fill(Color.accent).frame(width: 240, height: 140)
            for _ in 0..<8 { _ = Self.pixels(probe) }
            return true
        }()

        static func stable(_ view: some View) -> Data? {
            _ = Self.warmUp
            _ = Self.pixels(view)
            _ = Self.pixels(view)
            return Self.pixels(view)
        }
    }

    /// 水平渐变——同一块画布位置在**更窄的窗格里**取样比例不同，
    /// 足以让 overlay（未按窗格切）与 sideBySide/stacked（按窗格切）在同一份数据上分出位图。
    private static func swatch(_ color: Color) -> some View {
        LinearGradient(colors: [color, color.opacity(0.25)], startPoint: .leading, endPoint: .trailing)
    }

    @MainActor
    private static func shot(
        layout: BeforeAfterSliderLayout? = nil,
        content: (before: some View, after: some View),
        fraction: CGFloat = 0.5,
        labels: BeforeAfterSliderLabels = .hidden
    ) -> Data? {
        let before = AnyView(content.before)
        let after = AnyView(content.after)
        let body: BeforeAfterSliderBody<AnyView, AnyView> =
            if let layout {
                BeforeAfterSliderBody(fraction: fraction, labels: labels, layout: layout, before: before, after: after)
            } else {
                BeforeAfterSliderBody(fraction: fraction, labels: labels, before: before, after: after)
            }
        return Render.stable(body.frame(width: 240, height: 140))
    }

    @MainActor
    private static func gradientShot(layout: BeforeAfterSliderLayout? = nil) -> Data? {
        Self.shot(
            layout: layout,
            content: (Self.swatch(Color.dataAccent), Self.swatch(Color.statusSuccessForeground))
        )
    }

    @MainActor
    private static func flatShot(layout: BeforeAfterSliderLayout? = nil) -> Data? {
        Self.shot(layout: layout, content: (Color.dataAccent, Color.statusSuccessForeground))
    }

    @Test("三种 layout 在同一份数据上两两位图不同")
    @MainActor
    func layoutsRenderDistinctBitmaps() throws {
        let overlay = try #require(Self.gradientShot(layout: .overlay), "渲染失败，下面的差异断言会静默变绿")
        let sideBySide = try #require(Self.gradientShot(layout: .sideBySide), "渲染失败")
        let stacked = try #require(Self.gradientShot(layout: .stacked), "渲染失败")

        expectBitmapsDiffer(overlay, sideBySide, "overlay 与 sideBySide 的位图逐字节相同 —— 形态没生效")
        expectBitmapsDiffer(overlay, stacked, "overlay 与 stacked 的位图逐字节相同 —— 形态没生效")
        expectBitmapsDiffer(sideBySide, stacked, "sideBySide 与 stacked 的位图逐字节相同 —— 形态没生效")
    }

    @Test(".overlay 与「不传 layout」逐像素等价——默认行为未变")
    @MainActor
    func overlayMatchesTheDefaultLayout() throws {
        let explicit = try #require(Self.flatShot(layout: .overlay), "渲染失败")
        let implicit = try #require(Self.flatShot(layout: nil), "渲染失败")
        // ⚠️ 容差比较：macOS 离屏渲染的首渲变体与稳定输出之间有 1 LSB 噪声（#317），
        // 逐字节比较在本平台不成立，见 BitmapExpectations.swift 的 expectBitmapsEquivalent 文档。
        expectBitmapsEquivalent(
            explicit, implicit, maxChannelDelta: 1,
            "显式 .overlay 与省略 layout: 的默认行为不再等价"
        )
    }
}
