# Tree 密度与样式配置（#429）设计 spec

- 日期：2026-09-23
- Issue：`wxlpp/oh-my-design#429`（依赖 `#422`，与 `#423` 同一批文件、不并行）
- 基线：`origin/epic/structure-components` = `805f40f`（`#422` Tree 本体已合入）
- 本文只是设计，**不含实现代码**。文中「实测」均指下方 §0 列出的探针（scratch，不进仓库），
  其余一律标「推断」或「源码读」。
- 实现拆成 4 个独立可合并的 PR，见 `docs/superpowers/plans/2026-09-23-tree-style-plan.md`。

## 0. 证据来源与标注口径

| 标签 | 含义 |
|---|---|
| **源码读** | 在 `805f40f` 上直接读到的源码 / 文档原文 |
| **实测** | 本次在 scratch 下写的 SwiftUI 探针，macOS 26 / Swift 6.3 / `swiftc` 直接编译运行；**只跑了 macOS**，iOS 腿未测 |
| **推断** | 未经实测的推理；进实现期前要么补探针，要么在判据里兜住 |

本次探针（`scratchpad/429/p1.swift` `p2.swift` `p2b.swift` `p3.swift`）的读数：

| # | 问题 | 读数 |
|---|---|---|
| P1 | `LazyVStack` **不在** `ScrollView` 里时是否惰性 | 100 行全部构建（`lazyBare=100`），渲染尺寸与 `VStack` 相同（200×2200） |
| P1 | `LazyVStack` 在 300pt 高的 `ScrollView` 里 | 100 行只构建 14 行 |
| P1 | 自定义 `@Entry` 环境值能否穿过「自定义 `DisclosureGroupStyle` + 嵌套 `DisclosureGroup` 的 content」 | 能：3 个读取点全部读到注入值（`env=custom` ×3） |
| P2 | 惰性能否穿过根级 `DisclosureGroup`（`LazyVStack { DisclosureGroup { ForEach 200 } }`，300pt 视口） | **不能**：201 行全部构建；展平成单层 `ForEach` 后只构建 7 行 |
| P2 | 「嵌套 `DisclosureGroup` + 逐行 leading padding」与「展平成单层 `ForEach`」在 `VStack(spacing: 2)` 下的位图 | **逐字节相同**（400×732，差异字节 0）——用的是仿照 `TreeRowView` 结构的代理视图，**不是真组件** |
| P2b | 同一份展平内容 `VStack` vs `LazyVStack` | 尺寸相同；60 个字节不同，**最大逐通道偏差 1 LSB**，两次运行读数相同（文字抗锯齿层面） |
| P3 | `.contextMenu { … }` 的 builder 闭包何时求值 | **随 body 立即求值**：5 行在 `ImageRenderer` 与 `NSHostingView` 下各调用 10 次（每行 2 次）；菜单项自身的 `body` 调用 0 次 |
| C | 调用方写法在「今天的 struct」与「将来升协议」两种库版本下是否编译（见 §2.1 兼容表） | 见 §2.1；库与调用方都是独立模块（`swiftc -swift-version 6`，**未开** `defaultIsolation(MainActor)`） |

C 组探针：库三版——v1 `public struct TreeStyle`（`nonisolated static var`、`treeStyle(_: TreeStyle)`）；
v3 `public protocol TreeStyle { associatedtype Body: View; func makeBody(configuration:) -> Body }` +
`where Self ==` 静态成员 + 泛型 `treeStyle<S: TreeStyle>(_: S)`；v4 同 v3 但 modifier 为非泛型
`treeStyle(_: any TreeStyle)`。调用方四份（c1 `.treeStyle(.navigator)`、c2 `let s: TreeStyle = .navigator`、
c3 `.treeStyle(TreeStyle.navigator)`、c4 `.treeStyle(flag ? .navigator : .automatic)`）分别对三版做 `-typecheck`。

## 1. 密度：读 `@Environment(\.controlSize)`

### 1.1 约定

与按钮样式同一惯例：`Tree` 在**组件内**读 `controlSize`，推导一份内部的 `TreeRowMetrics`，
两种外观（§2）共用同一份度量——外观可以不用某个量，但不能改组件据以做命中与布局的那几个量（§1.3）。

`.automatic` 也跟随 `controlSize`（定案 D4）：代价是宿主祖先设了 `.controlSize(.small)` 时
默认外观会变密；`Tree` 未发布，现在跟随不构成破坏。

### 1.2 推导表（全部来自既有 token，不另立常量）

| 量 | 推导 | mini | small | **regular** | large | extraLarge | `#422` 现值 |
|---|---|---|---|---|---|---|---|
| 视觉行高 `rowHeight` | `size < .regular` ⇒ `iconSize(for:) + 2 × verticalPadding(for:)`；否则 `height(for:)` | 20 | **22** | **44** | 50 | 56 | 44（写死 `.regular`） |
| 展开槽宽 `disclosureWidth` | `iconSize(for:) + CoreSpacing.sm` | 20 | 22 | **24** | 28 | 32 | 24 |
| 缩进步长 `indentation` | `disclosureWidth / 2` | 10 | 11 | **12** | 14 | 16 | 12（`CoreSpacing.md`） |
| chevron 字号 | `compactIconSize(for:)` | 10 | 12 | **14** | 16 | 18 | 14（`iconSize(.small)`） |
| 行间距 `rowSpacing` | `size < .regular` ⇒ `CoreSpacing.none`；否则 `CoreSpacing.xxs` | 0 | 0 | **2** | 2 | 2 | 2 |
| 行内横向 padding / 行内 gap | 不随档位变：`CoreSpacing.xs` | 4 | 4 | 4 | 4 | 4 | 4 |
| 复选框字形 | `iconSize(for:)` | 12 | 14 | **16** | 20 | 24 | 16（`CheckBox` 写死 `.regular`） |

（数值为源码读 `CoreControlMetrics` / `CoreSpacing` 后的算术；`.regular` 一列逐项等于 `#422`
现值，这是 §6「`.automatic` 像素一致」的前提。）

推导理由（写进源码注释的只有第 1、2 条，各一句）：

1. **两个区间**：`mini` / `small` 是「桌面密集列表」区间，行高 = 图标 + 上下 padding（`small`
   正好落到 VS Code 的 22pt）；`regular` 起沿用控件高度 token。不用单一公式的原因：
   `iconSize + 2 × verticalPadding` 在 `.regular` 给 40，既破 44pt 又破现值。
2. **缩进 = 展开槽宽的一半**：子行的 chevron 落在父行 chevron 与行内容之间——VS Code 的
   twistie 16px / indent 8px 就是这个比例；`.regular` 恰好还原现值 12。
3. 行间距在密集区间取 0：VS Code 行与行无缝，缩进参考线要连成一条（§2.5）。

**已知取舍（定案 D4）**：macOS `.regular` 行距仍是 44，与本仓控件高度统一口径一致，不做平台分叉。
要 VS Code 式紧凑，调用方写 `.controlSize(.small)`。

### 1.3 iOS 触控目标：视觉行高与命中区的关系

**结论：连续堆叠的行，行距（pitch）就是命中区的上限，二者不能解耦。**
每行的独占命中高度 ≤ 相邻两行的中心距——把命中区扩到行框外（`contentShape` 负 inset）只会
和邻行重叠，重叠处归后绘制的那一行，等于把点击让给邻行（这正是 `#422` 修过的「一次点击勾上整棵
子树」那类事故的形状）。这是几何事实，不依赖 SwiftUI 行为（推断，但无需探针）。

因此（定案 D3）：

- 组件施加 `frame(minHeight: pitch)`，`pitch = max(rowHeight, platformFloor)`；
  `platformFloor` iOS 取 `CoreControlMetrics.height(for: .regular)`（44），macOS 取 0。
  交给外观的 `metrics.rowHeight` 就是**已经过下限**的 `pitch`，画出来的行与命中区一致。
- ⇒ **iOS 上所有档位行距 ≥ 44**，密度只体现在缩进、chevron、复选框字形与行间距。
- **行内**的子控件可以解耦：chevron 槽与复选框的命中高度 = 整个 `pitch`，字形按档位缩小。
  `#422` 的 `TreeDisclosureSlot` 写死 `height(for: .regular)` 与 `iconSize(for: .regular) + sm`，
  本次改为取 `metrics.rowHeight` / `metrics.disclosureWidth`。
- ⚠️ 横向：chevron 槽宽 20–32pt < 44pt，与 `#422` 现状同型（现判据只核高度）。本次不改，
  登记为已知项。

