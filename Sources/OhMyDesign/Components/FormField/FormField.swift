import SwiftUI

// MARK: - FormFieldLayout

/// `FormField` 的排布形态。
public nonisolated enum FormFieldLayout: Sendable, Equatable {
    /// 默认：label 在上，控件、description、错误行依次在下（现状形态）。
    /// 业界来源：Apple HIG iOS 表单 / Material Design 3 Text fields 的外置 label。
    case stacked
    /// label 在前一列，控件在后，description 与错误行位于控件下方；辅助功能大字号下回退为 `.stacked`。
    /// 业界来源：Ant Design `Form.Item` 的 `layout="horizontal"` / macOS 表单的标签列（`Form` 的 `.formStyle(.columns)`）。
    case inline

    func resolved(for dynamicTypeSize: DynamicTypeSize) -> FormFieldLayout {
        dynamicTypeSize.isAccessibilitySize ? .stacked : self
    }
}

// MARK: - FormField

/// 表单字段容器：label（必填时带星号）+ 输入控件 + 可选 description + 错误行。
///
/// 校验态与必填性经 `.fieldValidation(_:)` / `.fieldRequirement(_:)` 注入，推荐直接施加在
/// `FormField` 上。容器只把 label 与控件配对，不在自身挂无障碍 hint；系统控件请在控件上
/// 加 `.fieldAccessibility()`，由真实输入节点挂上 label、错误原因与 description。
public struct FormField<Content: View>: View {
    private let label: Text
    private let description: Text?
    private let layout: FormFieldLayout
    private let content: Content

