import SwiftUI
import Testing
@testable import OhMyDesign

// MARK: - StatefulButton

@Suite("StatefulButton：四态视觉表达、防重入门闩、无障碍")
@MainActor
struct StatefulButtonTests {
    private struct DemoError: Error, Equatable {
        let code: Int
    }

    // MARK: 四态是枚举 / The four states are one enum

    @Test("四态两两不等——`==` 被改写成恒真时 .coreAnimation(_, value:) 分辨不出任何两态")
    func fourStatesArePairwiseDistinct() {
        let cases = StatefulButtonState.allCases
        #expect(cases.count == 4, "allCases 实得 \(cases.count) 个，期望 4")
        var distinctPairs = 0
        for i in cases.indices {
            for j in cases.indices where j > i {
                if cases[i] != cases[j] { distinctPairs += 1 }
            }
        }
        #expect(distinctPairs == 6, "两两不等的对数实得 \(distinctPairs)，期望 6")
    }

    @Test("四态各有视觉表达：idle 无配件符号，三个非静息态的符号互异")
    func everyStateHasItsOwnSymbol() {
        #expect(StatefulButtonState.idle.symbolName == nil, "idle 不应有配件符号")
        let symbols = StatefulButtonState.allCases.compactMap(\.symbolName)
        #expect(symbols.count == 3, "非静息态的符号实得 \(symbols.count) 个，期望 3")
        #expect(Set(symbols).count == 3, "互异符号实得 \(Set(symbols).count) 个，期望 3：\(symbols)")
    }

    // MARK: 无障碍 / Accessibility

    @Test("accessibilityValue 真值表：idle 无值，三个非静息态取本地化文案且互异")
    func accessibilityValueTruthTable() {
        #expect(StatefulButtonState.idle.accessibilityValueText == nil, "idle 不应给 accessibilityValue")
        #expect(StatefulButtonState.loading.accessibilityValueText == Text("Loading", bundle: .module))
        #expect(StatefulButtonState.success.accessibilityValueText == Text("Success", bundle: .module))
        #expect(StatefulButtonState.failure.accessibilityValueText == Text("Failed", bundle: .module))

        let values = StatefulButtonState.allCases.compactMap(\.accessibilityValueText)
        #expect(values.count == 3, "带 accessibilityValue 的态实得 \(values.count) 个，期望 3")
        var distinctPairs = 0
        for i in values.indices {
            for j in values.indices where j > i {
                if values[i] != values[j] { distinctPairs += 1 }
            }
        }
        #expect(distinctPairs == 3, "三个态文本两两不等的对数实得 \(distinctPairs)，期望 3")
    }

    @Test("三个态文案都已注册进 Localizable.strings——缺键时辅助技术读到的是原始 key")
    func accessibilityValueKeysAreRegistered() {
        for key in ["Loading", "Success", "Failed"] {
            let resolved = Bundle.module.localizedString(forKey: key, value: "__MISSING__", table: nil)
            #expect(resolved != "__MISSING__", "键 \(key) 未注册进 Localizable.strings")
        }
    }

    // MARK: 防重入门闩 / Re-entrancy latch

    @Test("门闩：action 执行期间第二次点击不被准入")
    func gateRejectsReentryWhileRunning() {
        var gate = StatefulButtonGate()
        let first = gate.admit()
        #expect(first != nil, "首次点击应被准入")
        #expect(gate.isRunning, "准入后门闩应处于「在跑」")
        let second = gate.admit()
        #expect(second == nil, "执行期间第二次点击被准入了 —— 会并发重入，实得运行号 \(String(describing: second))")
    }

