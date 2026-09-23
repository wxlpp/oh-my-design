# Tree 密度与样式扩展点（#429）设计 spec

- 日期：2026-09-23
- Issue：`wxlpp/oh-my-design#429`（依赖 `#422`，与 `#423` 同一批文件、不并行）
- 基线：`origin/epic/structure-components` = `805f40f`（`#422` Tree 本体已合入）
- 本文只是设计，**不含实现代码**。文中「实测」均指下方 §0 列出的探针（scratch，不进仓库），
  其余一律标「推断」或「源码读」。

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

## 1. 密度：读 `@Environment(\.controlSize)`

### 1.1 约定

与按钮样式同一惯例：`Tree` 在**组件内**读 `controlSize`，推导一份 `TreeRowMetrics`，
经 configuration 交给样式（§2）。**所有样式共用同一份度量**——样式可以不用某个量，但不能
改组件据以做命中与布局的那几个量（§1.3）。

### 1.2 推导表（全部来自既有 token，不另立常量）

| 量 | 推导 | mini | small | **regular** | large | extraLarge | `#422` 现值 |
|---|---|---|---|---|---|---|---|
| 视觉行高 `rowHeight` | `size < .regular` ⇒ `iconSize(for:) + 2 × verticalPadding(for:)`；否则 `height(for:)` | 20 | **22** | **44** | 50 | 56 | 44（写死 `.regular`） |
| 展开槽宽 `disclosureWidth` | `iconSize(for:) + CoreSpacing.sm` | 20 | 22 | **24** | 28 | 32 | 24 |
| 缩进步长 `indentation` | `disclosureWidth / 2` | 10 | 11 | **12** | 14 | 16 | 12（`CoreSpacing.md`） |
| chevron 字号 | `compactIconSize(for:)` | 10 | 12 | **14** | 16 | 18 | 14（`iconSize(.small)`） |
| 行间距 `rowSpacing` | `size < .regular` ⇒ `CoreSpacing.none`；否则 `CoreSpacing.xxs` | 0 | 0 | **2** | 2 | 2 | 2 |
| 行内横向 padding / 行内 gap | 不随档位变：`CoreSpacing.xs` | 4 | 4 | 4 | 4 | 4 | 4 |

（数值为源码读 `CoreControlMetrics` / `CoreSpacing` 后的算术；`.regular` 一列逐项等于 `#422`
现值，这是 §6「`.automatic` 像素一致」的前提。）

推导理由（写进源码注释的只有第 1、2 条，各一句）：

1. **两个区间**：`mini` / `small` 是「桌面密集列表」区间，行高 = 图标 + 上下 padding（`small`
   正好落到 VS Code 的 22pt）；`regular` 起沿用控件高度 token。不用单一公式的原因：
   `iconSize + 2 × verticalPadding` 在 `.regular` 给 40，既破 44pt 又破现值。
2. **缩进 = 展开槽宽的一半**：子行的 chevron 落在父行 chevron 与行内容之间——VS Code 的
   twistie 16px / indent 8px 就是这个比例；`.regular` 恰好还原现值 12。
3. 行间距在密集区间取 0：VS Code 行与行无缝，缩进参考线要连成一条（§2.6）。

### 1.3 iOS 触控目标：视觉行高与命中区的关系

**结论：连续堆叠的行，行距（pitch）就是命中区的上限，二者不能解耦。**
每行的独占命中高度 ≤ 相邻两行的中心距——把命中区扩到行框外（`contentShape` 负 inset）只会
和邻行重叠，重叠处归后绘制的那一行，等于把点击让给邻行（这正是 `#422` 修过的「一次点击勾上整棵
子树」那类事故的形状）。这是几何事实，不依赖 SwiftUI 行为（推断，但无需探针）。

因此：

- **组件**在样式 body 外层施加 `frame(minHeight: pitch)`，`pitch = max(rowHeight, platformFloor)`；
  `platformFloor` iOS 取 `CoreControlMetrics.height(for: .regular)`（44），macOS 取 0。
  `configuration.metrics.rowHeight` 交给样式的就是**已经过下限**的 `pitch`，样式画出来的行
  与命中区一致，不存在「视觉 22、命中 44」的错位。
- ⇒ **iOS 上 `mini` / `small` 行距仍是 44**，密度只体现在缩进、chevron、行间距。iOS 不会长得像
  VS Code——这是有意的（待用户拍板，见 §10 D3）。
- **行内**的子控件可以解耦：chevron 槽与复选框槽的命中高度 = 整个 `pitch`，字形按档位缩小。
  这是 `#422` 已有做法（`TreeDisclosureSlot` 高 44），本次只把高度从写死改成 `pitch`。
- ⚠️ 横向：chevron 槽宽 20–32pt < 44pt，与 `#422` 现状同型（现判据只核高度）。本次不改，
  登记为已知项。

## 2. `TreeStyle` 协议

### 2.1 样式渲染的是「一行」，不是整棵树

理由：

1. **可见行序列是键盘层的坐标系**（`TreeFlatten.rows` → `TreeKeyboard.action`，源码读）。
   整树样式拿到递归结构后可以重排、跳过、合并行，键盘的「下一行」就不再是屏幕上的下一行。
   逐行样式在类型上就碰不到行序。
2. **惰性归容器**（§5）：`LazyVStack` 与行的实现化由组件持有，样式不应决定哪些行被构建。
3. `TreeNestedStyle` 的教训：`DisclosureGroupStyle` 在 `configuration.content` 内被重置回
   `.automatic`（`#419` 实测，源码注释与 registry notes 记载），所以「一个样式包住整棵递归」
   在系统协议上本来就做不到。本仓自有的 `@Entry` 不受该重置影响（P1 实测），但 §5 的结论是
   干脆不再递归 `DisclosureGroup`，这个问题随之消失。
4. 与 Apple `ButtonStyle` / 本仓 `BannerStyle` / `RatingStyle` 同粒度：一个样式 = 一个可重复单元。

### 2.2 公开 API 草案

