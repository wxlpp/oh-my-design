# Breaking Changes

破坏性变更按版本 / Issue 记录在此，下游升级前请对照。

> 已发布的 git tag：`v0.1.0`（2026-07-19）、`v0.2.0`（2026-07-21）、`v0.3.0`（2026-07-23）、
> `v0.4.0`（2026-07-24，Phase 2 新组件）、`v0.4.1`（2026-07-24，非破坏性收尾）、
> `v0.5.0`（2026-07-24，文本入参统一——含破坏性变更）、
> `v0.6.0`（2026-07-25，Separator.Inset 改名 + ProgressBar 弃用 + SettingsRowMetrics 公开——含破坏性变更）、
> `v0.7.0`（2026-07-27，`semi-mobile-components` epic 10 新组件 + ProgressIndicator 增强/spinning + 收口的取色修正——纯新增，无破坏性变更）、
> `v0.8.0`（2026-08-16，`component-contract` epic：把 5 组压扁成 Bool 的 API 还原成语义类型——**含破坏性变更**）、
> `v0.9.0`（2026-09-01，形态 D2 扩展点落地（`#59` / `#60` / `#64` / `#65`）+ 守卫（`#48`）+
> 可达类型登记表（`#72` / `#216`）：7 个已有 init / modifier 各加一个带默认值的形态参数
> ——**对已应用调用点零影响，但对未应用的函数引用是破坏性变更**）。
> `v0.10.0`（2026-09-09，仓库与模块改名为 OhMyDesign + 设计系统配色 / 样式回灌 +
> `NetworkGraph` 布局扩展点（`#312`）+ 删除 `SurfaceKind.overlay`（`#238`）+ NFR-7 能耗策略表
> 下沉（`#271`）+ 画廊场景化配色 + `coredesign-leftover-closeout` epic（`#220`）
> ——**含破坏性变更，所有 `import` 都要改**；本版共 7 个章节，见下）。
> `v0.11.0`（2026-09-22，`heroui-absorption` epic（`#372`）：`FormField` / `TagGroup` / `anchoredBadge` / `.coreCircular` / 按压样式 / `coreSheetPresentation` 等新增，Toast / Banner / `StatusLevel` / 尺寸体系 / surface 层级增强 + 移除 `Sidebar` / `BottomInputBar` + `coreAccent` on-accent 通路（`#357`）+ 五组件布局扩展点（`#312`）+ `ui-followups` epic（`#397`）——**含破坏性变更**；本版共 11 个章节，见下）。
> ⚠️ 本清单**失真过两次**：早期版本写「本库当前无外部版本 tag」（`v0.1.0` 之前成立、之后未同步）；
> 随后又停在 `v0.8.0`、漏了已发布的 `v0.9.0`（#240）。⇒ **发 tag 时同步本行与对应章节是同一个动作**，
> 只补一行 tag 而不补章节，会让「清单完整」这个表象更具误导性。

## 未发布（相对 `v0.11.0`）——Issue #420：Timeline 组合式 API

本节随 `#420` 的 4 个 PR 逐步追加。

### PR 1：容器级布局与横向连线（公开签名不变）

`Timeline(items:layout:)` / `TimelineItem` 的签名一个都没变；变的是渲染：

| 变化 | 影响 |
|---|---|
| `.horizontal` 画节点间连线 | 原来横向节点之间是空白，现在横轴上有一条 `dividerDefault`、`CoreBorderWidth.thin` 的连线（从前一节点盒右沿到后一节点盒左沿）。含 `.horizontal` 的快照会变 |
| 大于 24pt 的自定义节点撑宽节点列 / 撑高本行 | 原来节点方框固定 24×24、不裁剪，大节点溢出、侵入上一行、被连线穿过；现在节点盒取节点报告尺寸（下限 24），节点列宽取最宽节点，行高与连线端点按节点盒实际边沿算。≤ 24×24 的节点外观不变 |
| 内容高 < 16pt 的非末行变高 | 行高由 `max(24, 内容高 + lg)` 改为 `max(盒高 + CoreSpacing.sm, 内容高 + CoreSpacing.lg)`，保证节点下方至少留 8pt 连线；内容高 ≥ 16pt 时不变；更矮的内容行多出 `min(8, 16 − 内容高)`（0–8pt；内容高 10 的行由 26pt 变 32pt）。⚠️ macOS 上 `.coreFont(.callout)` 单行文字的行高不到 16pt，这类行也会变高 |
| `.alternate` 固定宽的超宽内容改为向外溢出 | 两侧内容照旧收到槽宽提议：文字照旧按槽宽换行、落在槽内（与原来相同）。按槽宽排版后仍宽于槽的**固定宽**元素（如 `.frame(width: 220)`、`.fixedSize()` 文字）：左槽原来向右溢出、盖住中轴上的节点，现在向左（远离中轴）溢出，节点与连线不被遮挡，但越出容器的部分会被屏幕 / `ScrollView` 裁掉；右槽本来就向外溢出，不变。需要完整显示的宽元素请改成可换行 / 可收缩的内容 |
| `content:` 里并列的多个视图统一竖排、左对齐、无间距 | 现在包在一个 `VStack(alignment: .leading, spacing: 0)` 里，三种布局一致。原来按布局各不相同：`.vertical` 被展平进行里的 `HStack`，左右并排；`.horizontal` 已是竖排，但彼此隔 `CoreSpacing.sm`、逐个居中；`.alternate` 整行不显示（旧布局只接受恰好 3 个子视图）。要并排请自己写 `HStack` |
| 空节点 / 多视图节点 | 现在：`node:` 闭包什么都不产出（如 `if` 不成立）时保留 24pt 空盒、内容与其他行对齐，该行上下的连线在空盒处断开 24pt；`node:` 里并列多个视图时叠在同一个节点盒里居中。原来按布局各不相同：`.vertical` 空节点整格消失、内容左移到节点列，多视图节点拆成并排的多个 24pt 格；`.horizontal` 多视图节点竖直堆叠成多个 24pt 格；`.alternate` 两种情况都整行不显示 |
| `TimelineLayout` 标为 `nonisolated` | 可在非主 actor 语境里取用、比较；对已有调用点无影响 |

### PR 2：组合式 API（**破坏性**）

**移除**：`Timeline(items:layout:)`、数据载体 `struct TimelineItem: Identifiable` 及其两个 init（`id:status:content:` /
`id:status:node:content:`）、`id:` 参数。旧写法编译失败（`[TimelineItem]` 不再是合法类型：`TimelineItem` 现为泛型 `View`），不会静默换义。

**新增**：

| 符号 | 说明 |
|---|---|
| `Timeline<Content: View>` | `init(layout: TimelineLayout = .vertical, @ViewBuilder content: () -> Content)` |
| `TimelineItem<Node: View, Content: View>: View` | 四个 init：`(step:status:content:)`、`(step:status:node:content:)`、`(_:time:description:step:status:content:)`、`(_:time:description:step:status:node:content:)`；`title` / `description` 为 `LocalizedStringKey`，`time` 为 `Text?`，`step: Int? = nil` |

**迁移**（机械）：

```swift
// 之前
Timeline(items: [
    TimelineItem(status: .success) { Text("审核通过") },
    TimelineItem(status: .info) { Image(systemName: "star") } content: { Text("自定义") },
], layout: .alternate)

// 之后：数组 → @ViewBuilder，去掉逗号与 id:
Timeline(layout: .alternate) {
    TimelineItem(status: .success) { Text("审核通过") }
    TimelineItem { Image(systemName: "star") } content: { Text("自定义") }   // 自定义节点不写 status 就不播报
}
```

数据驱动时用 `ForEach(items) { item in TimelineItem(…) }`；存成属性的 `[TimelineItem]` 改成 `@ViewBuilder` 计算属性。

**可见 / 可听的行为变化**：

| 变化 | 影响 |
|---|---|
| 施在行上的修饰对节点与内容**各施一次** | 行的 body 产出节点、内容两个子视图。**布局**（`.padding` / `.frame` / `.offset`）：节点盒与内容各加一次，节点盒变大会撑宽整列（`.padding(10)` 让节点盒 24→44）——写进 `content:`。**视觉**（`.opacity` / `.background` / `.redacted` / `.transition` / `.accessibilityHidden`）：节点与内容一起生效（原来碰不到节点），`.background` 会铺成两块。**行为**（`.onAppear` / `.task` / `.onTapGesture` / `.contextMenu` / `.swipeActions`）：**挂两次**，`.onAppear` / `.task` **执行两次**——勿施在行上，写进 `content:` 或施在 `Timeline` 外层 |
| 整行包 `Button` 不受支持 | `Button { … } label: { TimelineItem(…) }` 对容器是非行子视图：节点与内容竖叠、没有节点列、连线着色跳过它，点击区域覆盖节点。可点击的部分请把 `Button` / `NavigationLink` 放进 `content:` |
| 被包进 `VStack` 等容器的行 | 降级为非行子视图，节点与内容仍可见（各布局下的样子见 `docs/components/timeline.md`） |
| 默认圆点不再是无障碍元素 | 原来是一个独立的 10×10 元素（`label='Info'`，与内容分离；`.horizontal` 下五个状态元素排在五条内容之前）。现在圆点隐藏，状态作为值挂在行上：有标题的行挂**标题元素**，无标题的行挂**合并后的内容元素**（内容 `.accessibilityElement(children: .combine)`，内容里的按钮改走「操作」转子） |
| `.grouped` 有标题的行改挂标题元素 | 原来 `.grouped` 的内容一律合并成一个元素、值挂在上面；现在有标题的行值挂在标题上，时间、描述各自可聚焦。无标题的行不变 |
| 写了 `status:` 的自定义节点行新增状态播报 | 原来自定义节点行的 `status` 从不播报；现在自定义节点的 init 里 `status` 改为 `StatusLevel? = nil`，**传了才播报**（挂载点同上）。迁移时保留了 `status:` 的行会多读一个状态值；节点里自带 label 的图标请 `.accessibilityHidden(true)`，否则同一状态读两遍 |
| `.grouped` 下自定义节点、无标题、不传 `status` 的行不再合并 | 原来 `.grouped` 对所有行的内容合并成一个元素；现在只有带状态值的无标题行合并 |
| `.horizontal` 有标题的行按列读 | 有标题的行的内容在 `.horizontal` 下是一个 `.contain` 容器：VoiceOver 读完本列标题 → 时间 → 描述再到下一列（不加时是先读完各列标题、再读各列时间） |
| `content:` 多视图竖排、间距 0 | PR 1 起已生效，组合式 API 下不变 |

## 未发布（相对 `v0.11.0`）——Issue #422：新增 `Tree`

**纯新增，不是破坏。** 已有公开符号一个都没变。新增的公开符号：

| 符号 | 说明 |
|---|---|
| `Tree<Data, ID, RowContent>` | 层级树组件：`init(_:id:children:expanded:selection:selectionMode:checked:onActivate:content:)`，另有 `Data.Element: Identifiable` 时省略 `id:` 的便利 init |
| `TreeSelectionMode` | 行选择模式枚举：`.single` / `.multiple`（`nonisolated`、`Hashable`、`Sendable`、`CaseIterable`） |
| `Tree.expandedIDs(_:id:children:toDepth:)` | `nonisolated` 静态函数，预算「默认展开到第 N 层」的集合（**根为第 1 层**）；两个同名重载：主类型上一个，`where RowContent == EmptyView` 的扩展上一个（调用处可写 `Tree.expandedIDs(...)` 不带泛型） |
| `TreeStyle`（`#429`） | `Tree` 的行外观预设，**封闭配置**（`public struct`，无公开 init / 属性 / `Equatable`）：`nonisolated` 静态成员 `.automatic`（默认）/ `.navigator`（整行选中、悬停、缩进参考线、中性色 chevron） |
| `View.treeStyle(_:)`（`#429`） | 为子树中的所有 `Tree` 设置行外观。**只写 `.treeStyle(.navigator)` 形态**；不要写 `TreeStyle.navigator`、不要把 `TreeStyle` 存成属性——将来升协议时这两种写法编译不过 |
| `Tree.rowContextMenu(_:)`（`#429`） | builder 方法，为整行（含缩进区）挂右键菜单，返回改了这一项的同一棵树；`Tree` 仍是三个泛型参数。菜单以目标 ID 集合生成：右键的行已选中时为「选中 ∩ 当前可见行」，否则只是这一行。不调用时不挂菜单 |
| `Tree.searchFilter(_:text:)`（`#423`） | builder 方法，按调用方持有的搜索词过滤行：留下命中 ∪ 祖先 ∪ 后代，临时展开到每个命中；搜索期间的展开 / 折叠不写 `expanded`，搜索词为空（去首尾空白后）即恢复。匹配规则固定：不区分大小写 / 变音符 / 全半角的子串 |
| `Tree.searchMatches(_:id:children:query:text:)`（`#423`） | `nonisolated` 静态函数，返回搜索词**直接命中**的节点 ID，与 `searchFilter` 同一实现；供宿主算命中数、显示空态、播报结果数。`where RowContent == EmptyView` 上另有免写行内容泛型的同名重载（与 `expandedIDs` 同形） |
| `Text.init(verbatim:highlighting:)`（`#423`） | 以原文显示并高亮与搜索词匹配的片段（加粗 + `searchMatchBackground` 底色），与 `searchFilter` 同一条匹配规则；仅当传入相同的搜索词与文案时片段与过滤一致 |
| `Color.searchMatchBackground` / `Color.systemYellow`（`#423`） | 搜索命中底色（第 3 层，系统黄 × 0.35，暗色 × 0.20）与它的第 2 层来源（桥接 `UIColor` / `NSColor.systemYellow`） |
| `TreeRowClickBehavior`（`#431`） | 单击父行的行为枚举：`.select`（默认，只选中）/ `.selectAndToggleExpansion`（选中并取反展开态）（`nonisolated`、`Hashable`、`Sendable`、`CaseIterable`） |
| `Tree.rowClickBehavior(_:)`（`#431`） | builder 方法，设置单击父行的行为，返回改了这一项的同一棵树。不调用时与此前相同（`.select`） |

模块 `Localizable.strings` 新增两个 key：`"Expand"` / `"Collapse"`（chevron 的无障碍标签，说的是动作）。
`#423` 再加一个：`"Applies to filtered results only"`（搜索期间父行复选框的无障碍提示）。
`"Expanded"` / `"Collapsed"` 此前已由 `CoreDisclosureGroupStyle` 登记，本次复用。

**下游要改什么：通常不用改。** 唯一可能碰到的是**类型名歧义**：下游自己的模块（或它依赖的另一个库）
若也声明了名为 `Tree` 的类型，同时 `import OhMyDesign` 的文件里裸写 `Tree` 会报
`'Tree' is ambiguous for type lookup`。改成模块限定名（`OhMyDesign.Tree` 或 `MyModule.Tree`）即可。
`TreeSelectionMode` 同理，但名字更少见。

**行为（`#429`，同属本未发布小节）：`Tree` 读环境 `controlSize`。** 宿主祖先设了 `.controlSize(.small)`
（或 `.mini` / `.large` / `.extraLarge`）时，Tree 的行距、缩进、chevron 与复选框字形随档位变化
（macOS `.small` 行距 22；iOS 各档行距保底 44）；默认 `.regular` 与此前逐项相同。推导表见 tree.md「外观」。
`CheckBoxToggleStyle` 的公开行为不变。

**行为（`#429`）：命中区扩到整行。** 此前点选区在缩进之内，点缩进区不选中；现在缩进区也选中该行。
默认外观 `.automatic` 的像素不变（与此前逐像素对照过），**RTL 下展开态的 chevron 除外**（见下条修正）。

**修正（`#429`）：RTL 下展开态的 chevron 朝上。** `#422` 在 RTL 下把旋转角取成 -90°，与系统对字形和旋转的
RTL 镜像叠加后展开态画成朝上；现在两种书写方向都转 90°，RTL 下展开态朝下。

