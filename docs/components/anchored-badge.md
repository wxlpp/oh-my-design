# anchoredBadge

贴在宿主角上的红点 / 计数 / 短文案徽标 / Dot, count or short label anchored to a corner of any view.

`View.anchoredBadge(_:placement:hostShape:)`（`Modifier/AnchoredBadgeModifier.swift`）对应 HeroUI React `Badge` + `Badge.Anchor` 的「锚定」形态（PRD `heroui-absorption` FR-8，Issue #379）。本仓的 [`Badge`](badge.md) 是独立胶囊标签（HeroUI 的 `Chip`），不是这个。

⚠️ **名字刻意避开 SwiftUI 的 `.badge(_:)`**：系统 `.badge` 只作用于 `List` 行与 `TabView` 项，内容区头像 / 图标角标没有原生写法。

## API

| 参数 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| content | `AnchoredBadgeContent` | - | 徽标内容，见下表 |
| placement | `AnchoredBadgePlacement` | `.topTrailing` | 贴靠的角：`.topTrailing` / `.topLeading` / `.bottomTrailing` / `.bottomLeading`（跟随布局方向） |
| hostShape | `AnchoredBadgeHostShape` | `.rectangle` | 宿主外形：`.rectangle`（图标、卡片）/ `.circle`（圆形头像），见《几何》 |

### `AnchoredBadgeContent`

| case | 显示 | 不显示的条件 |
|---|---|---|
| `.dot` | 10pt 红点（随 Dynamic Type 缩放） | —— |
| `.count(Int, max: Int = 99)` | 数字；超过 `max` 显示 `"\(max)+"`（`.count(120, max: 99)` → `99+`）。`max < 1` 按 1 处理 | 计数 `≤ 0` |
| `.text(LocalizedStringKey)` | 短文案 | 空键 `""` |

不显示时 overlay 里只剩一层 `Color.clear`（`#408` 起外层 `GeometryReader` 常驻，理由见《动效》），不画任何像素；宿主的可访问值也不被改动。

### 文本分类

- `.text` 是**调用方文案（B 类）**，按公约第 4 节取 `LocalizedStringKey`，由 `Text` 按 `Bundle.main` 解析。
- 红点的朗读文本 `"New"` 是组件内部 chrome（A 类），用 `LocalizedStringResource` 从模块 bundle 解析（`en.lproj/Localizable.strings`）。
- 代价：`LocalizedStringKey` 不是 `Sendable`，因此 `AnchoredBadgeContent` 只遵循 `Equatable`、**不遵循 `Sendable`**。

## 取色

- 底色 `Color.badgeFill`（第 3 层 token）→ 第 2 层桥接 `Color.systemRed`（`UIColor.systemRed` / `NSColor.systemRed`）；前景 `Color.contentOnEmphasis`。与 iOS 系统角标一致，随外观 / 增强对比度自动适配。
- **不跟随 accent / `coreAccent`**，也不用 Primer 色阶。
- 系统色在 macOS `swift test` 腿上也能正常解析（不在「资源色解析为透明」那一批里），所以测试直接断言了解析值。

## 几何

- **纵向**：徽标中心落在锚点上（上边或下边）。
- **横向**：徽标只伸进宿主半个徽标高度，**宽度增长全部朝外**（UITabBar 角标的做法）。`99+` / `NEW` 这类宽徽标因此不会压住宿主内容。`.dot` 宽等于高，所以中心正好落在锚点上。
- `.rectangle`：锚点是宿主边界框的角。
- `.circle`：锚点是内切圆周上的 45° 点，距边框角约 `0.146·d`（`d` 为短边）。另外会画一圈约 2pt 的 `Color.surfaceCanvas` 分隔环，让徽标在花哨的头像上也能分辨出来。
- 徽标**不改变宿主的布局尺寸**，它越出宿主边界的部分可能被裁掉，见下节。

### 在 `ScrollView` / `List` 里：给越界部分留空间

徽标以 overlay 形式越出宿主边界：`.topTrailing` 时向上越出半个徽标高度，向右越出「徽标宽度减半个高度」。宿主若紧贴滚动容器或列表行的内容边缘，这部分会被容器裁掉。**调用方必须自己留出越界空间**，例如给宿主加 padding：

