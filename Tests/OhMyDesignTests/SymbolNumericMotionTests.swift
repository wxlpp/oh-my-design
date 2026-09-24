import QuartzCore
import SwiftUI
import Testing
@testable import OhMyDesign
#if canImport(UIKit)
import UIKit
#endif

// MARK: - 内容过渡的降级真值表（#408 FR-4）

@Suite("符号 / 数字内容过渡：按 MotionPresentation 降级")
struct SymbolNumericContentTransitionTests {
    @Test("ContentTransition 的 Equatable 能分辨取值与 identity —— 否则下面的断言是恒真的")
    func contentTransitionEqualityIsDiscriminating() {
        #expect(ContentTransition.numericText(value: 9) != ContentTransition.numericText(value: 10))
        #expect(ContentTransition.numericText(value: 9) != ContentTransition.identity)
        #expect(ContentTransition.numericText(value: 9) == ContentTransition.numericText(value: 9))
        #expect(ContentTransition.symbolEffect(.replace) != ContentTransition.identity)
        #expect(ContentTransition.symbolEffect(.replace) == ContentTransition.symbolEffect(.replace))
    }

    @Test("符号替换：animated 走 symbolEffect(.replace)，resting / hidden 直接换图")
    func symbolReplacementDegrades() {
        #expect(MotionPresentation.animated.symbolReplacement == ContentTransition.symbolEffect(.replace))
        #expect(MotionPresentation.resting.symbolReplacement == ContentTransition.identity)
        #expect(MotionPresentation.hidden.symbolReplacement == ContentTransition.identity)
    }

    // 方向不由本库给出：`.numericText(value:)` 让框架自己按插值中的取值判。本库要担保的是
    // 「喂进去的就是当前计数」——不同计数必须产生不同的过渡，否则框架无从判向。
    @Test("数字滚动：喂的是当前计数本身，不同计数产生不同过渡；resting / hidden 直接替换")
    func numericRollCarriesTheCount() {
        let animated = MotionPresentation.animated
        for value in [0, 7, 9, 10, 99, 100] {
            #expect(animated.numericRoll(to: value) == ContentTransition.numericText(value: Double(value)))
        }
        #expect(animated.numericRoll(to: 9) != animated.numericRoll(to: 10), "9 与 10 必须是两个不同的过渡")
        #expect(animated.numericRoll(to: 99) != animated.numericRoll(to: 100))
        #expect(animated.numericRoll(to: 10) != animated.numericRoll(to: 9))
        for presentation in [MotionPresentation.resting, .hidden] {
            for value in [9, 10, 99, 100] {
                #expect(presentation.numericRoll(to: value) == ContentTransition.identity)
            }
        }
    }
}

// MARK: - 出现 / 消失转场（#408 FR-4）

