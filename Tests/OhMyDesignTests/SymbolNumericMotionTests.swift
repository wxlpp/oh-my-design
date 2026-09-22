import SwiftUI
import Testing
@testable import OhMyDesign

// MARK: - 内容过渡的降级真值表（#408 FR-4）

@Suite("符号 / 数字内容过渡：按 MotionPresentation 降级")
struct SymbolNumericContentTransitionTests {
    @Test("ContentTransition 的 Equatable 能分辨方向与 identity —— 否则下面的断言是恒真的")
    func contentTransitionEqualityIsDiscriminating() {
        #expect(ContentTransition.numericText(countsDown: false) != ContentTransition.numericText(countsDown: true))
        #expect(ContentTransition.numericText(countsDown: false) != ContentTransition.identity)
        #expect(ContentTransition.symbolEffect(.replace) != ContentTransition.identity)
        #expect(ContentTransition.symbolEffect(.replace) == ContentTransition.symbolEffect(.replace))
    }

    @Test("符号替换：animated 走 symbolEffect(.replace)，resting / hidden 直接换图")
    func symbolReplacementDegrades() {
        #expect(MotionPresentation.animated.symbolReplacement == ContentTransition.symbolEffect(.replace))
        #expect(MotionPresentation.resting.symbolReplacement == ContentTransition.identity)
        #expect(MotionPresentation.hidden.symbolReplacement == ContentTransition.identity)
    }

    @Test("数字滚动：方向由新旧值决定；resting / hidden 直接替换")
    func numericRollDirectionAndDegradation() {
        let animated = MotionPresentation.animated
        #expect(animated.numericRoll(from: 9, to: 10) == ContentTransition.numericText(countsDown: false))
        #expect(animated.numericRoll(from: 99, to: 100) == ContentTransition.numericText(countsDown: false))
        #expect(animated.numericRoll(from: 10, to: 9) == ContentTransition.numericText(countsDown: true))
        #expect(animated.numericRoll(from: 100, to: 99) == ContentTransition.numericText(countsDown: true))
        #expect(animated.numericRoll(from: 7, to: 7) == ContentTransition.numericText(countsDown: false))
        for presentation in [MotionPresentation.resting, .hidden] {
            #expect(presentation.numericRoll(from: 9, to: 10) == ContentTransition.identity)
            #expect(presentation.numericRoll(from: 10, to: 9) == ContentTransition.identity)
        }
    }
}

// MARK: - 计数滚动的方向状态（#408 FR-4）

@Suite("anchoredBadge 计数滚动：方向状态机与出现 / 消失转场")
struct AnchoredBadgeMotionTests {
    @Test("首次出现无方向；随后每次变化把上一次的显示值记作 previous")
    func rollTracksPreviousValue() {
        let first = AnchoredBadgeModifier.nextRoll(nil, value: 9, isVisible: true)
        #expect(first == AnchoredBadgeCountRoll(previous: 9, value: 9))
        let up = AnchoredBadgeModifier.nextRoll(first, value: 10, isVisible: true)
        #expect(up == AnchoredBadgeCountRoll(previous: 9, value: 10))
        let down = AnchoredBadgeModifier.nextRoll(up, value: 9, isVisible: true)
        #expect(down == AnchoredBadgeCountRoll(previous: 10, value: 9))
    }

    @Test("非计数内容与不显示时清空方向状态 —— 隐藏后再出现不会闪一帧旧数字")
    func rollResetsWhenHidden() {
        let visible = AnchoredBadgeModifier.nextRoll(nil, value: 5, isVisible: true)
        #expect(AnchoredBadgeModifier.nextRoll(visible, value: 0, isVisible: false) == nil)
        #expect(AnchoredBadgeModifier.nextRoll(visible, value: nil, isVisible: true) == nil)
        let reappeared = AnchoredBadgeModifier.nextRoll(nil, value: 7, isVisible: true)
        #expect(reappeared == AnchoredBadgeCountRoll(previous: 7, value: 7))
    }

    @Test("方向由状态机推出：9 → 10 向上，10 → 9 向下")
    func rollFeedsDirection() {
        let start = AnchoredBadgeModifier.nextRoll(nil, value: 9, isVisible: true)
        let up = AnchoredBadgeModifier.nextRoll(start, value: 10, isVisible: true)
        let down = AnchoredBadgeModifier.nextRoll(up, value: 9, isVisible: true)
        let transition = { (roll: AnchoredBadgeCountRoll?) -> ContentTransition in
            MotionPresentation.animated.numericRoll(from: roll?.previous ?? 0, to: roll?.value ?? 0)
        }
        #expect(transition(up) == ContentTransition.numericText(countsDown: false))
        #expect(transition(down) == ContentTransition.numericText(countsDown: true))
    }

