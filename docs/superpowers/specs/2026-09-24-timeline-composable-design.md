# Timeline 组合式 API（#420）设计 spec

- 日期：2026-09-24
- Issue：`wxlpp/oh-my-design#420`（PRD `.claude/prds/timeline-tree-action-buttons.md` FR-1，破坏性变更）
- 基线：`origin/epic/structure-components` = `f0f03c2`
- 本文只是设计，**不含实现代码**。「实测」均指 §0 列出的 scratch 探针（不进仓库），其余标「源码读」或「推断」。
- 实现拆成 4 个可独立合并的 PR（§10）；逐 PR 的 plan 另写。

## 0. 证据来源与标注口径

| 标签 | 含义 |
|---|---|
| **源码读** | 在 `f0f03c2` 上直接读到的源码 / 文档原文 |
| **实测** | 本次 scratch 探针，macOS 26.3.1 / Swift 6.3 / `swiftc -swift-version 6` 直接编译运行（**未开** `defaultIsolation(MainActor)`）；**只跑了 macOS**，iOS 腿未测 |
| **推断** | 未经实测；进实现期前要么补探针，要么在判据里兜住 |

探针（`scratchpad/420/p1.swift` `p1b.swift` `p1c.swift` `p1d.swift` `p2.swift` `p3.swift` `p4.swift` `p5.swift`）读数：

| # | 问题 | 读数 |
|---|---|---|
| P1 | `Group(subviews:)` 对「body 是多个视图的自定义 View」怎么解析 | **展平**：5 个 `Item`（body 各 2 个视图，含 `ForEach` 与 `if` 生成的）解析出 10 个 subview，顺序与声明一致 |
| P1 | 自定义 `Layout` 能否在一次布局里取到「所有节点里最宽的那个」 | 能：`ImageRenderer` 单次渲染里 `placeSubviews` 算出 `col=40.0`（一个 40pt 宽节点 + 其余 24pt） |
| P1b / P1d | 对 `Subview` 代理施 `.environment(\.自定义键, 值)`，其 body 里 `@Environment` 读到什么 | **读不到**：`ImageRenderer` 与 `NSHostingView` 两种宿主下 body 都读到默认值（`rowIndex=-1`）；对照组直接对视图施同一环境值，读到了（宽度 1 vs 50） |
| P1c | 把节点视图以 `AnyView` 存进 `ContainerValues`、由容器取出后再施 `.environment` | 行得通：4 个节点各自读到容器注入的 `row0`…`row3`；顺序 `a, d1, d2, z`（含 `ForEach`） |
| P1c | 对 `Subview` 施 `.font(.system(size: 60))` 是否生效 | 生效（渲染高 16 → 71）——⇒ P1b 的「读不到」只针对自定义 View 的 body 读 `@Environment`，不是「一切环境修饰都失效」 |
| P5 | 在 `Group(subviews:)` **之前**对整个 content 施环境值 | 每行都读到（`uniform=pre-resolution`）——统一的值能下发，逐行不同的值不能 |
| P2 | 自定义 `Layout` 在 RTL 下是否自动镜像 | 是：同一次 `place(at: minX)`，LTR 落在第 0…9 列，RTL 落在第 90…99 列（宽 100） |
| P3 | `TimelineItem` 四个 init 的重载集是否有歧义；泛型 `@ViewBuilder` 闭包默认值 `= { EmptyView() }`（SE-0347）能否编译 | 四个 init 无歧义，8 种调用形态各落预期 init；**加第五个**「标题 + 节点、无富内容」init 后 `TimelineItem("Deployed") { Text("rich") }` 报 `ambiguous use of 'init'`；默认闭包可编译 |
| P4 | `onScrollVisibilityChange(threshold:)`：无 `ScrollView` 宿主 / 在 `ScrollView` 内 / 嵌套滚动 | 无宿主：挂载即回调 `true` 一次；在 `ScrollView` 内：首帧只对可见行回调 `true`、其余 `false`，之后**滚入滚出双向回调**；嵌套（纵向页面里的横向 `ScrollView`）：内层项在**外层**把它滚进视口前一直是 `false`，外层滚入后变 `true` |
| P4 | `.scrollTransition` 的当前相位能否用闭包内日志观测 | **不能**：闭包对三个相位都会被求值，日志里三相都出现，不代表当前相位——本 spec 对它的判断改取官方文档（§6.3），不引这组日志作证据 |
| P5 | 对 `Subview` 施 `.accessibilityValue` 是否进入无障碍树 | **未测成**：探针里 macOS 无障碍树没有 AX 客户端就不建，`accessibilityChildren()` 为空 ⇒ 这一条是**推断**（§7、R1） |

## 1. 组合式公开 API（FR-1 主体）

### 1.1 定案一览

| 公开类型 / 成员 | 形态 | 替代什么 |
|---|---|---|
| `Timeline<Content: View>` | 容器：`@ViewBuilder content` + `layout:` + 可选 `progress:` | `Timeline(items:layout:)` |
| `TimelineItem<Node: View, Content: View>` | 行，**是一个 `View`**；`node:` 外观槽 + `content:` 内容槽 + 行内结构件参数（标题 / 时间 / 描述） | 两个 `TimelineItem` init（旧 `TimelineItem` 是数据载体 struct） |
| `TimelineLayout` | **不变**（四个 case），加 `nonisolated` | —— |
| `TimelineProgress`（新） | `public nonisolated enum`：`.notStarted` / `.inProgress(at:)` / `.completed` | —— |
| `TimelinePhase`（新） | `public nonisolated enum`：`.completed` / `.inProgress` / `.upcoming` | —— |
| `EnvironmentValues.timelinePhase`（新） | `public` 只读（`internal(set)`），只在 `node:` 槽内有值 | —— |

### 1.2 签名草案

```swift
public struct Timeline<Content: View>: View {
    /// 纯活动流：不带阶段，连线一律 `dividerDefault`（与旧实现同）。
    public init(layout: TimelineLayout = .vertical, @ViewBuilder content: () -> Content)
    /// 带阶段：各行阶段由 `progress` 与行序推导（§4）。
    public init(layout: TimelineLayout = .vertical, progress: TimelineProgress, @ViewBuilder content: () -> Content)
    public var body: some View
}

public nonisolated enum TimelineLayout: Sendable, Equatable {
    case vertical, alternate, horizontal, grouped
}

public nonisolated enum TimelineProgress: Sendable, Equatable {
    case notStarted
    /// `index` 为 0 起的行序（只数 `TimelineItem`，§1.5）。
    case inProgress(at: Int)
    case completed

    /// 第 `index` 行的阶段（纯函数，§4 真值表）。
    public func phase(at index: Int) -> TimelinePhase
}

public nonisolated enum TimelinePhase: Sendable, Equatable, CaseIterable {
    case completed, inProgress, upcoming
}

public struct TimelineItem<Node: View, Content: View>: View {
    // ① 富内容 + 默认圆点
    public init(status: StatusLevel = .info, @ViewBuilder content: () -> Content) where Node == EmptyView
    // ② 富内容 + 自定义节点
    public init(status: StatusLevel = .info, @ViewBuilder node: () -> Node, @ViewBuilder content: () -> Content)
    // ③ 结构件（标题 / 时间 / 描述）+ 可选富内容 + 默认圆点
    public init(
        _ title: LocalizedStringKey,
        time: Text? = nil,
        description: LocalizedStringKey? = nil,
        status: StatusLevel = .info,
        @ViewBuilder content: () -> Content = { EmptyView() }
    ) where Node == EmptyView
    // ④ 结构件 + 自定义节点 + 富内容（无富内容时写 `content: {}`，见 §0 P3）
    public init(
        _ title: LocalizedStringKey,
        time: Text? = nil,
        description: LocalizedStringKey? = nil,
        status: StatusLevel = .info,
        @ViewBuilder node: () -> Node,
        @ViewBuilder content: () -> Content
    )
    public var body: some View
}

public extension EnvironmentValues {
    /// 本行阶段。只在 `TimelineItem` 的 `node:` 槽里有值；纯活动流、`content:` 内、`Timeline` 之外均为 `nil`。
    var timelinePhase: TimelinePhase? { get }
}
```

要点：