**行为（`#429`）：展平渲染 + `LazyVStack`，行不再是 `DisclosureGroup` 的 label。** 可见行按深度优先展平成一列，
放在 `ScrollView` 里时只构建视口附近的行。静态外观与此前逐像素相同（两条腿、128 格矩阵、偏差 0）。
iOS 的无障碍树有四处变化（iOS `axe describe-ui` 前后对照，详见 tree.md「无障碍与触控」；**macOS 未对照**）：
视口外的行**不再出现在无障碍树里**，滚进视口才出现；每棵树多一个匿名分组容器；父行复选框的元素类型从
`Button` 变为 `CheckBox`（与叶行一致）；放在 `ScrollView` 里时行内容里 `Label` 的图标成为独立的图像元素。
其余元素的类型、label、value、位置不变（同为 iOS 读数）。**下游要改什么：不用改**（公开 API 不变）；依赖「整棵树的行都在无障碍树里」
的 UI 测试需先把目标行滚进视口。

**新增行为（`#423`）：搜索过滤。** 只在调用了 `searchFilter(_:text:)` 且搜索词非空时生效，其余情况与此前相同。
搜索期间键盘、`Cmd/Ctrl+A`、右键菜单与焦点只作用于可见行；**父行复选框的三态仍按全部叶后代显示，点击只勾选 / 取消
被过滤保留的叶后代**（按「保留的叶子是否全勾」翻转，范围外的勾选值不变；不搜索时仍级联全部叶后代）。无结果时不画任何行、
不显示空态（宿主用 `searchMatches` 判空）。**下游要改什么：不用改。** 可能碰到的是**名字歧义**：下游若自己给 `Color` 扩展了
`systemYellow` / `searchMatchBackground`，或给 `Text` 扩展了同签名的 `init(verbatim:highlighting:)`，会报重复声明或歧义，
改名或用模块限定即可。

**新增行为（`#431`）：单击父行可同时展开 / 折叠。** 只在调用了 `.rowClickBehavior(.selectAndToggleExpansion)` 时生效：
单击父行（行内容或缩进区）选中该行，**另外**取反该行的展开态。`.single` 下再点已选中的父行是「保持选中 + 切换展开」
（VS Code 式）；`.multiple` 下仍按逐行切换移出选中、展开态照样取反。叶行与 `.select` 下再点已选中的行仍取消选中。
chevron、复选框、叶行与键盘不受影响；行内容里调用方自己的 `Button` 等控件先接到点击（`Link` 未测），不选中也不切换展开；
搜索期间的展开只写临时 overlay、不写 `expanded`。开启后父行带无障碍提示 "Activate to expand or collapse"。
**行为（`#431`，所有调用方）：** 单击行与点 chevron 改为按点击当时的展开态归约（数据与搜索词仍取渲染时的值）——
折叠动画期间点到正在淡出的行或它的 chevron，这一击什么都不改，也不把键盘焦点拿进树。
此前按该行渲染时的快照归约，会选中这个已不可见的行（按代码推断，`.select` 下未实测）；`.selectAndToggleExpansion` 下
按快照归约还会把旧展开态写回，搜索期间实测刚折叠的父行被重新展开——本次一并避开。**下游要改什么：不用改。**
可能碰到的是**类型名歧义**：下游若也声明了 `TreeRowClickBehavior`，同 `Tree` 一条的处置。

行为契约（两套独立状态、键盘表、Reduce Motion 取值、搜索过滤、单击父行、已知缺口 `#427` / `#428`）见
[tree.md](components/tree.md)。

## 未发布（相对 `v0.11.0`）——Issue #421：CheckBox 增读系统 mixed 态

**行为新增，不是破坏。** 公开符号一个都没变（`CheckBoxToggleStyle` 仍是无参构造、无配置项），
off / on 两态在 normal / disabled / invalid 三种外观下与改动前的实现**逐像素对照过**。
新增的是第三个态：`CheckBoxToggleStyle.makeBody` 现在读 `configuration.isMixed`。

| 位置 | 之前 | 现在 |
|---|---|---|
| `CheckBoxToggleStyle` 指示符 | **仅按 `configuration.isOn` 二选一**（`square` / `checkmark.square.fill`），不区分 mixed | 三态：`square` / `minus.square.fill` / `checkmark.square.fill`，mixed 压过 `isOn` |
| mixed 的取色 | （无此态） | `contentPrimary`，与 on 同为「已作用」；off 仍是 `contentSecondary` |
| `.coreAnimation(.selection, value:)` 的触发值 | `configuration.isOn` | 三态枚举——否则 off ↔ mixed 不补间 |

**下游要改什么：不用改。** 旧调用点（`Toggle(_:isOn:)`）只会产生 on / off，画出来一字未变。
想要 mixed 的调用点用系统的 `Toggle(sources:isOn:label:)`——它从一组 `Binding<Bool>` 自动派生
on / mixed / off，本库不新增任何入参（公开 API 无 Bool 入参这条不破）。示例见
[checkbox.md](components/checkbox.md)。

⚠️ 已经在用 `Toggle(sources:)` 的调用点会**看到外观变化**：那一行原先按 `isOn`（mixed 下
实测为 `false`）画成空方框，现在画 `minus.square.fill`。点击行为一字未动——实测 mixed 下
`isOn.toggle()` 把整组绑定写成全 `true`（全选），读数见 [checkbox.md](components/checkbox.md)。

**Reduce Motion 开启时**：三态之间的符号替换与原来两态同路——`ContentTransition.identity`，
直接换图、不描画。静息外观与 RM 开关无关。

## 未发布（相对 `v0.11.0`）——Issue #409：TagGroup / TagInput 增删与选中动画

**行为变更（无签名破坏）。** 公开符号的签名一个都没变；`Tag` 一字未动。

| 位置 | 之前 | 现在 |
|---|---|---|
| `TagInput` 的 chip 身份 | `ForEach(Array(tags.enumerated()), id: \.offset)` —— 删中间项时消失的恒是**末位** id、下标 ≥ 删除位置的每个 id 被重新绑定到邻居的值 ⇒ 退场动画落在最后一个 chip、中间几个原地换 label | 「标签值 + 该值的出现序号」—— 值唯一时消失的身份正是被点的那一项，没有任何身份换值 |
| `TagInput` chip 增删 | 无动画，瞬间增删 | 缩放 0.86 + 淡变进出，存活标签连续重排（`CoreMotionToken.reveal`，0.25 s `.smooth`） |
| `TagGroup` 标签增删 | 无动画 | 同上 |
| `TagGroup` 选中态切换 | 无动画，底色 / 描边瞬变 | 0.22 s 交叉淡变（`CoreMotionToken.selection`） |

**Reduce Motion 开启时**：两处增删的驱动曲线为 `nil` ⇒ 直接出现 / 消失，`FlowLayout` 不做补间重排，
转场只剩淡变（缩放在每一相恒为 1）。`TagGroup` 的**选中态切换照常淡变**——只有颜色插值、包围盒不变，
不属于要降级的位移 / 缩放类动效。

**下游可能受影响的两处**（都不是编译期破坏）：

- 数组里有**重复值**时：删掉某个重复值的**任一次**出现，`ForEach` 的身份集合只少一个
  `(值, 最大序号)`、没有任何新增（排在前面的同值身份被原样复用）⇒ 数据结果正确，但**退场动画播在
  该值的最后一次出现上**，不一定是用户点的那一个。异值标签不受影响。
  ⚠️ 「身份完全稳定」只在**输入数组里值唯一**时成立——`allowDuplicates: false`（默认）只约束
  提交路径，外部绑定照样可以写进重复值。
- `TagGroup` 的 `data` 在下游被频繁整体替换（例如每次搜索都换一批标签）时，现在会播增删动画；
  不想要动画的调用点可注入 `.environment(\.coreMotionPresentationOverride, .hidden)`。
## 未发布（相对 `v0.11.0`）——Issue #408：原生符号 / 数字动效接入小件

**行为变更（无签名破坏）。** 公开符号的签名一个都没变；静息外观也不变——`anchoredBadge` 取了
**八种内容 / 宿主外形组合**（红点、`count` 的 9 / 99 / 截断、`text`、不显示各一种矩形宿主，
另加红点与 `count` 各一种圆形宿主；**不是**八种内容 × 两种外形的全矩阵），CheckBox / RadioGroup
取 enabled / disabled / invalid，都与改动前的实现逐像素对照过。变的是「状态切换时怎么动」：

| 位置 | 之前 | 现在 |
|---|---|---|
| `anchoredBadge(.count(_))` 计数变化 | 数字直接突变 | `.contentTransition(.numericText(value:))` 纵向滚动，方向由框架按当前计数自己判（增加向上、减少向下） |
| `anchoredBadge` 徽标出现 / 消失 | 直接出现 / 消失 | 缩放（0.6 → 1）+ 淡变，走 `CoreMotionToken.reveal`；转场挂在徽标本身，锚点是徽标中心 |
| `CheckBoxToggleStyle` 勾选切换 | 两张 `Image`（`square` / `checkmark.square.fill`）交叉淡变 | 一张 `Image` + `.contentTransition(.symbolEffect(.replace))`，勾以描画方式出现 |
| `RadioGroup` 选中切换 | 同一张 `Image` 换 `systemName` + 交叉淡变 | 同上，加 `.contentTransition(.symbolEffect(.replace))` |

⚠️ `RadioGroup` 在 **invalid 且选中态发生变化**时符号替换播不出来：invalid + 选中走
`.symbolRenderingMode(.palette)`（实心点 `contentPrimary` / 圆环 `statusDangerForeground`，`#374` 的取舍），
与单色分支是两个 `if` 分支、视图身份不同。有意保留该分支——把它并成「始终 `.palette` + 两层同色」时，
`circle.inset.filled` 实测有 1 LSB 的取值差、`checkmark.square.fill` 的勾会被同色实心层吃掉（逐通道差到 191）。

**Reduce Motion 开启时**（静息外观不变；只影响开启了「减弱动态效果」的用户）：

| 位置 | RM 开的行为 |
|---|---|
| 计数变化 | `ContentTransition.identity`：数字直接替换，不滚动、不模糊；胶囊宽度也**不补间**（位数变化时直接跳到新宽度——补间等于横向位移，不该在 RM 下发生） |
| 徽标出现 / 消失 | 纯淡变，不缩放 |
| CheckBox / RadioGroup 指示符 | `ContentTransition.identity`：直接换图，不描画 |

## 未发布（相对 `v0.11.0`）——Issue #407：动效 token 与 Reduce Motion 纪律

**行为变更（无签名破坏）。** 公开符号的签名一个都没变；新增 `CoreMotionToken`、`EnvironmentValues.coreMotionPresentation`、
`EnvironmentValues.coreMotionPresentationOverride`（`nil` ⇒ 跟随系统）、`View.coreAnimation(_:value:)`。核心库所有过渡曲线改经 `CoreMotionToken` 取，下列时长 / 曲线随之变化：

| 位置 | 之前 | 现在 |
|---|---|---|
| `.pressableRow` / `.pressableCard` 按下 | `.easeOut(duration: 0.15)` | `CoreMotionToken.press`（`.snappy`，0.16 s） |
| `.borderless()` 按下变色 | `.easeInOut`（默认时长） | `CoreMotionToken.press` |
| `SegmentedControl` 切换 | `.easeInOut(duration: 0.18)` | `CoreMotionToken.selection`（`.snappy`，0.22 s） |
| `UnderlinedTabBar` 把选中项滚到中间 | `.snappy(duration: 0.2)` | `CoreMotionToken.selection`（`.snappy`，0.22 s） |
| `CheckBox` / `RadioGroup` 选中切换 | `.easeOut(duration: 0.25)` | `CoreMotionToken.selection` |
| `FormField` 校验消息 / 说明切换 | `.easeInOut(duration: 0.2)` | `CoreMotionToken.reveal`（`.smooth`，0.25 s） |
| `.disclosureGroupStyle(.core)` 展开 | `.snappy`（默认时长） | `CoreMotionToken.reveal` |
| `Carousel` 翻页（自动轮播与点页点） | `withAnimation`（`.default`） | `CoreMotionToken.scroll` |
| `Toast` 进出 | `.easeInOut(duration: 0.25)` | `CoreMotionToken.reveal`（时长不变，曲线换成 `.smooth`） |
| `Skeleton` 占位 ↔ 内容、`.spinning(_:)` 出现 / 消失 | `.animation(.default, …)` | `CoreMotionToken.reveal` |

按钮背景、`TelegramGlassButtonModifier`、`AsyncButton`、`UnderlinedTabBar` 选中切换的曲线原本就是
`CoreMotionToken` 对应档位的值，不变。

**Reduce Motion 开启时的新行为**（静息外观不变；只影响开启了「减弱动态效果」的用户）：

| 位置 | 之前（RM 开） | 现在（RM 开） |
|---|---|---|
| `.solidButton` / `.lightButton` / `.circularGlass` / `TelegramGlassButtonModifier` / Toast 操作按钮 按下 | 缩到 0.94 | 不缩放，按下透明度 0.7（与样式自带的 0.9 / 0.92 取较小值，不叠乘） |
| `Toast` 进出 / 退场 | 滑入滑出、退场位移 60pt、HUD 缩放 0.92 | 原地淡入淡出；滑动松手后停在松手位置淡出；HUD 不缩放 |
| `SegmentedControl` 滑块、`UnderlinedTabBar` 下划线 | 滑到新位置 | 原地淡变，不途经中间 |
| `.disclosureGroupStyle(.core)` chevron | 旋转补间 | 直接到位 |
| `.spinning(_:presentation: .topBar)` 顶条 | 循环扫动 | 静止居中 |
| `Carousel` 点页点、`UnderlinedTabBar` 滚到选中项 | 滚动补间 | 直接到位 |
| 上面所有淡变类动画 | 各自的曲线 | 同时长 `easeInOut` |

## `0.11.0`（2026-09-22）——Issue #399：浮层与层级（Toast / `floatingGlass` / `.surface`）

**视觉变更（无签名破坏）。** 公开符号的签名一个都没变；以下是默认外观的变化：

| 位置 | 之前 | 现在 |
|---|---|---|
| `Toast` danger 图标 | `exclamationmark.octagon` | **`exclamationmark.circle`**（与 `Banner` 的 circle 族成组，Toast 保持描线） |
| `Toast` 在 AX 字号（AX1+） | 图标单独占一列，文字列变窄，长单词会从中间折断 | 图标独占标题上方一行（字号上限 `accessibility1`），文字列拿到整条宽度；常规字号外观不变 |
| `.toastHost(presentation: .fullWidthBanner)` 外壳 | 四周 hairline，止于安全区 | **无 hairline**，底色与玻璃延伸进所贴那条边的安全区（顶部即状态栏），左右与贴边那侧的玻璃高光边推出屏幕 |
| `.toastHost(presentation: .centeredHUD)` 外壳 | 64% 背景色 + 玻璃，叠在文字上透字 | 底色改为不透明 `surfaceRaised`，保留玻璃边缘与 hairline |
| `.surface(.content)` / `.surface(.card)` / `Card()` 嵌套到 elevated 层（**仅 iOS**） | `borderMuted` 描边 | **无描边**（与 `.grouped` 合流）；raised / base 层不变；macOS 不变 |

- `.floatingCapsule` 与公开入口 `.floatingGlass(in:isInteractive:)`（含 `FloatButton` 的扩展样式）外观不变。
- macOS 上 `surfaceCard` 与 `surfaceElevated` 同色，描边是嵌套的唯一线索，所以 elevated 层的描边在 macOS 上保留。

## `0.11.0`（2026-09-22）——Issue #400：输入控件的校验 / 禁用 / 尺寸外观

**视觉与布局变更（无签名破坏，无公开 API 增减）。**

