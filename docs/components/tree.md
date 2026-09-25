# Tree

递归层级树 / Recursive tree：受控展开 + 行选中（单选 / 多选）+ 可选的三态复选框 +
W3C ARIA Treeview 键盘导航。

本仓**第一个层级数据组件**。可见行按深度优先展平成一列，放进 `LazyVStack`（`#429` 起；`#422` 走的是递归
`DisclosureGroup(isExpanded:)`）。**不是原生外观**——chevron、缩进、行选中底色与展开态的无障碍播报全部自绘。

## API

```swift
public nonisolated enum TreeSelectionMode: Hashable, Sendable, CaseIterable { case single, multiple }

public struct Tree<Data: RandomAccessCollection, ID: Hashable, RowContent: View>: View {
    public init(
        _ data: Data,
        id: KeyPath<Data.Element, ID>,
        children: KeyPath<Data.Element, Data?>,
        expanded: Binding<Set<ID>>,
        selection: Binding<Set<ID>>,
        selectionMode: TreeSelectionMode = .single,
        checked: Binding<Set<ID>>? = nil,
        onActivate: ((ID) -> Void)? = nil,
        @ViewBuilder content: @escaping (Data.Element) -> RowContent
    )

    nonisolated public static func expandedIDs(
        _ data: Data,
        id: KeyPath<Data.Element, ID>,
        children: KeyPath<Data.Element, Data?>,
        toDepth depth: Int
    ) -> Set<ID>
}

public extension Tree where RowContent == EmptyView {
    // 同上，调用处不必写出行内容泛型：Tree.expandedIDs(roots, id: \.id, children: \.children, toDepth: 2)
    nonisolated static func expandedIDs(
        _ data: Data,
        id: KeyPath<Data.Element, ID>,
        children: KeyPath<Data.Element, Data?>,
        toDepth depth: Int
    ) -> Set<ID>
}

// Data.Element: Identifiable 时可省略 id:
Tree(nodes, children: \.children, expanded: $expanded, selection: $selection) { Text($0.name) }

// 行外观（#429）：封闭配置，只有两个预设
public struct TreeStyle {
    nonisolated public static var automatic: TreeStyle { get }   // 默认
    nonisolated public static var navigator: TreeStyle { get }
}
public extension View {
    func treeStyle(_ style: TreeStyle) -> some View
}

// 整行右键菜单（#429）：builder 方法，返回同一棵树；Tree 仍是三个泛型参数
public extension Tree {
    func rowContextMenu<M: View>(@ViewBuilder _ menu: @escaping (Set<ID>) -> M) -> Tree
}

// 单击父行的行为（#431）：builder 方法，同上；默认 .select 与此前相同
public nonisolated enum TreeRowClickBehavior: Hashable, Sendable, CaseIterable { case select, selectAndToggleExpansion }
public extension Tree {
    func rowClickBehavior(_ behavior: TreeRowClickBehavior) -> Tree
}

// 搜索过滤（#423）：builder 方法，同上；搜索词由调用方持有
public extension Tree {
    func searchFilter(_ query: String, text: @escaping (Data.Element) -> String) -> Tree

    // 直接命中的节点 ID（与过滤同一实现），给调用方算命中数 / 空态 / 播报；
    // where RowContent == EmptyView 上另有同名重载，调用处不必写出行内容泛型
    nonisolated static func searchMatches(
        _ data: Data,
        id: KeyPath<Data.Element, ID>,
        children: KeyPath<Data.Element, Data?>,
        query: String,
        text: (Data.Element) -> String
    ) -> Set<ID>
}

// 命中高亮（#423）：与 searchFilter 同一条匹配规则
public extension Text {
    init(verbatim content: String, highlighting query: String)
}

// 高亮底色（#423）：第 3 层 token 与它的第 2 层来源
public extension Color {
    static var searchMatchBackground: Color { get }   // systemYellow × 0.35（亮）/ 0.20（暗）
    static var systemYellow: Color { get }
}
```

| 参数 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| data | RandomAccessCollection | - | 根节点集合 |
| id | KeyPath<Element, ID> | `\.id`（Identifiable 便利 init） | 稳定标识，**整棵树内**唯一；跨子树重复时，除了状态集合分不开，行的渲染身份（展平后 `ForEach` 按它取 id）也会错位 |
| children | KeyPath<Element, Data?> | - | 子节点；`nil` 与空集合都算叶节点 |
| expanded | Binding<Set<ID>> | - | 已展开节点，调用方持有，可读可写可持久化 |
| selection | Binding<Set<ID>> | - | 已选中行（导航语义） |
| selectionMode | TreeSelectionMode | `.single` | `single` / `multiple`；**枚举而非 Bool** |
| checked | Binding<Set<ID>>? | `nil` | 已勾选**叶**节点（数据语义）；`nil` 时不画复选框 |
| onActivate | ((ID) -> Void)? | `nil` | `Enter` 激活焦点行时回调，与选中分开；为 `nil` 时 `Enter` 交回系统 |
| content | (Element) -> RowContent | - | 行内容，常为 `Text` / `Label` |

## 展开 / 默认展开到第 N 层

- 展开态就是 `expanded` 这个 `Set<ID>`；组件不另存一份。点 chevron、按 `←` / `→`、
  `.rowClickBehavior(.selectAndToggleExpansion)` 下单击父行（`#431`）都直接写它。
  例外是搜索期间（`#423`）：那时的展开 / 折叠只落组件内的临时 overlay，不写 `expanded`，清空搜索词即丢弃。
- **根为第 1 层**。`Tree.expandedIDs(_:id:children:toDepth:)` 预算「默认展开到第 N 层」的集合：
  `toDepth: 1` 全折叠，`toDepth: 2` 只展开根这一层，依此类推。它是 `nonisolated` 的纯函数，
  可以在 `@State` 的初值里直接调用。

```swift
@State private var expanded = Tree.expandedIDs(roots, id: \.id, children: \.children, toDepth: 2)
```

不写泛型的这个写法解析到 `where RowContent == EmptyView` 的重载；已经写出
`Tree<[Node], String, Text>` 时解析到主类型上的同名函数，两者结果相同。

## 选择与勾选：两套独立状态

| | 行选中 `selection` | 勾选 `checked` |
|---|---|---|
| 语义 | 导航：当前高亮哪几行 | 数据：勾了哪些 |
| 谁能进集合 | 任意行（含父节点） | **只有叶节点** |
| 改变方式 | 点行、`Space`、`Shift+↑/↓`、`Ctrl/Cmd+A` | 点复选框、`⌥Space`（焦点行，`#428`）、行内容上的无障碍动作 "Check" / "Uncheck"（`#428`） |

`rowClickBehavior(.selectAndToggleExpansion)`（`#431`）下点父行还会取反展开态——那是第三份状态。行选中照旧按下面的规则变化，
唯一例外是该模式下 `single` 再点已选中的**父行**保持选中（见「单击父行」一节）。

- `single`：选中一个未选行时替换已选集合里**属于本树**的全部 ID——包括被折叠而当前不可见的；
  再选同一行取消（允许空选）。集合里不属于本树数据的 ID 原样保留。
- `multiple`：逐行切换。
- **父行复选框是派生的**：父行用系统 `Toggle(sources:isOn:)`，源集合是它**全部叶后代**的勾选绑定，
  三态（off / mixed / on）由系统派生、由 `CheckBoxToggleStyle` 呈现（见 [checkbox.md](checkbox.md)）。
  点 mixed 父节点 = 级联全选全部叶后代；再点一次 = 全不选。父节点 ID **永不进** `checked`。
  例外是搜索期间（`#423`）：三态照旧按全部叶后代显示，点击只作用于被过滤保留的叶后代，
  见「搜索过滤与命中高亮」的「父行复选框」一行。

## 行为真值表（PRD FR-2）

| 行为 | 定案 | 本组件的落点 |
|---|---|---|
| 行选中与复选框 | 两套独立状态 | 已实现 |
| 点击 mixed 父节点 | 全选（级联全部后代）；再点全不选 | 已实现 |
| 父节点自身 | 只由后代推导，不单独进选择集合 | 已实现（勾选侧） |
| 搜索期间的展开 | 不写进持久化 `Set<ID>`，只临时展开 | 已实现（`#423`：`searchFilter(_:text:)` 期间展开 / 折叠只写 overlay） |
| 清空搜索 | 恢复搜索前的展开态 | 已实现（`#423`：搜索词为空即丢弃 overlay，使用调用方**当前**的 `expanded`；宿主在搜索期间没改过它时即为搜索前的展开态） |
| 过滤后「全选」 | 范围是可见节点 | 已实现（`Ctrl/Cmd+A` 只选可见行）。父行复选框是另一处「全选」，`#423` 另定：三态按全部叶后代显示，点击只作用于**保留**的叶后代（含因折叠未显示的），见「搜索过滤与命中高亮」 |
| 焦点节点被过滤隐藏 | 移到最近的仍可见祖先；无祖先则移到首个可见节点 | 已实现（折叠祖先、宿主改 `expanded` 或 `data`、`#423` 起搜索过滤，任一使焦点行不可见时即归约） |

`#422` 只落了第 4 / 5 行的状态结构（`TreeExpansionState` 的 overlay），生产路径上 overlay 恒为 `nil`；
`#423` 起搜索期间 overlay 在生产路径上（见「搜索过滤与命中高亮」），不搜索时仍为 `nil`。
焦点归约：可见行集合一变就归约，按键时也先归约再执行。

## 键盘

契约取 **W3C ARIA Treeview Pattern** 的推荐（单选式）多选模型：方向键只移动焦点、不改变选择。

| 键 | 行为 |
|---|---|
| `↓` / `↑` | 焦点移到下 / 上一个**可见**行；首末行上 does nothing |
| `→` | 折叠的父节点：展开，焦点不动；已展开的父节点：焦点移到首个子节点；叶节点：does nothing |
| `←` | 已展开的父节点：折叠；子级的叶 / 折叠节点：焦点移到父节点；**根级**的叶 / 折叠节点：does nothing |
| `Home` / `End` | 焦点到首行 / 最后一个**可见**行 |
| `Space` | 切换焦点行的选中态 |
| `⌥Space`（Option+Space） | 仅传了 `checked:`：切换焦点行的勾选（`#428`，见下「勾选的键盘定案」）；没有勾选列时交回系统 |
| `Enter` | 激活焦点行（调 `onActivate`），不改选中 |
| `Shift+↓` / `Shift+↑` | 仅 `multiple`：移焦并切换目标行的选中态；`single` 下退化为纯移焦 |
| `Ctrl+A` / `Cmd+A` | 仅 `multiple`：全选可见行 |
| 其它字符键、`Tab` | 交回系统（不吞） |

### 勾选的键盘定案（`#428`）

