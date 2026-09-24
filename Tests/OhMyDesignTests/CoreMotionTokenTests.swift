import SwiftUI
import Testing
@testable import OhMyDesign

// MARK: - CoreMotionToken token（#407 FR-2）

@Suite("CoreMotionToken 动效 token")
struct CoreMotionTokenTests {
    @Test("四档 token 的时长与曲线")
    func tokenValues() {
        #expect(CoreMotionToken.allCases == [.press, .selection, .reveal, .scroll])
        #expect(CoreMotionToken.press.duration == 0.16)
        #expect(CoreMotionToken.selection.duration == 0.22)
        #expect(CoreMotionToken.reveal.duration == 0.25)
        #expect(CoreMotionToken.scroll.duration == 0.35)
        #expect(CoreMotionToken.press.animation == .snappy(duration: 0.16))
        #expect(CoreMotionToken.selection.animation == .snappy(duration: 0.22))
        #expect(CoreMotionToken.reveal.animation == .smooth(duration: 0.25))
        #expect(CoreMotionToken.scroll.animation == .smooth(duration: 0.35))
    }

    @Test("时长按 press < selection < reveal < scroll 严格递增")
    func durationsAreOrdered() {
        let durations = CoreMotionToken.allCases.map(\.duration)
        #expect(durations == durations.sorted())
        #expect(Set(durations).count == durations.count)
    }

    @Test("animated ⇒ token 本身")
    func animatedReturnsToken() {
        for motion in CoreMotionToken.allCases {
            #expect(motion.animation(for: .animated) == motion.animation)
        }
    }

    @Test("resting ⇒ 淡变类退为同时长 easeInOut，scroll 退为 nil（直接到位）")
    func restingDropsMotion() {
        for motion in [CoreMotionToken.press, .selection, .reveal] {
            #expect(motion.animation(for: .resting) == .easeInOut(duration: motion.duration))
            #expect(motion.animation(for: .resting) != motion.animation)
        }
        #expect(CoreMotionToken.scroll.animation(for: .resting) == nil)
    }

    @Test("hidden ⇒ 一律不补间")
    func hiddenIsInstant() {
        for motion in CoreMotionToken.allCases {
            #expect(motion.animation(for: .hidden) == nil)
        }
    }

    @Test("coreMotionPresentation 只由 accessibilityReduceMotion 推出")
    func environmentPresentationFollowsReduceMotion() {
        var environment = EnvironmentValues()
        #expect(environment.coreMotionPresentation == .animated)
        environment._accessibilityReduceMotion = true
        #expect(environment.accessibilityReduceMotion)
        #expect(environment.coreMotionPresentation == .resting)
        environment._accessibilityReduceMotion = false
        #expect(environment.coreMotionPresentation == .animated)
    }

    @Test("coreMotionPresentation 不受能耗注入影响：一次性动效不走能耗闸")
    func environmentPresentationIgnoresEnergy() {
        var environment = EnvironmentValues()
        environment.lowPowerModeOverride = true
        environment.scenePhaseOverride = .background
        #expect(environment.coreMotionPresentation == .animated)
    }
}

// MARK: - 渲染：RM 注入能到达组件（#407 FR-3）

@MainActor
private func pixels(_ content: some View) -> [UInt8]? {
    let renderer = ImageRenderer(content: content)
    renderer.scale = 1
    guard let image = renderer.cgImage, image.width > 0, image.height > 0 else { return nil }
    var buffer = [UInt8](repeating: 0, count: image.width * image.height * 4)
    guard let context = CGContext(
        data: &buffer,
        width: image.width,
        height: image.height,
        bitsPerComponent: 8,
        bytesPerRow: image.width * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }
    context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    return buffer
}

private func coverage(_ bytes: [UInt8]) -> (covered: Int, meanAlpha: Double) {
    var covered = 0
    var total = 0.0
    for index in stride(from: 3, to: bytes.count, by: 4) where bytes[index] > 0 {
        covered += 1
        total += Double(bytes[index])
    }
    return (covered, covered > 0 ? total / Double(covered) : 0)
}

@Suite("Reduce Motion 在核心库的降级（渲染）")
@MainActor
struct CoreMotionTokenReduceMotionRenderTests {
    private func pressedChrome(reduceMotion: Bool) -> some View {
        Color.clear
            .frame(width: 80, height: 40)
            .buttonBackground(shape: Rectangle(), fill: .red, border: .clear, isPressed: true)
            .frame(width: 100, height: 60)
            .environment(\.coreMotionPresentationOverride, reduceMotion ? .resting : .animated)
    }