    @Test("门闩不看视觉态：任一起始态下，执行期间把态改回 idle 再点，仍不重入")
    func latchIgnoresExternallyWrittenVisualState() {
        let hosts: [StatefulButtonState?] = [nil] + StatefulButtonState.allCases.map { $0 }
        var rejected = 0
        for host in hosts {
            var core = StatefulButtonCore()
            guard case .run = core.tap(host: host) else {
                Issue.record("起始态 \(String(describing: host))：首次点击应被准入")
                continue
            }
            if core.tap(host: .idle) == .ignored { rejected += 1 }
        }
        #expect(
            rejected == hosts.count,
            "把态改回 .idle 后仍拒绝重入的情形实得 \(rejected) 个，期望 \(hosts.count) —— 门闩依赖了可被外部修改的视觉态"
        )
    }

    // MARK: 事件 → 状态 / Event-to-state tables

    @Test("自管模式事件表：idle →(点击) loading →(成功) success →(停留结束) idle")
    func selfManagedSuccessTable() {
        var core = StatefulButtonCore()
        #expect(core.display(host: nil) == .idle)
        guard case .run(let run) = core.tap(host: nil) else {
            Issue.record("首次点击应被准入")
            return
        }
        #expect(core.display(host: nil) == .loading)
        let settled = core.settle(run, to: .success, host: nil)
        #expect(settled, "settle 应认下这次运行")
        #expect(core.display(host: nil) == .success)
        let didReset = core.reset(run, host: nil)
        #expect(didReset, "停留结束的复位应生效")
        #expect(core.display(host: nil) == .idle)
    }

    @Test("自管模式事件表：idle →(点击) loading →(抛错) failure →(停留结束) idle")
    func selfManagedFailureTable() {
        var core = StatefulButtonCore()
        guard case .run(let run) = core.tap(host: nil) else {
            Issue.record("首次点击应被准入")
            return
        }
        let settled = core.settle(run, to: .failure, host: nil)
        #expect(settled, "settle 应认下这次运行")
        #expect(core.display(host: nil) == .failure)
        let didReset = core.reset(run, host: nil)
        #expect(didReset, "停留结束的复位应生效")
        #expect(core.display(host: nil) == .idle)
    }

    @Test("托管模式事件表：组件从不写视觉态，只原样回放调用方那一份")
    func hostManagedCoreNeverWritesVisualState() {
        var core = StatefulButtonCore()
        guard case .run(let run) = core.tap(host: .idle) else {
            Issue.record("首次点击应被准入")
            return
        }
        #expect(core.display(host: nil) == .idle, "托管模式下 tap 写了组件自己那份视觉态")
        let settled = core.settle(run, to: .success, host: .loading)
        #expect(settled, "settle 应认下这次运行")
        #expect(core.display(host: nil) == .idle, "托管模式下 settle 写了组件自己那份视觉态")
        let didReset = core.reset(run, host: .loading)
        #expect(didReset, "reset 应认下这次运行")
        #expect(core.display(host: nil) == .idle, "托管模式下 reset 写了组件自己那份视觉态")
        for state in StatefulButtonState.allCases {
            #expect(core.display(host: state) == state, "托管态 \(state) 没有被原样回放")
        }
    }

    // MARK: 停留期间的点击与过期任务 / Dwell-window taps and stale runs

    @Test("停留期间点击立即开始新一轮；上一轮的停留复位不再改外观")
    func tapDuringDwellStartsNewRunAndStalePairsAreIgnored() {
        var core = StatefulButtonCore()
        guard case .run(let first) = core.tap(host: nil) else {
            Issue.record("首次点击应被准入")
            return
        }
        let settled = core.settle(first, to: .failure, host: nil)
        #expect(settled, "settle 应认下这次运行")
        #expect(core.display(host: nil) == .failure)

        guard case .run(let second) = core.tap(host: nil) else {
            Issue.record("停留期间的点击应被准入 —— failure 必须能立即重试")
            return
        }
        #expect(second != first, "新一轮应拿到新的运行号，实得 \(second) 与 \(first) 相同")
        #expect(core.display(host: nil) == .loading)
        let staleReset = core.reset(first, host: nil)
        #expect(staleReset == false, "上一轮的停留复位覆盖了新一轮的 loading")
        #expect(core.display(host: nil) == .loading)
        let freshReset = core.reset(second, host: nil)
        #expect(freshReset, "新一轮的停留复位应生效")
        #expect(core.display(host: nil) == .idle)
    }

    @Test("离屏 / 取消后作废：旧任务后到的结果与复位都不再改外观")
    func invalidatedRunCannotChangeAppearance() {
        var core = StatefulButtonCore()
        guard case .run(let run) = core.tap(host: nil) else {
            Issue.record("首次点击应被准入")
            return
        }
        core.invalidate()
        let staleSettle = core.settle(run, to: .success, host: nil)
        #expect(staleSettle == false, "作废后旧任务的结果仍改了外观")
        let staleReset = core.reset(run, host: nil)
        #expect(staleReset == false, "作废后旧任务的复位仍改了外观")
        #expect(core.display(host: nil) == .loading, "作废不回滚已画出的态")
        #expect(core.isRunning == false, "作废后门闩应已开，离屏再回来能重新点")
    }

    // MARK: 执行结果 / Outcome

    @Test("action 结果映射：正常返回 → success，抛错 → failure，取消 → 静默回 idle")
    func outcomeResolution() async {
        #expect(await StatefulButtonOutcome.resolve { } == .succeeded)
        #expect(await StatefulButtonOutcome.resolve { throw DemoError(code: 1) } == .failed)
        #expect(await StatefulButtonOutcome.resolve { throw CancellationError() } == .cancelled)
        #expect(StatefulButtonOutcome.succeeded.state == .success)
        #expect(StatefulButtonOutcome.failed.state == .failure)
        #expect(StatefulButtonOutcome.cancelled.state == .idle)
    }

    // MARK: Reduce Motion

    @Test("符号替换的 Reduce Motion 分支：resting / hidden 下为 ContentTransition.identity")
    func symbolReplacementDegrades() {
        #expect(MotionPresentation.animated.symbolReplacement == ContentTransition.symbolEffect(.replace))
        #expect(MotionPresentation.resting.symbolReplacement == ContentTransition.identity)
        #expect(MotionPresentation.hidden.symbolReplacement == ContentTransition.identity)
    }

    // MARK: 渲染 / Rendering

    @Test("四态渲染出四张互异位图 —— 不靠颜色，靠配件符号槽的有无与字形")
    func fourStatesRenderDistinctBitmaps() {
        var fingerprints: [UInt64] = []
        for state in StatefulButtonState.allCases {
            let window = HostedWindow(
                StatefulButton("Submit", state: state) { }
                    .buttonStyle(.solid()),
                size: CGSize(width: 240, height: 64),
                scheme: .light
            )
            defer { window.close() }
            guard let bytes = window.pixels().bytes else {
                Issue.record("态 \(state) 没画出位图")
                continue
            }
            fingerprints.append(bitmapFingerprint(bytes))
        }
        #expect(fingerprints.count == 4, "取到的位图实得 \(fingerprints.count) 张，期望 4")
        #expect(
            Set(fingerprints).count == 4,
            "四态渲染出的互异位图实得 \(Set(fingerprints).count) 张，期望 4 —— 有两态画得一模一样"
        )
    }

    // MARK: 无障碍接线 / Accessibility wiring

    // ⚠️ 实测（两条腿各一次）：单测进程里 SwiftUI 的无障碍树**观测不到**——
    // macOS 的 `NSHostingView` 只给出 `KeyViewProxy` / `_FocusRingView` 两个 AXUnknown 子节点，
    // iOS 的 `_UIHostingView` 连子视图都没有、`accessibilityElementCount()` 恒为 0，
    // 而同一份托管视图的位图渲染是正常的。⇒ 本条退回源码级接线判据；缺口已登记在
    // `docs/components/stateful-button.md` 的《无障碍》一节。
    @Test("无障碍接线：态文本接在 Button 整体上、由 StatefulButtonState 派生、配件符号对辅助技术隐藏")
    func accessibilityWiringIsStateDriven() {
        let url = GuardScanRoots.sourcesURL(of: GuardScanRoots.primaryTargetName)
            .appendingPathComponent("Components/Button/StatefulButton.swift")
        guard let source = try? String(contentsOf: url, encoding: .utf8) else {
            Issue.record(Comment(rawValue: "读不到 StatefulButton 源码：\(url.path)"))
            return
        }
        let required = [
            ".modifier(StatefulButtonAccessibility(state: state))",
            "if let value = self.state.accessibilityValueText {",
            "content.accessibilityValue(value)",
            ".accessibilityHidden(true)",
        ]
        let missing = required.filter { !source.contains($0) }
        #expect(
            missing.isEmpty,
            "无障碍接线缺 \(missing.count) 处，期望 0：\(missing) —— 缺第 1 条 ⇒ 四态切换对辅助技术不可见；缺第 2 / 3 条 ⇒ 播报的不是按态派生的那份文本；缺第 4 条 ⇒ 状态被读两遍"
        )
    }
}