```swift
ScrollView(.horizontal) {
    HStack(spacing: CoreSpacing.lg) {
        ForEach(friends) { friend in
            Avatar(name: friend.name, size: .fixed(48))
                .clipShape(Circle())
                .anchoredBadge(.count(friend.unread), hostShape: .circle)
        }
    }
    .padding(.vertical, CoreSpacing.sm)
    .padding(.horizontal, CoreSpacing.lg)
}
```

## 动效（#408）

- **计数变化**：`.contentTransition(.numericText(countsDown:))`，方向按**新旧值**定——增加向上滚、减少向下滚。
  方向不能靠 `onChange` 现算：`onChange` 比 body 晚一拍，数字变化那一次事务里拿到的还是旧方向。
  因此 modifier 内部镜像一层「上一次显示的值 + 当前显示值」，由 `onChange` 推进；显示的数字来自这份镜像，
  所以计数变化会比真实值晚一帧（约 16 ms）落地，朗读文本（`accessibilityValue`）不受影响、立即跟上真实值。
  徽标不显示时镜像被清空，因此「计数掉到 0 再涨回来」不会闪一帧旧数字。
- **出现 / 消失**：缩放（`0.6 → 1`）+ 淡变，走 `CoreMotionToken.reveal`。
  ⚠️ 转场挂在**徽标本身**、而不是挂在填满宿主的那层 `GeometryReader` 上：挂在外层时缩放锚点落在宿主中心
  （徽标会从宿主中间飞出来），而且圆形宿主上实测让徽标的亚像素光栅位置偏 0.5pt（逐通道差到 196、369 字节），
  与改动前的实现对不上。为此显示 / 不显示的条件判断下移到 `ZStack` 内部，外层 `GeometryReader` 常驻。
- `.dot` 与 `.text` 不加内容过渡：红点没有数字；`.text` 是调用方的 `LocalizedStringKey`，滚动读不出方向。
- **Reduce Motion**：计数改为 `ContentTransition.identity`（直接替换，不滚动不模糊），出现 / 消失改纯淡变。
  框架不替调用方降级这两条（`#407` FR-1 逐帧实测），全部由本 modifier 显式分支。

## 无障碍

- 徽标视图本身 `accessibilityHidden`，本意是不产生额外的焦点元素。
- 徽标显示时，modifier 把 `content.accessibilityText` 设为宿主的 `accessibilityValue`：计数 → `"99+"`，文案 → 该键，红点 → 本地化的 `"New"`。不显示时用 `accessibilityValue(_:isEnabled:)` 关闭，不设任何值。
- ⚠️ **不会自动合并**：SwiftUI 读不到宿主已有的 `accessibilityValue`。宿主自己有 value 时，调用方用公开的 `AnchoredBadgeContent.accessibilityText` 自行拼接到宿主的 value 里，不要依赖两处各设一个的结果：

```swift
let badge = AnchoredBadgeContent.count(unread)
Label("Inbox", systemImage: "tray")
    .accessibilityValue(badge.accessibilityText.map { Text("Synced, \($0)") } ?? Text("Synced"))
```

## 登记

modifier 结构体是 internal（`SurfaceModifier` 范式），公开表面只有 `View` 扩展方法与三个配置枚举 ⇒
按 `component-contract.md` AD-2，没有可登记的 public `View`/`ViewModifier` 类型，**不进** `component-registry.json`
的 `components[]`，也不进 README 组件表（表内每行须对账到登记表条目）。

## 使用示例 / Usage

```swift
Avatar(name: "Evan", size: .fixed(48))
    .clipShape(Circle())
    .anchoredBadge(.dot, hostShape: .circle)

Image(systemName: "envelope.fill")
    .anchoredBadge(.count(unread))          // unread == 0 时不显示

Image(systemName: "gift.fill")
    .anchoredBadge(.text("NEW"), placement: .topLeading)
```

## 视觉 Token

- 红点：`@ScaledMetric(relativeTo: .caption)` 10pt 圆
- 计数 / 文案：`.coreFont(.caption)` + `.semibold` + `monospacedDigit`；胶囊最小高度与最小宽度 20pt、横向内边距 6pt，三者都是 `@ScaledMetric(relativeTo: .caption)`，字号约占胶囊高度的 60%；形状为 `Capsule(style: .continuous)`
- 分隔环（仅 `.circle`）：`Color.surfaceCanvas`，`@ScaledMetric` 2pt
