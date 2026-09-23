import SwiftUI
import Testing
@testable import OhMyDesign

// MARK: - SlideToConfirm

@Suite("SlideToConfirm：纯距离阈值、夹紧、门闩、无障碍与播报")
@MainActor
struct SlideToConfirmTests {
    static let geometry = SlideToConfirmGeometry(width: 320, knob: 44, spacing: 4)
    // 待命时指示器中心的逻辑横坐标（间距 4 + 半径 22）。
    static let onKnob: CGFloat = 26

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
        core.drag(Self.geometry.travel + 30, startX: Self.onKnob, geometry: Self.geometry)
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

    @Test("回位阶段拒绝准入：无障碍激活与滑到底都被拒，回位走完后才放行")
    func returningPhaseRejectsAdmission() {
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

    // MARK: 拖动会话 / Drag session

    @Test("指示器命中区：指示器连同两侧间距，之外都不算")
    func knobHitArea() {
        let g = Self.geometry
        for x in [0, Self.onKnob, 52] as [CGFloat] {
            #expect(g.knobContains(logicalX: x, atOffset: 0), "x = \(x) 应落在待命指示器上")
        }
        for x in [-1, 53, 160, 300] as [CGFloat] {
            #expect(!g.knobContains(logicalX: x, atOffset: 0), "x = \(x) 不该算落在待命指示器上")
        }
        #expect(g.knobContains(logicalX: g.travel + Self.onKnob, atOffset: g.travel))
    }

    @Test("手势认领：横向位移严格占主导才认领；纵向起手、正斜 45° 与零位移都让给外层滚动视图")
    func panClaimsOnlyHorizontalDominantMovement() {
        let claimed: [CGPoint] = [CGPoint(x: 10, y: 0), CGPoint(x: -10, y: 3), CGPoint(x: 10, y: 9.9), CGPoint(x: 60, y: -20)]
        let yielded: [CGPoint] = [CGPoint(x: 0, y: 10), CGPoint(x: 3, y: -10), CGPoint(x: 10, y: 10), CGPoint(x: -10, y: -10), .zero]
        #expect(claimed.filter { !SlideToConfirmPanArbitration.claims($0) }.isEmpty, "横向占主导却没认领")
        #expect(yielded.filter { SlideToConfirmPanArbitration.claims($0) }.isEmpty, "纵向占主导或不分胜负却认领了 ⇒ 外层 ScrollView 滚不动")
    }

    @Test("起点不在指示器上的会话只吸收：不位移、松手不触发、不给触觉、不改动效键")
    func sessionStartingOffTheKnobIsAbsorbed() {
        var core = SlideToConfirmCore()
        let key = core.motionKey
        core.drag(Self.geometry.travel, startX: 120, geometry: Self.geometry)
        #expect(core.knobOffset(in: Self.geometry) == 0, "起点在轨道空白处的拖动推动了指示器")
        let release = core.release(Self.sample(Self.geometry.travel), geometry: Self.geometry)
        #expect(release == .ignored, "起点在轨道空白处的会话松手实得 \(release)")
        #expect(core.phase == .idle)
        #expect(core.feedback == nil, "被吸收的会话产生了触觉")
        #expect(core.motionKey == key, "被吸收的会话改了动效键")

        core.drag(Self.geometry.travel, startX: Self.onKnob, geometry: Self.geometry)
        guard case .run = core.release(Self.sample(Self.geometry.travel), geometry: Self.geometry) else {
            Issue.record("被吸收的会话之后，起点在指示器上的新会话应能触发")
            return
        }
    }

    @Test("门闩关闭期间开始的会话整段作废：开闸后继续拖、再松手也不触发")
    func sessionStartedWhileGateClosedStaysVoid() {
        var core = SlideToConfirmCore()
        guard let run = core.activate() else {
            Issue.record("首次激活应被准入")
            return
        }
        core.drag(10, startX: Self.geometry.travel + Self.onKnob, geometry: Self.geometry)
        core.settle(run, outcome: .succeeded)
        core.finish(run)
        #expect(core.acceptsInput, "回位走完后门闩应打开")
        core.drag(Self.geometry.travel, startX: Self.geometry.travel + Self.onKnob, geometry: Self.geometry)
        #expect(core.knobOffset(in: Self.geometry) == 0, "作废的会话在开闸后推动了指示器")
        let release = core.release(Self.sample(Self.geometry.travel), geometry: Self.geometry)
        #expect(release == .ignored, "门闩关闭期间开始的会话在开闸后松手实得 \(release) —— 排队式二次执行")
    }

    @Test("打断先于松手到达时，松手仍按会话裁决判定")
    func releaseAfterInterruptStillJudgesTheSession() {
        var core = SlideToConfirmCore()
        core.drag(Self.geometry.travel, startX: Self.onKnob, geometry: Self.geometry)
        core.interrupt()
        guard case .run = core.release(Self.sample(Self.geometry.travel), geometry: Self.geometry) else {
            Issue.record("打断先到时，滑到底的松手没有触发")
            return
        }
    }

    // MARK: RTL

    @Test("RTL：手势位移按方向系数换成「朝尽头为正」，起点在右端")
    func rightToLeftMirrorsTheTrack() {
        let rtl = SlideToConfirmGeometry(width: 320, knob: 44, spacing: 4, layoutDirection: .rightToLeft)
        let travel = rtl.travel
        #expect(rtl.confirms(rtl.sample(translation: -travel, predictedEndTranslation: -travel)), "RTL 下向左滑到底没触发")
        #expect(!rtl.confirms(rtl.sample(translation: travel, predictedEndTranslation: travel)), "RTL 下向右滑触发了")
        #expect(rtl.knobContains(logicalX: rtl.logicalX(320 - Self.onKnob), atOffset: 0), "RTL 下右端不是指示器起点")
        #expect(!rtl.knobContains(logicalX: rtl.logicalX(Self.onKnob), atOffset: 0), "RTL 下左端被当成指示器起点")

        let ltr = Self.geometry
        #expect(ltr.sample(translation: travel, predictedEndTranslation: 1) == Self.sample(travel, predicted: 1))
        #expect(ltr.logicalX(Self.onKnob) == Self.onKnob)
    }

    // MARK: 事件 → 状态 / Event-to-state table

    @Test("事件表：待命 →(滑到底) 执行 →(返回) 回位 →(回位走完) 待命")
    func eventTable() {
        var core = SlideToConfirmCore()
        core.drag(Self.geometry.travel, startX: Self.onKnob, geometry: Self.geometry)
        guard case .run(let run) = core.release(Self.sample(Self.geometry.travel), geometry: Self.geometry) else {
            Issue.record("滑到底应被准入")
            return
        }
        #expect(core.phase == .executing)
        #expect(core.knobOffset(in: Self.geometry) == Self.geometry.travel)
        core.drag(10, startX: Self.onKnob, geometry: Self.geometry)
        #expect(core.knobOffset(in: Self.geometry) == Self.geometry.travel, "执行阶段拖动改了指示器位置")
        core.settle(run, outcome: .failed)
        #expect(core.phase == .returning(.failed))
        #expect(core.knobOffset(in: Self.geometry) == 0)
        core.finish(run)
        #expect(core.phase == .idle)
        #expect(core.acceptsInput)
    }

    @Test("无障碍激活作废进行中的拖动会话：开闸后继续拖、再松手也不触发")
    func activationCancelsDragSession() {
        var core = SlideToConfirmCore()
        core.drag(80, startX: Self.onKnob, geometry: Self.geometry)
        guard let run = core.activate() else {
            Issue.record("激活应被准入")
            return
        }
        core.settle(run, outcome: .succeeded)
        core.finish(run)
        #expect(core.knobOffset(in: Self.geometry) == 0, "激活前的拖动位移在运行结束后残留了")
        core.drag(Self.geometry.travel, startX: Self.onKnob, geometry: Self.geometry)
        #expect(core.knobOffset(in: Self.geometry) == 0, "被激活作废的会话在开闸后推动了指示器")
        let release = core.release(Self.sample(Self.geometry.travel), geometry: Self.geometry)
        #expect(release == .ignored, "被激活作废的会话在开闸后松手实得 \(release) —— 排队式二次执行")
    }

    @Test("回弹 / 打断 / 阶段变化都改变动效键；拖动变化不改——跟手位移不补间")
    func motionKeyChangesOnlyOnDiscreteEvents() {
        var core = SlideToConfirmCore()
        let start = core.motionKey
        core.drag(50, startX: Self.onKnob, geometry: Self.geometry)
        core.drag(90, startX: Self.onKnob, geometry: Self.geometry)
        #expect(core.motionKey == start, "拖动变化改了动效键 ⇒ 跟手位移会被补间")
        _ = core.release(Self.sample(90), geometry: Self.geometry)
        let afterRebound = core.motionKey
        #expect(afterRebound != start, "回弹没改动效键 ⇒ 回弹不补间")
        core.drag(60, startX: Self.onKnob, geometry: Self.geometry)
        core.interrupt()
        #expect(core.motionKey != afterRebound, "打断没改动效键 ⇒ 打断后的回位不补间")
        let beforeRun = core.motionKey
        guard let run = core.activate() else { return }
        let executing = core.motionKey
        #expect(executing != beforeRun)
        core.settle(run, outcome: .succeeded)
        #expect(core.motionKey != executing, "进入回位没改动效键 ⇒ 回位不补间")
    }

    // 源码接线判据只能核「用的是 reveal」；这里核 reveal 本身是 bounce 为 0 的弹簧。
    @Test("回弹 / 回位的位移曲线是 bounce 为 0 的弹簧")
    func displacementCurveHasNoBounce() {
        let curve = CoreMotionToken.reveal.transformAnimation(for: .animated)
        #expect(curve == Animation.spring(duration: CoreMotionToken.reveal.duration, bounce: 0), "实得 \(String(describing: curve))")
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

    @Test("替代 Button 的操作提示：注册进 Localizable.strings，读出来不是「Slide…」")
    func accessibilityHintIsRegistered() {
        let resolved = Bundle.module.localizedString(forKey: "Double-tap to confirm", value: "__MISSING__", table: nil)
        #expect(resolved == "Double-tap to confirm", "键未注册或取值不对：\(resolved)")
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

    // MARK: 外观 / Appearance

    // 玻璃在离屏位图里一个像素都不画、流光的在屏状态在单测里没有滚动容器可驱动，这几处只能在源码层核。
    @Test("外观接线：轨道玻璃、流光开关与在屏状态、指示器浅色岛与 coreAccent 取色、文案留白、禁用不透明度")
    func appearanceWiring() {
        let url = GuardScanRoots.sourcesURL(of: GuardScanRoots.primaryTargetName)
            .appendingPathComponent("Components/SlideToConfirm/SlideToConfirm.swift")
        guard let source = try? String(contentsOf: url, encoding: .utf8) else {
            Issue.record(Comment(rawValue: "读不到 SlideToConfirm 源码：\(url.path)"))
            return
        }
        let required = [
            """
                ZStack(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(Color.secondaryFill)
                        .glassEffect(.regular, in: Capsule(style: .continuous))
            """,
            """
                let sweeps = SlideToConfirmShimmer.sweeps(
                    presentation: energy.presentation(reduceMotion: self.reduceMotion),
                    isEnabled: self.isEnabled,
                    phase: core.phase,
                    isOnScreen: self.titleOnScreen
                )
            """,
            "private var reduceMotion: Bool { self.motionPresentation != .animated }",
            """
                if sweeps {
                    TimelineView(.animation(minimumInterval: energy.minimumInterval)) { context in
                        self.titleText(bandCenter: SlideToConfirmShimmer.bandCenter(
                            progress: SlideToConfirmShimmer.progress(at: context.date),
                            layoutDirection: self.layoutDirection
                        ))
                    }
                } else {
                    self.titleText(bandCenter: nil)
                }
            """,
            ".padding(.leading, geometry.titleLeadingInset)",
            ".padding(.trailing, geometry.titleTrailingInset)",
            ".onAppear { self.titleOnScreen = true }",
            ".onDisappear { self.titleOnScreen = false }",
            ".onScrollVisibilityChange { self.titleOnScreen = $0 }",
            ".foregroundStyle(SlideToConfirmShimmer.style(bandCenter: bandCenter))",
            ".opacity(geometry.titleOpacity(forOffset: offset))",
            "let glyph = SlideToConfirmAppearance.glyph(accent: self.resolvedAccent)",
            ".tint(glyph)",
            ".foregroundStyle(glyph)",
            ".environment(\\.colorScheme, SlideToConfirmAppearance.knobScheme)",
            ".coreShadow(SlideToConfirmAppearance.knobElevation)",
            ".opacity(SlideToConfirmAppearance.opacity(isEnabled: self.isEnabled))",
        ]
        func squash(_ text: String) -> String { text.split(whereSeparator: \.isWhitespace).joined(separator: " ") }
        let flat = squash(source)
        let missing = required.filter { !flat.contains(squash($0)) }
        #expect(missing.isEmpty, "外观接线缺 \(missing.count) 处，期望 0：\(missing)")
        #expect(squash(source).components(separatedBy: "TimelineView(").count == 2, "TimelineView 不止一处 —— 流光可能绕过了开关")
    }

    @Test("文案区域在待命指示器之后：各档尺寸、各种宽度下都不重叠，宽度即全程减两侧留白")
    func titleRegionClearsTheKnob() {
        var overlaps: [String] = []
        for size in ControlSize.allCases {
            for width in [0, 30, 120, 320, 800] as [CGFloat] {
                let g = SlideToConfirmGeometry.standard(width: width, controlSize: size, layoutDirection: .leftToRight)
                if g.titleRegion.lowerBound < g.idleKnobRegion.upperBound + g.spacing {
                    overlaps.append("\(size) × \(width)：文案起点 \(g.titleRegion.lowerBound)，指示器止于 \(g.idleKnobRegion.upperBound)")
                }
                if g.travel > 2 * g.spacing, g.titleRegion.upperBound - g.titleRegion.lowerBound != g.travel - 2 * g.spacing {
                    overlaps.append("\(size) × \(width)：文案宽 \(g.titleRegion.upperBound - g.titleRegion.lowerBound) ≠ 全程 − 2×间距")
                }
            }
        }
        #expect(overlaps.isEmpty, "\(overlaps)")
    }

    @Test("执行阶段文案隐去、回位阶段文案回到不透明")
    func titleHiddenWhileExecuting() {
        var core = SlideToConfirmCore()
        guard let run = core.activate() else {
            Issue.record("首次激活应被准入")
            return
        }
        #expect(Self.geometry.titleOpacity(forOffset: core.knobOffset(in: Self.geometry)) == 0, "执行阶段文案仍可见")
        core.settle(run, outcome: .succeeded)
        #expect(Self.geometry.titleOpacity(forOffset: core.knobOffset(in: Self.geometry)) == 1)
    }

    @Test("流光只在「能耗闸 + Reduce Motion 裁出 animated、启用、待命、在屏」同时成立时扫，任一条不满足就关")
    func shimmerSweepsOnlyWhenEverythingAllows() {
        typealias S = SlideToConfirmShimmer
        func gate(_ phase: ScenePhase, lowPower: Bool, reduceMotion: Bool) -> MotionPresentation {
            EnergyState(scenePhase: phase, isLowPower: lowPower).presentation(reduceMotion: reduceMotion)
        }
        #expect(S.sweeps(presentation: gate(.active, lowPower: false, reduceMotion: false), isEnabled: true, phase: .idle, isOnScreen: true))
        #expect(S.sweeps(presentation: gate(.active, lowPower: true, reduceMotion: false), isEnabled: true, phase: .idle, isOnScreen: true), "低电量只降帧，不该停")
        let animated = gate(.active, lowPower: false, reduceMotion: false)
        let off: [(String, Bool)] = [
            ("Reduce Motion", S.sweeps(presentation: gate(.active, lowPower: false, reduceMotion: true), isEnabled: true, phase: .idle, isOnScreen: true)),
            ("场景不活跃", S.sweeps(presentation: gate(.inactive, lowPower: false, reduceMotion: false), isEnabled: true, phase: .idle, isOnScreen: true)),
            ("场景在后台", S.sweeps(presentation: gate(.background, lowPower: false, reduceMotion: false), isEnabled: true, phase: .idle, isOnScreen: true)),
            ("禁用", S.sweeps(presentation: animated, isEnabled: false, phase: .idle, isOnScreen: true)),
            ("执行", S.sweeps(presentation: animated, isEnabled: true, phase: .executing, isOnScreen: true)),
            ("回位（成功）", S.sweeps(presentation: animated, isEnabled: true, phase: .returning(.succeeded), isOnScreen: true)),
            ("回位（失败）", S.sweeps(presentation: animated, isEnabled: true, phase: .returning(.failed), isOnScreen: true)),
            ("离屏", S.sweeps(presentation: animated, isEnabled: true, phase: .idle, isOnScreen: false)),
        ]
        #expect(off.filter(\.1).isEmpty, "这些情形下流光仍在扫：\(off.filter(\.1).map(\.0))")
    }

    @Test("流光进度随时间线性、按周期回绕；高光带从一端外侧进、另一端外侧出，RTL 反向")
    func shimmerProgressAndDirection() {
        typealias S = SlideToConfirmShimmer
        let base = Date(timeIntervalSinceReferenceDate: S.period * 1000)
        for k in 0..<4 {
            let p = S.progress(at: base.addingTimeInterval(S.period * Double(k) / 4))
            #expect(abs(p - CGFloat(k) / 4) < 1e-6, "第 \(k)/4 周期进度实得 \(p)")
        }
        #expect(abs(S.progress(at: base.addingTimeInterval(S.period)) - 0) < 1e-6, "一个周期后没有回绕")
        #expect(S.bandCenter(progress: 0, layoutDirection: .leftToRight) + S.bandWidth / 2 <= 0, "LTR 起点高光带没完全在文案外侧")
        #expect(S.bandCenter(progress: 1, layoutDirection: .leftToRight) - S.bandWidth / 2 >= 1, "LTR 终点高光带没完全离开文案")
        let ltr = stride(from: 0, through: 1, by: 0.125).map { S.bandCenter(progress: $0, layoutDirection: .leftToRight) }
        let rtl = stride(from: 0, through: 1, by: 0.125).map { S.bandCenter(progress: $0, layoutDirection: .rightToLeft) }
        #expect(zip(ltr, ltr.dropFirst()).allSatisfy { $0 < $1 }, "LTR 高光带不是从左往右：\(ltr)")
        #expect(zip(rtl, rtl.dropFirst()).allSatisfy { $0 > $1 }, "RTL 高光带不是从右往左：\(rtl)")
    }

    // SwiftUI 不按布局方向镜像渐变的 UnitPoint（macOS 实测），方向只能由 bandCenter 换算——这里在真实渲染里核两者合起来的结果。
    @Test("流光方向随布局方向：同一进度下 LTR 高光在文案左半、RTL 在右半")
    func shimmerDirectionRendersWithLayoutDirection() {
        func highlightCentroid(_ direction: LayoutDirection) -> CGFloat? {
            let center = SlideToConfirmShimmer.bandCenter(progress: 0.35, layoutDirection: direction)
            let window = HostedWindow(
                Text(verbatim: "Slide to delete account now")
                    .font(.title)
                    .foregroundStyle(SlideToConfirmShimmer.style(bandCenter: center))
                    .environment(\.layoutDirection, direction),
                size: CGSize(width: 320, height: 60),
                scheme: .dark
            )
            defer { window.close() }
            let pixels = window.pixels()
            guard let bytes = pixels.bytes else { return nil }
            var sum = 0, count = 0
            for y in 0..<pixels.height {
                for x in 0..<pixels.width {
                    let i = (y * pixels.width + x) * 4
                    if bytes[i] > 215, bytes[i + 1] > 215, bytes[i + 2] > 215 { sum += x; count += 1 }
                }
            }
            return count > 20 ? CGFloat(sum) / CGFloat(count) / CGFloat(pixels.width) : nil
        }
        let ltr = highlightCentroid(.leftToRight)
        let rtl = highlightCentroid(.rightToLeft)
        #expect(ltr.map { $0 < 0.5 } == true, "LTR 高光质心在 \(String(describing: ltr))，应在左半")
        #expect(rtl.map { $0 > 0.5 } == true, "RTL 高光质心在 \(String(describing: rtl))，应在右半")
    }

    // iOS 单测宿主里动效开时拍到的两帧也相同（实测），流光推进只能在 macOS 腿观测。
    #if os(macOS)
    @Test("流光在时间上真的在走：动效开时两帧文案不同；RM / 禁用时两帧在噪声以内相同")
    func shimmerAdvancesOnlyWhenAllowed() {
        func frames(_ presentation: MotionPresentation, disabled: Bool) -> (HostedPixels, HostedPixels) {
            let window = HostedWindow(
                SlideHarness(runner: SlideToConfirmRunner { _ in })
                    .disabled(disabled)
                    .environment(\.coreMotionPresentationOverride, presentation)
                    .environment(\.scenePhaseOverride, .active),
                size: CGSize(width: 320, height: 60),
                scheme: .dark
            )
            defer { window.close() }
            let first = window.pixels()
            for _ in 0..<(Int(SlideToConfirmShimmer.period * 0.3 / 0.03)) {
                window.settle()
                if bitmapMaxChannelDelta(first.bytes, window.pixels().bytes).map({ $0 > 8 }) == true { break }
            }
            return (first, window.pixels())
        }
        let animated = frames(.animated, disabled: false)
        expectBitmapsDiffer(animated.0.bytes, animated.1.bytes, "动效开、场景活跃时流光没有推进")
        let resting = frames(.resting, disabled: false)
        expectBitmapsEquivalent(resting.0.bytes, resting.1.bytes, maxChannelDelta: 2, "Reduce Motion 下流光仍在走")
        let disabled = frames(.animated, disabled: true)
        expectBitmapsEquivalent(disabled.0.bytes, disabled.1.bytes, maxChannelDelta: 2, "禁用时流光仍在走")
    }
    #endif

    @Test("指示器是浅色岛：surfaceRaised 与墨色在浅色外观下对比 ≥ 7:1，禁用降不透明度")
    func knobIsALightIsland() {
        var environment = EnvironmentValues()
        environment.colorScheme = SlideToConfirmAppearance.knobScheme
        let ink = Color.contrastRatio(Color.surfaceRaised, Color.inkPrimary, in: environment)
        let white = Color.contrastRatio(Color.surfaceRaised, Color.white, in: environment)
        #expect(ink >= 7, "指示器底与墨色箭头对比 \(ink):1")
        #expect(white < 1.1, "指示器底在浅色岛里不是近白：与纯白对比 \(white):1")
        #expect(SlideToConfirmAppearance.opacity(isEnabled: true) == 1)
        #expect(SlideToConfirmAppearance.opacity(isEnabled: false) < 1)
    }

    @Test("箭头 / 进度取色：宿主强调色在浅色岛上对比不足 3:1 时退回墨色（.yellow / .white / .mint），够的不退（.blue / .red / 默认墨色）")
    func glyphFallsBackToInkWhenAccentIsIllegible() {
        var environment = EnvironmentValues()
        environment.colorScheme = SlideToConfirmAppearance.knobScheme
        for accent in [Color.yellow, .white, .mint] {
            let ratio = Color.contrastRatio(accent, .surfaceRaised, in: environment)
            #expect(ratio < 3, "\(accent) 在浅色岛上对比 \(ratio):1，本应不足 3:1 —— 样本失效")
            #expect(SlideToConfirmAppearance.glyph(accent: accent) == Color.inkPrimary, "\(accent)（对比 \(ratio):1）没有退回墨色")
        }
        for accent in [Color.blue, .red, .inkPrimary] {
            let ratio = Color.contrastRatio(accent, .surfaceRaised, in: environment)
            #expect(ratio >= 3, "\(accent) 在浅色岛上对比 \(ratio):1，本应 ≥ 3:1 —— 样本失效")
            #expect(SlideToConfirmAppearance.glyph(accent: accent) == accent, "\(accent)（对比 \(ratio):1）被错误地换掉了")
        }
    }

    @Test("箭头跟随 coreAccent：深色外观下 .red / .blue 的指示器区各自偏红 / 偏蓝，默认墨色与 .yellow（退回墨色）的箭头在白底上是深色；指示器之外相同")
    func arrowFollowsCoreAccent() {
        struct Tally { var red = 0, blue = 0, dark = 0 }
        func render(_ accent: Color?) -> HostedPixels {
            let harness = SlideHarness(runner: SlideToConfirmRunner { _ in })
            let window = HostedWindow(
                Group {
                    if let accent { harness.coreAccent(accent) } else { harness }
                }
                .environment(\.coreMotionPresentationOverride, .resting),
                size: CGSize(width: 320, height: 60),
                scheme: .dark
            )
            defer { window.close() }
            return window.pixels()
        }
        let knobEnd = Self.geometry.idleKnobRegion.upperBound
        // 深色像素只数四个方向 14 pt 内都碰得到白色的——即被白色圆盘包住的箭头；圆盘外接方框四角的深色画布不算。
        func tally(_ pixels: HostedPixels) -> Tally {
            var t = Tally()
            guard let bytes = pixels.bytes, slideKnobLeadingEdge(pixels) != nil else { return t }
            let limit = min(pixels.width, Int(knobEnd * pixels.scale))
            let reach = Int((14 * pixels.scale).rounded())
            func white(_ x: Int, _ y: Int) -> Bool {
                guard x >= 0, x < pixels.width, y >= 0, y < pixels.height else { return false }
                let i = (y * pixels.width + x) * 4
                return bytes[i] > 235 && bytes[i + 1] > 235 && bytes[i + 2] > 235
            }
            func enclosed(_ x: Int, _ y: Int) -> Bool {
                (1...reach).contains { white(x - $0, y) } && (1...reach).contains { white(x + $0, y) }
                    && (1...reach).contains { white(x, y - $0) } && (1...reach).contains { white(x, y + $0) }
            }
            for y in 0..<pixels.height {
                for x in 0..<limit {
                    let i = (y * pixels.width + x) * 4
                    let r = Int(bytes[i]), g = Int(bytes[i + 1]), b = Int(bytes[i + 2])
                    if r - max(g, b) > 80 { t.red += 1 }
                    if b - max(r, g) > 80 { t.blue += 1 }
                    if bytes[i + 3] > 200, r < 60, g < 60, b < 60, enclosed(x, y) { t.dark += 1 }
                }
            }
            return t
        }
        let red = render(.red), blue = render(.blue), ink = render(nil), yellow = render(.yellow)
        let tr = tally(red), tb = tally(blue), ti = tally(ink), ty = tally(yellow)
        #expect(tr.red > 20 && tr.blue == 0, ".red 下指示器区红 \(tr.red) / 蓝 \(tr.blue)")
        #expect(tb.blue > 20 && tb.red == 0, ".blue 下指示器区蓝 \(tb.blue) / 红 \(tb.red)")
        #expect(ti.dark > 20, "默认墨色下白底指示器里的深色箭头像素只有 \(ti.dark) —— 箭头没按浅色岛解析（深色外观下成了白箭头）")
        #expect(ty.dark > 20, ".yellow 下白底指示器里的深色箭头像素只有 \(ty.dark) —— 对比不足的强调色没有退回墨色")
        func outsideKnob(_ p: HostedPixels) -> [UInt8]? {
            guard let bytes = p.bytes else { return nil }
            let start = Int(knobEnd * p.scale) + 2
            return (0..<p.height).flatMap { y in bytes[((y * p.width + start) * 4)..<((y + 1) * p.width * 4)] }
        }
        expectBitmapsEquivalent(outsideKnob(red), outsideKnob(blue), maxChannelDelta: 2, "coreAccent 改动了指示器之外的像素")
    }

    // MARK: 渲染 / Rendering

    @Test("执行阶段指示器停在尽头：待命与执行两帧的指示器前沿相差约一个全程")
    func executingKnobSitsAtTheEnd() async throws {
        let runner = SlideToConfirmRunner { _ in }
        let window = HostedWindow(
            SlideHarness(runner: runner).environment(\.coreMotionPresentationOverride, .resting),
            size: CGSize(width: 320, height: 60),
            scheme: .dark
        )
        defer { window.close() }
        let idle = try #require(slideKnobLeadingEdge(window.pixels()), "待命帧里找不到指示器")

        let again = HostedWindow(
            SlideHarness(runner: SlideToConfirmRunner { _ in }).environment(\.coreMotionPresentationOverride, .resting),
            size: CGSize(width: 320, height: 60),
            scheme: .dark
        )
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

    @Test("RTL 渲染：待命指示器在右端，执行阶段向左移约一个全程")
    func rightToLeftKnobStartsAtTheRight() async throws {
        let runner = SlideToConfirmRunner { _ in }
        let window = HostedWindow(
            SlideHarness(runner: runner)
                .environment(\.layoutDirection, .rightToLeft)
                .environment(\.coreMotionPresentationOverride, .resting),
            size: CGSize(width: 320, height: 60),
            scheme: .dark
        )
        defer { window.close() }
        let scale = window.pixels().scale
        let idle = try #require(slideKnobLeadingEdge(window.pixels()), "待命帧里找不到指示器")
        #expect(CGFloat(idle) / scale > 160, "RTL 下待命指示器前沿在 \(CGFloat(idle) / scale) pt，应在右半边")

        let action = StatefulSuspension(.cooperative)
        runner.activate(presentation: .resting, action: { try await action.suspend() })
        try #require(await action.waitForArrivals(1))
        window.settle()
        let executing = try #require(slideKnobLeadingEdge(window.pixels()), "执行帧里找不到指示器")
        let moved = CGFloat(executing - idle) / scale
        #expect(abs(moved + Self.geometry.travel) <= 2, "RTL 下指示器前沿移动 \(moved) pt，期望约 \(-Self.geometry.travel)")
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

// 深色外观下找白色指示器：取「横向与纵向都连续近白 ≥ 14 pt」的像素里最小的横坐标（像素）。
// 两个方向都要求：文案流光的白色字形横向不够长，玻璃高光边纵向不够厚，只有实心圆盘两者都满足。
// 不取中线：iOS 宿主带顶部安全区，内容整体下移，中线穿不过指示器。
nonisolated func slideKnobLeadingEdge(_ pixels: HostedPixels) -> Int? {
    guard let bytes = pixels.bytes, pixels.width > 0 else { return nil }
    let run = Int((14 * pixels.scale).rounded())
    func white(_ x: Int, _ y: Int) -> Bool {
        guard x >= 0, x < pixels.width, y >= 0, y < pixels.height else { return false }
        let i = (y * pixels.width + x) * 4
        return bytes[i + 3] > 200 && bytes[i] > 235 && bytes[i + 1] > 235 && bytes[i + 2] > 235
    }
    func verticalRun(_ x: Int, through y: Int) -> Int {
        var top = y, bottom = y
        while white(x, top - 1) { top -= 1 }
        while white(x, bottom + 1) { bottom += 1 }
        return bottom - top + 1
    }
    var leading: Int?
    for y in 0..<pixels.height {
        var x = 0
        while x < (leading ?? pixels.width) {
            guard white(x, y) else { x += 1; continue }
            var end = x
            while white(end + 1, y) { end += 1 }
            if end - x + 1 >= run, verticalRun(x + run / 2, through: y) >= run {
                leading = x
                break
            }
            x = end + 1
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

    struct Trace {
        var intermediate: Int
        var overshoot: Int
        var moved: Bool
        var detail: String
    }

    // 一次 settle 约 0.24 s，追不完 reveal 弹簧的尾巴：起点读早了，后续朝尽头的残余位移会被记成越界。
    static func settledEdge(_ window: HostedWindow) -> Int? {
        window.settle()
        var previous = slideKnobLeadingEdge(window.pixels())
        for _ in 0..<10 {
            window.settle()
            let next = slideKnobLeadingEdge(window.pixels())
            if next == previous { return next }
            previous = next
        }
        return nil
    }

    static func trace(_ scenario: Scenario, presentation: MotionPresentation, sampleFor duration: TimeInterval) async -> Trace {
        let runner = SlideToConfirmRunner { _ in }
        let window = HostedWindow(
            SlideHarness(runner: runner).environment(\.coreMotionPresentationOverride, presentation),
            size: CGSize(width: 320, height: 60),
            scheme: .dark
        )
        defer { window.close() }
        let geometry = SlideToConfirmTests.geometry
        let action = StatefulSuspension(.cooperative)
        switch scenario {
        case .rebound:
            runner.dragChanged(geometry.travel * 0.7, startX: SlideToConfirmTests.onKnob, geometry: geometry)
        case .returning:
            runner.activate(presentation: presentation, action: { try await action.suspend() })
            _ = await action.waitForArrivals(1)
        }
        let before = Self.settledEdge(window)

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
        let after = Self.settledEdge(window)
        await runner.task?.value
        guard let before, let after else {
            return Trace(intermediate: -1, overshoot: -1, moved: false, detail: "before=\(String(describing: before)) after=\(String(describing: after))（前沿未稳定或找不到指示器）")
        }
        let low = min(before, after), high = max(before, after)
        let seen = edges.compactMap { $0 }
        let intermediate = Set(seen.filter { $0 > low + 1 && $0 < high - 1 }).count
        let outside = seen.filter { $0 < low - 1 || $0 > high + 1 }
        return Trace(
            intermediate: intermediate,
            overshoot: outside.count,
            moved: abs(before - after) > 10,
            detail: "before=\(before) after=\(after) 越界帧=\(outside)"
        )
    }

    @Test("未达阈值松手的回弹：RM 关时途经中间位置且不越过起点，RM 开时直接到位")
    func reboundInFlight() async {
        let resting = await Self.trace(.rebound, presentation: .resting, sampleFor: 0.4)
        #expect(resting.moved, "指示器没有回到起点，判据无效")
        #expect(resting.intermediate == 0, "RM 开时回弹途经了 \(resting.intermediate) 个中间位置，期望 0（位移类动效须走 transformAnimation(for:)）")
        var overshoot = 0
        var detail = ""
        for window in CoreMotionTokenInFlightTests.samplingWindows {
            let animated = await Self.trace(.rebound, presentation: .animated, sampleFor: window)
            if animated.overshoot != 0 { detail += "[\(animated.detail)] " }
            overshoot = max(overshoot, animated.overshoot)
            if animated.moved, animated.intermediate >= 2 { break }
            if window == CoreMotionTokenInFlightTests.samplingWindows.last {
                Issue.record("回弹：RM 关时 \(CoreMotionTokenInFlightTests.samplingWindows.count) 个窗口里互异中间位置都不足 2 个（最后一次 \(animated.intermediate)）—— 无法下结论，不是通过")
            }
        }
        #expect(overshoot == 0, "回弹有 \(overshoot) 帧越出起止区间（过冲）：\(detail)")
    }

    @Test("执行后回位：RM 关时途经中间位置且不越过起点，RM 开时直接到位")
    func returnInFlight() async {
        let resting = await Self.trace(.returning, presentation: .resting, sampleFor: 0.4)
        #expect(resting.moved, "指示器没有回到起点，判据无效")
        #expect(resting.intermediate == 0, "RM 开时回位途经了 \(resting.intermediate) 个中间位置，期望 0")
        var overshoot = 0
        var detail = ""
        for window in CoreMotionTokenInFlightTests.samplingWindows {
            let animated = await Self.trace(.returning, presentation: .animated, sampleFor: window)
            if animated.overshoot != 0 { detail += "[\(animated.detail)] " }
            overshoot = max(overshoot, animated.overshoot)
            if animated.moved, animated.intermediate >= 2 { break }
            if window == CoreMotionTokenInFlightTests.samplingWindows.last {
                Issue.record("回位：RM 关时 \(CoreMotionTokenInFlightTests.samplingWindows.count) 个窗口里互异中间位置都不足 2 个（最后一次 \(animated.intermediate)）—— 无法下结论，不是通过")
            }
        }
        #expect(overshoot == 0, "回位有 \(overshoot) 帧越出起止区间（过冲）：\(detail)")
    }
}

#endif
