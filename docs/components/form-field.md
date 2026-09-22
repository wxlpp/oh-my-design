# FormField

表单字段容器 + 字段校验基础层 / Form field container and the field validation foundation.

## API

### `FormField`

| 参数 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| label | LocalizedStringKey / StringProtocol | - | 字段标题（字面量在 `Bundle.main` 本地化；运行期字符串 verbatim） |
| description | LocalizedStringKey? / StringProtocol? | nil | 控件下方的补充说明；同时经环境值下传给真实输入节点作无障碍 hint |
| content | () -> Content | - | 真实输入控件，通常是一个系统 `TextField` |

### 校验态与必填性

```swift
public enum FieldValidation: Equatable, Sendable { case valid; case invalid(Text) }
public enum FieldRequirement: Equatable, Sendable { case optional; case required }

extension EnvironmentValues {
    public var fieldValidation: FieldValidation   // 缺省 .valid
    public var fieldRequirement: FieldRequirement // 缺省 .optional
}

extension View {
    public func fieldValidation(_ validation: FieldValidation) -> some View
    public func fieldRequirement(_ requirement: FieldRequirement) -> some View
    public func fieldAccessibilityHint() -> some View
}
```

- 两个环境值嵌套时按 SwiftUI 惯例**最近一层生效**，推荐直接施加在 `FormField` 上。
- `fieldAccessibilityHint()` 读所在 `FormField` 的错误原因与 description，挂成**调用它的那个节点**的
  无障碍 hint（错误原因在前、description 在后；两者皆无时不挂 hint）。系统控件由调用方加在控件上；
  本库的自有输入控件在各自的真实输入节点内部调用同一个 modifier。

## 行为

- **invalid**：label 与错误行取 `statusDangerForeground`，错误行带 `exclamationmark.circle.fill` 图标，
  以 `.transition(.opacity)` 出现；设回 `.valid` 时错误行淡出。
- **required**：label 旁显示星号（`statusDangerForeground`，对 VoiceOver 隐藏），label 的可访问文本追加
  「, required」（`en.lproj` 键 `"%@, required"`）。
- **disabled**：外层 `.disabled(true)` 时 label、description、错误行、星号统一退到 `contentDisabled`。
  视觉优先级 **disabled > invalid > focused**。容器看不到子控件焦点，本身没有 focused 外观；
  焦点态由控件自己表达。
- **系统控件不自动出现 danger 描边**：`TextField` 等系统控件的错误态由 label 与错误行表达。

## 无障碍

- label 与控件用 `accessibilityLabeledPair(role:id:in:)` 配对。⚠️ 已知限制：iOS 26.4 模拟器上用 AXe 读预览宿主的无障碍树，系统 `TextField` 节点的 `AXLabel` 仍为空（label 未被并入输入节点），label 以独立元素出现在输入节点之前；hint 与必填文案均如预期落位。
- 容器**不挂 hint**——它不知道真实输入节点是哪一个；description 经环境值下传，
  由 `fieldAccessibilityHint()` 挂到真实输入节点上。
- 播报：仅在 `valid → invalid`、或 invalid 的错误文本变化时播报一次错误原因；
  首次渲染即 invalid、以及值未变的重建都不播报。播报由 `FormField` 发出
  （`AccessibilityNotification.Announcement`），错误原因按环境 `locale` 解析成字符串。

## 使用示例 / Usage

```swift
@State private var email = ""

FormField("Email", description: "We never share your address.") {
    TextField("you@example.com", text: $email)
        .textFieldStyle(.roundedBorder)
        .fieldAccessibilityHint()
}
.fieldRequirement(.required)
.fieldValidation(email.contains("@") ? .valid : .invalid(Text("Enter a valid email address.")))
```

## 视觉 Token

- label：`coreFont(.subheadline)`，`contentPrimary` / invalid `statusDangerForeground` / disabled `contentDisabled`
- description：`coreFont(.footnote)`，`contentSecondary`
- 错误行：`coreFont(.footnote)`，`statusDangerForeground`
- 行间距：`CoreSpacing.xs`；label 与星号、图标与错误文本间距：`CoreSpacing.xxs`

## 预览 / Preview

预览宿主画廊 id：`form-field`（`App/Sources/ComponentData.swift`）；`App/Sources/Previews.swift` 注册
`#Preview("FormField")`，运行 `scripts/run-snapshots.sh` 后导出到 `docs/snapshots/`。
