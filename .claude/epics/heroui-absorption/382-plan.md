# Issue #382 plan: surface 有效层级 + coreSheetPresentation（FR-12 / FR-13）

## 文件

- `Sources/OhMyDesign/Modifier/SurfaceModifier.swift`
  - 新增 internal `enum SurfaceLevel: Sendable, Comparable { case base, raised, elevated }`（`nonisolated`）。
  - `EnvironmentValues` 上 internal `@Entry var surfaceLevel: SurfaceLevel = .base`。
  - `SurfaceKind.level(inheriting:) -> SurfaceLevel`：canvas / canvasSubtle → `.base`；
    content / grouped / card → 父 + 1（封顶 `.elevated`）；panel / sidebar / control / floating → 父层级。
  - `SurfaceKind.background(at:) -> Color` 取代原 `background` 属性：只有 content / grouped / card
    随层级变（`.elevated` → `surfaceElevated`，其余 → `surfaceCard`）；其余角色取各自现值。
  - `SurfaceModifier` 读父层级、按自身有效层级取背景，并把有效层级写给子树。描边 / 圆角不变。
- `Sources/OhMyDesign/Modifier/CoreSheetPresentation.swift`（新）
  - `public extension View { func coreSheetPresentation() -> some View }`：
    `presentationCornerRadius(CoreRadius.xLarge)` + `presentationDragIndicator(.visible)` +
    `presentationBackground(Color.surfaceRaised)` + `environment(\.surfaceLevel, .raised)`。
- `Card` 不改逻辑（仍是 `.surface` 薄封装）；预览加嵌套样例。

## 公开 API

- 新增：`View.coreSheetPresentation() -> some View`。
- `SurfaceLevel` / `surfaceLevel` 保持 internal（消费方需要层级时经 `.surface(_:)` 参与，不新开读写入口）。
- 行为变化（非签名破坏）：嵌套在 content / grouped / card 内的 content / grouped / card 取 `surfaceElevated`
  ⇒ 登记进 `docs/BREAKING-CHANGES.md`。

## 测试（Swift Testing）

- `SurfaceLevelTests`（双腿）：9 角色 × 3 父层级的 `level(inheriting:)` 全表；
  `background(at:)` 的 Color 身份表；探针视图经 `ImageRenderer` 读环境层级：
  默认 base、单层 raised、双层 elevated、三层封顶、canvas 重置、panel / floating 透传、
  `.surface(.content)` 内 `Card` = elevated、`coreSheetPresentation()` 内容 = raised、sheet 内 Card = elevated。
- iOS 腿：嵌套 Card 中心像素 = `surfaceElevated` 像素且 ≠ 外层；`surfaceElevated` 与 `surfaceCard` 两外观解析互异。
- `SurfaceKindAlphaContractGuard` 改为「角色 × 父层级」遍历（经 `level(inheriting:)` + `background(at:)`），α 契约不放宽。

## 文档 / 登记

- `docs/components/card.md`：层级规则、嵌套取色、macOS 已知限制（raised/elevated 塌缩；grouped 嵌套 grouped 无区分）。
- `docs/components/surface-levels.md`（新）：`.surface` 层级表 + `coreSheetPresentation()`；`docs/README.md` 若有 modifier 索引则补。
- `docs/DESIGN-FOUNDATION.md`：已知限制一段。
- 登记表：`.surface` / `coreSheetPresentation` 均无 public 类型（AD-2 ⇒ 不登记）。
- digest：`viewext` +1。
- 预览宿主：Card 组件页加嵌套样例 + sheet 演示。

## Review round 1 修订

- `coreSheetPresentation(background: CoreSheetBackground = .system)`：不设圆角（交给系统、与屏幕同心），
  `.system` 保留 Liquid Glass、`.raised` 不透明 `surfaceRaised`；新增 `public enum CoreSheetBackground`。
  `CoreRadius.xLarge` 因此仍零消费（PRD 已修订）。
- `Card` 自身有效层级为 elevated 时不出投影。
- 普通 `.sheet` / `.popover` 继承宿主层级：实测成立，登记为已知限制，`coreSheetPresentation` 为推荐边界。
