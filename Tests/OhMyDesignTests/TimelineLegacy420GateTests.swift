import SwiftUI
import Testing
@testable import OhMyDesign

// MARK: - 旧实现闸门 / Legacy gate（#420 PR 1–4）

@Suite("Timeline 旧实现闸门")
@MainActor
struct TimelineLegacy420GateTests {
    nonisolated enum Scheme: CaseIterable, CustomTestStringConvertible, Sendable {
        case light, dark

        var colorScheme: ColorScheme { self == .light ? .light : .dark }
        var testDescription: String { self == .light ? "light" : "dark" }
    }

    nonisolated enum PreservedLayout: CaseIterable, CustomTestStringConvertible, Sendable {
        case vertical, alternate, grouped

        var layout: TimelineLayout {
            switch self {
            case .vertical: .vertical
            case .alternate: .alternate
            case .grouped: .grouped
            }
        }

        var testDescription: String {
            switch self {
            case .vertical: "vertical"
            case .alternate: "alternate"
            case .grouped: "grouped"
            }
        }
    }

    private static let size = CGSize(width: 320, height: 900)
    private static let horizontalSize = CGSize(width: 2400, height: 120)
    private static let noiseTolerance = 2

    private static var statuses: [StatusLevel] {
        assetCatalogIsCompiled ? [.info, .success, .warning, .danger, .neutral] : [.neutral]
    }

    private enum Fixture {
        case dot(StatusLevel)
        case symbol
        case flexibleCircle
        case square20
        case emptyNode
        case multiViewNode
    }

    private static let nodeIsShown = false

    private static var fixtures: [(Fixture, String)] {
        Self.statuses.enumerated().map { (.dot($0.element), $0.offset == 0 ? Self.leadingLongText : "Event \($0.offset)") } + [
            (.symbol, "Shipped with a symbol node that wraps onto a second line in the narrow slot"),
            (.flexibleCircle, "Flexible circle"),
            (.square20, "Square 20"),
            (.emptyNode, "Empty node"),
            (.multiViewNode, "Multi-view node"),
        ]
    }

    private static let leadingLongText = "Event 0 with a description long enough to wrap inside the leading slot"

    private static func content(_ text: String) -> some View {
        Text(verbatim: text).coreFont(.callout).frame(minHeight: 20, alignment: .topLeading)
    }

    @ViewBuilder
    private static func node(_ fixture: Fixture) -> some View {
        switch fixture {
        case .dot: EmptyView()
        case .symbol: Image(systemName: "checkmark.circle.fill")
        case .flexibleCircle: Circle().fill(Color.black)
        case .square20: Color.black.frame(width: 20, height: 20)
        case .emptyNode:
            if Self.nodeIsShown { Color.black.frame(width: 10, height: 10) }
        case .multiViewNode:
            Self.plusBars()
        }
    }

    @ViewBuilder
    private static func plusBars() -> some View {
        Color.black.frame(width: 16, height: 4)
        Color.black.frame(width: 4, height: 16)
    }

    @ViewBuilder
    private static func legacyNode(_ fixture: Fixture) -> some View {
        switch fixture {
        case .emptyNode: Color.clear.frame(width: 24, height: 24)
        case .multiViewNode: ZStack { Self.plusBars() }
        default: Self.node(fixture)
        }
    }

    private static var items: [TimelineItem] {
        Self.fixtures.map { fixture, text in
            if case .dot(let status) = fixture {
                TimelineItem(status: status) { Self.content(text) }
            } else {
                TimelineItem(status: .neutral) { Self.node(fixture) } content: { Self.content(text) }
            }
        }
    }

    private static var legacyItems: [Legacy420TimelineItem] {
        Self.fixtures.map { fixture, text in
            if case .dot(let status) = fixture {
                Legacy420TimelineItem(status: status) { Self.content(text) }
            } else {
                Legacy420TimelineItem(status: .neutral) { Self.legacyNode(fixture) } content: { Self.content(text) }
            }
        }
    }