| 问题 | 定案 | 理由 / 放弃的方案 |
|---|---|---|
| 用哪个键 | **`⌥Space` 切换勾选，`Space` 仍只切换选中**（有无 `checked:` 都一样） | `Space` 在 `.single` 下是唯一的键盘选中手势（方向键不改选中），让它随 `checked:` 改义会让单选树失去键盘选中、同一个键的语义随配置漂移；因此保 W3C 契约不变，另加一个专用键。放弃「有 `checked:` 时 `Space` 改切勾选」（Windows TreeView 的 CheckBoxes 模式如此，但那里选中跟随焦点、`Space` 本来空着，本组件没有这个前提）。放弃 `Shift+Space`：W3C APG 把它留给「从上一个选中行到焦点行的范围选中」。放弃 `Ctrl+Space` / `Cmd+Space`：macOS 默认分别是切换输入法与 Spotlight。放弃字母键（如 `x`）：W3C 把可打印字符留给 type-ahead |
| 已知冲突：全局热键 | **保留 `⌥Space`**。Alfred、Raycast 的出厂全局热键都是 `⌥Space`，装了它们的机器上这一键在到达 app 之前就被吃掉，Tree 收不到 | 替代通路：点该行复选框，或用行内容上的 "Check" / "Uncheck" 无障碍动作（VoiceOver 转子 / Full Keyboard Access 的动作菜单）。建议这类用户把启动器的热键改成别的组合（两者都能在设置里改）。没有另设第二个键：可选的组合都有同类问题（见上一行），多一个键只多一份契约 |
| 父行 | 按父行复选框的显示态级联：off / mixed → 全部叶后代勾上，on → 全不勾；父 ID 不进 `checked` | 与点父行复选框同一结果（`TreeChecking.toggling` → `applying`） |
| 搜索期间 | 只作用于**保留**的叶后代，与点父行复选框同一范围 | 与「搜索过滤」一节父行复选框的定案一致 |
| 选中 / 展开 / 焦点 | 都不动；交互来源置为键盘（焦点环照画） | 勾选是数据语义，与行选中是两套独立状态 |
| 修饰键 | 只认恰为 `option`；`⌥⇧Space`、`⌥⌘Space` 等交回系统 | 与其它键同一白名单口径 |

- 行为落在 `TreeKeyboard.action`（`.toggleCheck`）→ `TreeInteractionReducer.key`（带出 `checkToggled`）→ 视图按
  `TreeChecking.togglingRow` 写回 `checked`。
- 真 HID 读数（`422-probe`，`checked` 事件逐条）：macOS 26 System Events 发 `key code 49 using {option down}`：
  焦点 `a` 上 ⌥Space → `+["a1x", "a1y", "a2"]`；↓ 三次到 `b` 再 ⌥Space → `+["b"]`；Home 再 ⌥Space → `-["a1x", "a1y", "a2"]`；
  随后不带修饰键的 `Space` 只产生 `SELECT +["a"]`。iOS 26.4 模拟器 `axe key-combo --modifiers 226 --key 44`：
  点 `README.md` 行后 ⌥Space → `checked` 加入 `readme`；移到 mixed 的 `Design` 再 ⌥Space → 它的全部叶后代勾上。
- 键盘层按 `KeyPress.key` 判键，上面两条腿的真 HID 都接住了 ⌥Space。托管窗口判据合成的事件取
  `characters` U+00A0（不间断空格）、`charactersIgnoringModifiers` 空格——这是按 macOS 美式布局下 Option+Space
  的形态写的，**未抓真事件核对**；其它键盘布局下是否同样接住未验证。

- **初始焦点**：第一下键到达时焦点尚未确定，先按 W3C 规则解析（无选中 → 首行；有选中 → 可见顺序里
  第一个已选行），再执行这一键。
- **焦点形态**：容器是**唯一**可聚焦元素，「焦点在哪一行」是组件内部状态（ARIA activedescendant 形态），
  画成行上的焦点环。⚠️ 不要改回「每行一个 `@FocusState`」：macOS 真 HID 实测那种形态下第一下 `Space`
  之后整个窗口丢键盘焦点。
- **焦点环何时画**：容器有键盘焦点，**且**最近一次交互来自键盘时才画。「来自键盘」有两种：
  按键被 Tree 接住；容器**不是因点行**而获焦（`Tab` 进入、宿主程序化聚焦）——此时焦点行按初始焦点规则
  解析（有选中落可见顺序里第一个已选行，否则首行），环直接画在那一行，不必先按一下键。
  点行 / 点 chevron / 点复选框会清掉它，容器失焦（macOS `Tab` 离开）也不画。iOS 模拟器截图核过：
  点一行无环 → 按 `↓` 环落在下一行 → 再点一行环消失。
- **进入方式**：macOS 上 `Tab` 进入容器；iOS 上 `Tab` 不移焦点，**点一行**会同时把键盘焦点交给容器
  （点行导致的获焦记一个一次性标记，获焦回调据此不画环）。
- **修饰键按白名单判**：只认 shift / control / option / command。macOS 真 HID 下方向键自带
  `.numericPad | .function`（`rawValue 96`），`Home` / `End` 带 `.function`（`64`）——写成黑名单漏一位，
  方向键就会整条静默失效。
- 键盘层挂在容器上。⚠️ 两条腿实测：宿主**祖先**视图上的 `onKeyPress` 比 Tree 的**先**执行——
  宿主若在祖先上对方向键返回 `.handled`，Tree 就收不到。
- **不做**：type-ahead（组件不持有节点文案，行内容是调用方的 `@ViewBuilder`）、`F2` 重命名。
- ⚠️ **按住方向键是否连续移焦：未验证。** 键盘层只接 `.down` 相位。两条腿的探针装置都送不出 repeat：
  macOS 用 `CGEvent` 只发一次 keyDown、1.5 s 后 keyUp，iOS 用 `axe key --duration 1.5`，
  哨兵的 `.repeat` 相位都收到 **0** 次、焦点都只移一行。物理键盘的自动重复是否会到达、到达后是否冒泡出提示音，
  这套装置测不出来。
- ⚠️ **虚拟焦点移出可视区时不跟随滚动**：Tree 不持有滚动容器，宿主的 `ScrollView` 不会因为焦点行变化而滚动。
  可行的做法（行上挂 `.id`、Tree 内包 `ScrollViewReader` 按焦点 `scrollTo`）需要一套带滚动的探针另行验证，本次未做。

真 HID 读数（macOS System Events / iOS 26.4 模拟器 `axe`，逐步对预期表）与装置在
`.claude/epics/structure-components/422-probe/README.md`。

## 外观

### 密度：跟随 `controlSize`

`Tree` 读环境 `\.controlSize`（与按钮样式同一惯例），推导一份行度量；全部取自既有 token，不另立常量：

| 量 | 推导 | mini | small | **regular** | large | extraLarge |
|---|---|---|---|---|---|---|
| 视觉行高 | `size < .regular` ⇒ `iconSize(for:) + 2 × verticalPadding(for:)`；否则 `height(for:)` | 20 | 22 | **44** | 50 | 56 |
| 展开槽宽 | `iconSize(for:) + CoreSpacing.sm` | 20 | 22 | **24** | 28 | 32 |
| 缩进步长 | 展开槽宽 / 2 | 10 | 11 | **12** | 14 | 16 |
| chevron 字号 | `compactIconSize(for:)` | 10 | 12 | **14** | 16 | 18 |
| 行间距 | `size < .regular` ⇒ `CoreSpacing.none`；否则 `CoreSpacing.xxs` | 0 | 0 | **2** | 2 | 2 |
| 复选框字形 | `iconSize(for:)` | 12 | 14 | **16** | 20 | 24 |

- `.regular`（默认档）一列逐项等于引入密度之前写死的取值，默认外观不变。
- 术语：**行高**是单行的最小高度（`minHeight`），**行距** = 行高 + 行间距（相邻两行顶边之差）。
- **iOS 行高保底 44**：视觉行高低于 44 的档位（mini / small）在 iOS 上行高仍是 44（行间距 0，行距也是 44）——连续堆叠的行，行距就是
  命中区的上限，把命中区扩到行框外只会和邻行重叠。密度在 iOS 上只体现在缩进、chevron、复选框字形与行间距。
  macOS 无下限。
- macOS `.regular` 行高仍是 44、行距 46（本仓控件高度统一口径，不做平台分叉）；要 VS Code 式紧凑，写 `.controlSize(.small)`（行高 22、行间距 0，行距 22）。
- 复选框随档位缩放只发生在 `Tree` **自己画的**复选框上；`CheckBoxToggleStyle` 的公开行为不变（仍按 `.regular`）。
- ⚠️ 行高是**下限**不是上限：行内容里若放了读 `controlSize` 的控件（例如按钮，`height(for: .small)` = 32），
  行会被内容撑高。密集档位的行内容宜用 `Text` / `Label` / `Image`。

### 画法

- 缩进：每深一层一个缩进步长（上表）。
- chevron：`chevron.forward`，展开时转 90°；叶行保留同宽的占位，行内容左缘对齐。
  RTL 下系统已把字形镜像成朝左、并镜像了旋转方向，所以旋转角**两种书写方向都是 90°**。
  ⚠️ `#422` 原写 RTL 下 -90°，实测画出来展开态朝**上**（`#429` 的 RTL 镜像判据首跑即抓到），已改。
- 行：最小高度为该档行高（上表，iOS 过 44 下限）。
- 选中底色从**环境 `coreAccent`** 派生（与 `TagGroup` 选中态同一条通路），`.coreAccent(_:)` 换色即跟随：
  `.automatic` 取 `accentSubtleBackground(from: coreAccent)`（× 0.08），`.navigator` 取
  `accentSelectedRowBackground(from: coreAccent)`（× 0.16，理由见下节「三档阶梯」）。
- **命中区是整行**（含缩进区）：点缩进区也选中该行。两种外观相同。

### 外观配置：`.treeStyle(_:)`

`TreeStyle` 是**封闭**的外观配置（不是样式协议，第三方不能新增外观），只有两个预设：

| 部位 | `.automatic`（默认） | `.navigator`（VS Code Explorer 式） |
|---|---|---|
| 选中 | 圆角 `CoreRadius.small` 选中块，起于缩进之后 | **整行**底色（含缩进区），直角，`accentSelectedRowBackground(from: coreAccent)` |
| 悬停 | 无 | 整行底色 `Color.quaternaryFill`；选中优先于悬停 |
| 焦点指示 | 焦点环（`focusRing`，圆角 small） | `CoreBorderWidth.thin` 内描边，取 `coreAccent` |
| 缩进参考线 | 无 | 每个祖先层一根 `CoreBorderWidth.hairline` 竖线，色 `Color.borderDefault`，x 对齐该层 chevron 中心；向上溢出一个行间距，使行与行之间连成一条 |
| chevron 着色 | 取 `.tint`（默认即强调色） | 固定 `Color.contentSecondary`，不随宿主 `.tint` |

