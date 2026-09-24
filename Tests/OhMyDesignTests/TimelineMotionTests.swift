import SwiftUI
import Testing
@testable import OhMyDesign

// MARK: - 推进位置与入场裁决（纯函数）/ Motion pure logic

@Suite("Timeline 动效纯函数：推进位置、分段系数、圆点插值、入场裁决")
struct TimelineMotionPureTests {
    @Test("推进位置：.notStarted = 最小 step − 1、.inProgress(at: k) = k、.completed = 最大 step + 1；无 progress 或无 step ⇒ nil")
    func positionEndpoints() {
        let steps: [Int?] = [nil, 2, 5, nil, 9]
        #expect(TimelineMotion(progress: .notStarted, steps: steps)?.position == 1)
        #expect(TimelineMotion(progress: .inProgress(at: 5), steps: steps)?.position == 5)
        #expect(TimelineMotion(progress: .completed, steps: steps)?.position == 10)
        #expect(TimelineMotion(progress: nil, steps: steps) == nil)
        #expect(TimelineMotion(progress: .completed, steps: [nil, nil]) == nil)
    }

    @Test("推进位置在 Int.min / Int.max 下不 trap；端点的 ±1 在 Double 里被吸收，与极值 step 位置相同（切换不补间，静止帧仍按整数判定）")
    func positionExtremes() {
        let steps: [Int?] = [Int.min, Int.max]
        #expect(TimelineMotion(progress: .notStarted, steps: steps)?.position == Double(Int.min))
        #expect(TimelineMotion(progress: .completed, steps: steps)?.position == Double(Int.max))
    }

    @Test("推进位置夹在 [最小 step − 1, 最大 step + 1]：越界的 inProgress 与 notStarted / completed 位置相同，补间不会只在开头 5% 里可见")
    func positionClamped() {
        let steps: [Int?] = [0, 1, 2, 3, 4]
        #expect(TimelineMotion(progress: .inProgress(at: 100), steps: steps)?.position == 5)
        #expect(TimelineMotion(progress: .inProgress(at: -100), steps: steps)?.position == -1)
        #expect(TimelineMotion(progress: .inProgress(at: 2), steps: steps)?.position == 2)
    }

    @Test("静止（插值值 == 模型值）时分段系数与圆点取整数判定：极值相邻 step 不会被 Double 精度判成同一点")
    func restingIsExact() {
        let pieces = TimelineStackLayout.connectorMotionPieces(
            slots: [.row(node: 0, content: 1), .row(node: 2, content: 3)],
            steps: [Int.max - 1, Int.max], progress: .inProgress(at: Int.max - 1), layout: .vertical
        )
        #expect(pieces.count == 1)
        let position = Double(Int.max - 1)
        #expect(Double(Int.max - 1) == Double(Int.max), "夹具前提：两个极值 step 在 Double 里相等")
        #expect(pieces[0].fraction(position: position, target: position) == 0)
        #expect(TimelineStackLayout.dotMorph(step: Int.max, position: position, target: position) == nil)
    }

    @Test("在飞：段系数 = clamp(P − 后一行 step + 1)；.alternate 被截断的段按截数依次填满")
    func inFlightFractions() {
        let piece = TimelineStackLayout.ConnectorPiece(resting: 0, nextStep: 3, index: 0, count: 1)
        #expect(piece.fraction(position: 2.25, target: 3) == 0.25)
        #expect(piece.fraction(position: 1.5, target: 3) == 0)
        #expect(piece.fraction(position: 3, target: 0) == 1)
        let split = (0..<2).map { TimelineStackLayout.ConnectorPiece(resting: 0, nextStep: 1, index: $0, count: 2) }
        #expect(split.map { $0.fraction(position: 0.25, target: 1) } == [0.5, 0])
        #expect(split.map { $0.fraction(position: 0.75, target: 1) } == [1, 0.5])
        let orphan = TimelineStackLayout.ConnectorPiece(resting: 0, nextStep: nil, index: 0, count: 1)
        #expect(orphan.fraction(position: 2.5, target: 3) == 0, "后一行无 step ⇒ 不随 P 插值")
    }

