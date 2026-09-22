import SwiftUI

// MARK: - AnchoredBadgeContent

/// 锚定徽标的内容：红点、计数或短文本。
public nonisolated enum AnchoredBadgeContent: Sendable, Equatable {
    /// 不带文字的红点。
    case dot
    /// 计数；`≤ 0` 时不显示，超过 `max` 时显示为 `"\(max)+"`。
    case count(Int, max: Int = 99)
    /// 调用方提供的短文本，原样显示；空串时不显示。
    case text(String)

    var isVisible: Bool {
        switch self {
        case .dot: true
        case .count(let value, _): value > 0
        case .text(let text): !text.isEmpty
        }
    }

    var displayText: String? {
        switch self {
        case .dot:
            nil
        case .count(let value, let limit):
            value > Swift.max(limit, 1) ? "\(Swift.max(limit, 1))+" : "\(value)"
        case .text(let text):
            text
        }
    }

    @MainActor var accessibilityValueText: String? {
        guard self.isVisible else { return nil }
        switch self {
        case .dot:
            return String(localized: "New", bundle: .module)
        case .count, .text:
            return self.displayText
        }
    }
}

// MARK: - AnchoredBadgePlacement

/// 锚定徽标贴在宿主的哪个角；徽标中心落在该角上。
public nonisolated enum AnchoredBadgePlacement: Sendable, Equatable, CaseIterable {
    /// 右上角（RTL 下为左上）。
    case topTrailing
    /// 左上角（RTL 下为右上）。
    case topLeading
    /// 右下角（RTL 下为左下）。
    case bottomTrailing
    /// 左下角（RTL 下为右下）。
    case bottomLeading

    var alignment: Alignment {
        switch self {
        case .topTrailing: .topTrailing
        case .topLeading: .topLeading
        case .bottomTrailing: .bottomTrailing
        case .bottomLeading: .bottomLeading
        }
    }
}

// MARK: - AnchoredBadgeModifier

struct AnchoredBadgeModifier: ViewModifier {
    static let fill: Color = .statusDangerEmphasis
    static let foreground: Color = .contentOnEmphasis

    let content: AnchoredBadgeContent
    let placement: AnchoredBadgePlacement

    @ScaledMetric(relativeTo: .caption2) private var dotSize: CGFloat = 10
    @ScaledMetric(relativeTo: .caption2) private var labelHeight: CGFloat = 18

    func body(content: Content) -> some View {
        let accessibilityValue = self.content.accessibilityValueText
        return content
            .overlay(alignment: self.placement.alignment) {
                if self.content.isVisible {
                    self.badge
                        .alignmentGuide(.top) { $0.height / 2 }
                        .alignmentGuide(.bottom) { $0.height / 2 }
                        .alignmentGuide(.leading) { $0.width / 2 }
                        .alignmentGuide(.trailing) { $0.width / 2 }
                        .accessibilityHidden(true)
                }
            }
            .accessibilityValue(
                Text(verbatim: accessibilityValue ?? String()),
                isEnabled: accessibilityValue != nil
            )
    }

    @ViewBuilder
    private var badge: some View {
        if let text = self.content.displayText {
            Text(verbatim: text)
                .coreFont(.caption2)
                .fontWeight(.semibold)
                .monospacedDigit()
                .lineLimit(1)
                .foregroundStyle(Self.foreground)
                .padding(.horizontal, CoreSpacing.xs + CoreSpacing.xxs / 2)
                .frame(minWidth: self.labelHeight, minHeight: self.labelHeight)
                .background(Capsule(style: .continuous).fill(Self.fill))
                .fixedSize()
        } else {
            Circle()
                .fill(Self.fill)
                .frame(width: self.dotSize, height: self.dotSize)
        }
    }
}

// MARK: - View + anchoredBadge

public extension View {
    /// 在宿主的一个角上叠加红点 / 计数 / 短文本徽标；计数并入宿主的可访问值。
    ///
    /// 取色固定为 `statusDangerEmphasis` 底 + `contentOnEmphasis` 前景，与系统角标一致，
    /// 不跟随 accent。与 SwiftUI 的 `.badge(_:)`（只作用于 `List` 行与 `TabView`）无关。
    ///
    /// - Parameters:
    ///   - content: 徽标内容，见 `AnchoredBadgeContent`；计数 `≤ 0` 或空文本时不显示。
    ///   - placement: 贴靠的角，默认 `.topTrailing`。
    /// - Returns: 叠加了徽标的视图。
    func anchoredBadge(
        _ content: AnchoredBadgeContent,
        placement: AnchoredBadgePlacement = .topTrailing
    ) -> some View {
        self.modifier(AnchoredBadgeModifier(content: content, placement: placement))
    }
}

// MARK: - Preview

#Preview("anchoredBadge") {
    HStack(spacing: CoreSpacing.xxl) {
        Avatar(name: "Evan")
            .frame(width: CoreSpacing.xxxxl, height: CoreSpacing.xxxxl)
            .clipShape(Circle())
            .anchoredBadge(.count(3))
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