### 1.4 复选框密度（`CheckBox` 写死 `.regular`）

源码读：`CheckBox.swift` 的 `CheckBoxBody` 字形写死 `CoreControlMetrics.iconSize(for: .regular)`、
`.frame(minHeight: CoreControlMetrics.height(for: .regular))`。⇒ 只要传了 `checked`，macOS `.small`
的行距**必然**被撑到 44，密度只对不带复选框的树成立。

**定案：Tree 内的复选框单独适配，不改 `CheckBox` 的公开行为。** 做法：`CheckBoxBody` 读一个
**internal** 环境值（形如 `checkBoxLayout: CheckBoxLayout?`，含字形尺寸与最小高度），缺省 `nil`
⇒ 取值与今天逐字相同；`Tree` 在自己构造的复选框上注入 `(iconSize(for: size), pitch)`。

理由：

1. `CheckBox` 已随 `v0.11.0` 发布。让它整体读 `controlSize` 是它自己的设计决定：iOS 上
   `height(for: .small)` = 32 < 44，需要它自己的触控下限裁决，还要登记 BREAKING / 行为变化、
   复核 `CheckBoxMixedTests.swift` 的四个 suite（`CheckBoxIndicatorTests` / `CheckBoxMixedRenderTests` /
   `CheckBoxMixedWriteBackTests` / `CheckBoxLegacyAppearanceTests`）与 `FieldValidationControlsAppearanceTests` /
   `FieldControlFollowUpTests` 的 CheckBox 格——超出本 issue 射程。
2. internal 环境值可逆：将来 `CheckBox` 若自己读 `controlSize`，Tree 的注入直接删掉。
3. 三态（`#421` 的 mixed 态）不受影响：注入只改字形尺寸与最小高度，`CheckBoxIndicator.resolve`
   与 `Toggle(sources:isOn:)` 的派生路径不动；上面那四个 CheckBox suite 在 PR 1 里照跑作回归。
4. 注入点**只在 Tree 自己构造的那个 `Toggle` 上**（`.environment(\.checkBoxLayout, …)` 施在该 `Toggle`
   本身），不施在行、不施在 `Tree` 容器——否则调用方放进行内容里的 `CheckBox` 也会被改尺寸。

**另登记（不修）**：调用方行内容里若放了读 `controlSize` 的控件（例如按钮，`height(for: .small)` = 32），
行会被内容撑高到 32。行高是**下限**不是上限，这是正确行为；`tree.md` 写明「密集档位的行内容宜用
`Text` / `Label` / `Image`」。

## 2. `TreeStyle`：封闭的外观配置（不是协议）

### 2.1 定案（D2）

`TreeStyle` 是 **`public struct`**，内部持有一个 internal 的封闭外观枚举；公开面只有：

```swift
// MARK: - TreeStyle

/// `Tree` 的行外观预设。
public struct TreeStyle {
    /// 默认外观：圆角选中块、内容区起于缩进之后、焦点环。
    nonisolated public static var automatic: TreeStyle { get }
    /// 导航器外观：整行选中、悬停高亮、缩进参考线、中性色 chevron。
    nonisolated public static var navigator: TreeStyle { get }
}

public extension View {
    /// 为子树中的所有 `Tree` 设置行外观。
    ///
    /// - Parameter style: 行外观预设，`.automatic` 或 `.navigator`。
    func treeStyle(_ style: TreeStyle) -> some View
}

public extension Tree {
    /// 为整行挂右键菜单（§4）。
    func rowContextMenu<M: View>(@ViewBuilder _ menu: @escaping (Set<ID>) -> M) -> Tree
}
```

内部：`enum TreeAppearance { case automatic, navigator }`、`@Entry var treeStyle`（internal）、
`TreeRowMetrics` / `TreeRowConfiguration` 全部 internal。

**为什么不发协议、也不做「唯一外观」**：

- 公约「多给扩展点不可逆」：公开协议一旦发出，第三方样式就依赖 configuration 的每个字段，收不回来。
- 但「唯一外观」又回到 issue 动机里的问题——下游先拿到一个锁死的版本。
- 封闭配置是**可逆的那一侧**：将来改成
  `protocol TreeStyle { associatedtype Body: View; func makeBody(configuration:) -> Body }` +
  `extension TreeStyle where Self == NavigatorTreeStyle { static var navigator }` 时，常见调用点源码兼容
  ⇒ 以后开放协议是加法——**前提是 modifier 届时写成非泛型 `treeStyle(_ style: any TreeStyle)`**（下表）。

**升协议兼容表**（§0 C 组探针，实测；macOS、独立模块、未开 `defaultIsolation(MainActor)`）：

| 调用方写法 | 今天：struct（v1） | 升协议 + 泛型 `treeStyle<S: TreeStyle>(_: S)`（v3） | 升协议 + `treeStyle(_: any TreeStyle)`（v4） |
|---|---|---|---|
| `.treeStyle(.navigator)` | 通过 | 通过 | 通过 |
| `.treeStyle(flag ? .navigator : .automatic)` | 通过 | **报错**：`static property 'automatic' requires the types 'NavigatorTreeStyle' and 'AutomaticTreeStyle' be equivalent` | 通过 |
| `.treeStyle(TreeStyle.navigator)` | 通过 | **报错**：`static member 'navigator' cannot be used on protocol metatype '(any TreeStyle).Type'` | **报错**（同左） |
| `let s: TreeStyle = .navigator` | 通过 | 通过，警告 `use of protocol 'TreeStyle' as a type must be written 'any TreeStyle'`（`ExistentialAny`，将来的语言模式下升为错误） | 同左 |

⇒ **定案：将来升协议时 modifier 必须是 `treeStyle(_ style: any TreeStyle)`，不是本仓先例的
`some XStyle`**（`bannerStyle(_ style: some BannerStyle)`、`segmentedControlStyle(_ style: some SegmentedControlStyle)`）。
偏离理由：今天的 struct 形态下三元表达式 `flag ? .navigator : .automatic` 是合法写法，泛型参数要求两个分支
推断成同一个具体类型，升级后这类调用点会编译失败；存在类型参数把两个分支都推到 `any TreeStyle`，保住它。
代价：环境里存 `any TreeStyle`、行宿主要对存在类型开箱调用 `makeBody`（`AnyView` 擦除，见 §2.3 末段）——
这份代价升协议时本来就要付，不是 `any` modifier 额外带来的。

升级后**仍不**源码兼容的两种写法（上表实测）：显式 `TreeStyle.navigator`（协议元类型上取不到
`where Self ==` 的静态成员，`any` modifier 也救不了）；把 `TreeStyle` 当具体类型存储（今天只是警告，
将来的语言模式下是错误）。⇒ 文档注释与 `tree.md` 只示范 `.treeStyle(.navigator)`，并写明「不要写
`TreeStyle.navigator`」。

**为保住这条升级路径，公开面刻意收窄**：

- 不给 `TreeStyle` 公开 init、公开属性、`Equatable` / `Hashable` 一致性——这些都是协议形态兑现不了的承诺。
- 隔离：上表的探针**没开** `defaultIsolation(MainActor)`；本仓三个 target 都开了。在本仓 target 里
  `TreeStyle` 可能要写成 `nonisolated public struct` 并加 `Sendable`（`nonisolated` 静态成员返回它、
  `@Entry` 默认值都可能要求）。以 PR 2 前置探针的编译器读数为准；加了 `Sendable` 就登记为升级时要一并
  处理的一项（协议届时同样要 `Sendable` 约束，否则存在类型进不了环境）。
- 静态成员一律 `nonisolated`（对齐 `SegmentedControlStyle` 的 `.glass` / `.plain` / `.ink`），
  不给 MainActor 棘轮添新豁免。

**PR 2 前置探针读数（本仓 target，开 `defaultIsolation(MainActor)`；实测，Swift 6.3）**：库侧两版作为临时文件
放进 `Sources/OhMyDesign/Components/Tree/`，调用方放进 `scripts/downstream-probe`（该包未开 `defaultIsolation`，
调用方即 nonisolated 默认），`swift build` 后删除。

