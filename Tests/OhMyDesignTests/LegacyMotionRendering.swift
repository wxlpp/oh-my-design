import SwiftUI
@testable import OhMyDesign

// MARK: - #407 之前的按压实现（原样拷贝，供逐像素对照）

struct LegacyButtonBackgroundModifier<S: InsettableShape>: ViewModifier {
    let shape: S
    let fill: Color
    let border: Color
    let isPressed: Bool
    var pressedOpacity: Double?

    func body(content: Content) -> some View {
        content
            .background(
                self.shape
                    .fill(self.fill)
            )
            .overlay(
                self.shape
                    .strokeBorder(self.border, lineWidth: CoreBorderWidth.hairline)
            )
            .scaleEffect(self.isPressed ? CoreButtonMetrics.pressedScale : 1)
            .opacity(self.isPressed ? (self.pressedOpacity ?? 1) : 1)
            .animation(.snappy(duration: 0.16), value: self.isPressed)
    }
}

struct LegacyTelegramGlassButtonModifier<S: InsettableShape>: ViewModifier {
    let shape: S
    let isPressed: Bool
    let border: Color?
    let pressFeedback: Bool

    func body(content: Content) -> some View {
        content
            .background(
                self.shape
                    .inset(by: CoreButtonMetrics.glassInset)
                    .fill(.background)
                    .glassEffect()
            )
            .overlay(
                self.shape.strokeBorder(
                    self.border ?? Color.white.opacity(CoreButtonMetrics.glassBorderOpacity),
                    lineWidth: CoreBorderWidth.hairline
                )
            )
            .scaleEffect(self.pressFeedback && self.isPressed ? CoreButtonMetrics.pressedScale : 1)
            .animation(self.pressFeedback ? Animation.snappy(duration: 0.16) : nil, value: self.isPressed)
    }
}

// MARK: - #408 之前的 anchoredBadge（原样拷贝，供逐像素对照）

struct LegacyAnchoredBadgeModifier: ViewModifier {
    let content: AnchoredBadgeContent
    let placement: AnchoredBadgePlacement
    let hostShape: AnchoredBadgeHostShape

    @ScaledMetric(relativeTo: .caption) private var dotSize: CGFloat = 10
    @ScaledMetric(relativeTo: .caption) private var labelHeight: CGFloat = 20
    @ScaledMetric(relativeTo: .caption) private var labelPadding: CGFloat = 6
    @ScaledMetric(relativeTo: .caption) private var ringWidth: CGFloat = 2

    func body(content: Content) -> some View {
        let accessibilityText = self.content.accessibilityText
        return content
            .accessibilityValue(accessibilityText ?? Text(verbatim: String()), isEnabled: accessibilityText != nil)
            .overlay {
                if self.content.isVisible {
                    GeometryReader { proxy in
                        let host = proxy.size
                        let placement = self.placement
                        let hostShape = self.hostShape
                        ZStack(alignment: .topLeading) {
                            Color.clear
                            self.badge
                                .alignmentGuide(.leading) { dimensions in
                                    -AnchoredBadgeModifier.badgeOrigin(
                                        hostSize: host,
                                        badgeSize: CGSize(width: dimensions.width, height: dimensions.height),
                                        placement: placement,
                                        hostShape: hostShape
                                    ).x
                                }
                                .alignmentGuide(.top) { dimensions in
                                    -AnchoredBadgeModifier.badgeOrigin(
                                        hostSize: host,
                                        badgeSize: CGSize(width: dimensions.width, height: dimensions.height),
                                        placement: placement,
                                        hostShape: hostShape
                                    ).y
                                }
                        }
                    }
                    .accessibilityHidden(true)
                }
            }
    }

    @ViewBuilder
    private var badge: some View {
        let body = self.badgeBody
        if self.hostShape == .circle {
            body.background {
                Capsule(style: .continuous)
                    .fill(AnchoredBadgeModifier.ring)
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
                .fill(AnchoredBadgeModifier.fill)
                .frame(width: self.dotSize, height: self.dotSize)
        case .count:
            self.pill(Text(verbatim: self.content.countText ?? String()))
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
            .foregroundStyle(AnchoredBadgeModifier.foreground)
            .padding(.horizontal, self.labelPadding)
            .frame(minWidth: self.labelHeight, minHeight: self.labelHeight)
            .background(Capsule(style: .continuous).fill(AnchoredBadgeModifier.fill))
            .fixedSize()
    }
}