// MARK: - 动画进行中 / In-flight frames

// iOS 上 `layer.render(in:)` 取的是模型层，拍不到进行中的帧 ⇒ 只在 macOS 腿观测。
// ⚠️ 两臂都断言「采到中间帧」，不断言 resting 臂为 0：`.press` 档在 Reduce Motion 下按
// `CoreMotionToken.animation(for:)` 的定义仍是同时长 `easeInOut`（只去掉运动、保留淡变），
// 且实测 resting 臂的中间像素峰值（214）比 animated 臂（28）还高。
#if os(macOS)

@MainActor
private final class StatefulStateBox: ObservableObject {
    @Published var state: StatefulButtonState = .loading
}

private struct StatefulHarness: View {
    @ObservedObject var box: StatefulStateBox

    var body: some View {
        StatefulButton("Submit", state: self.box.state) { }
            .buttonStyle(.solid())
            .controlSize(.large)
    }
}

@Suite("StatefulButton 动画进行中：态切换经 CoreMotionToken 补间", .serialized)
@MainActor
struct StatefulButtonInFlightTests {
    static func outsideEndpoints(before: HostedPixels, after: HostedPixels, frame: HostedPixels) -> Int {
        guard let b = before.bytes, let a = after.bytes, let f = frame.bytes,
              b.count == a.count, b.count == f.count else { return -1 }
        func differs(_ x: [UInt8], _ y: [UInt8], _ i: Int) -> Bool {
            (0..<3).contains { abs(Int(x[i + $0]) - Int(y[i + $0])) > 40 }
        }
        var count = 0
        var i = 0
        while i + 3 < f.count {
            if differs(f, b, i), differs(f, a, i) { count += 1 }
            i += 4
        }
        return count
    }