| 调用方写法 | v1 `public struct`（**未加** `nonisolated` / `Sendable`）+ `nonisolated static var` | v2 协议 + `where Self ==` + `treeStyle(_: any TreeStyle)` |
|---|---|---|
| `.treeStyle(.navigator)` | 通过 | 通过 |
| `.treeStyle(self.flag ? .navigator : .automatic)` | 通过 | 通过 |
| `.treeStyle(TreeStyle.navigator)` | 通过 | **报错** `static member 'navigator' cannot be used on protocol metatype '(any TreeStyle).Type'` |
| `let style: TreeStyle = .navigator`（View body 内） | 通过 | 通过，警告 `ExistentialAny` |
| `nonisolated func` 内 `let style: TreeStyle = flag ? .navigator : .automatic` | 通过 | 通过，警告 `ExistentialAny` |

库侧两版都是 0 条诊断 ⇒ 编译器**不要求** `nonisolated public struct`，也**不要求** `Sendable`（`@Entry` 默认值、
`nonisolated` 静态成员返回该类型两处都过）。实现取 v1 原样（`public struct TreeStyle`），没有 `Sendable` 需要登记。

**删除**（相对上一稿）：`lineage` / `TreeSiblingPosition`（YAGNI：`.navigator` 只画直线，
不画肘线）、`HostileTreeStyle` 对抗样式、第三方样式漏画焦点 / 丢部件的风险条目——非协议形态下
不存在第三方实现者。

### 2.2 外观渲染的是「一行」

理由不变，只是作用对象从「样式协议」变成「内部外观实现」：

1. **可见行序列是键盘层的坐标系**（`TreeFlatten.rows` → `TreeKeyboard.action`，源码读）。
   外观只拿到一行的配置，碰不到行序。
2. **惰性归容器**（§5）：哪些行被构建由组件持有。
3. 与 Apple `ButtonStyle` / 本仓 `BannerStyle` 同粒度——这也是将来升协议时 `makeBody` 的粒度。

### 2.3 内部行配置（internal）

组件逐行构造 `TreeRowConfiguration`（internal，可带泛型——不公开就不需要 `AnyView` 擦除）：

| 字段 | 含义 |
|---|---|
| `label` | 调用方 `content(element)` |
| `disclosure` | 组件造好的展开控件：父行是可点 chevron（行为、命中槽、无障碍都在里面）；叶行是同宽隐藏占位 |
| `checkBox` | 组件造好的三态复选框；未传 `checked` 时为 `nil` |
| `level` | 层级，根为 1 |
| `hasChildren` / `isExpanded` / `isSelected` | 状态描述 |
| `showsFocusIndicator` | 本行是否应画焦点指示（容器有键盘焦点**且**最近一次交互来自键盘**且**焦点在本行） |
| `isHovered` | 指针是否悬停在本行（§3） |
| `metrics` | 已过平台下限的 `TreeRowMetrics` |

- 字段名取 `showsFocusIndicator` 而非 `isFocused`：它不是「本行有焦点」，而是 `TreeFocusing.showsRing`
  的归约结果落到本行——点击获焦时焦点在本行但不画指示。与 `#422` 的 `showsFocusRing` 同义，换名是因为
  `.navigator` 画的是内描边不是环。
- configuration **不含任何闭包**（行为留在组件内，§2.4）。
- 行宿主按 `switch appearance` 选 `AutomaticTreeRow` / `NavigatorTreeRow`，走 `_ConditionalContent`，
  **不需要行级 `AnyView`**。

**行级 `AnyView` 成本登记（S-6）**：本轮不引入。将来升协议时，公开的 configuration 必须非泛型
（`BannerStyleConfiguration` 形态），`label` / `disclosure` / `checkBox` 三个部件都得 `AnyView` 擦除，
每个已构建行三次擦除、SwiftUI 无法跨擦除边界做结构 diff。届时要在 `LazyVStack` 大树（1 万行、300pt 视口）
上量一次滚动与展开的 body 耗时再定，不在本轮。

### 2.4 外观拿不到、改不了的东西

| 能力 | 归属 |
|---|---|
| 键盘层（`onKeyPress`、W3C 逐键） | 容器 |
| 行选择归约（单选替换 / 多选切换） | `TreeInteractionReducer`；配置只给 `isSelected` |
| 三态勾选与级联 | 组件造的 `checkBox` 部件 |
| 焦点归约 / 焦点来源 | `TreeFocusing`；配置只给 `showsFocusIndicator` |
| 无障碍取值（"Expanded"/"Collapsed"、`.isSelected` trait、chevron 动作 label） | 组件，施在外观 body **外层** |
| 命中区 | 组件：外层 `frame(minHeight: pitch)` + `contentShape(Rectangle())` + 点选手势 |
| 悬停检测 | 行宿主的 `@State` + `.onHover`（§3），外观只读 `isHovered` |
| 右键菜单 | 组件：行外层 `contextMenu`（§4） |
| 行序、哪些行被构建 | 容器 |

**明确否决 issue 草案里的「展开切换入口」**：配置不含 `toggleExpansion` 闭包。「单击文件夹行即展开」
是**行为**，按公约《边界条款：样式不得携带行为》不进外观；它不进本 issue，**另开 issue**（编排者开）
在 `Tree` 上加行为参数（定案 D5）。

**I-2（样式挡行为）为什么大部分消失**：上一稿的风险是「第三方样式丢掉 / 隐藏部件、把手势挂进
样式」——类型系统挡不住，只能靠对抗样式判据。非协议形态下外观实现只有仓内两个，第三方写不了。
**剩余风险**：仓内实现者自己仍须遵守「放置 `disclosure` / `checkBox`、不挂手势、不读闭包」。
兜底：§7.3 的接线判据对 `.automatic` / `.navigator` 两种外观参数化，外加配置无闭包的结构判据。

### 2.5 内置外观

**`.automatic`**：`#422` 的 `TreeRowView` 修饰链**逐字搬进** `AutomaticTreeRow`，只把写死的常量换成
`metrics`（`.regular` 下取值不变）：

`HStack(spacing: xs) { disclosure; checkBox; label }` → `.padding(.horizontal, xs)` →
`.frame(maxWidth: .infinity, alignment: .leading)` → `.frame(minHeight: metrics.rowHeight)` →
圆角 `CoreRadius.small` 选中底色 `accentSubtleBackground(from: coreAccent)` →
`.padding(.leading, (level - 1) × metrics.indentation)` → `.focusRing(visible: showsFocusIndicator, cornerRadius: small)`。

**`.navigator`**（定案 D6）：

| 部位 | 画法 |
|---|---|
| 选中 | 整行底色（含缩进区），直角；`accentSubtleBackground(from: coreAccent)`。⚠️ **PR 2 实测改为 `accentSelectedRowBackground(from: coreAccent)`（× 0.16）**：× 0.08 与悬停分不清（macOS 亮 235 vs 悬停 243），iOS 暗色下比 `tertiaryFill` 悬停还暗（20 vs 28，阶梯倒置）；定案「底色 < 悬停 < 选中」三档阶梯，四格读数见 `docs/components/tree.md`《三档阶梯》 |
| 悬停 | 整行底色 `Color.surfaceCanvasSubtle`（与 `ListRow` 悬停同一 token，源码读）；选中优先于悬停。⚠️ **PR 2 实测改为 `Color.quaternaryFill`**（三档阶梯的最轻一档）：macOS 上 `surfaceCanvasSubtle` 与 `surfaceCanvas` 同值（`controlBackgroundColor` / `windowBackgroundColor`），悬停与未悬停位图 Δ=0 |
| 焦点 | `CoreBorderWidth.thin` 内描边，取 `coreAccent` |
| 缩进参考线 | 对每个祖先层 `k = 1 … level-1` 画一根 `CoreBorderWidth.hairline` 竖线，色 `Color.borderSubtle`；x 坐标 = **第 k 层 chevron 的中心**，即 `CoreSpacing.xs + (k-1) × indentation + disclosureWidth / 2`（行内横向 padding 计入）；上下各外溢 `rowSpacing / 2`，使 `.regular` 的 2pt 行间距处也连续。⚠️ **PR 2 实测改两处**：色改 `Color.borderDefault`（`borderSubtle` α 0.027，白底 255→248，几乎不可见）；外溢改为**只向上溢出整个 `rowSpacing`**（上下各半时父行与首个子行之间留 `rowSpacing / 2` 的断口，§7.5「从父行下缘连续」判不过） |
| chevron | `.tint(Color.contentSecondary)`（VS Code 的 twistie 是前景色，不是强调色） |
| 缩进 | 内容区左移 `(level - 1) × indentation`，底色 / 悬停 / 焦点描边铺满整行 |

