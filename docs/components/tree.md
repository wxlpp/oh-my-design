# Tree

递归层级树 / Recursive tree：受控展开 + 行选中（单选 / 多选）+ 可选的三态复选框 +
W3C ARIA Treeview 键盘导航。

本仓**第一个递归组件**。走递归 `DisclosureGroup(isExpanded:)`：从系统拿到的是**展开态接口与嵌套能力**，
**不是原生外观**——chevron、缩进、行选中底色与展开态的无障碍播报全部自绘。

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
```

| 参数 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| data | RandomAccessCollection | - | 根节点集合 |
| id | KeyPath<Element, ID> | `\.id`（Identifiable 便利 init） | 稳定标识，**整棵树内**唯一 |
| children | KeyPath<Element, Data?> | - | 子节点；`nil` 与空集合都算叶节点 |
| expanded | Binding<Set<ID>> | - | 已展开节点，调用方持有，可读可写可持久化 |
| selection | Binding<Set<ID>> | - | 已选中行（导航语义） |
| selectionMode | TreeSelectionMode | `.single` | `single` / `multiple`；**枚举而非 Bool** |
| checked | Binding<Set<ID>>? | `nil` | 已勾选**叶**节点（数据语义）；`nil` 时不画复选框 |
| onActivate | ((ID) -> Void)? | `nil` | `Enter` 激活焦点行时回调，与选中分开；为 `nil` 时 `Enter` 交回系统 |
| content | (Element) -> RowContent | - | 行内容，常为 `Text` / `Label` |

## 展开 / 默认展开到第 N 层

- 展开态就是 `expanded` 这个 `Set<ID>`；组件不另存一份。点 chevron、按 `←` / `→` 都直接写它。
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
| 改变方式 | 点行、`Space`、`Shift+↑/↓`、`Ctrl/Cmd+A` | 点复选框 |

- `single`：选中一个未选行时替换已选集合里**属于本树**的全部 ID——包括被折叠而当前不可见的；
  再选同一行取消（允许空选）。集合里不属于本树数据的 ID 原样保留。
- `multiple`：逐行切换。
- **父行复选框是派生的**：父行用系统 `Toggle(sources:isOn:)`，源集合是它**全部叶后代**的勾选绑定，
  三态（off / mixed / on）由系统派生、由 `CheckBoxToggleStyle` 呈现（见 [checkbox.md](checkbox.md)）。
  点 mixed 父节点 = 级联全选全部叶后代；再点一次 = 全不选。父节点 ID **永不进** `checked`。

## 行为真值表（PRD FR-2）

| 行为 | 定案 | 本组件的落点 |
|---|---|---|
| 行选中与复选框 | 两套独立状态 | 已实现 |
| 点击 mixed 父节点 | 全选（级联全部后代）；再点全不选 | 已实现 |
| 父节点自身 | 只由后代推导，不单独进选择集合 | 已实现（勾选侧） |
| 搜索期间的展开 | 不写进持久化 `Set<ID>`，只临时展开 | **只有状态结构** |
| 清空搜索 | 恢复搜索前的展开态 | **只有状态结构** |
| 过滤后「全选」 | 范围是可见节点 | 已实现（`Ctrl/Cmd+A` 只选可见行） |
| 焦点节点被过滤隐藏 | 移到最近的仍可见祖先；无祖先则移到首个可见节点 | 已实现（折叠祖先 / 宿主改 `expanded` 或 `data` 使焦点行不可见时即归约）；过滤触发属 `#423` |

⚠️ 「搜索期间的展开」「清空搜索」两行只落了内部状态结构（展开态的临时 overlay），有纯函数判据；
**搜索 UI 属 `#423`**。今天生产路径上 overlay 恒为 `nil`，只有判据在走它。
焦点归约则已在生产路径上：可见行集合一变就归约，按键时也先归约再执行。

## 键盘

契约取 **W3C ARIA Treeview Pattern** 的推荐（单选式）多选模型：方向键只移动焦点、不改变选择。