- **保留名字 `TimelineItem` 与 `node:` 标签**（用户拍板点 U2）。理由：① 公约 `docs/component-contract.md` 把
  `TimelineItem` 的 `node:` 当 D1 外观槽的**范例**（逐字 `@ViewBuilder node: () -> Node,`），
  `TimelineItem` 的 `content:` 当内容槽范例——新 API 里两句话仍然为真，引文仍逐字存在于源码，
  `QuotedEvidenceGuard` 那 4 条（`node:` ×2、`nodeContent` ×2）不必动；② 迁移是机械的：
  `Timeline(items: [ A, B ], layout: x)` → `Timeline(layout: x) { A; B }`，行本身的写法不变。
  旧代码里把 `TimelineItem` 放进 `[TimelineItem]` 的写法会**编译失败**（新类型是泛型 `View`，
  `[TimelineItem]` 缺泛型参数），不会静默换义。
- **去掉 `id:` 参数**：行身份改由 SwiftUI 结构身份 / 调用方 `ForEach` 的 id 决定（`Group(subviews:)`
  给的 `subview.id`）。旧文档那段「传稳定 `id` 避免误触发动画」随之改写为「用带 id 的 `ForEach`」。
- **`time: Text?`** 而非 `LocalizedStringKey`：时间是格式化数据，调用方写 `Text(date, style: .relative)` /
  `Text(date, format: …)`；`Text` 在 `ComponentTextParamGuard` 里属携带文本类型，不需登记 `textParams`。
  `title` / `description` 走 `LocalizedStringKey`（按类型放行）。结构件的排版：
  `VStack(alignment: .leading, spacing: CoreSpacing.xxs)`，顺序**标题 → 时间 → 描述 → 富内容**
  （沿用本仓现有画廊「标题在上、时间在下」的写法；U7），标题 `.coreFont(.callout)` + `contentPrimary`
  + `.accessibilityAddTraits(.isHeader)`，时间与描述 `.coreFont(.footnote)` + `contentSecondary`。
- 新 API **无 Bool 入参**；所有公开类型、init、`body` 显式 `public`；两个新枚举与 `TimelineLayout`
  标 `nonisolated`（后者是放宽隔离，源码兼容），供 §3.7 的 `nonisolated static func` 纯函数与测试直接调用。
  不新增公开 `static` 存储成员 ⇒ MainActor 棘轮预期无新增豁免（`TimelineProgress` 的 case 在
  `nonisolated` 类型上）。
- `timelinePhase` 用手写 `EnvironmentKey` + `public internal(set)`，**不用** `@Entry public var`
  （后者连 setter 一起公开）。`@Environment(\.timelinePhase)` 只需 `KeyPath`，只读即可用。

### 1.3 为什么这样分解：一条实测约束决定了渲染管线

reui 的做法是 Context 下发 `activeStep`、每项读它自判 `data-completed`（`reference-implementations.md` 第 1 节）。
SwiftUI 的对应物是「容器用 `Group(subviews:)` 遍历子视图、逐行注入环境值」——**P1b / P1d 实测这条路不通**：
对 `Subview` 代理施的自定义环境值进不了它的 body。能下发的只有**对所有行统一**的值（P5）。

而阶段是**逐行不同**的（取决于行序）。⇒ 定案：

1. `TimelineItem` 的 body **只产出一个视图**——它的内容部分（结构件 + 富内容，包在一个 `VStack` 里），
   并用 `ContainerValues` 把本行的规格交给容器：`status`、`node`（`AnyView?`，`nil` = 默认圆点）。
2. `Timeline` 用 `Group(subviews: content)` 读出行序列，**节点视图与连线由容器自己构造**
   （容器构造的是普通视图值，不是 `Subview` 代理，施 `.environment(\.timelinePhase, …)` 能进去，P1c 实测）。
3. 容器把「节点 ×n、内容 ×n、连线 ×(n−1)」作为**同一个自定义 `Layout`** 的子视图摆放，
   用 `LayoutValueKey` 标部件角色与行号——列宽、行高、连线端点在**一次**布局里算完（§3）。

副作用（写进文档）：`TimelineItem` 离开 `Timeline` 单独使用时**只渲染内容**，没有节点与连线；
`content:` 里读 `@Environment(\.timelinePhase)` 恒为 `nil`——要按阶段给内容换样式，调用方用
`progress.phase(at: index)` 自己算（`ForEach` 的下标它手里有）。

### 1.4 渲染管线（内部）

```
Timeline.body
└─ Group(subviews: content.environment(\.timelineLayoutContext, layout))   // 统一值，可下发（P5）
   └─ subviews → rows: [(subview, spec: TimelineItemSpec?)]              // spec 取自 containerValues
      ├─ layout == .grouped → VStack(spacing: md) { 每个 subview + 无障碍包装 }（§7）
      └─ 其余 → TimelineStackLayout(layout, metrics) {
             ForEach(rows) { row in
               TimelineNodeView(spec, phase)   .layoutValue(TimelinePartKey, .node(i))
               row.subview                     .layoutValue(TimelinePartKey, .content(i))
               TimelineConnector(segment: i)   .layoutValue(TimelinePartKey, .connector(i))  // 非末行
             }
           }
           // .horizontal 外面仍包 ScrollView(.horizontal, showsIndicators: false)
```

`TimelineNodeView` 保留现名，默认画法仍在它的 `private var nodeContent: some View` 里（被引文登记）；
新增的逐阶段画法（§4.2）也在这里。文件布局：公开类型与 `TimelineNodeView` 留在
`Sources/OhMyDesign/Components/Timeline/Timeline.swift`（被引文件路径不变），几何与纯函数拆到同目录新文件
`TimelineStackLayout.swift`。

### 1.5 非 `TimelineItem` 的直接子视图（U6）

调用方可能在 `Timeline { … }` 里直接放一个 `Text`（比如活动流里的日期分组标题）。建议处置：

- 它**不占行序**（`progress` 的下标只数 `TimelineItem`），没有节点；
- 按内容部件摆放（`.vertical` 在内容列、`.alternate` 跨满整行居中、`.horizontal` 自成一列、`.grouped` 照常）；
- 连线**贯穿**：前一个节点到后一个节点之间的连线跨过它。

识别方式：`containerValues` 里没有 `TimelineItemSpec` 即非行。备选是「一律当成无节点的行并计入行序」，
它会让 `progress` 下标与调用方直觉错位，故不取。

### 1.6 三种参考形态的调用样貌（PRD 成功标准）

```swift
// 活动流：头像大于旧 24pt 槽（非正方形同理），不传 progress
Timeline {
    ForEach(events) { e in
        TimelineItem("\(e.actor) \(e.verb)", time: Text(e.date, style: .relative)) {
            Avatar(e.actor, size: .large)          // 40pt
        } content: {}
    }
}

// 部署日志：逐项 success / danger，自定义图标节点
Timeline {
    ForEach(deploys) { d in
        TimelineItem(d.title, time: Text(d.date, format: .dateTime), status: d.ok ? .success : .danger) {
            Image(systemName: d.ok ? "checkmark.circle.fill" : "xmark.octagon.fill")
        } content: {
            Text(d.commit).coreFont(.caption).monospaced()
        }
    }
}

// 路线图：带阶段，横向
Timeline(layout: .horizontal, progress: .inProgress(at: 2)) {
    TimelineItem("Q1 Alpha")
    TimelineItem("Q2 Beta")
    TimelineItem("Q3 GA", description: "Public launch")
    TimelineItem("Q4 v2")
}
```

（`Avatar` 的实际签名以现有组件为准，此处示意。）三种形态各进 `App/Sources/Previews.swift` 一个 `#Preview`
与 `ComponentData.swift` 画廊一条（§8）。

### 1.7 与 `Steps` 的边界

- `Timeline` 展示已发生 / 计划中的事件（活动流可以完全没有阶段）；`Steps` 是向导，恒有「当前步」。
  `Timeline` 不加任何 Steps 的向导行为（无 `currentIndex` 绑定、无点击跳步、无 `.segmentedBar` / `.text` 呈现）。
- **不共用类型**：`TimelineProgress` / `TimelinePhase` 是 Timeline 自己的公开类型；`Steps` 的阶段
  是其内部 `enum StepsProgress`（`Sources/OhMyDesign/Components/Steps/Steps.swift` 逐字 `enum StepsProgress: Equatable {`），
  两者不互相引用、不抽公共基类型。`Steps` 本 issue 不改一个字。
