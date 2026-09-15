import OhMyDesign
import SwiftUI

// MARK: - 本 target 的 chrome 文案入口

extension LocalizedStringResource {
    static func effectsChrome(_ key: String.LocalizationValue) -> Self {
        LocalizedStringResource(key, bundle: .atURL(Bundle.module.bundleURL))
    }
}

// MARK: - 标签取值域

/// `BeforeAfterSlider` 两侧标签的取值域。
public enum BeforeAfterSliderLabels {
    /// 不显示标签。
    case hidden

    /// 显示**组件自带**的默认文案（"Before" / "After"，公约 §4 A 类）。
    case standard

    /// 显示**调用方给定**的文案（公约 §4 B 类）。
    case shown(before: LocalizedStringKey, after: LocalizedStringKey)

    static let defaultBefore: LocalizedStringResource = .effectsChrome("Before")

    static let defaultAfter: LocalizedStringResource = .effectsChrome("After")
}

enum BeforeAfterSliderChrome {
    static let accessibilityTitle: LocalizedStringResource =
        .effectsChrome("Before and after comparison")
}

// MARK: - 入场摆动与几何（纯函数，生产代码与判据共用同一份）

nonisolated struct BeforeAfterIntroSweep: Equatable, Sendable {
    let peak: CGFloat
    let settle: CGFloat
    let duration: Double
}

nonisolated enum BeforeAfterSweep {
    static let initialFraction: CGFloat = 0.5

    static let sweepPeak: CGFloat = 0.78

    static let sweepDuration: Double = 0.55

    static let handleHitSize: CGFloat = 44

    static let handleDiameter: CGFloat = 28

    static let dividerWidth: CGFloat = CoreBorderWidth.thick

    static func introSweep(reduceMotion: Bool) -> BeforeAfterIntroSweep? {
        guard !reduceMotion else { return nil }
        return BeforeAfterIntroSweep(
            peak: Self.sweepPeak,
            settle: Self.initialFraction,
            duration: Self.sweepDuration
        )
    }

    static func settlesAfterSweep(hasInteracted: Bool) -> Bool { !hasInteracted }

    /// 入场扫动的三态。⚠️ **不能用 Bool**：`#330` 第一版用 `introPlayed: Bool`，把「重放一次」
    /// 换成了**持久错态** —— 扫到 peak 之后、回程之前视图 disappear，`Task.sleep` 抛出、
    /// 回程不执行，而布尔已置真 ⇒ 把手**永远停在 peak**，只有用户拖一下才恢复。
    /// LazyVStack 快速滚动让 cell 停留不足 `sweepDuration` 是常态，不是边角。
    enum IntroPhase: Equatable, Sendable {
        case pending
        case sweeping
        case done
    }

    enum IntroAction: Equatable, Sendable {
        case idle
        case sweep
        case settleOnly
    }

    /// ⚠️ `.sweeping` 一律判 `.settleOnly`，**与 `sweep` 是否为 nil 无关** ——
    /// 隐藏期间用户打开 Reduce Motion 时 `introSweep(reduceMotion:)` 返回 nil，
    /// 若在这里跟着返回 `.idle`，把手就又卡在 peak 上了。
    static func introAction(phase: IntroPhase, sweep: BeforeAfterIntroSweep?) -> IntroAction {
        switch phase {
        case .done: .idle
        case .sweeping: .settleOnly
        case .pending: sweep == nil ? .idle : .sweep
        }
    }

    static func fraction(dragX: CGFloat, width: CGFloat) -> CGFloat {
        Self.fraction(dragCoordinate: dragX, extent: width)
    }

    static func fraction(dragCoordinate: CGFloat, extent: CGFloat) -> CGFloat {
        guard extent > 0 else { return Self.initialFraction }
        return Self.clamp01(dragCoordinate / extent)
    }

    static func revealWidth(fraction: CGFloat, width: CGFloat) -> CGFloat {
        Self.clamp01(fraction) * max(0, width)
    }

    static func leadingInset(fraction: CGFloat, width: CGFloat) -> CGFloat {
        max(0, Self.revealWidth(fraction: fraction, width: width) - Self.handleHitSize / 2)
    }

    static func clamp01(_ value: CGFloat) -> CGFloat { min(1, max(0, value)) }

    /// 分隔轴——`.stacked` 是竖轴，其余两个形态是横轴。
    static func axis(for layout: BeforeAfterSliderLayout) -> Axis {
        layout == .stacked ? .vertical : .horizontal
    }

    /// 并排 / 堆叠形态下两个窗格各自的长度：和为 `max(0, extent)`，`extent ≤ 0` 时两者为 0。
    static func paneExtents(fraction: CGFloat, extent: CGFloat) -> (first: CGFloat, second: CGFloat) {
        let clampedExtent = max(0, extent)
        let first = Self.clamp01(fraction) * clampedExtent
        return (first, clampedExtent - first)
    }
}