    @Test("在飞：圆点到达比例 r = clamp(P − s + 1)、完成比例 c = clamp(P − s)")
    func inFlightDot() {
        let morph = TimelineStackLayout.dotMorph(step: 2, position: 1.25, target: 3)
        #expect(morph == TimelineStackLayout.DotMorph(arrival: 0.25, completion: 0))
        #expect(TimelineStackLayout.dotMorph(step: 2, position: 2.5, target: 3)
            == TimelineStackLayout.DotMorph(arrival: 1, completion: 0.5))
        #expect(TimelineStackLayout.dotMorph(step: nil, position: 2.5, target: 3) == nil)
        #expect(TimelineStackLayout.dotMorph(step: 2, position: 2.5, target: nil) == nil)
    }

    @Test("入场只在挂载窗口已关、且呈现为 .animated 时播放")
    func entranceDecision() {
        for presentation in [MotionPresentation.animated, .resting, .hidden] {
            #expect(!TimelineEntranceFrame.plays(mountWindowOpen: true, presentation: presentation))
            #expect(TimelineEntranceFrame.plays(mountWindowOpen: false, presentation: presentation) == (presentation == .animated))
        }
        #expect(TimelineEntranceFrame.resting == TimelineEntranceFrame(scale: 1, opacity: 1))
    }

    @Test("入场闩锁：不可见回调不改任何状态；首个可见回调结算——挂载窗口内或非 .animated 直接终态，否则置待入场并要求补间；结算后不再变")
    func entranceLatch() {
        let fresh = TimelineEntrance()
        #expect(fresh.frame == .resting)

        let hidden = fresh.visibilityChanged(false, mountWindowOpen: false, presentation: .animated)
        #expect(hidden.entrance == fresh && !hidden.plays, "不可见回调不得改状态（宿主误报 false 时节点不能消失）")

        let mountedVisible = fresh.visibilityChanged(true, mountWindowOpen: true, presentation: .animated)
        #expect(mountedVisible.entrance == TimelineEntrance(isWaiting: false, isSettled: true) && !mountedVisible.plays)

        let scrolledIn = fresh.visibilityChanged(true, mountWindowOpen: false, presentation: .animated)
        #expect(scrolledIn.plays && scrolledIn.entrance == TimelineEntrance(isWaiting: true, isSettled: true))
        #expect(scrolledIn.entrance.frame == .entering, "补间前的首帧已是待入场态（无闪帧）")

        var settled = scrolledIn.entrance
        settled.isWaiting = false
        for visible in [false, true] {
            let again = settled.visibilityChanged(visible, mountWindowOpen: false, presentation: .animated)
            #expect(again.entrance == settled && !again.plays, "结算后不再变")
        }

        for presentation in [MotionPresentation.resting, .hidden] {
            let reduced = fresh.visibilityChanged(true, mountWindowOpen: false, presentation: presentation)
            #expect(!reduced.plays && reduced.entrance.frame == .resting)
        }
    }
}

// MARK: - 静止帧 / Resting frame

@Suite("Timeline 静止帧：ImageRenderer 在任何呈现下都画终态")
@MainActor
struct TimelineRestingFrameTests {
    private static let scale: CGFloat = 2

    private static func widths(_ presentation: MotionPresentation) -> (dot: Int, square: Int)? {
        let view = Timeline {
            TimelineItem(status: .neutral) { Color.clear.frame(width: 40, height: 40) }
            TimelineItem {
                Color.black.frame(width: 20, height: 20)
            } content: {
                Color.clear.frame(width: 40, height: 40)
            }
        }
        .frame(width: 120)
        .background(Color.white)
        .environment(\.coreMotionPresentationOverride, presentation)
        .environment(\.colorScheme, .light)
        let renderer = ImageRenderer(content: view)
        renderer.scale = Self.scale
        guard let image = renderer.cgImage else { return nil }
        let pixels = HostedPixels(image, scale: Self.scale)
        guard let bytes = pixels.bytes else { return nil }
        func width(atY y: CGFloat, isInk: (Int) -> Bool) -> Int {
            let row = Int(y * Self.scale)
            return (0..<Int(24 * Self.scale)).filter { isInk((row * pixels.width + $0) * 4) }.count
        }
        let dot = width(atY: 12) { i in (0..<3).contains { abs(Int(bytes[i + $0]) - 255) > 24 } }
        let square = width(atY: 56 + 12) { i in (0..<3).allSatisfy { bytes[i + $0] < 40 } }
        return (dot, square)
    }

