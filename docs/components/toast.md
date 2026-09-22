# Toast

Scene 级 Toast 通知 / Scene-scoped toast notification.

## API

### ToastHost (通过 Environment 获取)

`ToastHost` 是 `@Observable` 类，非 View，通过 `@Environment(\.toastHost)` 获取，不直接放入视图层级。

```swift
@Observable final class ToastHost { ... }
```

| 方法 | 说明 |
|---|---|
| `show(_ title: String, description: String? = nil, level: StatusLevel = .info, duration: ToastDuration = ToastDefaults.duration)` | 入队一条 toast（level 缺省 `.info`，duration 缺省 `.seconds(3)`） |
| `show(_ item: ToastItem)` | 入队预构造的 ToastItem（带 `action` 时用这个入口） |
| `dismiss(_ id: ToastItem.ID)` | 关闭指定 toast：正在显示的进入退场动画，排队中的直接移除 |
| `dismissAll()` | 清空当前与排队中的全部 toast；退场动画进行中调用同样生效，之后可立即 `show` |

### ToastItem / ToastAction / ToastDuration

```swift
public nonisolated struct ToastItem: Identifiable, Sendable {
    public init(id: UUID = UUID(), title: String, description: String? = nil,
                level: StatusLevel = .info, duration: ToastDuration = ToastDefaults.duration,
                action: ToastAction? = nil)
}

public nonisolated struct ToastAction: Sendable {
    public init(_ label: String, action: @escaping @MainActor @Sendable () -> Void)
    @MainActor public func perform()
}

public nonisolated enum ToastDuration: Sendable, Equatable {
    case seconds(TimeInterval)
    case persistent
}
```

- 常规字号下 `title` 单行、`description` 最多两行；辅助功能字号（AX1+）下两者都不限行数。
  文案均为调用方传入的 B 类 `String`。
- `ToastItem` / `ToastAction` 是 `nonisolated` + `Sendable`：可在后台构造，
  再 `await MainActor.run { host.show(item) }`；动作闭包始终在主 actor 上执行。
- `.seconds` 的非正值（含 NaN）按缺省 3 秒处理；`.seconds(.infinity)` 等同 `.persistent`。
- ⚠️ **`.persistent` 在被关闭前阻塞队列**：其后 `show` 的 toast 只排队、不显示，
  直到它被点按 / 滑动 / `dismiss(_:)` / `dismissAll()` 关闭。

StatusLevel: info / success / warning / danger / neutral。

## 预览 / Preview

此组件依赖 Scene 级 context，需运行 App 后在界面中触发。运行 `scripts/run-preview.sh` 启动预览 App 体验效果。

### View Modifier

| 方法 | 说明 |
|---|---|
| `.toastHost(edge: VerticalEdge, presentation: ToastPresentation)` | 在 view 子树挂载 ToastHost |

默认 edge: `.top`，默认 presentation: `.floatingCapsule`，默认时长: `.seconds(3)`。

### ToastPresentation（呈现形态，`#65`）

公约 §2 形态 D2「配置枚举」。三个 case 对应三种**业界真实存在的布局骨架**，
不是同一骨架换画法：

| case | 形态 | 具名来源 | 挂载方式 | 占宽 |
|---|---|---|---|---|
| `.floatingCapsule`（默认） | 边缘悬浮胶囊 | 现状形态 | `safeAreaInset(edge:)` | 撑满减两侧 16pt |
| `.fullWidthBanner` | 全宽横幅条 | Android Snackbar / in-app banner | `safeAreaInset(edge:)` | **撑满、触边** |
| `.centeredHUD` | 居中 HUD | 经典 UIKit toast / HUD | **`.overlay(alignment: .center)`** | **收缩为内容宽** |

⚠️ **`edge` 在 `.centeredHUD` 下不生效** —— 居中浮层没有「贴哪边」可言。受影响的有
贴边内边距、方向性入/出场、朝 `edge` 滑出的 dismiss 位移、滑动手势方向，四条都不适用。
这是**有意的静默**：传了不生效不是错误、只是无效，因此**不加运行期断言**，本文档即约定
（与 `StepsPresentation` 对 `indicatorStyle` 的处置同源）。

⚠️ `.centeredHUD` 下**滑动 dismiss 关闭、只保留点击 dismiss**。⚠️ 这只关**滑动位移** ——
自动 dismiss 计时与「按住暂停」不受影响，三个形态都照常。

### 交互与计时 / Interaction & timing

- 点整条 toast 关闭；点动作按钮 = 先在主 actor 上执行动作，再关闭（不会同时触发整条点击）。
  若动作内部已 `dismissAll()` 并重新 `show`（即使复用同一个 `id`），新展示的 toast 不会被这次收尾关闭。
- 按住或拖拽 toast 时暂停计时，松手（含手势被系统取消）后按**剩余**时长恢复；
  计时从该条开始显示时起算，排队期间不计时。
