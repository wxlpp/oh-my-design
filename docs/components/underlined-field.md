# Underlined Field

用于命名等单个重点输入。保留原生 TextField，以一条细线代替厚重的填充和边框；字体由页面决定，不需要在外侧再套卡片。

```swift
@State private var title = ""
@FocusState private var isFocused: Bool

TextField("故事名称", text: $title)
    .coreFont(.title)
    .focused($isFocused)
    .underlinedField(isFocused: isFocused)
    .accessibilityLabel("故事名称")
```

`underlinedField(isFocused:)` 使用 plain 原生输入外观、上下 `CoreSpacing.md` 间距及一物理像素的下划线。聚焦时取 `coreAccent`，校验错误时取 `statusDangerForeground`，禁用时统一弱化。焦点由调用方持有，modifier 不安装绑定、不拥有文本或提交逻辑。

可与 `FormField` / `.fieldValidation` / `.fieldAccessibility()` 组合；错误文案仍由 FormField 或调用方提供。无背景、圆角、业务文案、固定字体或保存按钮，不改变现有 FormField 外观。用于真实输入节点，不对包含多个字段的整个表单使用。
