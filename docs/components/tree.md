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
| onActivate | ((ID) -> Void)? | `nil` | `Enter` 激活焦点行时回调，与选中分开 |
| content | (Element) -> RowContent | - | 行内容，常为 `Text` / `Label` |

## 展开 / 默认展开到第 N 层

- 展开态就是 `expanded` 这个 `Set<ID>`；组件不另存一份。点 chevron、按 `←` / `→` 都直接写它。
- **根为第 1 层**。`Tree.expandedIDs(_:id:children:toDepth:)` 预算「默认展开到第 N 层」的集合：
  `toDepth: 1` 全折叠，`toDepth: 2` 只展开根这一层，依此类推。它是 `nonisolated` 的纯函数，
  可以在 `@State` 的初值里直接调用。

```swift
@State private var expanded = Tree<[Node], String, Text>.expandedIDs(
    roots, id: \.id, children: \.children, toDepth: 2
)
```

## 选择与勾选：两套独立状态

| | 行选中 `selection` | 勾选 `checked` |
|---|---|---|
| 语义 | 导航：当前高亮哪几行 | 数据：勾了哪些 |
| 谁能进集合 | 任意行（含父节点） | **只有叶节点** |
| 改变方式 | 点行、`Space`、`Shift+↑/↓`、`Ctrl/Cmd+A` | 点复选框 |

- `single`：选中一个未选行时替换「当前可见行里」的已选集合；再选同一行取消（允许空选）。
  集合里不在可见行中的 ID 原样保留。
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
| 焦点节点被过滤隐藏 | 移到最近的仍可见祖先；无祖先则移到首个可见节点 | **只有状态结构** |

⚠️ 与搜索相关的三行，本组件只落了内部状态结构（展开态的临时 overlay、焦点归约），
有纯函数判据；**搜索 UI 属 `#423`**。今天生产路径上 overlay 恒为 `nil`，只有判据在走它。

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
- **进入方式**：macOS 上 `Tab` 进入容器；iOS 上 `Tab` 不移焦点，**点一行**会同时把键盘焦点交给容器。
- **修饰键按白名单判**：只认 shift / control / option / command。macOS 真 HID 下方向键自带
  `.numericPad | .function`（`rawValue 96`），`Home` / `End` 带 `.function`（`64`）——写成黑名单漏一位，
  方向键就会整条静默失效。
- 键盘层挂在容器上。⚠️ 两条腿实测：宿主**祖先**视图上的 `onKeyPress` 比 Tree 的**先**执行——
  宿主若在祖先上对方向键返回 `.handled`，Tree 就收不到。
- **不做**：type-ahead（组件不持有节点文案，行内容是调用方的 `@ViewBuilder`）、`F2` 重命名。

真 HID 读数（macOS System Events / iOS 26.4 模拟器 `axe`，逐步对预期表）与装置在
`.claude/epics/structure-components/422-probe/README.md`。

## 外观

- 缩进：每深一层 `CoreSpacing.md`。
- chevron：`chevron.forward`，取 `.tint`，展开时转 90°（RTL 下 -90°）；叶行保留同宽的占位，行内容左缘对齐。
- 行：最小高度 `CoreControlMetrics.height(for: .regular)`，圆角 `CoreRadius.small`。
- 选中底色 `accentSubtleBackground(from: coreAccent)`，从**环境 `coreAccent`** 派生
  （与 `TagGroup` 选中态同一条通路），`.coreAccent(_:)` 换色即跟随。

## 动效

| 调用点 | token | Reduce Motion 下 |
|---|---|---|
| chevron 旋转 | `CoreMotionToken.reveal.transformAnimation(for:)` | `nil`，直接到终态角度 |
| 键盘 `←` / `→` 展开折叠 | `withAnimation(CoreMotionToken.reveal.animation(for:))` | `easeInOut`（与 `CoreDisclosureGroupStyle` 同一口径） |
| 选中态切换 | `.coreAnimation(.selection, value: selection)` | 按 `CoreMotionToken.selection` 的裁决 |

⚠️ 点 chevron 展开**不**包 `withAnimation`（只有 chevron 自身旋转），键盘展开才包——两条通路的行出现方式不同。
目前没有判据覆盖这一格。

## 无障碍与触控

- 父行 `accessibilityValue` 播报 "Expanded" / "Collapsed"（自绘 `Button` 不会被系统自动播报，这一层是唯一来源）；
  chevron 的 `accessibilityLabel` 说的是**动作**（"Expand" / "Collapse"）。四个 key 都走 `bundle: .module`。
- 已选行带 `.isSelected` trait。
- **chevron 命中槽 24×44 pt**（宽 `iconSize(.regular) + CoreSpacing.sm`、高 `height(for: .regular)`）。
  原先按钮只有图标大小（实测 12×7 pt），在 iOS 上偏离 10 pt 的点击会落到紧邻的父行复选框上，
  **一次点击勾上整棵子树**；判据 `TouchTargetTests.treeDisclosureMeetsMinimumTouchTarget`（iOS 腿）。
- 行高 ≥ 44 pt：判据 `TouchTargetTests.treeRowMeetsMinimumTouchTarget`（iOS 腿）。
- ⚠️ **已知缺口**：复选框没有可读的 label——`CheckBoxToggleStyle` 自身不设无障碍标签，
  Tree 里又是 `labelsHidden()` + 空 label，iOS 实测 VoiceOver 读到的是 SF Symbol 名 "Square"。
  根因在 CheckBox，不在本组件内处置。

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
