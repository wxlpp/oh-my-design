# Surface 有效层级与 sheet 预设

`.surface(_:)` 的层级规则与 `View.coreSheetPresentation()` / Surface levels and the sheet preset.

## `.surface(_:)` 的有效层级

`.surface(_:)` 除了施加背景 + 描边 + 圆角，还把**有效层级**（`base` / `raised` / `elevated`，internal）
写进环境，交给子树里的下一个 `.surface(_:)`。默认层级是 `base`。

| 角色 | 本层有效层级 | 背景 |
|---|---|---|
| `canvas` / `canvasSubtle` | 重置为 `base` | 各自现值（`surfaceCanvas` / `surfaceCanvasSubtle`），不随层级变 |
| `content` / `grouped` / `card` | 父层级 + 1，封顶 `elevated` | `raised` → `surfaceCard`，`elevated` → `surfaceElevated` |
| `panel` / `sidebar` / `control` / `floating` | 沿用父层级 | 各自现值（`surfacePanel` / `surfaceSidebar` / `surfaceInteractive` / `surfaceOverlay`），不随层级变 |

- 只有 `content` / `grouped` / `card` 三个角色的背景随层级变；圆角只由角色决定。
- 描边由角色决定，唯一例外是 `content`：`elevated` 层不描边（`.clear`），与 `grouped` 同观感；
  `raised` / `base` 层仍是 `borderMuted`。`card`（兼容别名）在任何层级都保留 `borderMuted`。
- ⇒ `.surface(.content)` 里的 `Card` 取 `surfaceElevated`；再往里嵌套仍是 `surfaceElevated`（封顶）。
- 需要在卡片里重新从画布起算时，用 `.surface(.canvas)` 重置（`ListRow` 就是这样贴画布的）。

```swift
Card {
    Text("外层：raised → surfaceCard")
    Card { Text("内层：elevated → surfaceElevated") }
}
```

### 已知限制：macOS 上 raised / elevated 同色

macOS 没有分层背景 API：`surfaceCard`（`secondarySystemGroupedBackground`）与 `surfaceElevated`
（`tertiarySystemGroupedBackground`）在 AppKit 下都桥到 `controlBackgroundColor`，取值相同
（见 `docs/DESIGN-FOUNDATION.md` 的 macOS 取值表）。

- `card` 嵌套时靠描边区分；
- **`content` / `grouped` 嵌进 `content` / `grouped` / `card` 时，在 macOS 上没有任何视觉区分**
  （elevated 层无描边、背景同色）——已知限制，不做平台分支补救。

### 已知限制：普通 `.sheet` / `.popover` 继承宿主层级

SwiftUI 的环境值会传进弹层内容，本库也无法拦截任意 `.sheet` / `.popover`。实测（iOS 26.4）：挂在
`.surface(.content)` 内部的普通 `.sheet` / `.popover`，内容读到的是宿主层级——嵌在两层 content 里时读到
`elevated`，于是 sheet 里的顶层 `Card` 直接取 `surfaceElevated`、不出投影（判据
`PresentedSheetLevelTests`；预览宿主 Card 页「系统 sheet」按钮可目视复现）。

- **推荐边界**：在 sheet 内容上施加 `coreSheetPresentation(background:)`，它显式把内容层级设为 `raised`。
- 不想用预设时，在 sheet 内容最外层加 `.surface(.canvas)` 也能把层级重置为 `base`（代价：多铺一层
  `surfaceCanvas` 背景）。
- 挂在 surface **外侧**的 `.overlay` / `.background` 读的是父层级，挂在内侧的读本层；兄弟视图互不影响。

## `View.coreSheetPresentation(background:)`

施加在 sheet 的**内容**上，与 iOS 26 系统 sheet 对齐：

| 设置 | 取值 |
|---|---|
| 圆角 | **不设**——交给系统，保持浮动 sheet 与屏幕圆角同心 |
| `presentationDragIndicator` | `.visible` |
| `background: CoreSheetBackground` | `.system`（缺省）：保留系统 Liquid Glass 背景；`.raised`：不透明 `Color.surfaceRaised` |
| 内容有效层级 | 两种背景下都是 `raised`（里面的 `Card` 因而取 `surfaceElevated`、不出投影） |

```swift
.sheet(isPresented: self.$isPresented) {
    SheetContent()
        .coreSheetPresentation()                    // 系统 Liquid Glass
        // .coreSheetPresentation(background: .raised) // 不透明 surfaceRaised
}
```

sheet 本体仍是系统原生 sheet；本 modifier 只设置指示条、背景与层级，不改 detent / 交互。

## 登记

`.surface(_:)` 与 `coreSheetPresentation(background:)` 都只经 `public extension View` 暴露、没有 public
View / ViewModifier 类型，按公约 AD-2 不进 `docs/component-registry.json`；`CoreSheetBackground` 是入参辅助枚举。
