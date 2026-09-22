import SwiftUI

// MARK: - FormField

/// 表单字段容器：label（必填时带星号）+ 输入控件 + 可选 description + 错误行。
///
/// 校验态与必填性经 `.fieldValidation(_:)` / `.fieldRequirement(_:)` 注入，推荐直接施加在
/// `FormField` 上。容器只把 label 与控件配对，不在自身挂无障碍 hint；系统控件请在控件上
/// 加 `.fieldAccessibilityHint()`，由真实输入节点挂上错误原因与 description。
public struct FormField<Content: View>: View {
    private let label: Text
    private let description: Text?
    private let content: Content

    @Environment(\.fieldValidation) private var validation
    @Environment(\.fieldRequirement) private var requirement
    @Environment(\.isEnabled) private var isEnabled
    @Namespace private var pairNamespace

    private init(label: Text, description: Text?, content: Content) {
        self.label = label
        self.description = description
        self.content = content
    }

    /// 以本地化键创建字段容器，字面量在 **`Bundle.main`** 本地化。
    ///
    /// - Parameters:
    ///   - label: 字段标题。
    ///   - description: 字段下方的补充说明，可选。
    ///   - content: 真实输入控件（通常是一个系统 `TextField`）。
    public init(
        _ label: LocalizedStringKey,
        description: LocalizedStringKey? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.init(label: Text(label), description: description.map { Text($0) }, content: content())
    }

    /// 以运行期字符串创建字段容器，verbatim 显示、不走本地化查表。
    ///
    /// - Parameters:
    ///   - label: 字段标题。
    ///   - description: 字段下方的补充说明，可选。
    ///   - content: 真实输入控件（通常是一个系统 `TextField`）。
    @_disfavoredOverload
    public init<S: StringProtocol>(
        _ label: S,
        description: S? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.init(label: Text(label), description: description.map { Text($0) }, content: content())
    }

    /// 渲染 label 行、控件、description 与错误行。
    public var body: some View {
        let appearance = FieldAppearance.resolve(
            isEnabled: self.isEnabled,
            validation: self.validation,
            isFocused: false
        )

        VStack(alignment: .leading, spacing: CoreSpacing.xs) {
            self.labelRow(appearance: appearance)

            self.content
                .environment(\.fieldDescription, self.description)
                .accessibilityLabeledPair(role: .content, id: FormFieldPairID.field, in: self.pairNamespace)

            if let description = self.description {
                description
                    .coreFont(.footnote)
                    .foregroundStyle(appearance == .disabled ? Color.contentDisabled : Color.contentSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if case .invalid(let reason) = self.validation {
                HStack(alignment: .firstTextBaseline, spacing: CoreSpacing.xxs) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .accessibilityHidden(true)
                    reason
                }
                .coreFont(.footnote)
                .foregroundStyle(appearance.messageColor)
                .fixedSize(horizontal: false, vertical: true)
                .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.easeInOut(duration: 0.2), value: self.validation)
        .modifier(FieldValidationAnnouncementModifier())
    }

    // MARK: - Label row

    private func labelRow(appearance: FieldAppearance) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: CoreSpacing.xxs) {
            self.label
                .foregroundStyle(appearance.labelColor)
            if self.requirement == .required {
                Text(verbatim: "*")
                    .foregroundStyle(appearance.requiredMarkColor)
                    .accessibilityHidden(true)
            }
        }
        .coreFont(.subheadline)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(FormFieldAccessibility.label(self.label, requirement: self.requirement))
        .accessibilityLabeledPair(role: .label, id: FormFieldPairID.field, in: self.pairNamespace)
    }
}

// MARK: - Helpers

private enum FormFieldPairID: Hashable {
    case field
}

enum FormFieldAccessibility {
    static func label(_ label: Text, requirement: FieldRequirement) -> Text {
        switch requirement {
        case .optional: label
        case .required: Text("\(label), required", bundle: .module)
        }
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var email = "not-an-email"
    @Previewable @State var name = ""
    VStack(spacing: CoreSpacing.xl) {
        FormField("Name", description: "Shown on your public profile.") {
            TextField("Jane Appleseed", text: $name)
                .textFieldStyle(.roundedBorder)
                .fieldAccessibilityHint()
        }
        .fieldRequirement(.required)

        FormField("Email") {
            TextField("you@example.com", text: $email)
                .textFieldStyle(.roundedBorder)
                .fieldAccessibilityHint()
        }
        .fieldValidation(email.contains("@") ? .valid : .invalid(Text("Enter a valid email address.")))

        FormField("Team") {
            TextField("Design", text: .constant(""))
                .textFieldStyle(.roundedBorder)
        }
        .fieldValidation(.invalid(Text("Disabled wins over invalid.")))
        .disabled(true)
    }
    .padding()
    .background(Color.surfaceCanvas)
}
