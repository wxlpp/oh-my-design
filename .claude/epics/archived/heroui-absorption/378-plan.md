# Issue #378 计划：Badge / Tag / Avatar 尺寸体系 + AvatarSize（PRD FR-7）

## 文件清单

| 文件 | 改动 |
|---|---|
| `Sources/OhMyDesign/Tokens/CoreControlMetrics.swift` | 新增查询函数：`compactFontToken(for:)`、`compactHorizontalPadding(for:)`、`compactVerticalPadding(for:)`、`compactIconSize(for:)`（Badge / Tag 这类紧凑 chip 用）；`avatarDiameter(for:)`（五档头像直径表）；`avatarInitialFontSize(forDiameter:)`；internal `avatarGroupOverlap(for:)`（AvatarGroup 交叠量，从组件内搬出，无外部消费者故不公开） |
| `Sources/OhMyDesign/Components/Avatar/Avatar.swift` | 新增 `AvatarSize`；`Avatar(name:size:)`；按直径绘制并 `.frame` 固定 |
| `Sources/OhMyDesign/Components/AvatarGroup/AvatarGroup.swift` | 私有 `avatarSize` 表 / `overlapOffset` 表改读 `CoreControlMetrics`；子视图不改写 |
| `Sources/OhMyDesign/Components/Badge/Badge.swift` | 读 `\.controlSize`，字号 / 内边距取 compact 查询 |
| `Sources/OhMyDesign/Components/Tag/Tag.swift` | 读 `\.controlSize`，字号 / 内边距 / 关闭钮图标取 compact 查询 |
| `Tests/OhMyDesignTests/SizeSystemTests.swift` | 新测试 |
| `docs/components/{avatar,avatar-group,badge,tag}.md` | 尺寸体系说明 |
| `docs/BREAKING-CHANGES.md` | Avatar 默认固定直径（布局破坏）+ `Avatar.init(name:)` 函数引用破坏 |
| `App/Sources/ComponentData.swift` / `Previews.swift` | 多档尺寸预览 |
| `scripts/design-digest.py` / `docs/design-digest.md` | 控件尺寸表纳入新查询；FLOORS 按真实值 |

## 公开 API

```swift
public nonisolated enum AvatarSize: Sendable, Equatable {
    case automatic
    case fixed(CGFloat)
}
public struct Avatar: View { public init(name: String, size: AvatarSize = .automatic) }

extension CoreControlMetrics {
    public static func compactFontToken(for: ControlSize) -> CoreTypography.Token
    public static func compactHorizontalPadding(for: ControlSize) -> CGFloat
    public static func compactVerticalPadding(for: ControlSize) -> CGFloat
    public static func compactIconSize(for: ControlSize) -> CGFloat
    public static func compactMinHeight(for: ControlSize) -> CGFloat?   // regular 为 nil；iOS / macOS 各一张表
    public static func compactCornerRadius(for: ControlSize) -> CGFloat
    public static func avatarDiameter(for: ControlSize) -> CGFloat
    public static func avatarInitialFontSize(forDiameter: CGFloat) -> CGFloat
    static func avatarGroupOverlap(forDiameter: CGFloat) -> CGFloat   // internal，直径的 1/4
    static func avatarCountFontToken(for: ControlSize) -> CoreTypography.Token   // internal
}
```

`.regular` 档的 compact 取值与现状一致（footnote / sm / xs / 14pt），默认调用方视觉零变化。
`avatarDiameter` 取 `AvatarGroup` 现有私有表（20 / 24 / 32 / 40 / 48），两者共享。
`.fixed` 负值按 0 处理。

## 测试清单（Swift Testing，ImageRenderer 取像素尺寸 / scale）

1. Badge 五档渲染宽高严格单调递增。
2. Tag 五档渲染宽高严格单调递增；removable Tag 同样单调（关闭钮随档）。
3. Avatar `.automatic` 五档渲染边长 == `avatarDiameter(for:)` 且严格递增。
4. `Avatar(name:size: .fixed(100))` 渲染 100×100，外部 `.frame(200)` 不拉伸。
5. AvatarGroup(max: 1) { Avatar } 五档渲染宽 == 同档独立 Avatar 宽 == `avatarDiameter`。
6. CoreControlMetrics 新查询五档单调、`.regular` 与现状取值一致。
7. `AvatarSize` 缺省 `.automatic`、`.fixed` 负值夹为 0。

## 登记 / 文档落点

- `AvatarSize` 是 Avatar 的尺寸参数类型，非外观形态枚举、非组件 ⇒ 不进 `component-registry.json`（不造幽灵条目）；Avatar 条目 notes 不涉及尺寸，不改。
- 守卫数字按实测更新并在报告列出。