- **可共用的**：动效 token（`CoreMotionToken.reveal`）与已到达连线的着色通路（`.tint`，Steps 逐字
  `Rectangle().fill(.tint)`）；两边的连线归属规则**同义**（§4.1 末尾）。

## 2. a：四种布局保留，`TimelineAlternateRowLayout` 的几何判据延续

- 四个 case 不变，`TimelineLayout` 继续是 `Timeline.init` 的参数 ⇒ `ComponentJudgeRules` 的 J-2
  「`styleEnum` 须接线于本组件公开 `init`」照样满足（宿主名仍是 `Timeline`；泛型参数不影响宿主识别，
  **推断**，PR 2 跑 J-2 判据兜住）。
- 旧 `TimelineAlternateRowLayout` 是**逐行**的三栏 `Layout`；新实现把它并进容器级 `TimelineStackLayout`
  的 `.alternate` 分支（列宽要跨行取最大，逐行 `Layout` 做不到）。
- 纯函数：
  - 保留 `nonisolated static func alternateRowMetrics(forRowWidth:)` 与 `alternateSlotWidth(forRowWidth:)`
    的**签名与语义**（等价于节点列宽取下限 24 的特例）⇒ `TimelineTests` 里现有的 `infinity` / `-infinity` /
    `nan` / 负数 / `0` / `fixed` / `fixed - 1` / `fixed + 2` 断言**逐条原样继续有效**；
  - 新增 `alternateRowMetrics(forRowWidth:nodeColumnWidth:)`，旧函数转调它；`nodeColumnWidth` 非有限或
    小于下限时按下限处理（与 `rowWidth` 同一套防御）。
- 旧常量 `static let nodeColumnWidth: CGFloat = 24` 的语义从「固定列宽」变成「节点盒下限」，**改名**为
  `minimumNodeExtent`（PR 1）。它被 registry `notes` 逐字引用（`QuotedEvidenceGuard` 一条）⇒ 同 PR 改写那条
  引文与 `notes` 那句（§5.2），不删登记项。

## 3. b：指示器尺寸两维自适应

### 3.1 机制比较与定案

| 机制 | 能否跨行取最宽节点 | 行高 / 连线端点 | 一致性 | 结论 |
|---|---|---|---|---|
| **自定义 `Layout`（容器级，节点 / 内容 / 连线都是它的子视图）** | 能，`sizeThatFits` 里遍历节点子视图取最大（P1 实测 `col=40`） | 同一遍算出：行高 = f(节点盒高, 内容高)；连线的起止就是相邻节点盒的实际边 | **单遍、确定**；`ImageRenderer` 与真实窗口同一结果；RTL 自动镜像（P2） | **采用** |
| `alignmentGuide`（自定义 `HorizontalAlignment` 让节点中心对齐） | 不能：只能让中轴对齐，拿不到「最宽」这个数 ⇒ 内容列起点随各行节点宽度参差 | 不管行高 | 单遍 | 否决：只解决一半 |
| `PreferenceKey` 汇总最宽节点 → `@State` → 环境值回灌 | 能，但要**两遍**（首帧按 24 排、下一帧再排） | 同上两遍 | 首帧跳动；`ImageRenderer` 单次渲染拿不到回灌后的状态（**推断**，状态更新发生在渲染之后） ⇒ 位图判据测到的是首帧 | 否决 |
| `onGeometryChange` | 同 `PreferenceKey`，异步回调 | 同上 | 同上，且有「写状态 → 重排 → 再回调」自激风险 | 否决 |

### 3.2 节点盒

- 节点的**提议尺寸是 `24 × 24`**（`minimumNodeExtent`），与旧实现 `.frame(width: 24, height: 24)` 给的提议相同
  ⇒ `Circle()` 这类弹性视图仍画成 24pt（若改提议 `.unspecified`，`Shape` 的理想尺寸是 10×10，会悄悄缩小——
  这是 §9.2 的一条计划变异）。
- 节点**报告**的尺寸 `(w, h)`（非有限值按 24 处理）⇒ 节点盒 `(max(24, w), max(24, h))`；节点在盒内居中。
- ⇒ 所有 ≤ 24×24 的节点（含默认圆点、SF Symbol 图标、20pt 圆）**盒子与旧实现逐点相同**，这就是 §8.3
  「像素不变」射程的几何根据。

### 3.3 `.vertical`

- 节点列宽 `C = max(24, 各节点盒宽)`；中轴 `x = C / 2`；每个节点盒**中心**落在中轴上、**顶**贴本行顶。
- 内容 x 起点 `C + CoreSpacing.md`，提议宽 `W − C − md`（`W` 非有限时取内容理想宽）；与旧 `HStack(spacing: md)` 在 `C = 24` 时相同。
- 行高 `H_i = max(盒高_i + m, 内容高_i + lg)`，末行 `H_last = max(盒高, 内容高)`；
  `m = CoreSpacing.sm`（节点下方连线的最短可见长度，U9），`lg` 即旧实现内容的 `.padding(.bottom, CoreSpacing.lg)`。
  - 旧实现行高是 `max(24, 内容高 + lg)`。两式在 `内容高 ≥ 24 + m − lg = 16` 时相等 ⇒ 单行 `.callout` / `.footnote`
    文本（行高 > 16）都满足；**更矮的内容行是有意的外观变化**（旧实现下连线长度为 0，看不见），登记 BREAKING。
- 连线段 `i`：x = 中轴，从节点盒_i 的**实际下沿**到下一个节点盒的**实际上沿**（隔着 §1.5 的非行子视图时照样贯穿）。
  旧实现的起点是常量 `.padding(.top, Timeline.nodeColumnWidth)`，对 ≤ 24 的节点恰等于盒下沿 ⇒ 这类行像素不变；
  高节点不再被连线穿过。

### 3.4 `.alternate`

- 节点列宽 `C` 同上（跨行取最大）；槽宽与中轴走 `alternateRowMetrics(forRowWidth: W, nodeColumnWidth: C)`
  ⇒ 各行节点中心恒在同一条中轴上（旧文档「节点恒在同一条中轴」的不变量不变）。
- 行高 `H_i = max(左槽高, 右槽高 [+ lg 由内容自带], 盒高_i + m)`，末行不加 `m`；内容仍按行序奇偶换边。
- 连线在中轴上，从盒_i 下沿到盒_{i+1} 上沿。

### 3.5 `.horizontal`

- 外层仍是 `ScrollView(.horizontal, showsIndicators: false)`。
- 节点**横轴**：`y_axis = max(各盒高) / 2`；每个盒中心落在横轴上（盒高不同时上下居中于横轴）。
- 内容顶一律在 `max(各盒高) + CoreSpacing.sm`（各列对齐，不随本列盒高参差）；内容以本列中心为轴居中。
- 列宽 `max(盒宽_i, 内容理想宽_i)`，列间距 `CoreSpacing.lg`（均同旧实现 `HStack(alignment: .top, spacing: lg)` +
  `VStack(alignment: .center, spacing: sm)`）⇒ 盒全是 24 时，除连线外与旧实现逐点相同。
- 连线段 `i`（d）：y = 横轴，从盒_i 的**实际右沿**到盒_{i+1} 的**实际左沿**（RTL 自动镜像，P2）。

### 3.6 `.grouped`

无节点列、无连线；`VStack(alignment: .leading, spacing: CoreSpacing.md)` 摆内容（同旧实现）。
容器**不构造**节点视图（`node:` 槽照旧静默不生效，存储不丢——现在「存储」就是 `containerValues` 里的那份规格）。

### 3.7 纯函数面（`nonisolated static`，双腿可测）

| 函数 | 输入 → 输出 | 防御 |
|---|---|---|
| `nodeBox(reported:)` | 节点报告尺寸 → 盒尺寸 | 非有限 / 负数 → 24 |
| `nodeColumnWidth(boxWidths:)` | 各盒宽 → 列宽 | 空数组 → 24；结果 ≥ 24 且有限 |
| `verticalRowHeight(box:content:isLast:)` | → 行高 | 负数按 0 |
| `alternateRowMetrics(forRowWidth:nodeColumnWidth:)` | 同 §2 | `infinity` / `nan` / 负数（两个参数都防） |
| `horizontalAxis(boxHeights:)` | → 横轴 y 与内容顶 y | 空数组 → 24 |
| `connectorSpan(from:to:)` | 两盒相邻边 → 连线长度 | 结果 ≥ 0（盒重叠时为 0，不画负长） |

