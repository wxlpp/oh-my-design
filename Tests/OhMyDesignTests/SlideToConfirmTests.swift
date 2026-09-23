import SwiftUI
import Testing
@testable import OhMyDesign

// MARK: - SlideToConfirm

@Suite("SlideToConfirm：纯距离阈值、夹紧、门闩、无障碍与播报")
@MainActor
struct SlideToConfirmTests {
    static let geometry = SlideToConfirmGeometry(width: 320, knob: 44, spacing: 4)

    private static func sample(_ translation: CGFloat, predicted: CGFloat? = nil) -> SlideToConfirmDragSample {
        SlideToConfirmDragSample(translation: translation, predictedEndTranslation: predicted ?? translation)
    }

    // MARK: 阈值 / Threshold

    @Test("全程 = 容器宽 − 指示器宽 − 2×间距")
    func travelIsWidthMinusKnobMinusSpacing() {
        #expect(Self.geometry.travel == CGFloat(268))
        #expect(SlideToConfirmGeometry(width: 30, knob: 44, spacing: 4).travel == 0, "容器比指示器还窄时全程应为 0")
        #expect(SlideToConfirmGeometry(width: .nan, knob: 44, spacing: 4).travel == 0, "NaN 宽度应按 0 处理")
    }

    @Test("正例：位移恰为全程、超过全程都触发")
    func reachingTheEndConfirms() {
        let travel = Self.geometry.travel
        #expect(Self.geometry.confirms(Self.sample(travel)), "位移恰为全程 \(travel) 没触发")
        #expect(Self.geometry.confirms(Self.sample(travel + 80)), "位移超过全程没触发")
    }