    @Test("按钮背景按下：RM 关缩放、RM 开不缩放只变暗")
    func buttonBackgroundPressDegrades() throws {
        let moving = coverage(try #require(pixels(self.pressedChrome(reduceMotion: false))))
        let reduced = coverage(try #require(pixels(self.pressedChrome(reduceMotion: true))))
        let idle = coverage(try #require(pixels(
            Color.clear.frame(width: 80, height: 40)
                .buttonBackground(shape: Rectangle(), fill: .red, border: .clear, isPressed: false)
                .frame(width: 100, height: 60)
        )))
        #expect(moving.covered < idle.covered, "RM 关时按下应缩小：\(moving) vs \(idle)")
        #expect(reduced.covered == idle.covered, "RM 开时按下不得缩放：\(reduced) vs \(idle)")
        #expect(reduced.meanAlpha < idle.meanAlpha - 30, "RM 开时按下应变暗：\(reduced) vs \(idle)")
    }

    private func pressedGlass(reduceMotion: Bool, feedback: Bool = true) -> some View {
        Color.red
            .frame(width: 80, height: 40)
            .modifier(TelegramGlassButtonModifier(shape: Rectangle(), isPressed: true, border: .clear, pressFeedback: feedback))
            .frame(width: 100, height: 60)
            .environment(\.coreMotionPresentationOverride, reduceMotion ? .resting : .animated)
    }