// MARK: - 揭示裁剪（**裁剪**，不是 alpha 遮罩）

struct BeforeAfterRevealClip: Shape {
    var width: CGFloat

    var animatableData: CGFloat {
        get { self.width }
        set { self.width = newValue }
    }

    func path(in rect: CGRect) -> Path {
        Path(CGRect(
            x: rect.minX,
            y: rect.minY,
            width: min(max(0, self.width), rect.width),
            height: rect.height
        ))
    }
}

// MARK: - 把手

struct BeforeAfterSliderHandle: View {
    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.contentOnEmphasis)
                .frame(width: BeforeAfterSweep.dividerWidth)
            Circle()
                .fill(Color.contentOnEmphasis)
                .frame(width: BeforeAfterSweep.handleDiameter, height: BeforeAfterSweep.handleDiameter)
                .overlay {
                    Image(systemName: "arrow.left.and.right")
                        .font(.system(size: CoreControlMetrics.iconSize(for: .mini), weight: .semibold))
                        // ⚠️ 把手恒为白，而 contentPrimary 深色下也是白 ⇒ 深色下图标不可见。
                        // 既有问题，非本次引入；修它需要一个「恒定深色」token，本仓没有
                        // （darkText 在 macOS 退化为随外观切换的 textColor，grey9 明暗镜像）。
                        .foregroundStyle(Color.contentPrimary)
                }
        }
        .frame(minWidth: BeforeAfterSweep.handleHitSize, minHeight: BeforeAfterSweep.handleHitSize)
        .contentShape(Rectangle())
    }
}

// ⚠️ 与 BeforeAfterSliderHandle 是两份独立几何，不靠 rotationEffect 转——本文件零 motionCalls 子串。
struct BeforeAfterSliderStackedHandle: View {
    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.contentOnEmphasis)
                .frame(height: BeforeAfterSweep.dividerWidth)
            Circle()
                .fill(Color.contentOnEmphasis)
                .frame(width: BeforeAfterSweep.handleDiameter, height: BeforeAfterSweep.handleDiameter)
                .overlay {
                    Image(systemName: "arrow.up.and.down")
                        .font(.system(size: CoreControlMetrics.iconSize(for: .mini), weight: .semibold))
                        .foregroundStyle(Color.contentPrimary)
                }
        }
        .frame(minWidth: BeforeAfterSweep.handleHitSize, minHeight: BeforeAfterSweep.handleHitSize)
        .contentShape(Rectangle())
    }
}

// MARK: - 绘制层（不含手势与状态）

struct BeforeAfterSliderBody<Before: View, After: View>: View {
    let fraction: CGFloat
    let labels: BeforeAfterSliderLabels
    let layout: BeforeAfterSliderLayout
    let before: Before
    let after: After

    init(
        fraction: CGFloat,
        labels: BeforeAfterSliderLabels,
        layout: BeforeAfterSliderLayout = .overlay,
        before: Before,
        after: After
    ) {
        self.fraction = fraction
        self.labels = labels
        self.layout = layout
        self.before = before
        self.after = after
    }