    @Test("负例：快速甩到一半松手不触发——预测终点远超整宽也不算")
    func fastFlickToHalfDoesNotConfirm() {
        let travel = Self.geometry.travel
        for predicted in [Self.geometry.width + 1, Self.geometry.width * 4, .infinity] {
            #expect(
                !Self.geometry.confirms(Self.sample(travel / 2, predicted: predicted)),
                "位移 \(travel / 2)、预测终点 \(predicted) 触发了 —— 阈值被速度补偿降低了"
            )
        }
    }

    @Test("负例：反向拖动不触发")
    func reverseDragDoesNotConfirm() {
        for translation in [-1, -Self.geometry.travel, -Self.geometry.width * 3] as [CGFloat] {
            #expect(!Self.geometry.confirms(Self.sample(translation, predicted: translation * 2)), "反向位移 \(translation) 触发了")
        }
    }

    @Test("负例：拖到阈值前一点松手不触发")
    func justBeforeTheEndDoesNotConfirm() {
        let travel = Self.geometry.travel
        for gap in [0.5, 1, 4] as [CGFloat] {
            #expect(!Self.geometry.confirms(Self.sample(travel - gap)), "阈值前 \(gap) pt 触发了")
        }
    }

    @Test("未量到宽度（全程为 0）时任何位移都不触发")
    func unmeasuredTrackNeverConfirms() {
        let unmeasured = SlideToConfirmGeometry(width: 0, knob: 44, spacing: 4)
        for translation in [0, 1, 500] as [CGFloat] {
            #expect(!unmeasured.confirms(Self.sample(translation)), "全程为 0 时位移 \(translation) 触发了")
        }
    }

    @Test("负例：拖到底后被打断（手势取消）不触发，指示器回起点")
    func interruptionAfterReachingTheEndDoesNotConfirm() {
        var core = SlideToConfirmCore()
        core.drag(Self.geometry.travel + 30)
        #expect(core.knobOffset(in: Self.geometry) == Self.geometry.travel)
        core.interrupt()
        #expect(core.phase == .idle, "被打断后阶段实得 \(core.phase)")
        #expect(core.acceptsInput, "被打断后门闩被关了")
        #expect(core.knobOffset(in: Self.geometry) == 0, "被打断后指示器没回起点")
    }

    // MARK: 夹紧 / Clamping

    @Test("拖动中位移夹在 [0, 全程] 内，任何输入都不过冲")
    func dragOffsetIsClamped() {
        let travel = Self.geometry.travel
        let inputs: [CGFloat] = [-10_000, -1, 0, 1, travel / 2, travel - 0.1, travel, travel + 0.1, 10_000, .infinity, -.infinity, .nan]
        var outside: [CGFloat] = []
        for input in inputs {
            let offset = Self.geometry.clampedOffset(forTranslation: input)
            if !(offset >= 0 && offset <= travel) { outside.append(input) }
        }
        #expect(outside.isEmpty, "这些输入产生了越界位移：\(outside)")
        #expect(Self.geometry.clampedOffset(forTranslation: travel / 2) == travel / 2, "区间内的位移被改写了")
        #expect(Self.geometry.clampedOffset(forTranslation: 10_000) == travel)
        #expect(Self.geometry.clampedOffset(forTranslation: -10_000) == 0)
    }

    @Test("文案随指示器前进淡出：起点不透明、尽头全透明、中间单调递减")
    func titleFadesWithProgress() {
        let travel = Self.geometry.travel
        let samples = stride(from: 0, through: travel, by: travel / 8).map { Self.geometry.titleOpacity(forOffset: $0) }
        #expect(samples.first == 1)
        #expect(samples.last == 0)
        #expect(zip(samples, samples.dropFirst()).allSatisfy { $0 > $1 }, "不是严格递减：\(samples)")
    }

    // MARK: 门闩 / Gate

    @Test("门闩：运行中第二次准入被拒；只有本次运行号能开闸")
    func gateRejectsReentryUntilItsOwnRunFinishes() {
        var gate = SlideToConfirmGate()
        let first = gate.admit()
        #expect(first != nil)
        let second = gate.admit()
        #expect(second == nil, "运行中第二次准入被放行了")
        if let first {
            let foreign = gate.finish(first + 1)
            #expect(foreign == false, "别的运行号开了闸")
            #expect(gate.isRunning)
            let own = gate.finish(first)
            #expect(own)
        }
        #expect(!gate.isRunning)
        let third = gate.admit()
        #expect(third != nil)
    }

    @Test("准入只看门闩、不读阶段：把阶段拿走也不影响拒绝")
    func admissionDoesNotReadPhase() {
        var core = SlideToConfirmCore()
        guard let run = core.activate() else {
            Issue.record("首次激活应被准入")
            return
        }
        core.settle(run, outcome: .succeeded)
        #expect(core.phase == .returning(.succeeded))
        let lateActivation = core.activate()
        #expect(lateActivation == nil, "回位阶段激活被准入")
        let lateRelease = core.release(Self.sample(Self.geometry.travel), geometry: Self.geometry)
        #expect(lateRelease == .ignored, "回位阶段滑到底被准入")
        core.finish(run)
        #expect(core.phase == .idle)
        let fresh = core.activate()
        #expect(fresh != nil)
    }

    // MARK: 事件 → 状态 / Event-to-state table

    @Test("事件表：待命 →(滑到底) 执行 →(返回) 回位 →(回位走完) 待命")
    func eventTable() {
        var core = SlideToConfirmCore()
        core.drag(Self.geometry.travel)
        guard case .run(let run) = core.release(Self.sample(Self.geometry.travel), geometry: Self.geometry) else {
            Issue.record("滑到底应被准入")
            return
        }
        #expect(core.phase == .executing)
        #expect(core.knobOffset(in: Self.geometry) == Self.geometry.travel)
        core.drag(10)
        #expect(core.knobOffset(in: Self.geometry) == Self.geometry.travel, "执行阶段拖动改了指示器位置")
        core.settle(run, outcome: .failed)
        #expect(core.phase == .returning(.failed))
        #expect(core.knobOffset(in: Self.geometry) == 0)
        core.finish(run)
        #expect(core.phase == .idle)
        #expect(core.acceptsInput)
    }

    @Test("无障碍激活作废进行中的拖动会话")
    func activationCancelsDragSession() {
        var core = SlideToConfirmCore()
        core.drag(80)
        guard let run = core.activate() else {
            Issue.record("激活应被准入")
            return
        }
        core.settle(run, outcome: .succeeded)
        core.finish(run)
        #expect(core.knobOffset(in: Self.geometry) == 0, "激活前的拖动位移在运行结束后残留了")
    }

    @Test("回弹 / 打断 / 阶段变化都改变动效键；拖动变化不改——跟手位移不补间")
    func motionKeyChangesOnlyOnDiscreteEvents() {
        var core = SlideToConfirmCore()
        let start = core.motionKey
        core.drag(50)
        core.drag(90)
        #expect(core.motionKey == start, "拖动变化改了动效键 ⇒ 跟手位移会被补间")
        _ = core.release(Self.sample(90), geometry: Self.geometry)
        let afterRebound = core.motionKey
        #expect(afterRebound != start, "回弹没改动效键 ⇒ 回弹不补间")
        core.drag(60)
        core.interrupt()
        #expect(core.motionKey != afterRebound, "打断没改动效键 ⇒ 打断后的回位不补间")
        let beforeRun = core.motionKey
        guard let run = core.activate() else { return }
        let executing = core.motionKey
        #expect(executing != beforeRun)
        core.settle(run, outcome: .succeeded)
        #expect(core.motionKey != executing, "进入回位没改动效键 ⇒ 回位不补间")
    }

    // MARK: 触觉 / Sensory feedback

    @Test("确认与回弹给不同的触觉反馈")
    func confirmAndReboundFeedbackDiffer() {
        #expect(SlideToConfirmFeedbackKind.confirm.sensoryFeedback != SlideToConfirmFeedbackKind.rebound.sensoryFeedback)
    }

    // MARK: Reduce Motion

    @Test("Reduce Motion 分支：位移曲线 resting / hidden 下为 nil，回位停留为 0")
    func reduceMotionDegradesDisplacement() {
        #expect(CoreMotionToken.reveal.transformAnimation(for: .animated) != nil)
        #expect(CoreMotionToken.reveal.transformAnimation(for: .resting) == nil)
        #expect(CoreMotionToken.reveal.transformAnimation(for: .hidden) == nil)
        #expect(SlideToConfirmMotion.returnDwell(for: .animated) == .seconds(CoreMotionToken.reveal.duration))
        #expect(SlideToConfirmMotion.returnDwell(for: .resting) == .zero)
        #expect(SlideToConfirmMotion.returnDwell(for: .hidden) == .zero)
    }

    // MARK: 无障碍 / Accessibility

    @Test("替代 Button 的状态与禁用语义真值表：只有待命可激活，只有执行阶段带 Loading")
    func accessibilityTruthTable() {
        var core = SlideToConfirmCore()
        #expect(core.acceptsInput)
        #expect(core.phase.accessibilityValueText == nil)
        guard let run = core.activate() else { return }
        #expect(!core.acceptsInput, "执行阶段替代 Button 未禁用")
        #expect(core.phase.accessibilityValueText == Text("Loading", bundle: .module))
        core.settle(run, outcome: .succeeded)
        #expect(!core.acceptsInput, "回位阶段替代 Button 未禁用")
        #expect(core.phase.accessibilityValueText == nil)
        core.finish(run)
        #expect(core.acceptsInput)
    }

    @Test("播报文案：开始执行 Loading、成功 Success、失败 Failed；取消不播；键都已注册")
    func announcementTable() {
        let locale = Locale(identifier: "en_US")
        typealias Kind = SlideToConfirmCore.Announcement.Kind
        #expect(Kind.started.text(locale: locale) == "Loading")
        #expect(Kind.finished(.succeeded).text(locale: locale) == "Success")
        #expect(Kind.finished(.failed).text(locale: locale) == "Failed")
        #expect(Kind.finished(.cancelled).text(locale: locale) == nil, "取消被当成失败播报了")
        for key in ["Loading", "Success", "Failed"] {
            #expect(Bundle.module.localizedString(forKey: key, value: "__MISSING__", table: nil) != "__MISSING__", "键 \(key) 未注册")
        }
    }

    @Test("播报经 poster 走真实视图：一轮成功、一轮失败、一轮取消")
    func announcementsFlowThroughTheView() async throws {
        let recorder = SlideAnnouncementRecorder()
        let runner = SlideToConfirmRunner { _ in }
        let window = HostedWindow(
            SlideHarness(runner: runner)
                .environment(\.slideToConfirmAnnouncementPoster, FieldAnnouncementPoster { recorder.posts.append($0) })
                .environment(\.locale, Locale(identifier: "en_US")),
            size: CGSize(width: 320, height: 60),
            scheme: .light
        )
        defer { window.close() }
        #expect(recorder.posts.isEmpty, "首帧就播报了：\(recorder.posts)")

        for error in [nil, SlideDemoError() as (any Error)?, CancellationError() as (any Error)?] {
            let action = StatefulSuspension(.cooperative)
            runner.activate(presentation: .animated, action: { try await action.suspend() })
            try #require(await action.waitForArrivals(1))
            window.settle()
            action.release(throwing: error)
            await runner.task?.value
            window.settle()
        }
        #expect(
            recorder.posts == ["Loading", "Success", "Loading", "Failed", "Loading"],
            "播报序列实得 \(recorder.posts)"
        )
    }

    @Test("以执行阶段首帧出现（例如回屏重建）时不播报")
    func executingFirstFrameIsNotAnnounced() async throws {
        let recorder = SlideAnnouncementRecorder()
        let runner = SlideToConfirmRunner { _ in }
        let action = StatefulSuspension(.cooperative)
        runner.activate(presentation: .animated, action: { try await action.suspend() })
        try #require(await action.waitForArrivals(1))
        #expect(runner.core.phase == .executing)

        let window = HostedWindow(
            SlideHarness(runner: runner)
                .environment(\.slideToConfirmAnnouncementPoster, FieldAnnouncementPoster { recorder.posts.append($0) })
                .environment(\.locale, Locale(identifier: "en_US")),
            size: CGSize(width: 320, height: 60),
            scheme: .light
        )
        defer { window.close() }
        window.settle()
        #expect(recorder.posts.isEmpty, "以执行阶段首帧出现就播报了：\(recorder.posts)")
        action.release()
        await runner.task?.value
    }

    // MARK: 渲染 / Rendering

    @Test("执行阶段指示器停在尽头：待命与执行两帧的指示器前沿相差约一个全程")
    func executingKnobSitsAtTheEnd() async throws {
        let runner = SlideToConfirmRunner { _ in }
        let window = HostedWindow(SlideHarness(runner: runner), size: CGSize(width: 320, height: 60), scheme: .light)
        defer { window.close() }
        let idle = try #require(slideKnobLeadingEdge(window.pixels()), "待命帧里找不到指示器")

        let again = HostedWindow(SlideHarness(runner: SlideToConfirmRunner { _ in }), size: CGSize(width: 320, height: 60), scheme: .light)
        defer { again.close() }
        expectBitmapsEquivalent(window.pixels().bytes, again.pixels().bytes, maxChannelDelta: 2, "同一待命态两次渲染应在噪声以内相同")

        let action = StatefulSuspension(.cooperative)
        runner.activate(presentation: .resting, action: { try await action.suspend() })
        try #require(await action.waitForArrivals(1))
        window.settle()
        let executing = try #require(slideKnobLeadingEdge(window.pixels()), "执行帧里找不到指示器")
        let moved = CGFloat(executing - idle) / window.pixels().scale
        #expect(abs(moved - Self.geometry.travel) <= 2, "指示器前沿移动 \(moved) pt，期望约 \(Self.geometry.travel)")
        action.release()
        await runner.task?.value
    }
}

