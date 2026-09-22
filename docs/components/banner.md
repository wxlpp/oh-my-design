# Banner

通栏式信息提示组件 / Full-width notification banner.

## API

### 便利 init：`Banner(level:title:message:actions:onDismiss:)`

| 参数 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| level | StatusLevel | - | 语义等级：info / success / warning / danger / neutral |
| title | LocalizedStringKey? | nil | 标题，headline 字重，显示在正文之上 |
| message | LocalizedStringKey | - | 正文 |
| actions | @ViewBuilder () -> Actions | 空 | 动作按钮；横排放不下（如 AX5 大字号）时自动竖排，不截断。按钮样式由调用方决定 |
| onDismiss | (() -> Void)? | nil | 关闭回调；非 nil 时右上角显示 `xmark` 关闭钮（命中区 44×44pt） |

Banner **无状态**：`onDismiss` 只回调，由调用方把 Banner 从视图树中移除。

### 通用 init：`Banner(level:label:)`

| 参数 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| level | StatusLevel | - | 语义等级 |
| label | () -> Label | - | 正文槽（任意视图） |

### 样式

支持 `View.bannerStyle(_:)` 注入外观，内置 `PlainBannerStyle`（默认）与 `BorderedBannerStyle`。
`BannerStyleConfiguration` 字段：`label`（正文槽，语义不变）、`level`、`title: Text?`、
`actions: AnyView?`、`dismiss: (() -> Void)?`。自定义 style 应渲染这三个可选槽，
并让动作与关闭钮保持为独立的可聚焦按钮（迁移见 `docs/BREAKING-CHANGES.md`）。

### 无障碍

- 图标 + 标题 + 正文合并为一个元素，读作「状态（Info / Success / Warning / Error / Neutral）、标题、正文」。
- 动作按钮与关闭钮（标签「Dismiss」）是独立的可聚焦、可激活节点。读序由 `accessibilitySortPriority`
  指定为 内容 → 动作 → 关闭（关闭钮几何上在右上角，不靠几何顺序）。AXe 的 `describe-ui` 不反映 sort priority，
  不能用来核对读序；读序需在真机 / 模拟器的 VoiceOver 下人工确认。
- 只用正文（未传 title / actions / onDismiss）时，布局与加入这些槽之前完全一致：banner 按内容宽度收缩、
  图标与正文居中对齐；加了任一新槽才切换为撑满宽度、首行基线对齐的布局。

## 预览 / Preview

运行 `scripts/run-snapshots.sh`（默认模式）后，预览图落地 `docs/snapshots/`——但前提是该组件已在 `App/Sources/Previews.swift` 注册（导出文件名形如 `OhMyDesignPreview_<组件名>.png`）；组件源码内自带的 `#Preview` 仅用于开发期本地预览，或经 `KEEP_LIBRARY_SNAPSHOTS=1 scripts/run-snapshots.sh` 导出到本地 scratch 目录做逐组件视觉核对（不写入 docs/snapshots，见 `.claude/epics/semi-mobile-components/phase0-decisions.md` §3）。

## 使用示例 / Usage

```swift
Banner(level: .info) {
    Text("A pre-released version is available.")
}

Banner(level: .warning, title: "Storage almost full", message: "Free up space to keep syncing.") {
    Button("Manage storage") { /* … */ }
} onDismiss: {
    self.showStorageBanner = false
}
.bannerStyle(BorderedBannerStyle())
```

## 视觉 Token

- 布局：图标与文字列首行基线对齐，`CoreSpacing.sm` icon-to-label 间距；标题与正文间距 `CoreSpacing.xxs`；
  动作行与文字列左缘对齐、在正文下方 `CoreSpacing.md`；关闭钮居右上，命中区 ≥ 44pt，占位随 Dynamic Type 缩放，
  经负内边距不撑高 banner；`CoreSpacing.md` 内边距
- 字号：正文 `.callout`，标题 `.headline`
- 颜色（有标题时标题取状态前景色、正文取 `contentPrimary`；无标题时正文取状态前景色；关闭钮恒为 `contentSecondary`）：按 `StatusLevel` 走 status color token（`statusAccentForeground` / `statusAccentSubtle` / `statusAccentBorder` 等）；
  `neutral` 不取状态色：图标 `contentSecondary`、正文 `contentPrimary`、背景 `statusNeutralSubtle`（第 2 层 `systemGray5`，不透明——叠在分组画布、白底卡片或图片上视觉重量不变；macOS 取 `unemphasizedSelectedContentBackgroundColor`，是外观近似而非语义等价，增强对比度与 vibrancy 下的表现未经验证）、描边 `borderDefault`
- 图标：`info.circle.fill` / `exclamationmark.triangle.fill` / `exclamationmark.circle.fill` / `checkmark.circle.fill` / `bell.fill`（neutral）
- 形状：容器为 `CoreRadius.medium` 连续圆角（Plain 与 Bordered 都是），不裁切内容——内边距 `CoreSpacing.md` 保证图标、正文、动作与关闭钮都落在圆角以内
- 描边（BorderedBannerStyle）：`CoreBorderWidth.thin`，沿同一圆角形状内描（`strokeBorder`）