    var body: some View {
        GeometryReader { proxy in
            switch self.layout {
            case .overlay:
                self.overlayBody(size: proxy.size)
            case .sideBySide:
                self.sideBySideBody(size: proxy.size)
            case .stacked:
                self.stackedBody(size: proxy.size)
            }
        }
    }

    // MARK: - .overlay（现状）

    private func overlayBody(size: CGSize) -> some View {
        let reveal = BeforeAfterSweep.revealWidth(fraction: self.fraction, width: size.width)

        return ZStack(alignment: .topLeading) {
            self.after
                .frame(width: size.width, height: size.height)
                .clipped()

            self.before
                .frame(width: size.width, height: size.height)
                .clipped()
                .clipShape(BeforeAfterRevealClip(width: reveal))

            self.labelOverlay(width: size.width)

            HStack(spacing: 0) {
                Color.clear
                    .frame(width: BeforeAfterSweep.leadingInset(fraction: self.fraction, width: size.width))
                BeforeAfterSliderHandle()
                Spacer(minLength: 0)
            }
        }
    }

    // MARK: - .sideBySide

    private func sideBySideBody(size: CGSize) -> some View {
        let extents = BeforeAfterSweep.paneExtents(fraction: self.fraction, extent: size.width)

        return ZStack(alignment: .topLeading) {
            HStack(spacing: 0) {
                self.before
                    .frame(width: extents.first, height: size.height)
                    .clipped()
                    .overlay(alignment: .topLeading) { self.paneChip(self.beforeLabelText) }
                    .clipped()
                self.after
                    .frame(width: extents.second, height: size.height)
                    .clipped()
                    .overlay(alignment: .topLeading) { self.paneChip(self.afterLabelText) }
                    .clipped()
            }

            HStack(spacing: 0) {
                Color.clear
                    .frame(width: BeforeAfterSweep.leadingInset(fraction: self.fraction, width: size.width))
                BeforeAfterSliderHandle()
                Spacer(minLength: 0)
            }
        }
    }

    // MARK: - .stacked

    private func stackedBody(size: CGSize) -> some View {
        let extents = BeforeAfterSweep.paneExtents(fraction: self.fraction, extent: size.height)

        return ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                self.before
                    .frame(width: size.width, height: extents.first)
                    .clipped()
                    .overlay(alignment: .topLeading) { self.paneChip(self.beforeLabelText) }
                    .clipped()
                self.after
                    .frame(width: size.width, height: extents.second)
                    .clipped()
                    .overlay(alignment: .topLeading) { self.paneChip(self.afterLabelText) }
                    .clipped()
            }

            VStack(spacing: 0) {
                Color.clear
                    .frame(height: BeforeAfterSweep.leadingInset(fraction: self.fraction, width: size.height))
                BeforeAfterSliderStackedHandle()
                Spacer(minLength: 0)
            }
        }
    }

    // MARK: - 标签：.overlay 走跨两侧的居中标签对，.sideBySide / .stacked 各窗格自带一枚

    private var beforeLabelText: Text? {
        switch self.labels {
        case .hidden: nil
        case .standard: Text(BeforeAfterSliderLabels.defaultBefore)
        case let .shown(before, _): Text(before)
        }
    }

    private var afterLabelText: Text? {
        switch self.labels {
        case .hidden: nil
        case .standard: Text(BeforeAfterSliderLabels.defaultAfter)
        case let .shown(_, after): Text(after)
        }
    }

    @ViewBuilder
    private func labelOverlay(width: CGFloat) -> some View {
        switch self.labels {
        case .hidden:
            EmptyView()
        case .standard:
            self.labelPair(
                before: Text(BeforeAfterSliderLabels.defaultBefore),
                after: Text(BeforeAfterSliderLabels.defaultAfter)
            )
        case let .shown(before, after):
            self.labelPair(before: Text(before), after: Text(after))
        }
    }

    private func labelPair(before: Text, after: Text) -> some View {
        HStack {
            self.chip(before)
            Spacer(minLength: CoreSpacing.sm)
            self.chip(after)
        }
        .padding(CoreSpacing.sm)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func paneChip(_ text: Text?) -> some View {
        if let text {
            self.chip(text)
                .padding(CoreSpacing.sm)
                .accessibilityHidden(true)
        }
    }

    private func chip(_ text: Text) -> some View {
        text
            .font(.caption2.weight(.semibold))
            .foregroundStyle(Color.contentPrimary)
            .padding(.horizontal, CoreSpacing.sm)
            .padding(.vertical, CoreSpacing.xs)
            .background(Color.quaternaryFill, in: Capsule())
    }
}

