import SwiftUI

// MARK: - BannerPalette

struct BannerPalette {
    let icon: Color
    let foreground: Color
    let background: Color
    let border: Color
}

// MARK: - Banner

/// 页内信息表面，按状态语义配描边或填充；浮层反馈请改用 `ToastHost`。
///
/// Banner 无状态：`onDismiss` 只回调，由调用方把它从视图树中移除。
public struct Banner<Label: View>: View {
    /// 创建只有正文的 Banner。
    ///
    /// - Parameters:
    ///   - level: 语义等级，决定图标与配色（见 `StatusLevel`）。
    ///   - label: banner 正文视图，通常为 `Text`。
    public init(level: StatusLevel, @ViewBuilder label: () -> Label) {
        self.configuration = .init(label: .init(label()), level: level, title: nil, actions: nil, dismiss: nil)
    }

    public var body: some View {
        AnyView(self.style.makeBody(configuration: self.configuration))
    }

    @Environment(\.bannerStyle) var style

    let configuration: BannerStyleConfiguration
}

public extension Banner where Label == Text {
    /// 创建带标题、正文、动作与关闭钮的 Banner。
    ///
    /// - Parameters:
    ///   - level: 语义等级，决定图标与配色（见 `StatusLevel`）。
    ///   - title: 可选标题，以 headline 字重显示在正文之上。
    ///   - message: 正文文案。
    ///   - actions: 动作按钮，横排放不下时自动竖排；样式由调用方决定。
    ///   - onDismiss: 关闭回调；非 `nil` 时显示关闭钮，由调用方移除 Banner。
    init<Actions: View>(
        level: StatusLevel,
        title: LocalizedStringKey? = nil,
        message: LocalizedStringKey,
        @ViewBuilder actions: () -> Actions = { EmptyView() },
        onDismiss: (() -> Void)? = nil
    ) {
        let actionsView = actions()
        self.configuration = .init(
            label: .init(Text(message)),
            level: level,
            title: title.map { Text($0) },
            actions: actionsView is EmptyView ? nil : AnyView(actionsView),
            dismiss: onDismiss
        )
    }
}

// MARK: - BannerStyle

/// `Banner` 视觉外观的扩展点，形态对齐 Apple `ButtonStyle` / `ToggleStyle`。
public protocol BannerStyle {
    associatedtype Body: View

    @ViewBuilder
    @MainActor @preconcurrency
    func makeBody(configuration: Self.Configuration) -> Body

    typealias Configuration = BannerStyleConfiguration
}

// MARK: - BannerStyleConfiguration

/// 传给 `BannerStyle.makeBody` 的上下文：语义等级、正文与可选的标题 / 动作 / 关闭回调。
public struct BannerStyleConfiguration {
    public typealias Label = AnyView

    /// 正文视图。
    public let label: Label
    /// 语义等级。
    public let level: StatusLevel
    /// 可选标题。
    public let title: Text?
    /// 可选动作行；自定义 style 应把它渲染为独立可聚焦的按钮。
    public let actions: AnyView?
    /// 可选关闭回调；非 `nil` 时 style 应渲染关闭钮。
    public let dismiss: (() -> Void)?
}

// MARK: - Banner shared helpers

func bannerIcon(for level: StatusLevel) -> Image {
    switch level {
    case .info:
        Image(systemName: "info.circle.fill")
    case .warning:
        Image(systemName: "exclamationmark.triangle.fill")
    case .danger:
        Image(systemName: "exclamationmark.circle.fill")
    case .success:
        Image(systemName: "checkmark.circle.fill")
    case .neutral:
        Image(systemName: "bell.fill")
    }
}

func bannerIconAccessibilityKey(for level: StatusLevel) -> String {
    Timeline.accessibilityLabelKey(for: level)
}