@Suite("anchoredBadge 出现 / 消失转场")
struct AnchoredBadgeMotionTests {
    @Test("出现 / 消失：animated 缩放 + 淡变，resting / hidden 纯淡变")
    func appearanceKindDegrades() {
        #expect(AnchoredBadgeModifier.appearanceKind(motion: .animated) == .scale)
        #expect(AnchoredBadgeModifier.appearanceKind(motion: .resting) == .fade)
        #expect(AnchoredBadgeModifier.appearanceKind(motion: .hidden) == .fade)
        #expect(AnchoredBadgeModifier.appearanceScale < 1, "缩放转场必须真的从小变大")
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
    // 把出现转场挂到外层 `GeometryReader`（而不是徽标本身）时，圆形宿主上实测 369 字节偏差、
    // maxDelta 196 —— 远在容差外，这道网抓得住真实的亚像素位移。
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

// MARK: - 真实 modifier 上的计数序列（#408 FR-4）

@MainActor
final class BadgeCountBox: ObservableObject {
    @Published var count: Int

    init(_ count: Int) {
        self.count = count
    }
}

struct BadgeCountMotionHarness: View {
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

@MainActor
enum BadgeSequenceRunner {
    static let size = CGSize(width: 160, height: 100)

    static func window(_ box: BadgeCountBox, reduceMotion: Bool) -> HostedWindow {
        HostedWindow(
            BadgeCountMotionHarness(box: box)
                .environment(\.coreMotionPresentationOverride, reduceMotion ? .resting : .animated),
            size: Self.size,
            scheme: .light
        )
    }

    // 一轮固定等待可能追不完出现转场（CI 曾在 scale 0.6 → 1 途中取像：宽 46 vs 56、高 32 vs 40），所以等到相邻两轮宽高相同。
    static func settle(_ window: HostedWindow, sourceLocation: SourceLocation = #_sourceLocation) {
        Self.settleOnce(window)
        var previous = BadgeFillShape.measure(window.pixels())
        for _ in 0..<Self.stabilityAttempts {
            Self.refresh(window)
            RunLoop.main.run(until: Date().addingTimeInterval(0.1))
            let next = BadgeFillShape.measure(window.pixels())
            if next?.width == previous?.width, next?.height == previous?.height { return }
            previous = next
        }
        Issue.record(
            "徽标在 \(Self.stabilityAttempts) 轮稳定等待后宽高仍在变（最后一次 \(String(describing: previous))），终态读数不可信",
            sourceLocation: sourceLocation
        )
    }

    static let stabilityAttempts = 10

    // ⚠️ iOS 腿必须补一次 `CATransaction.flush()`：只跑 `settle()` + runloop 时，托管窗口的取像
    // 拿到的还是**变更前**的状态（实测把 0 → 3 跑完仍量到徽标不存在、9 → 10 仍量到旧宽度），
    // 因为 `layer.render(in:)` 取的是模型层而更新还没提交。macOS 腿不需要，但加上无害。
    static func settleOnce(_ window: HostedWindow) {
        window.settle()
        RunLoop.main.run(until: Date().addingTimeInterval(0.4))
        Self.refresh(window)
    }

    private static func refresh(_ window: HostedWindow) {
        #if canImport(UIKit)
        window.root.setNeedsLayout()
        window.root.layoutIfNeeded()
        window.root.setNeedsDisplay()
        #endif
        CATransaction.flush()
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
    }

    /// 在同一个活视图上依次施加 `counts`（中间步只等一轮），终值稳定后返回位图。
    static func settled(after counts: [Int], from start: Int, reduceMotion: Bool) -> HostedPixels {
        let box = BadgeCountBox(start)
        let window = Self.window(box, reduceMotion: reduceMotion)
        defer { window.close() }
        Self.settleOnce(window)
        for count in counts.dropLast() {
            box.count = count
            Self.settleOnce(window)
        }
        box.count = counts.last ?? start
        Self.settle(window)
        return window.pixels()
    }

    /// 同一份 harness 直接以 `count` 建起来、稳定后的位图（参照物）。
    static func reference(_ count: Int, reduceMotion: Bool) -> HostedPixels {
        let box = BadgeCountBox(count)
        let window = Self.window(box, reduceMotion: reduceMotion)
        defer { window.close() }
        Self.settle(window)
        return window.pixels()
    }
}

/// 徽标底色（`badgeFill` = systemRed，两条腿都能解析）的整数几何描述子。
///
/// ⚠️ **不拿位图逐字节比终态**：这套 harness 的取像分辨率下整个胶囊只有 20 × 20 px
/// （macOS 腿 scale 1），「数字错一位」实测只差 **104 / 64000** 字节，而「滚动过的文字与从未滚动
/// 过的文字」的光栅化残差实测 **54–119** 字节 —— 噪声与信号同量级，位图比不出东西来。
/// 改比整数描述子：`width` 由文字宽度决定（0 / 20 / 26 / 33，实测逐例精确），是承重的那一项；
/// `fillPixels` / `glyphPixels` 只作辅助，容差按实测的光栅化残差放宽。
nonisolated struct BadgeFillShape: Equatable, Sendable, CustomStringConvertible {
    let width: Int
    let height: Int
    let fillPixels: Int
    let glyphPixels: Int

    var description: String { "w\(self.width)×h\(self.height) fill\(self.fillPixels) glyph\(self.glyphPixels)" }

    static let absent = BadgeFillShape(width: 0, height: 0, fillPixels: 0, glyphPixels: 0)

    static func measure(_ frame: HostedPixels) -> BadgeFillShape? {
        guard let bytes = frame.bytes, frame.width > 0, frame.height > 0 else { return nil }
        var minX = Int.max, maxX = -1, minY = Int.max, maxY = -1, fill = 0
        for row in 0..<frame.height {
            for column in 0..<frame.width {
                let index = (row * frame.width + column) * 4
                let red = Int(bytes[index]), green = Int(bytes[index + 1]), blue = Int(bytes[index + 2])
                if red - green > 40, red - blue > 40 {
                    minX = min(minX, column)
                    maxX = max(maxX, column)
                    minY = min(minY, row)
                    maxY = max(maxY, row)
                    fill += 1
                }
            }
        }
        guard maxX >= 0 else { return Self.absent }
        var glyph = 0
        for row in minY...maxY {
            for column in minX...maxX {
                let index = (row * frame.width + column) * 4
                if (0..<3).allSatisfy({ bytes[index + $0] > 200 }) { glyph += 1 }
            }
        }
        return BadgeFillShape(
            width: maxX - minX + 1, height: maxY - minY + 1, fillPixels: fill, glyphPixels: glyph
        )
    }
}

@Suite("anchoredBadge 计数序列：终态只取决于最终计数", .serialized)
@MainActor
struct AnchoredBadgeSequenceTests {
    struct Sequence: Sendable, CustomStringConvertible {
        let start: Int
        let steps: [Int]
        /// 另一条通向同一个终值的路径，用来证明终态与路径无关。
        let otherStart: Int
        let otherSteps: [Int]
        let note: String

        var final: Int { self.steps.last ?? self.start }
        /// 「卡在半路」的候选终态：起点、以及退场后没跟上新计数的那一格。
        var staleCandidates: [Int] { ([self.start] + self.steps.dropLast()).filter { $0 != self.final } }

        var description: String { "\(self.start)→\(self.steps.map(String.init).joined(separator: "→"))（\(self.note)）" }
    }

    // 每条的终值都与它的「卡半路」候选**宽度不同**（由 staleCandidatesDifferInWidth 逐条核对），
    // 所以下面那条精确比宽度的判据真的钉得住。
    nonisolated static let sequences: [Sequence] = [
        Sequence(start: 9, steps: [10], otherStart: 11, otherSteps: [10], note: "进位，胶囊变宽"),
        Sequence(start: 10, steps: [9], otherStart: 8, otherSteps: [9], note: "递减，胶囊变窄"),
        Sequence(start: 99, steps: [100], otherStart: 101, otherSteps: [100], note: "跨到截断，文字变 99+"),
        Sequence(start: 100, steps: [99], otherStart: 98, otherSteps: [99], note: "从截断退回"),
        Sequence(start: 5, steps: [0], otherStart: 3, otherSteps: [0], note: "退场"),
        Sequence(start: 5, steps: [0, 70], otherStart: 9, otherSteps: [0, 70], note: "退场后再出现，必须直接用新计数"),
        Sequence(start: 0, steps: [3], otherStart: 4, otherSteps: [3], note: "出现"),
    ]

    static func shape(after steps: [Int], from start: Int, reduceMotion: Bool) -> BadgeFillShape? {
        BadgeFillShape.measure(BadgeSequenceRunner.settled(after: steps, from: start, reduceMotion: reduceMotion))
    }

    static func referenceShape(_ count: Int, reduceMotion: Bool) -> BadgeFillShape? {
        BadgeFillShape.measure(BadgeSequenceRunner.reference(count, reduceMotion: reduceMotion))
    }

    // 容差：宽 / 高精确；fill / glyph 按实测的光栅化残差放宽（macOS 腿实测 ≤ 4 px，
    // iOS 腿取像 scale 2 ⇒ 面积项约 4 倍，故用相对量兜底）。
    static func expectSameShape(_ a: BadgeFillShape?, _ b: BadgeFillShape?, _ label: String) {
        guard let a, let b else {
            #expect(a != nil && b != nil, "\(label)：没量到形状（\(String(describing: a)) / \(String(describing: b))）")
            return
        }
        #expect(a.width == b.width, "\(label)：胶囊宽不同 —— \(a) vs \(b)")
        #expect(a.height == b.height, "\(label)：胶囊高不同 —— \(a) vs \(b)")
        let fillSlack = max(6, b.fillPixels / 10)
        let glyphSlack = max(6, b.glyphPixels / 10)
        #expect(abs(a.fillPixels - b.fillPixels) <= fillSlack, "\(label)：底色像素差超出 \(fillSlack) —— \(a) vs \(b)")
        #expect(abs(a.glyphPixels - b.glyphPixels) <= glyphSlack, "\(label)：数字像素差超出 \(glyphSlack) —— \(a) vs \(b)")
    }

    @Test("终态与路径无关（RM 开 / 关）", arguments: Self.sequences, [false, true])
    func settledStateIsPathIndependent(_ sequence: Sequence, _ reduceMotion: Bool) {
        Self.expectSameShape(
            Self.shape(after: sequence.steps, from: sequence.start, reduceMotion: reduceMotion),
            Self.shape(after: sequence.otherSteps, from: sequence.otherStart, reduceMotion: reduceMotion),
            "\(sequence) RM=\(reduceMotion) 路径无关"
        )
    }

    @Test("终态与直接建起来的参照物一致（RM 开 / 关）", arguments: Self.sequences, [false, true])
    func settledStateMatchesFreshReference(_ sequence: Sequence, _ reduceMotion: Bool) {
        Self.expectSameShape(
            Self.shape(after: sequence.steps, from: sequence.start, reduceMotion: reduceMotion),
            Self.referenceShape(sequence.final, reduceMotion: reduceMotion),
            "\(sequence) RM=\(reduceMotion) 对参照物"
        )
    }

    @Test("判据钉得住：每条序列的「卡半路」候选都与终值宽度不同", arguments: Self.sequences, [false, true])
    func staleCandidatesDifferInWidth(_ sequence: Sequence, _ reduceMotion: Bool) throws {
        let final = try #require(Self.referenceShape(sequence.final, reduceMotion: reduceMotion))
        #expect(!sequence.staleCandidates.isEmpty, "\(sequence)：没有可比的「卡半路」候选，上面两条判据恒真")
        for stale in sequence.staleCandidates {
            let shape = try #require(Self.referenceShape(stale, reduceMotion: reduceMotion))
            #expect(shape.width != final.width,
                    "\(sequence) RM=\(reduceMotion)：卡在 \(stale) 与终值 \(sequence.final) 宽度相同（\(shape) vs \(final)）—— 宽度判据抓不住它")
        }
    }

    @Test("退场后徽标真的不见了：底色一个像素都不剩", arguments: [false, true])
    func exitLeavesNothing(_ reduceMotion: Bool) throws {
        let gone = try #require(Self.shape(after: [0], from: 5, reduceMotion: reduceMotion))
        #expect(gone == BadgeFillShape.absent, "退场后还剩 \(gone)")
        let present = try #require(Self.referenceShape(5, reduceMotion: reduceMotion))
        #expect(present.fillPixels > 100, "起始态没画出来，上面那条恒真（实测 \(present)）")
    }

    // `.numericText(value:)` 收的值变了（120 → 130），但 `Text` 的内容没变（都是 `99+`）⇒
    // 没有内容变化可供过渡，屏上**一帧都不动**。这条把该行为钉住，免得被读成「截断区间内的计数不生效」。
    @Test("被截断的两个计数渲染完全相同：120 → 130 屏上没有可见变化", arguments: [false, true])
    func clampedCountsRenderIdentically(_ reduceMotion: Bool) {
        let low = BadgeSequenceRunner.reference(120, reduceMotion: reduceMotion)
        let high = BadgeSequenceRunner.reference(130, reduceMotion: reduceMotion)
        let sequenced = BadgeSequenceRunner.settled(after: [130], from: 120, reduceMotion: reduceMotion)
        #expect(low.bytes != nil)
        // 这三张是逐字节相同的（实测）：文字没变 ⇒ 没有过渡跑过 ⇒ 没有光栅化残差。
        expectBitmapsEqual(low.bytes, high.bytes, "120 与 130 都该是 99+")
        expectBitmapsEqual(sequenced.bytes, high.bytes, "120 → 130 的终态与直接建 130 不同")
        #expect(AnchoredBadgeContent.count(120, max: 99).countText == "99+")
        #expect(AnchoredBadgeContent.count(130, max: 99).countText == "99+")
        // 取值确实变了——只是没有内容变化可动画。
        #expect(MotionPresentation.animated.numericRoll(to: 120) != MotionPresentation.animated.numericRoll(to: 130))
    }
}

// MARK: - 动画进行中的帧（#408 FR-4）

// iOS 上 `layer.render(in:)` 取的是模型层，拍不到进行中的帧 ⇒ 只在 macOS 腿观测。
#if os(macOS)

/// 只覆盖数字滚动与徽标出现 / 退场的**进行中帧**；终态与序列由
/// `AnchoredBadgeSequenceTests` 在两条腿上覆盖。
///
/// CheckBox / Radio 的符号替换在这套 harness 上**观测不到**：托管窗口的取像分辨率固定在
/// 后备层（macOS 上 `pixels(scale:)` 不生效），16pt 的指示符只有 15 × 15 px。三种度量实测都
/// 分不开两条路径——端点包络外像素 RM 关 16 / RM 开 8；墨迹包围盒两边都恒为 15 × 15；
/// 墨迹掩码「离两端都远」的峰值 RM 关 11 / RM 开 42（反向，被 resting 那条淡变曲线污染）。
/// ⇒ 符号替换的降级由真值表 `SymbolNumericContentTransitionTests.symbolReplacementDegrades`
/// 与逐点台账兜住，不在这里假装有像素证据。
///
/// 「计数不晚一帧」也**测不出来**：托管窗口取像会强制走一次显示，镜像一层显示值多出的那一次
/// 更新在同一次取像里就已落地——实测「立即取像是否已是新数字」在有镜像与无镜像两种实现下
/// 结果相同（RM 开两边都已是新数字）。⇒ 不留恒真的断言；今天的担保是结构性的（喂给
/// `numericText` 的取值与文字同出于 `case .count` 的那一次绑定，中间没有状态），
/// 而把镜像加回去会被下面那条 `numericRollInFlight` 判红——镜像的状态变化不在
/// `.coreAnimation(.reveal, value: self.content)` 的触发集里，滚动动画整个不播。
@Suite("动画进行中：数字滚动 / 出现 / 退场在 Reduce Motion 下不滚动、不缩放", .serialized)
@MainActor
struct SymbolNumericInFlightTests {
    // MARK: - 采样结果与「能否下结论」

    /// 一次采样的归约结果。
    ///
    /// ⚠️ **空采样必须是失败哨兵，不能落成「差得很多」**：`minWidth` 在没采到任何画出来的帧时是 `-1`，
    /// 直接拿 `fullWidth - minWidth` 当观测量会让「一帧都没看到」比真实缩放还大，对照组从此恒绿。
    /// 观测量一律走 `scaleShortfall` / `rollPeak`，它们在 `!isConclusive` 时返回 `-1`。
    struct WidthTrace: Sendable {
        let fullWidth: Int
        let minWidth: Int
        let drawnFrames: Int
        let sampledFrames: Int
        let sawPartial: Bool

        var isConclusive: Bool {
            self.fullWidth > 10 && self.sampledFrames > 5 && self.drawnFrames > 0 && self.minWidth > 0
        }

        var scaleShortfall: Int { self.isConclusive ? self.fullWidth - self.minWidth : -1 }
    }

    struct RollTrace: Sendable {
        let peak: Int
        let sampledFrames: Int
        let changed: Bool

        var isConclusive: Bool { self.changed && self.sampledFrames > 5 && self.peak >= 0 }
        var rollPeak: Int { self.isConclusive ? self.peak : -1 }
    }

    static func reduceWidths(
        sampled: [(width: Int, count: Int)],
        reference: (width: Int, count: Int)
    ) -> WidthTrace {
        let drawn = sampled.filter { $0.count > 0 }
        return WidthTrace(
            fullWidth: reference.width,
            minWidth: drawn.map(\.width).min() ?? -1,
            drawnFrames: drawn.count,
            sampledFrames: sampled.count,
            sawPartial: drawn.contains { $0.count < reference.count }
        )
    }

    static func reduceRoll(peaks: [Int], changed: Bool) -> RollTrace {
        RollTrace(peak: peaks.max() ?? -1, sampledFrames: peaks.count, changed: changed)
    }

    @Test("自证：空采样不得算成「缩放 / 滚动很明显」——观测量必须是失败哨兵")
    func emptySamplingCannotPass() {
        let reference = (width: 20, count: 317)
        let empty = Self.reduceWidths(sampled: [], reference: reference)
        #expect(!empty.isConclusive, "空采样必须判为无法下结论")
        #expect(empty.scaleShortfall == -1, "空采样的观测量必须是 -1，实测 \(empty.scaleShortfall)")
        let blank = Self.reduceWidths(
            sampled: Array(repeating: (width: 0, count: 0), count: 30), reference: reference
        )
        #expect(!blank.isConclusive, "只采到「什么都没画」的帧，同样无法下结论")
        #expect(blank.scaleShortfall == -1, "实测 \(blank.scaleShortfall)")
        let tooFew = Self.reduceWidths(sampled: [(width: 12, count: 100)], reference: reference)
        #expect(!tooFew.isConclusive, "只采到 1 帧不足以下结论")
        #expect(tooFew.scaleShortfall == -1)
        let scaled = Self.reduceWidths(
            sampled: [(12, 100), (16, 200), (20, 317), (20, 317), (20, 317), (20, 317)].map { (width: $0.0, count: $0.1) },
            reference: reference
        )
        #expect(scaled.isConclusive, "真实的缩放序列必须可下结论")
        #expect(scaled.scaleShortfall == 8, "实测 \(scaled.scaleShortfall)")

        #expect(Self.reduceRoll(peaks: [], changed: true).rollPeak == -1, "零帧的滚动采样必须是 -1")
        #expect(Self.reduceRoll(peaks: [0, 5, 30], changed: false).rollPeak == -1, "端点没变过 ⇒ 无法下结论")
        #expect(Self.reduceRoll(peaks: Array(repeating: -1, count: 30), changed: true).rollPeak == -1,
                "逐帧比对失败（长度不符）时必须是 -1")
        #expect(Self.reduceRoll(peaks: [0, 5, 30, 12, 0, 0], changed: true).rollPeak == 30)
        #expect(Self.reduceRoll(peaks: Array(repeating: 0, count: 30), changed: true).rollPeak == 0,
                "真的一帧都没出界时是 0，不是哨兵 —— RM 开那一侧断言的正是它")
    }