| 控件 / 状态 | 之前 | 现在 |
|---|---|---|
| `CheckBoxToggleStyle` / `RadioGroup` 在 `.disabled(true)` 下 | 与 enabled 外观相同 | 整行（图标 + 标题）降到 0.4 不透明度；enabled 外观逐像素不变 |
| `RadioGroup` invalid 且选中 | 圆环与实心点都取 `statusDangerForeground` | 只有圆环取 danger，实心点保持 `contentPrimary` |
| `TagInput` invalid | 只在输入框下面画一条 80pt 起的红线 | 整个字段底部一条横跨全宽的红色基线 |
| `PinCode` invalid 且获焦的那一格 | 2pt 红边 | 2pt 红边 + 格外 4pt `statusDangerForeground` 30% 光晕（不占布局） |
| `PinCode` 有值时（浅色最明显） | 中间两格的空隙里透出淡淡的数字 | 不再透出，获焦编辑与选区高亮时也不透出（隐藏输入框的文字 / 光标取透明色，并在几何上裁掉） |
| `SearchField` 放进不限高的容器（iOS） | 被纵向拉伸到容器高度 | 取固有高度 44pt；macOS 本来就不拉伸，布局不变 |
| `SearchField` 由调用方显式给高度，如 `.frame(height: 60)`（iOS） | 原生搜索框（绘制带与命中区）被撑到 60pt | 外层框仍是 60pt，原生搜索框保持 44pt、垂直居中；44pt 之外的上下各 8pt 是空白，点按不聚焦。macOS 前后都是原生固有高度 |

- **迁移**：一般不需要；之前为规避拉伸加的 `.fixedSize(horizontal: false, vertical: true)` 可以删掉（留着也无害）。
  ⚠️ **原生搜索框的高度没有恢复手段**：外层再包 `.frame(height:)` / `.frame(maxHeight: .infinity)` 只会放大外面那层
  框，原生搜索框的绘制带与命中区都停在 44pt，不会跟着变高。依赖旧的「给多高就画多高」的调用点（如用
  `.frame(height: 60)` 画一条加高搜索条）需要自行包一个 `UISearchTextField` / `.searchable`，本库不提供开关。想让禁用的 CheckBox / Radio 保持不变淡的旧观感，没有开关——这是有意对齐系统控件的行为。

## `0.11.0`（2026-09-22）——Issue #398：Banner 圆角与 neutral 不透明底色、Timeline 浅色 warning 圆点

**视觉变更（无签名破坏）。** 新增公开 token：`Color.systemGray5`（第 2 层）、`Color.statusNeutralSubtle`（第 3 层）。

| 外观 | 之前 | 现在 |
|---|---|---|
| `Banner` 容器（`PlainBannerStyle` / `BorderedBannerStyle`） | 直角矩形 | `CoreRadius.medium`（10pt）连续圆角；Bordered 描边沿同一圆角形状内描。内容布局与尺寸不变；形状这一项只改变四角像素（该对照在 neutral 底色变更之后测得，底色变更见下一行） |
| `Banner` `.neutral` 背景 | `tertiaryFill`（半透明，随背后底色变深浅） | `statusNeutralSubtle` → `systemGray5`（不透明；iOS 浅 `#E5E5EA` / 深 `#2C2C2E`，macOS 取 `unemphasizedSelectedContentBackgroundColor`——外观近似而非语义等价，增强对比度与 vibrancy 下的表现未经验证） |
| `Timeline` 浅色 `warning` 默认圆点 | `statusAttentionEmphasis`（`#D1A72D`，对分组背景约 2.0:1） | `statusAttentionForeground`（`#9A6700`，对分组背景 4.36:1）；暗色不变 |

- **迁移（保留旧观感）**：想要直角或旧的半透明 neutral 底色，写一个自定义 `BannerStyle`（`makeBody` 里用
  `Rectangle()` 背景、neutral 取 `Color.tertiaryFill`），经 `.bannerStyle(_:)` 注入。
- 截图 / 快照基线比对 Banner 的下游需要重录；Timeline 只有浅色 warning 圆点变化。

## `0.11.0`（2026-09-22）——Issue #382：surface 有效层级 + `coreSheetPresentation(background:)`

**行为变更（无签名破坏）。** `.surface(_:)` 现在按环境里的有效层级取背景（规则见
`docs/components/surface.md`）：

| 调用形态 | 之前 | 现在 |
|---|---|---|
| `content` / `grouped` / `card` 嵌套在另一个 `content` / `grouped` / `card`（含 `Card`、`InsetGroupedSection`）里 | `surfaceCard` | **`surfaceElevated`**（`tertiarySystemGroupedBackground`） |
| 顶层或 `.surface(.canvas)` / `.surface(.canvasSubtle)` 之下的 `content` / `grouped` / `card` | `surfaceCard` | 不变——⚠️ **前提是它不在一个挂在 surface 内部的普通 `.sheet` / `.popover` 里**：弹层内容继承宿主层级（实测），这时 sheet 里「看起来是顶层」的卡片也会取 `surfaceElevated` |
| `panel` / `sidebar` / `control` / `floating` / `canvas` / `canvasSubtle` | 各自现值 | 不变 |
| `Card` 自身有效层级为 elevated（上面第一行的情形，含 `coreSheetPresentation` 内容里的 `Card`） | 按 `elevation` 出投影（默认 `.small`） | **不出投影**，显式传 `.medium` / `.large` 也不出 |

- **迁移（逐项保留旧观感）**：想让某个嵌套处保持旧的 `surfaceCard` 外观，不要再用 `.surface`，改写成与旧
  `.surface(.content)` 逐项相同的手写链——背景、1pt 描边、圆角、裁切都一致，且不写层级：

  ```swift
  let shape = CoreShape.rounded(CoreRadius.medium)
  content
      .background(shape.fill(Color.surfaceCard))
      .overlay(shape.strokeBorder(Color.borderMuted, lineWidth: CoreBorderWidth.thin)) // `.grouped` 删掉这一行
      .clipShape(shape)
  ```

  嵌套的 `Card` 同理：`content.padding(CoreSpacing.lg).frame(maxWidth: .infinity, alignment: .leading)` +
  上面三行 + `.coreShadow(.small)`（即旧 `Card` 的全部修饰链）。
- 两个**不等价**的捷径及其代价：
  - 内层外包 `.surface(.canvas)`：层级确实重置、内层回到 `surfaceCard`，但 canvas 角色会在内层**外接矩形**上
    铺一层 `surfaceCanvas`（无圆角）——内层卡片的四个圆角处露出画布色（浅色 `#F2F2F7` 落在白色外层卡片上、
    深色为黑），它与内层之间若有 padding 则露出一整圈。
  - 内层改用 `.background(Color.surfaceCard)`：底色对了，但**丢掉描边、圆角与裁切**（直角、无描边）。
- macOS 上 `surfaceCard` 与 `surfaceElevated` 同值，背景像素不变；投影收起在 macOS 同样生效。
- 新增（纯新增）：`View.coreSheetPresentation(background:)` 与 `enum CoreSheetBackground`（`.system` / `.raised`）。

## `0.11.0`（2026-09-22）——Issue #377：Toast 标题 / 说明 / 动作、`ToastDuration`、计时状态机

**破坏性变更（源码）。** 新旧签名映射：

| 旧 | 新 |
|---|---|
| `ToastItem.message: String` | `ToastItem.title: String` |
| `ToastItem(id:message:level:duration:)` | `ToastItem(id:title:description:level:duration:action:)` |
| `ToastItem.duration: TimeInterval` | `ToastItem.duration: ToastDuration` |
| `ToastHost.show(_ message:level:duration:)`，`duration: TimeInterval` | `ToastHost.show(_ title:description:level:duration:)`，`duration: ToastDuration` |
| `ToastDefaults.duration: TimeInterval`（`3`） | `ToastDefaults.duration: ToastDuration`（`.seconds(3)`） |

迁移：

```swift
// 旧
host.show("Saved", level: .success, duration: 5)
let item = ToastItem(message: "Saved", duration: 2)
print(item.message)
// 新
host.show("Saved", level: .success, duration: .seconds(5))
let item = ToastItem(title: "Saved", duration: .seconds(2))
print(item.title)
```

- 位置实参调用 `show("…")` / `show("…", level:)` 不受影响；只有 `message:` 标签、读 `.message`、
  传 `TimeInterval` 时长与把 `ToastDefaults.duration` 当 `TimeInterval` 用的调用点需要改。
- 行为变化：旧版 `duration <= 0` 会立即关闭；新版 `.seconds` 的非正值（含 NaN）按缺省 3 秒处理，
  `.seconds(.infinity)` 等同新增的 `.persistent`。
- 新增（非破坏）：`ToastItem.description`、`ToastAction`、`ToastDuration.persistent`、`ToastHost.dismissAll()`；
  按住 / 拖拽暂停计时。

## `0.11.0`（2026-09-22）——Issue #376：Banner 补齐 title / actions / dismiss

**破坏性变更（自定义 style 行为 + 无障碍结构）；编译期无信号。**

1. **`BannerStyleConfiguration` 新增 `title: Text?`、`actions: AnyView?`、`dismiss: (() -> Void)?`**。
   该类型没有公开 init，新增字段不破坏编译；`label` 仍是正文槽、语义不变。但**自定义 `BannerStyle`
   若不渲染这三个字段，经新便利 init `Banner(level:title:message:actions:onDismiss:)` 传入的标题、
   动作与关闭钮会被静默丢弃**。迁移：在 `makeBody` 里按需渲染它们，并让动作与关闭钮保持为独立按钮：

   ```swift
   struct MyBannerStyle: BannerStyle {
       func makeBody(configuration: Configuration) -> some View {
           VStack(alignment: .leading) {
               HStack(alignment: .top) {
                   VStack(alignment: .leading) {
                       configuration.title?.font(.headline)
                       configuration.label
                   }
                   .accessibilityElement(children: .combine)
                   Spacer()
                   if let dismiss = configuration.dismiss {
                       Button(action: dismiss) { Image(systemName: "xmark") }
                           .accessibilityLabel("Dismiss")
                   }
               }
               configuration.actions
           }
       }
   }
   ```

2. **内建 style 不再把整条 Banner 合并为单一无障碍元素**。此前 `PlainBannerStyle` /
   `BorderedBannerStyle` 对整条施加 `.accessibilityElement(children: .combine)`，图标对 VoiceOver 隐藏。
   现在：图标 + 标题 + 正文合并为一个元素，并且**图标读出状态**（Info / Success / Warning / Error /
   Neutral，与 `Timeline` 同一组键）；动作按钮与关闭钮是各自独立的可聚焦节点，经 `accessibilitySortPriority`
   排在正文之后（内容 → 动作 → 关闭）。
   只有正文的旧调用点**视觉布局不变**（尺寸与像素有回归测试对照旧实现）；变化只在无障碍：
   VoiceOver 读法由「正文」变为「状态、正文」；在 `label` 槽里放了按钮的
   调用点，该按钮仍被合并进内容元素——请改用 `actions` 槽让它成为独立节点。UI 测试若按旧的合并
   label 查找 Banner，需要同步。

## `0.11.0`（2026-09-22）——Issue #378：Badge / Tag / Avatar 尺寸体系 + `AvatarSize`

**破坏性变更（布局 + 函数引用）。**

1. **`Avatar` 改为固定直径（布局破坏，编译期无信号）**。此前 `Avatar` 是 `.resizable()` 的位图，
   尺寸完全由外部 `.frame` 决定；现在它按 `size: AvatarSize` 渲染固定边长——缺省 `.automatic`
   随环境 `\.controlSize` 取 `CoreControlMetrics.avatarDiameter(for:)`（mini 20 / small 24 /
   regular 32 / large 40 / extraLarge 48），外部 `.frame` **不再拉伸**它，只决定摆放位置。
   迁移：写过 `.frame(width: d, height: d)` 来定头像尺寸的调用点改为 `size: .fixed(d)`：

   ```swift
   // 旧
   Avatar(name: "Alice").frame(width: 100, height: 100).clipShape(Circle())
   // 新
   Avatar(name: "Alice", size: .fixed(100)).clipShape(Circle())
   ```

   不带 `.frame` 的调用点：旧版按 `.resizable()` + `.aspectRatio(contentMode: .fill)` 占满父布局提议的空间，
   新版在 `.regular` 档为 32pt；需要保持 48pt 的请写 `.fixed(48)` 或 `.controlSize(.extraLarge)`。
2. **`Avatar.init(name:)` → `Avatar.init(name:size:)`**（`size` 带默认值 `.automatic`）：
   已应用的调用点 `Avatar(name:)` 源码零改动；**未应用的函数引用** `Avatar.init(name:)` 不再存在，
   改为闭包 `{ Avatar(name: $0) }`。
3. **`Badge` / `Tag` 跟随 `\.controlSize`（视觉变化，非 API 破坏）**：`.regular`（缺省）档取值与旧版一致；
   但处在 `.controlSize(.small)` 等非缺省环境里的 Badge / Tag 会随之缩放。要保持旧外观，在它们上面
   显式加 `.controlSize(.regular)`。
4. **可删除 `Tag` 变矮（视觉变化）**：关闭钮外围的可见 `CoreSpacing.xxs` 内边距移除、关闭钮不再撑高行，
   `removable: true` 的 Tag 在各档都与普通 Tag 等高（regular 档因此比旧版矮）；点击热区大小不变。
5. **`AvatarGroup` 非 regular 档的几何变化（视觉变化）**：交叠量改为直径的 1/4（mini -6→-5、
   extraLarge -10→-12，其余不变）；`+N` / 计数徽标文字随档缩放（regular 仍为 `.caption`）。

新增公开符号：`AvatarSize`（`.automatic` / `.fixed(CGFloat)`）；`CoreControlMetrics.compactFontToken(for:)` /
`compactHorizontalPadding(for:)` / `compactVerticalPadding(for:)` / `compactIconSize(for:)` /
`compactMinHeight(for:)` / `compactCornerRadius(for:)` /
`avatarDiameter(for:)` / `avatarInitialFontSize(forDiameter:)`。

## `0.11.0`（2026-09-22）——Issue #375：`StatusLevel` 新增 `.neutral`

**源码破坏性变更。** `public enum StatusLevel` 新增 `case neutral`（中性提示，取内容 / 填充语义色，
不取状态色）。本包以源码形式分发、不开 library evolution，下游对 `StatusLevel` 写的 **exhaustive `switch`**
（逐个列出 `.info` / `.success` / `.warning` / `.danger`、不带 `default`）会在升级后编译失败：
`switch must be exhaustive`。

- 迁移：在该 `switch` 里补一个 `case .neutral:` 分支（推荐，按中性语义给出取值）；或加 `default:`。
- 只构造 / 比较 `StatusLevel` 值、或把它传给 `Banner` / `ToastHost.show` / `TimelineItem` 的调用点**不受影响**。
- 本库内的三处消费者已同步，neutral 一律「图标 / 节点 `contentSecondary`、正文 `contentPrimary`」：
  `Banner`（背景 `tertiaryFill`、描边 `borderDefault`，图标 `bell.fill`）、`Toast`（图标 `bell`）、`Timeline`
  （圆点 `contentSecondary`，VoiceOver 文案键 `"Neutral"`，已登记进 `en.lproj/Localizable.strings`）。

## `0.11.0`（2026-09-22）——移除 `Sidebar` 与 `BottomInputBar` 组件

**破坏性变更。** 这两个组件不再属于本库，整体删除（不迁到其他 target）；需要它们的调用方请在
自己的代码里维护一份。被移除的公开符号：

| 组件 | 移除的公开符号 |
|---|---|
| `BottomInputBar` | `struct BottomInputBar`（`init(isShowingSuggestions:placeholder:wandEnabled:sendEnabled:showMenuButton:isRunning:autoFocus:externalFocus:onActivate:onStop:onSubmit:)`）、`enum BottomInputBarDefaults`（`placeholder`）、`View.bottomInputBar(suggestions:placeholder:autoShowSuggestions:wandEnabled:sendEnabled:showMenuButton:isRunning:showShuffleButton:autoFocus:externalFocus:onActivate:onStop:onSubmit:)` |
| `Sidebar` | `SidebarSection`（`init(title:showsChevron:content:)`）、`SidebarNavigationRow`（`init(title:isSelected:action:leading:)` 与 `init(systemImage:title:isSelected:action:)`）、`SidebarUtilityRow`（`init(systemImage:title:trailingSystemImage:presentation:action:)`）、`enum SidebarUtilityRowPresentation`（`.iconLeading` / `.textOnly`）、`SidebarDocumentRow`（`init(systemImage:title:detail:action:)`）、`SidebarTagRow`（`init(title:action:)`）、`SidebarStatusFooter`（`init(title:detail:statusColor:)`）、`enum SidebarTextStyle`（`primary` / `secondary` / `tertiary`）、`View.sidebarSelectedBackground(_:)` |