```swift
Tree(roots, children: \.children, expanded: $expanded, selection: $selection) { node in
    Label(node.name, systemImage: node.children == nil ? "doc" : "folder")
}
.treeStyle(.navigator)
.controlSize(.small)   // 行距 22，VS Code 量级
```

- **只写 `.treeStyle(.navigator)` 这种形态**（三元 `.treeStyle(flag ? .navigator : .automatic)` 也可以）。
  **不要**写 `TreeStyle.navigator`，也**不要**把 `TreeStyle` 存成属性：`TreeStyle` 将来可能升为协议，
  这两种写法届时编译不过（兼容表见 spec `docs/superpowers/specs/2026-09-23-tree-style-design.md` §2.1）。
- 外观只决定**怎么画**：键盘、选择归约、三态勾选、焦点归约、无障碍取值、命中区都在组件的行宿主上，
  换外观不影响行为。
- 取值偏离 spec 的三处（实测驱动）：悬停 spec 原写 `surfaceCanvasSubtle`——macOS 上它与 `surfaceCanvas` 同值，
  悬停不可见，改 `quaternaryFill`；选中 spec 原写 `accentSubtleBackground`（× 0.08）——与悬停分不清，改 × 0.16；
  参考线 spec 原写 `borderSubtle`——α 0.027，白底上几乎不可见，改 `borderDefault`。

#### `.navigator` 的三档阶梯：底色 < 悬停 < 选中

悬停与选中必须一眼分得清，且选中必须比悬停**更**偏离底色。× 0.08 的选中在 iOS 暗色下（0 → 20）比
`tertiaryFill` 悬停（0 → 28）还暗——阶梯倒置；iOS 亮色下两者只差 4。实测（`surfaceCanvas` 底上逐通道读数，
选中取默认墨色 `coreAccent`；括号内为宿主换成系统蓝时的选中读数）：

| | 底色 | 悬停 `quaternaryFill` | 选中 × 0.16 | 选中（宿主蓝） |
|---|---|---|---|---|
| macOS 亮 | 255 | 248 | 214 | (214, 236, 255) |
| macOS 暗 | 30 | 36 | 66 | (25, 48, 66) |
| iOS 亮 | (242, 242, 247) | (232, 232, 237) | (203, 203, 207) | (203, 225, 248) |
| iOS 暗 | 0 | (21, 21, 23) | 41 | (0, 23, 41) |

⚠️ macOS 上悬停只比底色偏 6–7 个灰阶，是刻意取的「最轻一档」——悬停是冗余反馈（指针本身已经指明位置），
不应与选中抢眼。判据 `selectionIsStrongerThanHover`（双腿，明 / 暗 × 默认墨色 / 宿主蓝）：选中与悬停逐通道差
≥ 16，且选中偏离底色多于悬停。

### 悬停

- 只有 `.navigator` 画悬停；**状态在行级**（行宿主的 `@State` + `.onHover`，与 `ListRow` 同一形态），
  不放容器——容器级状态会让指针每跨一行就重算整棵树。
- `.onHover` **只在 `.navigator` 分支挂**：`.automatic` 不画悬停，挂了只会给每一行白付一个指针追踪区域、
  每次进出白写一次 `@State`。代价是切换外观时行的视图结构跟着变（外观本来就不会逐帧切换）。
- **即时生效、无补间**，三档 `MotionPresentation` 一致，没有需要按 Reduce Motion 分支的动效。
- macOS 鼠标触发；iPadOS 指针下预期同样触发（未实测）；iPhone 纯触控下永不触发。

## 右键菜单：`rowContextMenu(_:)`

```swift
Tree(roots, children: \.children, expanded: $expanded, selection: $selection, selectionMode: .multiple) { node in
    Label(node.name, systemImage: node.children == nil ? "doc" : "folder")
}
.rowContextMenu { targets in
    Button("Delete \(targets.count) item(s)", role: .destructive) { delete(targets) }
}
```

- **目标集合**：右键的行**已选中**时，是「选中集合 ∩ 当前可见行」；否则**只是右键的那一行**（不并进已有选中）。
  「可见」指展开之后的行序列，不是视口内可见。因此被折叠隐藏的选中项、不属于本树的 ID
  （几棵树共用一个 `selection` 时）都不会传给菜单——对齐 Finder：折叠的文件夹里之前选中的项不参与右键操作。
- **唤起菜单不改变**选中、焦点与交互来源。
- ⚠️ **已知缺口（`#438`）：macOS 右键时不给目标行画指示环。** Finder / Xcode（`NSOutlineView`）右键时会给被点的行
  画 contextual-menu 高亮环，VS Code 也画；本组件不画，不是有意对齐。后果：多选时右键一个**未选中**的行，
  菜单只作用于这一行，屏幕上却仍高亮原选中——`Delete 1 item` 读不出删的是哪个。SwiftUI `.contextMenu`
  没有打开 / 关闭回调，行宿主拿不到「正在给我弹菜单」，候选机制与成本见该 issue。
- **整行都是右键区**（含缩进区）：菜单挂在行宿主上、`contentShape` 之后，与点选区同一层，换外观不丢菜单。
- **不调用就不挂**：没有 `rowContextMenu` 时行上不挂 `.contextMenu`（不是挂一个空菜单）。
- builder **只在取菜单时求值**，渲染行时不求值：行上挂的是一个小视图，它的 `body` 才调 builder。
  直接写 `.contextMenu { menu(targets) }` 时 builder 随每行的 body 求值（`ImageRenderer` 与托管窗口实测每行都会跑）。
  builder 在视图更新期执行，**必须是纯的**，不要在里面写状态。选中 ∩ 可见行每次 body 只算一次，所有行共用，不遍历整树。
- **直接在 `Tree` 上调用，放在其它 modifier 之前**（它返回 `Tree`，放在 modifier 之后编译不过）。
  ⚠️ 不要写 `flag ? tree.rowContextMenu { … } : tree` 这类按条件开关菜单：设与不设走行宿主里
  `TreeRowMenu` 的两个条件分支，切换即换分支，行内容里的 `@State` 会被重置（按 `if let` 结构推断，未实测）。要按条件禁用，
  让 builder 按条件返回不同的菜单项。
- 菜单内容是调用方的数据操作，不是外观——所以它是 `Tree` 上的 builder 方法，不在 `TreeStyle` 里，
  也不是环境值（环境值要擦除 `ID`，闭包里就拿不到强类型集合）。拖放仍不在范围内。

## 单击父行：`rowClickBehavior(_:)`（`#431`）

```swift
Tree(roots, children: \.children, expanded: $expanded, selection: $selection) { node in
    Label(node.name, systemImage: node.children == nil ? "doc" : "folder")
}
.rowClickBehavior(.selectAndToggleExpansion)   // VS Code Explorer 式：单击文件夹行即展开 / 折叠
.treeStyle(.navigator)
```

### 设计定案

| 问题 | 定案 | 理由 / 放弃的方案 |
|---|---|---|
| 参数形态 | 公开枚举 `TreeRowClickBehavior`（`.select` 默认 / `.selectAndToggleExpansion`），经 `Tree` 上的 builder 方法 `rowClickBehavior(_:)` 设置 | **不进 `TreeStyle`**：这是行为，公约《边界条款：样式不得携带行为》。**不做 init 参数**：`#422` 之后加到 `Tree` 上的能力（`rowContextMenu` / `searchFilter`）都是 builder 方法，init 保持不变、现有调用点零改动。**不做环境值**：环境值会穿透到子树里的**每一棵** `Tree`，而点击行为是某一棵树的交互设计（同一窗口里导航树与勾选树常常要不同的点击语义）。**枚举而非 Bool**：公开 API 无 Bool 入参（`BoolExemptionGuard`），也给「双击展开」之类留位 |
| 默认值 | `.select`：与 `#422` 起的现状逐字相同（只走行选中归约，不动展开态） | 已有调用方不改就不变 |
| 一次单击改了哪几份状态 | `.select`：焦点 → 被点的行、交互来源 → pointer、行选中按既有归约。`.selectAndToggleExpansion` **且被点的是父行**：焦点与交互来源照旧，行选中按下面两行，**另外**把该行的展开态取反（生效集合里有它就折叠，否则展开）。**两份状态互不读取**：行选中不看展开态，展开态不看这次点击是选中还是取消选中 | 行选中与展开是两套独立状态（本文档「选择与勾选」一节的同一原则）。放弃「这次点击取消了选中就不折叠」之类的耦合：会让同一个点击的结果依赖另一份状态，调用方推不出来 |
| `.single` 下单击父行 | **恒为选中**（替换本树里的已选 ID，不属于本树的 ID 原样保留），展开态取反 ⇒ 再点已选中且展开的父行 = 「保持选中 + 折叠」，再点已选中且折叠的父行 = 「保持选中 + 展开」 | 对齐 VS Code Explorer：单击文件夹只在展开 / 折叠之间切换，不会把自己取消选中（用户拍板）。只在 `pointerClick` 里对「父行 + `.selectAndToggleExpansion` + `.single`」走这条局部规则，`TreeSelection.toggled` 的全局语义不变：叶行与 `.select` 下再点已选中的行仍取消选中，`Space` 也仍是切换 |
| `.multiple` 下单击父行 | 行选中**仍逐行切换**（再点已选中的父行把它移出选中），展开态取反，两者独立 ⇒ 再点已选中的父行 = 「移出选中 + 切换展开」 | 放弃「多选也保持选中」：本组件的多选没有修饰键点击，**不带修饰键的单击就是多选下唯一的指针增删手势**。多选也保持选中的话，父行一旦选中，指针就再也移不出选中集合——iOS 触控没有 `Space` 可按，只能靠选别的行也不行（多选下选别的行不会清掉它）。VS Code 的类比也指向这边：它的「保持选中」来自单击即替换选中（对应本组件的 `.single`），逐项增删用的是 Cmd+单击，而 Cmd+单击文件夹会把它移出选中。差异：VS Code 的 Cmd+单击文件夹**不**切换展开，本组件会。⚠️ 本行为执行者定案，待用户确认 |
| 行内容里的可交互控件 | 调用方放进行内容的 `Button` 等自己的控件**先接到点击**（`Link` 按同一机理推断、未测）：这一击只触发该控件，行不选中、不切换展开 | SwiftUI 手势优先级：子视图的 `Button` 先于祖先上的 `onTapGesture`，与 chevron 不被行上的点选手势收到同一机理。要「点控件同时选中行」由调用方在控件动作里自己写 `selection` |
| 修饰键 | 行上的点击**不读修饰键**（`#422` 起如此：点选走 `onTapGesture`，没有 Shift / Cmd 点击的范围选 / 追加语义），因此带修饰键的单击与普通单击相同，`.selectAndToggleExpansion` 下同样切换展开（按源码推断；真 HID 下修饰键点击是否仍送达 `onTapGesture` 未实测） | 组件没有修饰键点击语义可供区分；将来要加 Shift / Cmd 点击，另开 issue 一并定「修饰键点击是否切换展开」 |
| 点 chevron | 仍**只**切换展开，不选中（chevron 是独立的 `Button`，行上的点选手势收不到这次点击）；`.selectAndToggleExpansion` 下也**只切换一次**，不会被行上的点击再切回去 | chevron 与整行各管各的；两者都切换时一次点击等于没点 |
| 点复选框 | 不受影响：只写 `checked`，不选中、不动展开 | 勾选是数据语义，与点击行为无关 |
| 叶行 | 不受影响：两种取值下都只选中 | 叶行没有展开态 |
| 键盘 | 不受影响：`Space` 仍只切换选中、`←` / `→` 仍只展开 / 折叠、`Enter` 仍只激活 | 本参数只管指针单击 |
| 搜索期间（`#423`） | 展开态的写入与点 chevron 同一路径（`TreeExpansionState.set`）：写 overlay、**不写** `expanded` 绑定；清空搜索词即丢弃 | 与 `#423`「临时展开写到哪」一行同一定案 |
| 动效 | 展开事务与点 chevron / 按 `←` `→` 同一个 `withAnimation(CoreMotionToken.treeExpansion(for:))`，Reduce Motion 分支不变；选中底色仍按 `.coreAnimation(.selection, …)` | 没有新增动效 ⇒ 没有新的 Reduce Motion 分支 |
| 点到正在淡出的行 | 折叠动画期间，被折叠掉的子行还在屏幕上淡出、仍能接到点击。单击行与点 chevron 都按**点击当时的展开态**归约（数据与搜索词仍取渲染时的值）：被点的行已不在可见行里 ⇒ 这一击什么都不改（焦点、交互来源、选中、展开都不动，也不把键盘焦点拿进树）；chevron 的取反目标取当时的生效展开态，不取该行渲染时的 `isExpanded` | 淡出中的行保留的是渲染时的旧闭包。按旧快照归约时，`.selectAndToggleExpansion` 下搜索期间实测会把旧 overlay 整个写回——刚折叠的父行被重新展开，淡出的子行被选中（`TreeSearchHostedTests` 两种外观都复现）；点淡出子行的 chevron 同理会把旧 overlay 写回；`.select` 下按快照归约会选中这个已不可见的行（按代码推断，未实测） |
| 无障碍提示 | `.selectAndToggleExpansion` 下父行带本地化 `accessibilityHint`："Activate to expand or collapse"；叶行与 `.select` 下不带 | 激活行内容会同时切换展开，不说出来辅助技术用户预料不到 |

