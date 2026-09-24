import SwiftUI

// MARK: - CheckBoxToggleStyle

/// 复选框样式 / CheckBox toggle style：把 SwiftUI `Toggle` 渲染为左侧方框 +
/// 右侧 label 的复选框形态；勾选 / 未勾选之外，还读系统从
/// `Toggle(sources:isOn:)` 派生的 mixed 态并画出第三种符号。
public struct CheckBoxToggleStyle: ToggleStyle {
    /// 无参构造 / Memberwise-free init：显式声明才能让下游可达
    /// （Swift 默认合成的 memberwise init 是 internal）。
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        CheckBoxBody(configuration: configuration)
    }
}

// MARK: - 指示符三态 / Indicator tri-state

enum CheckBoxIndicator: Equatable, CaseIterable {
    case off
    case mixed
    case on

    static func resolve(isOn: Bool, isMixed: Bool) -> CheckBoxIndicator {
        if isMixed { return .mixed }
        return isOn ? .on : .off
    }

    var symbolName: String {
        switch self {
        case .off: "square"
        case .mixed: "minus.square.fill"
        case .on: "checkmark.square.fill"
        }
    }

    var normalColor: Color {
        switch self {
        case .off: Color.contentSecondary
        case .mixed, .on: Color.contentPrimary
        }
    }
}

// MARK: - 布局注入 / Layout injection

nonisolated struct CheckBoxLayout: Equatable, Sendable {
    let glyph: CGFloat
    let minHeight: CGFloat
}

extension EnvironmentValues {
    @Entry var checkBoxLayout: CheckBoxLayout? = nil
}

private struct CheckBoxBody: View {
    let configuration: ToggleStyleConfiguration

    @Environment(\.checkBoxLayout) private var layout
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.fieldValidation) private var validation
    @Environment(\.coreMotionPresentation) private var motionPresentation

    var body: some View {
        let appearance = FieldAppearance.resolve(isEnabled: self.isEnabled, validation: self.validation, isFocused: false)
        let indicator = CheckBoxIndicator.resolve(
            isOn: self.configuration.isOn, isMixed: self.configuration.isMixed
        )
        HStack(alignment: .top, spacing: CoreSpacing.sm) {
            Image(systemName: indicator.symbolName)
                .font(.system(size: self.layout?.glyph ?? CoreControlMetrics.iconSize(for: .regular)))
                .foregroundStyle(appearance.indicatorColor(normal: indicator.normalColor))
                .contentTransition(self.motionPresentation.symbolReplacement)
            self.configuration.label
                .fieldAccessibilityHint()
        }
        .opacity(appearance.controlOpacity)
        .frame(minHeight: self.layout?.minHeight ?? CoreControlMetrics.height(for: .regular))
        .contentShape(Rectangle())
        .coreAnimation(.selection, value: indicator)
        .onTapGesture {
            self.configuration.isOn.toggle()
        }
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var isOn = false
    @Previewable @State var terms = false
    @Previewable @State var privacy = true

    VStack(alignment: .leading, spacing: CoreSpacing.md) {
        Toggle("同意用户协议 / Accept terms", isOn: $isOn)

        Toggle(sources: [$terms, $privacy], isOn: \.self) {
            Text(verbatim: "全选 / Select all")
        }
        Toggle("用户协议 / Terms", isOn: $terms)
        Toggle("隐私政策 / Privacy", isOn: $privacy)
    }
    .toggleStyle(CheckBoxToggleStyle())
    .padding()
}
