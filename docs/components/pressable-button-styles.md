# PressableRowButtonStyle / PressableCardButtonStyle

按压反馈样式：把一整条行、一张卡片做成可点击区域 / Press-feedback styles for tappable rows and cards.

## API

| 静态入口 | 返回类型 | 按下时 | reduce motion 下按下 | 禁用 |
|---|---|---|---|---|
| `.pressableRow` | `PressableRowButtonStyle` | label 之上叠一层 `Color.pressedBackground`（半透明，不拦点击） | 同左（不涉及动效） | 不给反馈，整体 `opacity 0.4` |
| `.pressableCard` | `PressableCardButtonStyle` | label 按 `CoreButtonMetrics.pressedScale`（0.94）缩放 | **不缩放**，只变暗（`opacity 0.7`） | 不给反馈，整体 `opacity 0.4` |

两者都是无参数 `init()`，经 `ButtonStyle` 的静态成员使用；按下 / 抬起有 0.15s 的 ease-out 过渡。

## 与《按钮样式模式》的有意例外

仓库的按钮样式约定（`CLAUDE.md`《按钮样式模式》）是：`*ButtonStyle` + `static func *Button(role:)`，
由 `ButtonRoleStyleRole` 提供色板、从 `\.controlSize` 读尺寸。这两个样式**有意不遵守**：

- **不接 role**：它们不给 label 上色，也不画按钮底色——label 的外观（`SettingsRow`、`Card` 或任意自绘内容）完全由调用方决定，只叠加按压反馈。
- **不按 `controlSize` 改布局**：不加内边距、不定高度、不换字号。样式包进去之后 label 的尺寸不变（`PressableButtonStyleTests` 用渲染尺寸对比核对）。
- **入口是静态属性而非 `*Button(role:)` 工厂**：没有可参数化的东西。

它们与 `.solidButton` / `.lightButton` 这类「按钮外观」不是一族，而是给已有内容加点击反馈的装饰层；
需要按钮外观时仍走 role 参数化的那一族。

## 预览 / Preview

预览宿主 `App/Sources/ComponentData.swift` 的 `pressable-button-styles` 条目展示 `SettingsRow` 行（含禁用行）与 `Card` 包进这两个样式的静态态；
源码内 `#Preview("Pressable ButtonStyles")` 可在 Xcode 里按住查看按压态。

## 使用示例 / Usage

```swift
InsetGroupedSection(header: "General") {
    Button { openWiFi() } label: {
        SettingsRow(icon: .init(systemName: "wifi", background: .blue), title: "Wi-Fi") {
            SettingsRowChevron()
        }
    }
    .buttonStyle(.pressableRow)
}

Button { openDetail() } label: {
    Card { Text("Weekly report") }
}
.buttonStyle(.pressableCard)
```

## 视觉 Token

- 行按下高亮：`Color.pressedBackground`（委托 `tertiaryFill` 系统色，本身半透明），以 overlay 铺满 label 的矩形区域——叠在行自带背景（`ListRow` 的 `.surface(.canvas)`、分组卡片的 raised 底）**之上**，放在背后会被这些不透明背景整个盖住；文字透过这层半透明色仍清晰可读。label 同时获得矩形 `contentShape`，行内空白处也可点
- 卡片按下缩放：`CoreButtonMetrics.pressedScale`
- 禁用透明度 0.4 与 `CircularGlassButtonStyle` / `ExtendedFloatButtonStyle` 的禁用态一致