```swift
// MARK: - TreeStyle

/// `Tree` 单行外观的扩展点，形态对齐 `BannerStyle` / Apple `ButtonStyle`。
public protocol TreeStyle {
    associatedtype Body: View

    @ViewBuilder
    @MainActor @preconcurrency
    func makeBody(configuration: Self.Configuration) -> Body

    typealias Configuration = TreeStyleConfiguration
}

// MARK: - TreeStyleConfiguration

/// 传给 `TreeStyle.makeBody` 的一行上下文：只描述外观所需的状态与组件交来的部件。
public struct TreeStyleConfiguration {
    public typealias Label = AnyView

    /// 调用方 `content` 生成的行内容。
    public let label: Label
    /// 展开控件：父行是可点的 chevron（行为、命中槽、无障碍都在里面）；叶行是同宽的隐藏占位。
    public let disclosure: AnyView
    /// 三态复选框；只有 `Tree` 传了 `checked` 时非 `nil`。样式必须放置它。
    public let checkBox: AnyView?
    /// 层级，根为 1。
    public let level: Int
    /// 从根到本行每一层在兄弟中的位置；`lineage.count == level`，末项是本行自己。
    public let lineage: [TreeSiblingPosition]
    /// 是否有子节点。
    public let hasChildren: Bool
    /// 是否展开。
    public let isExpanded: Bool
    /// 是否在行选中集合里。
    public let isSelected: Bool
    /// 键盘焦点环是否应画在本行（容器有键盘焦点且最近一次交互来自键盘）。
    public let isFocused: Bool
    /// 指针是否悬停在本行（macOS 鼠标 / iPadOS 指针；纯触控下恒为 false）。
    public let isHovered: Bool
    /// 按 `controlSize` 推导、已过平台命中下限的度量。
    public let metrics: TreeRowMetrics
}

/// 节点在同级兄弟中的位置，供样式画连接线（如 `├` / `└`）。
public nonisolated enum TreeSiblingPosition: Hashable, Sendable {
    case notLast
    case last
}

/// `Tree` 按 `controlSize` 推导的行度量（pt）。
public nonisolated struct TreeRowMetrics: Hashable, Sendable {
    /// 行距：视觉行高与平台命中下限取大。
    public let rowHeight: CGFloat
    /// 每深一层的缩进。
    public let indentation: CGFloat
    /// 相邻行的间距。
    public let rowSpacing: CGFloat
    /// 展开控件占位宽度。
    public let disclosureWidth: CGFloat
}

// MARK: - 内置样式

/// 默认外观：与 `#422` 逐像素一致（圆角选中块、内容区起于缩进之后、焦点环）。
public struct AutomaticTreeStyle: TreeStyle { public nonisolated init() {} … }

/// 导航器外观：整行选中、悬停高亮、缩进参考线、中性色 chevron。
public struct NavigatorTreeStyle: TreeStyle { public nonisolated init() {} … }

public extension TreeStyle where Self == AutomaticTreeStyle {
    /// 默认外观。
    nonisolated static var automatic: AutomaticTreeStyle { AutomaticTreeStyle() }
}

public extension TreeStyle where Self == NavigatorTreeStyle {
    /// 导航器外观（整行选中 + 悬停 + 缩进参考线）。
    nonisolated static var navigator: NavigatorTreeStyle { NavigatorTreeStyle() }
}

extension EnvironmentValues {
    @Entry var treeStyle: any TreeStyle = AutomaticTreeStyle()
}

public extension View {
    /// 为子树中的所有 `Tree` 设置行外观。
    ///
    /// - Parameter style: 任意符合 `TreeStyle` 的实现，内置 `.automatic` / `.navigator`。
    func treeStyle(_ style: some TreeStyle) -> some View {
        self.environment(\.treeStyle, style)
    }
}
```

形态上的几条定案：

- **configuration 没有 public init**（与 `BannerStyleConfiguration` 同）。⇒ 其上的 Bool 全是只读
  状态描述，不产生公开 Bool **入参**，`BoolExemptionGuard` 无需新增豁免（`SegmentedControlStyle
  Configuration.Segment` 之所以要豁免，是因为它有 public init，源码读 `docs/bool-exemptions.json`）。
  代价：下游无法自己构造 configuration 给自定义样式做单测。
- **`disclosure` / `checkBox` 用 `AnyView`，不用具名 `View` 结构体**：`ComponentRegistryGuard`
  把任何 `public struct …: View` 登记为组件（源码读 `visit(_ node: StructDeclSyntax)`），
  具名部件类型会被判成未登记组件。`BannerStyleConfiguration.actions: AnyView?` 是同一形态的先例。
- **静态快捷成员一律 `nonisolated`**（对齐 `SegmentedControlStyle` 的 `.glass` / `.plain` / `.ink`），
  不给 MainActor 棘轮添新豁免。
- **往 configuration 加字段是加法、不破坏既有样式**；往协议加要求才是破坏性的。⇒ 本轮只放
  VS Code 复刻真正要用的字段，「容器是否有焦点（失焦时选中色变淡）」「活动缩进参考线」
  「整棵树是否被悬停（VS Code 默认 `onHover` 才画参考线）」都留作后续加法（§10）。

### 2.3 样式拿不到、改不了的东西

| 能力 | 归属 | 样式为什么够不着 |
|---|---|---|
| 键盘层（`onKeyPress`、W3C 逐键） | 容器 | 挂在容器上；configuration 不含任何按键入口 |
| 行选择归约（单选替换 / 多选切换） | `TreeInteractionReducer` | configuration **不含任何闭包**；样式只读 `isSelected` |
| 三态勾选与级联 | 组件造的 `checkBox` 部件 | 行为封在 `AnyView` 里；样式只能摆放 |
| 焦点归约 / 焦点来源（键盘 vs 指针） | `TreeFocusing` | 样式只读 `isFocused` |
| 无障碍取值（"Expanded"/"Collapsed"、`.isSelected` trait、chevron 的动作 label） | 组件，施在样式 body **外层** | 外层 modifier，样式 body 在其内 |
| 命中区 | 组件：外层 `frame(minHeight: pitch)` + `contentShape(Rectangle())` + 点选手势 | 样式 body 在其内；样式不能把行缩到 `pitch` 以下 |
| 悬停检测 | 组件：外层 `onHover`，写容器级 `hoveredID` | 样式只读 `isHovered` |
| 右键菜单 | 组件：外层 `contextMenu`（§4） | 同上 |
| 行序、哪些行被构建 | 容器 `LazyVStack` + `ForEach(visibleRows)` | 逐行样式够不着行序 |

**明确否决 issue 草案里的「展开切换入口」**：configuration 不暴露 `toggleExpansion: () -> Void`。
一旦给了闭包，样式就能把它绑到整行点击上——那是**行为**（VS Code「单击文件夹行即展开」正是
这种行为），按公约《边界条款：样式不得携带行为》不能进样式协议。要这个行为，应在 `Tree` 上加
行为参数（§10 D5），而不是交给样式。放置由 `disclosure` 部件承担：样式决定它**在哪**，
组件决定它**做什么**。

样式**能**对部件做的外观调整：位置、`.tint(_:)`（chevron 取 `.tint`，源码读）、透明度。
样式**做得到但被契约禁止**的：对部件 `.hidden()` / `.allowsHitTesting(false)` / 不放置。
类型系统挡不住（Apple 的 `ButtonStyle` 同样挡不住样式丢掉 `label`），由文档注释写成「必须」，
由 §7.3 的判据兜住两个内置样式。

⚠️ **焦点指示由样式负责画**（`isFocused` 为真时必须可见）。理由：VS Code 的焦点指示（1px 内描边、
与选中色合并）和 `.automatic` 的焦点环长相完全不同，这正是样式要定制的东西。代价是第三方样式
可能漏画——登记为风险（§10 R4）。

### 2.4 内置样式外观

**`.automatic`**：`#422` 的 `TreeRowView` 修饰链**逐字搬进** `AutomaticTreeStyle.makeBody`，
只把三处写死的常量换成 `configuration.metrics`（`.regular` 下取值不变）：

