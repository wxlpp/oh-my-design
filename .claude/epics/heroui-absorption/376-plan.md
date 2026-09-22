# Issue #376 计划：Banner 补齐（title / actions / dismiss，PRD FR-5）

## 文件清单

- `Sources/OhMyDesign/Components/Banner/Banner.swift`：配置字段、便利 init、两个 style 的新布局、无障碍结构。
- `Sources/OhMyDesign/Resources/en.lproj/Localizable.strings`：新增 A 类 chrome 键 `"Dismiss"`（关闭钮标签）。
- `Tests/OhMyDesignTests/BannerTests.swift`：行为测试。
- `docs/components/banner.md`、`docs/BREAKING-CHANGES.md`、`docs/component-registry.json`（Banner 条目 textParams）。
- `App/Sources/ComponentData.swift` / `Previews.swift`：完整形态预览（ScrollView，便于 AX5 截图）。
- 守卫台账：`ComponentTextParamGuard` 的 `byTypeCount`（+2：`Banner.title` / `Banner.message`）、`design-digest.py` 实测值。

## 公开 API

```swift
public struct BannerStyleConfiguration {
    public let label: Label            // 正文槽，语义不变
    public let level: StatusLevel
    public let title: Text?            // 新增
    public let actions: AnyView?       // 新增
    public let dismiss: (() -> Void)?  // 新增
}

extension Banner where Label == Text {
    public init<Actions: View>(
        level: StatusLevel,
        title: LocalizedStringKey? = nil,
        message: LocalizedStringKey,
        @ViewBuilder actions: () -> Actions = { EmptyView() },
        onDismiss: (() -> Void)? = nil
    )
}
```

- 单个 init + SE-0347 泛型默认实参：避免「有 / 无 actions」两个重载在尾随闭包上与 `onDismiss` 歧义。
  `Actions == EmptyView` 时 `configuration.actions` 为 `nil`。
- `title` / `message` 为调用方界面文案，只有 `LocalizedStringKey` 入口、无裸串孪生 ⇒ 登记 `by-type`。
- 既有 `init(level:label:)` 不变（title / actions / dismiss 均为 nil）。

## 布局与无障碍

- 内容组 = 图标 + (标题 headline) + 正文，`.accessibilityElement(children: .combine)`；图标不再 hidden，
  改用 `Timeline.accessibilityLabelKey(for:)` 的状态键作标签 ⇒ 读序「图标语义 / 标题 / 正文」。
- 动作行在内容组之外（独立节点）；`ViewThatFits(in: .horizontal)`：横排放不下时竖排，AX5 不截断。
- 关闭钮：`xmark`，仅 `dismiss != nil` 时出现；命中框 44×44，经负 padding 不撑高 banner；
  `accessibilityLabel(Text("Dismiss", bundle: .module))`。读序最后。
- 颜色沿用 `bannerPalette`（neutral 档不变）；标题取前景色。

## 测试清单（Swift Testing）

1. 便利 init：configuration 的 title / actions / dismiss 均非 nil，label 为正文。
2. 无 actions 的便利 init：actions 为 nil；无 onDismiss：dismiss 为 nil。
3. 既有 `init(level:label:)`：三个新字段均为 nil，类型仍为 `Banner<Text>`。
4. `configuration.dismiss` 调用 = 调用方回调被调用一次，Banner 无内部状态（再次渲染仍带关闭钮）。
5. 自定义 `BannerStyle` 经 `.bannerStyle` 收到含新字段的 configuration（渲染触发 makeBody）。
6. iOS：关闭钮命中框 ≥ 44pt；带关闭钮的 banner 高度不超过同内容无关闭钮的 banner + 容差（不撑高）。
7. 图标无障碍键覆盖五档且键已注册进 Localizable.strings。

AXe（手动，报告附输出）：关闭钮 / 动作按钮为独立 Button 节点，frame ≥ 44（关闭钮），激活后回调生效。