- 行为落在纯函数 `TreeInteractionReducer.pointerClick`：它先按行为与「该行是不是父行」分叉——非切换情形走既有点选归约；切换父行时 `.single` 用 `TreeSelection.replacing` 替换、`.multiple` 逐行切换——再取反展开态并带出环境动效档；
  视图只把点击转给它、把结果经同一个 `commit` 写回（与点 chevron 共用写回与动效路径）。
- ⚠️ **推断、未实测**：VoiceOver / 切换控制对行内容元素的「激活」经 `onTapGesture` 到达时，同样会切换展开；本仓装置读不到辅助技术的激活语义。
- ⚠️ **非 key 窗口里的首击**（见「判据覆盖到哪」）：行上的点选手势在非 key 窗口里首击不生效，`.selectAndToggleExpansion` 下这一击同样既不选中也不展开。
- ⚠️ 不在搜索时，托管窗口里「折叠后紧接着点第 2 行位置」点到的是已上移的 `b`，没能构造出「点到淡出行」——
  不搜索时的这一格没有判据（修法相同：单击与 chevron 一律按点击当时的展开态归约）。
- ⚠️ 「被忽略的点击不把键盘焦点拿进树」没有判据：托管窗口里读不到这一击前后容器焦点的变化来源（按代码：焦点只在归约接住这一击后才申领）。
- ⚠️ 无障碍提示只有取值判据（哪种行、哪种行为带哪个 key，key 已登记）；视图确实挂上了、VoiceOver 读出来了未实测。

## 搜索过滤与命中高亮（`#423`）

```swift
@State private var query = ""

TextField("Filter", text: self.$query)
Tree(roots, children: \.children, expanded: self.$expanded, selection: self.$selection) { node in
    Label { Text(verbatim: node.name, highlighting: self.query) } icon: { Image(systemName: "doc") }
}
.searchFilter(self.query, text: \.name)

// 命中数 / 空态由宿主做（组件不显示空态、不播报）
let matches = Tree.searchMatches(roots, id: \.id, children: \.children, query: self.query, text: \.name)
if !self.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, matches.isEmpty {
    ContentUnavailableView.search(text: self.query)
}
```

两个术语，下文严格区分：
- **保留节点**：命中节点、它们的祖先与后代的并集。
- **可见行**：保留节点按当前**生效**展开态（持久化 ∪ 自动展开 ∪ overlay 展开 − overlay 折叠）展平后的行序列，
  与视口裁剪无关。命中的文件夹折叠着时，它的后代是保留节点、但不是可见行。

### 设计定案

| 问题 | 定案 | 理由 / 放弃的方案 |
|---|---|---|
| 搜索词谁持有 | **调用方**，每次 body 把当前值传给 `searchFilter(_:text:)` | 与 `expanded` / `selection` 同一惯例（组件不藏状态）；搜索框放哪（工具栏、`.searchable`、行内 `TextField`）是宿主的事。组件自带搜索框会把布局写死 |
| 匹配谓词 | 调用方给**文案投影** `text: (Element) -> String`，谓词由组件**固定**：去首尾空白后的整串，按不区分大小写 / 变音符 / 全半角做子串匹配，组合与分解形式的 Unicode 视为相同；不带 locale；空串 = 不在搜索 | 组件不持有节点文案，只能由调用方投影。谓词不开放，是为了让过滤、`searchMatches` 与高亮是**同一条规则**——调用方自定谓词时，高亮的片段与「为什么这行被留下」对不上。多字段可以在投影里拼接，但**拼接不是模糊匹配**，还可能跨字段边界命中（`"ab" + "cd"` 命中 `"bc"`）；显示的文案与投影不一致时，由调用方解释命中来源。真要自定谓词另开 issue |
| 过滤后留下哪些行 | **命中 ∪ 命中的祖先 ∪ 命中的后代** | 祖先：不留就无法定位；后代：命中一个文件夹后要能展开浏览它的内容（Xcode 导航器过滤同型）。只留「命中 ∪ 祖先」时，命中的文件夹变成没有 chevron 的行，而它的复选框又级联不到任何可见叶子 |
| 自动临时展开 | **命中的严格祖先**全部临时展开；命中后代不自动展开（沿用调用方持久化集合里的展开态） | 展开到「看见每个命中」为止，不多展一层 |
| 临时展开写到哪 | `TreeExpansionState` 的 overlay（`#422` 为本 issue 预留的结构）：生效集合 = 持久化 ∪ 自动展开 ∪ overlay 展开 − overlay 折叠。搜索期间点 chevron / `←` / `→` **只写 overlay**，调用方的 `expanded` 绑定不被写（真值表第 4 行） | 否则搜一次就永久改了用户的展开偏好 |
| 清空搜索 | 搜索词变成空串（含只剩空白），overlay 整个丢弃，生效集合回到调用方**当前**的 `expanded`（第 5 行）；宿主在搜索期间没改过 `expanded` 时即为搜索前的展开态。搜索词**每变一次**（按去首尾空白后的值比较，只增删首尾空白不算变），overlay 里用户手动的展开 / 折叠也清零，按新命中重新自动展开；清空后再搜同一个词也从头开始 | 换了关键词，旧的手动折叠会把新命中藏起来 |
| 非命中但为命中祖先 / 后代的行 | **照常画**，不变暗；只有命中片段被高亮 | 行内容是调用方的视图，组件改它的前景色会覆盖调用方的着色（例如 VS Code 示例里的 git 状态色） |
| 命中高亮 | 组件**不往行内容里注入**任何东西；公开 `Text(verbatim:highlighting:)`，与过滤共用同一个取片段的函数：从左到右逐个找、**不重叠**（`"aa"` 在 `"aaaa"` 里是 2 段），片段取原文里的那一段、不改写原文；`AttributedString` 给片段加粗 + `Color.searchMatchBackground`（第 3 层，系统黄 × 0.35，暗色 × 0.20）底色。暗色取更淡的一档：iOS 模拟器截图实测，`.navigator` 选中行上叠 git 状态色时，× 0.35 让橙字对比度从 5.61 降到 2.51、绿字从 5.12 降到 2.29；改 × 0.20 后为 3.54 / 3.23（普通行白字 10.23）。亮色的 git 状态色在选中行灰底上本来就只有 1.6 左右（不加高亮 1.67），高亮几乎不改变它（1.60），那是画廊示例的取色问题，不是高亮造成的 | 行内容是调用方的 `@ViewBuilder`，组件改不了其中某段文字；环境值方案需要新增一个公开 View 类型读环境。规则相同只保证：**仅当**调用方给 `highlighting:` 与 `searchFilter` 传入相同的搜索词、相同的文案时，片段一致——调用方可以高亮别的文案、传别的词，或根本不用它；`searchFilter` 本身不产生高亮。加粗是**非颜色**线索（不只靠颜色区分） |
| 选择 / 焦点 / 右键菜单 / 键盘 | 全部作用在**可见行**上：`↑` / `↓` / `Home` / `End` 只在可见行里走；`Ctrl/Cmd+A` 只选可见行（第 6 行）；右键目标取「选中 ∩ 可见行」；焦点行被过滤掉时移到最近的仍可见祖先，无祖先则移到首个可见行（第 7 行，走 `#422` 既有的可见行变化归约） | 与折叠隐藏同一套口径，没有第二套「可见」定义 |
| 父行复选框 | **显示**：三态始终按它**全部**叶后代算（保留的 A 勾、被过滤掉的 B 未勾 ⇒ mixed）；清空搜索时三态不突变。**点击**：按「**保留**的叶后代是否全勾」翻转——全勾 ⇒ 取消保留的叶子，否则 ⇒ 勾上全部保留的叶子；保留的叶后代包括因折叠未显示的，不含被过滤移除的；范围外的叶子勾选值不变，父 ID 不进 `checked`。换词 / 清空只改变显示与动作的范围，本身不写 `checked` / `selection`。⚠️ 范围外的叶子本身就是半勾时，父行点击前后都显示 mixed、VoiceOver 前后都读 mixed，变化只能在保留的叶行上看到。搜索期间父行复选框带本地化无障碍提示 "Applies to filtered results only"。不在搜索时与 `#422` 相同（系统 `Toggle(sources:)` 级联全部叶后代）；叶行不受影响 | 用户拍板。显示按全部叶子是为了不撒谎（只算保留的叶子时 A 勾就显示全勾，清空后突然变 mixed）；动作只作用于保留的叶子，是真值表第 6 行的依据「作用到全树会静默勾上看不见的项」在级联上的延伸。**不能**直接给 `Toggle(sources:)` 接全部叶子、把被过滤叶子的 setter 置空：mixed 下系统写 `true`，保留的叶子已全勾时点击无效，卡在 mixed（变异实测判红）。实现：仍用 `Toggle(sources:)` + `CheckBoxToggleStyle` 呈现三态，来源换成恰两路合成绑定 `[任一叶子已勾, 全部叶子已勾]`，系统据此派生 off / mixed / on；动作只挂在第二路的 setter 上，不看系统写入的值。放弃的方案：单个自定义 `Binding<Bool>`——`ToggleStyleConfiguration` 没有公开构造，`isMixed` 只由 `Toggle(sources:)` 派生，画不出 mixed；`Toggle` 只作显示、另挂手势——点击与 VoiceOver 激活要各接一次，还要压掉样式自带的点按 |
| 单选替换 | 不变：单选下选中一行，仍替换本树内全部已选 ID（含被过滤掉的） | 单选的语义是「树里只有一个选中」，与过滤无关 |
| 动效 | 过滤结果随搜索词**即时**变化，不补间；搜索期间点 chevron / 按键展开仍走 `CoreMotionToken.treeExpansion(for:)`（同一个 `withAnimation`，Reduce Motion 分支不变） | 逐键输入时补间会让行跳动；没有新增动效 ⇒ 没有新的 Reduce Motion 分支 |
| 无结果 | 可见行为空，组件不画任何行、**不显示空态**；内部行焦点置空；导航 / 激活 / 全选交回系统，不操作之前的隐藏行，不改 `selection` / `checked` / `expanded`（被过滤掉的已选项保持已选）。结果重新出现时焦点仍为空，下一次键盘进入（或按键）按初始焦点规则解析：首个已选的可见行，否则首行 | 空态文案与位置是宿主的布局；宿主用 `Tree.searchMatches(_:id:children:query:text:)` 判空，不必复刻匹配规则 |
| 结果数 | 口径 = **直接命中的节点数**（`searchMatches(...).count`），不计只作上下文保留的祖先 / 后代。组件**不自动播报**，由宿主本地化播报（画廊示例：搜索词稳定 300 ms 后用 `AccessibilityNotification.Announcement` 播报一次） | 播报时机（防抖、零结果、是否抢焦点）取决于宿主的搜索框交互，组件不知道何时算「输入完成」 |
| 输入法组字 | Tree 对收到的**每个** `query` 值立即过滤，**不识别组字状态**（`String` 不带 marked text 信息）。宿主若不想让拼音组字中的中间串触发过滤，应在组字期间保留上一次已提交的查询、提交后再更新传给 `searchFilter` 的值，取消组字不更新。SwiftUI `TextField` 不公开 marked text，要区分组字需桥接 `UITextField.markedTextRange` / `NSTextView.hasMarkedText()`，见下方示例 | 组件拿不到输入框，只能由宿主决定「哪个值算搜索词」 |
| 惰性 | **不搜索时零代价**（`TreeLazinessTests` 的承诺不变，加一条「设了 `searchFilter` 但搜索词为空」的格）；**搜索期间每次 body 求值遍历整树一次**，读每个节点的 `children` 与投影文案并各做一次匹配。body 求值不只由换词触发：选中变化（点行、`Space`、`Cmd+A`）、焦点移动（方向键）、展开 / 折叠、宿主改 `checked` 都会让 `Tree` 的 body 重算，每次都再遍历一遍。父行复选框另有「惰性」一节登记的子树遍历（搜索期间显示与动作范围各一次） | 不读折叠子树就不可能知道折叠子树里有没有命中。代价如实登记。本轮不缓存：通用 `Data` 无法廉价判等，只按搜索词做键会在数据变化时给出过期的行；调用方显式传版本号的最小方案见 `#441`。读数见「惰性」一节 |