- 随组件一起删除的 internal 实现：`CoreMenuButton` / `CoreMenuButtonStyle`（`BottomInputBar` 的菜单按钮）、
  `BottomInputBarModifier` / `BottomInputBarSuggestionsView` / `BottomInputBarGlassEffectShape`，
  以及 `Localizable.strings` 里只被它们使用的 `"iMessage"` / `"Menu"` / `"Send"` / `"Stop"` / `"Suggestions"` 五个键。
- **保留**（通用 token，不是组件）：`Color.surfaceSidebar` 与 `SurfaceKind.sidebar`（`.surface(.sidebar)`）。
- `SidebarTextStyle` 的三个成员原是 `.primary` / `.secondary` / `.tertiary` 对
  `Color.contentPrimary` / `.contentMuted` / `.contentSubtle` 的别名，迁移时直接改用这三个 token。
- 登记表 / 台账同步：`docs/component-registry.json` 移除 7 条（`BottomInputBar` 与 6 个 `Sidebar*`），
  `docs/bool-exemptions.json` 移除 15 条豁免，`docs/mainactor-static-exemptions.txt` 移除 4 条
  （`SidebarTextStyle.*` 与 `BottomInputBarDefaults.placeholder`）。

## `0.11.0`（2026-09-22）——Issue #312：五个组件的布局形态扩展点

**含破坏性变更（与 `v0.9.0` 那 7 处、`0.10.0` 的 `NetworkGraph` 同形）** —— 五个 `init` 各新增一个
带默认值的 `layout:` 参数：

| 组件 | 新参数（默认 = 现状画法） | 参数位置 |
|---|---|---|
| `RadarChart` | `layout: RadarChartLayout = .polygon` | 末尾 |
| `RingChart` | `layout: RingChartLayout = .rings` | 末尾（`colors:` 之后） |
| `ActivityHeatmap` | `layout: ActivityHeatmapLayout = .weeks` | 末尾（`calendar:` 之后） |
| `BeforeAfterSlider` | `layout: BeforeAfterSliderLayout = .overlay` | `labels:` 之后、`before:` 闭包之前 |
| `OrbitingLogos` | `layout: OrbitingLogosLayout = .outerRing` | `rotationPeriod:` 之后、`logo:` 闭包之前 |

- **对已应用的调用点零影响**：参数带默认值且位于闭包参数之前，尾随闭包写法照常编译。
- **对未应用的函数引用是破坏性变更**：把这些 `init` 当函数值取，或写死不含 `layout:` 的完整签名时，类型变了。
- **新增 public 类型** `RadarChartLayout`（`.polygon` / `.parallel` / `.radialBars` / `.bars`）、
  `RingChartLayout`（`.rings` / `.bars` / `.segmentedRings` / `.stackedBar`）、
  `ActivityHeatmapLayout`（`.weeks` / `.monthCalendar` / `.monthTracks` / `.dailyColumns`）、
  `BeforeAfterSliderLayout`（`.overlay` / `.sideBySide` / `.stacked`）、
  `OrbitingLogosLayout`（`.outerRing` / `.multiRing` / `.ellipse`），另新增
  `RingChart.segmentCount`（`.segmentedRings` 的分段数，固定为 10）。
  ⚠️ 五个枚举都**非 `@frozen`** ⇒ **将来加 case 也是破坏性变更**（下游穷举 `switch` 不写
  `@unknown default` 就编译红），届时要在本文件另起一条。
- **默认 case 即本版之前的画法**：不传 `layout:` 时走默认 case，调用方观感不变。

理由与判定过程见 `docs/components/{radar-chart,ring-chart,activity-heatmap,before-after-slider,orbiting-logos}.md`
与登记表各条 `notes`；`OrbitingLogos` 的落点裁定见 `docs/contract-defects.md` 的 `## #312` 节。

## `0.11.0`（2026-09-22）——Issue #357：`coreAccent` on-accent 通路

**源码兼容，行为有变。** `View.coreAccent(_:)` 增加可选 `on` 参数
（`coreAccent(_ color: Color, on: Color? = nil)`）——与 `v0.9.0` 那 7 处同形：
对已应用调用点零影响，对未应用的函数引用是破坏性变更。

- **`on` 缺省（`nil`）时自动选前景**：墨色（黑 / 白极性）accent 走 `contentOnAccent`
  特判——与 `0.10.0` 的静态 token **逐字节相同**；其余颜色按 accent 在当前外观下的
  相对亮度分档，`L = 0.2126R + 0.7152G + 0.0722B`，L < 0.5 → `.white`，否则 `.black`。
  消费点：`SolidButtonStyle` 的 `.primary` 前景（新公开
  `ButtonRoleStyleRole.resolvedOnColor(accent:on:environment:)`）与
  `InkSegmentedControlStyle` 选中段文字。
  ⚠️ **行为变化**：`0.10.0` 章节登记的「主题色应为近单色」约束解除——
  `.coreAccent(<饱和色>)` 下深色模式前景不再是近黑字压饱和底，而是按亮度自动反色
  （系统蓝两档白字、黄两档黑字）；显式 `on` 则原样使用。
- **`contentOnAccent` 保留**作静态回退；其余四个 role 的底色是明暗镜像的
  `ColorGrade` 色阶，前景仍走 `contentOnAccent`、不吃 `on`。
- 新增 `@Entry var coreAccentOn: Color? = nil`（`nil` = 缺省派生）。

## `0.10.0`（2026-09-09）——仓库与模块改名为 OhMyDesign

**含破坏性变更，且是本版影响面最大的一条：所有 `import` 都要改。** 已随 `v0.10.0` 发布。

| 旧 | 新 |
|---|---|
| 仓库 `github.com/wxlpp/CoreDesign` | `github.com/wxlpp/oh-my-design` |
| 包名 `CoreDesign` | `OhMyDesign` |
| product / module `CoreDesign` | `OhMyDesign` |
| product / module `CoreDesignEffects` | `OhMyDesignEffects` |
| product / module `CoreDesignCharts` | `OhMyDesignCharts` |
| 预览宿主 `CoreDesignPreview` | `OhMyDesignPreview` |
| bundle id 前缀 `com.coredesign` | `com.ohmydesign` |
| `docs/component-registry.json` 的 `repo` 字段 `"coredesign"` | `"ohmydesign"` |
| SwiftPM checkout 目录名 / 包 identity `CoreDesign` | `oh-my-design` |

下游改法：

```diff
- .package(url: "https://github.com/wxlpp/CoreDesign", from: "0.9.0"),
+ .package(url: "https://github.com/wxlpp/oh-my-design", from: "0.10.0"),

- import CoreDesign
+ import OhMyDesign
```

⚠️ **`Core` 前缀的公开符号一律未改**（`CoreElevation` / `CoreTypography` /
`CoreControlMetrics` / `CoreMenuButton` / `.coreAccent(_:)` / `.core` 系列 control style
……）。它们表达的是「核心 / 内建」语义，不是仓库名 ⇒ 改名不波及，下游这部分调用点零改动。

⚠️ 后两行是**跨仓契约**，本仓 CI 只 checkout 本仓 ⇒ 对面仓（`wxlpp/oh-my-story` 的
`CrossRepoRegistryGuard` 按 `repo` 值筛条目、按 checkout 目录名定位本仓登记表）在这条
分叉上**零信号**，须人工去对面仓核一次。

⚠️ 旧仓库名在 GitHub 上的重定向是**会过期的外部状态**（截至 2026-09-09 有效；任何人新建
一个 `wxlpp/CoreDesign` 就会打断它），不要当长期契约。而 `import CoreDesign` **没有**任何
兼容垫片，不改就编译不过。

## `0.10.0`（2026-09-09）——设计系统配色 / 样式回灌

**含破坏性变更。** 已随 `v0.10.0` 发布。

### token 取值变更（不改签名，但下游观感会变）

| token | 旧 | 新 |
|---|---|---|
| `Color.accent` | `Color.accentColor`（跟随宿主 `AccentColor`） | `Color.inkPrimary`（墨色；iOS `label` / macOS `textColor`）。宿主换色改走 `View.coreAccent(_:)` |
| `accentHover` / `accentPressed` | `mix(with: .primary, by: 0.15 / 0.25)`（远离背景） | `mix(with: .surfaceBase, by: 0.18 / 0.30)`（**朝向背景**，方向反转） |
| `accentDisabled` | `.opacity(0.35)` | `.opacity(0.22)` |
| `accentSubtleBackground` | `.opacity(0.12)` | `.opacity(0.08)` |
| `contentOnAccent` | `.white` | `.systemBackground`（随主题反转） |
| `contentLink` | `.link`（系统蓝） | `.label`。⚠️ 本仓无链接下划线约定 ⇒ 链接与正文视觉上**不可区分**，是登记在案的缺口 |
| `success` | `green5` | 系统绿 |
| `info` | `blue5` | `.label` |
| `secondaryAccent` 族 | `lightBlue5/6/7/2` | `grey7/8/9/2` |
| 四个图表的 `tint` 默认实参 | `.accent` | `.dataAccent`（系统蓝） |

⚠️ `contentOnEmphasis` / `contentInverse` / `contentOnDanger` **保持 `.white`**——
它们压的是固定饱和色背景，一刀切会让深色下变成黑字压红 / 橙 / 绿底。
⚠️ `warning` / `danger` 两族 8 个 token **不动**：它们被 `ButtonRoleStyleRole` 消费，
基色换系统色而派生态留色阶会让同一按钮 rest 与 pressed 分属两个色相族。

### 签名变更

- **`tint` / `color` 参数改 `Color? = nil`**（`nil` 时回落环境 `\.coreAccent`）：
  `SpinningModifier.init` 与其 **`public let tint` 存储属性**、`View.spinning(...)`、
  `ProgressIndicator` 三个 init、`View.ping(...)`、`View.rise(...)`、`View.focusRing(...)`。
  ⚠️ **读取存储属性的下游要改**：`SpinningModifier(...).tint` 现在是 `Color?`
  （本仓 `scripts/downstream-probe` 已同步）。调用点因 optional 提升不受影响。
- **`Card.init` 新增 `elevation: CoreElevation.Level = .small`**——与 `v0.9.0` 那 7 处同形：
  对已应用调用点零影响，对未应用的函数引用是破坏性变更。⚠️ 默认值不是 `.none`：
  `Card` 现在**默认带一层浅投影**，这是逐条确认过的单点越界（背离「静置内容不浮起」），
  `elevation: .none` 一行退回。
- **`ButtonRoleStyleRole` 新增** `resolvedColor(accent:isEnabled:isPressed:)` 与 `onColor`。
  旧 `resolvedColor(isEnabled:isPressed:)` 与三个无参属性**保留**并委托新重载。

### 行为变更

- **`SearchField` 内部改用平台原生控件**（iOS `UISearchTextField` / macOS `NSSearchField`）。
  公开 API `SearchField(text:placeholder:onSubmit:)` 源码兼容。
  清除按钮与其 a11y 名改由系统提供 ⇒ 移除 internal `clearLabel(for:)` 与
  `Localizable.strings` 的 `"Clear %@"`；`.focusRing` 撤除（系统自绘焦点态）。
- **Sidebar 选中态扁平化**：去 `floatingGlass` + `borderSelected` 描边 + `coreShadow(.medium)`，
  改为 `accentSubtleBackground` 填充。这是对 `#226`「保持现状」的改判，
  依据是 `#226` 自己写下的重议条件（原记在 `docs/components/sidebar.md`，该文档已随组件移除，可从 git 历史取回）。
- **`ListRow` 竖向 padding 12 → 8**（本处调用改 `CoreSpacing.sm`，
  **未动共享的 `CoreControlMetrics.verticalPadding`**）。44pt 触控下限不变
  ⇒ 单行行观感不变，只有多行 / 带副标题的行收紧。
- **`SegmentedControl` 新增 `InkSegmentedControlStyle`** 与 `.glass` / `.plain` / `.ink`
  三个静态入口。**默认仍是 `GlassSegmentedControlStyle`**，不变。

### 新增

`Color.inkPrimary`（第 2 层）、`Color.dataAccent` / `dataAccentSubtle`、
`EnvironmentValues.coreAccent` + `View.coreAccent(_:)`。

⚠️ **`coreAccent(_:)` 的主题色应为近单色（黑 / 白极性）。** `contentOnAccent` 取
`systemBackground`，只在墨色 accent 上正确；传入**饱和色**时深色模式下前景会是近黑色
压在该饱和色上。本版本**不提供** on-accent 的环境钩子（要修需加 `coreAccent(_:on:)`
或按亮度派生 `onColor`，是独立的 API 决定）——已登记为 `#357`。

⚠️ **`SearchField.onSubmit` 在 macOS 上的触发时机**：走 `NSSearchField` 后仅在**回车**
触发，与 iOS 及旧的 SwiftUI `.onSubmit` 一致。⚠️ 实现上**不得**改用 `target` / `action`
——`sendsWholeSearchString` 默认 `false` 会让它逐键触发，且清除按钮会再触发两次空串。

---

## `0.10.0`（2026-09-09）——Issue #312：`NetworkGraph` 的布局形态扩展点

**含破坏性变更（与 `v0.9.0` 那 7 处同形）** —— `NetworkGraph.init` 新增
`layout: NetworkGraphLayout = .force`。

- **对已应用的调用点零影响**：参数带默认值，`NetworkGraph(nodes:edges:)` 照常编译。
- **对未应用的函数引用是破坏性变更**：把 `NetworkGraph.init` 当函数值取（`let f = NetworkGraph.init`）
  或写死 `(nodes:edges:title:tint:)` 的完整签名时，类型变了。
- **新增 public 类型** `NetworkGraphLayout`（`.force` / `.circular` / `.grid` / `.layered`）。
  ⚠️ **非 `@frozen`** ⇒ **将来加 case 也是破坏性变更**（下游穷举 `switch` 不写
  `@unknown default` 就编译红），届时要在本文件另起一条。

理由与判定过程见 `docs/components/network-graph.md` 与登记表 `NetworkGraph.notes`。

## `0.10.0`（2026-09-09）——Issue #238：删除 `SurfaceKind.overlay`

**含破坏性变更** —— `SurfaceKind` 删除 **1** 个 public case：`.overlay`。

数字由 `scripts/api-surface-diff.sh` 得出（与 `#271` 那章同一格式）：

```bash
bash scripts/api-surface-diff.sh 42a872a
#   - 删除  EnumElement    overlay
#   EXIT=1
```

⚠️ **该脚本不在 CI 里**（`grep -rn api-surface .github` 零命中）⇒ 这个数是**人工跑的**，
没有机器兜底。

### 为什么删而不是改语义

`.overlay` 的 doc 写着「**覆盖层表面，如菜单与 popover**」，而它自 `#220` 起走 `quaternaryFill`
—— **iOS** 实测 α **0.078（浅）/ 0.180（深）**，即约 **92% 透明**，**且没有任何模糊**
（⚠️ macOS 侧是 `#00000007` / `#FFFFFF07`，α ≈ .027、约 97% 透明——更淡，不是同一个数）。
⚠️ 叠在纯色底上看着只是「淡一点的面」（`#225` 的合成对照预览正是这么漏掉它的），
**叠在文字内容上会整片 ghosting**。⇒ **名字在邀请一种它做不到的用法。**

⚠️ `.overlay` 与 `.panel` **今天就是全等的两个 case**（同 background / border / radius，
`SurfaceModifier` 的三个 switch 逐条相同），而 `.panel` 的 doc 本就是「兼容别名」。
⇒ 删掉误导的那个、把诚实的那个扶正，**取值零变化**。

### ⚠️ 为什么是**硬删**而不是 `@available(*, deprecated, renamed:)`

本仓两种先例都有：`ProgressBar` 是**弃用**（`v0.6.0`，source-compatible、带警告、
「保留至下游迁移完成后移除」），`#271` 是**硬删** 31 条。本次选硬删，理由：

**`#238` 的核心是「名字本身在邀请误用」。** 弃用别名会让 `.overlay` **继续留在补全列表里**
（只是带删除线），而那正是要消除的东西 —— 一个仍能被打出来、doc 还写着「如菜单与 popover」
的名字。⇒ 弃用能消除**破坏**，消除不了**邀请**。

