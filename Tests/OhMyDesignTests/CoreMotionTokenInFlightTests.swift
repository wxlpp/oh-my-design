import SwiftUI
import Testing
@testable import OhMyDesign

// MARK: - 动画进行中的帧（#407 FR-3）

// iOS 上 `layer.render(in:)` 取的是模型层，拍不到进行中的帧 ⇒ 只在 macOS 腿观测。
#if os(macOS)

@MainActor
private final class SelectionBox: ObservableObject {
    @Published var value = "A"
}

private struct SegmentedHarness: View {
    @ObservedObject var box: SelectionBox

    var body: some View {
        SegmentedControl(items: ["A", "B", "C"], selection: self.$box.value, title: { $0 })
            .segmentedControlStyle(.ink)
            .frame(width: 300)
    }
}

private struct UnderlinedHarness: View {
    @ObservedObject var box: SelectionBox

    var body: some View {
        UnderlinedTabBar(items: ["A", "Bbbbbbbbbb", "C"], selection: self.$box.value, title: { $0 })
    }
}

@MainActor
private final class ExpansionBox: ObservableObject {
    @Published var isExpanded = false
}

private struct DisclosureHarness: View {
    @ObservedObject var box: ExpansionBox

    var body: some View {
        DisclosureGroup(isExpanded: self.$box.isExpanded) {
            Color.clear.frame(height: 1)
        } label: {
            Text("Details")
        }
        .disclosureGroupStyle(.core)
        .tint(.black)
        .padding(.horizontal, 20)
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

@Suite("动画进行中：Reduce Motion 下指示器只在起止两处淡变，不途经中间", .serialized)
@MainActor
struct CoreMotionTokenInFlightTests {
    enum Axis { case horizontal, vertical }

    static func motionTrace(before: HostedPixels, after: HostedPixels, frame: HostedPixels, axis: Axis = .horizontal) -> Int {
        guard let b = before.bytes, let a = after.bytes, let f = frame.bytes,
              b.count == a.count, b.count == f.count, before.width > 0 else { return -1 }
        func differs(_ x: [UInt8], _ y: [UInt8], _ i: Int, by threshold: Int) -> Bool {
            (0..<3).contains { abs(Int(x[i + $0]) - Int(y[i + $0])) > threshold }
        }
        let width = before.width, height = before.height
        let lanes = axis == .horizontal ? width : height
        let depth = axis == .horizontal ? height : width
        func index(lane: Int, step: Int) -> Int {
            (axis == .horizontal ? step * width + lane : lane * width + step) * 4
        }
        let endpointLanes = Set((0..<lanes).filter { lane in
            (0..<depth).contains { step in differs(b, a, index(lane: lane, step: step), by: 8) }
        })
        var count = 0
        for lane in 0..<lanes where !endpointLanes.contains(lane) {
            for step in 0..<depth where differs(f, b, index(lane: lane, step: step), by: 40) {
                count += 1
            }
        }
        return count
    }

    static let samplingWindows: [TimeInterval] = [0.3, 0.5, 0.8]

    // RM 关的对照组：负载下可能一帧中间态都拍不到，逐次放宽窗口在新窗口里重试；始终拍不到时判「无法下结论」而不是放行。
    static func observeControlMotion(_ name: String, threshold: Int, measure: (TimeInterval) -> Int) -> Int {
        var peaks: [Int] = []
        for window in Self.samplingWindows {
            let peak = measure(window)
            peaks.append(peak)
            if peak > threshold { return peak }
        }
        Issue.record("""
        \(name)：采样器在 \(Self.samplingWindows.count) 次尝试（窗口 \(Self.samplingWindows) s，每次新窗口）里都没观测到 RM 关时的运动 \
        （峰值 \(peaks)，阈值 > \(threshold)）—— sampler could not observe motion，判据无法下结论（inconclusive），不是通过
        """)
        return peaks.max() ?? -1
    }

    fileprivate static func peakTrace(
        _ content: some View,
        box: SelectionBox,
        target: String,
        motion: CoreMotionToken,
        reduceMotion: Bool,
        size: CGSize,
        sampleFor duration: TimeInterval = 0.3
    ) -> (peak: Int, changed: Bool) {
        let window = HostedWindow(content.environment(\.coreMotionPresentationOverride, reduceMotion ? .resting : .animated), size: size, scheme: .light)
        defer { window.close() }
        let before = window.pixels()
        var frames: [HostedPixels] = []
        withAnimation(motion.animation(for: reduceMotion ? .resting : .animated)) {
            box.value = target
        }
        let start = Date()
        while Date().timeIntervalSince(start) < duration {
            RunLoop.main.run(until: Date().addingTimeInterval(0.008))
            frames.append(window.pixels())
        }
        window.settle()
        let after = window.pixels()
        let peak = frames.map { Self.motionTrace(before: before, after: after, frame: $0) }.max() ?? -1
        return (peak, before.bytes != after.bytes)
    }

    @Test("SegmentedControl A → C：RM 关时滑块扫过 B，RM 开时只在 A、C 两处淡变")
    func segmentedThumb() {
        let size = CGSize(width: 300, height: 60)
        let boxOn = SelectionBox()
        let on = Self.peakTrace(SegmentedHarness(box: boxOn), box: boxOn, target: "C",
                                motion: .selection, reduceMotion: true, size: size)
        #expect(on.changed, "选中态没切过去，判据无效")
        #expect(on.peak == 0, "RM 开时滑块不得途经中间，实测 \(on.peak)")
        _ = Self.observeControlMotion("SegmentedControl 滑块", threshold: 50) { window in
            let box = SelectionBox()
            let off = Self.peakTrace(SegmentedHarness(box: box), box: box, target: "C",
                                     motion: .selection, reduceMotion: false, size: size, sampleFor: window)
            return off.changed ? off.peak : -1
        }
    }

    @Test("UnderlinedTabBar A → C：RM 关时下划线扫过中间标签，RM 开时只在两端淡变")
    func underline() {
        let size = CGSize(width: 360, height: 60)
        let boxOn = SelectionBox()
        let on = Self.peakTrace(UnderlinedHarness(box: boxOn), box: boxOn, target: "C",
                                motion: .selection, reduceMotion: true, size: size)
        #expect(on.changed, "选中态没切过去，判据无效")
        #expect(on.peak == 0, "RM 开时下划线不得途经中间，实测 \(on.peak)")
        _ = Self.observeControlMotion("UnderlinedTabBar 下划线", threshold: 20) { window in
            let box = SelectionBox()
            let off = Self.peakTrace(UnderlinedHarness(box: box), box: box, target: "C",
                                     motion: .selection, reduceMotion: false, size: size, sampleFor: window)
            return off.changed ? off.peak : -1
        }
    }

    static func toastInsertionPeak(reduceMotion: Bool, sampleFor duration: TimeInterval) -> (peak: Int, changed: Bool) {
        let host = ToastHost()
        let window = HostedWindow(
            ToastOverlay(host: host, edge: .top, presentation: .floatingCapsule)
                .frame(maxHeight: .infinity, alignment: .top)
                .environment(\.coreMotionPresentationOverride, reduceMotion ? .resting : .animated),
            size: CGSize(width: 320, height: 160),
            scheme: .light
        )
        defer { window.close() }
        let before = window.pixels()
        host.show("Saved", level: .success)
        var frames: [HostedPixels] = []
        let start = Date()
        while Date().timeIntervalSince(start) < duration {
            RunLoop.main.run(until: Date().addingTimeInterval(0.008))
            frames.append(window.pixels())
        }
        window.settle()
        let after = window.pixels()
        let peak = frames.map { Self.motionTrace(before: before, after: after, frame: $0, axis: .vertical) }.max() ?? -1
        return (peak, before.bytes != after.bytes)
    }

    nonisolated static let isCIRunner: Bool = {
        let environment = ProcessInfo.processInfo.environment
        return environment["CI"] != nil || environment["GITHUB_ACTIONS"] != nil
    }()

    nonisolated static let toastInsertionCISkip = """
    跳过：CI runner 上从未在托管窗口里拍到 Toast 入场转场的中间帧（RM 关对照组峰值 [0, 0, 0]，\
    runs 35755896429 / 35759184720），判据在那里无法下结论；本条在本机跑。\
    Toast 在 RM 开时的转场选择由纯函数真值表 \
    CoreMotionTokenDegradationTableTests.toastTransitionKind 在每条腿上兜住。
    """

    @Test(
        "Toast 顶部入场：RM 关时从屏幕上沿滑入，RM 开时原地淡入",
        .enabled(if: !isCIRunner, Comment(rawValue: Self.toastInsertionCISkip))
    )
    func toastInsertion() {
        let on = Self.toastInsertionPeak(reduceMotion: true, sampleFor: 0.4)
        #expect(on.changed, "Toast 没出现，判据无效")
        #expect(on.peak == 0, "RM 开时 Toast 不得位移，实测 \(on.peak)")
        _ = Self.observeControlMotion("Toast 入场", threshold: 50) { window in
            let off = Self.toastInsertionPeak(reduceMotion: false, sampleFor: window + 0.1)
            return off.changed ? off.peak : -1
        }
    }

    static func outsideEndpoints(before: HostedPixels, after: HostedPixels, frame: HostedPixels, rows: Range<Int>) -> Int {
        guard let b = before.bytes, let a = after.bytes, let f = frame.bytes,
              b.count == a.count, b.count == f.count else { return -1 }
        var count = 0
        for row in rows where row < before.height {
            for col in 0..<before.width {
                let i = (row * before.width + col) * 4
                let outside = (0..<3).contains { c in
                    let lo = Int(min(b[i + c], a[i + c])) - 40, hi = Int(max(b[i + c], a[i + c])) + 40
                    return Int(f[i + c]) < lo || Int(f[i + c]) > hi
                }
                if outside { count += 1 }
            }
        }
        return count
    }

    static func chevronPeak(reduceMotion: Bool, sampleFor duration: TimeInterval) -> Int {
        let box = ExpansionBox()
        let window = HostedWindow(
            DisclosureHarness(box: box).environment(\.coreMotionPresentationOverride, reduceMotion ? .resting : .animated),
            size: CGSize(width: 240, height: 80),
            scheme: .light
        )
        defer { window.close() }
        let before = window.pixels()
        withAnimation(CoreMotionToken.reveal.animation(for: reduceMotion ? .resting : .animated)) {
            box.isExpanded = true
        }
        var frames: [HostedPixels] = []
        let start = Date()
        while Date().timeIntervalSince(start) < duration {
            RunLoop.main.run(until: Date().addingTimeInterval(0.008))
            frames.append(window.pixels())
        }
        window.settle()
        let after = window.pixels()
        expectBitmapsDiffer(before.bytes, after.bytes, "chevron 没转过去，判据无效")
        let headerRows = 0..<Int(40 * before.scale)
        return frames.map { Self.outsideEndpoints(before: before, after: after, frame: $0, rows: headerRows) }.max() ?? -1
    }

    @Test("折叠组 chevron：RM 关时旋转途经中间角度，RM 开时直接到位")
    func disclosureChevron() {
        let on = Self.chevronPeak(reduceMotion: true, sampleFor: 0.35)
        #expect(on == 0, "RM 开时 chevron 不得途经中间角度，实测 \(on)")
        _ = Self.observeControlMotion("折叠组 chevron", threshold: 10) { window in
            Self.chevronPeak(reduceMotion: false, sampleFor: window + 0.05)
        }
    }

    static func contentRows(_ frame: HostedPixels, empty: HostedPixels) -> ClosedRange<Int>? {
        guard let f = frame.bytes, let e = empty.bytes, f.count == e.count else { return nil }
        var top: Int?, bottom: Int?
        for row in 0..<frame.height {
            var hits = 0
            for col in 0..<frame.width {
                let i = (row * frame.width + col) * 4
                if (0..<3).contains(where: { abs(Int(f[i + $0]) - Int(e[i + $0])) > 40 }) { hits += 1 }
            }
            if hits > 2 {
                top = top ?? row
                bottom = row
            }
        }
        guard let top, let bottom else { return nil }
        return top...bottom
    }

    // 按与空白帧的差值加权的行质心：纯淡出只按比例缩放差值，质心不动；行阈值法的上沿会随 α 下移。
    static func contentCentroid(_ frame: HostedPixels, empty: HostedPixels) -> (row: Double, weight: Int)? {
        guard let f = frame.bytes, let e = empty.bytes, f.count == e.count else { return nil }
        var weight = 0, moment = 0
        for row in 0..<frame.height {
            var rowWeight = 0
            for col in 0..<frame.width {
                let i = (row * frame.width + col) * 4
                rowWeight += (0..<3).map { abs(Int(f[i + $0]) - Int(e[i + $0])) }.reduce(0, +)
            }
            weight += rowWeight
            moment += rowWeight * row
        }
        return weight > 0 ? (Double(moment) / Double(weight), weight) : nil
    }

    static func swipeReleaseTravel(reduceMotion: Bool, sampleFor duration: TimeInterval) throws -> Double {
        let host = ToastHost()
        let window = HostedWindow(
            ToastOverlay(host: host, edge: .top, presentation: .floatingCapsule)
                .frame(maxHeight: .infinity, alignment: .top)
                .padding(.top, 100)
                .environment(\.coreMotionPresentationOverride, reduceMotion ? .resting : .animated),
            size: CGSize(width: 320, height: 240),
            scheme: .light
        )
        defer { window.close() }
        let empty = window.pixels()
        host.show("Saved", level: .success)
        window.settle()
        RunLoop.main.run(until: Date().addingTimeInterval(0.4))
        let shown = window.pixels()
        let restRows = Self.contentRows(shown, empty: empty)
        let rest = try #require(restRows, "Toast 没画出来")
        let grab = CGPoint(x: 160, y: CGFloat(rest.lowerBound + rest.upperBound) / 2 / shown.scale)
        window.sendMouse(.leftMouseDown, at: grab)
        for step in 1...8 {
            window.sendMouse(.leftMouseDragged, at: CGPoint(x: grab.x, y: grab.y - CGFloat(step) * 5))
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        }
        window.settle()
        let released = window.pixels()
        let releasedRows = Self.contentRows(released, empty: empty)
        let atRelease = try #require(releasedRows, "拖动后 Toast 不见了")
        #expect(atRelease.lowerBound < rest.lowerBound, "合成拖动没有带动 Toast（\(atRelease) vs \(rest)），判据无效")
        let releaseCentroid = try #require(Self.contentCentroid(released, empty: empty), "拖动后 Toast 不见了")
        window.sendMouse(.leftMouseUp, at: CGPoint(x: grab.x, y: grab.y - 40))
        var centroids: [Double] = []
        let start = Date()
        while Date().timeIntervalSince(start) < duration {
            RunLoop.main.run(until: Date().addingTimeInterval(0.008))
            if let centroid = Self.contentCentroid(window.pixels(), empty: empty),
               centroid.weight * 20 >= releaseCentroid.weight {
                centroids.append(centroid.row)
            }
        }
        return centroids.map { abs($0 - releaseCentroid.row) }.max() ?? -1
    }

    @Test("Toast 滑过阈值后松手：RM 关时继续上滑退场，RM 开时停在松手位置原地淡出")
    func toastSwipeRelease() throws {
        let on = try Self.swipeReleaseTravel(reduceMotion: true, sampleFor: 0.3)
        #expect(on >= 0, "松手后一帧都没采到 Toast")
        // 上界 1 行：淡出全程质心实测漂 ≤ 0.16 行；松手后弹回原位（撤掉修复）实测 ≈ 15 行。
        #expect(on <= 1, "RM 开时松手后不得位移（停在松手位置淡出），实测最大质心位移 \(String(format: "%.2f", on)) 行，上界 1")
        _ = Self.observeControlMotion("Toast 滑动松手", threshold: 5) { window in
            Int(((try? Self.swipeReleaseTravel(reduceMotion: false, sampleFor: window)) ?? -1).rounded())
        }
    }

    static func contrast(_ frame: HostedPixels, against empty: HostedPixels) -> Double {
        guard let f = frame.bytes, let e = empty.bytes, f.count == e.count else { return -1 }
        var total = 0
        for i in stride(from: 0, to: f.count, by: 4) {
            total += (0..<3).map { abs(Int(f[i + $0]) - Int(e[i + $0])) }.reduce(0, +)
        }
        return Double(total)
    }

    // 本 harness 观测不到样式链尾的外层 `.opacity`（实测加回 0.9 后比值不变），叠乘回归由真值表 `pressedOpacityIsNotStacked` 兜。
    @Test("真实按下（合成鼠标）：.lightButton 在 RM 下走到 PressFeedback 的变暗分支，不缩放、对比度按 0.7")
    func realPressOpacity() {
        let cases: [(String, AnyView, Double)] = [
            ("light", AnyView(Button {} label: { Color.clear.frame(width: 120, height: 36) }.buttonStyle(.light())), 0.7),
        ]
        for (name, button, expected) in cases {
            let window = HostedWindow(
                button.environment(\.coreMotionPresentationOverride, .resting),
                size: CGSize(width: 200, height: 80),
                scheme: .light
            )
            defer { window.close() }
            let emptyWindow = HostedWindow(Color.clear, size: CGSize(width: 200, height: 80), scheme: .light)
            let empty = emptyWindow.pixels()
            emptyWindow.close()
            let idle = Self.contrast(window.pixels(), against: empty)
            window.sendMouse(.leftMouseDown, at: CGPoint(x: 100, y: 40))
            window.settle()
            RunLoop.main.run(until: Date().addingTimeInterval(0.4))
            let pressed = Self.contrast(window.pixels(), against: empty)
            window.sendMouse(.leftMouseUp, at: CGPoint(x: 100, y: 40))
            #expect(idle > 0, "\(name)：按钮没画出来")
            let ratio = pressed / idle
            // 容差 0.05：CI 并行负载下实测偏差到 0.032；把 0.7 改成 0.5 的变异差 0.2，仍在界外。
            #expect(abs(ratio - expected) < 0.05, "\(name)：RM 下按下后对比度比为 \(ratio)，应为 \(expected)")
        }
    }
}
#endif