// MARK: - 测试支撑 / Support

private struct SlideDemoError: Error {}

@MainActor
private final class SlideAnnouncementRecorder {
    var posts: [String] = []
}

struct SlideHarness: View {
    let runner: SlideToConfirmRunner

    var body: some View {
        SlideToConfirm(runner: self.runner, action: { }) {
            Text(verbatim: "Slide to delete")
        }
    }
}

// 全帧近黑像素的最小横坐标（像素）：浅色外观下 accent 为墨色，文案是 secondaryLabel，不会落进阈值。
// 不取中线：iOS 宿主带顶部安全区，内容整体下移，中线穿不过指示器。
nonisolated func slideKnobLeadingEdge(_ pixels: HostedPixels) -> Int? {
    guard let bytes = pixels.bytes, pixels.width > 0 else { return nil }
    var leading: Int?
    for y in 0..<pixels.height {
        for x in 0..<(leading ?? pixels.width) {
            let i = (y * pixels.width + x) * 4
            if bytes[i + 3] > 200, bytes[i] < 50, bytes[i + 1] < 50, bytes[i + 2] < 50 {
                leading = x
                break
            }
        }
    }
    return leading
}

// MARK: - 动画进行中 / In-flight frames

// iOS 上 `layer.render(in:)` 取的是模型层，拍不到进行中的帧 ⇒ 只在 macOS 腿观测。
#if os(macOS)

