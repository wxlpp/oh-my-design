# Tag

任意分类标签 / Caller-colored label chip.

## API

| 参数 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| text | String | - | 标签文本 |
| color | Color | - | 调色板，驱动衬底与前景色 |
| removable | Bool | false | 是否显示关闭按钮 |
| onRemove | (() -> Void)? | nil | 关闭按钮回调 |

也可使用 `Tag(color:removable:onRemove:label:)` 自定义 label 视图。

尺寸跟随环境 `\.controlSize`：字号、内边距与关闭钮图标都随档变化，取值来自 `CoreControlMetrics` 的紧凑查询（与 `Badge` 同一组）；
`.regular`（缺省）档与接入尺寸体系前的外观一致。

## 预览 / Preview

运行 `scripts/run-snapshots.sh`（默认模式）后，预览图落地 `docs/snapshots/`——但前提是该组件已在 `App/Sources/Previews.swift` 注册（导出文件名形如 `OhMyDesignPreview_<组件名>.png`）；组件源码内自带的 `#Preview` 仅用于开发期本地预览，或经 `KEEP_LIBRARY_SNAPSHOTS=1 scripts/run-snapshots.sh` 导出到本地 scratch 目录做逐组件视觉核对（不写入 docs/snapshots，见 `.claude/epics/semi-mobile-components/phase0-decisions.md` §3）。

## 使用示例 / Usage

```swift
Tag("bug", color: .red)
Tag("enhancement", color: .blue, removable: true, onRemove: { print("dismissed") })
Tag("small", color: .purple)
    .controlSize(.small)
Tag(color: .green, removable: true, onRemove: {}) {
    Label("verified", systemImage: "checkmark.seal.fill")
}
```

## 视觉 Token

- 圆角：`CoreControlMetrics.compactCornerRadius(for:)`（4 / 5 / 6 / 7 / 8，regular 为 `CoreRadius.small`），圆角矩形与 Badge 的 pill 形态区分
- 字号：`CoreControlMetrics.compactFontToken(for:)`
- Padding：横向 `CoreControlMetrics.compactHorizontalPadding(for:)`，纵向 `CoreControlMetrics.compactVerticalPadding(for:)`
- 最小高度：`CoreControlMetrics.compactMinHeight(for:)`（与 Badge 同一张表）
- 背景：`color.opacity(0.12)` 衬底
- 前景：直接使用 `color`
- 关闭按钮：`xmark.circle.fill`，尺寸 `CoreControlMetrics.compactIconSize(for:)`（mini 10 / small 12 / regular 14 / large 16 / extraLarge 18）。
  关闭钮不参与行高（可删除与普通 Tag 等高），点击热区仍向外扩 `CoreSpacing.md + CoreSpacing.xxs`
