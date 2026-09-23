# Button

Apple HIG 风格按钮样式 / Apple HIG-styled button styles.

## API

| 静态方法 | 返回类型 | 说明 |
|---|---|---|
| `.solidButton(role:)` | `SolidButtonStyle` | 实色背景按钮，主要 CTA |
| `.lightButton(role:)` | `LightButtonStyle` | 轻量按钮，次要操作 |
| `.borderless(role:)` | `CoreBorderlessButtonStyle` | 无边框按钮，行内链接 |
| `.circularGlass` / `.circularGlass(size:)` | `CircularGlassButtonStyle` | 圆形玻璃浮按钮（send / stop 一类），默认 `.large` = 40pt |
| `.circularGlass(diameter:)` | 同上 | 逃生舱：绕过档位直接给直径，用于 metrics 序列覆盖不到的非标尺寸 |

> ⚠️ **`.borderless` 必须带括号。** 访问器名与 SwiftUI 自带的
> `PrimitiveButtonStyle.borderless` 重合，两者只差一对括号且都能编译、无诊断：
> `.buttonStyle(.borderless)` 拿到的是 **SwiftUI 的**样式，
> `.buttonStyle(.borderless())` 才是 OhMyDesign 的。

| 参数 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| role | ButtonRoleStyleRole | .primary | 角色色板 |

`ButtonRoleStyleRole`: primary / secondary / tertiary / warning / danger。

**按压反馈**（#407）：`.solidButton` / `.lightButton` / `.circularGlass`（经 `TelegramGlassButtonModifier`）按下时缩到
`CoreButtonMetrics.pressedScale`（0.94），曲线 `CoreMotionToken.press`（`.snappy`，0.16 s）；Reduce Motion 下不缩放，
改为按下透明度 0.7，与样式自带的按下透明度（`.lightButton` / `.circularGlass` 0.9、`.solidButton` 0.92）取较小值、不叠乘
（禁用的 `.circularGlass` 整体 0.4；禁用按钮拿不到按下态）。`.borderless()` 只变色，曲线同为 `CoreMotionToken.press`
（#407 前是默认时长的 `.easeInOut`）。

## 预览 / Preview

运行 `scripts/run-snapshots.sh`（默认模式）后，预览图落地 `docs/snapshots/`——但前提是该组件已在 `App/Sources/Previews.swift` 注册（导出文件名形如 `OhMyDesignPreview_<组件名>.png`）；组件源码内自带的 `#Preview` 仅用于开发期本地预览，或经 `KEEP_LIBRARY_SNAPSHOTS=1 scripts/run-snapshots.sh` 导出到本地 scratch 目录做逐组件视觉核对（不写入 docs/snapshots，见 `.claude/epics/semi-mobile-components/phase0-decisions.md` §3）。

## 使用示例 / Usage

```swift
Button("Login") {}
    .buttonStyle(.solidButton(role: .primary))
Button("Cancel") {}
    .buttonStyle(.lightButton(role: .secondary))
Button("Delete") {}
    .buttonStyle(.borderless(role: .danger))
    .disabled(true)
```

## 同族按钮组件

按钮**样式**在本文件；按钮**组件**（自带异步 / 状态语义的 `View`）各有独立文档：

- [`AsyncButton`](../../Sources/OhMyDesign/Components/Button/AsyncButton.swift) —— 把
  `async` 闭包封成按钮，执行期间用系统 spinner 替换 label；出错走 `onError` 或自动弹 toast。
- [`StatefulButton`](stateful-button.md) —— idle / loading / success / failure 四态视觉回执，
  自管与托管两种模式，防重入门闩不看视觉态。何时用哪个见该文档的《与 `AsyncButton` 的分工》。

两者都是包裹 `Button` 的 `View`，chrome 仍由本文件的 `ButtonStyle` 决定。

## 视觉 Token

- 圆角：`Capsule()`（pill 形态）
- 字号 / padding / icon：由 `@Environment(\.controlSize)` 通过 `CoreControlMetrics` 决定
- SolidButton 背景：`role.resolvedColor(accent:isEnabled:isPressed:)`，`accent` 取自环境 `\.coreAccent`
  ⚠️ 只有 `.primary` role 跟随 `coreAccent`；其余四个 role 有意留在自有色阶（`secondaryAccent` / `neutralAccent` / `warning*` / `danger*`）
- SolidButton 前景：`role.resolvedOnColor(accent:on:environment:)`——`.primary` 缺省按 accent 在当前外观下的亮度派生黑 / 白（`View.coreAccent(_:on:)` 的 `on` 参数可覆盖），其余四 role 走 `contentOnAccent`（随主题反转）
- SolidButton 阴影：`CoreElevation.small`
- LightButton 暗色：`.glassEffect(.regular)`；亮色：`Color.surfaceInteractive` + `CoreElevation.small`
- CoreBorderlessButtonStyle 无视觉容器（无背景/边框/阴影），但字号、padding 与命中区仍走 `CoreControlMetrics` token
- 颜色映射见 `ButtonRoleStyleRole`：primary → `.accent`，secondary → `.secondaryAccent`，tertiary → `.neutralAccent`，warning → `.warning`，danger → `.danger`
