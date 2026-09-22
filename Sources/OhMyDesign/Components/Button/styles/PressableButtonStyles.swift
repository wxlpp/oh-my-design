import SwiftUI

// MARK: - PressableRowButtonStyle

/// 行式按压反馈：按下时在调用方 label 背后铺满中性按下底色（`Color.pressedBackground`）。
///
/// 只装饰 label——不接 role 色板、不改前景色、不读 `controlSize`、不加内边距，
/// 适合把整条 `SettingsRow` / `ListRow` 做成可点击行。禁用时不给按压反馈并整体变淡。
public struct PressableRowButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        PressableRowBody(label: configuration.label, isPressed: configuration.isPressed)
    }
}

// MARK: - PressableCardButtonStyle

/// 卡片式按压反馈：按下时把调用方 label 按 `CoreButtonMetrics.pressedScale` 缩放；
/// 系统开启「减弱动态效果」时不缩放、只变暗。
///
/// 只装饰 label——不接 role 色板、不改前景色、不读 `controlSize`、不加背景与内边距，
/// 适合把 `Card` 或任意自绘卡片做成可点击卡片。禁用时不给按压反馈并整体变淡。
public struct PressableCardButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        PressableCardBody(label: configuration.label, isPressed: configuration.isPressed)
    }
}

// MARK: - ButtonStyle convenience

public extension ButtonStyle where Self == PressableRowButtonStyle {
    /// 行式按压反馈样式：按下铺 `Color.pressedBackground`，不改布局。
    static var pressableRow: PressableRowButtonStyle { PressableRowButtonStyle() }
}

public extension ButtonStyle where Self == PressableCardButtonStyle {
    /// 卡片式按压反馈样式：按下缩放，减弱动态效果时只变暗，不改布局。
    static var pressableCard: PressableCardButtonStyle { PressableCardButtonStyle() }
}

// MARK: - 反馈解析 / Feedback resolution

struct PressFeedback: Equatable {
    var fill: Color?
    var scale: Double
    var opacity: Double

    static let idle = PressFeedback(fill: nil, scale: 1, opacity: 1)
    static let disabledOpacity: Double = 0.4
    static let reducedMotionPressedOpacity: Double = 0.7
    static let animation: Animation = .easeOut(duration: 0.15)

    static func row(isPressed: Bool, isEnabled: Bool) -> PressFeedback {
        guard isEnabled else { return PressFeedback(fill: nil, scale: 1, opacity: Self.disabledOpacity) }
        return isPressed ? PressFeedback(fill: Color.pressedBackground, scale: 1, opacity: 1) : Self.idle
    }

    static func card(isPressed: Bool, isEnabled: Bool, reduceMotion: Bool) -> PressFeedback {
        guard isEnabled else { return PressFeedback(fill: nil, scale: 1, opacity: Self.disabledOpacity) }
        guard isPressed else { return Self.idle }
        return reduceMotion
            ? PressFeedback(fill: nil, scale: 1, opacity: Self.reducedMotionPressedOpacity)
            : PressFeedback(fill: nil, scale: CoreButtonMetrics.pressedScale, opacity: 1)
    }
}

// MARK: - Bodies

struct PressableRowBody<Label: View>: View {
    let label: Label
    let isPressed: Bool

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        let feedback = PressFeedback.row(isPressed: self.isPressed, isEnabled: self.isEnabled)
        self.label
            .contentShape(Rectangle())
            .background {
                if let fill = feedback.fill {
                    fill
                }
            }
            .opacity(feedback.opacity)
            .animation(PressFeedback.animation, value: feedback)
    }
}

struct PressableCardBody<Label: View>: View {
    let label: Label
    let isPressed: Bool

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let feedback = PressFeedback.card(
            isPressed: self.isPressed,
            isEnabled: self.isEnabled,
            reduceMotion: self.reduceMotion
        )
        self.label
            .scaleEffect(feedback.scale)
            .opacity(feedback.opacity)
            .animation(PressFeedback.animation, value: feedback)
    }
}

#Preview("Pressable ButtonStyles") {
    VStack(spacing: CoreSpacing.xl) {
        InsetGroupedSection(header: "Rows") {
            Button {} label: {
                SettingsRow(icon: .init(systemName: "wifi", background: .blue), title: "Wi-Fi") {
                    SettingsRowChevron()
                }
            }
            .buttonStyle(.pressableRow)
            Button {} label: {
                SettingsRow(icon: .init(systemName: "lock", background: .gray), title: "Disabled") {
                    SettingsRowChevron()
                }
            }
            .buttonStyle(.pressableRow)
            .disabled(true)
        }
        Button {} label: {
            Card {
                Text("Tap this card").frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(.pressableCard)
    }
    .padding()
    .background(Color.surfaceCanvas)
}