@Suite("SlideToConfirm 动画进行中：回弹与回位经 CoreMotionToken 补间，Reduce Motion 下直接到位", .serialized)
@MainActor
struct SlideToConfirmInFlightTests {
    enum Scenario { case rebound, returning }

    static func pump() {
        RunLoop.main.run(until: Date().addingTimeInterval(0.008))
    }

    // 返回（途经的互异中间位置个数, 越出起止区间的帧数, 起止是否确实不同）。
    static func trace(_ scenario: Scenario, presentation: MotionPresentation, sampleFor duration: TimeInterval) async -> (intermediate: Int, overshoot: Int, moved: Bool) {
        let runner = SlideToConfirmRunner { _ in }
        let window = HostedWindow(
            SlideHarness(runner: runner).environment(\.coreMotionPresentationOverride, presentation),
            size: CGSize(width: 320, height: 60),
            scheme: .light
        )
        defer { window.close() }
        let geometry = SlideToConfirmTests.geometry
        let action = StatefulSuspension(.cooperative)
        switch scenario {
        case .rebound:
            runner.dragChanged(geometry.travel * 0.7)
        case .returning:
            runner.activate(presentation: presentation, action: { try await action.suspend() })
            _ = await action.waitForArrivals(1)
        }
        window.settle()
        let before = slideKnobLeadingEdge(window.pixels())

        var edges: [Int?] = []
        switch scenario {
        case .rebound:
            runner.release(
                SlideToConfirmDragSample(translation: geometry.travel * 0.7, predictedEndTranslation: geometry.travel * 0.7),
                geometry: geometry,
                presentation: presentation,
                action: { }
            )
        case .returning:
            action.release()
            while runner.core.phase == .executing { await Task.yield() }
        }
        let start = Date()
        while Date().timeIntervalSince(start) < duration {
            Self.pump()
            edges.append(slideKnobLeadingEdge(window.pixels()))
        }
        window.settle()
        let after = slideKnobLeadingEdge(window.pixels())
        await runner.task?.value
        guard let before, let after else { return (-1, -1, false) }
        let low = min(before, after), high = max(before, after)
        let seen = edges.compactMap { $0 }
        let intermediate = Set(seen.filter { $0 > low + 1 && $0 < high - 1 }).count
        let overshoot = seen.filter { $0 < low - 1 || $0 > high + 1 }.count
        return (intermediate, overshoot, abs(before - after) > 10)
    }