// MARK: - 公开入口

/// 拖动分隔线对比"之前 / 之后"两张图的滑块。典型用途：修图前后、主题深浅、
/// 优化前后的截图对照。
public struct BeforeAfterSlider<Before: View, After: View>: View {
    private let labels: BeforeAfterSliderLabels
    private let layout: BeforeAfterSliderLayout
    private let before: Before
    private let after: After

    @State private var fraction: CGFloat = BeforeAfterSweep.initialFraction

    @State private var hasInteracted = false

    @State private var introPhase = BeforeAfterSweep.IntroPhase.pending

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// - Parameters:
    ///   - labels: 两侧标签的取值域，默认 `.standard`。见 `BeforeAfterSliderLabels`。
    ///   - layout: 排布形态，默认 `.overlay`（现状：两层叠放、分隔线裁切）。见 `BeforeAfterSliderLayout`。
    ///   - before: 分隔线**左侧 / 上侧**露出的内容（"之前"）。
    ///   - after: 分隔线**右侧 / 下侧**露出的内容（"之后"）。
    public init(
        labels: BeforeAfterSliderLabels = .standard,
        layout: BeforeAfterSliderLayout = .overlay,
        @ViewBuilder before: () -> Before,
        @ViewBuilder after: () -> After
    ) {
        self.labels = labels
        self.layout = layout
        self.before = before()
        self.after = after()
    }

    public var body: some View {
        GeometryReader { proxy in
            BeforeAfterSliderBody(
                fraction: self.fraction,
                labels: self.labels,
                layout: self.layout,
                before: self.before,
                after: self.after
            )
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        self.hasInteracted = true
                        let axis = BeforeAfterSweep.axis(for: self.layout)
                        let extent = axis == .vertical ? proxy.size.height : proxy.size.width
                        let coordinate = axis == .vertical ? value.location.y : value.location.x
                        self.fraction = BeforeAfterSweep.fraction(dragCoordinate: coordinate, extent: extent)
                    }
            )
        }
        .task { await self.playIntroSweep(BeforeAfterSweep.introSweep(reduceMotion: self.reduceMotion)) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(BeforeAfterSliderChrome.accessibilityTitle))
        .accessibilityValue(Text(Double(self.fraction), format: .percent.precision(.fractionLength(0))))
        .accessibilityAdjustableAction { direction in
            let step: CGFloat = 0.05
            switch direction {
            case .increment: self.fraction = BeforeAfterSweep.clamp01(self.fraction + step)
            case .decrement: self.fraction = BeforeAfterSweep.clamp01(self.fraction - step)
            @unknown default: break
            }
        }
    }

    private func playIntroSweep(_ sweep: BeforeAfterIntroSweep?) async {
        switch BeforeAfterSweep.introAction(phase: self.introPhase, sweep: sweep) {
        case .idle:
            return
        case .settleOnly:
            self.introPhase = .done
            self.settleAfterIntro(duration: sweep?.duration ?? BeforeAfterSweep.sweepDuration)
        case .sweep:
            guard let sweep else { return }
            self.introPhase = .sweeping
            withAnimation(.easeInOut(duration: sweep.duration)) { self.fraction = sweep.peak }
            do {
                try await Task.sleep(for: .seconds(sweep.duration))
            } catch {
                return
            }
            self.introPhase = .done
            self.settleAfterIntro(duration: sweep.duration)
        }
    }

    private func settleAfterIntro(duration: Double) {
        guard BeforeAfterSweep.settlesAfterSweep(hasInteracted: self.hasInteracted) else { return }
        withAnimation(.easeInOut(duration: duration)) { self.fraction = BeforeAfterSweep.initialFraction }
    }
}

