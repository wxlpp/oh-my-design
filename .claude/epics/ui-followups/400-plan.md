# Issue #400 plan — 输入控件跟进（FR-C1…FR-C6，来源 #384 评论 8 / 9）

公开 API：无新增、无破坏。视觉变化登记 `docs/BREAKING-CHANGES.md`。

## 残影来源（FR-C4，改动前已查清）

- 位置：`PinCode` 的 `ZStack` 里，隐藏 `TextField` 带 `.fixedSize()`，宽度只有文本宽（值 `"12"` 时 17pt），
  居中落在第 3、4 格之间的 `CoreSpacing.sm` 空隙里 —— 空隙处没有格子背景遮挡。
- 内容：`UITextField.text` 就是当前值，`textColor` 为默认黑（托管探针读出 `0 0 0 1`）。
- 强度：SwiftUI 的 `.opacity(0.01)` 落在 `UIKitPlatformViewHost` 上（`alpha = 0.01`）。`layer.render(in:)`
  下偏差只有逐通道约 3 级；**模拟器真实截图**里空隙处偏差达 26 级（242 → 216），肉眼可见 —— 所以只靠调低
  opacity 不能证明消除。
- 处置：隐藏输入框的文字与光标改用透明色（`.foregroundStyle(Color.clear)` + `.tint(Color.clear)`），
  opacity、`focused`、`textContentType(.oneTimeCode)`、`keyboardType(.numberPad)`、无障碍隐藏全部不动。

## 外观改动

| FR | 控件 | 改动 |
|---|---|---|
| C1 | TagInput | invalid 下划线从输入框 overlay 挪到 `FlowLayout` 整体底部；`FlowLayout` 宽度 = max(提议宽度, 最宽行)，下划线横跨整个字段 |
| C2 | RadioGroup | invalid + 选中：`circle.inset.filled` 用 `.palette`（primary = 实心点取原色 `contentPrimary`，secondary = 圆环取 danger）；未选中圆环照旧 danger；valid 分支代码原样 |
| C3 | PinCode | 获焦格在 invalid 下除 `thick` 红边外，再在格外画一圈 `CoreBorderWidth.thicker` 的 `statusDangerMuted` 光晕（不占布局） |
| C4 | PinCode | 见上 |
| C5 | CheckBox / RadioGroup | `FieldAppearance.controlOpacity`：disabled 0.4（与 `TagGroup` / 按钮样式的禁用不透明度一致），其余 1；施加在整行（图标 + 文字） |
| C6 | SearchField | 包装层 `frame(minHeight:)` 后加 `.fixedSize(horizontal: false, vertical: true)`：两端都取固有高度（下限 44pt）；预览宿主去掉三处为此加的 `fixedSize` |

## 测试

- `FieldValidationControlsTests`：
  - C1：invalid 的 danger 下划线像素横跨整个字段宽度（iOS 腿，编译 catalog）；valid 不变的既有判据保留。
  - C2：invalid 选中行里点的中心像素 = valid 选中行点中心像素（contentPrimary），圆环上有 danger 像素。
  - C3：获焦 + invalid 格与非获焦 invalid 格位图不同，且 danger 类像素（含光晕）明显更多；获焦 valid 与旧实现一致。
  - C5：disabled 与 `旧实现.opacity(0.4)` 等价、与 enabled 不同；enabled 与旧实现逐像素一致；disabled + invalid 与 disabled + valid 一致。
- `PinCodeHiddenFieldTests`（iOS 托管）：隐藏 `UITextField` 的 `textColor` / `tintColor` α = 0；
  把隐藏输入框的宿主视图 `isHidden` 前后两次 `layer.render` 逐像素相同；`insertText` 后绑定值更新（输入行为不变）。
- `SearchFieldHostedSnapshotTests`（iOS）+ 新 macOS 托管套件：300pt 高容器里 SwiftUI 视图高度 = 固有高度，
  原生框 frame 与位图等于 `旧实现.fixedSize(vertical)`。

## 文档

`docs/components/{pin-code,tag-input,radio,search-field,form-field}.md`、`docs/BREAKING-CHANGES.md`。