参考线用**视图**（`Rectangle` + leading padding）画，不用 `Canvas` / `Path` 的绝对坐标——
前者随 `layoutDirection` 自动镜像，后者在 RTL 下不翻转（推断，§7.5 有 RTL 判据兜）。
参考线 x 由一个 internal 纯函数给出，chevron 位置由布局给出——判据比的是**两者在位图上是否对齐**，
不是同一个公式算两遍（§7.5）。

### 2.6 部件如何交出而不交出行为

- `disclosure`：组件构造 `TreeDisclosureControl(hasChildren:isExpanded:metrics:) { setExpansion }`，
  内含 `Button`、命中槽（宽 `disclosureWidth`、高 `pitch`）、旋转动效（`reveal.transformAnimation`，
  RM 下为 `nil`）、`accessibilityLabel`。
- `checkBox`：组件构造 `Toggle(sources:isOn:)` + `CheckBoxToggleStyle()` + `labelsHidden()` + §1.4 的
  internal 布局注入，内含 `notePointerCheck` 与级联写回。
- 部件的尺寸都取自组件算好的 `metrics`，不另读环境——避免外观对部件施 `.controlSize(_:)` 时部件与
  行度量分叉（推断）。

## 3. 悬停

- **状态放在行级**（定案，I-7；先例 `ListRow.swift` 的行内 `@State private var isHovered` + `.onHover`，
  源码读）：行宿主持有 `@State isHovered`，`.onHover { self.isHovered = $0 }`，经配置交给外观。
  **不放容器 `@State`**：容器级 `hoveredID` 每次指针跨行都会让 `Tree.body` 重算——整棵可见行重新展平、
  每行 body 重新求值；行级状态只让进出的两行重算。
- 行级状态在 `LazyVStack` 回收行时丢失：被回收的行不在屏幕上，指针不可能悬停在它上面，丢失即正确。
  「同一时刻至多一行悬停」由 `onHover` 的进出配对保证，不另设容器仲裁（指针跨行的一帧内可能两行同真，
  下一次事件即收敛；推断）。
- 行被折叠隐藏后该行视图被移除，状态随之销毁——上一稿「`onChange(of: rows)` 里清空 `hoveredID`」
  随容器状态一起删掉。
- **平台**：macOS 鼠标；iPadOS 指针下 `onHover` 同样触发（推断，未实测，登记为真 HID 项）；
  iPhone 纯触控下永不触发 ⇒ `isHovered` 恒为 false。不用 `.hoverEffect`：那是系统的抬升 / 高亮效果，
  会与外观自己画的悬停底色叠加。
- **动效与 Reduce Motion**：悬停高亮**即时生效、无补间**，三档 `MotionPresentation` 一致 ⇒
  没有需要按 RM 分支的动效。这条「无补间」要有能打红「外观里加隐式 `.animation(_, value: isHovered)`」
  的判据（§7.4）。

## 4. 整行右键菜单

**定案（I-5）：builder 方法，不加第 4 个泛型。**

```swift
public extension Tree {
    /// 为整行挂右键菜单。菜单作用于目标集合：右键行在选中集合里时为「选中集合中当前可见的行」，
    /// 否则只是右键的那一行。builder 会在每个已构建的行上随 body 求值，闭包里不要做重活。
    ///
    /// - Parameter menu: 以目标 ID 集合生成菜单项。
    /// - Returns: 挂好菜单的同一棵树。
    func rowContextMenu<M: View>(@ViewBuilder _ menu: @escaping (Set<ID>) -> M) -> Tree
}
```

- 内部存 `((Set<ID>) -> AnyView)?`，方法返回改了这一个字段的副本。`Tree` 保持
  `Tree<Data, ID, RowContent>` 三个泛型 ⇒ `Tree<[Node], String, Text>` 这类显式写法与
  `Tree.expandedIDs(…)` 的两个重载**全不受影响**。
- **未设置时不挂 `.contextMenu`**（`if let` 分支，不挂空菜单）。
- 菜单项 `AnyView` 擦除只发生在菜单 builder 上，不在行上；P3 实测菜单项自身 body 在右键前调用 0 次。
- **受影响调用点核实**（源码读）：
  - `App/Sources/ComponentData.swift` 里逐字 `Tree<[GalleryTreeNode], String, Text>.expandedIDs` —— 不受影响；
  - `scripts/downstream-probe/Sources/DownstreamProbe/PublicVisibility.swift` 里逐字
    `Tree<[ProbeTreeNode], String, Text>.expandedIDs` —— 不受影响；
  - `Tests/OhMyDesignTests/TreeTests.swift` 里逐字 `Tree<[TreeJudgeNode], String, Text>.expandedIDs` —— 不受影响；
  - `TreeNestedStyleTests.theRootAppliesTheStyleToo` 里逐字 `Tree<[TreeJudgeNode], String, Text>.Body` 的类型串断言含
    `TreeNestedStyle` —— 与右键菜单无关；**PR 4（展平）**删除 `TreeNestedStyle` 时整个
    `TreeNestedStyleTests` 随之删除（§5）。
  - 另需**新增**：downstream-probe 一处 `.rowContextMenu { … }` 调用。

**目标集合（定案，I-4）**：

```
targets(for id, selection, visibleIDs) =
    selection.contains(id) ? selection ∩ visibleIDs : [id]
```

- 纯函数 `TreeContextMenu.targets(for:selection:visibleIDs:) -> Set<ID>` 定义语义（判据对它写）。
  视图侧**每次 body 预算一次** `selectedVisible = selection ∩ visibleIDs`（`visibleIDs` 取自容器 body 里
  已经算好的可见行），所有行共用；行上只做 `selectedVisible.contains(id) ? selectedVisible : [id]`——
  右键行必然可见，故与纯函数等价，且不逐行重做交集。**不遍历树**（P3 实测 builder 随 body
  逐行求值，这里若求整树 ID 就把惰性毁了）。
- **不把其他树共享 selection 里的 ID 传出**：交集天然滤掉。
- **被折叠隐藏的选中项不入目标**（对齐 Finder：折叠的文件夹里之前选中的项不参与右键操作）；文档注释写明。
- 右键**不改**选中、焦点、交互来源（对齐 Finder / Xcode；VS Code 会给右键行画焦点框，本轮不做）。
- 挂在组件的行外层（与命中区同一层）⇒ 覆盖整行（含缩进区），与外观无关，换外观不丢菜单。

不选「配置能力」：菜单内容是调用方的数据操作，不是外观。不选「环境值 + modifier」：
环境值要类型擦除 `ID`，调用方在闭包里拿不到强类型集合。builder 方法挂在 `Tree` 上，`ID` 天然强类型。
拖放：**仍 Out of Scope**（PRD 原文）。

## 5. 展平渲染 + `LazyVStack`（定案 D1，单独成最后一个 PR）

### 5.1 关键事实

- 惰性只作用于 `LazyVStack` 的**直接** `ForEach` 子项；`#422` 的结构是「根层 `ForEach` →
  `DisclosureGroup` → 嵌套 `TreeBranch`」，一个根节点下的整棵可见子树是**一个**子项
  ⇒ P2 实测 201 行全部构建。**不展平，换 `LazyVStack` 对单根大目录的收益为零。**
- 组件本来就在 body 里算 `visibleRows`（键盘层用）——展平渲染不增加遍历。

### 5.2 结构

```
LazyVStack(alignment: .leading, spacing: metrics.rowSpacing) {
    ForEach(visibleItems) { item in  TreeRowHost(item) /* 组件外层 + switch appearance */ }
}
```

`TreeBranch` / `TreeNestedStyle` / `TreeDisclosureGroupStyle` 与 `TreeNestedStyleTests` 删除——
它们防的「嵌套层样式被重置」问题不再存在。

### 5.3 「行渲染需要元素」的形态（I-6）

`TreeRow<ID>` 今天是 `Identifiable, Equatable`（`id` / `level` / `parent` / `hasChildren`，源码读），
被 `onChange(of: rows)` 与键盘归约使用。渲染还需要 `Data.Element`，而 `Element` 一般不是 `Equatable`。

