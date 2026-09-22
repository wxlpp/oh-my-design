# TagInput

标签输入框 / Tag input field with inline chip entry.

`Binding<[String]>` 驱动：已有标签以 chip 形式展示，末尾内联一个文本输入框，
回车或逗号提交新标签，点击 chip 上的删除按钮移除标签。

## API

| 参数 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| tags | Binding<[String]> | - | 已提交标签的双向绑定，按添加顺序排列 |
| placeholder | String | "Add tag" | 输入框空态占位文案 |
| tagColor | Color | `.contentSecondary` | chip 调色板，透传给 `Tag(color:)` |
| allowDuplicates | Bool | false | 是否允许提交与已有标签完全相同（大小写敏感）的候选 |
| onCommit | ((String) -> Void)? | nil | 每次成功提交一个新标签后调用，参数为归一化后的文本 |

## 与 FlowLayout / Tag 的复用关系

- **折行**：复用 `FlowLayout(spacing: CoreSpacing.sm)`（8pt 为 `Tag` 删除按钮命中区纵向溢出所需下限，系对 168.md AC 写死的 `.xs` 的有意偏离，防相邻行删除按钮命中区重叠误删）——输入框作为其最后一个
  子视图，随已有标签数量自然换行到新行，不改动 `FlowLayout` 本身。
- **chip**：复用 `Tag(_:color:removable:onRemove:)`——拿到现成的 44pt 命中区
  删除按钮与已登记的 `"Remove tag"` 本地化键，不重造删除交互。`tagColor`
  默认 `Color.contentSecondary`（中性文本色），而非 `Tag` 常见的分类色板，
  因为标签输入场景通常不需要 GitHub-label 式的按色相分类。
- **chip 迭代**：`ForEach` over `TagInput.chips(for:)`——身份是「**标签值 + 该值的出现序号**」，
  既避免 `allowDuplicates: true` 时同名标签产生 `ForEach` id 碰撞，又让删除中间项时存活项的身份
  **不变**；删除仍按下标（`chip.index`）定位，精确命中目标 chip 而非误删同名的第一个。
  ⚠️ 本条原写「按下标取 id」（`id: \.offset`）——那个方案下删中间项会让其后**每一项**换身份，
  增删转场因此画在错的 chip 上（`#409` 改掉）。
  ⚠️ **重复标签的限制**（如实登记，不是「无限制」）：删掉某个重复值的**前一个**出现时，
  该值的后续出现序号会下降 ⇒ 它们在 `ForEach` 看来换了身份，会各播一次移除 + 插入转场。
  异值标签不受影响；`allowDuplicates: false`（默认）下标签唯一，身份完全稳定。

## 提交规则

- trim 首尾空白/换行后为空字符串的候选不提交（`normalizedTag(_:)`）。
- `allowDuplicates == false`（默认）时，与已有标签完全相等（大小写敏感，不做
  归一化）的候选不重复添加。
- 提交后清空输入框，无论走哪条提交路径。
- **Return 提交**：`TextField.onSubmit`，整段输入框内容作为单个候选提交。
- **逗号快速录入**（增强路径，非替代）：输入框内容包含 `,` 时即时拆分——除
  最后一段外的每一段各自按上述规则提交，最后一段留在输入框继续编辑。例如
  `"bug, enhancement,"` 会连续提交 `"bug"` 与 `"enhancement"`；`"bug,enh"`
  只提交 `"bug"`，`"enh"` 留在输入框内。

## 增删动效

- chip 的插入 / 移除走 `CollectionItemTransition`（`Tokens/CoreMotionToken.swift`）：完整动效下是
  缩放 0.86 + 淡变，Reduce Motion 下缩放在每一相都是 1、只剩透明度。
  ⚠️ 静息态那一侧在生产路径上**看不到**——驱动曲线是 `nil`（见下条），转场根本不播。
  它是「万一将来给静息态配上曲线」时的兜底，判据 `CollectionItemTransitionTests.restingNeverScales`
  钉的是这一格的配置，不是可见行为。
