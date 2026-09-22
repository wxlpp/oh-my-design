# Issue #400 plan — 输入控件跟进（FR-C1…FR-C6，来源 #384 评论 8 / 9）

公开 API：无新增、无破坏。视觉变化登记 `docs/BREAKING-CHANGES.md`。

## 残影来源（FR-C4，改动前已查清）

- 位置：`PinCode` 的 `ZStack` 里，隐藏 `TextField` 带 `.fixedSize()`，宽度只有文本宽（值 `"12"` 时 17pt），
  居中落在第 3、4 格之间的 `CoreSpacing.sm` 空隙里 —— 空隙处没有格子背景遮挡。
- 内容：`UITextField.text` 就是当前值，`textColor` 为默认黑（托管探针读出 `0 0 0 1`）。
- 强度：SwiftUI 的 `.opacity(0.01)` 落在 `UIKitPlatformViewHost` 上（`alpha = 0.01`）。空隙处逐通道约差 3 级
  （模拟器截图 242 → 239，`layer.render(in:)` 同量级），在均匀底色上肉眼可辨；再调低 opacity 只是把差值变小，
  不能证明消除。
- 处置：隐藏输入框的文字与光标改用透明色（`.foregroundStyle(Color.clear)` + `.tint(Color.clear)`），
  opacity、`focused`、`textContentType(.oneTimeCode)`、`keyboardType(.numberPad)`、无障碍隐藏全部不动。

## 外观改动

| FR | 控件 | 改动 |
|---|---|---|
| C1 | TagInput | invalid 下划线从输入框 overlay 挪到 `FlowLayout` 整体底部；`FlowLayout` 宽度 = max(提议宽度, 最宽行)，下划线横跨整个字段 |
| C2 | RadioGroup | invalid + 选中：`circle.inset.filled` 用 `.palette`（primary = 实心点取原色 `contentPrimary`，secondary = 圆环取 danger）；未选中圆环照旧 danger；valid 分支代码原样 |
| C3 | PinCode | 获焦格在 invalid 下除 `thick` 红边外，再在格外画一圈 `CoreBorderWidth.thicker` 的 `statusDangerForeground` 30% 光晕（不占布局） |
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
  藏掉隐藏输入框前后两次渲染逐像素相同（两端）；键盘 / OTP 配置不变（iOS）。进程内 `insertText` 能改到
  `UITextField.text` 却不回写 SwiftUI 绑定（托管测试环境的限制，改动前后一致），键入 / 退格 / 粘贴改用
  模拟器 AXe 对照：改动前后同一序列得到同一取值（`1234` → `123` → `123987`）。
- `SearchFieldHostedSnapshotTests`（iOS）+ 新 macOS 托管套件：300pt 高容器里 SwiftUI 视图高度 = 固有高度，
  原生框 frame 与位图等于 `旧实现.fixedSize(vertical)`。

## 文档

`docs/components/{pin-code,tag-input,radio,search-field,form-field}.md`、`docs/BREAKING-CHANGES.md`。

## 评审第 1 轮

- PinCode 输入行为：macOS 进程内获焦编辑（末尾键入 / 部分选区替换 / 全选替换）写回绑定；iOS 进程内 `insertText`
  不回写绑定，改走预览宿主 + AXe，改动前后同一序列（键入 `3a4`、退格、⌘A 后键入 `56`、⌘A 后粘贴 `987654`）
  得到相同取值与逐格无障碍 value；数字键盘截图逐像素相同。
- 编辑态残影：macOS 深色全选时系统选区高亮仍差 2 个色阶（不跟 `tint`），隐藏输入框改为再加
  `.clipShape(Rectangle().size(.zero))`；判据覆盖未获焦 / 光标 / 全选三态，两端 light / dark。
  随之 PinCode 的像素对照基准改为旧实现的格子行（旧隐藏输入框即使为空值也留 ±2 的像素）。
- 未验证：短信 OTP 的 QuickType 建议（模拟器收不到短信）、听写（数字键盘无听写键）、真实 VoiceOver 朗读。
- SearchField：显式 `.frame(height: 60)` 时，改动前 iOS 原生框被撑到 60pt，现在保持 44pt 居中；外层 frame
  无法恢复原生框的高度与命中区（BREAKING-CHANGES 写明）。