| 候选 | 结论 |
|---|---|
| (a) `TreeRow` 加 `element` 字段 | **否**：`Equatable` 要么丢（`onChange(of: rows)` 编译不过），要么手写 `==` 忽略 element（「相等」不再是值相等，数据变了但行结构没变时 `onChange` 不触发——那本来就是想要的，但把这层语义藏进 `==` 会误导后来者） |
| (b) 另建 `[ID: Element]` 映射 | **否**：每次 body 多建一个字典（可见行规模的哈希），且 ID 重复时静默覆盖 |
| (c) **一次遍历产出 `[TreeRenderItem]`**，`TreeRenderItem { row: TreeRow<ID>; element: Data.Element }`，只 `Identifiable`（`id = row.id`）、不 `Equatable`；`rows = items.map(\.row)` 供 `onChange` 与键盘 | **采用**：一次遍历，元素与行按下标天然对齐；`TreeRow` 与其 `Equatable` 语义不动 |

- `TreeFlatten.rows(...)` 保留为 `items(...).map(\.row)` 的薄封装，`TreeFlattenTests` 不改。
- **对 `TreeLazinessTests` 的影响**：该 suite 断言的是「折叠子树的 `children` 读取 == 0」与「可见父行
  读取 > 0」，不断言精确次数。展平后渲染与键盘共用同一次遍历，可见行的读取次数只会**减少**（今天
  `visibleRows` 一遍 + 递归 `TreeBranch` 一遍），两条断言的方向都不变。新增一条构建计数判据（§7.7）。

### 5.4 无障碍：展平不劣化

- 源码读：当前实现**本就不播报层级**——行上只有 `accessibilityValue`（"Expanded"/"Collapsed"）与
  `.isSelected` trait，没有层级 / 位置信息；tree.md 记载 iOS `axe describe-ui` 实读「行在无障碍树里
  不是一个元素」（拆成 chevron / 复选框 / 行内容三个元素）。⇒ 展平后若 `DisclosureGroup` 曾贡献某种
  容器语义，丢掉的也不是「层级播报」这项今天就没有的能力。
- 但「`DisclosureGroup` 是否贡献过容器语义」未知 ⇒ **iOS 上 `axe describe-ui` 对照是 PR 4 的前置实验**：
  同一夹具在展平前后各读一次，逐元素比对（元素数、类型、label、value、traits）。有差异先登记再决定。

### 5.5 逐项影响

| 维度 | 影响 |
|---|---|
| 虚拟焦点 | **无**。焦点是容器状态里的 ID，不依赖行视图存在；焦点落在未构建行上时，指示在该行被构建时画出 |
| 快照 / 位图判据 | `ImageRenderer` 下 `LazyVStack` 不在 `ScrollView` 里 ⇒ 全部行构建、尺寸与 `VStack` 相同（P1）；与 `VStack` 有 ≤1 LSB 文字抗锯齿差（P2b），在现有 `noiseTolerance = 2` 内 |
| 展开动效 | 由「`DisclosureGroup` 内容整体插入」变为「若干行插入 `ForEach`」；都在 `withAnimation(treeExpansion)` 事务里。静态终态一致；在飞帧外观会不同（推断），实现期真机人工看 |
| 键盘滚动跟随 | `#422` 已登记的缺口**不变**；`LazyVStack` 让「焦点移到未构建行」更常见，不引入新错误 |
| 不在 `ScrollView` 里用 | 退化成全量构建（P1），行为与今天相同 |

⚠️ 这一条**推翻 `#419` spike 选定的路径 A**（递归 `DisclosureGroup`）。A 相对 C 的剩余收益只有
「`DisclosureGroup` 的内容插入过渡」一项（`#422` 落地后行布局、缩进、chevron、展开态播报已全部自绘）。

### 5.6 一次性迁移闸门：`Legacy422` 位图对照（S-2）

- 在 PR 4 里把**被本 PR 改动或删除**的渲染类型从 PR 4 的父提交原样拷进测试 target，改名 `Legacy422*`：
  至少 `TreeBranch` / `TreeNestedStyle` / `TreeDisclosureGroupStyle` / `TreeContext`（`TreeBranch` 依赖它，
  必须连带拷贝）与当时的行宿主；PR 4 未改动的类型直接引用生产代码。拷贝范围：先用
  `git diff --stat <父提交>..HEAD -- Sources/OhMyDesign/Components/Tree/` 列出**被改动的文件**，再逐文件读
  `git diff <父提交>..HEAD -- <文件>` 的 hunk，列出其中被改动或删除的**类型**（`--stat` 只到文件粒度，不列类型）。
- 夹具矩阵：{全折叠, 展开到第 3 层} × {无选中, 选中一个第 3 层行} × {不传 `checked`, 父行 mixed} ×
  {焦点指示画在某行, 不画} × {`.automatic`, `.navigator`} × {light, dark} × {LTR, RTL}，`.regular`，新旧各渲一张。
- 判据：**尺寸完全相同**，且**逐通道最大偏差 ≤ `noiseTolerance`（2）**（P2b）。权威腿是 iOS，macOS 辅证。
- **不常驻**：跑出证据（矩阵读数、iOS `.xcresult` 顶层计数）写进 PR 4 正文后，在同一 PR 的最后一个 commit
  删除 `Legacy422*`。理由：拷贝件会随每次行宿主改动失去对照意义，常驻只会变成维护负担。

## 6. 兼容与登记

### 6.1 行为变化（相对 `#422`，未发布）

`Tree` 尚未进 main（`docs/BREAKING-CHANGES.md` 里 `#422` 一节标「未发布（相对 `v0.11.0`）」，源码读），
以下全部**改写该未发布小节**：

1. `Tree` 读 `controlSize`：祖先设了 `.controlSize(.small)` 的宿主，Tree 会变密（macOS 行距 22）。
2. **命中区扩到整行**：`#422` 的 `contentShape` 在缩进 padding 之内，缩进区点不中；现在组件在外层
   施 `contentShape`，缩进区也选中该行。像素不变，行为变。
3. 新增 `TreeStyle`（`.automatic` / `.navigator`）、`View.treeStyle(_:)`、`Tree.rowContextMenu(_:)`。
4. （PR 4）行不再是 `DisclosureGroup` 的 label；无障碍树结构以 §5.4 前置实验读数为准。

`CheckBox` 公开行为不变（§1.4），不进 BREAKING。

### 6.2 登记表：仍 prescriptive，不进 J-2

- `docs/component-registry.json` 的 `Tree`：`kind` / `decidedBy` / `needsExtensionPoint` / 各协议字段
  **不动**（`prescriptive` / `step3` / `false`）⇒ **不走修订回路**，不新增 `R-50`，
  `ComponentExtensionPointGuard` 的 `inspected.count == 16` 不动。
- `notes` 追加一段（不改原有步骤 1–3 的走查），写明：
  1. **步骤 3 ⇒ 公约不要求扩展点**。`TreeStyle` 是规定性组件上的「**装饰预设**」——封闭配置，第三方不能
     新增外观，公开面只有两个静态成员与一个 modifier——**不在公约 A–D 扩展点形态的射程内**
     （A–D 讲的都是把定制权交给调用方的形态；封闭预设不交出任何定制权）。它是否仍应被公约当作扩展点
     处置，公约没有成文，已登记 `docs/contract-defects.md` 的 `D-429-1` 待公约 owner 裁定。
  2. **两种外观之间的差异逐项落档**。`#422` 步骤 2 的装饰档原文是「连线 / 选中块 / 尺寸 / 缩进引导线」：
     整行选中 vs 圆角选中块 ⇒「选中块」；缩进参考线 ⇒「缩进引导线」；密度 ⇒「尺寸」（由 `controlSize`
     承担）；chevron 着色 ⇒ 同一槽内的画法变化。**悬停高亮不在那份名单里**，不挂在 `#422` 名下，按公约
     补充规则 1（「纯装饰层」指不承载状态 / 内容语义的层，判装饰须写明依据、自陈不足以定性）逐条论证：
     · 它是背景层（补充规则 1 列举的「背景」）；
     · 它不进任何绑定、不进无障碍树（无 trait / value）、不改变可见行 / 选中 / 焦点 / 展开任一状态；
       去掉它，用户失去的只是「指针在哪一行」的冗余反馈——指针自身已经给出这一信息；
     · **但**它随「指针在本行」这一交互状态变化而变化——补充规则 1 的反例（`SidebarStatusFooter` 的状态圆点，
       颜色即状态）判的是**承载**组件状态的层，悬停承载的是指针位置这一**宿主输入**状态，公约没有区分这两者。
     ⇒ **如实写明：论证落在灰区**，倾向「装饰」的理由是前两点；这一问并入 `D-429-1` 一起待裁。
  3. 将来若要让第三方扩展：`TreeStyle` 升为协议 + `where Self ==` 静态成员，modifier 改为
     `treeStyle(_: any TreeStyle)`（§2.1 兼容表）；届时 `kind` / `decidedBy` 翻转走修订回路
     （公约《事后补写的效力边界》），J-2 计数 16 → 17。
