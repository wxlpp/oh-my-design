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
- 动作按钮与关闭钮（标签「Dismiss」）是独立的可聚焦、可激活节点，读序在正文之后：动作 → 关闭。

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
  动作行在文字下方、间距 `CoreSpacing.sm`；关闭钮居右上，44pt 命中区经负内边距不撑高 banner；`CoreSpacing.md` 内边距
- 字号：正文 `.callout`，标题 `.headline`
- 颜色（标题与正文同取前景色，关闭钮取图标色）：按 `StatusLevel` 走 status color token（`statusAccentForeground` / `statusAccentSubtle` / `statusAccentBorder` 等）；
  `neutral` 不取状态色：图标 `contentSecondary`、正文 `contentPrimary`、背景 `tertiaryFill`、描边 `borderDefault`
- 图标：`info.circle.fill` / `exclamationmark.triangle.fill` / `exclamationmark.circle.fill` / `checkmark.circle.fill` / `bell.fill`（neutral）
- 描边（BorderedBannerStyle）：`CoreBorderWidth.thin`
