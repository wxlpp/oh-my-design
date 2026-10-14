import SwiftUI

// MARK: - UnderlinedFieldModifier

private struct UnderlinedFieldModifier: ViewModifier {
    let isFocused: Bool
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.fieldValidation) private var validation
    @Environment(\.coreAccent) private var accent
    @Environment(\.displayScale) private var displayScale

    func body(content: Content) -> some View {
        let appearance = FieldAppearance.resolve(
            isEnabled: self.isEnabled,
            validation: self.validation,
            isFocused: self.isFocused
        )
        content
            .textFieldStyle(.plain)
            .padding(.vertical, CoreSpacing.md)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(appearance.indicatorColor(
                        normal: appearance == .focused ? self.accent : Color.dividerDefault
                    ))
                    .frame(height: 1 / self.displayScale)
                    .accessibilityHidden(true)
                    .allowsHitTesting(false)
            }
            .opacity(appearance.controlOpacity)
    }
}

public extension View {
    /// 给原生输入控件添加无填充的细下划线，聚焦时使用环境强调色。
    ///
    /// 保留调用方的字体、标签、文本绑定与提交动作；在真实输入节点上使用。
    /// 校验错误沿用 `fieldValidation` 的错误色，错误文案由调用方或 `FormField` 呈现。
    /// - Parameter isFocused: 调用方原生 FocusState 的当前值；本 modifier 不安装焦点绑定。
    /// - Returns: 带下划线且使用原生 plain 输入外观的视图。
    func underlinedField(isFocused: Bool) -> some View {
        self.modifier(UnderlinedFieldModifier(isFocused: isFocused))
    }
}

#Preview("Underlined Field") {
    UnderlinedFieldPreview()
}

private struct UnderlinedFieldPreview: View {
    @State private var title = ""
    @FocusState private var focusedField: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: CoreSpacing.xl) {
            TextField("故事名称", text: self.$title)
                .coreFont(.title)
                .focused(self.$focusedField, equals: 1)
                .underlinedField(isFocused: self.focusedField == 1)
            TextField("不可编辑", text: .constant("已保存的名称"))
                .underlinedField(isFocused: false)
                .disabled(true)
            FormField("名称") {
                TextField("输入名称", text: self.$title)
                    .focused(self.$focusedField, equals: 2)
                    .underlinedField(isFocused: self.focusedField == 2)
                    .fieldAccessibility()
            }
            .fieldValidation(.invalid("名称已被使用"))
        }
        .padding(CoreSpacing.xl)
        .background(Color.surfaceCanvas)
    }
}