    @Test("出现 / 消失：animated 缩放 + 淡变，resting / hidden 纯淡变")
    func appearanceKindDegrades() {
        #expect(AnchoredBadgeModifier.appearanceKind(motion: .animated) == .scale)
        #expect(AnchoredBadgeModifier.appearanceKind(motion: .resting) == .fade)
        #expect(AnchoredBadgeModifier.appearanceKind(motion: .hidden) == .fade)
        #expect(AnchoredBadgeModifier.appearanceScale < 1, "缩放转场必须真的从小变大")
    }

    @Test("countText 的静态入口与实例属性同源，截断规则不变")
    func countTextIsSharedWithTheEnumCase() {
        #expect(AnchoredBadgeContent.countText(value: 9, max: 99) == "9")
        #expect(AnchoredBadgeContent.countText(value: 100, max: 99) == "99+")
        #expect(AnchoredBadgeContent.countText(value: 5, max: 0) == "1+")
        for (value, limit) in [(9, 99), (100, 99), (5, 0), (1, 1)] {
            #expect(AnchoredBadgeContent.count(value, max: limit).countText == AnchoredBadgeContent.countText(value: value, max: limit))
        }
        #expect(AnchoredBadgeContent.dot.countValue == nil)
        #expect(AnchoredBadgeContent.text("NEW").countValue == nil)
        #expect(AnchoredBadgeContent.count(120, max: 99).countValue == 120)
    }
}

// MARK: - Radio 指示符取色（#374 的取舍，#408 合并单张 Image 后仍成立）

@Suite("RadioGroup 指示符：invalid 只染圆环")
struct RadioIndicatorPaletteTests {
    @Test("选中 + invalid 走 palette（实心点 contentPrimary / 圆环 danger），其余走单色")
    func indicatorColorsByAppearance() {
        #expect(FieldAppearance.invalid.indicatorColor(normal: Color.contentPrimary) == Color.statusDangerForeground)
        #expect(FieldAppearance.normal.indicatorColor(normal: Color.contentPrimary) == Color.contentPrimary)
        #expect(FieldAppearance.normal.indicatorColor(normal: Color.contentSecondary) == Color.contentSecondary)
        #expect(FieldAppearance.disabled.indicatorColor(normal: Color.contentPrimary) == Color.contentPrimary)
    }
}

// MARK: - 静态外观：与 #408 之前的实现逐像素相同