`HStack(spacing: xs) { disclosure; checkBox; label }` → `.padding(.horizontal, xs)` →
`.frame(maxWidth: .infinity, alignment: .leading)` → `.frame(minHeight: metrics.rowHeight)` →
圆角 `CoreRadius.small` 选中底色 `accentSubtleBackground(from: coreAccent)` →
`.padding(.leading, (level - 1) × metrics.indentation)` → `.focusRing(visible: isFocused, cornerRadius: small)`。

**`.navigator`**（命名待拍板，§10 D6）：

| 部位 | 画法 |
|---|---|
| 选中 | 整行底色（含缩进区），直角；`accentSubtleBackground(from: coreAccent)` |
| 悬停 | 整行底色 `Color.surfaceCanvasSubtle`（与 `ListRow` 悬停同一 token，源码读）；选中优先于悬停 |
| 焦点 | `CoreBorderWidth.thin` 内描边，取 `coreAccent` |
| 缩进参考线 | 对每个祖先层 `k = 1 … level-1`，在 `x = (k-1) × indentation + disclosureWidth / 2` 画 `CoreBorderWidth.hairline` 竖线，色 `Color.borderSubtle`；上下各外溢 `rowSpacing / 2`，使 `.regular` 的 2pt 行间距处也连续 |
| chevron | `.tint(Color.contentSecondary)`（VS Code 的 twistie 是前景色，不是强调色） |
| 缩进 | 内容区左移 `(level - 1) × indentation`，但底色 / 悬停 / 焦点描边铺满整行 |

参考线用**视图**（`Rectangle` + leading padding）画，不用 `Canvas` / `Path` 的绝对坐标——
前者随 `layoutDirection` 自动镜像，后者在 RTL 下不翻转（推断，§7 有 RTL 判据兜）。

### 2.5 configuration 如何交出部件而不交出行为

- `disclosure`：组件构造 `TreeDisclosureControl(hasChildren:isExpanded:metrics:) { setExpansion }`，
  内含 `Button`、命中槽（宽 `disclosureWidth`、高 `pitch`）、旋转动效（`reveal.transformAnimation`，
  RM 下为 `nil`）、`accessibilityLabel`，然后 `AnyView` 包一层交出。
- `checkBox`：组件构造 `Toggle(sources:isOn:)` + `CheckBoxToggleStyle()` + `labelsHidden()`，
  内含 `notePointerCheck` 与级联写回，`AnyView` 交出。
- 部件内部读 `controlSize` 的只有 chevron 字号与槽宽，都取自组件算好的 `metrics`，
  不另读环境——避免样式对部件施 `.controlSize(_:)` 时部件与行度量分叉（推断）。

### 2.6 跨行的缩进参考线

逐行样式画跨行的线，靠的是**每一行各画自己那一段**：`level` 给出要画几根，`metrics` 给出每根的
x 与上下外溢量，行与行拼起来就是连续的竖线（P2 实测：展平后的行之间无额外缝隙，`rowSpacing`
就是全部缝隙）。

- VS Code 形态（直线）只需要 `level` + `metrics`。
- Ant Design `showLine` 形态（`├` / `└` 肘线）还需要「每个祖先是不是它那一层的最后一个」——
  祖先是最后一个 ⇒ 该列在本行不画竖线；本行自己是最后一个 ⇒ 画 `└` 而不是 `├`。
  这就是 `lineage: [TreeSiblingPosition]` 的用途。计算成本为零：展平遍历时本来就知道下标
  （`TreeFlatten.rows` 带上 `index == nodes.count - 1`）。
- 不暴露「祖先 ID 链」：样式不应知道 ID（configuration 非泛型，与 `BannerStyle` 同），
  且那会让样式有能力按数据分支，逼近「样式携带行为」。

## 3. 悬停

