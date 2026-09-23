import Foundation
import SwiftUI
import Testing
@testable import OhMyDesign

// 等待一律事件驱动、不设时限（同 StatefulButtonRunnerTests）。
@Suite("SlideToConfirm 编排：手势 / 无障碍激活 → 执行 → 回位，共用门闩、离屏与取消")
@MainActor
struct SlideToConfirmRunnerTests {
    private struct DemoError: Error {}

    static let geometry = SlideToConfirmGeometry(width: 320, knob: 44, spacing: 4)

    private static func runner(sleeper: StatefulSuspension) -> SlideToConfirmRunner {
        SlideToConfirmRunner { try await sleeper.suspend(recording: $0) }
    }

    private static func sample(_ translation: CGFloat, predicted: CGFloat? = nil) -> SlideToConfirmDragSample {
        SlideToConfirmDragSample(translation: translation, predictedEndTranslation: predicted ?? translation)
    }

    @discardableResult
    private static func slide(
        _ runner: SlideToConfirmRunner,
        to translation: CGFloat,
        predicted: CGFloat? = nil,
        presentation: MotionPresentation = .animated,
        action: StatefulSuspension
    ) -> Bool {
        runner.dragChanged(translation)
        return runner.release(
            Self.sample(translation, predicted: predicted),
            geometry: Self.geometry,
            presentation: presentation,
            action: { try await action.suspend() }
        )
    }

    // 回位停留缺席时 action 返回后直接落到待命——此时判红，而不是等一个永远不来的 sleep 到达。
    private static func enteredReturning(_ runner: SlideToConfirmRunner, sleeper: StatefulSuspension, arrivals: Int) async -> Bool {
        while runner.core.phase == .executing { await Task.yield() }
        guard case .returning = runner.core.phase else { return false }
        return await sleeper.waitForArrivals(arrivals)
    }

    @discardableResult
    private static func activate(
        _ runner: SlideToConfirmRunner,
        presentation: MotionPresentation = .animated,
        action: StatefulSuspension
    ) -> Bool {
        runner.activate(presentation: presentation, action: { try await action.suspend() })
    }

    @Test("滑到底：执行一次 → 回位（停留 reveal 时长）→ 待命，门闩到回位走完才开")
    func slidingToTheEndRunsOnceThenReturns() async throws {
        let action = StatefulSuspension(.cooperative)
        let sleeper = StatefulSuspension(.cooperative)
        let runner = Self.runner(sleeper: sleeper)

        #expect(Self.slide(runner, to: Self.geometry.travel, action: action), "滑到底未被准入")
        try #require(await action.waitForArrivals(1), "action 没被调起")
        #expect(runner.core.phase == .executing)
        #expect(runner.core.knobOffset(in: Self.geometry) == Self.geometry.travel, "执行期间指示器应停在尽头")

        action.release()
        try #require(await Self.enteredReturning(runner, sleeper: sleeper, arrivals: 1), "没有进入回位停留")
        #expect(runner.core.phase == .returning(.succeeded))
        #expect(runner.core.knobOffset(in: Self.geometry) == 0, "回位阶段目标位置应为起点")
        #expect(
            sleeper.durations == [.seconds(CoreMotionToken.reveal.duration)],
            "回位时长实得 \(sleeper.durations)"
        )
        #expect(!runner.core.acceptsInput, "回位未走完门闩就开了")