    // MARK: - 采样

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

    static func sample(
        from start: Int,
        to target: Int,
        reduceMotion: Bool,
        sampleFor duration: TimeInterval
    ) -> (frames: [HostedPixels], before: HostedPixels, after: HostedPixels) {
        let box = BadgeCountBox(start)
        let window = BadgeSequenceRunner.window(box, reduceMotion: reduceMotion)
        defer { window.close() }
        BadgeSequenceRunner.settle(window)
        let before = window.pixels()
        box.count = target
        var frames: [HostedPixels] = []
        let clock = Date()
        while Date().timeIntervalSince(clock) < duration {
            RunLoop.main.run(until: Date().addingTimeInterval(0.008))
            frames.append(window.pixels())
        }
        BadgeSequenceRunner.settle(window)
        return (frames, before, window.pixels())
    }

    /// 出现 / 退场两条在 CI runner 上无法下结论，按 `#407` 的先例跳过；读数与机理见 issue `#410`。
    ///
    /// ⚠️ 别靠放大徽标或放宽 `samplingWindows` 救它——缺的是**采样相位**不是幅度（已实测证伪）。
    /// ⚠️ CI 上那两条判据盖不住「`.transition(self.appearanceTransition)` 整行被删」：
    /// 终态与配置层都不变，`CI=1` 下实测 13 tests in 4 suites 全绿，只有本机这条 in-flight 抓得住。
    nonisolated static let appearanceCISkip = """
    跳过：CI runner 上采不到出现 / 退场转场的中间帧（观测量是单调收敛到端点的包围盒跨度，\
    动画跑过约 95% 后与端点无从分辨；run 35786828672）。本条在本机跑。\
    CI 上守着这条契约的是 AnchoredBadgeMotionTests.appearanceKindDegrades \
    与 AnchoredBadgeSequenceTests；⚠️ 两者都盖不住「.transition(self.appearanceTransition) 整行被删」\
    ——那种改动在 CI 上不判红，见 issue #410。
    """