- **检测**：组件在每行外层挂 `onHover { hovering in hoveredID = hovering ? id : (hoveredID == id ? nil : hoveredID) }`，
  `hoveredID` 是**容器级** `@State`（不放在行里：`LazyVStack` 回收行时行级 `@State` 会丢，
  且容器级保证同一时刻至多一行悬停）。
- **平台**：macOS 鼠标；iPadOS 指针下 `onHover` 同样触发（推断，未实测，§7 登记为真 HID 项）；
  iPhone 纯触控下永不触发 ⇒ `isHovered` 恒为 false。不用 `.hoverEffect`：那是系统的抬升 / 高亮效果，
  会与样式自己画的悬停底色叠加。
- **动效与 Reduce Motion**：悬停高亮**即时生效、无补间**，三档 `MotionPresentation` 一致 ⇒
  没有需要按 RM 分支的动效。`hoveredID` 的写入不包 `withAnimation`；容器上既有的
  `.coreAnimation(.selection, value: selection)` 只绑 `selection`，悬停变化不触发它。
  这条「无补间」本身要有判据（§7.4），否则后来者给悬停加一个淡入就绕开了 RM。
- 行被折叠隐藏或从数据中删除时，`onChange(of: rows)` 里若 `hoveredID` 不在新可见行中则清空
  （避免重新出现时残留悬停态）。

## 4. 整行右键菜单

**定案：`Tree` 的 init 参数，不进 configuration。**

```swift
// Tree<Data, ID, RowContent, MenuItems: View>
public init(
    _ data: Data, id: …, children: …, expanded: …, selection: …,
    selectionMode: TreeSelectionMode = .single,
    checked: Binding<Set<ID>>? = nil,
    onActivate: ((ID) -> Void)? = nil,
    @ViewBuilder content: @escaping (Data.Element) -> RowContent,
    @ViewBuilder contextMenu: @escaping (Set<ID>) -> MenuItems
)
```

- `Tree` 增加第 4 个泛型参数：`Tree<Data, ID, RowContent, MenuItems: View>`；不带
  `contextMenu:` 的 init 放在 `where MenuItems == EmptyView` 的扩展里（`id:` 版与 `Identifiable`
  版各一对，共 4 个 init）。`Tree.expandedIDs` 的免泛型重载改为
  `where RowContent == EmptyView, MenuItems == EmptyView`，否则 `Tree.expandedIDs(…)` 推不出第 4 个参数。
- 调用形态：`Tree(…) { node in … } contextMenu: { targets in … }`（多尾随闭包，
  形状对齐 SwiftUI `Menu { } label: { }`）。
- **目标集合语义对齐 `contextMenu(forSelectionType:menu:primaryAction:)`**：右键行在当前选中集合里 ⇒
  目标 = 整个 `selection`；否则 ⇒ 目标 = `[该行 ID]`。纯函数
  `TreeContextMenu.targets(for:selection:) -> Set<ID>`，**不遍历树**（P3 实测 builder 随 body
  逐行求值，这里若求整树 ID 就把惰性毁了）。`selection` 里不属于本树的 ID 原样传出——集合是调用方的。
- 右键**不改**选中、焦点、交互来源（对齐 Finder / Xcode 的行为；VS Code 会给右键行画焦点框，
  本轮不做）。
- 挂在组件的行外层（与命中区同一层）⇒ 覆盖整行（含缩进区与 chevron 槽之外的空白），
  与样式无关，换样式不丢菜单。

不选「configuration 能力」的理由：菜单内容是**调用方的数据操作**（打开 / 删除 / 重命名），
不是外观；交给样式意味着样式要知道菜单内容、甚至决定挂不挂——同一棵树换个样式右键就没了，
违反《边界条款》。不选「环境值 + modifier」（`.treeRowContextMenu { }`）：环境值要类型擦除
`ID`，调用方在闭包里拿不到强类型集合。

⚠️ 文档注释要写明：builder 会在每个已构建的行上随 body 求值（P3 实测），闭包里不要做重活。
拖放：**仍 Out of Scope**（PRD 原文），本设计不为它预留任何字段。

## 5. `LazyVStack`

### 5.1 关键事实

- 惰性只作用于 `LazyVStack` 的**直接** `ForEach` 子项；`#422` 的结构是「根层 `ForEach` →
  `DisclosureGroup` → 嵌套 `TreeBranch`」，一个根节点下的整棵可见子树是**一个**子项
  ⇒ P2 实测 201 行全部构建。**不展平，换 `LazyVStack` 对 VS Code 形态（单根大目录）的收益为零。**
- 组件本来就在 body 里算 `visibleRows`（展平的可见行序列，键盘层用）——展平渲染不增加遍历。

### 5.2 结论：部分换——**展平渲染 + `LazyVStack`**，不再递归 `DisclosureGroup`

```
LazyVStack(alignment: .leading, spacing: metrics.rowSpacing) {
    ForEach(visibleRows) { row in  TreeRowHost(row) /* 组件外层 + AnyView(style.makeBody) */ }
}
```

逐项影响：

| 维度 | 影响 |
|---|---|
| 虚拟焦点 | **无**。焦点是容器状态里的 ID（ARIA activedescendant 形态），不依赖行视图存在；焦点落在未构建行上时，环在该行被构建时画出 |
| 递归 `DisclosureGroup` | **移除**。`TreeBranch` / `TreeNestedStyle` / `TreeDisclosureGroupStyle` 与 `TreeNestedStyleTests` 三条判据随之删除；它们防的「嵌套层样式被重置」问题不再存在 |
| `Group(subviews:)` | 现实现未使用，展平后也不需要 |
| 快照 / 位图判据 | `ImageRenderer` 下 `LazyVStack` 不在 `ScrollView` 里 ⇒ 全部行构建、尺寸与 `VStack` 相同（P1）；与 `VStack` 相比有 ≤1 LSB 的文字抗锯齿差（P2b），在现有 `noiseTolerance = 2` 内 |
| 展开动效 | 由「`DisclosureGroup` 内容整体插入」变为「若干行插入 `ForEach`」；两者都在 `withAnimation(treeExpansion)` 事务里。静态终态一致；在飞帧外观会不同（推断），`LazyVStack` 的插入动画偶有抖动的社区报告（未核实）——实现期看真机 |
| 键盘滚动跟随 | `#422` 已登记的缺口（Tree 不持有滚动容器）**不变**；`LazyVStack` 让「焦点移到未构建行」更常见，但不引入新错误。跟随滚动另开 issue（需要 `ScrollViewReader` 与宿主滚动容器的协作设计） |
| 不在 `ScrollView` 里用 | 退化成全量构建（P1），行为与今天相同 |
| 惰性判据 `TreeLazinessTests` | 读 `children` 的次数不变（展平本就只读可见行）；另加一条「300pt 视口只构建可见行」的构建计数判据 |

