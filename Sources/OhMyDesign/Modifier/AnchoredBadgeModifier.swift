import SwiftUI

// MARK: - AnchoredBadgeContent

/// 锚定徽标的内容：红点、计数或短文本。
public nonisolated enum AnchoredBadgeContent: Equatable {
    /// 不带文字的红点。
    case dot
    /// 计数；`≤ 0` 时不显示，超过 `max` 时显示为 `"\(max)+"`。
    case count(Int, max: Int = 99)
    /// 调用方提供的短文案（本地化键，按 `Bundle.main` 解析）；空键时不显示。
    case text(LocalizedStringKey)

    var isVisible: Bool {
        switch self {
        case .dot: true
        case .count(let value, _): value > 0
        case .text(let key): key != LocalizedStringKey("")
        }
    }

    static func countText(value: Int, max limit: Int) -> String {
        let cap = Swift.max(limit, 1)
        return value > cap ? "\(cap)+" : "\(value)"
    }

    var countText: String? {
        guard case .count(let value, let limit) = self else { return nil }
        return Self.countText(value: value, max: limit)
    }

    var countValue: Int? {
        guard case .count(let value, _) = self else { return nil }
        return value
    }

    /// 徽标对辅助技术的朗读文本；不显示时为 `nil`。
    ///
    /// 宿主自带 `accessibilityValue` 时，SwiftUI 无法把两者自动合并，调用方用本属性自行拼接。
    @MainActor public var accessibilityText: Text? {
        guard self.isVisible else { return nil }
        switch self {
        case .dot:
            return Text(Self.newChrome)
        case .count:
            return self.countText.map { Text(verbatim: $0) }
        case .text(let key):
            return Text(key)
        }
    }

    @MainActor static var newChrome: LocalizedStringResource {
        LocalizedStringResource("New", bundle: .atURL(Bundle.module.bundleURL))
    }
}

// MARK: - AnchoredBadgePlacement

/// 锚定徽标贴在宿主的哪个角。
public nonisolated enum AnchoredBadgePlacement: Sendable, Equatable, CaseIterable {
    /// 右上角（RTL 下为左上）。
    case topTrailing
    /// 左上角（RTL 下为右上）。
    case topLeading
    /// 右下角（RTL 下为左下）。
    case bottomTrailing
    /// 左下角（RTL 下为右下）。
    case bottomLeading

    var isTop: Bool { self == .topTrailing || self == .topLeading }
    var isTrailing: Bool { self == .topTrailing || self == .bottomTrailing }
}

// MARK: - AnchoredBadgeHostShape

/// 宿主的外形，决定徽标锚点落在哪里。
public nonisolated enum AnchoredBadgeHostShape: Sendable, Equatable, CaseIterable {
    /// 矩形宿主（图标、卡片）：锚点在边界框的角上。
    case rectangle
    /// 圆形宿主（头像）：锚点在内切圆的 45° 点上，并带一圈 `surfaceCanvas` 分隔环。
    case circle

    func cornerInset(hostSize: CGSize) -> CGSize {
        switch self {
        case .rectangle:
            return .zero
        case .circle:
            let diameter = Swift.min(hostSize.width, hostSize.height)
            let along = diameter / 2 * (1 - 1 / 2.0.squareRoot())
            return CGSize(
                width: (hostSize.width - diameter) / 2 + along,
                height: (hostSize.height - diameter) / 2 + along
            )
        }
    }
}

// MARK: - 计数滚动与出现 / 消失 / Count roll and appearance

nonisolated struct AnchoredBadgeCountRoll: Equatable, Sendable {
    let previous: Int
    let value: Int
}

nonisolated enum AnchoredBadgeTransitionKind: Equatable, Sendable {
    case scale
    case fade
}

// MARK: - AnchoredBadgeModifier

struct AnchoredBadgeModifier: ViewModifier {
    static let fill: Color = .badgeFill
    static let foreground: Color = .contentOnEmphasis
    static let ring: Color = .surfaceCanvas
    static let appearanceScale: CGFloat = 0.6

    let content: AnchoredBadgeContent
    let placement: AnchoredBadgePlacement
    let hostShape: AnchoredBadgeHostShape

    @Environment(\.coreMotionPresentation) private var motionPresentation
    @State private var roll: AnchoredBadgeCountRoll?

    @ScaledMetric(relativeTo: .caption) private var dotSize: CGFloat = 10
    @ScaledMetric(relativeTo: .caption) private var labelHeight: CGFloat = 20
    @ScaledMetric(relativeTo: .caption) private var labelPadding: CGFloat = 6
    @ScaledMetric(relativeTo: .caption) private var ringWidth: CGFloat = 2

    nonisolated static func badgeOrigin(
        hostSize: CGSize,
        badgeSize: CGSize,
        placement: AnchoredBadgePlacement,
        hostShape: AnchoredBadgeHostShape
    ) -> CGPoint {
        let inset = hostShape.cornerInset(hostSize: hostSize)
        let half = badgeSize.height / 2
        let x = placement.isTrailing
            ? hostSize.width - inset.width - half
            : inset.width + half - badgeSize.width
        let y = placement.isTop
            ? inset.height - half
            : hostSize.height - inset.height - half
        return CGPoint(x: x, y: y)
    }

    nonisolated static func nextRoll(
        _ current: AnchoredBadgeCountRoll?,
        value: Int?,
        isVisible: Bool
    ) -> AnchoredBadgeCountRoll? {
        guard let value, isVisible else { return nil }
        guard let current else { return AnchoredBadgeCountRoll(previous: value, value: value) }
        return AnchoredBadgeCountRoll(previous: current.value, value: value)
    }