    @Test("默认圆点（.neutral）非背景像素宽 10pt、20pt 黑色自定义节点宽 20pt（±1pt），.resting 与 .animated 相同", arguments: [
        MotionPresentation.resting, .animated,
    ])
    func restingWidths(_ presentation: MotionPresentation) throws {
        let measured = try #require(Self.widths(presentation), "渲染失败")
        #expect(abs(measured.dot - Int(Timeline.nodeDiameter * Self.scale)) <= Int(Self.scale), "圆点宽 \(measured.dot)px")
        #expect(abs(measured.square - Int(20 * Self.scale)) <= Int(Self.scale), "自定义节点宽 \(measured.square)px")
    }
}

// MARK: - 动画进行中的帧 / In-flight frames

// iOS 上 `layer.render(in:)` 拍不到进行中的帧 ⇒ 只在 macOS 腿观测（同 `CoreMotionTokenInFlightTests`）。
#if os(macOS)

@MainActor
private final class TimelineMotionBox: ObservableObject {
    @Published var progress: TimelineProgress
    @Published var scrollTarget: Int?
    @Published var isShown: Bool

    init(progress: TimelineProgress = .inProgress(at: 0), isShown: Bool = true) {
        self.progress = progress
        self.isShown = isShown
    }
}

private struct AdvanceHarness: View {
    @ObservedObject var box: TimelineMotionBox