⚠️ 这一条**推翻 `#419` spike 选定的路径 A**（递归 `DisclosureGroup`）。spike 选 A 的理由是
「免费拿到受控展开 + 不必手写行布局 / 缩进 / 展开动画」；`#422` 落地后行布局、缩进、chevron、
展开态播报已全部自绘，展开动画也由组件 `withAnimation` 驱动，A 相对 C（完全自定义）的剩余收益
只有「`DisclosureGroup` 的内容插入过渡」一项。⇒ 需要用户拍板（§10 D1）。拍板为「不展平」时的
退路：保持 `VStack` + 递归，只做 §1–§4，`LazyVStack` 登记为「收益为零，不换」。

## 6. 兼容与迁移

### 6.1 `.automatic` 与 `#422` 像素一致——怎么判

- 把 `805f40f` 的 `TreeBranch` / `TreeRowView` / `TreeDisclosureControl` / `TreeDisclosureSlot` /
  `TreeDisclosureGroupStyle` / `TreeNestedStyle` **原样拷贝**进测试 target，改名 `Legacy422*`
  （PRD NFR「静态外观的像素判据对照原样拷贝的旧实现」）。拷贝件只依赖公开 token 与 `@testable` 的
  纯函数，不依赖会被本次改掉的内部类型。
- 在 `.regular` 下渲染夹具矩阵：{全折叠, 展开到第 3 层} × {无选中, 选中一个第 3 层行} ×
  {不传 `checked`, 父行 mixed} × {焦点环画在某行, 不画} × {light, dark} × {LTR, RTL}，
  新旧各渲一张。
- 判据：**尺寸完全相同**，且**逐通道最大偏差 ≤ `noiseTolerance`（2）**。不要求 0 字节：
  `LazyVStack` 与 `VStack` 之间实测有 1 LSB 文字抗锯齿差（P2b）。
- 权威腿是 **iOS**：复选框与选中色在 macOS native 腿上若落到那 198 个 catalog 常量会解析成透明
  （CLAUDE.md），两边一起透明会让「一致」空转。macOS 腿同样跑，但只当辅证。
- 焦点环一格要能构造「键盘交互后的焦点态」：走内部 init 直接喂 `isFocused`（旧拷贝喂
  `showsFocusRing`），不走合成按键。

### 6.2 行为变化（相对 `#422`，未发布）

`Tree` 尚未进 main（`docs/BREAKING-CHANGES.md` 里 `#422` 一节标「未发布（相对 `v0.11.0`）」，
源码读），所以以下全部**改写该未发布小节**，不另开「破坏性变更」小节：

1. `Tree` 的泛型参数 3 → 4（`MenuItems`）；显式写出 `Tree<[Node], String, Text>` 的代码要补
   `EmptyView`。`Tree.expandedIDs(…)` 免泛型写法不受影响（约束同步扩到两个参数）。
2. `Tree` 读 `controlSize`：祖先设了 `.controlSize(.small)` 的宿主，Tree 会变密（macOS 行距 22）。
3. **命中区扩到整行**：`#422` 的 `contentShape` 在缩进 padding 之内，缩进区点不中；现在组件在外层
   施 `contentShape`，缩进区也选中该行。像素不变，行为变。
4. 新增 `TreeStyle` / `TreeStyleConfiguration` / `TreeSiblingPosition` / `TreeRowMetrics` /
   `AutomaticTreeStyle` / `NavigatorTreeStyle` / `View.treeStyle(_:)`、`contextMenu:` 参数。
5. （若 D1 拍板展平）行不再是 `DisclosureGroup` 的 label；无障碍树结构可能变化——实现期用
   `axe describe-ui` 对照 `#422` 的读数（tree.md「行在无障碍树里不是一个元素」一段）。

### 6.3 登记表改判：prescriptive → 有扩展点（走修订回路）

公约《事后补写的效力边界》：翻转 `kind` / `decidedBy` **必须走修订回路**，不能只改 `notes`。
先例是 `OrbitingLogos`（`D-270-2` → 裁定 A → `R-49`，源码读）。本次落点：

1. `docs/contract-defects.md` 新增 `## #429` → `D-429-1`：`#422` 的步骤 2 把「缩进参考线」
   「悬停层」分箱为**装饰**，与三分法补充规则 1 冲突——
   - 缩进参考线承载**层级归属**（哪些行同属一个祖先），不是背景 / 描边式的纯装饰层；
   - Ant Design `showLine` 的肘线还承载**兄弟次序**（`└` = 最后一个子节点）；
   - 悬停层承载**指针目标**这一交互状态。
   ⇒ 按补充规则 1（看承不承载语义，不看自陈）与补充规则 4（含任一槽差异即整体计入非皮肤），
   VS Code Explorer（参考线 + 悬停）与 Ant Design `Tree showLine`（肘线）是两个**非皮肤**候选，
   各有具名来源 ⇒ 计入 ≥2 ⇒ **出口 1**。
   ⚠️ 同一条要写明**不推翻** `#422` 对三个「长相完全不同」形态（分栏浏览 / 逐级下钻 / 面包屑）的
   排除——那三者丢掉 `expanded: Set<ID>`、含义不同，排除理由仍成立。
