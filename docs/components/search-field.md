# SearchField

搜索输入框 / Search input field.

## API

| 参数 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| text | Binding<String> | - | 搜索文本的双向绑定 |
| placeholder | String | "Search" | 空文本占位提示 |
| onSubmit | ((String) -> Void)? | nil | Return 提交回调 |

## 预览 / Preview

运行 `scripts/run-snapshots.sh`（默认模式）后，预览图落地 `docs/snapshots/`——但前提是该组件已在 `App/Sources/Previews.swift` 注册（导出文件名形如 `OhMyDesignPreview_<组件名>.png`）；组件源码内自带的 `#Preview` 仅用于开发期本地预览，或经 `KEEP_LIBRARY_SNAPSHOTS=1 scripts/run-snapshots.sh` 导出到本地 scratch 目录做逐组件视觉核对（不写入 docs/snapshots，见 `.claude/epics/semi-mobile-components/phase0-decisions.md` §3）。

## 使用示例 / Usage

```swift
@State private var query = ""

SearchField(text: $query, placeholder: "Filter issues") { submitted in
    viewModel.runSearch(submitted)
}
```

## 视觉 Token

⚠️ **本节整段已作废。** 组件内部改用**平台原生**搜索框
（iOS `UISearchTextField` / macOS `NSSearchField`），背景、边框、圆角、放大镜、
清除按钮、占位文案、焦点态、RTL 镜像与 Dynamic Type **全部由平台提供**，
库不再逐项指定这些 token。

⚠️ 上一版本节自身也已失真（写 `surfaceCanvasInset` / `CoreRadius.medium`，
而代码是 `surfaceInteractive` / `CoreRadius.small`）——一并记在这里，
说明「逐 token 抄一遍视觉」这种文档形态本身就容易掉队。

仍由库指定的只有两项：

- **命中区高度**：`CoreControlMetrics.height(for: .regular)` = 44pt，由外层包装层承担。
  包装层纵向 `fixedSize`，整个控件取固有高度（44pt），放进不限高的容器（如占满一屏的
  `VStack`）也**不会被纵向拉伸**，调用方不需要再加 `fixedSize`。⚠️ 这一条只对 iOS 有实际作用：
  `UISearchTextField` 的绘制带随 frame 撑满，没有它就会被拉高；macOS `NSSearchField` 本身取
  固有高度（24pt），改动前后布局相同（`SearchFieldIntrinsicHeightTests`，两端托管窗口实测）。
  调用方显式给更高的框（如 `.frame(height: 60)`）时，原生搜索框同样保持 44pt、垂直居中于该框，框内多出的
  空白不属于命中区；外层 frame 无法把原生搜索框撑高（`SearchFieldIntrinsicHeightTests`）。
  包装层用 `contentShape` + tap 转 `becomeFirstResponder()` 把命中区上下缘也接上。
- **横向撑满**：`frame(maxWidth: .infinity)`。

## 校验态与禁用 / Validation and disabled

- 读 `.fieldValidation(_:)`（见 `form-field.md`）：invalid 时在原生搜索框外沿叠一圈
  `CoreBorderWidth.thin` 的 `Color.statusDangerForeground` 胶囊描边（叠在 representable 自身
  bounds 上，贴合绘制带，不改布局、不拦截点击）；disabled 优先于 invalid，禁用时不画。
- 无障碍：放在 `FormField` 里时，原生搜索框的 label 为字段 label（必填时追加「, required」），
  错误原因与 description 为 hint（AXe 实测读在原生 `TextField` 节点上）。
- iOS 回车键为「搜索」（`returnKeyType = .search`）。
- **`.disabled(true)`**：分析报告曾从源码推断「`isEnabled` 未透传给原生控件」。运行期实测
  **复现不出**：SwiftUI 对 representable 承载的 `UIControl` / `NSControl` 自动同步 `isEnabled`
  （`SearchFieldNativeStateTests`：默认 `true`、`.disabled(true)` 为 `false`、运行期切换双向跟随，
  iOS Simulator 与 macOS 两端一致；模拟器里对禁用的搜索框点按后输入，值不变）。因此**未加**
  手动透传代码，测试留作回归判据。禁用外观由系统提供：iOS 背景退为灰底，取值文字颜色不变。

⚠️ **`#222` 的 a11y 行为改由系统提供**：清除按钮及其可访问名现在来自平台，
库不再自带 `clearLabel(for:)`，`Localizable.strings` 里的 `"Clear %@"` 已移除。
