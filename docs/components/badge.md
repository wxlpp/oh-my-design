# Badge

GitHub 风格的状态指示器 / GitHub-style status indicator.

## API

| 参数 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| text | String | - | 显示的文本 |
| variant | BadgeVariant | .neutral | 语义等级：info / success / warning / danger / neutral |
| outlined | Bool | false | 是否带描边 |

也可使用 `Badge(variant:outlined:label:)` 自定义 label 视图（如含 SF Symbol）。

尺寸跟随环境 `\.controlSize`（`.controlSize(.small)` 等），五档字号与内边距取自 `CoreControlMetrics` 的紧凑查询；
`.regular`（缺省）档与接入尺寸体系前的外观一致。

## 预览 / Preview

运行 `scripts/run-snapshots.sh`（默认模式）后，预览图落地 `docs/snapshots/`——但前提是该组件已在 `App/Sources/Previews.swift` 注册（导出文件名形如 `OhMyDesignPreview_<组件名>.png`）；组件源码内自带的 `#Preview` 仅用于开发期本地预览，或经 `KEEP_LIBRARY_SNAPSHOTS=1 scripts/run-snapshots.sh` 导出到本地 scratch 目录做逐组件视觉核对（不写入 docs/snapshots，见 `.claude/epics/semi-mobile-components/phase0-decisions.md` §3）。

## 使用示例 / Usage

```swift
Badge("Beta", variant: .info)
Badge("Draft", variant: .warning, outlined: true)
Badge("New", variant: .success)
    .controlSize(.large)
Badge(variant: .success) {
    HStack(spacing: CoreSpacing.xxs) {
        Image(systemName: "checkmark")
            .accessibilityHidden(true)
        Text("Merged")
    }
}
```

## 视觉 Token

- 圆角：`Capsule()`（pill 形态）
- 字号：`CoreControlMetrics.compactFontToken(for:)`（mini `caption2` / small `caption` / regular `footnote` / large `subheadline` / extraLarge `callout`）
- Padding：横向 `CoreControlMetrics.compactHorizontalPadding(for:)`，纵向 `CoreControlMetrics.compactVerticalPadding(for:)`（regular 档为 `CoreSpacing.sm` / `CoreSpacing.xs`）
- 背景色：`Color.surfaceCanvasSubtle`（neutral）/ status background token（info/success/warning/danger）
- 边框（`outlined: true` 时）：`Color.borderMuted`（neutral）/ status border token，宽度 `CoreBorderWidth.thin`