    @Test("Telegram 玻璃按钮按下：RM 开不缩放只变暗；关掉按压反馈时两者都没有")
    func telegramGlassPressDegrades() throws {
        let moving = coverage(try #require(pixels(self.pressedGlass(reduceMotion: false))))
        let reduced = coverage(try #require(pixels(self.pressedGlass(reduceMotion: true))))
        let silent = coverage(try #require(pixels(self.pressedGlass(reduceMotion: true, feedback: false))))
        #expect(moving.covered < silent.covered, "RM 关时按下应缩小：\(moving) vs \(silent)")
        #expect(reduced.covered == silent.covered, "RM 开时按下不得缩放：\(reduced) vs \(silent)")
        #expect(reduced.meanAlpha < silent.meanAlpha - 30, "RM 开时按下应变暗：\(reduced) vs \(silent)")
    }
}

// MARK: - 各降级点的真值表（#407 FR-3）

@Suite("Reduce Motion 降级点真值表")
@MainActor
struct CoreMotionTokenDegradationTableTests {
    @Test("按钮 chrome：animated 缩放并保留调用方透明度；resting 不缩放、至多 0.7")
    func chromeFeedback() {
        #expect(PressFeedback.chrome(isPressed: false, pressedOpacity: 0.5, presentation: .resting) == .idle)
        let moving = PressFeedback.chrome(isPressed: true, pressedOpacity: nil, presentation: .animated)
        #expect(moving.scale == CoreButtonMetrics.pressedScale)
        #expect(moving.opacity == 1)
        let reduced = PressFeedback.chrome(isPressed: true, pressedOpacity: nil, presentation: .resting)
        #expect(reduced.scale == 1)
        #expect(reduced.opacity == PressFeedback.reducedMotionPressedOpacity)
        let reducedDimmer = PressFeedback.chrome(isPressed: true, pressedOpacity: 0.5, presentation: .resting)
        #expect(reducedDimmer.opacity == 0.5, "调用方给的按下透明度更暗时保留它")
        #expect(PressFeedback.chrome(isPressed: true, pressedOpacity: nil, presentation: .hidden).scale == 1)
    }

    @Test("按下透明度不叠乘：Light / Toast 操作按钮 / 圆形玻璃按钮的最终值（含禁用）")
    func pressedOpacityIsNotStacked() {
        let light = { (presentation: MotionPresentation) in
            PressFeedback.chrome(isPressed: true, pressedOpacity: LightButtonStyle.pressedOpacity, presentation: presentation).opacity
        }
        #expect(light(.animated) == 0.9)
        #expect(light(.resting) == PressFeedback.reducedMotionPressedOpacity, "RM 下是 0.7，不是 0.9 × 0.7")

        func circular(isEnabled: Bool, isPressed: Bool, _ presentation: MotionPresentation) -> Double {
            CircularGlassButtonStyle.outerOpacity(isEnabled: isEnabled, isPressed: isPressed, presentation: presentation)
                * PressFeedback.chrome(isPressed: isPressed, pressedOpacity: nil, presentation: presentation).opacity
        }
        #expect(circular(isEnabled: true, isPressed: false, .animated) == 1)
        #expect(circular(isEnabled: true, isPressed: true, .animated) == 0.9)
        #expect(circular(isEnabled: true, isPressed: true, .resting) == PressFeedback.reducedMotionPressedOpacity,
                "RM 下是 0.7，不是 0.9 × 0.7")
        #expect(circular(isEnabled: false, isPressed: false, .resting) == 0.4)
        #expect(circular(isEnabled: false, isPressed: true, .animated) == 0.4)
        #expect(abs(circular(isEnabled: false, isPressed: true, .resting) - 0.28) < 1e-9,
                "禁用按钮拿不到按下态；若真出现，登记值是 0.4 × 0.7")
    }

    @Test("Toast 转场：animated 按形态滑入 / 缩放，resting 一律纯淡变")
    func toastTransitionKind() {
        #expect(ToastOverlay.transitionKind(presentation: .floatingCapsule, edge: .top, motion: .animated) == .slide(.top))
        #expect(ToastOverlay.transitionKind(presentation: .fullWidthBanner, edge: .bottom, motion: .animated) == .slide(.bottom))
        #expect(ToastOverlay.transitionKind(presentation: .centeredHUD, edge: .top, motion: .animated) == .scale)
        for presentation in [ToastPresentation.floatingCapsule, .fullWidthBanner, .centeredHUD] {
            for edge in [VerticalEdge.top, .bottom] {
                #expect(ToastOverlay.transitionKind(presentation: presentation, edge: edge, motion: .resting) == .fade)
            }
        }
    }

    @Test("Toast 退场：animated 位移 60 / HUD 缩到 0.92；resting 停在松手位置、不缩放")
    func toastDismissMotion() {
        #expect(ToastView.dismissOffset(edge: .top, motion: .animated, releasedAt: -40) == -ToastDefaults.dismissSlideDistance)
        #expect(ToastView.dismissOffset(edge: .bottom, motion: .animated, releasedAt: 40) == ToastDefaults.dismissSlideDistance)
        #expect(ToastView.dismissOffset(edge: .top, motion: .resting, releasedAt: 0) == 0, "点击关闭：原地淡出")
        #expect(ToastView.dismissOffset(edge: .top, motion: .resting, releasedAt: -40) == -40, "滑动松手：停在松手位置淡出")
        #expect(ToastView.dismissOffset(edge: .bottom, motion: .resting, releasedAt: 37) == 37)
        #expect(ToastView.dismissScale(presentation: .centeredHUD, isDismissing: true, motion: .animated) == ToastDefaults.hudDismissScale)
        #expect(ToastView.dismissScale(presentation: .centeredHUD, isDismissing: true, motion: .resting) == 1)
        #expect(ToastView.dismissScale(presentation: .centeredHUD, isDismissing: false, motion: .animated) == 1)
        #expect(ToastView.dismissScale(presentation: .floatingCapsule, isDismissing: true, motion: .animated) == 1)
    }

    @Test("Toast 退场计时与 reveal 同源")
    func toastTimerFollowsToken() {
        #expect(ToastDefaults.dismissAnimationDuration == CoreMotionToken.reveal.duration)
    }

    @Test("滑动指示器：animated 各槽共用一个几何 ID（会滑），resting 各槽各自 ID（原地淡变）")
    func slidingIndicatorIdentity() {
        let a0 = MotionPresentation.animated.slidingIndicatorID("thumb", slot: 0)
        let a1 = MotionPresentation.animated.slidingIndicatorID("thumb", slot: 1)
        let r0 = MotionPresentation.resting.slidingIndicatorID("thumb", slot: 0)
        let r1 = MotionPresentation.resting.slidingIndicatorID("thumb", slot: 1)
        #expect(a0 == a1)
        #expect(r0 != r1)
        #expect(a0 != r0)
    }

    @Test("变换动画：animated 补间，resting / hidden 直接到位")
    func transformAnimation() {
        #expect(CoreMotionToken.reveal.transformAnimation(for: .animated) == CoreMotionToken.reveal.animation)
        #expect(CoreMotionToken.reveal.transformAnimation(for: .resting) == nil)
        #expect(CoreMotionToken.reveal.transformAnimation(for: .hidden) == nil)
        #expect(CoreMotionToken.selection.transformAnimation(for: .animated) == .snappy(duration: 0.22),
                "标签栏把选中项滚到中间走 selection，不走页级的 scroll")
        #expect(CoreMotionToken.selection.transformAnimation(for: .resting) == nil)
    }