- 驱动曲线取 `CoreMotionToken.reveal`，经 `transformAnimation(for:)` ⇒ **Reduce Motion 下为 `nil`**：
  增删必然带来 `FlowLayout` 重排，而重排是位移；给静息态一条曲线只会把位移变慢，不会消掉它。
  `nil` 让增删「直接出现 / 消失」，是零位移的唯一取法。
- 静息（未播动画）外观**不随呈现裁决变化**：五档 `controlSize` × light / dark 下，
  `.animated` / `.resting` / `.hidden` 三种注入的位图在光栅化噪声内相同（判据
  `TagStaticAppearanceTests.tagInputIgnoresPresentationWhenSettled`，Δ ≤ 1、差异 ≤ 0.2%
  ——噪声来自同一进程里连渲多张时前几张的 1 个 LSB 量化差，不是呈现裁决，理由写在该判据的
  `expectSettledMatch` 文档注释里）。

### `FlowLayout` 重排实测

在 280pt 宽、6 个标签折成两行的 `TagInput` 上删掉第 2 个标签，macOS 托管窗口 20 ms 采样一次
（@2x 像素，行带按 y 分段统计红色 chip 像素）：

| 呈现 | 现象 |
|---|---|
| `.animated` | 第 2 行左边缘 x 由 0 依次经 10 → 35 → 55（峰）→ 36 → 22 → 15 → 9 → 6 → 4 → 3 → 2 → 1 回到 0，右边缘 223 → 163（谷）→ 218；第 1 行红色像素数 7318 → 5447（谷）→ 7410。**逐帧都是新值，没有突跳**：换行位置变化由存活标签连续移动完成 |
| `.resting` | 第 1 帧（t ≈ 0.03 s）就已等于终态（7410 / 2054），**一帧中间态都没有** |

⇒ 重排本身平滑，`FlowLayout` 不需要改动。

## 预览 / Preview

运行 `scripts/run-snapshots.sh`（默认模式）后，预览图落地 `docs/snapshots/`——但前提是该组件已在 `App/Sources/Previews.swift` 注册（导出文件名形如 `OhMyDesignPreview_<组件名>.png`）；组件源码内自带的 `#Preview` 仅用于开发期本地预览，或经 `KEEP_LIBRARY_SNAPSHOTS=1 scripts/run-snapshots.sh` 导出到本地 scratch 目录做逐组件视觉核对（不写入 docs/snapshots，见 `.claude/epics/semi-mobile-components/phase0-decisions.md` §3）。

## 使用示例 / Usage

```swift
@State private var tags: [String] = ["bug", "enhancement"]

TagInput(tags: $tags, placeholder: "Add tag") { committed in
    print("committed: \(committed)")
}
```

## 视觉 Token

- 折行容器：`FlowLayout(spacing: CoreSpacing.sm)`（8pt，见上「折行」节的命中区偏离说明）
- chip：`Tag(color: tagColor, removable: true, onRemove:)`
- 输入框字号：`CoreControlMetrics.fontToken(for: .regular)`
- 输入框文字色：`Color.contentPrimary`
- 输入框最小宽度：80pt（避免 `FlowLayout` 压缩到不可用宽度）
- 输入框最小高度：`CoreControlMetrics.height(for: .regular)`
- 校验态（`.fieldValidation(_:)`，见 `form-field.md`）：invalid 时整个字段底部叠一条
  `CoreBorderWidth.thin` 的 `Color.statusDangerForeground` 基线（overlay，不改布局），横跨字段全宽、
  落在最后一行（chips 与输入框共用的那一行）底部——`FlowLayout` 的宽度取提议宽度，所以基线随字段宽度走；
  disabled 优先于 invalid，禁用时不画。

## 无障碍

- 输入框的无障碍 label：放在 `FormField` 里时为字段 label（必填时追加「, required」），
  否则为 `Text(placeholder)`——`placeholder` 为调用方任意字符串，走 verbatim 渲染，
  与 `SearchField.placeholder` 处理方式一致。
- 错误原因与 `FormField` 的 description 作为 hint 挂在**输入框**上，不挂在 chip 的删除按钮上。
- chip 删除按钮的无障碍标签完全来自 `Tag` 内建的 `"Remove tag"`（Phase 0 已
  登记），本组件不重复声明。