2. `docs/component-contract.md`：在 J-2 定义域计数的现状注记处追加「`#429` 起 16 → 17」。
   ⚠️ J-2 **当前逐字是 16**（`ComponentExtensionPointGuard` 源码读）；公约正文里的「17」是
   `#312` 的历史记账，按 CLAUDE.md 不改，只追加现状注记。
3. `docs/component-contract-revisions.md` 新增 `R-50`（当前最后一条是 `R-49`，源码读）。
4. `docs/component-registry.json` 的 `Tree`：`kind: semantic`、`decidedBy: step2`、
   `needsExtensionPoint: true`、`customStyleProtocol: "TreeStyle"`、`nativeProtocol: null`
   （步骤 1 的否决理由原样保留：`DisclosureGroupStyle.Configuration` 承载不了两套状态与键盘层）；
   `notes` 重写，引 `D-429-1` / `R-50`。
5. `ComponentExtensionPointGuard`：逐项裁决 Tree **进入** J-2 定义域（semantic + needsExtensionPoint）⇒
   `inspected.count == 16` → `== 17`，名单加 `Tree`；另加正向断言
   `result.satisfied["Tree"]?.contains("TreeStyle") == true`（第四例 customStyleProtocol 通路）。
   `ComponentRegistryGuard` 的 OhMyDesign 条目数（58）**不变**——没有新组件条目：
   `AutomaticTreeStyle` / `NavigatorTreeStyle` 符合的是 `TreeStyle` 不是 `View`，不被扫成组件。
6. `QuotedEvidenceGuard`：registry notes 与 tree.md 逐字引用的 `content.disclosureGroupStyle(TreeDisclosureGroupStyle())`
   若随 D1 删除，这一行登记要连同 notes 一起改（否则判红）；其余四条引文所在的
   `TreeCore.swift` / `TreeInteraction.swift` 不动。
7. 「更正传播」三处：源码文档注释、`docs/components/tree.md`（「判定法」一节整段改写、「外观」一节
   改为推导表 + 两个内置样式、新增「样式」「右键菜单」两节）、registry `notes`。改完 grep
   「规定性」「不给扩展点」「prescriptive」「CoreSpacing.md」「height(for: .regular)」在三处的残留。

⚠️ **这次改判不是板上钉钉**：参考线「承载层级归属」这个论证可以被反驳为「与缩进冗余编码，
缩进已经承载了层级」。若评审认定参考线仍属装饰，按公约它落**步骤 4 tiebreaker ⇒ prescriptive ⇒
形态 C 不给扩展点**，`TreeStyle` 就与公约冲突。见 §10 D2。

### 6.4 PRD FR-2 修订点

`.claude/prds/timeline-tree-action-buttons.md`：

1. FR-2 能力范围追加一条「**密度与样式扩展点**」：读 `controlSize`（推导表见本 spec §1.2）、
   `TreeStyle` 协议（逐行、configuration 无闭包）、内置 `.automatic` / `.navigator`、
   整行右键菜单（`contextMenu:` 参数、目标集合语义对齐 `contextMenu(forSelectionType:)`）。
2. FR-2 开头「用户已定案：**自己递归** + 每节点展开绑定」——若 D1 拍板展平，改为「每节点展开绑定；
   渲染按可见行展平」，并注明推翻 FR-2a 选定的路径 A 的理由（§5.2）。
3. NFR 的 J-2 计数句「当前写 `== 16`」追加「`#429` 起 17」。
4. Out of Scope 不变（拖拽重排、懒加载子节点、`F2`、type-ahead）；视 D5 追加「单击父行即展开」。

## 7. 判据计划

纪律：判据能被变异打红；**变异不照判据的形状构造**（改的是一个真实会犯的错，而不是把判据
读的那个常量改掉）；每次变异先 `git diff` 确认落到了文件里，再跑判据。

### 7.1 密度

| 判据 | 腿 | 形式 |
|---|---|---|
| `TreeRowMetrics` 五档取值 | 双腿 | 纯函数；`.regular` 一列逐项等于 `#422` 现值（兼容锚点）；五档单调不减；`.small` 视觉行高 = 22 |
| 渲染行距 = `metrics.rowHeight` | **macOS** | 单叶节点 Tree 在五档下的渲染高度（扣除夹具 padding）逐档等于表值（macOS 无下限） |
| 渲染缩进 = `metrics.indentation` | 双腿 | 两层树、行内容是纯色块：量父子两行色块左缘的列差（位图），`.small` 与 `.regular` 各一次 |
| iOS 触控目标 | **iOS** | `TouchTargetTests` 两条改成对 `ControlSize.allCases` 参数化：行高、chevron 槽高都 ≥ 44 |

计划中的变异：

- **只改了行、忘了改 chevron 槽**（`TreeDisclosureSlot` 仍写死 `height(for: .regular)`）——这是
  真实会漏的第二落点；预期 macOS `.small` 渲染高度判据红（44 ≠ 22）。
- **平台下限写反**（`#if os(macOS)` 施 44）——预期 iOS 触控目标判据红、macOS 行距判据红。
- **缩进从 `metrics` 取错档**（样式里写 `CoreSpacing.md`）——预期 `.small` 缩进位图判据红。

### 7.2 `.automatic` 像素一致

§6.1 的矩阵。变异：选中块圆角换 `CoreRadius.medium`；把 `.padding(.leading)` 挪到背景之前
（选中块铺进缩进区）；展平改成层序遍历（广度优先）。预期各自至少一格红；层序那条还应打红键盘判据。

### 7.3 「自定义样式下行为与 `.automatic` 一致」

1. **测试用对抗样式** `HostileTreeStyle`（测试 target 内）：把 `checkBox` 放最前、`disclosure` 放最后、
   不缩进、不画选中态、不画焦点。它是「合法但一切外观都反着来」的样式。