`TimelineStackLayout` 的 `sizeThatFits` / `placeSubviews` 只做「量子视图 → 调纯函数 → 摆放」，
不持有存储状态（与旧 `TimelineAlternateRowLayout` 同一结构事实：不会冻结在首帧宽度）。

## 4. c：阶段维度与真值表

### 4.1 阶段取值：容器推导（二选一的结论，U1）

取「容器 `progress` + 行序推导」，不取「逐行显式 `phase:`」。理由：

1. 单调性由构造保证：前缀已完成、至多一行进行中、其余未开始——逐行显式会允许「已完成排在未开始之后」
   这类无意义组合，连线该怎么着色就没有答案。
2. 阶段推进动效要的是**一个可插值的标量**（§6.2 的位置 `P`），容器级模型天然给出；逐行模型下每段各自跳变，
   做不出「沿线依次推进」。
3. reui 的模型本来就是容器级（`step <= activeStep`），只是它没有「进行中」；本仓补上这一态。

`StatusLevel` 这一维**保留且正交**：`status` 决定**色相**，阶段决定**形态**与连线着色；
活动流（不传 `progress`）没有阶段，外观与旧实现相同。

**阶段真值表**（`n` = `TimelineItem` 个数，`i` = 0 起行序，`k` = `inProgress(at:)` 的参数）：

| `progress` | 第 `i` 行阶段 | 连线段 `i`（行 `i` → 行 `i+1`）着色 | 位置 `P` |
|---|---|---|---|
| 不传（纯活动流） | `nil` | 一律 `dividerDefault`（**= 旧实现**） | 不适用（无着色层） |
| `.notStarted` | 全部 `upcoming` | 全部 `dividerDefault` | `0` |
| `.inProgress(at: k)`，`0 ≤ k < n` | `i < k` → `completed`；`i == k` → `inProgress`；`i > k` → `upcoming` | `i < k` → `.tint`；否则 `dividerDefault` | `k` |
| `.inProgress(at: k)`，`k < 0` | 全部 `upcoming`（没有一行等于 `k`） | 全部 `dividerDefault` | `0` |
| `.inProgress(at: k)`，`k ≥ n` | 全部 `completed`（没有一行等于 `k`） | 全部 `.tint` | `n − 1` |
| `.completed` | 全部 `completed` | 全部 `.tint` | `n − 1` |
| 任意，`n == 0` | —— | 无连线，渲染为空 | —— |
| 任意，`n == 1` | 按上表 | 无连线 | `0` |

- **「进行中」判定**：恰为 `i == k` 且 `0 ≤ k < n` 的那一行；越界的 `k` 不产生进行中行（上表两行）。
  `.inProgress(at: n)` 与 `.completed` 渲染相同，但作为值不相等（`Equatable` 按 case 比）。
- **连线段归属**：段 `i` 由行 `i` 与行 `i+1` 共有，**着色看它通向的那一行**：行 `i+1` 已到达
  （`completed` 或 `inProgress`）⇒ `.tint`。等价写法「行 `i` 已完成」——`i < k ⇔ i + 1 ≤ k`，两者恒同。
  这与 `Steps` 的连线规则同义（`Steps.swift` 逐字 `self.progress(for: index) == .done`，即段后一侧行 `index` 已完成），
  也与 reui 的 `has-[+[data-completed]]` 同义（看下一项）。
- **着色层**：已到达段用 `.tint`（`TintShapeStyle`，调用方 `.tint(_:)` 可改；U11），底线 `dividerDefault`，宽
  `CoreBorderWidth.thin` 不变。每段的着色比例 `f_i = clamp(P − i, 0, 1)`，静态时 `f_i ∈ {0, 1}`。
- **回退**（`k` 变小，或 `.completed` → `.inProgress`）：按同一张表重算；动效上段从远端往回收（§6.2）。
  不做「回退警示」之类的额外表现——Timeline 是展示型，回退就是数据变了。
- **纯活动流 ↔ 带阶段** 是两个 init，切换属结构身份变化，**不做补间**。
- 行序只数 `TimelineItem`（§1.5）。

### 4.2 默认圆点的形态（色相仍由 `status` 经 `Timeline.nodeColor(for:in:)` 决定，U3）

| 阶段 | 形态 |
|---|---|
| `nil`（活动流） | 实心圆 Ø10（**旧实现原样**） |
| `completed` | 实心圆 Ø10（与活动流逐点相同） |
| `inProgress` | 实心圆 Ø10 + 同色外环（Ø18、线宽 `CoreBorderWidth.thick`、不透明度待视觉评审定，草案 0.4）；整体仍在 24 盒内 ⇒ 列宽不变 |
| `upcoming` | 空心圆 Ø10，线宽 `CoreBorderWidth.thick`，同色 |

- 浅色 `warning` 仍取 `statusAttentionForeground`（`#398` 的对比度修正对三种形态都成立，空心环同色同宽）。
- **进行中是静态强调，不做呼吸 / 脉冲**（§6.5）。
- 自定义 `node:` **不叠加任何阶段画法**：调用方在自己的节点视图里读 `@Environment(\.timelinePhase)` 自行决定。

### 4.3 `TimelineProgress.phase(at:)`

公开纯函数，就是真值表第二列；容器与调用方（按阶段给 `content` 换样式时）共用同一实现。

## 5. d：`.horizontal` 补连线与更正传播

### 5.1 几何

见 §3.5：横轴上从盒_i 右沿到盒_{i+1} 左沿；着色规则同 §4.1；纯活动流下为 `dividerDefault`。
旧文档给出的不画理由（逐字「竖向连线的实现依赖「节点在上、内容在下」的纵向几何，换轴后那套 padding 计算不成立」）
在新几何下不再成立：连线端点来自容器 `Layout` 的盒边，不依赖 padding。

### 5.2 更正传播（CLAUDE.md《「更正传播」约定》三处落点，均在 PR 1）

| 落点 | 现文（逐字节选） | 处置 |
|---|---|---|
| 源码文档注释 | `Timeline.swift` 逐字 `/// 横向：节点沿水平轴排列，内容在节点下方。` | 补「节点间有连线」；`grouped` 那条注释不变 |
| `docs/components/timeline.md` | 逐字「⚠️ `.horizontal` **不画节点间连线**」及用法注释「（无连线，可横向滚动）」 | 删去不画连线的段落与注释，按「更正只留一层」写一句「原写不画连线，`#420` 起画」 |
| `docs/component-registry.json` `Timeline.notes` | 逐字「⚠️ 这条是**有意不开** issue 的：横向连线是一个尚无需求驱动的增强，不是缺口；要做时再开，别把它读成待办。」及其前一句 | 改写为一句：原判「尚无需求驱动、不是缺口」被 PRD FR-1 d 推翻，`#420` 已画出横向连线 |

同一条 `notes` 里「结构事实是现状「左侧固定 24pt 节点列 + 右侧内容」（`Timeline.nodeColumnWidth`，逐字
`static let nodeColumnWidth: CGFloat = 24`）」一句随常量改名同步：改写为「左侧节点列（`#420` 起列宽按最宽节点推导、
下限逐字 `static let minimumNodeExtent: CGFloat = 24`）+ 右侧内容」，`QuotedEvidenceGuard` 那一条登记同 PR 换成新引文。
该句承载的判定（左右交替 / 横向判**排布**）不受影响：换轴与分居两侧的结构关系不变。

改完 grep 三处的残留：`不画节点间连线`、`无连线`（排除 `.grouped` 的合法用法）、`nodeColumnWidth`、`尚无需求驱动`。

## 6. e：动效

### 6.1 两类动效，分开定义

| | **阶段推进** | **节点入场** |
|---|---|---|
| 触发 | `progress` 值变化（数据变了） | 该行节点**第一次**进入可见区域 |
| 作用对象 | 连线着色比例 + 默认圆点形态 | 节点（默认与自定义都作用） |
| token | `CoreMotionToken.reveal` | `CoreMotionToken.reveal` |
| 与视口的关系 | **无关**：行在屏外时照常推进，不延迟、不排队 | 就是视口事件 |
| 重播 | 每次 `progress` 变化都播 | **不重播**（§6.3） |

两者可同时发生（新行进入视口时阶段刚好变了），互不影响：一个改节点的缩放，一个改颜色 / 连线比例。

### 6.2 阶段推进