- 显示计时与退场动画等待是两个独立的计时器，`dismissAll()` 同时取消两者；截止时刻在排程时确定，
  主线程繁忙导致计时任务晚启动不会拉长显示时长。

### 无障碍 / Accessibility

- 无动作：整条是一个按钮元素（标题 + 说明合并朗读，提示「Tap to dismiss」，激活即关闭）。
- 有动作：整条不再是单一按钮——「标题 + 说明」是一个可激活关闭的按钮元素，动作是另一个独立按钮，
  二者可分别聚焦（AXe 实测为两个 `Button` 节点）。
- AX 字号下图标不再单独占一列，改为标题文字里的内联图标（朗读标签仍只是标题），文字列拿到整条宽度，
  长单词不会从中间折断；动作按钮换到消息下方一行、允许折行，标题与说明完整显示；常规字号下动作按钮保持完整单行，
  由标题让出宽度（标题单行截断）。
- 动作按钮外观是紧凑的 small 胶囊，但命中区向四周各扩 `CoreSpacing.md`（≥ 44×44pt），
  再以等量负内边距抵消，不撑高 toast。

## 使用示例 / Usage

```swift
// App 入口挂 host
@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .toastHost(edge: .top)
        }
    }
}

// 子 view 触发
struct DetailView: View {
    @Environment(\.toastHost) private var toast
    var body: some View {
        Button("Save") {
            toast?.show("Saved.", level: .success)
        }
        Button("Archive") {
            toast?.show(ToastItem(
                title: "Conversation archived",
                description: "Undo within a few seconds to restore it.",
                level: .neutral,
                action: ToastAction("Undo") { /* restore */ }
            ))
        }
    }
}
```

## 视觉 Token

- 容器：`floatingGlass` 液态玻璃外壳，不消费 `.surface(.card)`（Phase 3A 迁移，见 `ToastView`）。三形态外壳不同：
  - `.floatingCapsule`：公开入口 `.floatingGlass(in:isInteractive:)` 的默认外壳（64% 背景色 + 玻璃 + 四周 hairline）；
  - `.fullWidthBanner`：不画 hairline，底色与玻璃延伸进所贴那条边的安全区（顶部即状态栏）；
  - `.centeredHUD`：底色改为不透明 `surfaceRaised`（保留玻璃边缘与 hairline），叠在文字上不透字。
- 字号：标题 `callout`（有说明时 semibold），说明 `footnote` + `contentSecondary`；动作按钮外观同 `.light(role: .primary)` + `.controlSize(.small)`、semibold（内部样式另加命中区外扩）；常规字号下图标与标题首行基线对齐，字号上限 `xxxLarge`；AX 字号下图标内联在标题文字开头、随标题字号缩放
- 内边距：`CoreSpacing.md`
- Icon / 前景色：按 `StatusLevel` 走 status color token（`statusAccentForeground` / `statusSuccessForeground` / `statusAttentionForeground` / `statusDangerForeground`）；
  图标 `info.circle` / `checkmark.circle` / `exclamationmark.triangle` / `exclamationmark.circle`（danger，与 `Banner` 的 `exclamationmark.circle.fill` 同属 circle 族，Toast 保持描线）；
  `neutral` 图标 `bell`、图标色 `contentSecondary`（正文各档统一为 `contentPrimary`）
- 入场/出场动画：从 `edge` 方向滑入 + 淡入（⚠️ `.centeredHUD` 例外：改用不依赖方向的
  缩放 + 淡入淡出）
- 滑动手势：向 edge 方向滑动超过 `CoreSpacing.xxl`（32pt）触发 dismiss
  （⚠️ `.centeredHUD` 例外：关闭滑动，只保留点击）
- 容器形状：`.floatingCapsule` 单行时用 `Capsule`，有说明或处于 AX 字号时改用
  `RoundedRectangle(cornerRadius: CoreRadius.xLarge)`（高内容套胶囊会被大圆角切到）；`.fullWidthBanner` 用 `Rectangle`、
  `.centeredHUD` 用 `RoundedRectangle(cornerRadius: CoreRadius.large)`；三者共用
  `CoreSpacing.md` 的内容内边距（内容留白不是三形态的差异所在）
- z-order：toast 只在**挂 `.toastHost(...)` 那层 view 树**内绘制，不覆盖 sheet /
  fullScreenCover，每个 scene 需独立挂载 host。
  ⚠️ **三个 presentation 一律如此** —— `.floatingCapsule` / `.fullWidthBanner` 走
  `safeAreaInset`，`.centeredHUD` 走 `.overlay`，但根因是「在哪层 view 树绘制」、
  不是用哪个 modifier 挂（上一版把原因写成「通过 `safeAreaInset` 实现」，对 HUD 不准确）。
