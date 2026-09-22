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

- 只有 `content` / `grouped` / `card` 三个角色的背景随层级变；描边与圆角仍只由角色决定（`grouped` 仍无描边）。
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

- 有描边的角色（`content` / `card`）嵌套时靠描边区分；
- **`grouped` 嵌套 `grouped` 在 macOS 上没有任何视觉区分**（无描边、背景同色）——已知限制，不做平台分支补救。

## `View.coreSheetPresentation()`

施加在 sheet 的**内容**上，一次打包本库的 sheet 观感：

| 设置 | 取值 |
|---|---|
| `presentationCornerRadius` | `CoreRadius.xLarge`（22pt） |
| `presentationDragIndicator` | `.visible` |
| `presentationBackground` | `Color.surfaceRaised` |
| 内容有效层级 | `raised`（sheet 背景已是 raised，里面的 `Card` 因而取 `surfaceElevated`） |

```swift
.sheet(isPresented: self.$isPresented) {
    SheetContent()
        .coreSheetPresentation()
}
```

sheet 本体仍是系统原生 sheet；本 modifier 只设置外观与层级，不改 detent / 交互。

## 登记

`.surface(_:)` 与 `coreSheetPresentation()` 都只经 `public extension View` 暴露、没有 public 类型，
按公约 AD-2 不进 `docs/component-registry.json`。