- 容器把 §4.1 的位置 `P` 作为可动画标量下发给每段连线；每段自己算 `f_i = clamp(P − i, 0, 1)` 并画
  「底线 + 从起点（上沿 / leading）长到 `f_i` 的着色层」。`P` 由 `k₀` 补间到 `k₁` 时，段按序依次被填满——
  **一次补间、总时长 = `reveal` 的 0.25s**，与跨越段数无关。回退时 `P` 变小，从远端往回收。
- 默认圆点的形态切换（实心 / 外环 / 空心）走颜色与不透明度插值（`.coreAnimation(.reveal, value: phase)`），
  不做缩放、不做位移。
- 首次出现时不播：初始渲染直接是终态（`P` 不从 0 起补）。

### 6.3 节点入场（「进入视口才播」）

候选比较：

| 方案 | 行为 | 结论 |
|---|---|---|
| `.scrollTransition` | 官方文档：「as this view appears and disappears within the visible region of the containing scroll view」——**双向**、**每次滚入滚出都作用**；`axis: nil` 时取「innermost containing scroll view」的轴 | 否决：① 滚出时节点会缩回，读起来像「未到达 / 被禁用」，与阶段语义冲突；② 每次重播；③ 横向布局自带内层 `ScrollView`，按文档取最内层 ⇒ 页面纵向滚动驱动不了它（推断）；④ 无滚动宿主时的行为文档未写 |
| `.onAppear` 触发 | `VStack` 内全部行在挂载时一起 `onAppear`，与视口无关 | 否决：屏外的行在用户看到之前就播完了 |
| **`onScrollVisibilityChange` + 一次性闩锁** | 首次回调 `true` 时置闩、播一次；之后的 `false` / `true` 忽略 | **采用** |

采用方案的行为（P4 实测支撑前三行）：

- **无 `ScrollView` 宿主**：挂载即回调 `true` ⇒ 挂载时播一次。
- **在 `ScrollView` 内**：首帧只有可见行播；屏外行在第一次被滚入时播。
- **嵌套滚动**：可见性同时受外层裁剪（纵向页面里的横向 `ScrollView`，内层项在外层滚入前为 `false`）⇒ 以「真的出现在屏幕上」为准。
- **再次滚入不重播**：闩锁是节点视图的 `@State`，身份不变就不重播。身份丢失时会重播：调用方把整个 `Timeline`
  放进会回收单元的惰性容器、`ForEach` 的 id 变了、施了 `.id(_:)`——写进文档。
- 阈值取 `0.5`（节点一半可见）；多行同时可见时同时播，**不做错峰**。
- 动画形态：`keyframeAnimator(initialValue: 1, trigger: 入场计数)`——首帧瞬移到 `CollectionItemTransition.enteringScale`
  （`CoreMotionToken.swift` 逐字 `nonisolated static let enteringScale: CGFloat = 0.86`）同时不透明度 0，
  再以 `reveal` 曲线回到 1。**静止值就是终态**：没触发过的节点（包括 `ImageRenderer` 快照、位图判据）画的都是
  缩放 1、不透明度 1 ⇒ 入场动效不污染任何静态像素。

### 6.4 Reduce Motion 降级（两类分开）

| 呈现（`coreMotionPresentation`） | 阶段推进 | 节点入场 |
|---|---|---|
| `.animated` | 连线沿线生长 + 圆点形态插值（`reveal`） | 缩放 0.86 → 1 + 淡入 |
| `.resting`（系统 RM 开） | **连线不生长**：新到达的段整段以 `easeInOut(0.25)` 淡入着色、退回的段淡出；圆点形态插值照旧（纯颜色 / 不透明度，`reveal.animation(for: .resting)` 给的正是 `easeInOut`） | **不播**（无缩放、无淡入）——入场不承载信息，淡入也省掉 |
| `.hidden`（只来自注入覆盖） | 直接到终态 | 不播 |

生长走 `CoreMotionToken.reveal.transformAnimation(for:)`（`.resting` 下为 `nil`），与折叠组 chevron 的降级同一取法。

### 6.5 能耗闸：不适用

`EnergyState` 管的是**常驻渲染层**（`CoreMotionToken.swift` 逐字「只看 Reduce Motion，不看能耗——能耗闸只管常驻渲染层（`EnergyState`）。」）。
本组件的两类动效都是一次性过渡，没有 `TimelineView` 驱动的常驻层 ⇒ 不接 `EnergyState`。
这也是「进行中」不做脉冲的理由之一：一旦做脉冲，它就是常驻层，必须过能耗闸（§11 否决项 7）。

### 6.6 纪律台账

- `CoreMotionTokenDisciplineGuard.ledger` 登记 `"Components/Timeline/Timeline.swift": .gated`（若动画调用点落在
  `TimelineStackLayout.swift`，该文件同样登记）。
- `transformLedger` 登记入场缩放的调用点（理由：「`keyframeAnimator` 只在 `.animated` 下被触发；resting / hidden 不触发，静止值为 1」）。
- ⚠️ 该守卫**不覆盖** `Shape` 的 `animatableData` 与 `keyframeAnimator` 的闭包（其文档注释已列为已知不覆盖）⇒
  连线生长的 RM 分支**只能**由 §9.5 的在飞帧判据兜，不能指望源码守卫。

## 7. f：无障碍不回退

保留的能力（源码读）：默认圆点逐字 `.accessibilityLabel(` + `Timeline.accessibilityLabelKey(for:)` 取键
（`Info` / `Success` / `Warning` / `Error` / `Neutral`）；自定义节点不叠加；`.grouped` 对默认节点项把状态挂在
内容的 `accessibilityValue` 上。

新设计：

| 场景 | 状态（`StatusLevel`） | 阶段（新增） |
|---|---|---|
| 默认圆点，活动流 | `accessibilityLabel` = 状态键（**不变**） | —— |
| 默认圆点，带阶段 | 同上 | `accessibilityValue` = 阶段键（`Completed` / `In Progress` / `Not Started`，进 `en.lproj/Localizable.strings`，`bundle: .module`） |
| 自定义节点，活动流 | 不叠加（**不变**） | —— |
| 自定义节点，带阶段 | 不叠加 | 节点外包 `.accessibilityElement(children: .combine)` + `accessibilityValue(阶段)`——调用方节点自带的 label（如头像名）被合并保留，读作「Alice, Completed」；节点无无障碍内容时只读阶段 |
| `.grouped` | 默认节点项：值含状态键（不变）；自定义节点项：不含 | 带阶段时值再追加阶段键，以「, 」连接 |
| 连线 | `.accessibilityHidden(true)`（装饰） | —— |

- **分组形态（U8）**：不引入行级无障碍容器。§3.1 的单遍 `Layout` 要求节点与内容是**同一个** `Layout` 的兄弟子视图，
  行级容器会把它们重新包成一个子视图、失去跨行列宽 ⇒ 结构上不可兼得。旧实现同样没有行级分组（节点元素 + 内容
  各自成元素），⇒ **不回退**；状态与阶段播报在节点元素上，它在阅读顺序上是每行的第一个元素（`.vertical`；
  `.alternate` 下内容在左的行，读序可能是内容先于节点——**推断**，见 R6）。
- 内容仍不合并（`content` 内含多个可交互元素时 VoiceOver 可逐一定位，同旧文档）。
- 结构件标题加 `.isHeader`，VoiceOver 转子可按条目跳转（新能力）。
- `.grouped` 的值是施在 `Subview` 代理外层的无障碍修饰——**未实测**（P5），R1。

## 8. 迁移面清单

### 8.1 调用点（grep 口径与计数，`f0f03c2`）

口径：`grep -cE '(^|[^A-Za-z])Timeline\('`（排除 `TimelineView(`、`LegacyTimeline(`、`consumeTimeline(` 这类前缀，
**不按** `Timeline(items:` 匹配——会漏换行写法）；`TimelineItem(` 用 `grep -oE '(^|[^A-Za-z])TimelineItem\(' | wc -l`。