    // 量的是「与徽标不显示那一帧相比有变化」的像素跨度——与 alpha 无关，只与几何有关：
    // 缩放让它先窄后宽（或先宽后窄），淡变全程满宽（按红色饱和度取阈值会被 alpha 污染，实测淡入早期只量到 6 px）。
    static func widthTrace(
        from start: Int,
        to target: Int,
        reduceMotion: Bool,
        sampleFor duration: TimeInterval
    ) -> WidthTrace {
        let shot = Self.sample(from: start, to: target, reduceMotion: reduceMotion, sampleFor: duration)
        let absent = start == 0 ? shot.before : shot.after
        let present = start == 0 ? shot.after : shot.before
        return Self.reduceWidths(
            sampled: shot.frames.map { Self.changedBox($0, against: absent) },
            reference: Self.changedBox(present, against: absent)
        )
    }

    static func rollTrace(
        from start: Int,
        to target: Int,
        reduceMotion: Bool,
        sampleFor duration: TimeInterval
    ) -> RollTrace {
        let shot = Self.sample(from: start, to: target, reduceMotion: reduceMotion, sampleFor: duration)
        let peaks = shot.frames.map {
            CoreMotionTokenInFlightTests.outsideEndpoints(
                before: shot.before, after: shot.after, frame: $0, rows: 0..<shot.before.height
            )
        }
        return Self.reduceRoll(peaks: peaks, changed: shot.before.bytes != shot.after.bytes)
    }

