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
        BannerPalette(icon: .contentSecondary, foreground: .contentPrimary, background: .tertiaryFill, border: .borderDefault)
    }
}

enum BannerMetrics {
    static let dismissHitTarget: CGFloat = 44
    static let dismissFootprint: CGFloat = 20
    static let dismissGlyphInset: CGFloat = (dismissHitTarget - dismissFootprint) / 2
}

struct BannerDismissButton: View {
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: self.action) {
            Image(systemName: "xmark")
                .font(.body.weight(.semibold))
                .imageScale(.small)
                .foregroundStyle(self.color)
                .frame(width: BannerMetrics.dismissHitTarget, height: BannerMetrics.dismissHitTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Dismiss", bundle: .module))
    }
}

@ViewBuilder
private func bannerBody(configuration: BannerStyleConfiguration, bordered: Bool) -> some View {
    let palette = bannerPalette(for: configuration.level)
    VStack(alignment: .leading, spacing: CoreSpacing.sm) {
        HStack(alignment: .firstTextBaseline, spacing: CoreSpacing.sm) {
            bannerIcon(for: configuration.level)
                .foregroundStyle(palette.icon)
                .accessibilityLabel(Text(LocalizedStringKey(bannerIconAccessibilityKey(for: configuration.level)), bundle: .module))
            VStack(alignment: .leading, spacing: CoreSpacing.xxs) {
                if let title = configuration.title {
                    title.coreFont(.headline)
                }
                configuration.label
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.trailing, configuration.dismiss == nil ? 0 : BannerMetrics.dismissFootprint + CoreSpacing.sm)
        .accessibilityElement(children: .combine)
        if let actions = configuration.actions {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: CoreSpacing.sm) { actions }
                VStack(alignment: .leading, spacing: CoreSpacing.sm) { actions }
            }
        }
    }
    .overlay(alignment: .topTrailing) {
        if let dismiss = configuration.dismiss {
            BannerDismissButton(color: palette.icon, action: dismiss)
                .padding(-BannerMetrics.dismissGlyphInset)
        }
    }
    .accessibilityElement(children: .contain)
    .coreFont(.callout)
    .foregroundStyle(palette.foreground)
    .padding(CoreSpacing.md)
    .background {
        if bordered {
            Rectangle().fill(palette.background).bordered(style: palette.border)
        } else {
            Rectangle().fill(palette.background)
        }
    }
}

// MARK: - PlainBannerStyle

/// 默认的 Banner 外观：纯色背景 + 同色系前景，无描边。
public struct PlainBannerStyle: BannerStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        bannerBody(configuration: configuration, bordered: false)
    }
}

// MARK: - BorderedBannerStyle

/// 带同色系描边的 Banner 外观：背景 + `CoreBorderWidth.thin` 描边。
public struct BorderedBannerStyle: BannerStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        bannerBody(configuration: configuration, bordered: true)
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
