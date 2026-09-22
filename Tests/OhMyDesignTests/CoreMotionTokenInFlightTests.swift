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

    fileprivate static func peakTrace(
        _ content: some View,
        box: SelectionBox,
        target: String,
        motion: CoreMotionToken,
        reduceMotion: Bool,
        size: CGSize
    ) -> (peak: Int, changed: Bool) {
        let window = HostedWindow(content.environment(\._accessibilityReduceMotion, reduceMotion), size: size, scheme: .light)
        defer { window.close() }
        let before = window.pixels()
        var frames: [HostedPixels] = []
        withAnimation(motion.animation(for: reduceMotion ? .resting : .animated)) {
            box.value = target
        }
        let start = Date()
        while Date().timeIntervalSince(start) < 0.3 {
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
        let boxOff = SelectionBox()
        let off = Self.peakTrace(SegmentedHarness(box: boxOff), box: boxOff, target: "C",
                                 motion: .selection, reduceMotion: false, size: size)
        #expect(off.changed && on.changed, "选中态没切过去，判据无效")
        #expect(off.peak > 50, "RM 关时应能看到滑块途经中间，实测 \(off.peak)")
        #expect(on.peak == 0, "RM 开时滑块不得途经中间，实测 \(on.peak)")
    }

    @Test("UnderlinedTabBar A → C：RM 关时下划线扫过中间标签，RM 开时只在两端淡变")
    func underline() {
        let size = CGSize(width: 360, height: 60)
        let boxOn = SelectionBox()
        let on = Self.peakTrace(UnderlinedHarness(box: boxOn), box: boxOn, target: "C",
                                motion: .selection, reduceMotion: true, size: size)
        let boxOff = SelectionBox()
        let off = Self.peakTrace(UnderlinedHarness(box: boxOff), box: boxOff, target: "C",
                                 motion: .selection, reduceMotion: false, size: size)
        #expect(off.changed && on.changed, "选中态没切过去，判据无效")
        #expect(off.peak > 20, "RM 关时应能看到下划线途经中间，实测 \(off.peak)")
        #expect(on.peak == 0, "RM 开时下划线不得途经中间，实测 \(on.peak)")
    }

    @Test("Toast 顶部入场：RM 关时从屏幕上沿滑入，RM 开时原地淡入")
    func toastInsertion() {
        var results: [Bool: (peak: Int, changed: Bool)] = [:]
        for reduceMotion in [false, true] {
            let host = ToastHost()
            let window = HostedWindow(
                ToastOverlay(host: host, edge: .top, presentation: .floatingCapsule)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .environment(\._accessibilityReduceMotion, reduceMotion),
                size: CGSize(width: 320, height: 160),
                scheme: .light
            )
            let before = window.pixels()
            host.show("Saved", level: .success)
            var frames: [HostedPixels] = []
            let start = Date()
            while Date().timeIntervalSince(start) < 0.4 {
                RunLoop.main.run(until: Date().addingTimeInterval(0.008))
                frames.append(window.pixels())
            }
            window.settle()
            let after = window.pixels()
            window.close()
            let peak = frames.map { Self.motionTrace(before: before, after: after, frame: $0, axis: .vertical) }.max() ?? -1
            results[reduceMotion] = (peak, before.bytes != after.bytes)
        }
        let off = results[false]!, on = results[true]!
        #expect(off.changed && on.changed, "Toast 没出现，判据无效")
        #expect(off.peak > 50, "RM 关时应能看到 Toast 途经上方留白，实测 \(off.peak)")
        #expect(on.peak == 0, "RM 开时 Toast 不得位移，实测 \(on.peak)")
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

    @Test("折叠组 chevron：RM 关时旋转途经中间角度，RM 开时直接到位")
    func disclosureChevron() {
        var peaks: [Bool: Int] = [:]
        for reduceMotion in [false, true] {
            let box = ExpansionBox()
            let window = HostedWindow(
                DisclosureHarness(box: box).environment(\._accessibilityReduceMotion, reduceMotion),
                size: CGSize(width: 240, height: 80),
                scheme: .light
            )
            let before = window.pixels()
            withAnimation(CoreMotionToken.reveal.animation(for: reduceMotion ? .resting : .animated)) {
                box.isExpanded = true
            }
            var frames: [HostedPixels] = []
            let start = Date()
            while Date().timeIntervalSince(start) < 0.35 {
                RunLoop.main.run(until: Date().addingTimeInterval(0.008))
                frames.append(window.pixels())
            }
            window.settle()
            let after = window.pixels()
            window.close()
            expectBitmapsDiffer(before.bytes, after.bytes, "chevron 没转过去，判据无效")
            let headerRows = 0..<Int(40 * before.scale)
            peaks[reduceMotion] = frames.map {
                Self.outsideEndpoints(before: before, after: after, frame: $0, rows: headerRows)
            }.max() ?? -1
        }
        #expect((peaks[false] ?? 0) > 10, "RM 关时 chevron 应有中间角度，实测 \(peaks[false] ?? -1)")
        #expect(peaks[true] == 0, "RM 开时 chevron 不得途经中间角度，实测 \(peaks[true] ?? -1)")
    }
}
#endif
