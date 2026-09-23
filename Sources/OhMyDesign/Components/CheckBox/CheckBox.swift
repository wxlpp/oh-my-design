import SwiftUI

// MARK: - CheckBoxToggleStyle

/// 复选框样式 / CheckBox toggle style：把 SwiftUI `Toggle` 渲染为左侧方框 +
/// 右侧 label 的复选框形态。
public struct CheckBoxToggleStyle: ToggleStyle {
    /// 无参构造 / Memberwise-free init：显式声明才能让下游可达
    /// （Swift 默认合成的 memberwise init 是 internal）。
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        CheckBoxBody(configuration: configuration)
    }
}

private struct CheckBoxBody: View {
    let configuration: ToggleStyleConfiguration

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.fieldValidation) private var validation
    @Environment(\.coreMotionPresentation) private var motionPresentation

    var body: some View {
        let appearance = FieldAppearance.resolve(isEnabled: self.isEnabled, validation: self.validation, isFocused: false)
        HStack(alignment: .top, spacing: CoreSpacing.sm) {
            Image(systemName: self.configuration.isOn ? "checkmark.square.fill" : "square")
                .font(.system(size: CoreControlMetrics.iconSize(for: .regular)))
                .foregroundStyle(appearance.indicatorColor(
                    normal: self.configuration.isOn ? Color.contentPrimary : Color.contentSecondary
                ))
                .contentTransition(self.motionPresentation.symbolReplacement)
            self.configuration.label
                .fieldAccessibilityHint()
        }
        .opacity(appearance.controlOpacity)
        .frame(minHeight: CoreControlMetrics.height(for: .regular))
        .contentShape(Rectangle())
        .coreAnimation(.selection, value: self.configuration.isOn)
        .onTapGesture {
            self.configuration.isOn.toggle()
        }
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var isOn = false

    Toggle("同意用户协议 / Accept terms", isOn: $isOn)
        .toggleStyle(CheckBoxToggleStyle())
        .padding()
}