⚠️ **代价照录**：`renamed:` 弃用可以做到**零编译破坏 + 下游一键 fix-it**
（终审实测：`@available(*, deprecated, renamed: "panel") static var overlay: SurfaceKind { .panel }`
可编译，调用方只得 warning）。**我们放弃了这个代价更低的路径**，换取名字彻底消失。

### 迁移

`.surface(.overlay)` → `.surface(.panel)`，**渲染结果逐位相同**。

⚠️ 本仓内 `SurfaceKind.overlay` **零调用点**（`App/` / `docs/component-registry.json` /
`docs/components/*.md` 均无）。⚠️ **理由要写准**：`git grep '\.overlay\b'` 的其余命中
**绝大多数是 SwiftUI 的 `View.overlay { }` / `.overlay(alignment:)` modifier 调用**
（AvatarGroup / Badge / Skeleton / BorderModifier 等十几个文件），另有少数属于
`SpinningPresentation` —— 初稿把它们**全部**说成 `SpinningPresentation`，那是错的。
⇒ 删除对本仓零改动，只影响外部调用方。

### 菜单 / popover 该用什么

⚠️ **不在 `SurfaceKind` 的射程内** —— 走系统 `Menu` / `.popover`（iOS 26 原生玻璃）。

⚠️ **初稿这里写的是「thick material 或 `floatingGlass`」，那是指向空处**：
`thick material` **不是本库的任何 API 或 token**（指的是裸 SwiftUI `.thickMaterial`）；
`floatingGlass` 在本仓的消费点全是 `Toast` / `FloatButton` / `Sidebar` 选中行 /
`BottomInputBar` 这类**小面积浮动 chrome**，**没有任何菜单 / popover / 大面积文字层的
用法、预览或判据** ⇒ 它能不能承载菜单，本仓**没有证据**。
⇒ 与其把人指向一个未经验证的替代品，不如明说这件事**不由 `SurfaceKind` 承担**。

⚠️ 顺带登记一条设计决定的变更：`docs/superpowers/specs/2026-05-14-native-primer-telegram-taste-design.md`
里「popover 与 menu | floating | overlay」那一行，在 `.overlay` 删除后**在 `SurfaceKind` 里
不再有对应**。

## `0.10.0`（2026-09-09）——Issue #271：NFR-7 通用能耗策略表下沉

**含破坏性变更** —— `OhMyDesignEffects` **删除 31 条** public 声明、新增 5 条；
`OhMyDesign` 删除 **0** 条、新增 28 条。两侧数字由 `scripts/api-surface-diff.sh` 各跑一次得出：

```bash
MODULE=OhMyDesignEffects bash scripts/api-surface-diff.sh <base>   # 删除侧
bash scripts/api-surface-diff.sh <base>                            # 新增侧（默认 MODULE=OhMyDesign）
```

⚠️ **必须跑两次**：脚本的 `MODULE` 默认是 `OhMyDesign`，只跑默认那次**看不到任何删除**
——本次的删除全在 `OhMyDesignEffects`。

### 主题：把「任何常驻渲染件都要」的那半张表移出动效层

原裁决（`#252`）逐字：「别让只想要 shader 的消费者链上整个 `OhMyDesignEffects` product」。
当时只下沉了两个**信号键**，而从信号推出「画不画 / 降不降帧」的策略表仍在 Effects
⇒ `shipswift-shaders` 的 B-2 只有两条路：`import OhMyDesignEffects`（推翻下沉的全部理由），
或自己把同一条映射再写一遍（本仓反复在堵的「两处各写一遍必然漂」）。

| 删除（`OhMyDesignEffects` 的 **public** 声明） | 替代（`OhMyDesign`） |
|---|---|
| `EffectsEnergyState` | `EnergyState` |
| `EffectsEnergyState.init(scenePhase:powerMode:)` | `EnergyState.init(scenePhase:isLowPower:)` |
| `EffectsEnergyState.powerMode`（属性） | `EnergyState.isLowPower`（`Bool`） |
| `EffectsEnergyState.scenePhase` | `EnergyState.scenePhase`（不变） |
| `EffectsEnergyState.policy` | `EnergyState.policy` |
| `EffectsEnergyState.resolve(injectedScenePhase:systemScenePhase:injectedPowerMode:)` | `EnergyState.resolve(injectedScenePhase:systemScenePhase:lowPowerModeOverride:)` |
| `EffectsRenderPolicy`（含三个 case） | `RenderPolicy` |
| `EffectsRenderPolicy.drawsAnything` / `.minimumInterval` | `RenderPolicy` 同名成员（下沉） |
| `EffectsRenderPolicy.usesGlow` / `.particleScale` | **仍在 Effects**，改挂 `extension RenderPolicy` |
| `EffectsPowerMode`（整个类型，含 `.standard` / `.lowPower`） | **无替代** —— 边界改用 `Bool` |
| `EffectsPowerMode.current` | `ProcessInfo.processInfo.isLowPowerModeEnabled` |

⚠️ **本表只列 public 声明**。`#271` 同时改名 / 移动了几个 **internal** 声明
（`EffectsPresentation` → `MotionPresentation`（并**转为 public**）、其 `.none` → `.hidden`、
`frozenIfPeriodIsDegenerate(_:)`、`presentation(reduceMotion:)`、`EffectsPowerMode.lifted(from:)`），
**对下游不构成破坏** —— 它们在 `main` 上就取不到。列在这里只为改名时能查到去向。

### 两处需要动手改的

1. **`powerMode:` → `isLowPower:`**：`EffectsPowerMode` 已删除，边界改用 `Bool`。
   读 `EffectsPowerMode.current` 的调用点改读 `ProcessInfo.processInfo.isLowPowerModeEnabled`；
   环境键 `\.lowPowerModeOverride` 本身就是 `Bool?`，直接传即可。
2. **`import`**：只用通用策略表的消费者现在**只需 `import OhMyDesign`**
   —— 这正是本次改动的全部目的。

### 为什么不留 typealias 兼容层

最硬的理由不是「0.x 先例」，而是**模块外实际消费者为零**
—— 唯一消费者是 `scripts/downstream-probe` 自己。留别名等于把两个名字都变成永久承诺。

### 一并付出的代价

`OhMyDesign` 新增 **3 条** Bool 豁免（`EnergyState.init#isLowPower` /
`resolve#lowPowerModeOverride` / `presentation#reduceMotion`），棘轮基线 32 → 35。
⚠️ **本仓惯例是每轮把棘轮压小，本次是反向抬 3**，逐条理由见 `docs/bool-exemptions.json`。

---

## `0.10.0`（2026-09-09）——画廊场景化配色 PR

**纯新增 + 一处行为变更 + 一处已修正的观感回归。**

### 行为变更（对下游编译零感知，但语义变了）

`.spinning(..., presentation: .topBar)` **不再响应外层 `.tint(_:)`**，改走 `tint:` 参数。

原本 `.topBar` 的顶条用 `.fill(.tint)` 从**环境**取色，而 `.overlay` / `.inline` 经
`ProgressIndicator` 走内层显式 tint、本就吞掉外层 `.tint(_:)` ⇒ 同一 modifier 的三个形态
取色行为分裂（`SpinningModifier` 自己的文档把这条当作「为什么自绘」的反对论据之一）。
本次把三者统一到 `tint:` 参数通路。**下游若写过
`.spinning(true, presentation: .topBar).tint(.orange)`，需改成
`.spinning(true, presentation: .topBar, tint: .orange)`** —— 不报错，只是不再变橙。

### 新增（对已应用调用点零影响）

| 符号 | 变更 |
|---|---|
| `RingChart.init(_:goal:title:tint:colors:)` | 新增 `colors: [Color] = []`，逐环取色。⚠️ **正交性代价**：`colors` 非空时 `tint` 完全不生效 |
| `ProgressIndicator.init(tint:)` / `init(text:tint:)` ×2 | 三个 init 各新增 `tint: Color = .accent` |
| `View.spinning(_:text:presentation:tint:)` | 新增 `tint: Color = .accent` |
| `SpinningModifier.tint` / `.init(..., tint:)` | 新增 `public let` 与 init 参数 |
| `TopBarIndicator.tint` | 新增（internal 类型） |

⚠️ **一处罕见的源码破坏**：带默认值的参数对**已应用**的调用点零影响，但对**未应用**的
`.init` 引用是硬破坏。实测 `let f: () -> ProgressIndicator = ProgressIndicator.init`
报 `cannot convert value of type '(Color) -> …' to specified type '() -> …'`。
`scripts/downstream-probe` 全绿（`EXIT=0`），但它只覆盖已应用调用点，对这条无射程。

### 已修正、未外泄的观感回归

`RingChart` 轨道一度写成 `ringColor(at:).opacity(0.18)`，而 `ringColor` 在 `colors` 为空时
已压过一次阶梯 ⇒ **二次相乘**，第 6 环轨道 α 从 0.18 掉到 0.018（10 倍）。
终审 C-1 抓到，已改为取本环**基色**再压 0.18，`colors` 为空时逐字节等于旧值。
判据 `RingChartColorsGuard.emptyColorsKeepsTrackOpacityConstant` 钉住这条。

---

## `0.10.0`（2026-09-09）——`coredesign-leftover-closeout` epic，Issue #220

**对下游编译零感知，仅改观感。** 不删除、不重命名任何公开符号；三处「同名换值」。

### 同名换值

#### `Color.surfacePanel` / `Color.surfaceOverlay` / `Color.surfaceSidebar`（Issue #220）

| token | 旧实现 | 新实现 | 服务的 `SurfaceKind` |
|---|---|---|---|
| `surfaceSidebar` | 别名 `surfaceCanvasSubtle`（= `secondarySystemGroupedBackground`） | 别名 `surfaceElevated`（= `tertiarySystemGroupedBackground`） | `.sidebar` |
| `surfaceOverlay` | 别名 `surfacePanel`（→ 背景族） | 别名 `secondaryFill`（**填充族，半透明**） | `.floating` |
| `surfacePanel` | 别名 `surfaceCanvasSubtle`（背景族） | 别名 `quaternaryFill`（**填充族，半透明**） | `.overlay` / `.panel` |

**影响**：

- **对下游编译零感知**——符号名、类型签名均未变，`scripts/downstream-probe` 探测不到。
- **视觉上**：`.surface(.floating)` / `.surface(.overlay)` / `.surface(.panel)` 的背景由**不透明**变为**半透明填充**，其下内容会透出；`.surface(.sidebar)` 换一档背景色。若下游直接调用了这三个 case、或直接引用 `Color.surfacePanel` / `surfaceOverlay` / `surfaceSidebar`，观感会随之改变。
  - ⚠️ 半透明档位**不宜再叠 `.coreShadow(_:)`**——阴影会从半透明背景透上来把表面压脏。需要不透明浮层请用 `floatingGlass` 或 `.surface(.content)`。
- **落地时库内的生产消费点**：`.floating` / `.overlay` / `.panel` / `.sidebar` 四个 case 在**产品代码路径上的 `.surface()` 调用点为零**（唯一消费者是 `SurfaceModifier.swift` 的 `SurfacePreviewGallery` 这个库内 `#Preview`）。真实观感改动落在 App 预览宿主的 6 处直接 token 消费点（`ComponentDetail.swift` 三处 `surfacePanel`、`ContentView.swift` / `Previews.swift` / `ComponentData.swift` 各一处 `surfaceSidebar`）。

**动机**：`SurfaceKind` 声称提供多档「表面角色」，但改动前 **10 个 case 只解析到 3 个 distinct 背景**（iOS 浅色与深色实测均为 3）——8 个 case 共用 `secondarySystemGroupedBackground`。修法承 #122 对 Badge 同型缺陷的裁决：**叠在别人之上的表面用 `FillColors`（半透明），充当底层的才用 `SurfaceColors`**；单纯改背景族的取值凑不出更多档位，因为 iOS 背景族在单一外观下只有 2（浅色）/ 3（深色）个取值。

**三档填充的 α 实测值**（iPhone 17 Pro / iOS 26.4 模拟器，Issue #220 实测钉死）：

| 填充档 | 服务的 kind | 浅色 | α | 深色 | α |
|---|---|---|---|---|---|
| `secondaryFill` | `.floating` | `#78788029` | 0.161 | `#78788052` | 0.322 |
| `tertiaryFill` | `.control` | `#7676801F` | 0.122 | `#7676803D` | 0.239 |
| `quaternaryFill` | `.overlay` / `.panel` | `#74748014` | 0.078 | `#7676802E` | 0.180 |

三档 RGB 几乎相同（`#787880` / `#767680` / `#747480`），**区分几乎全靠 α**。

改后 distinct 数（**必带平台与外观限定**）：**iOS 深色 6 / iOS 浅色 4 /
macOS 身份层 5、取值层 4**。

> ⚠️ **「iOS 浅色 5」是本行原写的数，已失真**：`#225`（`eb3efbd`）把 `.floating` 改成
> **按外观分道**后，iOS 浅色的 `.floating` 落到 `systemBackground`、与 `.content` 同值
> ⇒ distinct 由 5 变 4，判据 `SurfaceContrastTests.surfaceKindTokensAreFourDistinctInLight` 同次改成
> `resolved.count == 4`（**引方法名不引行号**——行号会漂，见 `#337`）。
> 而 `eb3efbd` **一个 docs 文件都没碰**（`git show --stat`）⇒ 这份活文档漏接了那次更正，
> 直到 `#239` 才补上。

> ⚠️ **三个数字不同量纲**：iOS 两个是 `Color.Resolved` **逐位**实测（模拟器上取值）；
> **macOS 那个 5 是 token 身份层**的数——只比 `Color` 承载的 `NSColor` 是否同一常量。
> ⚠️ **macOS 侧的取值层数字是 4，不是 5**（`#239` 实测）：`.canvas` 与 `.content` / `.card` /
> `.grouped` / `.canvasSubtle` / `.sidebar` 五路**解析值逐位相同**，`windowBackgroundColor`
> 与 `controlBackgroundColor` 在本代 macOS 上同值 ⇒ 取值层是「五路碰撞 + 三档 fill」= 4。
> ⚠️ 本行原写「AppKit 无 WindowServer 会话时颜色会塌成同一 fallback RGBA，故 macOS 侧刻意
> 不解析」——`#239` **两句都推翻**：macOS 侧现在有无条件的取值层判据（在 CI 上跑），
> 而那个前提复现不出来（拒掉 windowserver 的 mach-lookup 后取值逐位不变；拒读
> `SystemAppearance.bundle` 是硬崩不是塌缩）。逐条见 `docs/DESIGN-FOUNDATION.md`。
> 已知的相等项均为系统色族的物理下限，已钉成显式断言：iOS 浅色 `.canvas == .sidebar`
> **与 `.floating == .content`**（后者是 `#225` 分道的结果，正是让浅色 5 变 4 的那一对）；
> macOS 下 `.content` / `.card` / `.grouped` / `.canvasSubtle` / `.sidebar` 五路同落
> `controlBackgroundColor`；全平台 `.overlay == .panel`（二者走同一 token，border 与 radius 也相同）。

> **本条只担保「解析值不同」，不担保「肉眼可辨」**。三档填充的 RGB 几乎相同、只靠 α 区分，逐位判据会平凡通过；观感结论由视觉复核（Issue #225）给出。

## `0.9.0`（形态参数化：7 个 API 各加一个带默认值的形态参数，2026-09-01）

**含破坏性变更 —— 但只对一种调用形态。** 删除 **7 条 public 声明**、新增 56 条。
本节清单**不是凭 diff 印象写的**：由 `scripts/api-surface-diff.sh` 从 `v0.8.0` 与 `v0.9.0`
各提取一次 public 表面后做集合差得出（比较键是 `(usr, declAttributes)`，见该脚本文件头
「不要把比较器换回 `swift-api-digester -diagnose-sdk`」那段——它是**破坏性变更检测器**，
新增声明一行都不报）。`v0.8.0..v0.9.0` 共 143 个提交。

复现：

```bash
git worktree add /tmp/cd-v090 --detach v0.9.0
cp <本仓>/scripts/api-surface-diff.sh /tmp/cd-v090/scripts/   # v0.9.0 的树上 scripts/ 已存在
( cd /tmp/cd-v090 && bash scripts/api-surface-diff.sh v0.8.0 )
git worktree remove --force /tmp/cd-v090                      # worktree 记录留在调用者仓库里，要清
```

