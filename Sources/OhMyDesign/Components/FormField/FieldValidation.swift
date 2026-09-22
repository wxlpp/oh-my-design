import SwiftUI

// MARK: - FieldValidation / FieldRequirement

/// 字段的校验态，经环境值下发给 `FormField` 与接入校验的控件。
public nonisolated enum FieldValidation: Equatable, Sendable {
    /// 校验通过（或尚未校验）。
    case valid
    /// 校验未通过，关联值是展示给用户、也会被播报的错误原因。
    case invalid(LocalizedStringResource)
}

/// 字段是否必填，经环境值下发给 `FormField`。
public nonisolated enum FieldRequirement: Equatable, Sendable {
    /// 选填（默认）。
    case optional
    /// 必填：label 旁显示星号，可访问 label 追加必填说明。
    case required
}

// MARK: - Environment

public extension EnvironmentValues {
    /// 当前字段的校验态；嵌套时最近一层生效。
    @Entry var fieldValidation: FieldValidation = .valid
    /// 当前字段的必填性；嵌套时最近一层生效。
    @Entry var fieldRequirement: FieldRequirement = .optional
}

extension EnvironmentValues {
    @Entry var fieldDescription: Text? = nil
    @Entry var fieldLabel: Text? = nil
}

// MARK: - View extension

public extension View {
    /// 为这棵子树设定字段校验态，推荐施加在 `FormField` 上。
    ///
    /// - Parameter validation: `.valid`，或带错误原因的 `.invalid(_:)`。
    /// - Returns: 注入了校验态的视图。
    func fieldValidation(_ validation: FieldValidation) -> some View {
        self.environment(\.fieldValidation, validation)
    }

    /// 为这棵子树设定字段必填性，推荐施加在 `FormField` 上。
    ///
    /// - Parameter requirement: `.optional` 或 `.required`。
    /// - Returns: 注入了必填性的视图。
    func fieldRequirement(_ requirement: FieldRequirement) -> some View {
        self.environment(\.fieldRequirement, requirement)
    }

    /// 把所在 `FormField` 的 label（含必填说明）挂成本视图的无障碍 label，错误原因与 description 挂成无障碍 hint。
    ///
    /// 施加在真实输入节点上（如 `FormField` 内的系统 `TextField`）；容器本身不挂 hint。
    /// 不在 `FormField` 内时不挂 label；没有错误也没有 description 时不挂 hint。
    ///
    /// - Returns: 挂好无障碍 label 与 hint 的视图。
    func fieldAccessibility() -> some View {
        self.modifier(FieldAccessibilityModifier())
    }
}

// MARK: - Accessibility hint

enum FieldAccessibilityHint {
    static func parts(validation: FieldValidation, description: Text?) -> [Text] {
        var parts: [Text] = []
        if case .invalid(let reason) = validation {
            parts.append(Text(reason))
        }
        if let description {
            parts.append(description)
        }
        return parts
    }

    static func text(validation: FieldValidation, description: Text?) -> Text? {
        let parts = Self.parts(validation: validation, description: description)
        switch parts.count {
        case 0:
            return nil
        case 1:
            return parts[0]
        default:
            return Text("\(parts[0]), \(parts[1])", bundle: .module)
        }
    }
}

private struct FieldAccessibilityModifier: ViewModifier {
    @Environment(\.fieldValidation) private var validation
    @Environment(\.fieldRequirement) private var requirement
    @Environment(\.fieldDescription) private var description
    @Environment(\.fieldLabel) private var fieldLabel

    func body(content: Content) -> some View {
        let label = self.fieldLabel.map { FormFieldAccessibility.label($0, requirement: self.requirement) }
        let hint = FieldAccessibilityHint.text(validation: self.validation, description: self.description)
        content
            .accessibilityLabel(label ?? Text(verbatim: String()), isEnabled: label != nil)
            .accessibilityHint(hint ?? Text(verbatim: String()), isEnabled: hint != nil)
    }
}

// MARK: - Appearance

enum FieldAppearance: Equatable {
    case normal
    case focused
    case invalid
    case disabled

    static func resolve(isEnabled: Bool, validation: FieldValidation, isFocused: Bool) -> FieldAppearance {
        if !isEnabled { return .disabled }
        if case .invalid = validation { return .invalid }
        return isFocused ? .focused : .normal
    }

    var labelColor: Color {
        switch self {
        case .disabled: Color.contentDisabled
        case .invalid: Color.statusDangerForeground
        case .normal, .focused: Color.contentPrimary
        }
    }

    var messageColor: Color {
        self == .disabled ? Color.contentDisabled : Color.statusDangerForeground
    }

    var requiredMarkColor: Color {
        self == .disabled ? Color.contentDisabled : Color.statusDangerForeground
    }
}

// MARK: - Announcement

nonisolated struct FieldValidationAnnouncer: Equatable {
    private(set) var last: FieldValidation?

    mutating func observe(_ validation: FieldValidation) -> LocalizedStringResource? {
        defer { self.last = validation }
        guard let last = self.last, case .invalid(let reason) = validation else { return nil }
        if case .invalid(let previous) = last, previous == reason { return nil }
        return reason
    }
}

struct FieldValidationAnnouncementModifier: ViewModifier {
    @Environment(\.fieldValidation) private var validation
    @State private var announcer = FieldValidationAnnouncer()

    func body(content: Content) -> some View {
        content.onChange(of: self.validation, initial: true) { _, newValue in
            guard let reason = self.announcer.observe(newValue) else { return }
            AccessibilityNotification.Announcement(String(localized: reason)).post()
        }
    }
}