- `docs/components/tree.md`「判定法」一节同步上述三点。
- `docs/contract-defects.md` 按既有条目格式（「撞上公约哪一条 / 撞法 / 判据侧现状 / 本轮处置」）新增
  `## #429` 与 `### D-429-1：规定性组件的装饰预设（封闭外观配置）是否属扩展点`，首例 `TreeStyle`，
  连同第 2 点的悬停灰区，**待公约 owner 裁定**，本 issue 不改判。
- 仓库根 `CLAUDE.md`《组件 style 协议》节补一句：`TreeStyle` 是刻意的封闭配置例外（非协议），理由见本 spec
  §2.1；除非按那里的兼容路径（`any TreeStyle` modifier）升级，否则勿改成协议。
- 以上三处文档（registry `notes`、`contract-defects.md`、`CLAUDE.md`）**都落在 PR 2**，与 `TreeStyle` 同 PR。
- `QuotedEvidenceGuard`：registry notes 逐字引用的 `content.disclosureGroupStyle(TreeDisclosureGroupStyle())`
  在 PR 1–3 **保持原样**（PR 1 的行间距由 `TreeDisclosureGroupStyle` 在自己的 body 里读 `controlSize` 推出，
  不给它加构造参数，那句引文不变），在 PR 4 删除 → 该条登记与 notes 里那句原文**同 PR 改写**（否则判红）；其余四条引文所在的
  `TreeCore.swift` / `TreeInteraction.swift` 片段若被 PR 1–4 改到，同样同 PR 同步。
- 「更正传播」三处：源码文档注释、`tree.md`（「外观」改为推导表 + 两个内置外观；新增「外观配置」「右键菜单」
  两节；「判定法」追加上面三点）、registry `notes`。改完 grep「CoreSpacing.md」「height(for: .regular)」
  「showsFocusRing」「DisclosureGroup」在三处的残留。

### 6.3 PRD FR-2 修订点

`.claude/prds/timeline-tree-action-buttons.md`：

1. FR-2 能力范围追加「**密度与外观配置**」：读 `controlSize`（推导表见本 spec §1.2）、`TreeStyle` 封闭配置
  （`.automatic` / `.navigator`，非协议，升协议的兼容路径见 §2.1）、整行右键菜单（`rowContextMenu`，
   目标集合 = 选中 ∩ 可见 或 单行）。
2. FR-2 开头「自己递归 + 每节点展开绑定」——PR 4 合入时改为「每节点展开绑定；渲染按可见行展平」，
   注明推翻 FR-2a 路径 A 的理由（§5.5）。
3. NFR 的 J-2 计数句**不动**（仍 16）。
4. Out of Scope 不变（拖拽重排、懒加载子节点、`F2`、type-ahead）；追加「单击父行即展开：另开 issue」。

### 6.4 对 issue #429 正文的偏离（需在 issue 上登记）

| issue 原文 | 本 spec |
|---|---|
| 新增 `TreeStyle` **协议** | 封闭配置 struct（§2.1），升协议留作加法 |
| configuration 暴露「展开切换入口」 | 否决（§2.4），行为另开 issue |
| registry 由 prescriptive 改判、进 J-2 定义域 | 不改判，J-2 仍 16（§6.2） |
| DoD「自定义 `TreeStyle` 下行为一致的判据」 | 改为「两种内置外观下行为一致」（§7.3） |

## 7. 判据计划

纪律：判据能被变异打红；**变异不照判据的形状构造**（改的是一个真实会犯的错，而不是把判据
读的那个常量改掉）；每次变异先 `git diff` 确认落到了文件里，再跑判据。

### 7.1 密度（PR 1）

| 判据 | 腿 | 形式 |
|---|---|---|
| `TreeRowMetrics` 五档取值 | 双腿 | 纯函数；`.regular` 一列逐项等于 `#422` 现值；五档单调不减；`.small` 视觉行高 = 22 |
| 渲染行距 = `metrics.rowHeight` | **macOS** | 单叶节点 Tree 在五档下的渲染高度逐档等于表值（macOS 无下限） |
| **带复选框**时渲染行距 = `metrics.rowHeight` | **macOS** | 同上，传 `checked`；这是 §1.4 的承重判据 |
| 父行（有 chevron）渲染行距 = `metrics.rowHeight` | **macOS** | 两层树折叠态，`.small` 下等于 22 |
| 渲染缩进 = `metrics.indentation` | 双腿 | 两层树、行内容是纯色块：量父子两行色块左缘的列差（位图），`.small` 与 `.regular` 各一次 |
| iOS 触控目标 | **iOS** | `TouchTargetTests` 的 Tree 两条改成对 `ControlSize.allCases` 参数化：行高、chevron 槽高都 ≥ 44；加一条带复选框的行 |
| `CheckBox` 公开行为不变 | 双腿 | 不另写判据，靠既有的逐像素对照：`CheckBoxLegacyAppearanceTests.matchesLegacy`（与 `ce20fad` 原样拷贝的旧样式逐像素相等）与 `FieldValidationControlsAppearanceTests` 的 CheckBox 格（与测试内的 `LegacyCheckBoxToggleStyle` 对照）；另三个 CheckBox suite 照跑 |

「未注入 = 注入 `nil`」这类判据**不写**：两边走的是同一个 `nil` 分支，恒真。上面两条对照的参照物是写死
`.regular` 的旧实现拷贝，能打红 `nil` 分支的取值漂移（见下面第 5 条变异）。

计划中的变异：

- **只改了行、忘了改 chevron 槽**（`TreeDisclosureSlot` 仍写死 `height(for: .regular)`）——预期父行行距判据红（44 ≠ 22）。
- **忘了给 Tree 的复选框注入布局**（`CheckBoxBody` 读了环境值，但 Tree 没注入）——预期带复选框行距判据红。
- **平台下限写反**（`#if os(macOS)` 施 44）——预期 iOS 触控目标判据红、macOS 行距判据红。
- **缩进从错误来源取**（行宿主里写 `CoreSpacing.md`）——预期 `.small` 缩进位图判据红。
- **`CheckBoxBody` 的 `nil` 分支取错档**（缺省分支写成 `iconSize(for: .small)`，「顺手统一成 Tree 的密集档」）——
  预期 `CheckBoxLegacyAppearanceTests.matchesLegacy` 与 `FieldValidationControlsAppearanceTests` 的 CheckBox 格红。

### 7.2 `.automatic` 像素一致（PR 2）

PR 2 把行修饰链搬进 `AutomaticTreeRow`、把 `contentShape` 挪到外层。`.regular` 下既有 `TreeRenderTests`
的位图判据须全绿；另加一格「选中行 + 第 3 层」与 PR 1 合入态逐像素对照。基准**不存 scratch**：照
`CheckBoxLegacyAppearanceTests` 的做法，在 PR 2 内把 PR 1 合入态的行实现（`TreeRowView` 及其依赖）原样拷进
测试 target、改名作参照，新旧同进程各渲一张比；PR 2 最后一个 commit 删除拷贝（读数进 PR 正文）。
变异：选中块圆角换 `CoreRadius.medium`；把 `.padding(.leading)` 挪到背景之前（选中块铺进缩进区）。

### 7.3 两种外观下行为一致（PR 2）

1. `TreeHostedWiringTests`（macOS 托管窗口 + 合成事件）：既有判据**只有两条**——
   `expansionTransactionsFollowTheEnvironment`（点 chevron / 按 `←` 的展开事务曲线）与
   `keysWriteTheReducedStateBack`（`↓` + `Space` 写回选中）；这两条对 `[.automatic, .navigator]` 参数化。
   **新增**两条判据（同样参数化）：点复选框勾选、点行选中。`TreeHostedHarness` 今天不传 `checked`，
   要加一个 `@State checked` 绑定与对应的 `TreeHostedLog` 字段。两种外观下绑定终态逐项相等。
   点击坐标由 `metrics` 推出（chevron 中心 = `xs + (level-1) × indentation + disclosureWidth / 2`）；
   外观若把 chevron 放错位置，点击落空、判据红——这是真实的检查，不是自证。
2. 新增一格：点**缩进区**选中该行（§6.1 第 2 条的行为变化），两种外观都要成立。
3. 无障碍取值：两种外观下行的 `accessibilityValue` / trait 相同（iOS 腿既有读取方式；读不到则登记真 HID 项）。
4. **结构判据**：`Mirror(reflecting: TreeRowConfiguration(...)).children` 中没有函数类型的字段。

