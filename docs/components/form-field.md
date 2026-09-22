# FormField

表单字段容器 + 字段校验基础层 / Form field container and the field validation foundation.

## API

### `FormField`

| 参数 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| label | LocalizedStringKey / StringProtocol | - | 字段标题（字面量在 `Bundle.main` 本地化；运行期字符串 verbatim） |
| description | LocalizedStringKey? / StringProtocol? | nil | 控件下方的补充说明；同时经环境值下传给真实输入节点作无障碍 hint |
| layout | FormFieldLayout | .stacked | 排布形态：`.stacked`（label 在上）/ `.inline`（label 在前一列，description 与错误行在控件下方） |
| content | () -> Content | - | 真实输入控件，通常是一个系统 `TextField` |

### 校验态与必填性

```swift
public enum FieldValidation: Equatable, Sendable { case valid; case invalid(LocalizedStringResource) }
public enum FormFieldLayout: Sendable, Equatable { case stacked; case inline }
public enum FieldRequirement: Equatable, Sendable { case optional; case required }

extension EnvironmentValues {
    public var fieldValidation: FieldValidation   // 缺省 .valid
    public var fieldRequirement: FieldRequirement // 缺省 .optional
}

extension View {
    public func fieldValidation(_ validation: FieldValidation) -> some View
    public func fieldRequirement(_ requirement: FieldRequirement) -> some View
    public func fieldAccessibility() -> some View
    public func formFieldLabelColumn() -> some View
}
```

- 两个环境值嵌套时按 SwiftUI 惯例**最近一层生效**，推荐直接施加在 `FormField` 上。
- `fieldAccessibility()` 读所在 `FormField` 的环境值，在**调用它的那个节点**上同时设置无障碍 label
  （字段 label + 必填说明，如 `Email, required`）与 hint（错误原因在前、description 在后；两者皆无时不挂 hint）。
  系统控件由调用方加在控件上；本库的自有控件在各自的真实输入节点内部走同一套实现（选择类控件只挂 hint、保留选项自身 label，见下文《接入校验态的自有控件》）。
- 错误原因是 `LocalizedStringResource`：显示走 `Text(_:)`；播报前把环境 `locale` 写进资源副本再用
  `String(localized:)` 解析，「错误文本是否变化」也按同一解析结果判断。
- `formFieldLabelColumn()`：施加在一组字段的容器上，让其中所有 `.inline` 字段共用最宽 label 的列宽，控件左缘对齐。

## 行为

- **description 与错误行共用一个槽位**：enabled 且 invalid 时错误行（带 `exclamationmark.circle.fill`，
  文本悬挂缩进）替换 description，二者 `.transition(.opacity)` 交叉淡变；设回 `.valid` 时 description 淡回。
  被替换的 description 仍留在输入节点的无障碍 hint 里。
- **invalid**：label 与错误行取 `statusDangerForeground`。
- **required**：label 旁显示星号（valid 时 `contentSecondary`、invalid 时 `statusDangerForeground`、
  disabled 时 `contentDisabled`，对 VoiceOver 隐藏），label 的可访问文本追加「, required」
  （`en.lproj` 键 `"%@, required"`）。
- **disabled**：外层 `.disabled(true)` 时 label、description、星号退到 `contentDisabled`，**不渲染错误行**
  （错误原因只留在无障碍 hint 里）。视觉优先级 **disabled > invalid > focused**。容器看不到子控件焦点，
  本身没有 focused 外观。⚠️ 控件自身在禁用态下的取值文字颜色由调用方的 `TextField` 负责
  （如 `.foregroundStyle(Color.contentDisabled)`），容器不改写它。
- **系统控件不自动出现 danger 描边**：`TextField` 等系统控件的错误态由 label 与错误行表达。

## 无障碍

- label 与控件另用 `accessibilityLabeledPair(role:id:in:)` 配对（macOS 生效）；iOS 26 实测它不会把 label 关联到系统 `TextField`，所以 label 也由 `fieldAccessibility()` 设到输入节点上。
- 容器**不挂 hint**——它不知道真实输入节点是哪一个；description 经环境值下传，
  由 `fieldAccessibility()` 挂到真实输入节点上。
- description 与错误行本身对 VoiceOver 保持可见（调用方忘加 `.fieldAccessibility()` 时的兜底），
  因此加了 modifier 时二者可能被读两次：一次作为输入节点的 hint，一次作为独立文本。