func bannerPalette(for level: StatusLevel) -> BannerPalette {
    switch level {
    case .info:
        BannerPalette(icon: .statusAccentForeground, foreground: .statusAccentForeground, background: .statusAccentSubtle, border: .statusAccentBorder)
    case .warning:
        BannerPalette(icon: .statusAttentionForeground, foreground: .statusAttentionForeground, background: .statusAttentionSubtle, border: .statusAttentionBorder)
    case .danger:
        BannerPalette(icon: .statusDangerForeground, foreground: .statusDangerForeground, background: .statusDangerSubtle, border: .statusDangerBorder)
    case .success:
        BannerPalette(icon: .statusSuccessForeground, foreground: .statusSuccessForeground, background: .statusSuccessSubtle, border: .statusSuccessBorder)
    case .neutral:
        BannerPalette(icon: .contentSecondary, foreground: .contentPrimary, background: .statusNeutralSubtle, border: .borderDefault)
    }
}

nonisolated enum BannerRegion: Hashable, Sendable {
    case icon
    case title
    case body
    case actions
    case dismiss
}

nonisolated struct BannerRegionAnchorsKey: PreferenceKey {
    static var defaultValue: [BannerRegion: Anchor<CGRect>] { [:] }

    static func reduce(value: inout [BannerRegion: Anchor<CGRect>], nextValue: () -> [BannerRegion: Anchor<CGRect>]) {
        value.merge(nextValue()) { current, _ in current }
    }
}

extension View {
    func bannerRegion(_ region: BannerRegion) -> some View {
        self.anchorPreference(key: BannerRegionAnchorsKey.self, value: .bounds) { [region: $0] }
    }
}

enum BannerMetrics {
    static let minimumHitTarget: CGFloat = 44
    static let baseDismissFootprint: CGFloat = 20
    static let contentSortPriority: Double = 3
    static let actionsSortPriority: Double = 2
    static let dismissSortPriority: Double = 1

    static func dismissHitTarget(footprint: CGFloat) -> CGFloat {
        max(self.minimumHitTarget, footprint)
    }

    static func dismissGlyphInset(footprint: CGFloat) -> CGFloat {
        (self.dismissHitTarget(footprint: footprint) - footprint) / 2
    }
}

struct BannerDismissButton: View {
    let color: Color
    let action: () -> Void

    @ScaledMetric(relativeTo: .body) private var footprint = BannerMetrics.baseDismissFootprint

    var body: some View {
        let side = BannerMetrics.dismissHitTarget(footprint: self.footprint)
        Button(action: self.action) {
            Image(systemName: "xmark")
                .font(.body.weight(.medium))
                .imageScale(.small)
                .foregroundStyle(self.color)
                .bannerRegion(.dismiss)
                .frame(width: side, height: side)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Dismiss", bundle: .module))
    }
}

private struct BannerBody: View {
    let configuration: BannerStyleConfiguration
    let bordered: Bool

    @ScaledMetric(relativeTo: .body) private var dismissFootprint = BannerMetrics.baseDismissFootprint

    var body: some View {
        let palette = bannerPalette(for: self.configuration.level)
        self.content(palette: palette)
            .coreFont(.callout)
            .foregroundStyle(palette.foreground)
            .padding(CoreSpacing.md)
            .background {
                let shape = CoreShape.rounded(CoreRadius.medium)
                if self.bordered {
                    shape.fill(palette.background).bordered(style: palette.border, shape: shape)
                } else {
                    shape.fill(palette.background)
                }
            }
    }

    private var usesExtendedSlots: Bool {
        self.configuration.title != nil || self.configuration.actions != nil || self.configuration.dismiss != nil
    }

    private func icon(palette: BannerPalette) -> some View {
        bannerIcon(for: self.configuration.level)
            .foregroundStyle(palette.icon)
            .bannerRegion(.icon)
            .accessibilityLabel(Text(LocalizedStringKey(bannerIconAccessibilityKey(for: self.configuration.level)), bundle: .module))
    }