| 文件 | `Timeline(` | `TimelineItem(` | 备注 |
|---|---|---|---|
| `App/Sources/ComponentData.swift` | **4** | 8 | 含 `Timeline(` 换行写法 1 处；`private static var items: [TimelineItem]` 要改成 `@ViewBuilder` 属性 |
| `App/Sources/Previews.swift` | **5** | 9 | 含换行写法 1 处；共享 fixture `PreviewSnapshotFixtures.timelineItems`（逐字 `static var timelineItems: [TimelineItem] {`，被 3 处引用）改为 `@ViewBuilder static var timelineRows: some View`（P1 实测 `Group(subviews:)` 会展平它） |
| `scripts/downstream-probe/Sources/DownstreamProbe/PublicVisibility.swift` | 1 | 2 | `consumeTimeline()` 改写，覆盖 4 个 init + `progress:` + `timelinePhase` 读取；该 job 带 `-warnings-as-errors` |
| `Tests/OhMyDesignTests/TimelineTests.swift` | 11 | 19 | 结构断言（`timeline.items`、`item.node`、`isLastItem`）随类型消失而重写；`#398` 的 `LegacyTimeline` 依赖旧 `TimelineItem`，改为依赖测试内的旧类型拷贝 |
| `Tests/OhMyDesignTests/DynamicTypeLayoutTests.swift` | 1 | 2 | `#if os(iOS)`，只在 iOS 腿跑 |
| `Sources/OhMyDesign/Components/Timeline/Timeline.swift` | 7 | 13 | 本体 + `#Preview` 画廊 |

`ComponentJudgeRulesTests.swift` 里的 `public struct TimelineItem {` 是判据自证的合成源码字符串，**不改**。

### 8.2 文档与判据

| 落点 | 处置 | PR |
|---|---|---|
| `QuotedEvidenceGuard` 的 5 条（`grep -c 'Components/Timeline/Timeline.swift'` = 5） | `@ViewBuilder node: () -> Node,` ×2、`private var nodeContent: some View` ×2：**保持原样**（签名与默认画法保留，§1.2）；`static let nodeColumnWidth: CGFloat = 24` ×1：换成 `static let minimumNodeExtent: CGFloat = 24`，registry 引文同步（§5.2）。登记表条数不变（`citations` 现 114 条，地板 `>= 74`） | 1 |
| `docs/contract-defects.md` / `docs/component-contract.md` | 引文不变 ⇒ 不改；PR 2 合入前 grep 复核两段上下文仍为真（「`TimelineItem` 的 `node:`」是外观槽、「`content:`」是内容槽） | 2 |
| `docs/component-registry.json` `Timeline` | `notes`：§5.2 两处（PR 1）；追加 `#420` 段：组合式 API、阶段维度正交、`node:` 槽仍是 D1（PR 2 / 3）。`styleEnum` 仍 `TimelineLayout`，J-2 定义域仍 16 | 1–3 |
| registry 新条目 `TimelineItem` | 它成为公开 `View` ⇒ `registryCoversOhMyDesignTypes` 要求登记；条目数断言 58 → 59（同步那句「`#422` 新增 Tree 后变为 58」的注记）；README 索引 `Timeline` 行经 `readmeRowCoverage` 映射覆盖 `TimelineItem`（先例 `SettingsRow` → `SettingsRowChevron`）。落点按公约走查（预判：`prescriptive`、`needsExtensionPoint: false`，排布候选由 `Timeline` 条目承担）⇒ **不进** J-2 定义域 | 2 |
| `docs/components/timeline.md` | 重写 API / 用法 / 布局 / 视觉 token / 无障碍；删 `Timeline.applyGroupedStatusValue(_:item:)` 这个不存在的函数名（repo-survey A.6 已指出的漂移）；「stable identity 提示」改写 | 1–4 |
| `docs/BREAKING-CHANGES.md` | 新增「未发布（相对 `v0.11.0`）——Issue #420」一节：签名变更表（旧 → 新）、行为变更、新增、迁移示例 | 1–4 逐 PR 追加 |
| `docs/design-digest.md` | `scripts/design-digest.py` 重生成；`FLOORS` 按实际增量改并注 `#420`（预期 components +1、enums +2、enumcases +6） | 2 / 3 |
| `docs/snapshots/OhMyDesignPreview_Previews.swift_Timeline*.{png,json}` | `scripts/run-snapshots.sh` 重生成（PR 1 横向连线出现；PR 2 / 3 新增参考形态） | 1–3 |
| PRD FR-1 | PR 2 合入时在 FR-1 注明：命名保留 `TimelineItem` / `node:`、阶段取容器推导（本 spec §1.2、§4.1） | 2 |
| 历史 plan / spec（`docs/superpowers/plans/2026-05-*` 等 7 份引旧 API 的） | 史料，不改 | —— |

### 8.3 像素不变的射程

**有意保留**（对照原样拷贝的旧实现，§9.1 闸门）：

- `.vertical` / `.alternate` / `.grouped`，纯活动流，节点 ≤ 24×24（默认圆点五档状态、SF Symbol 图标、Ø20 固定圆、
  不带尺寸的 `Circle()`），内容高 ≥ 16pt；
- `.horizontal` 同上条件下，**连线像素以外**逐点相同；
- 带阶段时 `completed` 行的默认圆点与活动流逐点相同。

**有意改变**（另立新基线、登记 BREAKING）：

- `.horizontal` 多出节点间连线；
- 大于 24pt 的节点：列宽 / 行高 / 连线端点随之变化（旧实现是溢出、被连线穿过）；
- 内容高 < 16pt 的非末行：行高多出最短连线 `m`；
- 带阶段的全部新外观（外环、空心、着色连线）；
- 节点入场动效（首次可见时的运动，静止帧不变）。

## 9. 判据计划

纪律：判据能被变异打红；**变异不照判据的形状构造**（改一个真实会犯的错，不是把判据读的常量改掉）；
每次变异先 `git diff` 确认落到了文件里再跑。

**资源色约束**：默认圆点取 `StatusColors`（asset catalog），macOS native 腿上解析为全透明。⇒
- 状态色相关的位图判据只在 catalog 已编译的腿上跑（沿用 `TimelineNodeColorRenderTests` 的 `.enabled(if: assetCatalogIsCompiled, …)`）；
- macOS 腿的几何 / 形态判据改用**不走 catalog 的颜色**：`status: .neutral`（取 `contentSecondary`，系统色）、
  自定义节点 `Color.black` 色块、`.tint(.black)` 固定着色层（不用默认 `.tint`——它在 macOS 取用户强调色，换机器就变）；
- 取色映射本身继续用 asset 名断言（`nodeColorMapsToStatusColorsAsset` 那一族），双腿都跑。

**位图容差**：「应相同」用 `expectBitmapsEquivalent(maxChannelDelta: 2)`（`noiseTolerance = 2`，先例 `TreeTests`）；
「应不同」不用裸 `expectBitmapsDiffer`（一个字节不同就过），改为「逐通道最大偏差 > 8（`minimumSignalDelta`，
先例 `TreeSearchRenderTests`）**且**差异像素数 ≥ 预期区域面积的一半」——预期区域由几何算（例如一段连线 = 长 × 1pt）。

### 9.1 几何（PR 1）

| 判据 | 腿 | 形式 |
|---|---|---|
| §3.7 纯函数表逐行 | 双腿 | 纯函数；含 `infinity` / `-infinity` / `nan` / 负数 / 空数组；现有 `alternateSlotWidth` 断言原样保留 |
| 列宽 = 最宽节点 | macOS | `.vertical`：三行，节点 `Color.black` 24×24 / 40×56（非正方形）/ 20×20，内容为纯色块；量三行内容色块的左缘列 ⇒ 三者相等且 = 40 + md |
| 高节点不被穿过 | macOS | 同上夹具、`.tint(.black)` + `.completed` 使连线为实黑：中轴列上，40×56 那行节点盒内部无连线像素、连线首像素 y = 盒下沿（±1） |
| 连线终点 = 下一盒上沿 | macOS | 同上，连线末像素 y = 下一盒上沿 − 1（±1） |
| `.alternate` 中轴一致 | macOS | 同夹具 `.alternate`：各行节点色块水平中心列相同，且 = 行宽 / 2（±1）；连线列 = 该列 |
| `.horizontal` 横轴与内容顶 | macOS | 盒高 24 / 56 混排：各节点色块垂直中心行相同；各内容色块顶行相同 = 56 + sm；连线在横轴行上、从左盒右沿到右盒左沿 |
| RTL | macOS | 行内容为纯色块：`.vertical` RTL 图 = LTR 图水平翻转（≤ 噪声） |
| **旧实现闸门**（`Legacy420*`） | 双腿（iOS 另加五档状态色） | 把 PR 1 父提交的渲染类型原样拷进测试 target、改名；§8.3「有意保留」矩阵 × {light, dark} × {`.vertical`, `.alternate`, `.grouped`} 新旧各渲一张，尺寸相同且 `expectBitmapsEquivalent(maxChannelDelta: 2)`；`.horizontal` 先把连线带（横轴 ±1pt、相邻盒之间）遮掉再比 |
| `.horizontal` 确有连线 | macOS | 同夹具新旧对照的连线带：「应不同」（偏差 > 8 且差异像素 ≥ 连线预期面积一半） |