变异：把 `.onTapGesture` 从组件外层挪进 `NavigatorTreeRow`（行为被外观携带，且挂在缩进之内）——
预期 `.navigator` 那一格的「点缩进区选中」红；给配置加 `let toggleExpansion: () -> Void`——预期结构判据红。

⚠️ 合成事件测的是「两种外观下同一套接线是否等价」这一**相对**命题，不证明平台真实行为。
真 HID 复测沿用 `.claude/epics/structure-components/422-probe`。

### 7.4 悬停与 Reduce Motion（PR 2）

| 判据 | 形式 |
|---|---|
| `.navigator` 悬停 / 未悬停两张图不同；选中 + 悬停 与 仅选中 相同 | 位图（直接构造 `NavigatorTreeRow` 喂 `isHovered`） |
| **悬停切换不带动画（整行层）** | macOS 托管窗口：宿主 `@State` 翻转传给 `NavigatorTreeRow` 的 `isHovered`，行 `label` 里放 `.transaction { log($0.animation) }` 探针；三档 `MotionPresentation` 下翻转时 `animation == nil` |
| **悬停切换不带动画（源码层）** | SwiftSyntax 判据：`NavigatorTreeRow`（以实现时的实际类型名为准）与行宿主类型内**不得出现任何** `animation(` / `coreAnimation(` / `withAnimation` 调用——不做「`value:` 是否引用 `isHovered`」的数据流分析（写成 `value: hovered` 的局部别名就能绕过）。`.navigator` 的外观本来没有任何补间，禁令不误伤；chevron 旋转在 `TreeDisclosureControl` 里，不在这两个类型内 |
| 悬停状态在行级 | 源码判据：`Tree` 容器结构体内无含 `hover` 的存储属性；`.onHover` 只出现在行宿主类型内 |
| 悬停不重算整棵树 | macOS 托管窗口：`content` 闭包调用计数——翻转一行的悬停，只有该行的 `content` 被再次调用（其余行计数不变）。**依赖合成悬停可行**（下一行）；不可行则本条降级为真 HID 登记项 |
| `onHover` 真的接到状态 | 先试托管窗口合成 `mouseMoved` / `mouseEntered`（托管窗口不是 key window，能否触发 tracking area 未验证）。**不可行 ⇒ 不写这条判据**，登记为真 HID 探针项（写进 `tree.md`「不在 CI」清单），并在 PR 正文写明合成的读数 |

变异（均为真实会犯的错，不照判据形状）：

- 在 `NavigatorTreeRow` 的整行背景上加 `.animation(CoreMotionToken.selection.animation(for: presentation), value: isHovered)`
  （「给悬停加个淡入」，且走了 token，能过 `CoreMotionTokenDisciplineGuard`）——预期源码层判据红；
  若加在包住 `label` 的层上，整行层判据也红。
- 同一句改写成局部别名 `let hovered = isHovered` + `.animation(…, value: hovered)`——预期源码层判据仍红（按名禁调用，不看实参）。
- 把 `.onHover` 的写入包进 `withAnimation(CoreMotionToken.selection.animation(...))`——预期源码层判据红。
- 把悬停状态上提成容器 `@State hoveredID`——预期「状态在行级」源码判据红。**覆盖面如实写**：「不重算整棵树」
  那条只在合成悬停可行时存在；不可行时，这个变异只有源码判据一道网，而源码判据按名字（`hover`）匹配存储属性——
  换个名字（`@State pointerRow`）就漏。这一层缺口登记在 `tree.md`「不在 CI」清单。

Reduce Motion 台账：Tree 仍登记 `gated`；chevron 旋转、展开曲线两个调用点不变；悬停无动效调用点。

### 7.5 缩进参考线（PR 2）

| 判据 | 形式 |
|---|---|
| 参考线对齐 chevron 中心 | 位图：父行 chevron 字形的水平中心列（取非背景像素的左右缘中点）与其子行参考线所在列之差 ≤ 1pt，`.small` / `.regular` 各一次 |
| 参考线跨行连续 | 位图：`.regular`（有 2pt 行间距）下，参考线所在列从父行下缘到最后一个子行下缘逐像素非背景 |
| 参考线根数 = `level - 1` | 位图：第 3 层行在参考线列位置上恰有 2 列非背景 |
| RTL 镜像 | 位图：行内容用纯色块（无文字），RTL 图 = LTR 图水平翻转（≤ 噪声） |

变异：参考线 x 漏掉行内横向 padding（上一稿的 S-7 偏差，真实会犯）——预期「对齐 chevron 中心」红；
去掉上下外溢——预期「跨行连续」红；循环写成 `1...level`——预期「根数」红；用 `Path` 按绝对 x 画——预期 RTL 红。

### 7.6 右键菜单（PR 3）

| 判据 | 形式 |
|---|---|
| 目标集合 | 纯函数 `targets(for:selection:visibleIDs:)`：右键行在选中集里 → 选中 ∩ 可见；不在 → 单元素；selection 含树外 ID → 不传出；selection 含被折叠隐藏的本树 ID → 不传出 |
| 接线 | 渲染时捕获 builder 的实参（P3 实测 builder 随 body 求值）：每个已构建行**收到的目标集合都正确**、每行调用次数 **≥ 1**（P3 实测每行 2 次，次数是 SwiftUI 的实现细节，不钉死） |
| 未设置不挂菜单 | **运行时探针**：macOS 托管窗口里对行所在点取 `NSView.menu(for:)`（合成右键事件），或读该行 AX 元素的动作列表是否含 `AXShowMenu`；未设置时应无菜单 / 无该动作。⚠️ **实现前先验证探针可区分**：对「正确实现」与「无条件挂空 `.contextMenu`」这两份代码各跑一次，读数不同才采用；读数相同 ⇒ 换探针或登记为真 HID 项，不写一条恒绿的判据 |
| 不遍历树 | 沿用 `TreeLazinessTests` 的 `children` 读取计数：带菜单渲染时折叠子树读取次数仍为 0 |
| 右键不改状态 | 纯函数层无状态写入；视图层登记为真 HID 项 |

变异：目标集合写成 `selection.union([id])`（右键未选中行时把它并进旧选中集）——预期目标集合判据红；
目标集合直接用 `selection` 不求交（「对齐 `contextMenu(forSelectionType:)`」的写法）——预期
「树外 ID / 折叠隐藏 ID 不传出」红；用 `treeIDs` 求交代替可见集——预期惰性判据红；行宿主无条件挂
`.contextMenu { rowMenu?(targets) }`——预期「未设置不挂菜单」的运行时探针红（前提是该探针已通过可区分性验证）。

### 7.7 展平 + `LazyVStack`（PR 4）

- 构建计数：`ScrollView` 300pt 视口、200 个子节点的展开父节点，构建的行数 < 20（P2 实测 7）。
- 行身份：macOS 托管窗口里每行 `onAppear` 记下自己的 ID；展开一个中间的父节点后，新出现的 ID 集合恰为被插入的
  子行。`ForEach` 若按下标取 id，已有行的身份随下标平移，新出现的是尾部下标上的行 ⇒ 集合不同。
  （`ImageRenderer` 下每次都是全新构建，身份错位画不出差别，所以这条必须在托管窗口里做。）
- §5.6 的一次性 `Legacy422` 位图闸门。
- §5.4 的 iOS `axe describe-ui` 前置对照。
- 变异：容器换回 `VStack`——预期构建计数红；保留 `LazyVStack` 但恢复根层 `DisclosureGroup` 嵌套——预期红
  （P2 实测 201）；展平改成层序遍历——预期 `Legacy422` 闸门红、键盘判据红；`ForEach` 按下标取 id——预期行身份判据红。

### 7.8 强制检查

macOS `swift test`（读 `Test run with N tests` 总数，不数逐条行）、iOS `xcodebuild -scheme OhMyDesign-Package`
（`.xcresult` **顶层** `passedTests`）、预览宿主（公开 API 变化的 PR；按 CLAUDE.md 核 `Debug-iphonesimulator` +
`Compiling ComponentData.swift` + `in target 'OhMyDesignPreview'` 步数非 0）、`scripts/downstream-probe`
（PR 2 新增 `.treeStyle(.navigator)`，PR 3 新增 `.rowContextMenu`）、MainActor 棘轮（静态成员已 `nonisolated`，
预期无新增豁免）、`design-digest.py`（FLOORS 按实际增量改并注 `#429`）。快照：PR 2 画廊新增 VS Code 示例后按
`scripts/run-snapshots.sh` 重生成 `docs/snapshots/OhMyDesignPreview_Previews.swift_Tree.{png,json}`。
逐 PR 的口径见 plan。