    @ViewBuilder
    private func content(palette: BannerPalette) -> some View {
        if self.usesExtendedSlots {
            self.extendedContent(palette: palette)
        } else {
            HStack(spacing: CoreSpacing.sm) {
                self.icon(palette: palette)
                self.configuration.label
                    .bannerRegion(.body)
            }
            .accessibilityElement(children: .combine)
        }
    }

    private func extendedContent(palette: BannerPalette) -> some View {
        VStack(alignment: .leading, spacing: CoreSpacing.md) {
            HStack(alignment: .firstTextBaseline, spacing: CoreSpacing.sm) {
                self.icon(palette: palette)
                VStack(alignment: .leading, spacing: CoreSpacing.xxs) {
                    if let title = self.configuration.title {
                        title.coreFont(.headline)
                            .bannerRegion(.title)
                        self.configuration.label
                            .foregroundStyle(Color.contentPrimary)
                            .bannerRegion(.body)
                    } else {
                        self.configuration.label
                            .bannerRegion(.body)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.trailing, self.configuration.dismiss == nil ? 0 : self.dismissFootprint + CoreSpacing.sm)
            .accessibilityElement(children: .combine)
            .accessibilitySortPriority(BannerMetrics.contentSortPriority)
            if let actions = self.configuration.actions {
                HStack(alignment: .top, spacing: CoreSpacing.sm) {
                    bannerIcon(for: self.configuration.level)
                        .hidden()
                        .frame(height: 0)
                        .accessibilityHidden(true)
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: CoreSpacing.sm) { actions }
                        VStack(alignment: .leading, spacing: CoreSpacing.sm) { actions }
                    }
                    .bannerRegion(.actions)
                }
                .accessibilityElement(children: .contain)
                .accessibilitySortPriority(BannerMetrics.actionsSortPriority)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .topTrailing) {
            if let dismiss = self.configuration.dismiss {
                BannerDismissButton(color: .contentSecondary, action: dismiss)
                    .padding(-BannerMetrics.dismissGlyphInset(footprint: self.dismissFootprint))
                    .accessibilitySortPriority(BannerMetrics.dismissSortPriority)
            }
        }
        .accessibilityElement(children: .contain)
    }
}

// MARK: - PlainBannerStyle

/// 默认的 Banner 外观：`CoreRadius.medium` 圆角纯色背景 + 同色系前景，无描边。
public struct PlainBannerStyle: BannerStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        BannerBody(configuration: configuration, bordered: false)
    }
}

// MARK: - BorderedBannerStyle

/// 带同色系描边的 Banner 外观：`CoreRadius.medium` 圆角背景 + 沿同一形状的 `CoreBorderWidth.thin` 描边。
public struct BorderedBannerStyle: BannerStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        BannerBody(configuration: configuration, bordered: true)
    }
}

extension EnvironmentValues {
    @Entry var bannerStyle: any BannerStyle = PlainBannerStyle()
}

public extension View {
    /// 为子树中的所有 `Banner` 设置外观。
    ///
    /// - Parameter style: 任意符合 `BannerStyle` 协议的实现，通常为内置的
    ///   `PlainBannerStyle` / `BorderedBannerStyle`。
    func bannerStyle(_ style: some BannerStyle) -> some View {
        self.environment(\.bannerStyle, style)
    }
}

#Preview {
    VStack(spacing: 10) {
        Banner(level: .info) {
            Text("A pre-released version is available.")
        }.bannerStyle(BorderedBannerStyle())
        Banner(level: .warning) {
            Text("This version of the document is going to expire after 4 days.")
        }
        Banner(level: .danger) {
            Text("This document was deprecated since Jan 1, 2019.")
        }
        Banner(level: .success) {
            Text("You are viewing the latest version of this document.")
        }
        Banner(level: .neutral) {
            Text("Comments on this document are visible to all members.")
        }
        Banner(level: .warning, title: "Storage almost full", message: "Free up space to keep syncing your documents.") {
            Button("Manage storage") {}
                .buttonStyle(.light(role: .warning))
                .controlSize(.small)
        } onDismiss: {}
        .bannerStyle(BorderedBannerStyle())
    }
}