    // MARK: - 数字滚动

    struct RollCase: Sendable, CustomStringConvertible {
        let from: Int
        let to: Int
        let note: String

        var description: String { "\(self.from)→\(self.to)（\(self.note)）" }
    }

    // 8 → 9 两个字形同宽、胶囊尺寸不变 ⇒ 排除了「宽度插值」这个混淆量；另外三条刻意让位数变化。
    nonisolated static let rollCases: [RollCase] = [
        RollCase(from: 8, to: 9, note: "同宽，只有字形变"),
        RollCase(from: 10, to: 9, note: "递减，位数变少"),
        RollCase(from: 9, to: 10, note: "进位，位数变多"),
    ]

    @Test("徽标计数变化：RM 关时字形途经端点之外，RM 开时直接替换", arguments: Self.rollCases)
    func numericRollInFlight(_ rollCase: RollCase) {
        let on = Self.rollTrace(from: rollCase.from, to: rollCase.to, reduceMotion: true, sampleFor: 0.4)
        #expect(on.isConclusive, "\(rollCase) RM 开：采样无法下结论（changed=\(on.changed) 帧数=\(on.sampledFrames) peak=\(on.peak)）")
        #expect(on.rollPeak == 0, "\(rollCase) RM 开时数字不得滚动 / 模糊，实测 \(on.rollPeak)")
        _ = CoreMotionTokenInFlightTests.observeControlMotion("徽标计数滚动 \(rollCase)", threshold: 10) { window in
            Self.rollTrace(from: rollCase.from, to: rollCase.to, reduceMotion: false, sampleFor: window + 0.1).rollPeak
        }
    }