- 公开 API 无 Bool 入参；`query` / `text` 是调用方数据（用户输入与节点文案），不是组件文案，所以是 `String`
  而不是 `LocalizedStringKey`。
- `searchMatches` 是 `nonisolated` 的纯函数，非 MainActor 语境也能调用（`scripts/downstream-probe` 的
  `NonisolatedUsage.swift` 覆盖）；形态照 `expandedIDs(_:id:children:toDepth:)`：`Tree` 上的静态函数 +
  `where RowContent == EmptyView` 的免写泛型重载。没有另开 `String` 上的匹配谓词：宿主要的是「整棵树命中几个」，
  只给谓词就要宿主再写一遍遍历。
- `searchFilter(_:text:)` 与 `rowContextMenu(_:)` 一样是 `Tree` 上的 builder 方法，**直接在 `Tree` 上调用、放在其它 modifier 之前**；
  两者可以连写。
- 行为落在纯函数层：`TreeSearch`（匹配、留下的集合、自动展开集合、overlay 的派生与回写）与既有的
  `TreeInteractionReducer`（键盘 / 点击对展开态的写入改为经 `TreeExpansionState`），外加 `TreeChecking`
  （父行复选框的显示来源、按保留叶子翻转）。视图只把搜索词与投影交给它们。

输入法组字的宿主接入形态（iOS；macOS 同理换成 `NSTextView.hasMarkedText()`）。⚠️ 这是接入形态说明，**没有实测**
SwiftUI `TextField` 在组字期间是否把中间串写进绑定，也没有在真 HID 上验证这段代码：

```swift
struct CommittedSearchField: UIViewRepresentable {
    @Binding var committed: String   // 传给 searchFilter / searchMatches 的值

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        field.addTarget(context.coordinator, action: #selector(Coordinator.changed(_:)), for: .editingChanged)
        return field
    }

    func updateUIView(_ field: UITextField, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(committed: self.$committed) }

    final class Coordinator: NSObject {
        let committed: Binding<String>
        init(committed: Binding<String>) { self.committed = committed }

        @objc func changed(_ field: UITextField) {
            guard field.markedTextRange == nil else { return }   // 组字中：保留上一次已提交的查询
            self.committed.wrappedValue = field.text ?? ""
        }
    }
}
```

## 动效

| 调用点 | token | Reduce Motion 下 |
|---|---|---|
| chevron 旋转 | `CoreMotionToken.reveal.transformAnimation(for:)` | `nil`，直接到终态角度 |
| 展开折叠（点 chevron、键盘 `←` / `→`、`#431` 单击父行同一个函数） | `withAnimation(CoreMotionToken.treeExpansion(for:))`，即 `reveal.animation(for:)` | 同时长 `easeInOut`（`reveal` 档「展开」的既有口径，与 `CoreDisclosureGroupStyle` 相同）；`hidden` 下不补间 |
| 选中态切换 | `.coreAnimation(.selection, value: self.selection)` | 按 `CoreMotionToken.selection` 的裁决 |
| `.navigator` 悬停 | 无（即时生效） | 无分支可言 |

⚠️ `#429` 展平后，展开由「`DisclosureGroup` 内容整体插入」变为「若干行插入 `ForEach`」，仍在同一个 `withAnimation` 事务里。
静态终态逐像素相同（迁移对照），**在飞帧的样子未验证**（没有真机人工看过）。

判据分三层，射程各不相同：

- `TreeMotionTests.expansionAnimationHonoursReduceMotion` **只判 token 函数** `CoreMotionToken.treeExpansion(for:)`
  的三档取值，不判视图有没有把环境动效档传进去。
- `TreeInteractionReducerTests.expansionCarriesTheEnvironmentMotion` 判归约：键盘 `←` / `→` 与点 chevron 的
  展开都原样带出传入的动效档。
- `TreeHostedWiringTests.expansionTransactionsFollowTheEnvironment`（**仅 macOS 腿**，托管窗口 + 合成
  鼠标 / 键盘事件）判视图透传：注入 `coreMotionPresentationOverride` 后，点 chevron 与按 `←` 产生的展开事务
  带的曲线等于该档的 token 取值，`hidden` 下不带曲线。

## 无障碍与触控

- 父行 `accessibilityValue` 播报 "Expanded" / "Collapsed"（自绘 `Button` 不会被系统自动播报，这一层是唯一来源）；
  chevron 的 `accessibilityLabel` 说的是**动作**（"Expand" / "Collapse"）。四个 key 都走 `bundle: .module`。
- 已选行带 `.isSelected` trait。
- **行级无障碍取值只挂在行内容上**（`#427` 起）：展开态 value、单击提示、`.isSelected` trait 与勾选动作都施在
  `content` 上，不再施在整行上。整行不是一个元素，施在整行时这些取值会复制到行里的每个元素上——复选框因此报成
  `'Expanded'` / `''`，把系统给的勾选值盖掉了（`#427` 的一半根因）。代价：chevron 不再带 "Expanded" / "Collapsed"
  value（它的 label 仍说动作）。
- **复选框的名字 = 行内容**（`#427`）：`Tree` 把行内容作为复选框 `Toggle` 的 label 传入并 `.labelsHidden()`；
  `CheckBoxToggleStyle` 在 labels 隐藏时不画 label、只把它交给无障碍标签（见 [checkbox.md](checkbox.md)）。
  勾选态由系统 `Toggle` 自己报：AXValue `0` / `1` / `2`（off / on / mixed，`2` 由 `Toggle(sources:)` 派生）。
  传了 `checked:` 时行内容多一个副本（作复选框的无障碍标签，不画出来）。评审探针实测（macOS 托管窗口、没有辅助技术客户端）：
  这份副本**不求值 body、不触发 `onAppear`**。有辅助技术客户端接入时是否求值、行内容里的 `@State` 是否另起一份：**未验证**。
- **行内容上的勾选动作**（`#428`）：传了 `checked:` 时，行内容带自定义无障碍动作 "Check" / "Uncheck"
  （动作范围的叶子全勾时是 "Uncheck"），作用与点该行复选框相同（父行级联、搜索期间只作用于保留的叶子）。
  执行动作**不改交互来源**（不同于点复选框会置为指针）：键盘用户用动作勾选后焦点环照旧。
  行内容是多个元素时（例如 `Label` 的图标与文字），每个元素都带这个动作。
- **chevron 命中槽 = 展开槽宽 × 行高**（`.regular` 为 24×44 pt；iOS 各档高都 ≥ 44）。
  原先按钮只有图标大小（实测 12×7 pt），在 iOS 上偏离 10 pt 的点击会落到紧邻的父行复选框上，
  **一次点击勾上整棵子树**；判据 `TouchTargetTests.treeDisclosureMeetsMinimumTouchTarget`（iOS 腿，五档参数化）。
- 行高 ≥ 44 pt（五档）：判据 `TouchTargetTests.treeRowMeetsMinimumTouchTarget` 与
  `TouchTargetTests.treeCheckBoxRowMeetsMinimumTouchTarget`（iOS 腿，五档参数化）。
