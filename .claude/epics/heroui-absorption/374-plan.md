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
  - valid 与改动前实现（`92d224b` 原样拷贝的 Legacy*）在光栅化噪声内一致（`expectBitmapsEquivalent(maxChannelDelta: 1)`，两条腿；PinCode / TagInput / CheckBox / Radio）；
  - disabled + invalid 与 disabled + valid 逐像素一致；
  - invalid 出现 danger 像素、valid 没有（`assetCatalogIsCompiled` 腿）；
  - 无障碍：托管后读 iOS 可访问元素的 label / hint（iOS 腿），另以 AXe describe-ui 作证据。
- 文档：`docs/components/{pin-code,tag-input,search-field,radio,form-field}.md`（CheckBox 无独立文档则写进 form-field.md）。
- 预览宿主：`App/Sources/ComponentData.swift` 新增 `form-field-controls-{valid,invalid,disabled}` 三个直达条目。
- 公开 API：**无新增 / 无破坏**（不需要 BREAKING-CHANGES 条目，登记表不增条目）。

## 守卫台账

design-digest 按 `python3 scripts/design-digest.py` 实际值；Bool 基线、MainActor 豁免预计不变。

## 评审第 1 轮：无障碍证据

**进程内读不到真实节点（公开 API）**：iOS 测试里把控件放进 `UIHostingController` + `UIWindow`，遍历
`accessibilityElements`，托管视图下的元素数为 0。原生 `UISearchTextField` 及其宿主视图
（`UIKitPlatformViewHost`）的 `accessibilityLabel` / `accessibilityHint` 都是 `nil`，`isAccessibilityElement == false`。
经私有 SPI `_AXSApplicationAccessibilitySetEnabled(true)`（`dlopen` libAccessibility）打开后，SwiftUI 节点可读
（PinCode 各格为 `Code` / `Bad.`，CheckBox 为 `Accept` / `Bad.`）；原生搜索框仍然读不到。未采用：
私有 SPI、会改动整个测试进程的全局状态、仓库也没有先例。⇒ `FieldAccessibilityLabelPolicyTests` 改名为只声称
「判定函数」；真实节点的证据用下面这组 AXe 矩阵。

**AXe 矩阵**（iPhone 17 Pro / iOS 26.4，`axe describe-ui`，预览宿主直达条目。「改动前」= 在 `d9ee148` 上构建、
放入同一份 `ComponentData.swift` 的预览宿主）：

| 情形 | 条目 | 改动前 | 改动后 |
|---|---|---|---|
| 五个控件都不在 FormField 内、没有校验态 | `form-field-controls-plain` | PinCode 各格 label `Verification code`、无 hint；TagInput 输入框 label `Add tag`；SearchField label 为空；CheckBox `I accept…`；Radio `Basic` / `Pro`；全部无 hint | **逐项完全相同**（11 个节点的 label / value / hint 都一致） |
| 五个控件在 FormField 内且 invalid | `form-field-controls-invalid` | — | PinCode 每格：label `Verification code, required`，hint `The code has expired., Sent to your phone.`；TagInput 输入框：`Labels` / `Add at most 3 labels., Press Return or comma to add.`；SearchField：`Filter` / `No results match this filter.`；CheckBox 保留自身 label，hint 为错误原因（只出现一次）；Radio 每个选项保留标题，hint 为错误原因 + description |
| TagInput 删除按钮 | `form-field-controls-invalid` | — | 两个 `Remove tag` 按钮 hint 均为 `None` |
| 调用方自带 `.accessibilityLabel(...)` | `form-field-controls-edge` | `Caller search label` / `Caller toggle label`，无 hint | label **不被覆盖**（仍是 `Caller search label` / `Caller toggle label`），另挂上 hint `Filter is invalid.` / `Terms are required.` |
| 嵌套 FormField，内层自带 `.fieldValidation` | `form-field-controls-edge` | PinCode 各格 `Verification code`，无 hint | 取最近一层：label `Inner`，hint `Inner is wrong., Inner description.`（没有 Outer 的任何文本） |