    @Test("加载顶条：只有 animated 才扫动；静止位居中")
    func topBarSweeps() {
        #expect(TopBarIndicator.sweeps(for: .animated))
        #expect(!TopBarIndicator.sweeps(for: .resting))
        #expect(!TopBarIndicator.sweeps(for: .hidden))
        let track: CGFloat = 200
        let bar = track * TopBarIndicator.barWidthRatio
        let offset = TopBarIndicator.restingOffset(trackWidth: track)
        #expect(abs(offset - (track - bar - offset)) < 0.001)
    }
}

// MARK: - 静息外观不变（#407）

@Suite("静息外观：与旧实现在光栅化噪声内逐像素一致、与 RM 开关无关")
@MainActor
struct CoreMotionTokenRestingAppearanceTests {
    private func chrome(pressed: Bool, legacy: Bool, reduceMotion: Bool = false) -> some View {
        Group {
            if legacy {
                Text("OK").padding(8)
                    .modifier(LegacyButtonBackgroundModifier(shape: Capsule(), fill: .gray, border: .black, isPressed: pressed))
            } else {
                Text("OK").padding(8)
                    .buttonBackground(shape: Capsule(), fill: .gray, border: .black, isPressed: pressed)
            }
        }
        .frame(width: 80, height: 40)
        .environment(\.coreMotionPresentationOverride, reduceMotion ? .resting : .animated)
    }

    @Test("按钮背景：未按下 / 按下（RM 关）与旧实现在光栅化噪声内逐像素一致；未按下与 RM 无关")
    func buttonBackgroundMatchesLegacy() {
        // 新旧两棵视图树在抗锯齿边缘上偶发差 1 LSB（按下态缩放后边缘落在亚像素上），三处都按 ±1 比。
        expectBitmapsEquivalent(pixels(self.chrome(pressed: false, legacy: false)), pixels(self.chrome(pressed: false, legacy: true)),
                                maxChannelDelta: 1)
        expectBitmapsEquivalent(pixels(self.chrome(pressed: true, legacy: false)), pixels(self.chrome(pressed: true, legacy: true)),
                                maxChannelDelta: 1, "isPressed=true")
        expectBitmapsEquivalent(pixels(self.chrome(pressed: false, legacy: false, reduceMotion: true)),
                                pixels(self.chrome(pressed: false, legacy: true)), maxChannelDelta: 1)
        expectBitmapsDiffer(pixels(self.chrome(pressed: true, legacy: false, reduceMotion: true)),
                            pixels(self.chrome(pressed: true, legacy: true)), "RM 开时按下必须与旧实现不同，否则上面的相等是恒真的")
    }

    private func glass(pressed: Bool, feedback: Bool, legacy: Bool) -> some View {
        Group {
            if legacy {
                Text("OK").padding(8)
                    .modifier(LegacyTelegramGlassButtonModifier(shape: Capsule(), isPressed: pressed, border: nil, pressFeedback: feedback))
            } else {
                Text("OK").padding(8)
                    .modifier(TelegramGlassButtonModifier(shape: Capsule(), isPressed: pressed, pressFeedback: feedback))
            }
        }
        .frame(width: 80, height: 40)
    }

    @Test("Telegram 玻璃按钮：RM 关时四种组合与旧实现在光栅化噪声内逐像素一致")
    func telegramMatchesLegacy() {
        for pressed in [false, true] {
            for feedback in [false, true] {
                expectBitmapsEquivalent(pixels(self.glass(pressed: pressed, feedback: feedback, legacy: false)),
                                        pixels(self.glass(pressed: pressed, feedback: feedback, legacy: true)),
                                        maxChannelDelta: 1, "isPressed=\(pressed) pressFeedback=\(feedback)")
            }
        }
    }

    private func underRM<V: View>(_ view: V, _ reduceMotion: Bool) -> some View {
        view.environment(\.coreMotionPresentationOverride, reduceMotion ? .resting : .animated)
    }