`Legacy420*` 闸门横跨 PR 1–2（PR 2 换 API 后同一矩阵再过一遍），**PR 2 最后一个 commit 删除**，读数写进 PR 正文
（Tree `Legacy422` 的先例：拷贝件常驻只会变成维护负担）。`#398` 的三条旧圆点对照是另一回事，**保留**，只改它依赖的旧类型拷贝。

计划变异：

- 列宽逐行各算各的（不跨行取最大）——预期「列宽 = 最宽节点」红；
- 行高只看内容、不看盒高（「沿用 `HStack` 的思路」）——预期「高节点不被穿过」红；
- 连线起点写回常量 24（旧实现的 `.padding(.top, …)` 回归）——预期「高节点不被穿过」红，闸门仍绿（说明闸门测不到它，符合射程）；
- 节点提议改成 `.unspecified`——预期闸门红（`Circle()` 节点从 24 缩到 10）；
- `.alternate` 仍调单参数 `alternateRowMetrics(forRowWidth:)`（忘了传列宽）——预期「中轴一致」红；
- `.horizontal` 内容顶取本列盒高——预期「内容顶一致」红；
- 两参数版 metrics 去掉 `nodeColumnWidth` 的 `nan` 防御——预期纯函数红。

### 9.2 API 迁移（PR 2）

| 判据 | 形式 |
|---|---|
| 行规格读取 | 纯结构：`Group(subviews:)` 解析出的行序列与声明一致（含 `ForEach` / `if` / 非行子视图），用 `ImageRenderer` 渲染一个每行内容为不同宽度色块的夹具，量内容左缘 / 顶沿顺序 |
| 非行子视图不占行序 | 带阶段 `.inProgress(at: 1)`，第 0、1 行之间插一个 `Text`：第 1 个 `TimelineItem` 的节点形态为进行中（neutral 空心 / 实心 + 外环可在 macOS 区分） |
| `timelinePhase` 只在 `node:` 内有值 | 自定义节点与内容各放一个读环境的探针视图，把读数画成不同宽度色块：节点内按阶段、内容内恒 `nil` |
| 旧实现闸门 | §9.1 同一矩阵，新 API 写法 |
| J-2 / registry / README / 引文 | 既有守卫：`ComponentExtensionPointGuard`（16 不变）、`ComponentRegistryGuard`（59）、`QuotedEvidenceGuard`、`ComponentTextParamGuard`、`BoolExemptionGuard` |

变异：`TimelineItem` 的 body 把节点也作为第二个视图产出（「顺手让它自己画节点」）——预期行序判据红（P1：会被展平成额外子视图）；
容器改为对 `Subview` 施 `.environment(\.timelinePhase, …)`（「更 SwiftUI 的写法」）——预期 `timelinePhase` 判据红（P1b）。

### 9.3 阶段真值表（PR 3）

| 判据 | 形式 |
|---|---|
| 真值表逐行 | 纯函数：`phase(at:)` × {`.notStarted`, `.inProgress(at: -1 / 0 / 2 / n−1 / n / n+5)`, `.completed`} × `n ∈ {0, 1, 5}`；段着色与 `P` 同表 |
| 着色接线 | macOS 位图：`.tint(.black)`，`n = 5`，`.inProgress(at: 2)`：前两段中轴列为黑、后两段为 `dividerDefault`（系统色，可解析）；`.completed` 全黑；不传 `progress` 与旧实现闸门同图 |
| 形态接线 | macOS 位图：`status: .neutral` 三阶段三张图两两「应不同」；`completed` 与活动流「应相同」 |
| 无障碍取值 | 纯函数：`(status, 有无自定义节点, phase, layout)` → 值键序列，覆盖 §7 表每一行；iOS `axe describe-ui` 手工读一次（不进 CI，读数写 PR 正文与 `timeline.md`「不在 CI」清单） |

变异：照 reui 写成 `index <= k` 判已完成（进行中行被判成已完成）——预期真值表红；段着色看行 `i` 是否 `inProgress`
而非是否到达（「进行中那一段也算走过」）——预期着色接线红；不传 `progress` 时当成 `.completed`（「默认全完成」）——预期
闸门红；带阶段时自定义节点忘了包阶段值——预期无障碍纯函数红。

### 9.4 与 `Steps` 不共用类型

源码判据：`Timeline` 目录下不出现 `StepsProgress` / `StepItem`，`Steps` 目录下不出现 `TimelineProgress` / `TimelinePhase`；
`git diff` 核 `Sources/OhMyDesign/Components/Steps/` 零改动（PR 正文贴读数）。

### 9.5 动效与 Reduce Motion（PR 4）

在飞帧判据只在 macOS 腿（`CoreMotionTokenInFlightTests` 已登记原因：iOS 的 `layer.render(in:)` 拍不到进行中的帧），
承重量取**结构量**（互异中间位置的个数），不取具体读数（PRD NFR）：

| 判据 | 形式 |
|---|---|
| 推进会生长（RM 关） | `HostedWindow`，`n = 5`、`.tint(.black)`，`progress` 从 `.inProgress(at: 0)` 改为 `(at: 3)`：采样期内中轴列黑色长度出现 ≥ 2 个**不在段边界上**的中间值；拍不到按 `observeControlMotion` 的「无法下结论」处理，不放行 |
| 推进不生长（RM 开） | 同上 `.resting`：黑色长度只出现段边界值（整段淡入，长度不经过段内位置），中间值个数 = 0 |
| 回退从远端收 | RM 关，`(at: 3)` → `(at: 1)`：中间长度单调不增 |
| 入场按视口触发 | `HostedWindow` + `ScrollView`，第 8 行初始在屏外：滚入时该行节点色块宽度出现 ≥ 2 个介于 `0.86×` 与 `1×` 之间的中间值（若挂载时就播完了，此处为 0） |
| 不重播 | 同一窗口滚出再滚回：中间值个数 = 0 |
| 无滚动宿主挂载即播 | 无 `ScrollView`：挂载后采样出现中间值 |
| 入场 RM 不播 | `.resting`：滚入时中间值个数 = 0，且无不透明度渐变（色块像素只有两种取值） |
| 静止帧不受入场影响 | `ImageRenderer` 渲染 = `.hidden` 覆盖下的渲染（≤ 噪声） |
| 源码台账 | `CoreMotionTokenDisciplineGuard` 的 `.gated` 与 `transformLedger` 条目 |

变异：推进用 `.animation(CoreMotionToken.reveal.animation, value: position)`（取了 token、能过纪律守卫，但绕过了
`coreMotionPresentation`）——预期「RM 开不生长」红；入场改挂 `.onAppear`——预期「按视口触发」红；闩锁放在会被重建的
子视图里（身份随 `P` 变化）——预期「不重播」红；入场 `initialValue` 写成 0.86（「从小开始更自然」）——预期
「静止帧」红与 §9.1 闸门红。

### 9.6 强制检查（每个 PR）

macOS `swift test`（读 `Test run with N tests` 总数）、iOS `xcodebuild -scheme OhMyDesign-Package`（`.xcresult`
**顶层** `passedTests`）、预览宿主（按 CLAUDE.md 核 `Debug-iphonesimulator` + `Compiling ComponentData.swift` +
`in target 'OhMyDesignPreview'` 步数非 0）、`scripts/downstream-probe`、MainActor 棘轮、`design-digest.py`。

## 10. 拆 PR 建议

参照 `#429` 的 4-PR 拆法：每个 PR 独立可合并，验证口径分层。

