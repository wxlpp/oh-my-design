import SwiftUI

// MARK: - UnderlinedFieldModifier

private struct UnderlinedFieldModifier: ViewModifier {
    @FocusState private var isFocused: Bool
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
            .focused(self.$isFocused)
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
    /// - Returns: 带下划线且使用原生 plain 输入外观的视图。
    func underlinedField() -> some View {
        self.modifier(UnderlinedFieldModifier())
    }
}

#Preview("Underlined Field") {
    UnderlinedFieldPreview()
}

private struct UnderlinedFieldPreview: View {
    @State private var title = ""

    var body: some View {
        VStack(alignment: .leading, spacing: CoreSpacing.xl) {
            TextField("故事名称", text: self.$title)
                .coreFont(.title)
                .underlinedField()
            TextField("不可编辑", text: .constant("已保存的名称"))
                .underlinedField()
                .disabled(true)
            FormField("名称") {
                TextField("输入名称", text: self.$title)
                    .underlinedField()
                    .fieldAccessibility()
            }
            .fieldValidation(.invalid("名称已被使用"))
        }
        .padding(CoreSpacing.xl)
        .background(Color.surfaceCanvas)
    }
}
