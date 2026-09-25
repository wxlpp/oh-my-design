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

    @Test("四态两两不等——`==` 被改写成恒真时 .animation(_:value:) 分辨不出任何两态、永不触发")
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

    @Test("离屏作废只收回显示权、不开闸：旧运行 finish 前再点仍被忽略，finish 后自管态回 idle")
    func invalidatedRunKeepsGateClosedUntilItFinishes() {
        for host in [nil, StatefulButtonState.idle] {
            var core = StatefulButtonCore()
            guard case .run(let run) = core.tap(host: host) else {
                Issue.record("host \(String(describing: host))：首次点击应被准入")
                continue
            }
            core.invalidate(host: host)
            #expect(core.isRunning, "host \(String(describing: host))：作废后旧运行仍在跑，门闩却开了")
            #expect(
                core.tap(host: host) == .ignored,
                "host \(String(describing: host))：旧运行未 finish 时的点击被准入了 —— 会与仍在跑的 action 并发"
            )
            let staleSettle = core.settle(run, to: .success, host: host)
            #expect(staleSettle == false, "host \(String(describing: host))：作废后旧运行的结果仍改了外观")
            let staleReset = core.reset(run, host: host)
            #expect(staleReset == false, "host \(String(describing: host))：作废后旧运行的复位仍改了外观")
            #expect(core.isRunning == false, "host \(String(describing: host))：旧运行 finish 后门闩应已开")
            guard case .run = core.tap(host: host) else {
                Issue.record("host \(String(describing: host))：旧运行 finish 后的点击应被准入")
                continue
            }
        }
    }

    @Test("自管模式离屏不卡态：loading 期间离屏保持 loading 直到旧运行结束再回 idle；停留期间离屏直接回 idle")
    func selfManagedInvalidationNeverStrandsVisualState() {
        var core = StatefulButtonCore()
        guard case .run(let running) = core.tap(host: nil) else {
            Issue.record("首次点击应被准入")
            return
        }
        core.invalidate(host: nil)
        #expect(core.display(host: nil) == .loading, "旧运行仍占着门闩，外观应如实显示 loading")
        _ = core.settle(running, to: .success, host: nil)
        #expect(core.display(host: nil) == .idle, "作废后的旧运行结束，自管态卡在 \(core.display(host: nil))")

        for outcome in [StatefulButtonState.success, .failure] {
            var dwelling = StatefulButtonCore()
            guard case .run(let run) = dwelling.tap(host: nil) else {
                Issue.record("首次点击应被准入")
                continue
            }
            _ = dwelling.settle(run, to: outcome, host: nil)
            #expect(dwelling.display(host: nil) == outcome)
            dwelling.invalidate(host: nil)
            #expect(
                dwelling.display(host: nil) == .idle,
                "\(outcome) 停留期间离屏：停留复位随 Task 取消而不会来，自管态卡在 \(dwelling.display(host: nil))"
            )
        }
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

    // MARK: 播报 / Announcements

    @Test("态切换经 poster 播报：每次进入非静息态播一次、文案取本地化值，回 idle 与首帧不播")
    func stateChangesAreAnnounced() {
        let recorder = StatefulAnnouncementRecorder()
        let poster = FieldAnnouncementPoster { recorder.posts.append($0) }
        let box = StatefulStateBox(.idle)
        let window = HostedWindow(
            StatefulHarness(box: box)
                .environment(\.statefulButtonAnnouncementPoster, poster)
                .environment(\.locale, Locale(identifier: "en_US")),
            size: CGSize(width: 240, height: 64),
            scheme: .light
        )
        defer { window.close() }
        #expect(recorder.posts.isEmpty, "首帧就播报了：\(recorder.posts)")
        for next in [StatefulButtonState.loading, .success, .idle, .loading, .failure, .idle] {
            box.state = next
            window.settle()
        }
        let expected = [StatefulButtonState.loading, .success, .loading, .failure].compactMap {
            $0.announcement(locale: Locale(identifier: "en_US"))
        }
        #expect(expected == ["Loading", "Success", "Loading", "Failed"], "announcement 文案实得 \(expected)")
        #expect(recorder.posts == expected, "播报序列实得 \(recorder.posts)，期望 \(expected)")
    }

    @Test("以非静息态首帧出现时不播报")
    func nonIdleFirstFrameIsNotAnnounced() {
        for initial in [StatefulButtonState.loading, .success, .failure] {
            let recorder = StatefulAnnouncementRecorder()
            let poster = FieldAnnouncementPoster { recorder.posts.append($0) }
            let window = HostedWindow(
                StatefulHarness(box: StatefulStateBox(initial))
                    .environment(\.statefulButtonAnnouncementPoster, poster)
                    .environment(\.locale, Locale(identifier: "en_US")),
                size: CGSize(width: 240, height: 64),
                scheme: .light
            )
            defer { window.close() }
            window.settle()
            #expect(recorder.posts.isEmpty, "以 \(initial) 首帧出现就播报了：\(recorder.posts)")
        }
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

    // 单测进程里观测不到 SwiftUI 的无障碍树，所以接线只能在源码层核；缺口见组件文档《无障碍》。
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
            "content.accessibilityValue(self.state.accessibilityValueText ?? Text(verbatim: \"\"))",
            ".accessibilityHidden(true)",
        ]
        let missing = required.filter { !source.contains($0) }
        #expect(
            missing.isEmpty,
            "无障碍接线缺 \(missing.count) 处，期望 0：\(missing) —— 缺第 1 条 ⇒ 四态对辅助技术不可见；缺第 2 条 ⇒ value 不是按态派生的那份文本；缺第 3 条 ⇒ 状态被读两遍"
        )
    }
}