    @Environment(\.fieldValidation) private var validation
    @Environment(\.fieldRequirement) private var requirement
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.formFieldLabelColumnWidth) private var labelColumnWidth
    @Namespace private var pairNamespace

    private init(label: Text, description: Text?, layout: FormFieldLayout, content: Content) {
        self.label = label
        self.description = description
        self.layout = layout
        self.content = content
    }

    /// 以本地化键创建字段容器，字面量在 **`Bundle.main`** 本地化。
    ///
    /// - Parameters:
    ///   - label: 字段标题。
    ///   - description: 字段下方的补充说明，可选。
    ///   - layout: 排布形态，默认 `.stacked`。
    ///   - content: 真实输入控件（通常是一个系统 `TextField`）。
    public init(
        _ label: LocalizedStringKey,
        description: LocalizedStringKey? = nil,
        layout: FormFieldLayout = .stacked,
        @ViewBuilder content: () -> Content
    ) {
        self.init(label: Text(label), description: description.map { Text($0) }, layout: layout, content: content())
    }

    /// 以运行期字符串创建字段容器，verbatim 显示、不走本地化查表。
    ///
    /// - Parameters:
    ///   - label: 字段标题。
    ///   - description: 字段下方的补充说明，可选。
    ///   - layout: 排布形态，默认 `.stacked`。
    ///   - content: 真实输入控件（通常是一个系统 `TextField`）。
    @_disfavoredOverload
    public init<S: StringProtocol>(
        _ label: S,
        description: S? = nil,
        layout: FormFieldLayout = .stacked,
        @ViewBuilder content: () -> Content
    ) {
        self.init(label: Text(label), description: description.map { Text($0) }, layout: layout, content: content())
    }

    /// 按排布形态渲染 label、控件，以及 description 或错误行。
    public var body: some View {
        let appearance = FieldAppearance.resolve(
            isEnabled: self.isEnabled,
            validation: self.validation,
            isFocused: false
        )
        let layout = self.layout.resolved(for: self.dynamicTypeSize)
        let container = self.containerLayout(layout)

        container {
            self.labelRow(appearance: appearance)
                .fixedSize(horizontal: layout == .inline, vertical: false)
                .background {
                    GeometryReader { proxy in
                        Color.clear.preference(
                            key: FormFieldLabelWidthKey.self,
                            value: layout == .inline ? proxy.size.width : 0
                        )
                    }
                }
                .frame(minWidth: layout == .inline ? self.labelColumnWidth : nil, alignment: .leading)
            self.controlColumn(appearance: appearance)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .coreAnimation(.reveal, value: FormFieldSlot.resolve(
            appearance: appearance,
            validation: self.validation,
            hasDescription: self.description != nil
        ))
        .modifier(FieldValidationAnnouncementModifier())
    }

    private func containerLayout(_ layout: FormFieldLayout) -> AnyLayout {
        switch layout {
        case .stacked: AnyLayout(VStackLayout(alignment: .leading, spacing: CoreSpacing.xs))
        case .inline: AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: CoreSpacing.md))
        }
    }

    // MARK: - Control column

    private func controlColumn(appearance: FieldAppearance) -> some View {
        VStack(alignment: .leading, spacing: CoreSpacing.xs) {
            self.content
                .environment(\.fieldDescription, self.description)
                .environment(\.fieldLabel, self.label)
                .environment(\.fieldValidationAnnounced, true)
                .accessibilityLabeledPair(role: .content, id: FormFieldPairID.field, in: self.pairNamespace)

            switch FormFieldSlot.resolve(appearance: appearance, validation: self.validation, hasDescription: self.description != nil) {
            case .error(let reason):
                HStack(alignment: .firstTextBaseline, spacing: CoreSpacing.xxs) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .accessibilityHidden(true)
                    Text(reason)
                }
                .coreFont(.footnote)
                .foregroundStyle(appearance.messageColor)
                .fixedSize(horizontal: false, vertical: true)
                .transition(.opacity)
            case .description:
                self.description
                    .coreFont(.footnote)
                    .foregroundStyle(appearance == .disabled ? Color.contentDisabled : Color.contentSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity)
            case .empty:
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

// MARK: - Label column

public extension View {
    /// 让这棵子树里所有 `.inline` 排布的 `FormField` 共用同一 label 列宽（取其中最宽的 label），使控件左缘对齐。
    ///
    /// - Returns: 统一了 label 列宽的视图。
    func formFieldLabelColumn() -> some View {
        self.modifier(FormFieldLabelColumnModifier())
    }
}

nonisolated struct FormFieldLabelWidthKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

extension EnvironmentValues {
    @Entry var formFieldLabelColumnWidth: CGFloat? = nil
}

private struct FormFieldLabelColumnModifier: ViewModifier {
    @State private var width: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .environment(\.formFieldLabelColumnWidth, self.width > 0 ? self.width : nil)
            .onPreferenceChange(FormFieldLabelWidthKey.self) { self.width = $0 }
    }
}

enum FormFieldSlot: Equatable {
    case error(LocalizedStringResource)
    case description
    case empty

    static func resolve(appearance: FieldAppearance, validation: FieldValidation, hasDescription: Bool) -> FormFieldSlot {
        if appearance != .disabled, case .invalid(let reason) = validation {
            return .error(reason)
        }
        return hasDescription ? .description : .empty
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
                .fieldAccessibility()
        }
        .fieldRequirement(.required)

        FormField("Email") {
            TextField("you@example.com", text: $email)
                .textFieldStyle(.roundedBorder)
                .fieldAccessibility()
        }
        .fieldValidation(email.contains("@") ? .valid : .invalid("Enter a valid email address."))

        FormField("Team") {
            TextField("Design", text: .constant("Design"))
                .textFieldStyle(.roundedBorder)
                .foregroundStyle(Color.contentDisabled)
                .fieldAccessibility()
        }
        .fieldValidation(.invalid("Disabled wins over invalid."))
        .disabled(true)

        VStack(spacing: CoreSpacing.md) {
            FormField("City", layout: .inline) {
                TextField("Cupertino", text: .constant(""))
                    .textFieldStyle(.roundedBorder)
                    .fieldAccessibility()
            }
            FormField("Postal code", layout: .inline) {
                TextField("95014", text: .constant("950"))
                    .textFieldStyle(.roundedBorder)
                    .fieldAccessibility()
            }
            .fieldValidation(.invalid("Enter a 5-digit postal code."))
        }
        .formFieldLabelColumn()
    }
    .padding()
    .background(Color.surfaceCanvas)
}