    static func peak(reduceMotion: Bool, sampleFor duration: TimeInterval) -> (peak: Int, changed: Bool) {
        let box = StatefulStateBox()
        let window = HostedWindow(
            StatefulHarness(box: box)
                .environment(\.coreMotionPresentationOverride, reduceMotion ? .resting : .animated),
            size: CGSize(width: 240, height: 64),
            scheme: .light
        )
        defer { window.close() }
        let before = window.pixels()
        var frames: [HostedPixels] = []
        box.state = .success
        let start = Date()
        while Date().timeIntervalSince(start) < duration {
            RunLoop.main.run(until: Date().addingTimeInterval(0.008))
            frames.append(window.pixels())
        }
        window.settle()
        let after = window.pixels()
        let peak = frames.map { Self.outsideEndpoints(before: before, after: after, frame: $0) }.max() ?? -1
        return (peak, before.bytes != after.bytes)
    }

    @Test("loading → success 真的在补间：两种呈现下都采到两端之外的中间帧（态枚举的 == 被改写或 coreAnimation 被摘掉时归零）")
    func stateChangeIsInterpolatedInFlight() {
        for reduceMotion in [false, true] {
            let arm = reduceMotion ? "resting" : "animated"
            _ = CoreMotionTokenInFlightTests.observeControlMotion(
                "StatefulButton loading → success（\(arm)）",
                threshold: 0
            ) { window in
                let sample = Self.peak(reduceMotion: reduceMotion, sampleFor: window)
                return sample.changed ? sample.peak : -1
            }
        }
    }
}

#endif
