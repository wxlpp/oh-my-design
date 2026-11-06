# ProgressIndicator

通用圆形加载指示器 / Generic circular loading indicator.

使用圆头细弧与弱轨道，0.95秒匀速旋转。默认颜色来自 `coreAccent`，`tint:` 可覆盖。保留既有构造 API 和可选文案。

`controlSize` 对应可见直径 mini 14、small 16、regular 20、large / extraLarge 28pt。减少动态效果时保留静止弧；不活跃、离屏停止周期更新；低电量降帧。UIKit 保留的离屏 hosting cell 应通过 `scenePhaseOverride = .inactive` 明确暂停。

`ProgressView().progressViewStyle(.coreCircular)` 复用同一细弧，颜色仍经系统 `.tint`；有真实数值时继续显示确定进度环。

## API

| 参数 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| (none) | - | - | `init()`，不带文案；通过 `.controlSize(_:)` 调整尺寸 |
| text | `LocalizedStringKey` | - | `init(text:)`，静态文案，在 `Bundle.main` 本地化 |
| text | `some StringProtocol` | - | `init(text:)`，运行期字符串文案，verbatim 显示（`@_disfavoredOverload`，字面量优先落到 `LocalizedStringKey` 重载） |
| tint | `Color` | `nil` | spinner 取色。⚠️ **必须走这个参数**——本组件对系统 `ProgressView` 显式设 tint，内层恒胜外层，调用方外加的 `.tint(_:)` 会被**静默吞掉**（实测：外加 `.tint(.orange)` 时 spinner 仍是强调色、橙色零像素） |

三个 init 均保留既有 `accessibilityLabel("Loading")` 语义——带文案时，可视文案对 VoiceOver `.accessibilityHidden(true)`，避免与 label 双重播报。

## 预览 / Preview

运行 `scripts/run-snapshots.sh`（默认模式）后，预览图落地 `docs/snapshots/`——但前提是该组件已在 `App/Sources/Previews.swift` 注册（导出文件名形如 `OhMyDesignPreview_<组件名>.png`）；组件源码内自带的 `#Preview` 仅用于开发期本地预览，或经 `KEEP_LIBRARY_SNAPSHOTS=1 scripts/run-snapshots.sh` 导出到本地 scratch 目录做逐组件视觉核对（不写入 docs/snapshots，见 `.claude/epics/semi-mobile-components/phase0-decisions.md` §3）。

## 使用示例 / Usage

```swift
ProgressIndicator()
    .controlSize(.large)

// 带静态文案
ProgressIndicator(text: "Loading…")

// 带运行期字符串文案
ProgressIndicator(text: statusMessage)

// 与其他 SwiftUI 控件一起被外层 controlSize 影响
HStack {
    ProgressIndicator()
    Text("Loading…")
}
.controlSize(.small)
```

为任意内容整体叠加加载遮罩（而非只放一个 spinner），见 [`spinning` modifier](spinning.md)。

## 视觉 Token

- 默认 `coreAccent`，可经 `tint:` 覆盖。使用系统 ProgressViewStyle 时走 `.tint`。
- 轨道12%强度，细弧尾部40%到头部100%；无放大/缩小循环，不影响布局占位。
- 文案 `.coreFont(.footnote)`、`Color.contentSecondary`；间距 `CoreSpacing.sm`。
- 无障碍保留 Loading 或调用方文案，不为未知进度伪造百分比。