// MARK: - 布局形态扩展点（#312 · 形态 D2）

/// `BeforeAfterSlider` 的排布形态。
///
/// ⚠️ **本枚举是 `#312` 给 `BeforeAfterSlider` 补的样式扩展点**（形态 D2 配置枚举）——
/// `#299` 步骤 2 枚举出的两个业界替代形态各对应一个 case，来源见 `docs/components/before-after-slider.md`
/// 的 `#299` 重判小节。
///
/// ⚠️ **「配置枚举可演进」不是零代价**：本枚举**非 `@frozen`**，加 case 对下游任何
/// 穷举 `switch` 都是 source-breaking（下游要写 `@unknown default` 才免疫）。
public nonisolated enum BeforeAfterSliderLayout: Sendable, Equatable, CaseIterable {
    /// 默认：两层叠放在同一块画布上，`before` 按分隔线位置裁切揭示（现状形态）。
    case overlay
    /// 左右并排两幅完整图——分隔线只改两个窗格的宽度比，两侧内容都不被裁切成"半张图"。
    /// 业界来源：Adobe Lightroom Classic 的 Before & After left/right 视图。
    case sideBySide
    /// 上下并排两幅完整图，主轴由横改纵，拖拽与把手随之切到竖向。
    /// 业界来源：Adobe Lightroom Classic 的 Before & After top/bottom 视图。
    case stacked
}

#Preview("BeforeAfterSlider") {
    BeforeAfterSlider {
        Rectangle().fill(Color.surfaceRaised)
            .overlay { Image(systemName: "photo").font(.system(size: 44)).foregroundStyle(Color.contentTertiary) }
    } after: {
        Rectangle().fill(Color.secondaryFill)
            .overlay { Image(systemName: "wand.and.stars").font(.system(size: 44)).foregroundStyle(.tint) }
    }
    .frame(width: 320, height: 200)
    .clipShape(CoreShape.rounded(CoreRadius.large))
    .padding(CoreSpacing.xxl)
}

#Preview("BeforeAfterSlider — 自定义文案 / 无标签") {
    VStack(spacing: CoreSpacing.xl) {
        BeforeAfterSlider(labels: .shown(before: "Draft", after: "Final")) {
            Rectangle().fill(Color.surfaceRaised)
        } after: {
            Rectangle().fill(Color.secondaryFill)
        }
        .frame(width: 300, height: 120)

        BeforeAfterSlider(labels: .hidden) {
            Rectangle().fill(Color.surfaceRaised)
        } after: {
            Rectangle().fill(Color.secondaryFill)
        }
        .frame(width: 300, height: 120)
    }
    .padding(CoreSpacing.xxl)
}

#Preview("BeforeAfterSlider — .sideBySide / .stacked") {
    VStack(spacing: CoreSpacing.xl) {
        BeforeAfterSlider(layout: .sideBySide) {
            Rectangle().fill(Color.surfaceRaised)
                .overlay { Image(systemName: "photo").font(.system(size: 32)).foregroundStyle(Color.contentTertiary) }
        } after: {
            Rectangle().fill(Color.secondaryFill)
                .overlay { Image(systemName: "wand.and.stars").font(.system(size: 32)).foregroundStyle(.tint) }
        }
        .frame(width: 300, height: 160)

        BeforeAfterSlider(layout: .stacked) {
            Rectangle().fill(Color.surfaceRaised)
                .overlay { Image(systemName: "photo").font(.system(size: 32)).foregroundStyle(Color.contentTertiary) }
        } after: {
            Rectangle().fill(Color.secondaryFill)
                .overlay { Image(systemName: "wand.and.stars").font(.system(size: 32)).foregroundStyle(.tint) }
        }
        .frame(width: 220, height: 260)
    }
    .padding(CoreSpacing.xxl)
}