（`api-surface-diff.sh` 是 `#245` 之后才加的，v0.9.0 的树上没有该文件，需拷进去。）

⚠️ **本块只覆盖 `OhMyDesign` 一个模块**（脚本的 `MODULE` 默认值）。对 v0.9.0 是完整的
——`v0.8.0` 与 `v0.9.0` 的 `Package.swift` **都只有一个 library product**，多 target 是
v0.9.0 之后才拆的。⇒ **下一个版本照抄本块会静默只测三分之一**，多 product 之后须
`MODULE=OhMyDesignEffects bash …` 之类对每个 module 各跑一次。

### 本次无同名换值 / 行为变更

⚠️ **上面那个脚本对这一类结构性失明**：它比的是 `(usr, declAttributes)`，
符号名与签名不变的取值 / 观感变更**一条都不报**——与本文件后面警告的
`downstream-probe` 盲区同型。所以「跑了脚本」不等于「全查过」。以下是另行查证的结果：

- `git diff --name-only v0.8.0 v0.9.0 -- Sources/` 共 **7 个文件**：`AvatarGroup` /
  `Sidebar` / `Steps` / `Timeline` / `Toast` 五个组件 + `SpinningModifier` +
  `en.lproj/Localizable.stringsdict`；**`Tokens/` 与 `Colors/` 零改动**。
- `Timeline.nodeColumnWidth` **取值**仍是 24（声明多了 `nonisolated`，值未动）；
  `AvatarGroup` 的 `overlapOffset`（−6 / −8 / −10）与 `avatarSize`（20 / 24 / 32 / 40）
  两张 ramp 表逐行相同。
- 20 个新 enum case **全部归属那 6 个新枚举**，既有 public enum 一个 case 都没加
  ⇒ `0.8.0` 节里 `SurfaceKind.grouped` 那条「加 case 打断下游穷尽 switch」的坑本次不适用。

### 主题：把「只有一种长相」的组件参数化成多形态

7 处删除同源——都是给已有的 init / modifier **插入一个带默认值的形态参数**，
并配套新增一个语义枚举：

| v0.8.0 | v0.9.0 | 新增的形态枚举 |
|---|---|---|
| `AvatarGroup.init(max:avatars:)` | `init(max:layout:avatars:)` | `AvatarGroupLayout`（`overlapped` / `spaced` / `grid` / `countOnly`） |
| `Timeline.init(items:)` | `init(items:layout:)` | `TimelineLayout`（`vertical` / `alternate` / `horizontal` / `grouped`） |
| `Steps.init(items:currentIndex:axis:indicatorStyle:)` | `…:presentation:)` | `StepsPresentation`（`steps` / `segmentedBar` / `navigation` / `text`） |
| `SidebarUtilityRow.init(systemImage:title:trailingSystemImage:action:)` | `…:trailingSystemImage:presentation:action:` | `SidebarUtilityRowPresentation`（`iconLeading` / `textOnly`） |
| `SpinningModifier.init(isActive:text:)` | `init(isActive:text:presentation:)` | `SpinningPresentation`（`overlay` / `topBar` / `inline`） |
| `View.spinning(_:text:)` | `spinning(_:text:presentation:)` | 同上 |
| `View.toastHost(edge:)` | `toastHost(edge:presentation:)` | `ToastPresentation`（`floatingCapsule` / `fullWidthBanner` / `centeredHUD`） |

### 迁移：绝大多数调用方**不需要改任何东西**

新参数都带默认值，且默认值就是 v0.8.0 的行为 ⇒ **已应用**的调用点逐字不动即可编译。

⚠️ **唯一会红的是「未应用」的函数引用**（把 init / 方法当一等函数值传递）。实测：

```swift
// v0.8.0 上通过，v0.9.0 上硬红
let items: [TimelineItem] = []
let make: ([TimelineItem]) -> Timeline = Timeline.init
_ = make(items)
```

报错形态：

```
cannot convert value of type '([TimelineItem], TimelineLayout) -> Timeline'
                 to specified type '([TimelineItem]) -> Timeline'
```

⚠️ **前缀随调用方的隔离语境变，别拿上面这行逐字 grep 自己的报错**（三种语境实测）：

| 调用方语境 | 报错里的类型 |
|---|---|
| nonisolated | `([TimelineItem], TimelineLayout) -> Timeline` |
| `@MainActor` | `@MainActor ([TimelineItem], TimelineLayout) -> Timeline` |

**迁移写法**：改成显式闭包，把默认值补齐。

```swift
let make: ([TimelineItem]) -> Timeline = { Timeline(items: $0) }
```

⚠️ **两处参数是插在中间而不是追加的**（`init(max:` **`layout:`** `avatars:)`、
`…trailingSystemImage:` **`presentation:`** `action:`），对已应用的调用点仍无影响。
⚠️ 理由**不是**「Swift 按标签匹配」——**那是假的**，实测
`S(currentIndex: 0, items: [])` 报 `argument 'items' must precede argument 'currentIndex'`。
真实理由是：**插入保持了原有标签之间的相对顺序**，且新参数有默认值可省略。
（照「按标签匹配」推会得出「签名随便重排也安全」这个相反结论，故此处写明。）

⚠️ 未应用引用的破坏面里，现实中真会被伤到的是 `Timeline.init` 与
`SidebarUtilityRow.init`；`AvatarGroup.init` 的 `avatars` 是
`@ViewBuilder … @escaping () -> Avatars` 且类型泛型于 `Avatars`，几乎不会有人对它做未应用引用。

### 新增（非破坏）

| 构成 | 数 |
|---|---|
| 6 个语义枚举（`TypeNominal`） | 6 |
| 它们的 enum case | 20 |
| `hashValue` / `hash(into:)` / `__derived_enum_equals`（各 6） | 18 |
| `AllCases` / `allCases`（只有 `ToastPresentation` 与 `SidebarUtilityRowPresentation` 是 `CaseIterable`） | 4 |
| 新签名的 init | 5 |
| 新签名的 modifier（`spinning` / `toastHost`） | 2 |
| **`SpinningModifier.presentation`** | **1** |
| 合计 | **56** |

⚠️ 最后一条容易漏：`SpinningModifier` 是六个组件里**唯一**把形态参数也暴露成
`public let` 的，其余五个的对应存储属性是 internal、根本不进 dump。
⇒ 下游多了一个可读的公开属性。

> **为什么是一次 minor 而不是 1.0.0**：本库 0.x 阶段以 minor 携带破坏性变更，
> `v0.3.0`（6 个组件删除 + `Blossom` trait 删除 + 9 个字体 token 改名，见下方该节自述）、
> `v0.5.0` / `v0.6.0` / `v0.8.0` 已有**四次**先例。
> ⚠️ `0.8.0` 节写的「已有两次先例」同样少算了 `0.3.0`；头部 tag 清单里 `v0.3.0`
> 也没有「含破坏性变更」标记，与该节自述冲突——**既存不一致，本次未收**。

---

## `0.8.0`（`component-contract` epic 试点改造，2026-08-16）

**含破坏性变更** —— 删除 **9 条 public 声明**（归为 5 组），另有 1 处「加枚举 case 但可能打断下游构建」。
本节的清单**不是凭 diff 印象写的**：由脚本从 `v0.7.0` 与发布 commit 的源码各提取一次 public
表面后做集合差得出（public 声明 642 → 652，public enum case 60 → 63），脚本全文见
`oh-my-story` 仓 `.claude/epics/component-contract/42-spec.md` 的附录。

> **为什么是一次 minor 而不是 1.0.0**：本库 0.x 阶段以 minor 携带破坏性变更，`v0.5.0`
> （文本入参统一）、`v0.6.0`（`Separator.Inset` 改名）已有两次先例，见下方各节。

### 主题：把「压扁成 Bool 的取值域」还原成语义类型

本次 5 组破坏性变更同源——它们都是把一个 `Bool` 参数还原成它真正表达的东西：
语义枚举、连续量、或干脆是两个不同的组件。判定依据是本 epic 产出的组件公约
（`docs/component-contract.md`）第 3 节的四条替代路径。

---

#### B1. `View.surface(_:bordered:)` → 删除 `bordered` 参数

```swift
// 变更前
func surface(_ kind: SurfaceKind, bordered: Bool = true) -> some View
// 变更后
func surface(_ kind: SurfaceKind) -> some View
```

**迁移**：`bordered: false` 表达的其实是「换一种容器角色」，改用新增的 `SurfaceKind.grouped`：

```swift
// 旧
.surface(.content, bordered: false)
.surface(.content, bordered: true)     // 或省略
// 新
.surface(.grouped)                     // 背景 + 圆角、无描边，等价于原 bordered: false
.surface(.content)                     // 背景 + 描边 + 圆角，等价于原 bordered: true
```

⚠️ `.grouped` 与原 `.content, bordered: false` **三个维度逐字等价**（背景 `surfaceCard`、
描边 `.clear`、圆角 `CoreRadius.medium`），视觉无变化。

⚠️ **但等价只在 `.content` 上成立**：`bordered` 是与全部 9 个 kind 正交的参数，
`.surface(.overlay, bordered: false)` / `.surface(.card, bordered: false)` 这类组合
**在新 API 下没有等价替代**。之所以只补 `.grouped` 一个 case 而不铺满 9×2 的积空间：
**本仓 + 跨仓（StoryUI）实测 7 处产品调用点 100% 落在 `.content` 上**——按用到的点建模、
不按可能的组合建模。（口径：**产品代码**的显式调用点，不含测试与 `#Preview`；
其中 OhMyDesign 侧 1 处、StoryUI 侧 6 处。）
若你在用其他 kind 的无描边组合，请提 issue——那会是一个新的容器角色，需要单独命名。

#### B2. `Card(bordered:)` → `Card(kind:)`

```swift
// 变更前
public init(padding: CGFloat = CoreSpacing.lg, alignment: Alignment = .leading,
            bordered: Bool = true, @ViewBuilder content: () -> Content)
// 变更后
public init(padding: CGFloat = CoreSpacing.lg, alignment: Alignment = .leading,
            kind: CardKind = .content, @ViewBuilder content: () -> Content)
```

**迁移**：

```swift
Card(bordered: false) { … }   →   Card(kind: .grouped) { … }
Card(bordered: true)  { … }   →   Card() { … }
```

⚠️ **`CardKind` 只有 `.content` / `.grouped` 两个 case，刻意不暴露完整 `SurfaceKind`**——
`Card` 是 `.content` 的薄封装，开放 `.canvas` / `.sidebar` 会把它拓宽成万能容器，
且 `Card(kind: .canvas)` 正是 Issue #140「卡片贴画布导致隐形」的形态。

#### B3 / B4. `SolidButtonStyle` 与 `LightButtonStyle` 删除 `glass` 开关

各删 3 条声明（存储属性 + init 参数 + 静态工厂参数）：

```swift
// 变更前
public init(role: ButtonRoleStyleRole = .primary, glass: Bool = false)
public let glass: Bool
static func solid(role: ButtonRoleStyleRole = .primary, glass: Bool = false) -> SolidButtonStyle
static func light(role: ButtonRoleStyleRole = .primary, glass: Bool = false) -> LightButtonStyle
// 变更后
public init(role: ButtonRoleStyleRole = .primary)
static func solid(role: ButtonRoleStyleRole = .primary) -> SolidButtonStyle
static func light(role: ButtonRoleStyleRole = .primary) -> LightButtonStyle
```

**迁移**：

```swift
// glass: false（默认值）——纯删参，行为完全不变
.buttonStyle(.solid(role: .primary, glass: false))   →  .buttonStyle(.solid(role: .primary))
.buttonStyle(.light(role: .secondary, glass: false)) →  .buttonStyle(.light(role: .secondary))
```

⚠️ **`glass: true` 没有行为保持的替代写法，别做机械替换。**
删掉的是 legacy Telegram 玻璃模式。**两个 style 的 glass 分支渲染并不相同**，迁移前先看清你用的是哪个：

| | 形状 | 宽度 | 玻璃底色 | 前景 |
|---|---|---|---|---|
| `SolidButtonStyle` 的 glass | Capsule | 随 label 伸展 | **role 色**（`backgroundStyle(backgroundColor)`） | 纯白 |
| `LightButtonStyle` 的 glass | Capsule | 随 label 伸展 | `Color.surfaceInteractive` | **role 色** |
| 保留的 `CircularGlassButtonStyle` | **Circle** | **固定直径 frame**（`.large` 默认 50pt） | `Color.surfaceInteractive` | 不设 |

> 表内「前景」为 **enabled 态**；禁用态三者处理各不相同（Solid glass 走 `contentDisabled`、
> Light 经 `role.resolvedColor` 内部处理、CircularGlass 用 `.opacity(0.4)`）。

⇒ `CircularGlassButtonStyle` **不是任何一个的等价物**：与 Solid 的 glass 差三处
（形状、固定尺寸、role 底色不携带），与 Light 的 glass 差两处（形状、固定尺寸——底色反而一致）。
把带文字 label 的 capsule 玻璃按钮直接换成它，会被压进一个圆里；Solid 侧还会额外丢掉 role 配色。

若你确实在用 `glass: true`，按场景三选一：
- **① 放弃玻璃观感** —— 改用普通 `.solid(role:)` / `.light(role:)`；
- **② 圆形 icon 按钮场景** —— 改用 `CircularGlassButtonStyle`。**对原 `LightButtonStyle(glass:)`
  的使用者尤其顺**，底色本来就一致，只需接受圆形与固定尺寸。
  ⚠️ 但原 Light glass 的 **role 色前景是由 style 施加的**，`CircularGlassButtonStyle` 不设前景
  ⇒ 迁移后需自行在 label 上补 `.foregroundStyle(…)`；
- **③ 需要逐字保持旧渲染** —— 自建 style，用 `.backgroundStyle(_:)` 配你要的底色 +
  `TelegramGlassButtonModifier`（**仍是 public、本次未改动**）重建即可。

⚠️ 这是**唯一一组走「论证删除」而非「记豁免」的变更**。公约第 3 节的终局条款是**有序**的：
先试**条款 (b)「论证可以删除」**；只有 (b) 不成立时，才退而用**条款 (a)「记入豁免清单」**。
本次跨仓复核确认 `glass:` **对外零调用点**（预览宿主、downstream-probe、StoryUI 全仓零命中）
⇒ 条款 (b) 成立，直接删除。

> 注：上面迁移出口的 ①②③ 与这里的公约**条款 (a)/(b)** 是两套互不相干的编号，别对应着读。

⇒ 由于对外零调用点，本组迁移说明预计不影响任何已知下游，是写给未知使用者的。

#### B5. `Rating(allowsHalfStar:isReadOnly:)` → `Rating(step:)` + 新组件 `RatingDisplay`

```swift
// 变更前
public init(value: Binding<Double>, count: Int = 5,
            allowsHalfStar: Bool = false, isReadOnly: Bool = false)
// 变更后
public init(value: Binding<Double>, count: Int = 5, step: Double = 1.0)
```

**迁移（两条，分别对应两个被删参数）**：

```swift
// ① allowsHalfStar → step：Bool 其实是被压扁的连续量（原实现内部就是 allowsHalfStar ? 0.5 : 1.0）
Rating(value: $v, allowsHalfStar: true)   →  Rating(value: $v, step: 0.5)
Rating(value: $v, allowsHalfStar: false)  →  Rating(value: $v)          // step 默认 1.0
Rating(value: $v, step: 0.25)             // 新能力：任意步进粒度，不再只有两档

// ② isReadOnly → 换组件（⚠️ 不是 .disabled(true)，见下）
Rating(value: .constant(4), isReadOnly: true)  →  RatingDisplay(value: 4)
```

⚠️ **`isReadOnly: true` 的迁移目标是 `RatingDisplay`，不是 `.disabled(true)`。**
`.disabled(true)` 走的是 SwiftUI 原生 disabled 视觉——**变灰 + 降对比度**，语义是
「这个控件现在不能用」；而只读评分的典型用途是**展示态**（列表里显示某本书的评分），
它不是「不能用」，是「本来就不是控件」。用 `.disabled(true)` 迁移会让所有展示态评分变灰，
是语义错配导致的视觉回归。拆成两个类型之后，「控制展示态」只剩一条路径：**选哪个类型**。