- ⚠️ 横向：展开槽宽 20–32 pt < 44 pt，现判据只核高度，登记为已知项。
- 行在无障碍树里**不是一个元素**：父行拆成 chevron（`Button`）、复选框、行内容三个元素（`#427` 保持这个形状）。
  没有改成 `.accessibilityElement(children: .combine)`：合并后 chevron 与复选框不再是独立可激活的目标，
  调用方行内容里的 `Button` 也会被并进去。⚠️ 仍未处理：`Label` 行内容的图标是独立的 `AXImage`、label 是 SF Symbol 名
  （`folder` 读作 "Move"），`#427` 的评论里登记过，本次没动（修法要么合并行内容、要么由调用方给图标 `accessibilityHidden`）。
- **`#427` / `#428` 前后的无障碍实读**：iOS 26.4 模拟器（预览宿主 Tree 画廊，`axe describe-ui`），多选 + 三态复选框那棵树
  （`checked = ["color"]`）：

  | 元素 | 修前 AXLabel / AXValue | 修后 AXLabel / AXValue / 自定义动作 |
  |---|---|---|
  | 父行 `Design` 复选框（mixed） | `Remove` / `Expanded` | `Design` / `2` |
  | 叶行 `README.md` 复选框（off） | `Square` / `''` | `README.md` / `0` |
  | 叶行 `Icons` 复选框，点一下之后 | —— | `Icons` / `1` |
  | 行内容 `Design` | `Design` / `Expanded` | `Design` / `Expanded` / `['Check']` |
  | 行内容 `Icons`（已勾） | —— | `Icons` / `''` / `['Uncheck']` |
  | chevron | `Collapse` / `Expanded` | `Collapse` / 无 |

  macOS 26（`422-probe`，`AXUIElementCopyAttributeValue` 读 `AXDescription` / `AXValue`，动作取 `AXUIElementCopyActionNames`）：
  修前叶 / 父复选框都是 `AXCheckBox` desc `Square`、value `0`；修后 desc 为行文字（`Alpha`、`Beta`…）、value `0` / `1`，
  行文字元素带 `Check` / `Uncheck` 动作；对 `row-c1` 执行 `Check` 动作，`checked` 事件为 `+["c1"]`。
  ⚠️ System Events 的 `description` 在这类 SwiftUI 元素上取不到 label（报 attribute 不存在），要用 AX API 直接读。
  ⚠️ VoiceOver 实际念出来的字、以及 VoiceOver 双击激活复选框是否切换：**未验证**（装置只读快照、只能执行动作）。
- **展平前后的无障碍树对照**（`#429`，iOS 26.4 模拟器，预览宿主 Tree 画廊，同一操作序列——组件详情页、展开到第 3 层、
  再滚动一屏——各读一次 `axe describe-ui`，逐元素比对类型 / label / value / frame）：
  1. **视口外的行不在无障碍树里**：展平前 6 棵树（明 / 暗各 3 棵）的全部行都在，不论是否在屏幕上；展平后只有与窗口
     相交的行在，滚进来才出现（首屏整页的视口外元素 81 → 9，剩下的 9 个都是画廊里的说明文字，没有一个是树行）。直达预览（不在 `ScrollView` 里、内容溢出屏幕上下缘）
     同样如此。这是 `LazyVStack` 的行为：放在 `ScrollView` 里时 VoiceOver 靠滚动走到后面的行，与 `List` 同型；
     ⚠️ 不放在可滚动容器里、又被裁出屏幕的行，辅助技术**够不到**——展平前它们至少还在树里。
     VoiceOver 实际的逐项滑动能否滚到视口外的行，**未验证**（本套装置只读快照，读不到 VoiceOver 的导航）。
  2. 每棵树多出一个匿名 `AXGroup` 容器包住它的行。
  3. **父行复选框的元素类型从 `Button` 变为 `CheckBox`（`AXSwitch`）**，与叶行一致；label 仍是 SF Symbol 名（见 `#427`；已修，见本节下方）。
  4. 放在 `ScrollView` 里时，`.navigator` 示例里 `Label` 的图标展平前不是独立元素、展平后是独立的 `AXImage`
     （详情页展开后那一屏：展平前 0 个、展平后 11 个）。实读：`folder` 图标是 `AXImage`，label `'Move'`（SF Symbol 的名字），
     value `'Expanded'`——行上的 `accessibilityValue` 被复制到了图标上。⚠️ 这不是本次独有：展平前的直达预览
     已有同样 12 个 `AXImage`、取值相同。成因未查明。并入 `#427` 后仍未处置（见本节上方「行在无障碍树里不是一个元素」）。
  5. 其余视口内元素的类型、label、value、frame 逐一相同。
  ⚠️ 以上 1–5 都是 **iOS** 读数；**macOS 的无障碍树未做前后对照**（本次会话屏幕锁定，System Events 读不到窗口）。
  ⚠️ `axe describe-ui` 的输出不含 traits，`.isSelected` 这一项读不到；它的取值由 `TreeAccessibilityTests` 的纯函数判据
  与行宿主上未改动的 `accessibilityAddTraits` 保证。
- `#427` 的根因更正：issue 原写根因在 `CheckBoxToggleStyle`（裸 `Image` + `onTapGesture`、没有无障碍修饰）。实测独立使用的
  `Toggle("Accept terms", isOn:)` + `CheckBoxToggleStyle` 修前就读作 `Accept terms` / `0`——无障碍元素由系统 `Toggle` 提供，
  样式 body 里加的 `accessibilityValue` / `accessibilityHidden` 在 iOS 上实读**不生效**（试过，已撤掉）。
  真正的根因在 Tree：label 是 `EmptyView()`（系统只能取到指示符的符号名），且行上的 `accessibilityValue` 盖掉了系统的勾选值。
- ⚠️ **未验证**：macOS 上 `.focusable()` 容器是否另画一圈系统焦点环（与行上的焦点环叠加）。
  本机会话没有屏幕录制权限，`screencapture` 取不到图，没能实看；iOS 截图上没有容器级的环。

## 惰性：什么时候读 `children`

- 渲染与按键**只读可见行**的 `children`（折叠的父行读一次自身的 `children` 以判断有没有 chevron，
  不下探）；`children` 是计算属性（如惰性加载的文件浏览器）时，折叠的子树不会被强制加载。
  判据：`TreeLazinessTests`（计数 `children` 读取次数的样本）。
- **只有单选模式下切换选中**（点行、`Space`；单选下 `Shift+↑/↓` 只移焦不切换，不遍历）会遍历整树：单选要替换
  已选集合里属于本树、但被折叠而不可见的旧选中项，只能求整树 ID。多选不遍历。
- 可见行变化后的焦点归约用**变化前的行**求祖先，不回头遍历数据。按键时若焦点行已不可见
  （可见行变化的回调还没来得及归约）才按数据求祖先——正常路径上不发生。
- 挂了 `rowContextMenu` 时，目标集合只用可见行求交，不读折叠子树（`TreeLazinessTests` 带菜单渲染的一格）。
- **行视图的构建也是惰性的**（`#429`）：可见行一次遍历展平成一列，直接作为 `LazyVStack` 的 `ForEach` 子项，
  每行的身份是节点 ID。放在 `ScrollView` 里时只构建视口附近的行：300 pt 视口、展开一个有 200 个子节点的父节点，
  实测构建 7 行（macOS / iOS 相同；判据 `TreeFlattenedRenderingTests`，上限 < 20）。
  不放在 `ScrollView` 里时**也不是全量构建**：同一夹具放进 300 pt 高的 macOS 托管窗口、不包 `ScrollView`，
  实测构建 10 行（直接放、`frame(maxHeight: .infinity)`、`fixedSize(vertical:)` 三种放法相同）——`LazyVStack`
  按窗口可见区裁，不看有没有可滚动容器；这与下面「无障碍与触控」第 1 点里直达预览的读数一致。
  ⚠️ `ImageRenderer` 下是全量构建（同一夹具 201 行）。iOS 托管窗口上这一项未测。
  ⚠️ `#422` 的递归 `DisclosureGroup` 下，一个根节点的整棵可见子树是**一个**子项——同一夹具构建 201 行；
  换成惰性容器而不展平，收益为零。
- **搜索（`#423`）**：`searchFilter` 的搜索词为空（去首尾空白后）时不遍历，上面几条不变
  （`TreeLazinessTests` 的空搜索词一格）；有搜索词时**每次 body 求值遍历整树一次**，读每个节点的 `children`
  与投影文案——不下探就不知道折叠子树里有没有命中。同一格的正向对照判「有搜索词时读到了折叠的 `c1`」。
  按键与点击的归约不另遍历：它们用 body 算好的那一份；但选中、焦点、展开的每次变化都让 body 重算，于是再遍历一次。
  单次遍历读数（`Tree.searchMatches`，与过滤同一个遍历函数；Apple M2 Pro / macOS 26.3.1，release，每格 25 次取中位数 / p95）：
  宽树 1 × 10 000 叶子、少量命中 18.6 / 19.8 ms，无命中 19.2 / 22.9 ms；均衡树（10 叉 4 层，11 110 节点）少量命中
  32.6 / 46.6 ms，无命中 31.1 / 38.9 ms，全部命中 8.8 / 12.7 ms（命中的串匹配提前结束）；链状深树 2 001 层 3.4 / 4.2 ms。
  ⇒ 万级节点下一次遍历就超过 60 Hz 的一帧（16.7 ms）。**数值预算与支持规模未定，发布前确定**（跟进 `#441`）。
  未测：iOS 设备、峰值内存、查询输入到画面呈现的端到端延迟、带 `checked` 时父行复选框的额外代价。
- ⚠️ 传了 `checked` 时，父行复选框的三态要读它**全部叶后代**的勾选态，因此会遍历该父行的整棵子树，
  折叠与否都一样。这是三态派生本身的代价。行宿主每次 body 求一份勾选范围（`TreeRowCheckScope`），复选框与行内容上的
  勾选动作共用：不搜索时遍历子树 **1** 次（显示与动作范围相同），搜索期间 **2** 次（全部叶后代 + 保留的叶后代）。
  `⌥Space` 只在按键时对焦点行遍历一次。

## 判据覆盖到哪、哪些接线不在 CI

按键、点击、获焦、可见行变化对内部状态的作用收在纯归约 `TreeInteractionReducer`
（`TreeInteractionReducerTests` 判）：焦点先归约再执行、被接住的键置键盘交互、点击置回 pointer、
非点击获焦置键盘交互并解析焦点行、展开带环境动效档、`Enter` 无回调时交回系统。
视图里只剩「把事件转给归约、把结果写回」。

macOS 托管窗口判据 `TreeHostedWiringTests` 另外覆盖：按键经 `onKeyPress` 真的到达归约并写回宿主绑定、
展开事务的曲线取自环境。⚠️ 它**不在 iOS 腿上跑**（`#if os(macOS)`）。