2. `TreeHostedWiringTests`（macOS 托管窗口 + 合成事件）的既有判据改成对
   `[.automatic, .navigator, HostileTreeStyle()]` 参数化：按键写回宿主绑定（首键解析焦点、`↓` 移焦、
   `Space` 选中）、点 chevron 展开、点复选框勾选、点行选中——三种样式下绑定终态逐项相等。
   点击坐标不能写死（对抗样式把 chevron 挪到了行尾）：组件的 `disclosure` / `checkBox` 部件内部各发一个
   internal 的锚点 preference，测试据此取中心点。
3. 无障碍取值：三种样式下行的 `accessibilityValue` / trait 相同——在 iOS 腿用既有的无障碍读取方式
   （若托管环境读不到，登记为真 HID 探针项，不装作有判据）。
4. **结构判据**：`Mirror(reflecting: configuration).children` 中没有函数类型的字段。

变异：把 `.onTapGesture` 从组件外层挪进 `AutomaticTreeStyle.makeBody`（行为被样式携带）——
预期对抗样式那一格的「点行选中」红；给 configuration 加 `let toggleExpansion: () -> Void`
（issue 草案里的「展开切换入口」）——预期结构判据红。

⚠️ 合成事件测的是「三种样式下同一套接线是否等价」这一**相对**命题，不证明平台真实行为
（memory：合成事件测不出平台行为）。真 HID 复测沿用 `.claude/epics/structure-components/422-probe`。

### 7.4 悬停与 Reduce Motion

| 判据 | 形式 |
|---|---|
| `.navigator` 悬停 / 未悬停两张图不同；选中 + 悬停 与 仅选中 相同 | 位图（内部 init 直接喂 `isHovered`） |
| 悬停写入不带曲线 | 托管窗口里经内部入口改 `hoveredID`，捕获事务：三档 `MotionPresentation` 下 `animation == nil` |
| 行隐藏后悬停清空 | 纯归约（`rowsChanged` 带上 `hoveredID`） |
| `onHover` 真的接到 `hoveredID` | **不在 CI**：托管窗口不是 key window，合成 `mouseMoved` 能否触发 tracking area 未验证 ⇒ 先试，失败则登记为真 HID 探针项 |

变异：`hoveredID = …` 包进 `withAnimation(CoreMotionToken.selection.animation)`（看似无害的「加个淡入」）——
预期「悬停写入不带曲线」在 `.animated` 档红。
Reduce Motion 台账：Tree 仍登记 `gated`；chevron 旋转、展开曲线两个调用点不变。

### 7.5 缩进参考线

| 判据 | 形式 |
|---|---|
| `lineage` 正确 | 纯函数：夹具每一可见行的 `lineage` 逐项对表（含根层最后一个、中间层最后一个） |
| 参考线跨行连续 | 位图：`.regular`（有 2pt 行间距）下，参考线所在列从父行下缘到最后一个子行下缘逐像素非背景 |
| 参考线根数 = `level - 1` | 位图：第 3 层行在参考线列位置上恰有 2 列非背景 |
| RTL 镜像 | 位图：行内容用纯色块（无文字），RTL 图 = LTR 图水平翻转（≤ 噪声） |

变异：去掉上下外溢（行间距处断开）——预期「跨行连续」红；参考线循环写成 `1...level`（多画一根）——
预期「根数」红；用 `Path` 按绝对 x 画——预期 RTL 判据红。

### 7.6 右键菜单

| 判据 | 形式 |
|---|---|
| 目标集合 | 纯函数 `targets(for:selection:)`：在选中集里 → 整个 selection；不在 → 单元素；selection 含树外 ID 原样传出 |
| 接线 | 渲染时捕获 builder 的实参（P3 实测 builder 随 body 求值）：每个已构建行各收到一次正确的目标集合 |
| 不遍历树 | 沿用 `TreeLazinessTests` 的 `children` 读取计数：带 `contextMenu` 渲染时折叠子树读取次数仍为 0 |
| 右键不改状态 | 纯函数层无状态写入；视图层登记为真 HID 项 |

变异：目标集合写成 `selection.union([id])`（右键未选中行时把它并进旧选中集——一个很像「对齐 Finder」
的错误）——预期目标集合判据红；目标集合里调 `treeIDs` 过滤——预期惰性判据红。

### 7.7 `LazyVStack`

- 构建计数：`ScrollView` 300pt 视口、200 个子节点的展开父节点，构建的行数 < 20（P2 实测 7）。
- 变异：容器换回 `VStack`——预期红；保留 `LazyVStack` 但恢复根层 `DisclosureGroup` 嵌套——预期红（P2 实测 201）。

### 7.8 六条强制检查