⚠️ `step` 的入参校验走 clamp 不 trap：`step <= 0` 或非有限值（如 `.infinity`）会被
clamp 回 `1.0`，不会崩溃。

---

### ⚠️ 非删除、但可能打断下游构建：`SurfaceKind` 新增 `.grouped`

```swift
public nonisolated enum SurfaceKind: Sendable, Equatable {
    case canvas
    case content
    case control
    case floating
    case overlay
    case grouped        // ← 本版本新增（声明位置在 overlay 与 canvasSubtle 之间）
    case canvasSubtle
    case panel
    case sidebar
    case card
}
```

`SurfaceKind` 是 public、非 `@frozen` 的 enum，且 OhMyDesign 以 SwiftPM 源码分发、
**不开 library evolution** ⇒ **下游若对它做穷尽 `switch`，加一个 case 就编译不过**
（`switch must be exhaustive`）。

**迁移**：给这类 `switch` 补 `default:` 或 `case .grouped:` 分支。

> 之所以把它单列而不是塞进「新增」段落：它是本次唯一一个**不在删除清单里、却可能打断
> 下游构建**的变更。本仓自查 `scripts/downstream-probe` 对 `SurfaceKind` 是透传、无穷尽
> switch，故 CI 不会因此变红——但下游第三方使用者不受此保护。

### 新增（非破坏性）

- **`CardKind`** —— `Card` 的容器观感取值域（`.content` / `.grouped`）。
- **`RatingDisplay`** —— 只读评分展示组件（indicator）：`RatingDisplay(value:count:)`，
  无 binding、无手势、无 accessibility adjust action。
- **`RatingStyle` 样式扩展点** —— `RatingStyle` 协议 + `RatingStyleConfiguration` +
  `StarRatingStyle`（默认实现）+ `View.ratingStyle(_:)`，形态与既有 `BannerStyle` 一致。
  `Rating` 与 `RatingDisplay` 共用同一个扩展点。
  ⚠️ **`RatingStyleConfiguration` 没有 public init**（与 Apple 的 `ButtonStyleConfiguration`
  一致）——下游自定义 style 时无法自造 configuration 做预览/单测，只能经 `Rating` /
  `RatingDisplay` 渲染触发。

### 本次无 B 类变更（文本参数 → `LocalizedStringResource`）

本版本**没有任何裸 `String` 文本参数转 `LocalizedStringResource`**，故不涉及
`Bundle.main` 解析语义的变化。两条证据：

1. FR-4 判据的四条计数全程未变（`registryTextParams == 30` / `covered == 29` /
   `localizedByType == 11` / `carrying == 8`）；
2. ⚠️ 计数不变只约束**基数**不约束**集合**（一进一出会全部不动），故另有 diff 级证据：
   `v0.7.0..HEAD` 的 `Sources/` 全量 diff 中**零文本参数签名变更、零 `LocalizedStringResource`
   增删**；新增的 `RatingDisplay.init(value:count:)` 不带文本参数。

## `0.7.0` 收口部分（`semi-mobile-components` 收尾，**已随 v0.7.0 发布**）

> 这一节曾标为「`0.7.1`（未发布）」。实际情况是：`v0.7.0` 的 tag 打在了 `9df7b68`，
> 而 `9df7b68` **正是引入下面这些改动的那个 commit**——所以它们已经在 `v0.7.0` 里了，
> 从来没有单独的 0.7.1。之所以标错，是因为发 `v0.7.0` 时跳过了本仓一贯的
> 「docs(release): X 定稿」步骤（对照 `v0.6.0` 的 `eab5ecc`），文档没来得及去掉「未发布」。
> 下游读 `v0.7.0` 的 release notes 时不要以为这些修正不在自己的构建里。

**非破坏性** —— 仅取色语义修正与测试补充，无 API 变更，对下游零破坏。

- **`CheckBox` / `Radio` 未选中态取色**（Issue #189）：从硬编码 `Color.gray`（`systemGray`，固定不透明）改为语义 token `Color.contentSecondary`（桥接系统 `.secondaryLabel`）。`CheckBox` 自 `v0.1.0` 发布，本次一并对齐（两组件文档均声明「同一套 token」，只改其一会造成成对组件视觉分叉）。观感变化：纯色背景下肉眼几乎不可辨；在 raised/tinted 背景上因 `.secondaryLabel` 的半透明特性会有轻微原生混色，并新增 Increase Contrast 无障碍适配——属修正硬编码色、非破坏。
- **`DynamicTypeLayoutTests` 补 Rating/Radio/TagInput/Timeline 大字号断言**（Issue #188）：仅测试新增。

## `0.7.0`（`semi-mobile-components` epic 收尾，2026-07-27）

**非破坏性** —— 全部为纯新增，无删除/改名/签名变更，对下游零破坏，无需迁移。

### 新增组件（10 个，`semi-mobile-components` epic Phase 1，Issue #162–#171）

| 组件 | 说明 | 文档 |
|---|---|---|
| `Skeleton` / `SkeletonLine` / `SkeletonRect` / `SkeletonCircle` + `View.skeletonShimmer()` | 骨架屏容器 + 占位形状 + shimmer 扫光 modifier | [skeleton.md](components/skeleton.md) |
| `Steps` / `StepItem` / `StepsAxis` / `StepsIndicatorStyle` | 横向 / 纵向步骤条，点状 / 数字两种指示器 | [steps.md](components/steps.md) |
| `Timeline` / `TimelineItem` | 纵向时间线，默认圆点或自定义节点 | [timeline.md](components/timeline.md) |
| `Rating` | `Binding<Double>` 星级评分，支持半星步进 + 只读 | [rating.md](components/rating.md) |
| `PinCode` | 验证码 / PIN 分格输入，隐藏 `TextField` 承接系统键盘 | [pin-code.md](components/pin-code.md) |
| `RadioGroup` / `RadioOption` | 互斥单选组，与 `CheckBox` 成对的视觉语汇 | [radio.md](components/radio.md) |
| `TagInput` | 标签输入框：`Tag` chip + 内联 `TextField` | [tag-input.md](components/tag-input.md) |
| `Descriptions` / `DescriptionsColumns` / `DescriptionsDividerDensity` | 描述列表：`.core LabeledContentStyle` + `InsetGroupedSection`，1/2 列 + 大字号自动塌列 | [descriptions.md](components/descriptions.md) |
| `ExtendedFloatButtonStyle` + `.extendedFloat` / `.extendedFloat(size:)` | 胶囊玻璃悬浮按钮样式（与既有 `CircularGlassButtonStyle` 并列） | [float-button.md](components/float-button.md) |
| `Carousel` | 走马灯：`ScrollView` 分页滚动 + 自动轮播 + 页点指示器 | [carousel.md](components/carousel.md) |

### 增强（Issue #172）

- `ProgressIndicator` 新增 `init(text: LocalizedStringKey)` 与 `init<S: StringProtocol>(text: S)`——可选文案渲染于 spinner 下方；原 `init()` 签名不变（NFR-6 无破坏）。带文案时 accessibility label 播报文案本身而非固定 `"Loading"`（收口修复，见下）。
- `SpinningModifier` + `View.spinning(_:text:)`——为任意内容整体叠加加载遮罩（吸收 Semi Design `Spin` 能力）。

### Typography 墓碑

`Typography`（PRD 原 12 组件候选之一）判定 parity 已由 `.coreFont(_:)` + 原生 `Text` modifier 达成，
不作为独立组件实现，见 [typography.md](components/typography.md)。

### Phase 1 评审累积收口项（Phase 3 / #173 统一处理）

- `Radio` 单选圆点 SF Symbol 从遗留名 `largecircle.fill.circle` 改为推荐名 `circle.inset.filled`。
- `TagInput` 的 `"Add tag"` Phase 0 预登记键确认为死键（组件 verbatim 消费 placeholder，仿 `SearchField` 先例），已从 `Localizable.strings` 移除。
- `FloatButton`（`CircularGlassButtonStyle` / `ExtendedFloatButtonStyle`）新增 `\.isEnabled` 禁用视觉（此前禁用态与启用态渲染无区别）；`ExtendedFloatButtonStyle` 胶囊横向 padding 改随 `size` 档位缩放（`CoreControlMetrics.horizontalPadding(for:)`），不再固定 `CoreSpacing.lg`。
- `ProgressIndicator` 带文案时的 accessibility label 改播报文案本身（`self.text ?? Text("Loading", bundle: .module)`），此前恒播 `"Loading"`。
- `spinning` 遮罩改用 `ContainerRelativeShape()` 替代 `Rectangle()`，避免直角材质溢出圆角内容轮廓。
- `PinCode` 隐藏承接输入的 `TextField` 补 `.fixedSize()`——此前在某些外层宽度大于格子行实际宽度的场景下（如宿主画廊详情页）会撑满可用宽度，导致其 0.01 透明度的文字内容露出到格子行左侧边界之外（Phase 3 视觉复查发现，截图可见「重影」，非本次改动引入，已一并修复）。
- 各组件 `docs/components/*.md` 结尾「运行 `run-snapshots.sh` 生成于 `docs/snapshots`」的样板措辞统一订正——与 `phase0-decisions.md` §3 的实际生成路径（默认模式依赖 `App/Sources/Previews.swift` 注册；组件自带 `#Preview` 走 `KEEP_LIBRARY_SNAPSHOTS=1` 到本地 scratch 目录）对齐（本 PR 共订正 32 个 `docs/components/*.md`，含既有组件）。
- `ToastHostTests` 时序 flaky 修复：`.serialized` trait + buffer 从 0.3–0.5s 放宽到 0.8–1.2s（`Suite` 与整套测试并跑时的调度抖动会吃掉窄余量）。
- Steps/Timeline 连线宽度对 phase0-decisions「hairline」的有意偏离（`Timeline` 取 `CoreBorderWidth.thin`、`Steps` 横向连线取 `.thick`）本次未额外改动。
- `%lld steps` 复数摘要键（Phase 0 预登记）裁决**不消费**——理由：每步已有「N of M」位置播报，容器层再插入总览摘要需要重新设计 accessibility 树分层，收益与改动面不成比例；键保留在 `.stringsdict` 供未来复用。

## `0.6.0`（收尾攒项 2/5/8，2026-07-25）

### 签名变更（source-breaking）

| 组件 | 旧 | 新（`0.6.0`） |
|---|---|---|
| `Separator.Inset` | `case none`（贯穿） | `case edgeToEdge`（贯穿） |

**迁移**：`Separator(inset: .none)` → `Separator(inset: .edgeToEdge)`；`init` 默认值同步改为 `.edgeToEdge`。**理由**：`.none` 与 `Optional.none` 同名，调用方持有 `Inset?` 时写 `.none` 会静默解析成 `Optional.none`（编译器仅在部分位置告警）——改名消除该遮蔽。

### 弃用（source-compatible，带警告）

| 符号 | 替代 |
|---|---|
| `ProgressBar`（`@available(*, deprecated)`） | 系统 `ProgressView(value:).progressViewStyle(.core)`——`.core` **响应环境 `.tint`**、走系统控件（`ProgressBar` 有意拒绝环境 tint）。见 [components/core-control-styles.md](components/core-control-styles.md)。`ProgressBar` 保留至下游迁移完成后移除 |

### 新增（非破坏）

- `SettingsRowMetrics` 从 `internal` 改为 **`public`**——让调用方把自定义行/内容对齐到 `SettingsRow` 的网格（图标列宽 `iconSquareSize`、分隔线 inset `iconAlignedDividerInset` / `textAlignedDividerInset` 等），不必抄魔数（SC#10「不写 OhMyDesign 之外样式代码」对自定义行的支撑）。

## `0.5.0`（文本入参统一，2026-07-24）

**破坏性** —— `SettingsRow` 的文本入参从 `Text` 改为 `LocalizedStringKey` / `StringProtocol`，与库内 `SectionHeader` / `SectionFooter` / `AsyncButton` 的入参形态统一。

### 签名变更（source-breaking）

| 组件 | 旧（`0.4.x`） | 新（`0.5.0`） |
|---|---|---|
| `SettingsRow`（带 accessory） | `init(icon:, title: Text, subtitle: Text? = nil, accessory:)` | `init(icon:, title: LocalizedStringKey, subtitle: LocalizedStringKey? = nil, accessory:)` + `@_disfavoredOverload init<S: StringProtocol>(...)` |
| `SettingsRow`（无 accessory 便利 init，`Accessory == EmptyView`） | `init(icon:, title: Text, subtitle: Text? = nil)` | `init(icon:, title: LocalizedStringKey, subtitle: LocalizedStringKey? = nil)` + `@_disfavoredOverload init<S: StringProtocol>(...)` |

**迁移**：把 `SettingsRow(title: Text("Wi-Fi"))` 改为 `SettingsRow(title: "Wi-Fi")`；副标题同理。**字面量**走 `LocalizedStringKey`（`Bundle.main` 本地化——`StringProtocol` 重载带 `@_disfavoredOverload`，与 SwiftUI `Text` 同款做法，保证字面量不落到 verbatim 泛型重载）；**运行期字符串**走 `StringProtocol` 重载（verbatim）。**注意**：`title` 与 `subtitle` 类型须一致——混用字面量 title + 运行期字符串 subtitle 时，两者会一起落到 `StringProtocol` 重载、字面量 title 也按 verbatim 处理（不本地化）。**代价**：不再能直接传样式化 `Text`（如 `Text("x").bold()`）——如需样式化标题，用系统 `.font` / attributed string 于 accessory，或按需在库层再引入 `titleView:` 形态。

### 新增（非破坏，随本次一并）

- `InsetGroupedSection` 的 `header` / `footer` 补 `StringProtocol` 重载——此前只收 `LocalizedStringKey`，运行期字符串传不进；现与 `SettingsRow` / Section 组件对齐。现有 `header: "General"` 字面量调用不变。

## `0.3.0`（epic coredesign-native-foundation，2026-07-21 ~ 2026-07-23）

把 token 地基从 GitHub Primer 换成 Apple HIG。取值理由见
[`docs/DESIGN-FOUNDATION.md`](DESIGN-FOUNDATION.md)。这是一次**破坏面很大**的改造：
6 个组件删除、`Blossom` trait 删除、`CoreGradient` 删除、9 个字体 token 改名、
圆角与控件尺寸档位换值、大量语义色改指系统色。本条目定稿时库自 `0.2.0` 升往 `0.3.0`；
库处于 `1.0` 之前，接受破坏性变更，但要求完整记录。

> **下游升级路径**：本次改造分两个版本发布——`0.3.0`（本条目，地基）与 `0.4.0`
> （新组件，`InsetGroupedSection` / `SettingsRow` / `Card` / `Separator` /
> `SectionHeader` / `SectionFooter` 等，另立 epic 交付）。若不急于跟进 `0.3.0`，
> **可直接从 `0.2.0` 跳到 `0.4.0`**，届时以本条目与 `0.4.0` 条目的并集为准。凡本条目中
> 标注"无直接替代"的删除项，下游都应先确认 `0.4.0` 是否提供了可组合出等价效果的
> 通用容器，而不是假定永久没有替代路径。

### 删除的公开符号