@MainActor
private func badgePixels(_ view: some View, scheme: ColorScheme) -> [UInt8]? {
    let renderer = ImageRenderer(
        content: view
            .padding(16)
            .frame(width: 120)
            .background(Color.surfaceCanvas)
            .environment(\.colorScheme, scheme)
            .dynamicTypeSize(.large)
    )
    renderer.scale = 2
    _ = renderer.cgImage
    guard let image = renderer.cgImage else { return nil }
    var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
    bytes.withUnsafeMutableBytes { buffer in
        let context = CGContext(
            data: buffer.baseAddress, width: image.width, height: image.height, bitsPerComponent: 8,
            bytesPerRow: image.width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        context?.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    }
    return bytes
}

@MainActor
enum AnchoredBadgeSample: CaseIterable, CustomStringConvertible {
    case dotRectangle
    case dotCircle
    case count9
    case count99
    case countCapped
    case countCircle
    case text
    case hidden

    var description: String {
        switch self {
        case .dotRectangle: "dot/rectangle"
        case .dotCircle: "dot/circle"
        case .count9: "count(9)"
        case .count99: "count(99)"
        case .countCapped: "count(120, max: 99)"
        case .countCircle: "count(7)/circle"
        case .text: "text(NEW)"
        case .hidden: "count(0) 不显示"
        }
    }

    var content: AnchoredBadgeContent {
        switch self {
        case .dotRectangle, .dotCircle: .dot
        case .count9: .count(9)
        case .count99: .count(99)
        case .countCapped: .count(120, max: 99)
        case .countCircle: .count(7)
        case .text: .text("NEW")
        case .hidden: .count(0)
        }
    }

    var hostShape: AnchoredBadgeHostShape {
        switch self {
        case .dotCircle, .countCircle: .circle
        default: .rectangle
        }
    }

    private var host: some View {
        Image(systemName: "bell.fill")
            .font(.title)
            .foregroundStyle(Color.contentSecondary)
    }

    var current: AnyView {
        AnyView(self.host.anchoredBadge(self.content, hostShape: self.hostShape))
    }

    var legacy: AnyView {
        AnyView(self.host.modifier(LegacyAnchoredBadgeModifier(
            content: self.content, placement: .topTrailing, hostShape: self.hostShape
        )))
    }
}

@Suite("anchoredBadge 静态外观：与 #408 之前的实现逐像素相同")
@MainActor
struct AnchoredBadgeStaticAppearanceTests {
    // 容差 1：并行负载下同一份视图两次渲染会抖 1/111360 字节、逐通道 ±1（实测）。
    // 把转场换成系统 `.scale`（而不是 identity 相无变换的 `.modifier(active:identity:)`）时，
    // 圆形宿主上实测 369 字节偏差、maxDelta 196 —— 远在容差外，这道网抓得住真实位移。
    @Test("静息外观与旧实现在光栅化噪声内逐像素一致（light / dark，两条腿）", arguments: AnchoredBadgeSample.allCases)
    func matchesLegacy(_ sample: AnchoredBadgeSample) {
        for scheme in [ColorScheme.light, .dark] {
            expectBitmapsEquivalent(
                badgePixels(sample.current, scheme: scheme),
                badgePixels(sample.legacy, scheme: scheme),
                maxChannelDelta: 1,
                "\(sample) \(scheme)"
            )
        }
    }

    @Test("静息外观与 Reduce Motion 开关无关", arguments: AnchoredBadgeSample.allCases)
    func restingAppearanceIgnoresReduceMotion(_ sample: AnchoredBadgeSample) {
        for scheme in [ColorScheme.light, .dark] {
            let animated = badgePixels(
                sample.current.environment(\.coreMotionPresentationOverride, .animated), scheme: scheme
            )
            let resting = badgePixels(
                sample.current.environment(\.coreMotionPresentationOverride, .resting), scheme: scheme
            )
            expectBitmapsEquivalent(animated, resting, maxChannelDelta: 1, "\(sample) \(scheme)")
        }
    }

    @Test("判据不是恒真的：显示与不显示画出的东西不同")
    func visibleAndHiddenDiffer() {
        expectBitmapsDiffer(
            badgePixels(AnchoredBadgeSample.count9.current, scheme: .light),
            badgePixels(AnchoredBadgeSample.hidden.current, scheme: .light),
            "count(9) 与 count(0) 渲染相同 —— 上面的逐像素相等恒真"
        )
    }
}

// MARK: - 动画进行中的帧（#408 FR-4）

// iOS 上 `layer.render(in:)` 取的是模型层，拍不到进行中的帧 ⇒ 只在 macOS 腿观测。
#if os(macOS)

@MainActor
private final class BadgeCountBox: ObservableObject {
    @Published var count = 8
}

private struct BadgeCountMotionHarness: View {
    @ObservedObject var box: BadgeCountBox

    var body: some View {
        Image(systemName: "bell.fill")
            .font(.title)
            .foregroundStyle(Color.contentSecondary)
            .anchoredBadge(.count(self.box.count))
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// 只覆盖数字滚动。
///
/// CheckBox / Radio 的符号替换在这套 harness 上**观测不到**：托管窗口的取像分辨率固定在
/// 后备层（macOS 上 `pixels(scale:)` 不生效），16pt 的指示符只有 15 × 15 px。三种度量实测都
/// 分不开两条路径——端点包络外像素 RM 关 16 / RM 开 8；墨迹包围盒两边都恒为 15 × 15；
/// 墨迹掩码「离两端都远」的峰值 RM 关 11 / RM 开 42（反向，被 resting 那条淡变曲线污染）。
/// ⇒ 符号替换的降级由真值表 `SymbolNumericContentTransitionTests.symbolReplacementDegrades`
/// 与逐点台账兜住，不在这里假装有像素证据。
@Suite("动画进行中：数字滚动在 Reduce Motion 下不滚动", .serialized)
@MainActor
struct SymbolNumericInFlightTests {
    static func badgeCountPeak(reduceMotion: Bool, sampleFor duration: TimeInterval) -> (peak: Int, changed: Bool) {
        let box = BadgeCountBox()
        let window = HostedWindow(
            BadgeCountMotionHarness(box: box)
                .environment(\.coreMotionPresentationOverride, reduceMotion ? .resting : .animated),
            size: CGSize(width: 140, height: 100),
            scheme: .light
        )
        defer { window.close() }
        window.settle()
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        let before = window.pixels()
        box.count = 9
        var frames: [HostedPixels] = []
        let start = Date()
        while Date().timeIntervalSince(start) < duration {
            RunLoop.main.run(until: Date().addingTimeInterval(0.008))
            frames.append(window.pixels())
        }
        window.settle()
        RunLoop.main.run(until: Date().addingTimeInterval(0.4))
        let after = window.pixels()
        let peak = frames.map {
            CoreMotionTokenInFlightTests.outsideEndpoints(
                before: before, after: after, frame: $0, rows: 0..<before.height
            )
        }.max() ?? -1
        return (peak, before.bytes != after.bytes)
    }

    // 8 → 9：两个字形同宽，胶囊尺寸不变 ⇒ 唯一的变量是数字本身，排除了「宽度插值」这个混淆量。
    @Test("徽标计数 8 → 9：RM 关时字形途经端点之外，RM 开时直接替换")
    func numericRollInFlight() {
        let on = Self.badgeCountPeak(reduceMotion: true, sampleFor: 0.4)
        #expect(on.changed, "计数没变过去，判据无效")
        #expect(on.peak == 0, "RM 开时数字不得滚动 / 模糊，实测 \(on.peak)")
        _ = CoreMotionTokenInFlightTests.observeControlMotion("徽标计数滚动", threshold: 10) { window in
            let off = Self.badgeCountPeak(reduceMotion: false, sampleFor: window + 0.1)
            return off.changed ? off.peak : -1
        }
    }

    struct AppearanceTrace: Sendable {
        let fullWidth: Int
        let minWidth: Int
        let sawPartial: Bool
    }

    static func changedBox(_ frame: HostedPixels, against baseline: HostedPixels) -> (width: Int, count: Int) {
        guard let bytes = frame.bytes, let base = baseline.bytes, bytes.count == base.count, frame.width > 0 else {
            return (-1, -1)
        }
        var minX = Int.max, maxX = -1, total = 0
        for row in 0..<frame.height {
            for column in 0..<frame.width {
                let index = (row * frame.width + column) * 4
                if (0..<3).contains(where: { abs(Int(bytes[index + $0]) - Int(base[index + $0])) > 8 }) {
                    minX = min(minX, column)
                    maxX = max(maxX, column)
                    total += 1
                }
            }
        }
        return maxX >= 0 ? (maxX - minX + 1, total) : (0, 0)
    }

    static func appearanceTrace(reduceMotion: Bool, sampleFor duration: TimeInterval) -> AppearanceTrace {
        let box = BadgeCountBox()
        box.count = 0
        let window = HostedWindow(
            BadgeCountMotionHarness(box: box)
                .environment(\.coreMotionPresentationOverride, reduceMotion ? .resting : .animated),
            size: CGSize(width: 140, height: 100),
            scheme: .light
        )
        defer { window.close() }
        window.settle()
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        let baseline = window.pixels()
        box.count = 3
        var boxes: [(width: Int, count: Int)] = []
        let start = Date()
        while Date().timeIntervalSince(start) < duration {
            RunLoop.main.run(until: Date().addingTimeInterval(0.008))
            boxes.append(Self.changedBox(window.pixels(), against: baseline))
        }
        window.settle()
        RunLoop.main.run(until: Date().addingTimeInterval(0.4))
        let full = Self.changedBox(window.pixels(), against: baseline)
        let drawn = boxes.filter { $0.count > 0 }
        return AppearanceTrace(
            fullWidth: full.width,
            minWidth: drawn.map(\.width).min() ?? -1,
            sawPartial: drawn.contains { $0.count < full.count }
        )
    }

    // 量的是「与徽标未出现时那一帧相比有变化」的像素跨度——与 alpha 无关，只与几何有关：
    // 缩放让它先窄后宽，淡变全程满宽（按红色饱和度取阈值会被 alpha 污染，实测淡入早期只量到 6 px）。
    @Test("徽标出现：RM 关时从 0.6 放大，RM 开时全程满宽只淡入")
    func appearanceInFlight() {
        let on = Self.appearanceTrace(reduceMotion: true, sampleFor: 0.4)
        #expect(on.fullWidth > 10, "徽标没画出来，判据无效（终态宽 \(on.fullWidth)）")
        #expect(on.sawPartial, "没采到淡入中的帧（全部帧都已是终态），判据无法下结论")
        #expect(on.minWidth >= on.fullWidth - 3,
                "RM 开时徽标不得缩放，实测最窄 \(on.minWidth) / 终态 \(on.fullWidth)")
        // 阈值 4：0.6 的缩放理论上让跨度少 8 px，实测最早采到的帧只少 6–7 px（`.smooth` 起步慢）；
        // RM 开那一侧实测恒为 0，4 仍然分得开。
        _ = CoreMotionTokenInFlightTests.observeControlMotion("徽标出现缩放", threshold: 4) { window in
            let off = Self.appearanceTrace(reduceMotion: false, sampleFor: window + 0.1)
            return off.fullWidth > 10 ? off.fullWidth - off.minWidth : -1
        }
    }
}
#endif