    @Test("未达阈值松手的回弹：RM 关时途经中间位置且不越过起点，RM 开时直接到位")
    func reboundInFlight() async {
        let resting = await Self.trace(.rebound, presentation: .resting, sampleFor: 0.4)
        #expect(resting.moved, "指示器没有回到起点，判据无效")
        #expect(resting.intermediate == 0, "RM 开时回弹途经了 \(resting.intermediate) 个中间位置，期望 0（位移类动效须走 transformAnimation(for:)）")
        var overshoot = 0
        for window in CoreMotionTokenInFlightTests.samplingWindows {
            let animated = await Self.trace(.rebound, presentation: .animated, sampleFor: window)
            overshoot = max(overshoot, animated.overshoot)
            if animated.moved, animated.intermediate >= 2 { break }
            if window == CoreMotionTokenInFlightTests.samplingWindows.last {
                Issue.record("回弹：RM 关时 \(CoreMotionTokenInFlightTests.samplingWindows.count) 个窗口里互异中间位置都不足 2 个（最后一次 \(animated.intermediate)）—— 无法下结论，不是通过")
            }
        }
        #expect(overshoot == 0, "回弹有 \(overshoot) 帧越出起止区间（过冲）")
    }

    @Test("执行后回位：RM 关时途经中间位置且不越过起点，RM 开时直接到位")
    func returnInFlight() async {
        let resting = await Self.trace(.returning, presentation: .resting, sampleFor: 0.4)
        #expect(resting.moved, "指示器没有回到起点，判据无效")
        #expect(resting.intermediate == 0, "RM 开时回位途经了 \(resting.intermediate) 个中间位置，期望 0")
        var overshoot = 0
        for window in CoreMotionTokenInFlightTests.samplingWindows {
            let animated = await Self.trace(.returning, presentation: .animated, sampleFor: window)
            overshoot = max(overshoot, animated.overshoot)
            if animated.moved, animated.intermediate >= 2 { break }
            if window == CoreMotionTokenInFlightTests.samplingWindows.last {
                Issue.record("回位：RM 关时 \(CoreMotionTokenInFlightTests.samplingWindows.count) 个窗口里互异中间位置都不足 2 个（最后一次 \(animated.intermediate)）—— 无法下结论，不是通过")
            }
        }
        #expect(overshoot == 0, "回位有 \(overshoot) 帧越出起止区间（过冲）")
    }
}

#endif