- 播报：仅在 `valid → invalid`、或 invalid 的错误文本变化时播报一次错误原因；
  首次渲染即 invalid、以及值未变的重建都不播报。播报由 `FormField` 发出
  （`AccessibilityNotification.Announcement`）。
- 播报归属：嵌套的内层 `FormField` 若继承外层的同一校验源，不再重复播报；内层自己施加了
  `.fieldValidation(_:)` 时视为独立校验源，各自播报。

## 接入校验态的自有控件

`PinCode`、`TagInput`、`SearchField`、`CheckBoxToggleStyle`、`RadioGroup` 自己读 `fieldValidation`，
放进 `FormField` 即可，**不要**再在它们外面加 `.fieldAccessibility()`（会覆盖控件内部挂好的节点）。

| 控件 | invalid 外观 | 无障碍 hint 挂在 | label |
|---|---|---|---|
| `PinCode` | 每格边框 `statusDangerForeground` | 每一格 | 字段 label；不在 `FormField` 内为 `"Verification code"` |
| `TagInput` | 输入框底部 danger 描边线 | 输入框（不是 chip 删除按钮） | 字段 label；否则 placeholder |
| `SearchField` | 原生搜索框外沿 danger 胶囊描边 | 原生搜索框 | 字段 label；否则 placeholder |
| `CheckBoxToggleStyle` | 方框图标 danger | `Toggle` 节点 | 保留 Toggle 自身文字 |
| `RadioGroup` | 圆点图标 danger | 每个选项 | 保留选项标题 |

- 外观统一走 disabled > invalid：禁用时与禁用 + valid 一致；valid 时与接入前逐像素一致。
- 播报仍只由 `FormField` 发出，控件不另播报。
- 预览宿主：`form-field-controls-valid` / `form-field-controls-invalid` / `form-field-controls-disabled`。

## 使用示例 / Usage

```swift
@State private var email = ""

FormField("Email", description: "We never share your address.") {
    TextField("you@example.com", text: $email)
        .textFieldStyle(.roundedBorder)
        .fieldAccessibility()
}
.fieldRequirement(.required)
.fieldValidation(email.contains("@") ? .valid : .invalid("Enter a valid email address."))
```

### `.inline` 排布

```swift
VStack {
    FormField("City", layout: .inline) {
        TextField("Cupertino", text: $city).fieldAccessibility()
    }
    FormField("Postal code", layout: .inline) {
        TextField("95014", text: $postalCode).fieldAccessibility()
    }
}
.formFieldLabelColumn()
```

label 在前一列，控件与 description / 错误行共用后一列。不加 `formFieldLabelColumn()` 时每个字段的 label
列只取自身宽度，相邻字段的控件左缘不对齐。辅助功能大字号（`isAccessibilitySize`）下自动回退为 `.stacked`；
两种排布经 `AnyLayout` 切换，控件子树的身份（`@State`、焦点）不受影响。

放进 `InsetGroupedSection` 当设置式表单行：

```swift
InsetGroupedSection(header: "Server", dividerInset: .textAligned) {
    FormField("Host", layout: .inline) {
        TextField("example.com", text: $host).textFieldStyle(.plain).fieldAccessibility()
    }
    .padding(.horizontal, SettingsRowMetrics.horizontalPadding)
    .padding(.vertical, CoreSpacing.sm)
    FormField("Port", layout: .inline) {
        TextField("443", text: $port).textFieldStyle(.plain).fieldAccessibility()
    }
    .padding(.horizontal, SettingsRowMetrics.horizontalPadding)
    .padding(.vertical, CoreSpacing.sm)
}
.formFieldLabelColumn()
```

## 视觉 Token

- label：`coreFont(.subheadline)`，`contentPrimary` / invalid `statusDangerForeground` / disabled `contentDisabled`
- 星号：`contentSecondary` / invalid `statusDangerForeground` / disabled `contentDisabled`
- description：`coreFont(.footnote)`，`contentSecondary`
- 错误行：`coreFont(.footnote)`，`statusDangerForeground`
- 行间距：`CoreSpacing.xs`；label 与星号、图标与错误文本间距：`CoreSpacing.xxs`；`.inline` label 列与控件间距：`CoreSpacing.md`

## 预览 / Preview

预览宿主画廊 id：`form-field`（`App/Sources/ComponentData.swift`）；`App/Sources/Previews.swift` 注册
`#Preview("FormField")`，运行 `scripts/run-snapshots.sh` 后导出到 `docs/snapshots/`。