    // MARK: - 出现 / 退场

    @Test(
        "徽标出现（0 → 3）：RM 关时从 0.6 放大，RM 开时全程满宽只淡入",
        .enabled(if: !CoreMotionTokenInFlightTests.isCIRunner, Comment(rawValue: Self.appearanceCISkip))
    )
    func appearanceInFlight() {
        let on = Self.widthTrace(from: 0, to: 3, reduceMotion: true, sampleFor: 0.4)
        #expect(on.isConclusive, "RM 开：采样无法下结论（\(on)）")
        #expect(on.sawPartial, "没采到淡入中的帧（全部帧都已是终态），判据无法下结论")
        #expect(on.minWidth >= on.fullWidth - 3,
                "RM 开时徽标不得缩放，实测最窄 \(on.minWidth) / 终态 \(on.fullWidth)")
        // 阈值 4：0.6 的缩放理论上让跨度少 8 px，实测最早采到的帧只少 6–7 px（`.smooth` 起步慢）；
        // RM 开那一侧实测恒为 0，4 仍然分得开。
        _ = CoreMotionTokenInFlightTests.observeControlMotion("徽标出现缩放", threshold: 4) { window in
            Self.widthTrace(from: 0, to: 3, reduceMotion: false, sampleFor: window + 0.1).scaleShortfall
        }
    }

    @Test(
        "徽标退场（5 → 0）：退场转场真的在播 —— RM 关时缩小，RM 开时全程满宽只淡出",
        .enabled(if: !CoreMotionTokenInFlightTests.isCIRunner, Comment(rawValue: Self.appearanceCISkip))
    )
    func exitInFlight() {
        let on = Self.widthTrace(from: 5, to: 0, reduceMotion: true, sampleFor: 0.4)
        #expect(on.isConclusive, "RM 开：采样无法下结论（\(on)）")
        #expect(on.sawPartial, "退场没被采到（没有一帧是淡出中的）—— 退场可能被取消了")
        #expect(on.minWidth >= on.fullWidth - 3,
                "RM 开时徽标不得缩放，实测最窄 \(on.minWidth) / 起始 \(on.fullWidth)")
        _ = CoreMotionTokenInFlightTests.observeControlMotion("徽标退场缩放", threshold: 4) { window in
            Self.widthTrace(from: 5, to: 0, reduceMotion: false, sampleFor: window + 0.1).scaleShortfall
        }
    }
}
#endif