    nonisolated static func appearanceKind(motion: MotionPresentation) -> AnchoredBadgeTransitionKind {
        motion == .animated ? .scale : .fade
    }

    func body(content: Content) -> some View {
        let accessibilityText = self.content.accessibilityText
        return content
            .accessibilityValue(accessibilityText ?? Text(verbatim: String()), isEnabled: accessibilityText != nil)
            .overlay { self.badgeLayer }
            .onChange(of: self.content, initial: true) { _, content in
                self.roll = Self.nextRoll(self.roll, value: content.countValue, isVisible: content.isVisible)
            }
    }

    @ViewBuilder
    private var badgeLayer: some View {
        GeometryReader { proxy in
            let host = proxy.size
            let placement = self.placement
            let hostShape = self.hostShape
            ZStack(alignment: .topLeading) {
                Color.clear
                if self.content.isVisible {
                    self.badge
                        .transition(self.appearanceTransition)
                        .alignmentGuide(.leading) { dimensions in
                            -Self.badgeOrigin(
                                hostSize: host,
                                badgeSize: CGSize(width: dimensions.width, height: dimensions.height),
                                placement: placement,
                                hostShape: hostShape
                            ).x
                        }
                        .alignmentGuide(.top) { dimensions in
                            -Self.badgeOrigin(
                                hostSize: host,
                                badgeSize: CGSize(width: dimensions.width, height: dimensions.height),
                                placement: placement,
                                hostShape: hostShape
                            ).y
                        }
                }
            }
        }
        .accessibilityHidden(true)
        .coreAnimation(.reveal, value: self.content.isVisible)
        .coreAnimation(.reveal, value: self.roll)
    }

    private var appearanceTransition: AnyTransition {
        switch Self.appearanceKind(motion: self.motionPresentation) {
        case .scale:
            .scale(scale: Self.appearanceScale).combined(with: .opacity)
        case .fade:
            .opacity
        }
    }

    @ViewBuilder
    private var badge: some View {
        let body = self.badgeBody
        if self.hostShape == .circle {
            body.background {
                Capsule(style: .continuous)
                    .fill(Self.ring)
                    .padding(-self.ringWidth)
            }
        } else {
            body
        }
    }

    @ViewBuilder
    private var badgeBody: some View {
        switch self.content {
        case .dot:
            Circle()
                .fill(Self.fill)
                .frame(width: self.dotSize, height: self.dotSize)
        case .count(let value, let limit):
            let shown = self.roll?.value ?? value
            self.pill(Text(verbatim: AnchoredBadgeContent.countText(value: shown, max: limit)))
                .contentTransition(self.motionPresentation.numericRoll(from: self.roll?.previous ?? shown, to: shown))
        case .text(let key):
            self.pill(Text(key))
        }
    }

    private func pill(_ text: Text) -> some View {
        text
            .coreFont(.caption)
            .fontWeight(.semibold)
            .monospacedDigit()
            .lineLimit(1)
            .foregroundStyle(Self.foreground)
            .padding(.horizontal, self.labelPadding)
            .frame(minWidth: self.labelHeight, minHeight: self.labelHeight)
            .background(Capsule(style: .continuous).fill(Self.fill))
            .fixedSize()
    }
}

// MARK: - View + anchoredBadge

public extension View {
    /// 在宿主的一个角上叠加红点 / 计数 / 短文案徽标，不改变宿主布局尺寸。
    ///
    /// 取色为 `badgeFill`（系统红）底 + `contentOnEmphasis` 前景，与 iOS 系统角标一致，不跟随 accent。
    /// 徽标纵向中心落在锚点上，横向只伸进宿主半个徽标高度、宽度增长全部朝外。
    /// 徽标对辅助技术隐藏；显示时把 `content.accessibilityText` 设为宿主的 `accessibilityValue`。
    ///
    /// - Parameters:
    ///   - content: 徽标内容，见 `AnchoredBadgeContent`；计数 `≤ 0` 或空文案时不显示。
    ///   - placement: 贴靠的角，默认 `.topTrailing`。
    ///   - hostShape: 宿主外形，默认 `.rectangle`；圆形头像传 `.circle`。
    /// - Returns: 叠加了徽标的视图。
    func anchoredBadge(
        _ content: AnchoredBadgeContent,
        placement: AnchoredBadgePlacement = .topTrailing,
        hostShape: AnchoredBadgeHostShape = .rectangle
    ) -> some View {
        self.modifier(AnchoredBadgeModifier(content: content, placement: placement, hostShape: hostShape))
    }
}

// MARK: - Preview

#Preview("anchoredBadge") {
    HStack(spacing: CoreSpacing.xxl) {
        Avatar(name: "Evan", size: .fixed(CoreSpacing.xxxxl))
            .clipShape(Circle())
            .anchoredBadge(.count(120), hostShape: .circle)
        Image(systemName: "bell.fill")
            .font(.title)
            .anchoredBadge(.dot)
        Image(systemName: "envelope.fill")
            .font(.title)
            .anchoredBadge(.count(120, max: 99))
        Image(systemName: "gift.fill")
            .font(.title)
            .anchoredBadge(.text("NEW"), placement: .topLeading)
    }
    .padding(CoreSpacing.xxxl)
    .background(Color.surfaceCanvas)
}