    private static func render(_ view: some View, scheme: Scheme, size: CGSize = Self.size) -> HostedPixels {
        renderTimelineFixture(
            view
                .environment(\.coreMotionPresentationOverride, .resting)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading),
            size: size, scheme: scheme.colorScheme
        )
    }

    private static func isBackground(_ bytes: [UInt8], _ offset: Int) -> Bool {
        let reference = bytes.count - 4
        return bytes[offset] == bytes[reference] && bytes[offset + 1] == bytes[reference + 1]
            && bytes[offset + 2] == bytes[reference + 2] && bytes[offset + 3] == bytes[reference + 3]
    }

    private static func distinctPixelCount(_ pixels: HostedPixels) -> Int {
        guard let bytes = pixels.bytes, bytes.count >= 4 else { return 0 }
        var count = 0
        for offset in stride(from: 0, to: bytes.count, by: 4) where !Self.isBackground(bytes, offset) {
            count += 1
        }
        return count
    }

    @Test("有意保留：节点 ≤ 24、内容 ≥ 16pt 的活动流，新实现与旧实现在光栅噪声内相同（空节点对照旧实现的 24pt 空盒、多视图节点对照旧实现包 ZStack 的同一组视图），容器下方标记同一行",
          arguments: PreservedLayout.allCases, Scheme.allCases)
    func preservedLayoutsMatchLegacy(layout: PreservedLayout, scheme: Scheme) {
        let now = Self.render(Self.marked(Timeline(items: Self.items, layout: layout.layout)), scheme: scheme)
        let old = Self.render(Self.marked(Legacy420Timeline(items: Self.legacyItems, layout: layout.layout)), scheme: scheme)
        #expect(Self.distinctPixelCount(old) > 500, "\(layout) / \(scheme)：旧实现几乎没画出东西，相等判据无意义")
        let bottom = Self.bottomMarkerRow(now)
        #expect(bottom != nil && bottom == Self.bottomMarkerRow(old),
                "\(layout) / \(scheme)：容器下方标记行 \(String(describing: bottom))，旧实现 \(String(describing: Self.bottomMarkerRow(old)))——容器高度不同或标记落在画布外")
        expectBitmapsEquivalent(
            now.bytes, old.bytes, maxChannelDelta: Self.noiseTolerance,
            "\(layout) / \(scheme)：新实现与旧实现不同"
        )
    }

    private static let markerHeight: CGFloat = 2

    private static func marked(_ view: some View) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Color(red: 1, green: 0, blue: 1).frame(width: 4, height: Self.markerHeight)
            view
            Color(red: 1, green: 0, blue: 1).frame(width: 4, height: Self.markerHeight)
        }
    }

    private static func isMarker(_ bytes: [UInt8], _ offset: Int) -> Bool {
        bytes[offset] > 200 && bytes[offset + 1] < 60 && bytes[offset + 2] > 200
    }

    private static func bottomMarkerRow(_ pixels: HostedPixels) -> Int? {
        guard let bytes = pixels.bytes else { return nil }
        let x = Int(pixels.scale)
        let belowTopMarker = Int(Self.markerHeight * pixels.scale)
        for y in stride(from: pixels.height - 1, through: belowTopMarker, by: -1) where Self.isMarker(bytes, (y * pixels.width + x) * 4) {
            return y
        }
        return nil
    }

    private static func axisBand(_ pixels: HostedPixels) -> ClosedRange<Int>? {
        guard let bytes = pixels.bytes else { return nil }
        let x = Int(pixels.scale)
        for y in 0..<pixels.height {
            let offset = (y * pixels.width + x) * 4
            if Self.isMarker(bytes, offset) {
                let axis = CGFloat(y) + (Self.markerHeight + Timeline.minimumNodeExtent / 2) * pixels.scale
                return Int(axis - pixels.scale)...Int(axis + pixels.scale)
            }
        }
        return nil
    }

    private static func lastColumnIsOnCanvas(_ pixels: HostedPixels) -> Bool {
        guard let bytes = pixels.bytes, bytes.count >= 4 else { return false }
        let margin = Int(CoreSpacing.lg * pixels.scale)
        for y in 0..<pixels.height {
            for x in (pixels.width - margin)..<pixels.width where !Self.isBackground(bytes, (y * pixels.width + x) * 4) {
                return false
            }
        }
        return true
    }

    private static func splitAxisBand(_ pixels: HostedPixels) -> (band: [UInt8], rest: [UInt8])? {
        guard let bytes = pixels.bytes, let axisBand = Self.axisBand(pixels) else { return nil }
        var band: [UInt8] = []
        var rest: [UInt8] = []
        for y in 0..<pixels.height {
            let row = bytes[(y * pixels.width * 4)..<((y + 1) * pixels.width * 4)]
            if axisBand.contains(y) {
                band.append(contentsOf: row)
            } else {
                rest.append(contentsOf: row)
            }
        }
        return (band, rest)
    }

    @Test(".horizontal：遮掉横轴连线带后与旧实现相同；连线带本身与旧实现不同（新画了连线）", arguments: Scheme.allCases)
    func horizontalMatchesLegacyOutsideTheConnectorBand(scheme: Scheme) {
        let now = Self.render(
            Self.marked(Timeline(items: Self.items, layout: .horizontal)), scheme: scheme, size: Self.horizontalSize
        )
        let old = Self.render(
            Self.marked(Legacy420Timeline(items: Self.legacyItems, layout: .horizontal)), scheme: scheme, size: Self.horizontalSize
        )
        #expect(Self.axisBand(now) != nil && Self.axisBand(now) == Self.axisBand(old), "\(scheme)：没找到横轴定位标记")
        #expect(Self.lastColumnIsOnCanvas(old), "\(scheme)：横向最后一列落在画布外，闸门只比了一部分")
        let bottom = Self.bottomMarkerRow(now)
        #expect(bottom != nil && bottom == Self.bottomMarkerRow(old),
                "\(scheme)：容器下方标记行 \(String(describing: bottom))，旧实现 \(String(describing: Self.bottomMarkerRow(old)))——容器高度不同或标记缺失")
        #expect(Self.distinctPixelCount(old) > 500, "\(scheme)：旧实现几乎没画出东西，相等判据无意义")
        let a = Self.splitAxisBand(now)
        let b = Self.splitAxisBand(old)
        expectBitmapsEquivalent(
            a?.rest, b?.rest, maxChannelDelta: Self.noiseTolerance,
            "\(scheme)：横轴连线带以外与旧实现不同"
        )
        guard let a, let b, let metrics = bitmapDifferenceMetrics(a.band, b.band) else {
            Issue.record("\(scheme)：连线带未渲染或长度不同")
            return
        }
        let segments = Self.fixtures.count - 1
        let expectedArea = segments * Int(CoreSpacing.lg * CoreBorderWidth.thin * now.scale * now.scale)
        let differingPixels = metrics.differingCount / 3
        #expect(metrics.maxChannelDelta > 8 && differingPixels >= expectedArea / 2,
                "\(scheme)：连线带与旧实现几乎相同（maxΔ=\(metrics.maxChannelDelta)，差异像素≈\(differingPixels)，预期 ≥ \(expectedArea / 2)）——横向连线没画出来")
    }
}