⚠️ **以下接线只由真 HID 探针覆盖、不在 CI**（托管窗口不是 key window，实测按键被接住后焦点环也不出现——
推断容器的 `isFocused` 没有变真，未直接读到）：
- `.onChange(of: isFocused)` 本身，以及区分「点行获焦」的一次性标记；
- `.onChange(of: rows)` 本身（焦点行被隐藏后环跟到祖先行上）；
- 焦点环是否真的画在屏幕上（渲染判据只判行宿主 `TreeRowHost` 收到 `showsFocusIndicator` 后画不画）；
- 点 chevron / 点复选框把交互来源置回 pointer 的调用点（归约函数本身有判据）。
- ⚠️ **未验证**：`Tab` 进入后环直接出现在已选行 / 首行——本次改动后没有跑真 HID。
- **非 key 窗口里的首击**（`#429` 托管窗口实测，待真 HID 复核）：chevron（`Button`）与复选框（`Toggle`）
  在非 key 窗口里首击即生效，行上的 `onTapGesture` 首击**不**生效——同一次点击，点 chevron 展开了、点行内容却不选中。
  真 HID 下要确认的是：窗口未激活时第一次点行，是只激活窗口还是同时选中；两种外观应当一致。
- **悬停的接线**（`#429`）：`.onHover` 真的把状态写进行宿主、以及「悬停只让进出的两行重算、不重算整棵树」。
  托管窗口里合成悬停不可行（`mouseMoved` / `mouseEntered` 经 `sendEvent` 或直接调 `NSHostingView` 的方法，
  `onHover` 回调都是 0 次）⇒ 两条都没有自动判据。剩下的网只有源码判据：`.onHover` 只在行宿主内、
  容器 `Tree` 没有名字含 `hover` 的成员变量——**按名字匹配**，把容器状态起名 `pointerRow` 就漏。
- **悬停命中区**：`.navigator` 行在 `.onHover` 之前挂了 `.contentShape(Rectangle())`，意在让从行右侧空白 / 缩进区进入也点亮（空闲态底色是 `Color.clear`）；真指针下从这两处进入是否点亮，**未验证**。
- **悬停中滚出视口再滚回不残留**：`.navigator` 行离开视口时（`onDisappear`）把悬停复位——`LazyVStack` 回收行时
  不保证先送一次「指针离开」。指针停在某行上滚动（触控板 / 滚轮）、该行滚出再滚回时不应仍是悬停底色，**未验证**。
- iPadOS 指针下 `onHover` 是否触发。
- **右键菜单的真实唤起路径**（`#429`）：真右键 / 双指点按 / Control-点按（macOS）、长按（iOS）真的弹出菜单，
  且**唤起后选中、焦点、交互来源都不变**；iOS 长按升起的预览 / 高亮是被按的那一行（含缩进区），而不是整棵树
  ——整棵树只挂 1 个 `UIContextMenuInteraction`、按位置分派，预览走 delegate 的 `previewForHighlightingMenuWithConfiguration`，没有判据。判据只对行所在点调 `NSView.menu(for:)`——那是菜单的构建，不是唤起。
  经 `sendEvent` 合成 `rightMouseDown` 会进入菜单的模态追踪，可用 `NSMenu.didBeginTrackingNotification` +
  异步 `cancelTracking()` 退出（合成右键确实弹出了该行的菜单，选中与展开未变）；⚠️ 但在 `swift test` 进程里
  这样做，该测试返回后**测试进程以退出码 0 整体退出**，后面的测试一条都不跑（退出栈在
  `swift_task_asyncMainDrainQueue` → `exit`）；在通知里同步 `cancelTracking()` 则追踪不退出、进程挂住。
  ⇒ 没有采用为判据，这一项仍只在真 HID 清单里。
- **两种外观下无障碍取值相同**的运行时读数：托管窗口的 `NSHostingView` 读不到无障碍子树（KVC 读
  `accessibilityChildren` 只有根 `AXGroup`）。现有的网是源码判据：`accessibilityValue` / `accessibilityAddTraits` /
  `onTapGesture` / `contentShape` 只挂在行宿主上、两种外观类型里一处都没有。

`#429` 起的外观判据（macOS 托管窗口判据**只在 macOS 腿**）：
- `TreeHostedWiringTests`：点 chevron / `←` 的展开曲线、按键写回选中、**点行选中**、**点缩进区选中**、
  **点复选框勾选（叶行 + 父行级联）**，每条都对 `.automatic` / `.navigator` 参数化，结论逐条相同。
  ⚠️ 托管窗口不是 key window，行上的 `onTapGesture` 收不到合成点击（`Button` / `Toggle` 能收到）——
  harness 加了 `.allowsWindowActivationEvents(true)` 才收到。这是托管窗口的限制，不是组件行为。
- `TreeStyleRenderTests`（双腿）：`.navigator` 画悬停、选中压过悬停、**选中强于悬停的三档阶梯**
  （`selectionIsStrongerThanHover`）、焦点指示按需画、选中底色铺满缩进区（`.automatic` 不铺）、
  chevron 不随宿主 `.tint`；行配置不含函数类型字段。展开控件的动作闭包与复选框的绑定都是 `private`，
  外观拿到部件也调不到——这一条由编译器保证，不靠判据。
- `TreeGuideLineTests`（双腿）：参考线对齐父行 chevron 中心（≤ 1 pt，`.small` / `.regular`）、跨行连续、
  第 3 层恰有 2 根、RTL 是 LTR 的镜像（容 1 px 亚像素错位）。
- `TreeHoverTests`（macOS）：翻转悬停时行内容收到的事务不带动画（三档动效）。

`#429` 起的展平判据（`TreeFlattenedRenderingTests`，双腿，托管窗口）：
- 构建计数：`ScrollView` 300 pt 视口、200 个子节点展开，构建的行 < 20（实测 7）。容器换回 `VStack`、或保留
  `LazyVStack` 但恢复递归 `DisclosureGroup`，都是 201 行。
- 行身份：展开中间的父节点后，新出现（`onAppear`）的行恰为插入的子行。`ForEach` 按下标取 id 时，新出现的是尾部下标上的行。
  这条必须在托管窗口里做：`ImageRenderer` 每次全新构建，身份错位画不出差别。
- 展平前后的逐像素对照（128 格矩阵、两条腿全部偏差 0）只在 `#429` 的迁移 PR 里跑过一次，不常驻。

`#429` 起的右键菜单判据（`TreeContextMenuTests`）：
- 纯函数（双腿）：右键已选中的行 → 选中 ∩ 可见行，折叠隐藏的本树 ID 与树外 ID 都不传出；右键未选中的行 → 只有这一行。
- 渲染不求值 builder（双腿，`ImageRenderer`）：渲染后 builder 调用 0 次。它单独看会被「根本没挂菜单」骗绿，
  所以两条腿各有一条同时判「挂上了、目标对」的托管判据（下两条）。
- 托管窗口（**仅 macOS**，两种外观）：渲染后 builder 0 次；对每一行所在点取 `NSView.menu(for:)`，得到的菜单就是
  这一行的目标集合（取过后 builder 计数非 0，证明计数探针有效）；第 2 层行 `a1` / `a2` 的**缩进区**也取到该行的菜单；
  取过一次菜单后点另一行改选中，再取，目标集合跟着新选中走（不陈旧）。
  ⚠️ 缩进区一条只在 `.automatic` 下能判出「菜单挂在 `contentShape` 之前」：`.navigator` 行自己带
  `contentShape`，那样挂照样覆盖整行。
  ⚠️ 它**不判**「唤起菜单不改选中」：把「构建菜单时顺手选中该行」写进 builder 包装，这条照样绿
  （builder 改为延迟求值后复测仍绿）⇒ 该项只在上面的真 HID 清单里。
- 托管窗口（**仅 iOS**）：渲染后 builder 0 次；沿纵向逐点向 `UIContextMenuInteraction` 的 delegate 要菜单配置，
  builder 收到的集合恰是各行的目标集合。托管窗口里整棵树只有 1 个菜单交互，按位置分派到行。
  ⚠️ iOS 腿没有「改选中后不陈旧」的判据（那条要点击改选中，只在 macOS 托管窗口里做）。
- 托管窗口点选（**仅 macOS**）：`clickingARowSelectsIt` 对「无菜单 / 设了菜单」参数化，设了菜单后点选照样工作。
- **「不调用就不挂」只在 iOS 腿有判据**：视图树里没有 `UIContextMenuInteraction`，调用了才有（正向对照在同一条里）。
  ⚠️ macOS 腿上**没有**这条判据：`menu(for:)` 对「不挂」与「挂了空菜单」都返回 `nil`，两者分不开；
  AX 动作列表也读不到（同上一条，`NSHostingView` 读不到无障碍子树）。
- `TreeHoverMotionGuard`（源码）：行宿主与 `.navigator` 行内不出现 `animation(` / `coreAnimation(` / `withAnimation` /
  `transaction` / `withTransaction`（按名禁调用，不看实参——局部别名绕不过去；`CoreMotionToken.x.animation(for:)`
  这类取 token 的调用也会被拦，这是刻意的）；`.onHover` 只在行宿主的 `case .navigator` 分支内；容器无悬停状态；
  行为 / 无障碍只挂在行宿主上。

`#427` / `#428` 起的勾选判据：
- `TreeKeyboardTests.optionSpaceTogglesTheFocusedCheck`（双腿）：有勾选列时 ⌥Space 在每一行上都是 `.toggleCheck`，
  没有时交回系统，不带修饰键的 `Space` 仍是 `.toggleSelection`；其它修饰键组合交回系统。
- `TreeCheckKeyboardReducerTests`（双腿）：⌥Space 带出焦点行、不动选中与展开、交互来源置为键盘；首键先解析初始焦点。
- `TreeCheckRowToggleTests`（双腿）：叶行切换自身；父行 off / mixed → 全勾、on → 全不勾；搜索范围外的叶子不动。
- `TreeCheckAccessibilityTests`（双腿）：动作名取值，两个 key 已登记进 `Localizable.strings`。
- `TreeHostedWiringTests.optionSpaceWritesTheCheckedSet`（**仅 macOS**，两种外观）：合成 ⌥Space 经 `onKeyPress` 写回宿主 `checked`
  （变异实测：把写回短路后两种外观各红 3 条）。
- `TreeHostedWiringTests.optionSpaceUnderSearchWritesRetainedLeavesOnly`（**仅 macOS**，两种外观）：`searchFilter("y")` 下对 `a`
  按两次 ⌥Space，只勾上 / 取消保留的 `a1y`，已勾的 `a2` 与被过滤掉的 `a1x` 不动（变异实测：把写回的 `within: frame.included`
  换成 `nil`，两种外观各红 2 条）。
- 行内容上勾选动作的**范围**与父行复选框共用同一份 `TreeRowCheckScope`：把它的 `within: self.context.included` 换成 `nil`，
  既有的 `TreeSearchHostedTests.checkCascadeUnderSearch` 红 12 条——范围的计算有判据。