        sleeper.release()
        await runner.task?.value
        #expect(runner.core.phase == .idle)
        #expect(runner.core.acceptsInput, "回位走完后门闩应打开")
        #expect(action.arrivals == 1)
    }

    @Test("四个负例经真实编排路径都不触发：甩一半、反向、阈值前一点、拖到底后被打断")
    func negativesNeverRun() async {
        let travel = Self.geometry.travel
        let action = StatefulSuspension(.passThrough)
        let sleeper = StatefulSuspension(.passThrough)
        let runner = Self.runner(sleeper: sleeper)

        #expect(!Self.slide(runner, to: travel / 2, predicted: Self.geometry.width * 4, action: action), "快速甩到一半松手触发了")
        #expect(!Self.slide(runner, to: -travel, predicted: -Self.geometry.width * 4, action: action), "反向拖动触发了")
        runner.dragChanged(travel + 40)
        let draggedBack = runner.release(
            Self.sample(8), geometry: Self.geometry, presentation: .animated, action: { try await action.suspend() }
        )
        #expect(!draggedBack, "先拖过尽头再拖回来松手触发了")
        #expect(!Self.slide(runner, to: travel - 0.5, action: action), "阈值前 0.5 pt 松手触发了")

        runner.dragChanged(travel + 40)
        runner.interrupt()
        #expect(runner.core.knobOffset(in: Self.geometry) == 0, "被打断后指示器没回起点")

        #expect(action.arrivals == 0, "负例里 action 被调起 \(action.arrivals) 次")
        #expect(runner.task == nil, "负例里起了 Task")
        #expect(runner.core.phase == .idle)
        #expect(runner.core.acceptsInput)
    }

    @Test("手势与无障碍激活共用一道门闩：任意交错的连续激活只执行一次")
    func gestureAndAccessibilityShareOneGate() async throws {
        for order in 0..<3 {
            let action = StatefulSuspension(.cooperative)
            let sleeper = StatefulSuspension(.passThrough)
            let runner = Self.runner(sleeper: sleeper)
            let travel = Self.geometry.travel

            let second: Bool
            switch order {
            case 0:
                #expect(Self.slide(runner, to: travel, action: action))
                second = Self.activate(runner, action: action)
                #expect(!second, "手势准入后无障碍激活又被准入")
            case 1:
                #expect(Self.activate(runner, action: action))
                second = Self.slide(runner, to: travel + 10, action: action)
                #expect(!second, "无障碍准入后迟到的松手又被准入")
            default:
                #expect(Self.activate(runner, action: action))
                second = Self.activate(runner, action: action)
                #expect(!second, "无障碍连续激活两次都被准入")
            }
            if second { continue }
            try #require(await action.waitForArrivals(1), "序列 \(order)：action 没被调起")
            action.release()
            await runner.task?.value
            #expect(action.arrivals == 1, "序列 \(order)：action 被调起 \(action.arrivals) 次，期望 1")
            #expect(runner.core.acceptsInput, "序列 \(order)：走完后门闩没开")
        }
    }

    @Test("「动作已完成、回位未完成」窗口：手势与无障碍激活都被拒，回位走完才能再次触发")
    func returningWindowIsNotRetriggerable() async throws {
        let action = StatefulSuspension(.cooperative)
        let sleeper = StatefulSuspension(.cooperative)
        let runner = Self.runner(sleeper: sleeper)

        Self.activate(runner, action: action)
        try #require(await action.waitForArrivals(1), "action 没被调起")
        action.release()
        try #require(await Self.enteredReturning(runner, sleeper: sleeper, arrivals: 1), "没有进入回位停留")
        #expect(runner.core.phase == .returning(.succeeded))

        let lateActivation = Self.activate(runner, action: action)
        #expect(!lateActivation, "回位窗口里无障碍激活被准入")
        // 被错误准入的运行会覆盖挂起点，再等下去只会挂死而不是判红。
        if lateActivation { return }
        let lateSlide = Self.slide(runner, to: Self.geometry.travel, action: action)
        #expect(!lateSlide, "回位窗口里滑到底被准入")
        if lateSlide { return }
        #expect(action.arrivals == 1)

        sleeper.release()
        await runner.task?.value
        #expect(Self.activate(runner, action: action), "回位走完后应能再次触发")
        try #require(await action.waitForArrivals(2), "第二轮 action 没被调起")
        action.release()
        try #require(await Self.enteredReturning(runner, sleeper: sleeper, arrivals: 2), "第二轮没有进入回位停留")
        sleeper.release()
        await runner.task?.value
    }

    @Test("action 抛错 → 回位（failed）；抛 CancellationError → 静默回位（cancelled）；两者都开闸")
    func thrownAndCancelledOutcomesReturn() async throws {
        for (error, outcome) in [
            (DemoError() as any Error, StatefulButtonOutcome.failed),
            (CancellationError() as any Error, .cancelled),
        ] {
            let action = StatefulSuspension(.cooperative)
            let sleeper = StatefulSuspension(.cooperative)
            let runner = Self.runner(sleeper: sleeper)

            Self.slide(runner, to: Self.geometry.travel, action: action)
            try #require(await action.waitForArrivals(1), "action 没被调起")
            action.release(throwing: error)
            try #require(await Self.enteredReturning(runner, sleeper: sleeper, arrivals: 1), "\(outcome)：没有进入回位停留")
            #expect(runner.core.phase == .returning(outcome), "实得 \(runner.core.phase)")
            sleeper.release()
            await runner.task?.value
            #expect(runner.core.phase == .idle)
            #expect(runner.core.acceptsInput, "\(outcome)：走完后门闩没开")
        }
    }

    @Test("执行中离屏：action 收到取消；它返回前再激活 / 再滑被忽略；返回后回位随取消立即结束、开闸")
    func disappearingMidRunKeepsGateClosedUntilActionReturns() async throws {
        let action = StatefulSuspension(.ignoresCancellation)
        let sleeper = StatefulSuspension(.cooperative)
        let runner = Self.runner(sleeper: sleeper)

        Self.slide(runner, to: Self.geometry.travel, action: action)
        try #require(await action.waitForArrivals(1), "action 没被调起")
        runner.disappear()
        #expect(action.cancelled, "离屏后 action 没收到取消")
        #expect(runner.core.phase == .executing, "action 仍在跑时应如实停在执行阶段")
        let lateActivation = Self.activate(runner, action: action)
        #expect(!lateActivation, "离屏后、action 返回前的无障碍激活被准入——会并发重入")
        let lateSlide = Self.slide(runner, to: Self.geometry.travel, action: action)
        #expect(!lateSlide, "离屏后、action 返回前的滑动被准入")
        if lateActivation || lateSlide { return }

        action.release()
        await runner.task?.value
        #expect(runner.core.phase == .idle, "action 返回后应回到待命，实得 \(runner.core.phase)")
        #expect(runner.core.acceptsInput, "action 返回后门闩应打开")
        #expect(action.arrivals == 1)
    }

    @Test("Reduce Motion：回位不停留，action 返回即开闸")
    func reduceMotionSkipsReturnDwell() async throws {
        let action = StatefulSuspension(.cooperative)
        let sleeper = StatefulSuspension(.passThrough)
        let runner = Self.runner(sleeper: sleeper)

        Self.slide(runner, to: Self.geometry.travel, presentation: .resting, action: action)
        try #require(await action.waitForArrivals(1), "action 没被调起")
        action.release()
        await runner.task?.value
        #expect(sleeper.arrivals == 0, "RM 下仍进入了回位停留 \(sleeper.arrivals) 次")
        #expect(runner.core.phase == .idle)
        #expect(runner.core.acceptsInput)
    }

    @Test("触觉事件：确认一次、回弹一次，二者反馈不同；被打断与无障碍激活不产生触觉")
    func feedbackEventsFollowGestureOnly() async throws {
        let action = StatefulSuspension(.passThrough)
        let sleeper = StatefulSuspension(.passThrough)
        let runner = Self.runner(sleeper: sleeper)

        Self.slide(runner, to: 60, action: action)
        let rebound = try #require(runner.core.feedback, "回弹没有触觉事件")
        #expect(rebound.kind == .rebound)

        runner.dragChanged(Self.geometry.travel)
        runner.interrupt()
        #expect(runner.core.feedback == rebound, "被打断产生了触觉事件")

        Self.slide(runner, to: 0, action: action)
        #expect(runner.core.feedback == rebound, "位移为 0 的松手产生了回弹触觉")

        Self.slide(runner, to: Self.geometry.travel, action: action)
        let confirm = try #require(runner.core.feedback)
        #expect(confirm.kind == .confirm, "滑到底的触觉事件实得 \(confirm.kind)")
        #expect(confirm != rebound)
        await runner.task?.value

        Self.activate(runner, action: action)
        #expect(runner.core.feedback == confirm, "无障碍激活产生了触觉事件")
        await runner.task?.value
    }

    // 单测进程里合成事件驱动不了 SwiftUI 手势、无障碍树里也找不到替代 Button，视图到编排器的接线只能在源码层核。
    @Test("视图接线：手势三路、无障碍激活与离屏各自转交编排器")
    func viewForwardsToRunner() {
        let url = GuardScanRoots.sourcesURL(of: GuardScanRoots.primaryTargetName)
            .appendingPathComponent("Components/SlideToConfirm/SlideToConfirm.swift")
        guard let source = try? String(contentsOf: url, encoding: .utf8) else {
            Issue.record(Comment(rawValue: "读不到 SlideToConfirm 源码：\(url.path)"))
            return
        }
        let required = [
            "@GestureState private var dragging = false",
            ".updating(self.$dragging) { _, state, _ in state = true }",
            ".onChanged { value in self.runner.dragChanged(value.translation.width) }",
            """
                        .onEnded { value in
                            self.runner.release(
                                SlideToConfirmDragSample(
                                    translation: value.translation.width,
                                    predictedEndTranslation: value.predictedEndTranslation.width
                                ),
                                geometry: geometry,
                                presentation: self.motionPresentation,
                                action: self.action
                            )
                        }
            """,
            """
                    .onChange(of: self.dragging) { _, active in
                        if !active { self.runner.interrupt() }
                    }
            """,
            """
                    .onDisappear {
                        self.runner.disappear()
                    }
            """,
            """
                    .accessibilityRepresentation {
                        Button {
                            self.runner.activate(presentation: self.motionPresentation, action: self.action)
                        } label: {
                            self.label
                        }
                        .disabled(!core.acceptsInput)
                        .accessibilityValue(core.phase.accessibilityValueText ?? Text(verbatim: ""))
                    }
            """,
        ]
        func squash(_ text: String) -> String { text.split(whereSeparator: \.isWhitespace).joined(separator: " ") }
        let flat = squash(source)
        let missing = required.filter { !flat.contains(squash($0)) }
        #expect(
            missing.isEmpty,
            """
            视图接线缺 \(missing.count) 处，期望 0：\(missing) —— 缺 GestureState / updating ⇒ 被打断的手势不回位；\
            缺 onEnded ⇒ 松手不判定；缺 onChange(dragging) ⇒ 打断不转交；缺 onDisappear ⇒ 离屏不取消；\
            缺 accessibilityRepresentation ⇒ 辅助技术没有替代路径，或它不走同一道门闩、不带禁用 / 状态
            """
        )
    }
}