    var body: some View {
        Timeline(progress: self.box.progress) {
            ForEach(0..<5, id: \.self) { step in
                TimelineItem(step: step, status: .neutral) { Color.clear.frame(height: 40) }
            }
        }
        .tint(.black)
        .frame(width: 120, alignment: .topLeading)
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

private struct HorizontalHarness: View {
    @ObservedObject var box: TimelineMotionBox

    var body: some View {
        Timeline(layout: .horizontal, progress: self.box.progress) {
            TimelineItem(step: 0) {
                Color.red.frame(width: 20, height: 20)
            } content: {
                Color.clear.frame(width: 80, height: 10)
            }
            TimelineItem(step: 1) {
                Color.blue.frame(width: 20, height: 20)
            } content: {
                Color.clear.frame(width: 80, height: 10)
            }
        }
        .tint(.black)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct EntranceHarness: View {
    @ObservedObject var box: TimelineMotionBox
    let scrolls: Bool
    let markedRow: Int

    var body: some View {
        if self.box.isShown {
            if self.scrolls {
                ScrollViewReader { proxy in
                    ScrollView {
                        self.timeline
                    }
                    .onChange(of: self.box.scrollTarget) { _, target in
                        if let target { proxy.scrollTo(target, anchor: .center) }
                    }
                }
            } else {
                self.timeline.frame(maxHeight: .infinity, alignment: .top)
            }
        }
    }

    private var timeline: some View {
        Timeline {
            ForEach(0..<(self.scrolls ? 12 : 2), id: \.self) { row in
                TimelineItem {
                    Rectangle().fill(row == self.markedRow ? Color.red : Color.black).frame(width: 20, height: 20)
                } content: {
                    Color(red: 0, green: 0, blue: 1, opacity: row == self.markedRow ? 1 : 0)
                        .frame(width: 40, height: 60)
                        .id(row)
                }
            }
        }
        .frame(width: 120, alignment: .leading)
    }
}

@Suite("Timeline 动效在飞帧：推进、回退、Reduce Motion、入场", .serialized)
@MainActor
struct TimelineMotionInFlightTests {
    private static let segment: CGFloat = 32

    private static func sample(
        _ window: HostedWindow, for duration: TimeInterval = 0.4, _ measure: (HostedPixels) -> Int
    ) -> [Int] {
        var values: [Int] = []
        let start = Date()
        while Date().timeIntervalSince(start) < duration {
            RunLoop.main.run(until: Date().addingTimeInterval(0.008))
            values.append(measure(window.pixels()))
        }
        return values
    }

    private static func isBlack(_ bytes: [UInt8], _ index: Int) -> Bool {
        (0..<3).allSatisfy { bytes[index + $0] < 60 }
    }

    private static func axisLength(_ pixels: HostedPixels) -> Int {
        guard let bytes = pixels.bytes else { return -1 }
        let x = Int(12 * pixels.scale)
        return (0..<pixels.height).filter { Self.isBlack(bytes, ($0 * pixels.width + x) * 4) }.count
    }

    private static func isBoundary(_ length: Int, scale: CGFloat) -> Bool {
        let unit = Self.segment * scale
        let nearest = (CGFloat(length) / unit).rounded() * unit
        return abs(CGFloat(length) - nearest) <= scale
    }

    private static func advance(
        from: TimelineProgress, to: TimelineProgress, presentation: MotionPresentation, window duration: TimeInterval = 0.4
    ) -> (values: [Int], before: Int, after: Int, scale: CGFloat) {
        let box = TimelineMotionBox(progress: from)
        let window = HostedWindow(
            AdvanceHarness(box: box).environment(\.coreMotionPresentationOverride, presentation),
            size: CGSize(width: 120, height: 300), scheme: .light
        )
        defer { window.close() }
        let first = window.pixels()
        box.progress = to
        let values = Self.sample(window, for: duration, Self.axisLength)
        window.settle()
        return (values, Self.axisLength(first), Self.axisLength(window.pixels()), first.scale)
    }

    @Test("推进会生长（RM 关）：(at: 0) → (at: 3)，中轴黑色长度出现 ≥ 2 个不在段边界上的中间值")
    func advanceGrows() {
        _ = CoreMotionTokenInFlightTests.observeControlMotion("Timeline 推进", threshold: 1) { duration in
            let run = Self.advance(from: .inProgress(at: 0), to: .inProgress(at: 3), presentation: .animated, window: duration)
            guard run.before == 0, Self.isBoundary(run.after, scale: run.scale), run.after > 0 else { return -1 }
            return Set(run.values.filter { !Self.isBoundary($0, scale: run.scale) }).count
        }
    }

    @Test("推进不生长（RM 开）：只出现段边界值，着色层整段淡入")
    func advanceFadesUnderReduceMotion() {
        let run = Self.advance(from: .inProgress(at: 0), to: .inProgress(at: 3), presentation: .resting)
        #expect(run.before == 0 && run.after == Int(3 * Self.segment * run.scale), "端点不对：\(run.before) → \(run.after)")
        let offenders = run.values.filter { !Self.isBoundary($0, scale: run.scale) }
        #expect(offenders.isEmpty, "RM 开时出现了非段边界长度 \(offenders)（全部 \(run.values)）")
    }

    @Test("回退从远端收：(at: 3) → (at: 1)，中轴黑色长度单调不增")
    func retreatShrinksFromFarEnd() {
        _ = CoreMotionTokenInFlightTests.observeControlMotion("Timeline 回退", threshold: 1) { duration in
            let run = Self.advance(from: .inProgress(at: 3), to: .inProgress(at: 1), presentation: .animated, window: duration)
            let rises = zip(run.values, run.values.dropFirst()).filter { $1 > $0 + Int(run.scale) }
            #expect(rises.isEmpty, "回退途中长度回升：\(run.values)")
            #expect(run.after == Int(Self.segment * run.scale), "终态应剩 1 段，实测 \(run.after)")
            return Set(run.values.filter { !Self.isBoundary($0, scale: run.scale) }).count
        }
    }

    @Test("圆点与连线同步：第 3 行圆点开始填充的帧不早于通向它的第 2 段开始生长的帧")
    func dotFollowsConnector() {
        var trace: [(length: Int, center: Int)] = []
        _ = CoreMotionTokenInFlightTests.observeControlMotion("Timeline 圆点同步", threshold: 1) { duration in
            let box = TimelineMotionBox(progress: .inProgress(at: 0))
            let window = HostedWindow(
                AdvanceHarness(box: box).environment(\.coreMotionPresentationOverride, .animated),
                size: CGSize(width: 120, height: 300), scheme: .light
            )
            defer { window.close() }
            let scale = window.pixels().scale
            let centerIndex = { (pixels: HostedPixels) -> Int in
                (Int((3 * 56 + 12) * scale) * pixels.width + Int(12 * scale)) * 4
            }
            let initial = window.pixels()
            guard let initialBytes = initial.bytes else { return -1 }
            let base = Int(initialBytes[centerIndex(initial)])
            box.progress = .inProgress(at: 3)
            trace = []
            let start = Date()
            while Date().timeIntervalSince(start) < duration {
                RunLoop.main.run(until: Date().addingTimeInterval(0.008))
                let pixels = window.pixels()
                guard let bytes = pixels.bytes else { continue }
                trace.append((Self.axisLength(pixels), abs(Int(bytes[centerIndex(pixels)]) - base)))
            }
            let into = Int(2 * Self.segment * scale)
            guard let segmentStart = trace.firstIndex(where: { $0.length > into + Int(scale) }),
                  let dotStart = trace.firstIndex(where: { $0.center > 24 }) else { return -1 }
            #expect(dotStart >= segmentStart - 1, "圆点在第 \(dotStart) 帧开始填充、早于第 2 段开始生长的第 \(segmentStart) 帧：\(trace)")
            return Set(trace.map(\.length).filter { !Self.isBoundary($0, scale: scale) }).count
        }
    }

    @Test("横向部分着色从前一行一侧长出，RTL 下同样如此", arguments: [LayoutDirection.leftToRight, .rightToLeft])
    func horizontalGrowsFromPreviousRow(_ direction: LayoutDirection) {
        _ = CoreMotionTokenInFlightTests.observeControlMotion("Timeline 横向 \(direction)", threshold: 0) { duration in
            let box = TimelineMotionBox(progress: .inProgress(at: 0))
            let window = HostedWindow(
                HorizontalHarness(box: box)
                    .environment(\.layoutDirection, direction)
                    .environment(\.coreMotionPresentationOverride, .animated),
                size: CGSize(width: 260, height: 60), scheme: .light
            )
            defer { window.close() }
            let initial = window.pixels()
            guard let bytes = initial.bytes else { return -1 }
            let redRows = (0..<initial.height).filter { row in
                (0..<initial.width).contains { let i = (row * initial.width + $0) * 4; return bytes[i] > 200 && bytes[i + 2] < 100 }
            }
            guard let top = redRows.first, let bottom = redRows.last else { return -1 }
            let y = (top + bottom) / 2
            func centroid(_ match: (Int) -> Bool) -> Double? {
                let xs = (0..<initial.width).filter { match((y * initial.width + $0) * 4) }
                return xs.isEmpty ? nil : Double(xs.reduce(0, +)) / Double(xs.count)
            }
            guard let red = centroid({ bytes[$0] > 200 && bytes[$0 + 2] < 100 }),
                  let blue = centroid({ bytes[$0 + 2] > 200 && bytes[$0] < 100 }) else { return -1 }
            box.progress = .inProgress(at: 1)
            var partial = 0
            let start = Date()
            while Date().timeIntervalSince(start) < duration {
                RunLoop.main.run(until: Date().addingTimeInterval(0.008))
                let pixels = window.pixels()
                guard let frame = pixels.bytes else { continue }
                let xs = (0..<pixels.width).filter { x in
                    (y...(y + 1)).contains { row in
                        (0..<3).allSatisfy { frame[(row * pixels.width + x) * 4 + $0] < 170 }
                    }
                }
                guard let low = xs.min(), let high = xs.max() else { continue }
                let span = abs(blue - red) - 24 * pixels.scale
                guard Double(high - low) < span - 2 * pixels.scale else { continue }
                partial += 1
                let mid = Double(low + high) / 2
                #expect(abs(mid - red) < abs(mid - blue), "\(direction)：部分着色 [\(low), \(high)] 贴着后一行（red \(red) blue \(blue)）")
            }
            return partial
        }
    }

    private static func markedNodeWidth(_ pixels: HostedPixels) -> Int {
        guard let bytes = pixels.bytes else { return -1 }
        return (0..<pixels.height).map { y in
            (0..<pixels.width).filter { x in
                let i = (y * pixels.width + x) * 4
                return Int(bytes[i]) - Int(bytes[i + 1]) > 20 && Int(bytes[i]) - Int(bytes[i + 2]) > 20
            }.count
        }.max() ?? 0
    }

    private static func isEntering(_ width: Int, scale: CGFloat) -> Bool {
        CGFloat(width) >= (20 * TimelineEntranceFrame.enteringScale - 1) * scale && CGFloat(width) < 19 * scale
    }

    private static func isResting(_ width: Int, scale: CGFloat) -> Bool {
        abs(CGFloat(width) - 20 * scale) <= scale
    }

    private static func showsMarkedContent(_ pixels: HostedPixels) -> Bool {
        guard let bytes = pixels.bytes else { return false }
        return stride(from: 0, to: bytes.count, by: 4).contains { bytes[$0 + 2] > 200 && bytes[$0] < 60 && bytes[$0 + 1] < 60 }
    }

    private static func scrollIn(
        _ box: TimelineMotionBox, _ window: HostedWindow, duration: TimeInterval
    ) -> [(scrolled: Bool, width: Int)] {
        box.scrollTarget = 8
        var frames: [(Bool, Int)] = []
        let start = Date()
        while Date().timeIntervalSince(start) < duration {
            RunLoop.main.run(until: Date().addingTimeInterval(0.008))
            let pixels = window.pixels()
            frames.append((Self.showsMarkedContent(pixels), Self.markedNodeWidth(pixels)))
        }
        return frames
    }

    private static func entranceWindow(
        _ box: TimelineMotionBox, scrolls: Bool, presentation: MotionPresentation, markedRow: Int = 8
    ) -> HostedWindow {
        HostedWindow(
            EntranceHarness(box: box, scrolls: scrolls, markedRow: markedRow).environment(\.coreMotionPresentationOverride, presentation),
            size: CGSize(width: 120, height: 200), scheme: .light
        )
    }

    @Test("入场按视口触发：挂载后滚入的第 8 行节点有 ≥ 2 帧宽度介于 0.86× 与 1× 之间，且滚入后第一帧不是终态（无闪帧）")
    func entrancePlaysOnScrollIn() {
        _ = CoreMotionTokenInFlightTests.observeControlMotion("Timeline 入场", threshold: 1) { duration in
            let box = TimelineMotionBox()
            let window = Self.entranceWindow(box, scrolls: true, presentation: .animated)
            defer { window.close() }
            let scale = window.pixels().scale
            let frames = Self.scrollIn(box, window, duration: duration).filter(\.scrolled)
            guard let first = frames.first else { return -1 }
            #expect(first.width < Int(20 * scale) - Int(scale), "滚入后第一帧节点宽 \(first.width)px，已是终态（闪帧）")
            return frames.map(\.width).filter { Self.isEntering($0, scale: scale) }.count
        }
    }

    @Test("不重播：滚出再滚回，第 8 行节点不再出现中间宽度")
    func entranceDoesNotReplay() {
        let box = TimelineMotionBox()
        let window = Self.entranceWindow(box, scrolls: true, presentation: .animated)
        defer { window.close() }
        let scale = window.pixels().scale
        let first = Self.scrollIn(box, window, duration: 0.4).filter(\.scrolled).map(\.width)
        #expect(first.contains { !Self.isResting($0, scale: scale) }, "第一次滚入没播入场，本条无对照：\(first)")
        window.settle()
        box.scrollTarget = 0
        window.settle()
        box.scrollTarget = nil
        window.settle()
        let frames = Self.scrollIn(box, window, duration: 0.4).filter(\.scrolled)
        #expect(!frames.isEmpty, "没滚到第 8 行，判据无效")
        #expect(frames.allSatisfy { Self.isResting($0.width, scale: scale) }, "再次滚入时节点不是终态（重播或透明）：\(frames.map(\.width))")
    }

    @Test("入场 RM 不播：.resting 下滚入第 8 行，节点宽度全程是终态")
    func entranceSkippedUnderReduceMotion() {
        let box = TimelineMotionBox()
        let window = Self.entranceWindow(box, scrolls: true, presentation: .resting)
        defer { window.close() }
        let scale = window.pixels().scale
        let frames = Self.scrollIn(box, window, duration: 0.4).filter(\.scrolled)
        #expect(!frames.isEmpty, "没滚到第 8 行，判据无效")
        #expect(frames.allSatisfy { Self.isResting($0.width, scale: scale) }, "RM 开时节点不是终态：\(frames.map(\.width))")
    }

    @Test("挂载时可见不播：ScrollView 内首屏行、以及无滚动宿主的行，内容一画出来节点就是终态（不缩小、不透明闪帧）", arguments: [true, false])
    func mountDoesNotPlay(scrolls: Bool) {
        let box = TimelineMotionBox(isShown: false)
        let window = Self.entranceWindow(box, scrolls: scrolls, presentation: .animated, markedRow: scrolls ? 0 : 1)
        defer { window.close() }
        let scale = window.pixels().scale
        box.isShown = true
        var frames: [Int] = []
        let start = Date()
        while Date().timeIntervalSince(start) < 0.4 {
            RunLoop.main.run(until: Date().addingTimeInterval(0.008))
            let pixels = window.pixels()
            if Self.showsMarkedContent(pixels) { frames.append(Self.markedNodeWidth(pixels)) }
        }
        #expect(!frames.isEmpty, "挂载后没画出标记行的内容，判据无效")
        #expect(frames.allSatisfy { Self.isResting($0, scale: scale) }, "挂载时可见的行节点不是终态（scrolls: \(scrolls)）：\(frames)")
    }
}

#endif