## 8. VS Code 复刻示例（最终 API）

```swift
import SwiftUI
import OhMyDesign

struct FileNode: Identifiable {
    enum GitStatus { case modified, untracked, deleted }

    let id: URL
    let name: String
    var children: [FileNode]?
    var git: GitStatus?
}

struct ExplorerPane: View {
    let roots: [FileNode]
    @State private var expanded: Set<URL>
    @State private var selection: Set<URL> = []

    init(roots: [FileNode]) {
        self.roots = roots
        self._expanded = State(initialValue: Tree.expandedIDs(roots, id: \.id, children: \.children, toDepth: 2))
    }

    var body: some View {
        ScrollView {
            Tree(
                self.roots,
                children: \.children,
                expanded: self.$expanded,
                selection: self.$selection,
                selectionMode: .multiple,
                onActivate: { url in self.open(url) }
            ) { node in
                HStack(spacing: CoreSpacing.xs) {
                    Label {
                        Text(verbatim: node.name)
                            .foregroundStyle(Self.tint(for: node.git) ?? Color.contentPrimary)
                            .lineLimit(1)
                    } icon: {
                        Image(systemName: Self.icon(for: node))
                            .foregroundStyle(Color.contentSecondary)
                    }
                    Spacer(minLength: 0)
                    if let git = node.git {
                        Text(verbatim: Self.letter(for: git))
                            .coreFont(.caption)
                            .foregroundStyle(Self.tint(for: git) ?? Color.contentSecondary)
                    }
                }
            }
            .rowContextMenu { targets in
                Button("Open") { targets.forEach(self.open) }
                Button("Reveal in Finder") { self.reveal(targets) }
                Divider()
                Button("Delete", role: .destructive) { self.delete(targets) }
            }
        }
        .treeStyle(.navigator)
        .controlSize(.small)
    }

    private static func icon(for node: FileNode) -> String {
        guard node.children == nil else { return "folder" }
        switch node.id.pathExtension {
        case "swift": return "swift"
        case "md": return "doc.richtext"
        case "json": return "curlybraces"
        default: return "doc"
        }
    }

    private static func letter(for status: FileNode.GitStatus) -> String {
        switch status {
        case .modified: "M"
        case .untracked: "U"
        case .deleted: "D"
        }
    }

    private static func tint(for status: FileNode.GitStatus?) -> Color? {
        switch status {
        case .modified: .warning
        case .untracked: .success
        case .deleted: .danger
        case nil: nil
        }
    }

    private func open(_ url: URL) {}
    private func reveal(_ urls: Set<URL>) {}
    private func delete(_ urls: Set<URL>) {}
}
```

macOS 上：行距 22、缩进 11、chevron 12pt 中性色、整行选中 / 悬停、参考线连续、右键作用于「选中 ∩ 可见」或单行。
iOS 上：同一份代码行距 44（§1.3），其余一致。
与 VS Code 仍有的差距（均属后续加法或行为参数，不在本轮）：单击文件夹行展开（另开 issue）、双击打开、
树失焦时选中色变淡、参考线只在悬停整棵树时显示、活动参考线高亮、右键行画焦点框、`showLine` 肘线。

## 9. 被否决的替代方案

1. **只读 `controlSize`、不给外观选项**。整行选中、悬停高亮、缩进参考线都是画法，写死就只有一种；
   用户要的 VS Code 形态与 `.automatic` 在这三处都不同。
2. **公开 `TreeStyle` 协议 + 走修订回路改判**。能承载 `showLine` 等开放候选，但「参考线承载层级归属」的
   改判论证可被反驳为「与缩进冗余编码」，且公开协议不可逆。封闭配置先交付两种外观，升协议保留为加法（§2.1）。
3. **`rowStyle:` 闭包（外观槽，形态 D1）**。差异分布在多处（选中底色铺设范围、缩进区参考线、焦点指示、
   chevron 着色、缩进由谁施加），一个槽装不下；且槽是逐实例参数，不能像 `.treeStyle(_:)` 那样对整个子树生效。
4. **公开枚举（形态 D2）并登记为扩展点**。登记为扩展点就要把 `Tree` 从步骤 3 改判、走修订回路，
   与第 2 条是同一个问题；本 spec 的封闭配置**不声称**是扩展点，它是否仍须按扩展点处置交 `D-429-1` 裁（§6.2）。
5. **系统 `List` / `OutlineGroup` + `.listStyle`**。`ListStyle` 没有公开 `makeBody`；`OutlineGroup` 的 8 个
   public init 无一带展开态；`List(selection:)` 在 iOS 26 上给 0 键盘、不能嵌进 `ScrollView`（`#419` spike）。
6. **第 4 个泛型 `MenuItems` + `contextMenu:` init 参数**。要么 init 翻倍、要么 `expandedIDs` 免泛型重载的约束
   跟着扩，显式写 `Tree<[Node], String, Text>` 的代码全部要补 `EmptyView`。builder 方法零破坏（§4）。
7. **悬停状态放容器**（`hoveredID`）。每次指针跨行重算整棵树 body（§3）。
8. **Tree 的复选框改走 `CheckBox` 读 `controlSize`**。见 §1.4。

## 10. 定案记录 / 风险 / 未决

### 定案（编排者已拍板）

| # | 定案 |
|---|---|
| D1 | 展平 + `LazyVStack`，单独成最后一个 PR（PR 4），含 `Legacy422` 一次性闸门与 iOS `axe` 前置实验 |
| D2 | 封闭配置 `struct TreeStyle`（`.automatic` / `.navigator`），非协议；registry 不改判、J-2 仍 16；「装饰预设是否属扩展点」登记 `D-429-1` 待公约 owner 裁定；将来升协议时 modifier 取 `any TreeStyle` |
| D3 | iOS 各档行距保底 44 |
| D4 | `.automatic` 跟随 `controlSize`；macOS `.regular` 仍 44，不做平台分叉 |
| D5 | 「单击文件夹行即展开」不进本 issue，另开 issue（编排者开） |
| D6 | 第二外观名 `.navigator` |

### 风险

- **R1** 展平后无障碍树结构可能变化——PR 4 前置 `axe describe-ui` 对照（§5.4）。
- **R2** `LazyVStack` 的插入 / 删除动画在展开折叠时的在飞帧质量未测；静态终态有判据，在飞帧只能人工看。
- **R3** 行内容里读 `controlSize` 的控件会把密集行撑高（§1.4 末段），只能靠文档。
- **R4** 升协议的源码兼容性已在独立模块上实测（§2.1 兼容表），但**未在开了 `defaultIsolation(MainActor)` 的本仓
  target 里测**——PR 2 前置探针补这一格；若 `.treeStyle(.navigator)` 或三元写法在 `any TreeStyle` 版本下不过，
  回到本 spec 重议 D2，不带着错误前提实现。
- **R5** `onHover` 的接线（尤其 iPadOS 指针）不在 CI；合成 `mouseMoved` 在非 key 托管窗口是否触发未知。
- **R6** 右键菜单 builder 随 body 逐行求值（P3 实测）——调用方在闭包里做重活会拖慢滚动；只能靠文档。
- **R7** `#423`（搜索高亮）改同一批文件，且要往行里加命中高亮；本 issue 的行宿主重构后 `#423` 需要 rebase，
  命中高亮应落在 `label` 内（调用方内容侧）还是行配置新字段，由 `#423` 定。
- **R8** 本 spec 的全部探针只在 macOS 跑过；iOS 腿上 `LazyVStack` / `ImageRenderer` / `contextMenu` 的行为是推断。

### 未决（可后续加法，不阻塞本轮）

- 行配置加「树是否有焦点」（失焦选中色）、「整棵树是否被悬停」（参考线仅悬停显示）、活动参考线。
- 双击激活（`onActivate` 的指针入口）；右键行的焦点框。
- 键盘焦点跟随滚动（需要滚动容器协作，另开 issue）。
- `TreeStyle` 升协议（第三方外观、`showLine` 肘线）——兼容路径见 §2.1，改判走修订回路。
- `CheckBox` 自身读 `controlSize`（含 iOS 触控下限裁决）——另议，Tree 的 internal 注入届时删除。
