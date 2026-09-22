# Issue #374 plan — 5 个控件接入校验态 + SearchField 修复（FR-2 / FR-3）

## 复用的基础层（#373）

- 外观：`FieldAppearance.resolve(isEnabled:validation:isFocused:)`（disabled > invalid > focused）。
- 无障碍：`FieldAccessibilityHint` + `FormFieldAccessibility.label`，经 `FieldAccessibilityModifier` 挂到节点。
  本 Issue 给该 modifier 加一个内部参数（label 策略），公开 `View.fieldAccessibility()` 行为不变：
  - `fieldLabel(fallback:)`：文本输入节点（PinCode 逐格、TagInput 输入框、SearchField）——在 `FormField`
    内用字段 label（含必填），不在时用控件原有 label（`"Verification code"` / placeholder），hint = 错误原因 + description。
  - `keepOwn`：选择类节点（CheckBox 的 Toggle、Radio 的每个选项）——保留选项自身 label（否则三个选项全读成同一个字段名），只挂 hint。
- 播报：仍由 `FormField` 发出，控件不另播报（避免重复）。

## 外观（只改 invalid 分支；normal / focused / disabled 分支原样）

| 控件 | invalid |
|---|---|
| PinCode | 每格描边 `statusDangerForeground`；当前格保留 `thick` 线宽（位置提示），颜色让位于 danger |
| TagInput | 输入框底部一条 `CoreBorderWidth.thin` 的 `statusDangerForeground` 描边线（overlay，不改布局） |
| SearchField | 原生搜索框绘制带外沿一圈 danger 描边（SwiftUI overlay，高度取原生 `intrinsicContentSize`，不改布局） |
| CheckBoxToggleStyle | 方框 / 勾选图标 `statusDangerForeground` |
| RadioGroup | 圆点图标 `statusDangerForeground` |

disabled + invalid → 走 disabled 分支 = 与 disabled + valid 逐像素一致。

## FR-3 SearchField

- 先运行期复现：`SearchFieldNativeStateTests` 在 macOS native 与 iOS Simulator 上读底层
  `NSSearchField.isEnabled` / `UISearchTextField.isEnabled`。**首轮实测两端都已是 `false`**（SwiftUI 对
  representable 的 `NSControl` / `UIControl` 自动同步 `isEnabled`，含运行期切换）⇒ 缺陷复现不到，按 PRD
  「复现不出则登记、不硬改」：不加透传代码，测试留作回归判据，结论登记进 `docs/components/search-field.md`。
- iOS `returnKeyType = .search`（`makeUIView`），测试已红。

## 文件清单

- `Sources/OhMyDesign/Components/FormField/FieldValidation.swift`：modifier 加 label 策略（internal）。
- `PinCode.swift` / `TagInput.swift` / `SearchField.swift` / `CheckBox.swift` / `Radio.swift`。
- 测试：`SearchFieldNativeStateTests.swift`（新）、`FieldValidationControlsTests.swift`（新）：
  - 外观解析映射（纯函数，两条腿）；
  - valid 与改动前实现（`60c8616` 原样拷贝的 Legacy*）逐像素一致（`expectBitmapsEqual`，两条腿；PinCode / TagInput / CheckBox / Radio）；
  - disabled + invalid 与 disabled + valid 逐像素一致；
  - invalid 出现 danger 像素、valid 没有（`assetCatalogIsCompiled` 腿）；
  - 无障碍：托管后读 iOS 可访问元素的 label / hint（iOS 腿），另以 AXe describe-ui 作证据。
- 文档：`docs/components/{pin-code,tag-input,search-field,radio,form-field}.md`（CheckBox 无独立文档则写进 form-field.md）。
- 预览宿主：`App/Sources/ComponentData.swift` 新增 `form-field-controls-{valid,invalid,disabled}` 三个直达条目。
- 公开 API：**无新增 / 无破坏**（不需要 BREAKING-CHANGES 条目，登记表不增条目）。

## 守卫台账

design-digest 按 `python3 scripts/design-digest.py` 实际值；Bool 基线、MainActor 豁免预计不变。
