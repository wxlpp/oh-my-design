# anchoredBadge

贴在宿主角上的红点 / 计数 / 短文本徽标 / Dot, count or short text anchored to a corner of any view.

`View.anchoredBadge(_:placement:)`（`Modifier/AnchoredBadgeModifier.swift`）对应 HeroUI React `Badge` + `Badge.Anchor` 的「锚定」形态（PRD `heroui-absorption` FR-8，Issue #379）。本仓的 [`Badge`](badge.md) 是独立胶囊标签（HeroUI 的 `Chip`），不是这个。

⚠️ **名字刻意避开 SwiftUI 的 `.badge(_:)`**：系统 `.badge` 只作用于 `List` 行与 `TabView` 项，内容区头像 / 图标角标没有原生写法。

## API

| 参数 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| content | `AnchoredBadgeContent` | - | 徽标内容，见下表 |
| placement | `AnchoredBadgePlacement` | `.topTrailing` | 贴靠的角：`.topTrailing` / `.topLeading` / `.bottomTrailing` / `.bottomLeading`（跟随布局方向，RTL 下左右互换）。徽标**中心**落在宿主边界框的该角上 |

### `AnchoredBadgeContent`

| case | 显示 | 不显示的条件 |
|---|---|---|
| `.dot` | 10pt 红点（随 Dynamic Type 缩放） | —— |
| `.count(Int, max: Int = 99)` | 数字；超过 `max` 显示 `"\(max)+"`（`.count(120, max: 99)` → `99+`）。`max < 1` 按 1 处理 | 计数 `≤ 0` |
| `.text(String)` | 原样显示的短文本 | 空串 |

不显示时 overlay 里不渲染任何视图，宿主布局与可访问值都不受影响。

### 文本分类

`.text(String)` 是**调用方文案（B 类）**，按 `Text(verbatim:)` 原样渲染，与 `Badge(_ text: String)` 同款。
⚠️ 公约第 4 节建议新增 B 类参数用 `LocalizedStringKey`；本 case 按 PRD FR-8 字面签名取 `String`，
需要本地化的调用方自行传入已本地化的串（`String(localized:)`）。
红点的可访问值 `"New"` 是组件内部 chrome（A 类），走 `en.lproj/Localizable.strings`。

## 取色

- 底色 `Color.statusDangerEmphasis`，前景 `Color.contentOnEmphasis`——与系统角标一致的固定饱和红 + 白字。
- **不跟随 accent / `coreAccent`**：墨色 accent 上的角标会读成禁用态。

## 无障碍

- 徽标视图本身 `accessibilityHidden`，信息**并入宿主的 `accessibilityValue`**：计数 → 显示串（`"99+"`），文本 → 原文，红点 → 本地化的 `"New"`。
- 不显示时不追加可访问值（`accessibilityValue(_:isEnabled:)` 关掉）。
- ⚠️ 本 modifier 不读取、也不拼接宿主已有的 `accessibilityValue`；宿主自带可访问值时，请把计数拼进宿主自己的值里，不要两处各设一个。

## 登记

modifier 结构体是 internal（`SurfaceModifier` 范式），公开表面只有 `View` 扩展方法与两个配置枚举 ⇒
按 `component-contract.md` AD-2 没有可登记的 public `View`/`ViewModifier` 类型，**不进** `component-registry.json`
的 `components[]`，也不进 README 组件表（表内每行须对账到登记表条目）。

## 使用示例 / Usage

```swift
Avatar(name: "Evan")
    .anchoredBadge(.dot)

Image(systemName: "envelope.fill")
    .anchoredBadge(.count(unread))          // unread == 0 时不显示

Image(systemName: "gift.fill")
    .anchoredBadge(.text("NEW"), placement: .topLeading)
```

## 视觉 Token

- 红点：`@ScaledMetric(relativeTo: .caption2)` 10pt 圆
- 计数 / 文本：`.coreFont(.caption2)` + `.semibold` + `monospacedDigit`，最小高度与最小宽度 18pt（随 Dynamic Type 缩放），横向内边距 `CoreSpacing.xs + CoreSpacing.xxs / 2`，`Capsule(style: .continuous)`