    @Test("SegmentedControl / DisclosureGroup / Toast / TopBar 静息外观与 RM 无关")
    func restingAppearanceIgnoresReduceMotion() {
        let segmented = SegmentedControl(items: ["A", "B", "C"], selection: .constant("B"), title: { $0 })
            .segmentedControlStyle(.plain)
            .frame(width: 240)
        let disclosure = VStack {
            DisclosureGroup("Open", isExpanded: .constant(true)) { Text("Body") }
            DisclosureGroup("Closed", isExpanded: .constant(false)) { Text("Body") }
        }
        .disclosureGroupStyle(.core)
        .frame(width: 200)
        let toast = ToastView(
            item: ToastItem(title: "Saved", level: .success),
            edge: .top,
            presentation: .centeredHUD,
            isDismissing: false,
            onDismiss: {}
        )
        .frame(width: 240)
        let cases: [(String, AnyView)] = [
            ("SegmentedControl", AnyView(segmented)),
            ("DisclosureGroup", AnyView(disclosure)),
            ("ToastView", AnyView(toast)),
        ]
        for (name, view) in cases {
            let off = pixels(self.underRM(view, false))
            let on = pixels(self.underRM(view, true))
            #expect(off?.contains(where: { $0 != 0 }) == true, "\(name) 没画出东西，相等断言恒真")
            expectBitmapsEquivalent(off, on, maxChannelDelta: 1, "\(name)：RM 开关不应改变静息外观")
        }
        var tabBars: [HostedPixels] = []
        for reduceMotion in [false, true] {
            let window = HostedWindow(
                UnderlinedTabBar(items: ["A", "B"], selection: .constant("A"), title: { $0 })
                    .environment(\.coreMotionPresentationOverride, reduceMotion ? .resting : .animated),
                size: CGSize(width: 240, height: 60),
                scheme: .light
            )
            tabBars.append(window.pixels())
            window.close()
        }
        #expect(tabBars[0].bytes != nil)
        expectBitmapsEquivalent(tabBars[0].bytes, tabBars[1].bytes, maxChannelDelta: 1, "UnderlinedTabBar：RM 开关不应改变静息外观")
        let restingBar = TopBarIndicator(tint: .black).frame(width: 200)
        let barA = pixels(self.underRM(restingBar, true))
        let barB = pixels(self.underRM(restingBar, true))
        expectBitmapsEquivalent(barA, barB, maxChannelDelta: 1, "RM 下顶条应静止（两次渲染相同）")
    }
}

// MARK: - 注入入口（coreMotionPresentationOverride）

@MainActor
private final class OverrideBox: ObservableObject {
    @Published var value: MotionPresentation?
    var seen: [MotionPresentation] = []
}

private struct PresentationProbe: View {
    let box: OverrideBox

    @Environment(\.coreMotionPresentation) private var presentation

    var body: some View {
        self.box.seen.append(self.presentation)
        return Color.black.frame(width: 10, height: 10)
    }
}

private struct OverrideHarness: View {
    @ObservedObject var box: OverrideBox

    var body: some View {
        PresentationProbe(box: self.box)
            .environment(\.coreMotionPresentationOverride, self.box.value)
    }
}

@Suite("coreMotionPresentationOverride：注入优先，nil 跟随系统", .serialized)
@MainActor
struct CoreMotionTokenOverrideTests {
    @Test("注入值优先于 accessibilityReduceMotion；nil 回到系统值")
    func overrideTakesPrecedence() {
        var environment = EnvironmentValues()
        environment._accessibilityReduceMotion = true
        #expect(environment.coreMotionPresentationOverride == nil)
        #expect(environment.coreMotionPresentation == .resting)
        environment.coreMotionPresentationOverride = .animated
        #expect(environment.coreMotionPresentation == .animated)
        environment.coreMotionPresentationOverride = .hidden
        #expect(environment.coreMotionPresentation == .hidden)
        environment.coreMotionPresentationOverride = nil
        #expect(environment.coreMotionPresentation == .resting)
        environment._accessibilityReduceMotion = false
        environment.coreMotionPresentationOverride = .resting
        #expect(environment.coreMotionPresentation == .resting)
    }

    @Test("托管视图上现场切换注入值，再撤回到跟随系统")
    func liveSwitchAndRestore() throws {
        let box = OverrideBox()
        let window = HostedWindow(OverrideHarness(box: box), size: CGSize(width: 40, height: 40), scheme: .light)
        defer { window.close() }
        let system = try #require(box.seen.last, "探针没有被求值")
        var systemEnvironment = EnvironmentValues()
        systemEnvironment._accessibilityReduceMotion = system == .resting
        #expect(system == systemEnvironment.coreMotionPresentation)

        for (value, expected) in [(MotionPresentation.resting, MotionPresentation.resting), (.animated, .animated)] {
            box.value = value
            window.settle()
            #expect(box.seen.last == expected, "注入 \(value) 后读到 \(String(describing: box.seen.last))")
        }
        box.value = nil
        window.settle()
        #expect(box.seen.last == system, "撤回注入后应回到系统值 \(system)，读到 \(String(describing: box.seen.last))")
        #expect(Set(box.seen).isSuperset(of: [.resting, .animated]), "两个注入值都没有真的到达视图：\(box.seen)")
    }
}