| 删除 | 来源 | 替代 |
|---|---|---|
| `BookCover` / `RefPill` / `StatusRow` / `EventRow` / `CommentCard` / `TimelineItem`（6 个组件） | #117 | **无直接替代**——它们服务于「GitHub Issue 时间线」这一具体场景，在通用设计系统里被判定为死重而非迁移目标。若下游依赖，需按各自场景用 SwiftUI 原生组件重建；`0.4.0` **已提供**的 `Card` / `InsetGroupedSection` / `SettingsRow` 等通用容器可作为重建时的基础构件，但**不是**这 6 个组件的直接替代品（Phase 1 已裁决：通用容器 ≠ GitHub 时间线场景组件的等价物） |
| `StatusResult`（枚举，`StatusRow.swift` 内） | #117 | 随 `StatusRow` 一并删除，无独立替代。注意 `StatusLevel`（`Banner` / `Toast` 的公开参数类型）**保留**，未受影响，不要混淆两者 |
| `timelineDepth`（`EnvironmentValues` 入口） | #117 | **从未 `public`，对下游无影响**——`@Entry` 不继承 public 访问级别（本库对此有惯例：`Toast.swift` 的 `toastHost` 显式写了 `@Entry public var`，而 `segmentedControlStyle` / `bannerStyle` 与本条一样是 internal）。列在此处仅为完整记录随 `TimelineItem` 一并消失的符号，**不构成破坏性变更** |
| `Blossom` package trait | #118 | **无替代**。下游若在 `Package.swift` 里写 `.package(url: "...", traits: ["Blossom"])`，升级后会在**依赖解析期**报 unknown-trait 错误——报错发生在 SwiftPM manifest 解析层，**不是编译错误**，下游不一定能第一时间把这个报错与本次升级关联起来，请特别注意。若需要强调色主题化，改用宿主 App 自己的 `AccentColor` 资源（见下方「改名的 token」表外的语义色变更） |
| `CoreGradient.brand` / `.cta` / `.canvas` | #118 | `brand` / `cta` → `Color.accent`；`canvas` → `Color.surfaceCanvas`。三者此前都是 `AnyShapeStyle`，默认主题下本就退化为对应纯色，替换后视觉不变 |
| `CoreRadius.smallPlus`（4pt，删除前库内零调用点） | #119 / #121 | 就近改用 `CoreRadius.small`（6pt） |
| `CoreRadius.mediumPlus`（8pt，删除前仅有的两处调用点在 `Sidebar.swift`） | #119 / #121 | 库内实际迁移选择改用 `CoreRadius.medium`（10pt）；若下游场景确实需要介于 `small`(6) 与 `large`(16) 之间的中间档，参考同一选择 |
| `CoreControlMetrics.primerVerticalPadding(for:)` | #119 / #121 | `CoreControlMetrics.verticalPadding(for:)`——原 escape hatch 是为了精确命中 Primer 的非 `CoreSpacing` 档位（6/10/14pt），新标度下不再需要 |
| `CoreTypography` 的全部 `*LineSpacing` / `*Tracking` 静态量（如 `bodyMediumLineSpacing` / `bodyMediumTracking`，每个旧尺寸档位各一对） | #119 | **无需替代**——新实现直接取系统 `Font.TextStyle`，行高与字距由系统决定，调用方不应再手动施加这两项 |
| `CoreTypography.Spec.scales` 开关、`Token.fixedFont` | #119 | 无替代——旧的"是否随 Dynamic Type 缩放"开关被删除，新 12 档 token 全部缩放，没有不缩放的例外 |
| `CoreTypography` 的 10 个旧 `*Font` static var：`displayLargeFont` / `titleLargeFont` / `titleMediumFont` / `titleSmallFont` / `subtitleFont` / `bodyLargeFont` / `bodyMediumFont` / `bodySmallFont` / `captionFont` / `captionSmallFont` | #119 / #121 | 改用 `.coreFont(_:)` + 对应新 `Token`（见下方改名表），如 `.coreFont(.largeTitle)`。**注意这是一次静默行为变化**：旧 `*Font` 是 `.system(size:)` 固定字号，不随 Dynamic Type 缩放；新 token 必然缩放 |

### 改名的 token

`CoreTypography.Token` 9 个改名档位，映射逐字沿用 `.claude/epics/archived/coredesign-native-foundation/119.md` 定案（不做二次判断）：

| 旧名 | 新名 |
|---|---|
| `displayLarge` | `largeTitle` |
| `titleLarge` | `title` |
| `titleMedium` | `title2` |
| `subtitle` | `title3` |
| `titleSmall` | `headline` |
| `bodyLarge` | `body` |
| `bodyMedium` | `callout` |
| `bodySmall` | `footnote` |
| `captionSmall` | `caption2` |

> **`caption` / `captionMono` 名字未变，但语义变了**（同名换语义，不产生 deprecation warning，编译器与 grep 都发现不了）：旧版本是 Primer 手写字号表的固定档位，新版本直接映射系统 `.caption` 文本样式（`captionMono` 额外指定等宽 design）。下游若有代码依赖旧 `caption` 的具体字号/行高数值，需要重新核对。
>
> **`subheadline` 是净新增**——对应系统 `.subheadline` 文本样式，Primer 标度里没有对应档位，无旧名可改。

### 同名换值（探针对此系统性失明，逐点列出）

这一类变化**编译器不报错、不产生 warning、grep 找不到、测试不变红**——调用点静默继承新值。下游升级后只会表现为"界面看着不太对"而无从定位，请对照下表逐点确认。

> **本库的 `scripts/downstream-probe`（CI 的 Downstream API probe job）对本节系统性失明**，
> 不要以它跑通为"同名换值已确认无影响"的证据。该探针只能发现**删除的符号**（下游引用会
> 编译失败）与**改名的符号**（下游用旧名会编译失败），因为它验证的是"下游代码能否编译"；
> 而同名换值不改变符号名、不改变类型签名，探针照样编译通过——它验证不了"这个值变了、
> 是否仍然符合下游的视觉预期"这件事。本节的逐点旧值 → 新值对照表是唯一权威来源。

#### `CoreRadius`

| 档位 | 旧值 | 新值 | 备注 |
|---|---|---|---|
| `none` | 0 | 0 | 未变 |
| `small` | 3pt | **6pt** | 新 `small` 恰好等于旧 `medium`——风险最集中的一档 |
| `medium` | 6pt | **10pt** | |
| `large` | 12pt | **16pt** | |
| `xLarge` | *(不存在)* | 22pt | 新增档位，非换值 |

#### `CoreControlMetrics.height(for:)`

| `ControlSize` | 旧值 | 新值 |
|---|---|---|
| `.mini` | 24pt | **28pt** |
| `.small` | 28pt | **32pt** |
| `.regular` | 32pt | **44pt** |
| `.large` | 40pt | **50pt** |
| `.extraLarge` | 48pt | **56pt** |

#### `CoreControlMetrics.horizontalPadding(for:)`

| `ControlSize` | 旧值 | 新值 |
|---|---|---|
| `.mini` | 8pt | 8pt（未变） |
| `.small` | 12pt | 12pt（未变） |
| `.regular` | 12pt | **16pt** |
| `.large` | 12pt | **16pt** |
| `.extraLarge` | 12pt | **24pt** |

#### `CoreControlMetrics.verticalPadding(for:)`

| `ControlSize` | 旧值 | 新值 |
|---|---|---|
| `.mini` | 2pt | **4pt** |
| `.small` | 4pt | 4pt（未变） |
| `.regular` | 8pt | **12pt** |
| `.large` | 12pt | **16pt** |
| `.extraLarge` | 16pt | 16pt（未变） |

#### 语义色指向变更

| Token | 旧实现 | 新实现 |
|---|---|---|
| `Color.accent` | `Color.brand5`（OhMyDesign 固定品牌蓝） | `Color.accentColor`（跟随宿主 App 的 `AccentColor` 资源） |
| `Color.accentHover` | `Color.brand6`（固定色阶） | `accent.mix(with: .primary, by: 0.15)`（对宿主 accent 动态调制） |
| `Color.accentPressed` | `Color.brand7`（固定色阶） | `accent.mix(with: .primary, by: 0.25)` |
| `Color.accentDisabled` | `Color.brand2`（固定色阶） | `accent.opacity(0.35)` |
| `Color.accentSubtleBackground` | `Color.brand1`（固定色阶） | `accent.opacity(0.12)` |
| `Color.selectionBackgroundEmphasis` | 借道 `accentDisabled`（= `brand2`，淡色块） | 实心 `accent` |
| `Color.borderFocus` / `Color.borderSelected` | `Color.accent`（即固定色阶 `brand5` 品牌蓝）——**注意它们在 `0.2.0` 就已指向 `accent`**，独立蓝色 colorset 是更早的 Issue #93 删的，不是本次 | `Color.accent`（指向不变，但 `accent` 本身改指宿主 `AccentColor`，故实际取值随之变化——见上一行） |
| `Color.surfaceCanvas` / `Color.surfaceGrouped` | 自有 `canvas-default` colorset（light `#FCFBF7` / dark `#11110F`） | `Color.systemGroupedBackground` |
| `Color.surfaceCanvasSubtle` | 自有 `canvas-subtle` colorset（light `#F3F0EA` / dark `#1A1916`） | `Color.secondarySystemGroupedBackground` |
| `Color.surfaceCanvasInset` / `Color.surfaceInteractive` | 自有 `canvas-inset` colorset（light `#F8F5EF` / dark `#0F0F0D`，不透明） | `Color.tertiaryFill`（系统填充色，半透明叠加语义） |
| `Color.surfaceRaised` | `.secondarySystemBackground`（plain 系统背景族） | `.secondarySystemGroupedBackground`（grouped 族，与 `surfaceCanvas` 同族） |
| `Color.surfaceElevated` | `.tertiarySystemBackground`（plain） | `.tertiarySystemGroupedBackground`（grouped） |
| `Color.systemGroupedBackground`（**仅 macOS**） | AppKit 降级 `.controlBackgroundColor` | AppKit 降级 `.windowBackgroundColor`——此前与 `secondarySystemGroupedBackground` 同色，画布与 raised 层在 macOS 上完全无法区分，本次修正为可辨的两档 |
| `status-accent-subtle` / `status-success-subtle` / `status-attention-subtle` / `status-danger-subtle` / `status-done-subtle`（**仅深色模式**） | alpha `0.067` | alpha `0.280`（视觉终审 #125 发现深色下四档在纯黑画布上几乎不可辨，统一提高不透明度） |

> `ContentColors`（`label` 族）与 `FillColors`（`systemFill` 族）本就直接指向系统色，本次未改动，不在上表中。`secondaryAccent` / `neutralAccent` 两族与 `StatusColors` 的其余 19 个 token（非 subtle 变体）**显式定案保留**现有取值，同样未换值。

## `0.4.1`（Phase 2 收尾改进，2026-07-24）

**非破坏性** —— 纯新增 + RTL 正确性修复，对下游零破坏，无需迁移。

- **`Card(bordered:)` + `View.surface(_:bordered:)`（新增公开 API）**：`Card` 新增 `bordered: Bool = true` 参数，`SurfaceModifier` 同步暴露 `.surface(_:bordered:)`。置 `false` 去描边、只留背景 + 圆角，贴近 iOS 系统分组容器（无描边、靠填充色对比定界）。默认 `true`，现有 `Card { }` / `.surface(kind)` 调用行为不变。
- **全库 chevron 统一 `chevron.forward`（RTL 正确性）**：`ChevronRightIcon` / `Sidebar` / `ListRow` / `CoreDisclosureGroupStyle` 的 disclosure chevron 从 `chevron.right` 改为 `chevron.forward`。**LTR 下视觉不变**（仍指右），**RTL 下自动镜像**为指左，与系统一致。`CoreDisclosureGroupStyle` 的展开旋转同步做了 `layoutDirection` 感知（RTL 展开态指下而非指上）。`ChevronRightIcon` 公开类型名保留（API 稳定）。

## `0.4.0`（epic coredesign-native-components）

Phase 2 新组件交付,**纯新增为主**:基础容器 `Card` / `Separator` / `SectionHeader` / `SectionFooter`、分组设置行 `InsetGroupedSection` / `SettingsRow`（含 `SettingsRowIcon` / `SettingsRowChevron` / 顶层枚举 `SettingsDividerInset`）、系统控件 `.core` style 3 个（`progressViewStyle(.core)` / `labelStyle(.core)` / `disclosureGroupStyle(.core)`）。这些**不删不改公开符号,对下游零破坏**。唯一的破坏面是下方「同名换值」的 `.content` / `.card` 表面色指向变更（对下游编译零感知,仅改观感）。

> `.toggleStyle(.core)` / `.textFieldStyle(.core)` **有意未提供**——自定义 `ToggleStyle.makeBody` 会丢原生 switch 的手势与 haptic、`TextFieldStyle._body` 是私有的无公开自定义入口;换皮即重造控件,违反「不重造系统控件」约束。设置行里的开关直接用系统 `Toggle` + `.tint`。

### 同名换值

#### `Color.surfaceCard`（Issue #140）

| 旧实现 | 新实现 | 影响 |
|---|---|---|
| 别名 `Color.surfaceCanvas`（= `systemGroupedBackground`，页面画布色） | 别名 `Color.surfaceRaised`（= `secondarySystemGroupedBackground`，浮起层色） | **对下游编译零感知**——符号名、类型签名均未变，`scripts/downstream-probe` 探测不到。视觉上：`.surface(.content)` 与 `.surface(.card)` 两个 `SurfaceKind` case（唯二消费 `surfaceCard` 的调用点）渲染出的背景色**在浅色与深色两种外观下都改变**（iOS 浅色：`systemGroupedBackground` #F2F2F7 → `secondarySystemGroupedBackground` #FFFFFF，灰画布卡片变白色浮起卡片；iOS 深色：由此前与画布同色的塌缩隐形变为可辨的浮起背景。上述 hex 为 **iOS 值**；macOS 走降级映射 `windowBackgroundColor` → `controlBackgroundColor`，具体值不同但同样两种外观下都变，见 `SystemBackgroundColors.swift` 的降级注释）。深色是动机（塌缩隐形），不是变化的全部范围。本变更落地（`0.3.0`）时库内**无生产组件调用** `.surface(.content)` / `.surface(.card)`（彼时唯一**生产**调用点是 `ListRow.swift` 的 `.surface(.canvas)`，不受影响；`SurfacePreviewGallery` 的 `#Preview` 会遍历全部 case，非生产路径）。**`0.4.0` 起新增的 `Card` 消费 `.surface(.content)`**——但 `Card` 是净新增组件、自始即渲染新值,不构成升级前后的观感变化。若下游代码直接调用了这两个 case，或直接引用 `Color.surfaceCard`，升级后视觉会随之改变 |

Phase 1 视觉终审（#125）与 #136 查明 `.surface(.content)` → `surfaceCard` → `surfaceCanvas` → `systemGroupedBackground` 这条链路——卡片背景与页面画布完全同色，深色下、无描边时不可辨。iOS 卡片本应浮于画布之上（`secondarySystemGroupedBackground`，即库内已有的 `surfaceRaised`），故只改 `surfaceCard` 的别名目标，不改 `SurfaceKind` 的 case 结构。

## Issue #97（epic coredesign-audit-remediation，2026-07-21）

### 删除的公开符号

| 删除 | 替代 |
|---|---|
| `EmptyState`（组件） | SwiftUI `ContentUnavailableView` / UIKit `UIContentUnavailableView`（见 [components/empty-state.md](components/empty-state.md)） |
| `KeyboardReadable` 协议及其默认实现 | 无 OhMyDesign 替代；键盘高度用 `keyboardLayoutGuide` 或自建 publisher |
| `View.dismissKeyboardOnTap(enabled:onKeyboardDismissed:)` | 同上 |
| `HideKeyboardOnTapGesture` | 同上 |
| `View.resignFirstResponder()` / `View.becomeFirstResponder()` | 直接用 UIKit/AppKit 的 first responder API |
| `anyWriterFirstResponderNotification`（= 字符串 `"io.platform.inputView.becomeFirstResponder"`） | **字符串键契约**：若下游用字面量 observe 该通知，符号 grep 查不到，请手动核对 |
| `CoreRadius.full`（= 9999） | pill 形态用 `Capsule()`，不要用大 `cornerRadius` |
| `bordered(color:width:)` 重载 | `bordered(style:width:shape:)`（`Color` 已 conform `ShapeStyle`，直接传） |

### 签名变更（源码兼容，追加带默认值的参数）

| 变更 | 说明 |
|---|---|
| `bordered(style:width:)` → `bordered(style:width:shape:)` | 新增 `shape` 参数（默认 `Rectangle()`）；同时描边从 `stroke` 改 `strokeBorder`，边框向内收 `width/2` |

> **零引用验证**：上述删除的符号已在真实下游 `any-writer` 实测零引用（排除其 vendored OhMyDesign 副本）。唯一无法用 grep 覆盖的是 `anyWriterFirstResponderNotification` 的**字符串键**——已单独在上表标注。