macOS `swift test`（读 `Test run with N tests` 总数，不数逐条行）、iOS `xcodebuild -scheme OhMyDesign-Package`
（`.xcresult` **顶层** `passedTests`）、预览宿主（按 CLAUDE.md 核 `Debug-iphonesimulator` +
`Compiling ComponentData.swift` + `in target 'OhMyDesignPreview'` 步数非 0）、`scripts/downstream-probe`
（新增一处 `.treeStyle(.navigator)` + `contextMenu:` 的调用）、MainActor 棘轮（静态快捷成员已 `nonisolated`，
预期无新增豁免）、`design-digest.py`。快照：画廊新增 VS Code 示例后按 `scripts/run-snapshots.sh` 重生成
`docs/snapshots/OhMyDesignPreview_Previews.swift_Tree.{png,json}`。

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
            } contextMenu: { targets in
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

macOS 上：行距 22、缩进 11、chevron 12pt 中性色、整行选中 / 悬停、参考线连续、右键作用于选中集或单行。
iOS 上：同一份代码行距 44（§1.3），其余一致。
与 VS Code 仍有的差距（均属后续加法或行为参数，不在本轮）：单击文件夹行展开（D5）、双击打开、
树失焦时选中色变淡、参考线只在悬停整棵树时显示、活动参考线高亮、右键行画焦点框。

## 9. 被否决的替代方案

1. **只读 `controlSize`、不给样式**。密度解决了行高，但整行选中、悬停高亮、缩进参考线都是**画法**，
   写死在组件里就只有一种；用户要的 VS Code 形态与 `.automatic` 在这三处都不同。
   且 §6.3 论证了参考线 / 悬停是非皮肤候选 ⇒ 公约要求给扩展点。
2. **`rowStyle:` 闭包（外观槽，形态 D1）而非协议**。D1 的成立条件是「一个外观槽完整承载外观差异」；
   这里差异分布在多处（选中底色的铺设范围、缩进区的参考线、焦点指示、chevron 着色、缩进由谁施加）
   ——一个槽装不下，拆成多个槽就是一个没有名字的协议。另外槽是逐实例参数，不能像
   `.treeStyle(_:)` 那样对整个子树（整个 app 的侧栏）生效。公约优先序 B > D 在「需要第三方开放扩展」时
   明确选 B。D2（配置枚举）同样不成立：候选空间是开放的（VS Code 直线、Ant 肘线、Fluent 尺寸变体…），
   封闭枚举装不下（公约《D2 的边界》）。
3. **系统 `List` / `OutlineGroup` + `.listStyle`**。`ListStyle` 没有公开的 `makeBody` 定制点
   （第三方写不出新样式，只能在 `.sidebar` / `.plain` / `.inset` 里挑）；`OutlineGroup` 的 8 个 public init
   无一带展开态（`#419` spike 查 swiftinterface）；`List(selection:)` 在 iOS 26 上给 0 键盘、不能嵌进
   `ScrollView`（同一 spike）。三条各自足以否决。
4. **整树样式**（`makeBody` 拿到全部行）。见 §2.1 第 1、2 条：样式能改行序就能打乱键盘坐标系，
   惰性也被样式左右。
5. **configuration 交出行为闭包**（Apple `DisclosureGroupStyle` 给 `$isExpanded` 的做法）。
   Apple 的做法让样式实现者负责展开交互；本仓公约《边界条款》明令样式不携带行为，
   且 `#422` 的展开要经归约（写交互来源、带环境动效档），直接写 binding 会绕过它。
6. **焦点指示由组件统一画、样式不管**。VS Code 与 `.automatic` 的焦点指示长相不同，统一画就复刻不了；
   代价（第三方样式可能漏画）登记为 R4。

## 10. 需要用户拍板 / 风险 / 未决

### 需要拍板

- **D1 展平渲染（推翻 `#419` 路径 A）**：推荐展平 + `LazyVStack`（§5.2）。不展平则 `LazyVStack`
  收益为零（P2 实测），应登记「不换」。
- **D2 公约改判的论证**：推荐按 §6.3 走修订回路（参考线承载层级归属、肘线承载兄弟次序、
  悬停承载指针目标 ⇒ 槽）。若你认为参考线只是冗余编码、属装饰，则 Tree 按公约应落 tiebreaker /
  形态 C，本 issue 的 `TreeStyle` 需要另立公约修订（例如「用户明确产品需求可越过判定法」一条），
  那是更大的口子，不推荐。
- **D3 iOS 紧凑档仍守 44pt 行距**：推荐守（§1.3 几何论证）。若要 iOS 也 22pt，只能放弃 44pt 触控下限
  （`TouchTargetTests` 改成仅 `.regular` 及以上），HIG 不支持。
- **D4 `.automatic` 也跟随 `controlSize`**：推荐跟随（按钮惯例，且 Tree 未发布）。代价是宿主祖先设了
  `.controlSize(.small)` 时默认外观会变密。
- **D5 「单击文件夹行即展开」**：这是行为，推荐**不进本 issue**；若要，另开 issue 在 `Tree` 上加行为枚举参数
  （不是 Bool、不是样式）。
- **D6 内置第二样式的名字**：候选 `.navigator`（推荐，Xcode 对该区域的叫法，不带品牌）/ `.outline` /
  `.lined`。不用 `.compact`：密度由 `controlSize` 负责，名字不应与之混淆。

### 风险

- **R1** 展平后无障碍树结构可能变化（`DisclosureGroup` 是否贡献过容器语义未知）——实现期 `axe describe-ui`
  对照 `#422` 读数。
- **R2** `LazyVStack` 的插入 / 删除动画在展开折叠时的在飞帧质量未测；静态终态有判据，在飞帧只能人工看。
- **R3** 复选框（`CheckBoxToggleStyle`）不读 `controlSize`（源码读：`Components/CheckBox/` 无 `controlSize`），
  macOS `.small` 带复选框的行可能被撑高于 22。本轮不改 CheckBox，登记；密度判据用不带复选框的夹具，
  另加一条「带复选框时行距 ≥ 表值」如实描述。
- **R4** 焦点指示由样式画，第三方样式可能漏画；类型系统挡不住，只有文档注释 + 内置样式判据。
- **R5** `onHover` 的接线（尤其 iPadOS 指针）不在 CI；合成 `mouseMoved` 在非 key 托管窗口是否触发未知。
- **R6** `contextMenu` builder 随 body 逐行求值（P3 实测）——调用方在闭包里做重活会拖慢滚动；只能靠文档。
- **R7** `#423`（搜索高亮）改同一批文件，且要往行里加命中高亮；本 issue 的行宿主重构后 `#423` 需要 rebase，
  命中高亮应落在 `label` 内（调用方内容侧）还是 configuration 新字段，由 `#423` 定。
- **R8** 本 spec 的全部探针只在 macOS 跑过；iOS 腿上 `LazyVStack` / `ImageRenderer` / `contextMenu` 的行为是推断。

### 未决（可后续加法，不阻塞本轮）

- configuration 加 `isTreeFocused`（失焦选中色）、`isTreeHovered`（参考线仅悬停显示）、活动参考线。
- 双击激活（`onActivate` 的指针入口）；右键行的焦点框。
- 键盘焦点跟随滚动（需要滚动容器协作，另开 issue）。
- `disclosure` 的字形替换（如 Ant 的 +/− 方块）：需要一个「只换字形不换行为」的入口，本轮不开。