- ⚠️ 无判据：复选框的无障碍 label 取自行内容；行内容上确实挂着勾选动作、执行动作确实写回 `checked`（动作闭包本身）
  ——托管窗口读不到无障碍子树、也执行不了自定义动作，只有上面的实读（iOS `axe` 读到动作名，macOS 用 AX API 执行过一次）。

`#431` 起的单击行为判据：
- `TreeRowClickBehaviorTests`（双腿，纯函数 `TreeInteractionReducer.pointerClick` / `pointerToggle`）：`.select` 与既有点选归约逐字段相同、不动展开；
  `.selectAndToggleExpansion` 在父行上选中并取反展开（`.single` / `.multiple`）；再点已选中的父行：`.single` 保持选中、
  `.multiple` 移出选中，两者都照样取反展开（已展开 → 折叠、已折叠 → 展开）；`.single` 保持选中 = 替换本树内的已选 ID、保留树外 ID；
  叶行与 `.select` 下再点已选中的行仍取消选中；点到不在可见行里的 ID 状态原样返回；三档动效档原样带出；搜索期间只写 overlay；
  多选不求整树 ID；点 chevron 按归约当时的展开态取反、不可见的 ID 原样返回。
- `TreeAccessibilityTests.clickTogglingParentRowsCarryAHint`（双腿）：只有 `.selectAndToggleExpansion` 下的父行取到提示 key，key 已登记进 `Localizable.strings`。
- `TreeHostedWiringTests`（**仅 macOS**，两种外观）：不调用 / `.select` 下单击父行只选中；`.selectAndToggleExpansion` 下
  单击父行选中并展开、再点保持选中并折叠、第三击保持选中并展开；单击父行的展开事务曲线等于环境动效档的 token 取值（三档）；
  点 chevron 恰好切换一次、不选中，点复选框只勾选，点叶行只选中、再点取消选中；行内容里的 `Button` 接到点击时行不选中、不展开。
- `TreeSearchHostedTests`（**仅 macOS**，两种外观）：搜索期间单击父行只在 overlay 里折叠、不写宿主 `expanded`；
  紧接着点正在淡出的子行不选中它、不回滚这次折叠；紧接着点正在淡出的子行的 chevron 也不把旧 overlay 写回；清空后宿主 `expanded` 不变。
- ⚠️ iOS 腿只有纯函数判据（托管窗口的合成点击只在 macOS 做）。真 HID 未测：真指针 / 触控下单击父行、修饰键点击、
  VoiceOver 激活行内容。

`#423` 起的搜索判据（`TreeSearchTests.swift`）：
- `TreeSearchMatcherTests` / `TreeSearchResultTests`（双腿，纯函数）：匹配规则（含组合 / 分解形式的 Unicode 等价、
  片段取原文）；公开入口 `searchMatches` 的两个重载与过滤的命中集合相同、高亮片段非空当且仅当命中；
  留下的集合 = 命中 ∪ 祖先 ∪ 后代，自动展开 = 命中的严格祖先；命中的文件夹保留不命中的后代且不自动展开。
- `TreeSearchTruthTableTests`（双腿，纯函数）：真值表第 4–7 行在搜索触发下逐行一条（← / → / 点 chevron 只写 overlay；
  清空与换词后 overlay 不带出；`Cmd+A` 只作用于可见行、父行复选框的动作范围是保留的叶子；焦点回退到最近可见祖先，
  按键路径也先归约）、保留节点 ≠ 可见行（折叠着的命中文件夹：全选只选可见行，复选框作用于它保留的全部叶后代）、
  右键目标不含被过滤掉的 ID、不搜索时与既有行为相同、搜索期间展开照样带环境动效档。
- `TreeSearchCheckScopeTests`（双腿，纯函数）：显示来源按全部叶子；A/B 例子四格（被过滤的叶子初始未勾 / 已勾、
  保留的已全勾、全部已勾）连点两次的结果；行宿主用的两路绑定只经第二路写、只写一次；换词只改变范围不改读数；
  提示 key 只在「父行 + 搜索中」给出，且已登记进 `Localizable.strings`。
- `TreeSearchEmptyResultTests`（双腿，纯函数）：无结果时焦点置空、选中与展开不变；九种按键在无可见行时全部交回系统、
  不激活、不改状态；空数据源与纯空白搜索词；结果重现后按初始焦点规则解析。
- `TreeSearchRenderTests`（双腿，`ImageRenderer`）：两种外观下，`searchFilter("y")` 的画面与手工裁剪成
  a › a1 › a1y 并展开的树逐像素等价（容差 2）；空搜索词与不设等价；搜索期间父行三态按全部叶子画（被过滤的叶子未勾时
  与全勾时画得不同）；`Text(verbatim:highlighting:)` 命中时与普通 `Text` 不同（最小差异 > 8）、未命中 / 空词时等价、
  命中片段有底色（与只加粗的同一段文字不同）、高亮跟着命中片段走；**选中行上**「加粗 + 底色」与「只加粗」画得不同
  （`.automatic`、`.navigator`、`.navigator` + 宿主 `coreAccent(systemYellow)`，× 明暗）。高亮底色是系统色，不走 asset catalog。
- `TreeSearchHostedTests`（**仅 macOS**，托管窗口，两种外观）：搜索期间 `←` 不写宿主 `expanded`、清空后恢复展开、
  清空后再搜同一个词重新自动展开、`Cmd+A` 只选可见行、A/B 例子四格经真 `Toggle` 连点两次父行复选框、
  换词与清空不写 `checked` / `selection` / `expanded`、焦点行被过滤后下一键从最近可见祖先出发。
  ⚠️ iOS 腿没有这组接线判据（托管窗口的合成键盘事件只在 macOS 做得出来）。
- ⚠️ **无判据**：父行复选框的无障碍提示是否真的挂在无障碍元素上（判据只到提示 key 的取值；托管窗口读不到无障碍子树）。
  命中底色叠彩色文字的对比度也没有判据：只有 iOS 模拟器截图的读数（见设计定案「命中高亮」一行），判据只到亮 / 暗两档的不透明度取值。
- ⚠️ **未验证**：真 HID 下在搜索框与树之间切换键盘焦点（`Tab`）；输入法组字（中文拼音：组字、选候选、取消、删除，两个平台）
  期间 SwiftUI `TextField` 是否把中间串写进绑定、上面的桥接示例是否挡得住；VoiceOver 实际读出的提示与画廊示例的结果数播报。

## 判定法

规定性组件（`prescriptive` / `step3`），**不给扩展点**，不进 `ComponentExtensionPointGuard` 的定义域。
逐步走查（步骤 1 无、步骤 2 已穷尽走出口 2、步骤 3 的 (A)(B)）写在
`docs/component-registry.json` 的 `Tree` 条目 `notes` 里。

`#429` 加了 `TreeStyle` 但**不改判**（J-2 计数仍 16），`notes` 末段逐条写了三点：
1. 本轮按「**不是扩展点**」的读法处置（`TreeStyle` 是封闭配置，调用方只能在两个预设里选）；
   它是否与形态 D2（公开配置枚举）同形、因而应按扩展点处置，**待 `D-429-1` 裁定**（`docs/contract-defects.md`）。
2. 两外观的差异里，**落在 `#422` 步骤 2 装饰档原文**（连线 / 选中块 / 尺寸 / 缩进引导线）的只有：
   整行选中 vs 圆角选中块（选中块）、缩进参考线（缩进引导线）、密度（尺寸）。
   **不在那份原文里**、按补充规则 1 单独论证的有三项，**都落在灰区、并入 `D-429-1` 待裁**：
   悬停高亮（随「指针在本行」变化，公约没有区分组件状态与宿主输入状态）；chevron 着色（`.navigator` 固定中性色、
   `.automatic` 取 `.tint`——是同一部件的上色，不改变部件承载的展开态）；焦点指示形态（`.automatic` 圆角焦点环、
   `.navigator` 直角内描边——两者承载同一个焦点状态，只是画法不同）。
3. 将来要让第三方扩展：升协议 + `where Self ==` 静态成员，modifier 取 `any TreeStyle`；届时走修订回路，J-2 计数 16 → 17。

`#429` 的 `rowContextMenu(_:)` 同样**不改判**：菜单内容是调用方按目标 ID 集合给出的数据操作，与行内容 `content`
同属调用方内容槽，不改变行的画法与含义，不是外观扩展点。

`#431` 的 `rowClickBehavior(_:)` 同样**不改判**：它选的是行为（单击父行是否同时取反展开态），不改变行的画法与含义，
不是外观扩展点；取值是封闭枚举，第三方不能新增。

`#423` 的 `searchFilter(_:text:)`、`searchMatches(...)` 与 `Text(verbatim:highlighting:)` 同样**不改判**：前两者是调用方给的数据投影
（按哪段文案过滤 / 求命中），匹配谓词固定、不可替换；后者是 SwiftUI `Text` 上的构造器，不是 `Tree` 的外观槽。
两者都不改变行的骨架与含义。

## 使用示例 / Usage

```swift
struct Node: Identifiable {
    let id: String
    let name: String
    var children: [Node]?
}

struct FileBrowser: View {
    let roots: [Node]
    @State private var expanded: Set<String> = []
    @State private var selection: Set<String> = []
    @State private var checked: Set<String> = []

    var body: some View {
        Tree(
            self.roots,
            children: \.children,
            expanded: self.$expanded,
            selection: self.$selection,
            selectionMode: .multiple,
            checked: self.$checked,
            onActivate: { id in print("open \(id)") }
        ) { node in
            Label(node.name, systemImage: node.children == nil ? "doc" : "folder")
        }
    }
}

// VS Code Explorer 式：整行选中 / 悬停 / 缩进参考线，行距 22（iOS 上仍 44）+ 搜索过滤 + 单击替换选中、单击文件夹即展开
struct Explorer: View {
    let roots: [Node]
    @State private var expanded: Set<String> = []
    @State private var selection: Set<String> = []
    @State private var query = ""

    var body: some View {
        TextField("Filter files", text: self.$query)
        ScrollView {
            Tree(
                self.roots,
                children: \.children,
                expanded: self.$expanded,
                selection: self.$selection,
                selectionMode: .single
            ) { node in
                Label {
                    Text(verbatim: node.name, highlighting: self.query)
                } icon: {
                    Image(systemName: node.children == nil ? "doc" : "folder")
                }
            }
            .searchFilter(self.query, text: \.name)
            .rowClickBehavior(.selectAndToggleExpansion)
            .rowContextMenu { targets in
                Button("Rename") { print("rename \(targets)") }
                    .disabled(targets.count != 1)
                Button("Delete", role: .destructive) { print("delete \(targets)") }
            }
        }
        .treeStyle(.navigator)
        .controlSize(.small)
    }
}
```