| 键 | 行为 |
|---|---|
| `↓` / `↑` | 焦点移到下 / 上一个**可见**行；首末行上 does nothing |
| `→` | 折叠的父节点：展开，焦点不动；已展开的父节点：焦点移到首个子节点；叶节点：does nothing |
| `←` | 已展开的父节点：折叠；子级的叶 / 折叠节点：焦点移到父节点；**根级**的叶 / 折叠节点：does nothing |
| `Home` / `End` | 焦点到首行 / 最后一个**可见**行 |
| `Space` | 切换焦点行的选中态 |
| `Enter` | 激活焦点行（调 `onActivate`），不改选中 |
| `Shift+↓` / `Shift+↑` | 仅 `multiple`：移焦并切换目标行的选中态；`single` 下退化为纯移焦 |
| `Ctrl+A` / `Cmd+A` | 仅 `multiple`：全选可见行 |
| 其它字符键、`Tab` | 交回系统（不吞） |

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
- chevron：`chevron.forward`，取 `.tint`，展开时转 90°（RTL 下 -90°）；叶行保留同宽的占位，行内容左缘对齐。
- 行：最小高度为该档行高（上表，iOS 过 44 下限），圆角 `CoreRadius.small`。
- 选中底色 `accentSubtleBackground(from: coreAccent)`，从**环境 `coreAccent`** 派生
  （与 `TagGroup` 选中态同一条通路），`.coreAccent(_:)` 换色即跟随。

## 动效

| 调用点 | token | Reduce Motion 下 |
|---|---|---|
| chevron 旋转 | `CoreMotionToken.reveal.transformAnimation(for:)` | `nil`，直接到终态角度 |
| 展开折叠（点 chevron 与键盘 `←` / `→` 同一个函数） | `withAnimation(CoreMotionToken.treeExpansion(for:))`，即 `reveal.animation(for:)` | 同时长 `easeInOut`（`reveal` 档「展开」的既有口径，与 `CoreDisclosureGroupStyle` 相同）；`hidden` 下不补间 |
| 选中态切换 | `.coreAnimation(.selection, value: self.selection)` | 按 `CoreMotionToken.selection` 的裁决 |

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
- **chevron 命中槽 = 展开槽宽 × 行高**（`.regular` 为 24×44 pt；iOS 各档高都 ≥ 44）。
  原先按钮只有图标大小（实测 12×7 pt），在 iOS 上偏离 10 pt 的点击会落到紧邻的父行复选框上，
  **一次点击勾上整棵子树**；判据 `TouchTargetTests.treeDisclosureMeetsMinimumTouchTarget`（iOS 腿，五档参数化）。
- 行高 ≥ 44 pt（五档）：判据 `TouchTargetTests.treeRowMeetsMinimumTouchTarget` 与
  `TouchTargetTests.treeCheckBoxRowMeetsMinimumTouchTarget`（iOS 腿，五档参数化）。
- ⚠️ 横向：展开槽宽 20–32 pt < 44 pt，现判据只核高度，登记为已知项。
- 行在无障碍树里**不是一个元素**：iOS `axe describe-ui` 实读，父行拆成 chevron（`Button`）、复选框、
  行内容三个元素，行上的 `accessibilityValue`（"Expanded" / "Collapsed"）被复制到这三个元素上。
  没有改成 `.accessibilityElement(children: .combine)`：合并后 chevron 与复选框不再是独立可激活的目标，
  而这套装置读不到 VoiceOver 的激活语义，无法确认合并后展开 / 勾选仍可达。行元素的整体设计并入 `#427` / `#428`。
- ⚠️ **已知缺口（`#427`）**：复选框没有可读的 label、不报勾选态——iOS 实读叶行 `CheckBox` / 父行 `Button`，
  AXLabel 都是 SF Symbol 名 "Square"。根因在 `CheckBoxToggleStyle`（裸 `Image` + `onTapGesture`），
  Tree 又是 `labelsHidden()` + 空 label。试过给行内容与复选框配 `accessibilityLabeledPair`：
  iOS AXLabel 仍为 "Square"、macOS `AXTitleUIElement` 仍缺失，两条腿都无效，未采用。
- ⚠️ **已知缺口（`#428`）**：勾选态无法用键盘操作——`Space` 切换的是行选中，没有键改变勾选。
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
- ⚠️ 传了 `checked` 时，父行复选框的三态要读它**全部叶后代**的勾选态，因此会遍历该父行的整棵子树，
  折叠与否都一样。这是三态派生本身的代价。

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
- 焦点环是否真的画在屏幕上（渲染判据只判 `TreeRowView` 收到 `showsFocusRing` 后画不画）；
- 点 chevron / 点复选框把交互来源置回 pointer 的调用点（归约函数本身有判据）。
- ⚠️ **未验证**：`Tab` 进入后环直接出现在已选行 / 首行——本次改动后没有跑真 HID。

## 判定法

规定性组件（`prescriptive` / `step3`），**不给扩展点**，不进 `ComponentExtensionPointGuard` 的定义域。
逐步走查（步骤 1 无、步骤 2 已穷尽走出口 2、步骤 3 的 (A)(B)）写在
`docs/component-registry.json` 的 `Tree` 条目 `notes` 里。

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
```