| PR | 内容 | 公开 API | 承重验证 |
|---|---|---|---|
| **1 几何内核** | `TimelineStackLayout` + §3.7 纯函数；**仍由旧 `[TimelineItem]` 数据喂**；节点盒自适应、连线端点取实际几何；`.horizontal` 连线（d）；`nodeColumnWidth` → `minimumNodeExtent`；§5.2 更正传播三处；`Legacy420*` 闸门 | 不变（`nonisolated` 加在 `TimelineLayout` 上除外） | §9.1；快照重生成 |
| **2 组合式 API 迁移** | `Timeline<Content>` + `Group(subviews:)` + `ContainerValues`；`TimelineItem` 变 `View`、四个 init、结构件；移除旧 init；§8.1 全部调用点、fixture、probe、测试；registry 新条目 + 计数 59 + README 映射；活动流（>24pt 头像）与部署日志两个参考形态；BREAKING；digest；删 `Legacy420*` | **破坏性** | §9.2；预览宿主、probe、棘轮（本 PR 是它们的主战场） |
| **3 阶段** | `TimelineProgress` / `TimelinePhase` / `init(progress:)` / `timelinePhase`；静态形态与连线着色；阶段无障碍；路线图参考形态 | 加法 | §9.3、§9.4 |
| **4 动效** | 推进补间、入场闩锁、RM 分支、纪律台账 | 无 | §9.5 |

依赖是线性的（2 依赖 1 的几何，3 依赖 2 的容器，4 依赖 3 的 `P`）；PR 1 不动公开签名，合入后 main 上外观只多了横向连线
与大节点自适应，可单独发布。

## 11. 被否决的替代方案

1. **容器逐行注入环境值（reui Context 的直译）**：P1b / P1d 实测对 `Subview` 施自定义环境值进不了 body。
2. **节点由 `TimelineItem` 自己画、作为第二个子视图产出**：拿不到阶段（同上），且会被 `Group(subviews:)` 展平成
   额外子视图（P1），行序要靠「两个一组」的约定维持，任何一个行多产出一个视图就全错位。
3. **`PreferenceKey` / `onGeometryChange` 求最宽节点**：两遍布局、首帧跳动、`ImageRenderer` 判据测到的是首帧（§3.1）。
4. **只用 `alignmentGuide` 对齐中轴**：拿不到最宽值，内容列起点参差（§3.1）。
5. **自定义 result builder、行不是 `View`（Swift Charts 的 `ChartContent` 式）**：可免去 registry 新条目，但要自己实现
   `ForEach` / `if` 的 builder 支持，调用方熟悉的 `ForEach(data)` 写法全要换成本组件专用的，收益不抵成本。
6. **逐行显式阶段 `phase:`**：允许非单调组合、连线着色无定义、做不出沿线推进（§4.1）。
7. **「进行中」呼吸 / 脉冲**：常驻渲染层，要接 `EnergyState`；「进行中」已有静态外环表达，脉冲只加成本。
8. **`.scrollTransition` 做入场**：双向、重播、滚出时缩回读作「未到达」、嵌套时取最内层（§6.3）。
9. **保留 `Timeline(items:)` 作过渡 shim**：PRD 已定案移除；且新 `TimelineItem` 是泛型 `View`，`[TimelineItem]`
   这个类型本身不成立，shim 只能换名，等于另起一套 API。
10. **行内结构件做成独立子组件视图**（`TimelineTitle` / `TimelineTime` / `TimelineDescription`，reui 的分解直译）：
    每个都是公开 `View` ⇒ registry 多 3 条、README 多 3 个映射、各走一遍公约，而它们只承担字体与颜色两个取值（U7）。
11. **改名 `TimelineEntry` + `indicator:`**：公约文档里 D1 / 内容槽两个范例要改写、`QuotedEvidenceGuard` 多动 4 条，
    语义上无收益（U2）。

## 12. 风险、未决与需要拍板

### 风险

- **R1** `.grouped` 与自定义节点的无障碍值施在容器构造的包装 / `Subview` 代理外层，是否进入无障碍树**未实测**（P5）——
  PR 2 / 3 以 iOS `axe describe-ui` 前置核对；读不到则 `.grouped` 的阶段值退回由 `TimelineItem` 自己施（它能读到统一下发的 `layout`，读不到逐行阶段 ⇒ 届时阶段在 `.grouped` 下无法播报，回来重议）。
- **R2** 入场闪帧：`onScrollVisibilityChange` 若在首帧提交之后才回调，用户会先看到一帧终态再缩小——PR 4 的在飞采样要专门看挂载后的前几帧；若闪，改为「`.animated` 且尚未触发时静止值为 0.86」并接受快照需要 `.resting` 覆盖。
- **R3** P4 只在 macOS 测；iOS 上 `onScrollVisibilityChange` 的首帧行为与嵌套滚动是推断。
- **R4** 容器非惰性：全部行都构建（与旧 `VStack` 相同，不是回退）；超长时间线的惰性化不在本 issue。
- **R5** `AnyView` 进 `ContainerValues`：节点视图类型擦除；节点的 `@State`（入场闩锁）挂在容器构造的 `TimelineNodeView` 上、以 `subview.id` 为身份——依赖 `subview.id` 在数据不变时稳定（文档保证，未单独实测）。
- **R6** `.alternate` 下 VoiceOver 读序按几何还是按声明序未测；若按几何，内容在左的行会先读内容后读状态。
- **R7** P1b 描述的是当前 SwiftUI 行为（「自定义环境值进不了 `Subview` 的 body」）；若将来 Apple 改变它，本设计仍然正确（容器自建节点不依赖这一点），只是 §11 第 1 条的否决理由弱化。
- **R8** `title: LocalizedStringKey` 接数据驱动的字符串（`"\(e.actor) \(e.verb)"`）会走一次本地化查表、查不到回退原文——行为正确但语义上是插值键；纯用户数据可改用 `content:` 放 `Text(verbatim:)`。
- **R9** 最短连线 `m` 让「内容高 < 16pt」的旧布局变高（§3.3），属有意变化但可能被下游快照捕获。
- **R10** 本 spec 的探针未开 `defaultIsolation(MainActor)`；四个 init 的重载解析与 `ContainerValues` 存 `AnyView` 在本仓 target 设置下是否同样成立，PR 2 第一个 commit 先编译验证。

### 未决（可后续加法）

- `.completed(through:)`：「前 k 行完成、暂无进行中」这一态（订单等待揽收）；现在只能用 `.inProgress(at:)` 近似。
- 惰性化（`LazyVStack` 版）、错峰入场、分组日期头的专用部件。
- 连线与节点之间的间隙（现为 0，贴盒边，与旧实现一致）是否要留空，交视觉评审。

### 需要用户拍板

| # | 问题 | 推荐 | 备选 |
|---|---|---|---|
| **U1** | 阶段取值方式 | 容器 `progress: TimelineProgress`（`.notStarted` / `.inProgress(at:)` / `.completed`）+ 行序推导 | 逐行显式 `phase:` |
| **U2** | 命名 | 沿用 `TimelineItem` + `node:` | 改 `TimelineEntry` + `indicator:` |
| **U3** | 未开始 / 进行中的默认圆点 | 色相仍取 `status`；未开始 = 同色空心环；进行中 = 实心 + 同色外环 | 未开始统一中性灰 |
| **U4** | 入场重播 | 每个视图身份只播一次（滚出再滚入不播） | 每次滚入都播 |
| **U5** | RM 下的入场 | 完全不播 | 保留淡入 |
| **U6** | 非 `TimelineItem` 直接子视图 | 按内容摆放、不占行序、连线贯穿 | 当无节点的行并计入行序 |
| **U7** | 行内结构件 | `TimelineItem` 的 init 参数（标题 → 时间 → 描述 → 富内容），不新增公开视图 | 三个独立子组件视图（多 3 条 registry） |
| **U8** | 无障碍分组 | 不加行级容器（与旧实现一致），状态 + 阶段挂在节点元素上 | 行级容器（要放弃单遍列宽，回到 §3.1 被否决的两遍方案） |
| **U9** | 节点下方最短连线 `m` | `CoreSpacing.sm`（8pt） | `CoreSpacing.xs`（4pt，像素保持前提放宽到内容高 ≥ 12） |
| **U10** | 阶段对调用方的暴露 | `@Environment(\.timelinePhase)` 只在 `node:` 槽内有值 + 公开 `TimelineProgress.phase(at:)` | `node:` 闭包带阶段参数（改 `@ViewBuilder node: () -> Node,` 这条被引签名） |
| **U11** | 已到达连线的颜色 | `.tint`（与 `Steps` 同源，调用方可 `.tint(_:)`） | 取下一行的 `status` 色 |