// MARK: - 动画进行中 / In-flight frames

@MainActor
private final class StatefulAnnouncementRecorder {
    var posts: [String] = []
}

@MainActor
private final class StatefulStateBox: ObservableObject {
    @Published var state: StatefulButtonState

    init(_ state: StatefulButtonState) {
        self.state = state
    }
}

private struct StatefulHarness: View {
    @ObservedObject var box: StatefulStateBox

    var body: some View {
        StatefulButton("Submit", state: self.box.state) { }
            .buttonStyle(.solid())
            .controlSize(.large)
    }
}

// iOS 上 `layer.render(in:)` 取的是模型层，拍不到进行中的帧 ⇒ 只在 macOS 腿观测。
#if os(macOS)

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

    static func peak(
        from: StatefulButtonState,
        to: StatefulButtonState,
        reduceMotion: Bool,
        sampleFor duration: TimeInterval
    ) -> (peak: Int, changed: Bool) {
        let box = StatefulStateBox(from)
        let window = HostedWindow(
            StatefulHarness(box: box)
                .environment(\.coreMotionPresentationOverride, reduceMotion ? .resting : .animated),
            size: CGSize(width: 240, height: 64),
            scheme: .light
        )
        defer { window.close() }
        let before = window.pixels()
        var frames: [HostedPixels] = []
        box.state = to
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

    @Test("idle → loading：RM 关时有中间帧（转圈层与宽度补间不区分），RM 开时直接跳到位")
    func layoutTransitionInFlight() {
        let resting = Self.peak(from: .idle, to: .loading, reduceMotion: true, sampleFor: 0.3)
        #expect(resting.changed, "配件槽没有出现，判据无效")
        #expect(
            resting.peak == 0,
            """
            RM 开时宽度不得补间（补间等于横向位移），两端之外的中间帧峰值实得 \(resting.peak)。\
            布局类动效须走 `transformAnimation(for:)`，它在 resting 下为 nil
            """
        )
        _ = CoreMotionTokenInFlightTests.observeControlMotion(
            "StatefulButton idle → loading（animated）",
            threshold: 0
        ) { window in
            let animated = Self.peak(from: .idle, to: .loading, reduceMotion: false, sampleFor: window)
            return animated.changed ? animated.peak : -1
        }
    }

    @Test("loading → success：RM 关时符号替换有中间帧，RM 开时一帧都没有")
    func symbolReplacementInFlight() {
        let resting = Self.peak(from: .loading, to: .success, reduceMotion: true, sampleFor: 0.3)
        #expect(resting.changed, "符号没有换过去，判据无效")
        #expect(
            resting.peak == 0,
            """
            RM 开时不得出现两端之外的中间帧，峰值实得 \(resting.peak)。\
            态切换的动效入口须走 `transformAnimation(for:)`；`animation(for:)`（即 `.coreAnimation`）\
            在 resting 下给的是同时长 easeInOut，不是 nil
            """
        )
        _ = CoreMotionTokenInFlightTests.observeControlMotion(
            "StatefulButton loading → success（animated）",
            threshold: 0
        ) { window in
            let animated = Self.peak(from: .loading, to: .success, reduceMotion: false, sampleFor: window)
            return animated.changed ? animated.peak : -1
        }
    }
}

#endif
