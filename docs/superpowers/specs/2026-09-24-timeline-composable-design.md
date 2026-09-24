# Timeline 组合式 API（#420）设计 spec

- 日期：2026-09-24（第 4 版：定向复审收口，U16–U18 定案；第 3 版 §12 拍板项全部定案；第 2 版按 spec 评审 REVISE 补实验、逐条处置）
- Issue：`wxlpp/oh-my-design#420`（PRD `.claude/prds/timeline-tree-action-buttons.md` FR-1，破坏性变更）
- 基线：`origin/epic/structure-components` = `f0f03c2`（PR 1 开工时 merge 到 `27fb971`，其间 Timeline 相关文件零改动）
- 本文只是设计，**不含实现代码**。「实测」均指 §0 列出的 scratch 探针（不进仓库），其余标「源码读」或「推断」。
- 实现拆成 4 个可独立合并的 PR（§10）；逐 PR 的 plan 见 `docs/superpowers/plans/2026-09-24-timeline-composable-plan.md`。
- **§12 的拍板项已全部定案**（用户拍板 2026-09-24，全部取推荐项，含 U16–U18；其余按证据定案），正文按定案写成。

## 0. 证据来源与标注口径

| 标签 | 含义 |
|---|---|
| **源码读** | 在 `f0f03c2` 上直接读到的源码 / 文档原文 |
| **实测** | 本次 scratch 探针。macOS 腿：macOS 26.3.1 / Swift 6.3 / `swiftc -swift-version 6` 直接编译运行（P1–P5 **未开** `-default-isolation MainActor`；P6–P8 **开了**）。iOS 腿：iOS 26.4 模拟器 + `axe describe-ui`（P9、P10） |
| **推断** | 未经实测；进实现期前要么补探针，要么在判据里兜住 |

探针（`scratchpad/420/` 下 `p1.swift` … `p8b.swift` 与 iOS 工程 `axapp/`）读数：

| # | 问题 | 读数 |
|---|---|---|
| P1 | `Group(subviews:)` 对「body 是多个视图的自定义 View」怎么解析 | **展平**：5 个 `Item`（body 各 2 个视图，含 `ForEach` 与 `if` 生成的）解析出 10 个 subview，顺序与声明一致 |
| P1 | 自定义 `Layout` 能否在一次布局里取到「所有节点里最宽的那个」 | 能：`ImageRenderer` 单次渲染里 `placeSubviews` 算出 `col=40.0`（一个 40pt 宽节点 + 其余 24pt） |
| P1b / P1d | 对**解析后**的 `Subview` 代理施 `.environment(\.自定义键, 值)`，其 body 里 `@Environment` 读到什么 | **读不到**：`ImageRenderer` 与 `NSHostingView` 两种宿主下 body 都读到默认值；对照组直接对视图施同一环境值，读到了 |
| P1c | 把节点视图以 `AnyView` 存进 `ContainerValues`、由容器取出后再施 `.environment` | 行得通：4 个节点各自读到容器注入的 `row0`…`row3` |
| P1c | 对 `Subview` 施 `.font(.system(size: 60))` 是否生效 | 生效（渲染高 16 → 71）⇒ P1b 只针对自定义 View 的 body 读 `@Environment` |
| P5 | 在 `Group(subviews:)` **解析之前**对整个 content 施环境值 | 每行 body 都读到。⚠️ 分界是**解析前 / 解析后**，不是「统一 / 逐行」：解析前施的值当然对所有行相同，但**行自己可以拿它和自己的参数算出逐行不同的结果**（P6） |
| P2 | 自定义 `Layout` 在 RTL 下是否自动镜像 | 是（宽 100：LTR 落第 0…9 列，RTL 落第 90…99 列） |
| P3 | 四个 init 的重载集是否有歧义；泛型 `@ViewBuilder` 闭包默认值能否编译 | 四个 init 无歧义；加第五个「标题 + 节点、无富内容」init 后 `TimelineItem("Deployed") { Text("rich") }` 报 `ambiguous use of 'init'`；默认闭包可编译 |
| P4 | `onScrollVisibilityChange(threshold:)`：无 `ScrollView` / 在 `ScrollView` 内 / 嵌套 | 无宿主：挂载即回调 `true` 一次；在 `ScrollView` 内：首帧只对可见行回调 `true`，之后**滚入滚出双向回调**；嵌套：内层项在外层滚入前一直是 `false` |
| P4 | `.scrollTransition` 的当前相位能否用闭包内日志观测 | 不能（三相都会被求值）——对它的判断改取官方文档（§6.3） |
| **P6** | **I-1 模型**：容器在解析前下发 `activeStep`，行用自己的 `step` 在自身 body 算阶段、自己产出「节点 + 内容」两个子视图并以 `ContainerValues` 标角色 | ① 4 行（含 `ForEach` 生成的 2 行、`if` 生成的 1 行、中间夹一个 `Text`）各自读到 `activeStep=1`，算出 `completed / inProgress / upcoming / upcoming`；节点里的探针读到行下发的阶段，内容里读到 `nil`（行只给节点施了阶段）。② 解析出 9 个 subview，角色序列 `node#0,content#0,node#1,content#1,node#2,content#2,none#-,node#3,content#3`；同一个容器 `Layout` **单遍**取到 `col=40.0`（40×56 节点），内容一律从 x=52 起，非行 `Text` 按内容列摆放。③ 开了 `-default-isolation MainActor` 后 `LayoutValueKey` 必须标 `nonisolated`（否则报 `main actor-isolated conformance of 'PartKey' to 'LayoutValueKey' cannot be used in nonisolated context`） |
| **P6** | 调用方施在**行**上的修饰，在两种模型下是否同时作用于节点与内容（macOS `ImageRenderer` 取像素 / 环境读数；`.transition` 用托管窗口在飞采样 P6b） | 见下表 |
| **P6** | 行被调用方包进 `VStack` | I-1 模型：解析成 1 个无角色子视图，**节点与内容都还在**（竖着叠在内容列里，节点仍读到阶段）——降级但可见。原方案：解析成 1 个非行子视图，**节点静默消失** |
| **P6** | 行离开 `Timeline` 单独使用 | I-1 模型：节点与内容都渲染（`activeStep=nil` ⇒ 阶段 `nil`）；原方案：只剩内容 |
| **P7** | n = 300 / 1000 的首次布局与「一行内容变宽」触发的重排耗时（macOS 托管窗口，`-O`，粗测，两轮取后一轮） | 见 §3.8 |
| **P8** | 入场动效：`onScrollVisibilityChange` + `keyframeAnimator(initialValue: 1)` 首帧是否先画终态（`cacheDisplay` 每 8ms 采一帧，节点 20pt，量黑色像素宽度） | **同步置 trigger**：挂载（无滚动宿主）与滚入两种情形首帧都已是 16pt（≈ 0.86 档），3/3 次无终态闪帧；但 **`ImageRenderer` 静态渲染读到 17pt**（节点被画成缩小态）。**改为下一轮 runloop 再置 trigger**（P8b）：`ImageRenderer` 恢复 20pt，但托管窗口首帧是 20pt、第二帧起 16pt ⇒ **闪一帧**，3/3 次复现。详见 §6.3 |
| **P9** | iOS 基线：`f0f03c2` 上的 Timeline 画廊（`PREVIEW_COMPONENT_ID=timeline`）无障碍树 | 见 §7.1 |
| **P10** | iOS 原型：U8 各候选的无障碍树（整树 + `--point` 命中测试） | 见 §7.2 |

P6 修饰对照（行 = `TimelineItem`；节点红 10×10 于 24×24 盒、内容蓝 100×20，白底）：

| 施在行上的修饰 | I-1 模型（行自己画节点） | 原方案（容器画节点） |
|---|---|---|
| `.opacity(0.5)` | 节点中心 `(255,156,158)`、内容中心 `(128,195,255)` ⇒ **两者都半透** | 节点 `(255,56,60)` **不变**、内容半透 |
| `.padding(10)` | 节点盒 24→**44**、列宽 24→**44**、内容高 20→40 ⇒ **各自加内边距**（节点列被撑宽） | 节点 24 不变、内容高 40 |
| `.background(Color.green)` | 节点盒角点 `(52,199,89)`（绿）⇒ **两者各自铺背景** | 节点角点白 ⇒ 只有内容铺 |
| `.redacted(reason: .placeholder)` | 节点、内容都读到 `redacted=true` | 节点 `false`、内容 `true` |
| `.transition(.offset(x: 150))`（插入，`linear(1.2)`） | 节点、内容都随偏移滑入（节点中心在 t=1.2s 才变红） | 内容滑入；**节点走默认淡入**（t=0.1s 起逐帧变红）——调用方的转场碰不到节点 |
| `.accessibilityHidden(true)`（iOS，P10 `--point`） | 行的全部元素命中测试均落空 ⇒ 整行隐藏 | 内容隐藏；**节点元素仍可命中**（`label='Success' value='In Progress'`）⇒ 隐藏不完整 |
| `containerValues` 是否在外层修饰后仍存活 | 以上 6 种修饰下解析出的角色序列恒为 `node#0,content#0` | 恒为 `row` |

⚠️ `axe describe-ui` 的**整树**输出**包含** `.accessibilityHidden(true)` 的元素（对照组：普通 `VStack` 里被隐藏的 `Text("Bravo")` 照样列出）；判「隐藏没隐藏」必须用 `--point` 命中测试（同一元素命中落到父级 `Group`）。§7 的隐藏读数全部取自 `--point`。

## 1. 组合式公开 API（FR-1 主体）

### 1.1 定案一览（U1 定案：每行 `step` + 容器 `progress`）

| 公开类型 / 成员 | 形态 | 替代什么 |
|---|---|---|
| `Timeline<Content: View>` | 容器：`@ViewBuilder content` + `layout:` + 可选 `progress:` | `Timeline(items:layout:)` |
| `TimelineItem<Node: View, Content: View>` | 行，**是一个 `View`**，**自己画节点**；`node:` 外观槽 + `content:` 内容槽 + 结构件参数（标题 / 时间 / 描述）+ 可选 `step:` | 两个 `TimelineItem` init（旧 `TimelineItem` 是数据载体 struct） |
| `TimelineLayout` | **不变**（四个 case），加 `nonisolated` | —— |
| `TimelineProgress`（新） | `public nonisolated enum`：`.notStarted` / `.inProgress(at:)` / `.completed` | —— |
| `TimelinePhase`（新） | `public nonisolated enum`：`.completed` / `.inProgress` / `.upcoming` | —— |
| `EnvironmentValues.timelinePhase`（新） | `public` 只读（`internal(set)`），在本行 `node:` 与 `content:` 两个槽内都有值 | —— |

### 1.2 签名草案

```swift
public struct Timeline<Content: View>: View {
    /// 纯活动流：不带阶段，连线一律 `dividerDefault`（与旧实现同）。
    public init(layout: TimelineLayout = .vertical, @ViewBuilder content: () -> Content)
    /// 带阶段：各行阶段由 `progress` 与**该行自己的 `step`** 决定（§4）。
    public init(layout: TimelineLayout = .vertical, progress: TimelineProgress, @ViewBuilder content: () -> Content)
    public var body: some View
}

public nonisolated enum TimelineLayout: Sendable, Equatable {
    case vertical, alternate, horizontal, grouped
}

public nonisolated enum TimelineProgress: Sendable, Equatable {
    /// 全部行处于 `.upcoming`。
    case notStarted
    /// `step` 小于参数的行已完成、等于的行进行中、大于的行未开始。
    case inProgress(at: Int)
    /// 全部带 `step` 的行已完成。
    case completed

    /// 给定 `step` 的阶段（纯函数，§4 真值表）。
    public func phase(forStep step: Int) -> TimelinePhase
}

public nonisolated enum TimelinePhase: Sendable, Equatable, CaseIterable {
    case completed, inProgress, upcoming
}

public struct TimelineItem<Node: View, Content: View>: View {
    // ① 富内容 + 默认圆点
    public init(step: Int? = nil, status: StatusLevel = .info, @ViewBuilder content: () -> Content) where Node == EmptyView
    // ② 富内容 + 自定义节点（`status` 传了才把状态键挂到行上，U18）
    public init(step: Int? = nil, status: StatusLevel? = nil, @ViewBuilder node: () -> Node, @ViewBuilder content: () -> Content)
    // ③ 结构件（标题 / 时间 / 描述）+ 可选富内容 + 默认圆点
    public init(
        _ title: LocalizedStringKey,
        time: Text? = nil,
        description: LocalizedStringKey? = nil,
        step: Int? = nil,
        status: StatusLevel = .info,
        @ViewBuilder content: () -> Content = { EmptyView() }
    ) where Node == EmptyView
    // ④ 结构件 + 自定义节点 + 富内容（无富内容时写 `content: {}`，见 §0 P3；`status` 同 ②）
    public init(
        _ title: LocalizedStringKey,
        time: Text? = nil,
        description: LocalizedStringKey? = nil,
        step: Int? = nil,
        status: StatusLevel? = nil,
        @ViewBuilder node: () -> Node,
        @ViewBuilder content: () -> Content
    )
    public var body: some View
}

public extension EnvironmentValues {
    /// 本行阶段。在 `Timeline(progress:)` 内、带 `step` 的 `TimelineItem` 的 `node:` / `content:` 里有值；其余为 `nil`。
    var timelinePhase: TimelinePhase? { get }
}
```

要点：

- **保留名字 `TimelineItem` 与 `node:` 标签**（U2 按证据定案：公约 `docs/component-contract.md` 把
  `TimelineItem` 的 `node:` 当 D1 外观槽范例、逐字 `@ViewBuilder node: () -> Node,`；新 API 下这句仍为真，
  `QuotedEvidenceGuard` 那 4 条引文不必动；改名只多出改写公约范例与 4 条引文的成本，没有语义收益）。
  迁移是机械的：`Timeline(items: [ A, B ], layout: x)` → `Timeline(layout: x) { A; B }`。旧代码里的 `[TimelineItem]`
  会**编译失败**（新类型是泛型 `View`），不会静默换义。
- **`step: Int? = nil`**：纯活动流不写；带阶段的时间线每行写一个。它是**增补在既有位置之后的默认参数**，不新增重载 ⇒
  P3 的重载集读数不变（**推断**，PR 2 第一个 commit 先编译验证，与 R10 同一步）。`ForEach` 里写
  `ForEach(Array(items.enumerated()), id: \.element.id) { i, item in TimelineItem(item.title, step: i) }`。
- **去掉 `id:` 参数**：行身份由 SwiftUI 结构身份 / 调用方 `ForEach` 的 id 决定。
- **自定义节点的 `status: StatusLevel? = nil`**（U18 定案）：默认圆点的 init（①③）`status` 决定圆点色相并恒带状态键，
  缺省 `.info`；自定义节点的 init（②④）里 `status` 只管无障碍——**传了**就把状态键挂到行上（§7.3 同一挂载规则），
  此时节点里若有自带 label 的图标（`Image(systemName:)` 会读出符号名）由调用方自行 `.accessibilityHidden(true)`，
  否则同一状态读两遍；**不传**则行不带状态键。旧 init ② 的 `status` 缺省 `.info` 且从不播报 ⇒ 迁移时写了
  `status:` 的自定义节点行**新增**状态播报，登记 BREAKING（§8.1）。`status` 从非可选改成可选会改变 ② / ④ 与 ① / ③
  的重载集 ⇒ 与 `step:` 一起进 PR 2 的 E2-1 编译验证。
- **`time: Text?`** 而非 `LocalizedStringKey`：时间是格式化数据，调用方写 `Text(date, style: .relative)`。
  ⚠️ 在 `ComponentTextParamGuard` 里 `Text?` 判 **`.notText`**，不是「携带文本」——分类器只认
  `Tests/OhMyDesignTests/ComponentJudgeScanner.swift` 逐字 `(String|Substring|LocalizedStringKey|LocalizedStringResource)`
  这四个标识符，`Text` 不在其中 ⇒ 该参数**不进任何桶**，也就无需登记 `textParams`（与第 1 版写的理由不同，结论相同）。
- `title` / `description` 走 `LocalizedStringKey`（公约 §4 B 类「新增用 `LocalizedStringKey`」）⇒ 进 `localizedByType` 桶，
  计数 21 → **23**（§8.2）。数据驱动标题按 U13 定案：**只给 `LocalizedStringKey`**（插值可本地化动词、运行期值原样代入）；
  纯运行期文本（无可本地化部分）走 `content:` 放 `Text(verbatim:)`，不加 `StringProtocol` 重载、不加 `title: Text`。
- 结构件排版：`VStack(alignment: .leading, spacing: CoreSpacing.xxs)`，顺序**标题 → 时间 → 描述 → 富内容**（U7 已按证据定案：
  沿用现有画廊写法；三个独立子组件视图要多 3 条 registry 与 3 个 README 映射，只承担字体与颜色两个取值），标题 `.coreFont(.callout)` +
  `contentPrimary` + `.accessibilityAddTraits(.isHeader)`，时间与描述 `.coreFont(.footnote)` + `contentSecondary`。
- 新 API **无 Bool 入参**；所有公开类型、init、`body` 显式 `public`；两个新枚举与 `TimelineLayout` 标 `nonisolated`。
  不新增公开 `static` 存储成员 ⇒ MainActor 棘轮预期无新增豁免。内部的 `LayoutValueKey` / `ContainerValues` 键类型须标
  `nonisolated`（P6 ③）。
- `timelinePhase` 用手写 `EnvironmentKey` + `public internal(set)`，**不用** `@Entry public var`（后者连 setter 一起公开）。

### 1.3 为什么这样分解：两种渲染管线的实测对照

**reui 的真实模型**：`.claude/epics/structure-components/reference-implementations.md` 里 `TimelineItem` 的 `step` 是必填项
（该文件 API 表的 `TimelineItem` 行逐字「**必填**，该 item 的步骤号」），阶段由每项自判
（逐字 `"data-completed": step <= activeStep || undefined,`）——**容器下发 `activeStep`、每项自带 `step`**，不是行序推导。
第 1 版把它读成「容器逐行注入」，据 P1b 否决，这是误读：reui 的 Context 下发的是**对所有项统一**的 `activeStep`，
在 SwiftUI 里对应「解析前施环境值」，P5 / P6 实测可行。

两条管线（都用同一个容器级 `Layout` 单遍排版，§3）：

| | **原方案**：容器画节点 | **I-1 方案**（U1 定案）：行自己画节点 |
|---|---|---|
| 行的 body | 只产出内容；节点以 `AnyView?` 存进 `ContainerValues` | 产出**节点 + 内容**两个子视图，各以 `ContainerValues` 标角色（`.node` / `.content`）；**两个槽都包单一容器**（防止调用方多视图闭包被展平成多个子视图、破坏「节点紧跟内容」的配对），见下方「单一容器」 |
| 阶段来源 | 容器按行序算，注入到自己构造的节点视图 | 容器**解析前**下发 `progress`，行用自己的 `step` 算（P6 ①） |
| 容器 → 行 | 只能到容器构造的节点 | 解析前统一值（`progress`、`layout`） |
| 行 → 容器 | `containerValues`（status、node） | `containerValues`（角色、`step`、阶段、status）——容器据此配对与算连线着色 |
| 调用方施在行上的修饰 | **碰不到节点**：`.opacity` / `.background` / `.redacted` / `.transition` / `.accessibilityHidden` 只作用于内容（P6、P10） | **同时作用于节点与内容**（P6、P10）；⚠️ 但**逐子视图各施一次**：`.padding(10)` 让节点盒 24→44、列宽随之变 44（P6） |
| 行被包进 `VStack` 等容器 | 当非行子视图，**节点静默消失**（P6） | 当非行子视图，节点与内容竖叠、阶段仍在（P6）——降级但可见，各布局下的样子见 §1.5 |
| 行离开 `Timeline` 单用 | 只剩内容 | 节点 + 内容照常渲染，阶段 `nil`（P6） |
| `timelinePhase` 在 `content:` 里 | 恒 `nil` | 有值（行给两个槽都施） |
| 行序与阶段的关系 | 行序推导（非行子视图不占序号要额外规则） | 与行序无关，由 `step` 决定；非行子视图天然不参与 |

⇒ **第 1 版 §1.3 的定案（容器画节点）撤回**，改取 I-1 方案。原方案下的两条缺陷（I-2）：

1. 行上修饰碰不到节点（上表第 5 行）——对 `.transition`、`.redacted`、`.accessibilityHidden` 尤其致命：插入动画节点与内容不同步、
   骨架屏节点不打码、隐藏一行却留下一个可聚焦的状态元素；
2. 行被包进 `VStack` / 自定义容器 / 调用方写的 `Group { … }.padding()` 以外的包装后，`containerValues` 对外层容器不可见，
   **节点静默消失**，无任何报错。

I-1 方案下第 2 条变成「降级可见」；第 1 条消失，但换来一条新代价：**逐子视图语义**——行的 body 产出两个子视图，
施在行上的修饰对节点与内容**各施一次**。这不是 bug，是 `Group` 语义在行上的直接投射（SwiftUI 自家 `Group { A; B }.padding()`
同样逐个施）。U1 定案时一并接受（R8）。PR 2 把下表原样写进 `timeline.md` 与 `BREAKING-CHANGES.md`：

| 修饰类别 | 例 | 施在行上的效果 | 引导 |
|---|---|---|---|
| **布局** | `.padding` / `.frame` / `.offset` | 节点盒与内容各加一次；节点盒变大会撑宽整列（P6：`.padding(10)` 让节点盒 24→44） | 写进 `content:` |
| **视觉** | `.opacity` / `.background` / `.redacted` / `.transition` / `.accessibilityHidden` | 节点与内容各施一次——对这几个正是想要的（整行一起半透 / 打码 / 转场 / 隐藏，P6 / P10）；`.background` 会铺成两块 | 可施在行上；要整行一块背景请写进 `content:` |
| **行为** | `.onAppear` / `.task` / `.onTapGesture` / `.contextMenu` / `.swipeActions` | **挂两次**：`.onAppear` / `.task` **执行两次**（节点与内容各一次）；`.contextMenu` / `.swipeActions` 两个子视图各挂一份；点节点与点内容各触发一次各自的手势 | **勿施在行上**，写进 `content:`（或施在 `Timeline` 外层） |

**可点击的行（U16 定案）**：官方写法是把 `Button` / `NavigationLink` 放进 `content:`（`TimelineItem("Deployed") { … } content: { NavigationLink(…) { … } }`，
或无结构件时整块内容做按钮 label）。**整行包 `Button` 不受支持**：`Button { … } label: { TimelineItem(…) }` 对容器是一个非行子视图，
按 §1.5 的降级形态渲染（节点与内容竖叠、没有节点列、连线着色跳过它），且点击区域覆盖节点。文档写明这副降级的样子，不做运行期检测。

**单一容器**：节点槽与内容槽在行的 body 里各包一层——内容槽用 `VStack(alignment: .leading, spacing: 0)`，节点槽用 `ZStack`。
对布局的影响：调用方在 `content:` 里并列写多个视图时，它们**竖排、间距 0、左对齐**（与 `@ViewBuilder` 闭包放进 `VStack(spacing: 0)` 等价），
不会被展平进容器的 `Layout` 各占一格；空内容（`content: {}` 或 `if false` 不成立）得到一个 0 高的内容子视图，行照常成对、节点照常绘制，
行高退化为节点盒高（+ 非末行的 `m`，§3.3）。结构件 init 的「标题 → 时间 → 描述 → 富内容」本身就在一个 `VStack` 里，不另套。

### 1.4 渲染管线（内部，I-1 方案）

```
Timeline.body
└─ Group(subviews: content
       .environment(\.timelineProgress, progress)        // 解析前，行 body 能读到（P5 / P6）
       .environment(\.timelineLayoutContext, layout))
   └─ subviews → parts: [(subview, role: .node / .content / nil, step, phase, status)]   // 取自 containerValues
      ├─ layout == .grouped → VStack(spacing: md) { 只放 .content 与无角色子视图 }（§3.6）
      └─ 其余 → TimelineStackLayout(layout, metrics) {
             ForEach(parts) { part in part.subview.layoutValue(TimelinePartKey, part.role) }
             ForEach(segments) { seg in TimelineConnector(seg).layoutValue(TimelinePartKey, .connector(seg.id)) }
           }
           // .horizontal 外面仍包 ScrollView(.horizontal, showsIndicators: false)
```

- 配对规则：`TimelineStackLayout` 按解析序把「`.node` 紧跟 `.content`」认作一行；孤立的 `.node` / `.content`（调用方把行拆开了）
  按无角色子视图处理。行的 body 用 `ViewBuilder` 固定产出「节点 → 内容」两个视图，调用方正常使用下恒成对。
- 连线段由容器构造（普通视图值），端点与着色读相邻两行的 `containerValues`（§3、§4）。
- `TimelineNodeView` 保留现名，默认画法仍在 `private var nodeContent: some View`（被引文登记），由 `TimelineItem` 的 body 构造。
  文件布局：公开类型与 `TimelineNodeView` 留在 `Sources/OhMyDesign/Components/Timeline/Timeline.swift`；几何与纯函数拆到同目录新文件
  `TimelineStackLayout.swift`。

### 1.5 非 `TimelineItem` 的直接子视图（U6 已按证据定案）

调用方可能在 `Timeline { … }` 里直接放 `Text`（日期分组标题）、页脚「加载更多」按钮等。**header / footer 一律由非行子视图承担**，
不设专用参数（S-10）。处置：

- 没有节点，不参与阶段（I-1 方案下阶段只看 `step`，「不占行序」无需额外规则）；
- 摆放：`.vertical` 在内容列；`.alternate` 跨满整行、居中；`.horizontal` 自成一列（内容顶与各列对齐）；`.grouped` 照常；
- 连线（S-1）：
  - `.vertical`：连线在节点列、非行子视图在内容列，二者不相交 ⇒ 段照常从前一节点盒下沿画到后一节点盒上沿，**贯穿**；
  - `.alternate`：非行子视图跨满整行、会压在中轴上 ⇒ 段在它的**上沿截断、下沿续接**（拆成两截，着色与动效仍按同一段算），
    不从文字底下穿过；
  - `.horizontal`：非行子视图那一列没有节点，横轴上的连线**贯穿**该列（横轴在内容顶之上，二者不相交）；
- 识别方式：`containerValues` 里没有角色即非行。备选「一律当无节点的行」已无意义（I-1 方案下没有行序可错位），不取。

**被包裹的行**（调用方把 `TimelineItem` 包进 `VStack` / `Button` / 自定义容器，或施了会把行变成单一视图的修饰）也走上面这套非行规则。
P6 读数：包进 `VStack` 后解析成 1 个无角色子视图，行 body 的节点与内容**都在**，按包裹容器自己的排法摆（`VStack` 下节点在上、内容在下），
节点仍读到阶段。落到各布局：

| 布局 | 被包裹行的样子 |
|---|---|
| `.vertical` | 整块摆在**内容列**（x 起点 = 列宽 + md）；节点列在该处空着，节点画在内容列里、不在中轴上；中轴连线从前一行节点贯穿到后一行节点 |
| `.alternate` | 跨满整行居中；中轴连线在它上沿截断、下沿续接 |
| `.horizontal` | 自成一列，内容顶与各列对齐；它自带的节点不在横轴上；横轴连线贯穿该列 |
| `.grouped` | 照常摆，**包括它自带的节点**（容器只对有角色的节点子视图不摆，认不出被包住的节点） |

连线着色**跳过它**：它不是行，不参与配对，段按相邻两个真正的行算（§4.1）。无障碍按它自己的元素结构读（行 body 里的挂载规则仍生效，
因为那是行自己施的）。

### 1.6 三种参考形态的调用样貌（PRD 成功标准）

```swift
// 活动流：头像大于旧 24pt 槽，不传 progress、不写 step
Timeline {
    Text("Today").coreFont(.footnote)            // 非行子视图当分组标题（§1.5）
    ForEach(events) { e in
        // U13：标题是 LocalizedStringKey，插值把运行期的人名原样代入、动词可本地化
        TimelineItem("\(e.actor) pushed \(e.count) commits", time: Text(e.date, style: .relative)) {
            Avatar(e.actor, size: .large)        // 40pt
        } content: {}
    }
    // 纯运行期文本（例如服务端下发的事件摘要）不走标题，走 content: + Text(verbatim:)
    TimelineItem {
        Text(verbatim: serverSummary).coreFont(.callout)
    }
}

// 部署日志：逐项 success / danger，自定义图标节点
Timeline {
    ForEach(deploys) { d in
        TimelineItem("Deployed \(d.version)", time: Text(d.date, format: .dateTime), status: d.ok ? .success : .danger) {
            Image(systemName: d.ok ? "checkmark.circle.fill" : "xmark.octagon.fill")
        } content: {
            Text(d.commit).coreFont(.caption).monospaced()
        }
    }
}

// 路线图：带阶段，横向
Timeline(layout: .horizontal, progress: .inProgress(at: 2)) {
    TimelineItem("Q1 Alpha", step: 0)
    TimelineItem("Q2 Beta", step: 1)
    TimelineItem("Q3 GA", description: "Public launch", step: 2)
    TimelineItem("Q4 v2", step: 3)
}
```

（`Avatar` 的实际签名以 PR 2 落画廊时的源码为准；标题形态已按 U13 定案。）三种形态各进 `App/Sources/Previews.swift` 一个 `#Preview`
与 `ComponentData.swift` 画廊一条（§8）。

### 1.7 与 `Steps` 的边界

- `Timeline` 展示已发生 / 计划中的事件（活动流可以完全没有阶段）；`Steps` 是向导，恒有「当前步」。
  `Timeline` 不加任何 Steps 的向导行为（无 `currentIndex` 绑定、无点击跳步、无 `.segmentedBar` / `.text` 呈现）。
- **不共用类型**：`Steps` 的阶段是其内部 `enum StepsProgress`（`Sources/OhMyDesign/Components/Steps/Steps.swift` 逐字
  `enum StepsProgress: Equatable {`），两者不互相引用。`Steps` 本 issue 不改一个字。
- **可共用的**：动效 token（`CoreMotionToken.reveal`）与已到达连线的着色通路（`.tint`，Steps 逐字 `Rectangle().fill(.tint)`）；
  两边的连线归属规则**同义**（§4.1）。

## 2. a：四种布局保留，`TimelineAlternateRowLayout` 的几何判据延续

- 四个 case 不变，`TimelineLayout` 继续是 `Timeline.init` 的参数 ⇒ J-2「`styleEnum` 须接线于本组件公开 `init`」照样满足
  （宿主名仍是 `Timeline`；泛型参数不影响宿主识别，**推断**，PR 2 跑 J-2 判据兜住）。
- 旧 `TimelineAlternateRowLayout` 是逐行三栏 `Layout`；新实现并进容器级 `TimelineStackLayout` 的 `.alternate` 分支（列宽要跨行取最大）。
- 纯函数：保留 `nonisolated static func alternateRowMetrics(forRowWidth:)` 与 `alternateSlotWidth(forRowWidth:)` 的签名与语义 ⇒
  `TimelineTests` 里现有 `infinity` / `-infinity` / `nan` / 负数 / `0` / `fixed` / `fixed - 1` / `fixed + 2` 断言原样有效；
  新增 `alternateRowMetrics(forRowWidth:nodeColumnWidth:)`，旧函数转调它；`nodeColumnWidth` 非有限或小于下限时按下限处理。
- 旧常量 `static let nodeColumnWidth: CGFloat = 24` 语义变成「节点盒下限」，**改名** `minimumNodeExtent`（PR 1），
  registry `notes` 引文同 PR 改写（§5.2）。

## 3. b：指示器尺寸两维自适应

### 3.1 机制比较与定案

| 机制 | 能否跨行取最宽节点 | 行高 / 连线端点 | 一致性 | 结论 |
|---|---|---|---|---|
| **自定义 `Layout`（容器级，节点 / 内容 / 连线都是它的子视图）** | 能（P1 `col=40`；P6 在 I-1 方案下同样 `col=40`） | 同一遍算出 | 单遍、确定；RTL 自动镜像（P2） | **采用** |
| `alignmentGuide` | 不能：只对齐中轴，拿不到最宽值 | 不管行高 | 单遍 | 否决 |
| `PreferenceKey` → `@State` → 环境值回灌 | 能，但要两遍 | 两遍 | 首帧跳动；`ImageRenderer` 单次渲染拿不到回灌后状态（**推断**） | 否决 |
| `onGeometryChange` | 同上，异步 | 同上 | 同上，且有自激风险 | 否决 |

⚠️ 单个容器级 `Layout` **在架构上排斥惰性**：`Layout` 协议的 `sizeThatFits` / `placeSubviews` 拿到的是**全部**子视图，
没有「只实例化可见子视图」的通路（`LazyVStack` 那种惰性不能由第三方 `Layout` 实现）。读数与后果见 §3.8。

### 3.2 节点盒

- 节点的**提议尺寸是 `24 × 24`**（`minimumNodeExtent`），与旧实现 `.frame(width: 24, height: 24)` 给的提议相同
  ⇒ `Circle()` 这类弹性视图仍画成 24pt（改提议 `.unspecified` 会让 `Shape` 缩到理想尺寸 10×10，§9.1 计划变异）。
- 节点**报告**的尺寸 `(w, h)`（非有限值按 24）⇒ 节点盒 `(max(24, w), max(24, h))`；节点在盒内居中。
- ⇒ 所有 ≤ 24×24 的节点（默认圆点、SF Symbol 图标、20pt 圆）盒子与旧实现逐点相同，这是 §8.3「像素不变」射程的几何根据。
- ⚠️ 调用方在**行**上施的 `.padding` 会进节点盒（P6：24→44）——§1.3 的逐子视图语义；文档引导把布局修饰写进 `content:`。

### 3.3 `.vertical`

- 节点列宽 `C = max(24, 各节点盒宽)`；中轴 `x = C / 2`；每个节点盒中心落在中轴上、顶贴本行顶。
- 内容 x 起点 `C + CoreSpacing.md`，提议宽 `W − C − md`（`W` 非有限时取内容理想宽）。
- 行高 `H_i = max(盒高_i + m, 内容高_i + lg)`，末行 `H_last = max(盒高, 内容高)`；`m = CoreSpacing.sm`（U9），`lg` 即旧实现内容的
  `.padding(.bottom, CoreSpacing.lg)`。两式在 `内容高 ≥ 24 + m − lg = 16` 时与旧式 `max(24, 内容高 + lg)` 相等；更矮的内容行是有意外观变化，登记 BREAKING。
- 连线段：x = 中轴，从节点盒_i 的**实际下沿**到下一个节点盒的**实际上沿**（隔着非行子视图时贯穿，§1.5）。

### 3.4 `.alternate`

- 节点列宽 `C` 同上；槽宽与中轴走 `alternateRowMetrics(forRowWidth: W, nodeColumnWidth: C)` ⇒ 各行节点中心恒在同一条中轴上。
- 行高 `H_i = max(左槽高, 右槽高, 盒高_i + m)`，末行不加 `m`；内容按**行的配对序**奇偶换边（非行子视图不计入奇偶）。
- **溢出规则（用户定案，2026-09-24）**：两侧内容都收到**槽宽**的宽度提议（高度不提议）——文字按槽宽换行、落在本槽内，内缘贴槽内缘；
  按槽宽排版后**仍宽于槽**的内容（固定宽元素，如 `.frame(width: 220)` 色块、`.fixedSize()` 文字）内缘照样贴槽内缘，**向外**（远离中轴）
  越过槽外缘溢出，不压节点与连线；越出容器的部分由屏幕 / `ScrollView` 裁掉。左右槽同一规则，RTL 自动镜像。
  文字换行与旧实现相同（`Legacy420*` 闸门首行即左槽长文本）；变化只在固定宽超宽元素的溢出方向（旧实现向右盖住节点，§8.3）。
- 连线在中轴上，从盒_i 下沿到盒_{i+1} 上沿；中间夹非行子视图时按 §1.5 截断、续接。

### 3.5 `.horizontal`

- 外层仍是 `ScrollView(.horizontal, showsIndicators: false)`。
- 横轴 `y_axis = max(各盒高) / 2`；每个盒中心落在横轴上。内容顶一律 `max(各盒高) + CoreSpacing.sm`；内容以本列中心为轴居中。
- 列宽 `max(盒宽_i, 内容理想宽_i)`，列间距 `CoreSpacing.lg` ⇒ 盒全是 24 时，除连线外与旧实现逐点相同。
- 连线段：y = 横轴，从盒_i 实际右沿到盒_{i+1} 实际左沿（RTL 自动镜像，P2）。

### 3.6 `.grouped`

无节点列、无连线；`VStack(alignment: .leading, spacing: CoreSpacing.md)` 摆**内容子视图与非行子视图**，节点子视图不放进去
（`node:` 槽照旧静默不生效；行的 body 仍构造节点，只是容器不摆它——**推断**：未摆放的子视图不进渲染树也不进无障碍树，PR 2 以
§9.2 判据兜住）。

### 3.7 纯函数面（`nonisolated static`，双腿可测）

| 函数 | 输入 → 输出 | 防御 |
|---|---|---|
| `nodeBox(reported:)` | 节点报告尺寸 → 盒尺寸 | 非有限 / 负数 → 24 |
| `nodeColumnWidth(boxWidths:)` | 各盒宽 → 列宽 | 空数组 → 24；结果 ≥ 24 且有限 |
| `verticalRowHeight(box:content:isLast:)` | → 行高 | 负数按 0 |
| `alternateRowMetrics(forRowWidth:nodeColumnWidth:)` | 同 §2 | `infinity` / `nan` / 负数（两个参数都防） |
| `horizontalAxis(boxHeights:)` | → 横轴 y 与内容顶 y | 空数组 → 24 |
| `connectorSpan(from:to:)` | 两盒相邻边 → 连线长度 | 结果 ≥ 0 |
| `pairParts(roles:)` | 解析序的角色序列 → 行 / 非行分组 | 孤立 `.node` / `.content` → 非行 |

`TimelineStackLayout` 只做「量子视图 → 调纯函数 → 摆放」，不持有存储状态。

### 3.8 规模与惰性（I-8）

P7 读数（macOS 托管窗口 390×844、`ScrollView` 内、`-O`，两轮取后一轮；「重排」= 改第 0 行文字长度后 `layoutSubtreeIfNeeded` + `display`，
连测 5 次）。⚠️ 探针的 `Layout` 在 `sizeThatFits` 与 `placeSubviews` 里各把全部子视图量一遍，未用 `Layout` 的 cache；是量级参考，不是基准。

| 管线 | n = 300 首次 | n = 300 重排 | n = 1000 首次 | n = 1000 重排 |
|---|---|---|---|---|
| 容器级 `Layout`（I-1 方案） | 80 ms | 16–18 ms | 966 ms | 162–355 ms |
| `VStack` + 逐行 `HStack`（≈ 旧实现） | 114 ms | 7–11 ms | 1496 ms | 73–166 ms |
| `LazyVStack` + 逐行 `HStack` | 21 ms | 0.7–2.4 ms | 97 ms | 0.8–11 ms |

- 首次布局与旧实现同量级（都是全量构建）；**重排约为旧实现的 2 倍**——一行内容变宽会让容器重量全部子视图（列宽可能变）。
  `Text(date, style: .relative)` 每分钟刷新一次，n = 300 下每次约 17 ms，可接受；n = 1000 下 160–355 ms，**会掉帧**。
- ⇒ **R4 改写**：本设计**架构上排斥惰性**，超长时间线（数百行以上、带相对时间）要惰性只能**另起一条管线**：列宽不再跨行推导，
  由调用方显式给出 ⇒ 每行可独立排版 ⇒ 可以放进 `LazyVStack`。
- **留门评估**：给 `Timeline` 预留一个将来加法的 `nodeColumnWidth:` 参数**在签名上可行**（新增默认参数、不破坏现有调用），
  但**本 issue 不加**：它引出第二条管线（惰性 + 显式列宽）与第二套几何判据，而三种参考形态都在几十行量级。登记进「未决」。

## 4. c：阶段维度与真值表

### 4.1 阶段取值（U1 定案：每行 `step` + 容器 `progress`）

`StatusLevel` 这一维**保留且正交**：`status` 决定**色相**，阶段决定**形态**与连线着色；活动流（不传 `progress`）没有阶段，外观与旧实现相同。

**阶段真值表**（`s` = 该行的 `step`，`k` = `inProgress(at:)` 的参数）：

| `progress` | 行阶段（`step == nil` 的行一律 `nil`） | 位置 `P`（§6.2） |
|---|---|---|
| 不传（纯活动流） | `nil`（不读 `step`） | 不适用 |
| `.notStarted` | `upcoming` | 首个带 `step` 的行之前（−1，不着色） |
| `.inProgress(at: k)` | `s < k` → `completed`；`s == k` → `inProgress`；`s > k` → `upcoming` | 见下 |
| `.completed` | `completed` | 末个带 `step` 的行 |

**连线段归属**（段 = 解析序中相邻两个**行**之间，跨过非行子视图）：段着色看它**通向的那一行**——后一行 `completed` 或 `inProgress`
⇒ `.tint`；否则 `dividerDefault`。纯活动流全部 `dividerDefault`（**= 旧实现**）。这与 `Steps` 的连线规则同义
（`Steps.swift` 逐字 `self.progress(for: index) == .done`，段后一侧已完成才着色），也与 reui 的 `has-[+[data-completed]]` 同义（看下一项）。
⚠️ 第 1 版写「逐行显式阶段 ⇒ 连线着色无定义」是错的：「看后一行」这条规则对任意阶段组合都有定义；U1 各选项的差别在单调性，
不在可定义性（§12 U1）。

边界：

- **`k` 不等于任何行的 `step`**（越界或落在空档）：没有进行中行；`s < k` 的全部已完成。`.inProgress(at: 末 step + 1)` 与 `.completed` 渲染相同、作为值不相等。
- **非单调 `step`**（调用方把 `step` 写乱）：逐行按上表各自判，连线按「看后一行」各自着色——画得出来，但语义由调用方负责；
  文档写明「`step` 按声明顺序递增」，不做运行期校验（没有不打断渲染的报错通道）。
- **重复 `step`**：两行同阶段（可能两行同时进行中）——同上，文档声明。
- **部分行无 `step`**：这些行阶段 `nil`、按活动流画；连线仍看后一行（`nil` 视为未到达）。
- **回退**（`k` 变小，或 `.completed` → `.inProgress`）：按同一张表重算；动效上段从远端往回收（§6.2）。不做「回退警示」。
- **纯活动流 ↔ 带阶段** 是两个 init，切换属结构身份变化，不做补间。
- **着色层**：已到达段用 `.tint`（U11 已按证据定案：与 `Steps` 同源、调用方 `.tint(_:)` 可改；按下一行 `status` 着色会让活动流的
  danger / success 混排连线五颜六色，与「阶段决定连线、状态决定色相」的正交分工冲突），底线 `dividerDefault`，宽 `CoreBorderWidth.thin`。

**位置 `P`**：容器从各行 `containerValues` 读到 `(配对序号 j, step, 阶段)`，`P` = 最后一个「已到达」行（`completed` 或 `inProgress`）
的配对序号，没有则 −1。静态时段 `j`（行 `j` → 行 `j+1`）的着色比例 `f_j = clamp(P − j, 0, 1) ∈ {0, 1}`，与上面「看后一行」逐段等价
（单调时；非单调时以逐段规则为准、`P` 只驱动动效）。

### 4.2 默认圆点的形态（色相仍由 `status` 经 `Timeline.nodeColor(for:in:)` 决定，U3）

| 阶段 | 形态 |
|---|---|
| `nil`（活动流） | 实心圆 Ø10（**旧实现原样**） |
| `completed` | 实心圆 Ø10（与活动流逐点相同） |
| `inProgress` | 实心圆 Ø10 + 同色外环（Ø18、线宽 `CoreBorderWidth.thick`、不透明度待视觉评审，草案 0.4）；仍在 24 盒内 |
| `upcoming` | 空心圆 Ø10，线宽 `CoreBorderWidth.thick`，同色 |

- 浅色 `warning` 仍取 `statusAttentionForeground`（`#398` 的对比度修正对三种形态都成立）。
- **进行中是静态强调，不做呼吸 / 脉冲**（§6.5）。
- 自定义 `node:` **不叠加任何阶段画法**：调用方读 `@Environment(\.timelinePhase)` 自行决定（U10）。

### 4.3 `TimelineProgress.phase(forStep:)`

公开纯函数，就是真值表第二列；行的 body 与调用方共用同一实现。

## 5. d：`.horizontal` 补连线与更正传播

### 5.1 几何

见 §3.5；着色规则同 §4.1。旧文档的不画理由（逐字「竖向连线的实现依赖「节点在上、内容在下」的纵向几何，换轴后那套 padding 计算不成立」）
在新几何下不再成立：连线端点来自容器 `Layout` 的盒边。

### 5.2 更正传播（CLAUDE.md《「更正传播」约定》三处落点，均在 PR 1）

| 落点 | 现文（逐字节选） | 处置 |
|---|---|---|
| 源码文档注释 | `Timeline.swift` 逐字 `/// 横向：节点沿水平轴排列，内容在节点下方。` | 补「节点间有连线」 |
| `docs/components/timeline.md` | 逐字「⚠️ `.horizontal` **不画节点间连线**」及用法注释「（无连线，可横向滚动）」 | 删去；按「更正只留一层」写一句「原写不画连线，`#420` 起画」 |
| `docs/component-registry.json` `Timeline.notes` | 逐字「⚠️ 这条是**有意不开** issue 的：横向连线是一个尚无需求驱动的增强，不是缺口；要做时再开，别把它读成待办。」及其前一句 | 改写为一句：原判被 PRD FR-1 d 推翻，`#420` 已画出横向连线 |

同一条 `notes` 里「左侧固定 24pt 节点列」一句随常量改名同步为「左侧节点列（`#420` 起列宽按最宽节点推导、下限逐字
`static let minimumNodeExtent: CGFloat = 24`）+ 右侧内容」，`QuotedEvidenceGuard` 那一条同 PR 换引文。
改完 grep 三处残留：`不画节点间连线`、`无连线`（排除 `.grouped` 合法用法）、`nodeColumnWidth`、`尚无需求驱动`。

## 6. e：动效

### 6.1 两类动效，分开定义

| | **阶段推进** | **节点入场** |
|---|---|---|
| 触发 | `progress` 值变化 | 该行节点在 `Timeline` **挂载之后**第一次滚入可见区域（挂载时已可见的行不播，U17） |
| 作用对象 | 连线着色比例 + 默认圆点形态 | 节点（默认与自定义都作用） |
| token | `CoreMotionToken.reveal` | `CoreMotionToken.reveal` |
| 与视口的关系 | 无关：屏外照常推进 | 就是视口事件 |
| 重播 | 每次 `progress` 变化都播 | 不重播（U4） |

### 6.2 阶段推进

- 容器把 §4.1 的 `P` 作为可动画标量交给每段连线（容器构造的普通视图，`Animatable`）；每段画「底线 + 从起点长到 `f_j` 的着色层」。
  `P` 由旧值补间到新值时段按序依次被填满——**一次补间、总时长 = `reveal` 的 0.25s，与跨越段数无关**。回退时 `P` 变小，从远端往回收。
- **圆点形态与连线同步**（S-6）：第 1 版让圆点走独立的 `.coreAnimation(.reveal, value: phase)`，与连线生长是两条动画、各自计时——
  跨多段推进时圆点在 0.25s 内一起变、连线却按段依次填满，二者不同步。改为**同一个 `P` 驱动**：`P` 以统一环境值在**解析前**下发
  （P5 通路），行的默认圆点是 `Animatable` 视图、从 `P` 与本行配对序号算「到达比例」`r = clamp(P − j + 1, 0, 1)` 与「完成比例」
  `c = clamp(P − j, 0, 1)`，据此在空心 / 外环 / 实心之间插值。⚠️ 行不知道自己的配对序号 `j`（容器解析后才知道）⇒ `P` 改在
  **`step` 空间**表达：`P_step` 从旧 `k` 补间到新 `k`，行用自己的 `step` 算 `r = clamp(P_step − s + 1, 0, 1)`；容器按「看后一行」（§4.1）
  把 `P_step` 换算成每段比例：段 `j`（行 `j` → 行 `j+1`）的系数 `f_j = clamp(P_step − s_{j+1} + 1, 0, 1)`，只取**后一行**的 `step`。
  **`step == nil` 行的相邻段**：后一行 `step == nil` ⇒ `f_j ≡ 0`（`nil` 视为未到达，不随 `P_step` 插值，推进时整段保持底线色）；
  前一行 `step == nil`、后一行有 `step` ⇒ 照上式按后一行算，前一行的 `nil` 不参与。`step == nil` 的行自身没有阶段、圆点不插值。
  `P_step` 的端点：`.notStarted` 取「最小 `step` − 1」，`.inProgress(at: k)` 取 `k`，`.completed` 取「最大 `step` + 1」（与 `.inProgress(at: 末 step + 1)` 同图，§4.1；末行的完成比例 `c` 才能到 1）；全部行 `step == nil` 时
  不产生 `P_step`（等同纯活动流）。**推断**：解析前下发的环境值在动画事务里变化时，行内 `Animatable` 视图的 `animatableData`
  会被插值——PR 4 第一个 commit 先以在飞帧探针核实，核不过则圆点退回独立插值、在文档登记不同步。
- 首次出现时不播：初始渲染直接是终态。

### 6.3 节点入场（「进入视口才播」）

候选比较：

| 方案 | 行为 | 结论 |
|---|---|---|
| `.scrollTransition` | 官方文档：「as this view appears and disappears within the visible region of the containing scroll view」——双向、每次滚入滚出都作用；`axis: nil` 时取「innermost containing scroll view」 | 否决：滚出时节点缩回读作「未到达」；每次重播；横向布局自带内层 `ScrollView` ⇒ 页面纵向滚动驱动不了它（推断） |
| `.onAppear` | `VStack` 内全部行挂载时一起触发 | 否决：屏外的行在被看到之前就播完了 |
| **`onScrollVisibilityChange` + 一次性闩锁** | 首次回调 `true` 时置闩、播一次 | **采用** |

采用方案的行为（U17 定案：**只在挂载后滚入视口才播**；P4 给出回调时序）：

- 无 `ScrollView` 宿主：挂载即回调 `true`（P4）⇒ 该回调落在挂载窗口内 ⇒ **不播**，节点直接是终态。
- 在 `ScrollView` 内：首帧可见的行（P4：首帧只对它们回调 `true`）**不播**；屏外行在挂载后第一次被滚入时播。
- 嵌套滚动：以「真的出现在屏幕上」为准（P4：外层滚入前内层项一直是 `false`）⇒ 挂载时整块在外层屏外的行，外层滚入时播。
- 区分「挂载时可见」与「挂载后滚入」：`Timeline` 在自身 `onAppear` 起开一个**挂载窗口**（容器 `@State`，下一轮 runloop 关闭），
  经解析前环境值下发；行的节点第一次收到可见性 `true` 时若窗口仍开 ⇒ 闩锁置为「已结算、不播」，否则 ⇒ 同步置 trigger 并置闩。
  **推断**：挂载时可见行的首次回调落在窗口关闭之前（含 `ImageRenderer` 的单次渲染）——PR 4 前置实验 E4-0 先核实，核不过停下回 spec。
  代价：`Timeline` 自身在惰性容器（`LazyVStack` 等）里随滚动被创建时，这一刻就是它的挂载 ⇒ 当时可见的行不播。
- 再次滚入不重播：闩锁是节点视图的 `@State`；身份丢失时会重播（惰性容器回收、`ForEach` id 变、`.id(_:)`），写进文档。
- 阈值 `0.5`；多行同时可见时同时播，不做错峰。

**入场首帧与「静止值」（S-7，P8 读数）**：

| 触发方式 | 托管窗口首帧 | `ImageRenderer` 静态渲染 |
|---|---|---|
| 回调里**同步**置 trigger（`keyframeAnimator(initialValue: 1)`，首个关键帧 `MoveKeyframe(0.86)`） | 已是缩小态，**无闪帧**（挂载 / 滚入各 3/3） | **缩小态**（20pt 节点量得 17pt）——无滚动宿主时挂载即回调，`ImageRenderer` 那一次渲染就取到了动画第 0 帧 |
| 回调里**推迟到下一轮 runloop** 置 trigger | **闪一帧**：首帧 20pt（终态）、次帧起 16pt（3/3） | 20pt（终态） |

P8 的两种写法各破一个性质：同步触发下，**挂载即触发**的节点会被 `ImageRenderer` 画成缩小态；推迟触发则滚入时闪一帧终态。
U17 让挂载时可见的行根本不触发，冲突随之消失。定案：

1. **同步触发**（滚入时不闪帧，P8 滚入 3/3）；只有挂载后滚入的行会走到这一步。
2. 入场**只在 `coreMotionPresentation == .animated` 时触发**（`.resting` / `.hidden` 不播，§6.4）。
3. **`ImageRenderer` 不再画出缩小态**：它的单次渲染里节点处于挂载窗口内，不触发 ⇒ 任何呈现下的静态渲染都是终态。
   P8 里 17pt 那一格读的是「挂载即播」的旧行为，U17 之后不再适用；§9.5「静止帧」判据改为断言 `.animated` 下 `ImageRenderer` 也 = 终态。
4. 对调用方：导出图片**无需**注入任何呈现覆盖（U14 定案不新增 API，U17 之后也无须提示调用方注入）。本仓的位图判据、`Legacy420*`
   闸门与 `ImageRenderer` 夹具仍一律写 `.environment(\.coreMotionPresentationOverride, .resting)`——它是 `EnvironmentValues` 属性、
   没有同名 View modifier（`CoreMotionToken.swift` 逐字 `/// 供预览与测试固定一种呈现；产品代码通常不写它。`）——用途是把判据钉在
   与系统 RM 设置无关的一种呈现上，不再是「拿到终态」的前提。

⚠️ P8 的采样器是 `cacheDisplay`，它强制一次同步渲染；「真实屏幕合成帧」与它是否逐帧一致**未测**（R2）。iOS 未测（R3）。

### 6.4 Reduce Motion 降级（两类分开）

| 呈现（`coreMotionPresentation`） | 阶段推进 | 节点入场 |
|---|---|---|
| `.animated` | 连线沿线生长 + 圆点形态插值（同一 `P`，`reveal`） | 缩放 0.86 → 1 + 淡入 |
| `.resting`（系统 RM 开） | **连线不生长**：新到达的段整段以 `easeInOut(0.25)` 淡入着色、退回的段淡出；圆点形态照旧插值（纯颜色 / 不透明度） | 不播（U5） |
| `.hidden`（只来自注入覆盖） | 直接到终态 | 不播 |

**两条动画通路**（S-5）：`.animated` 下着色层的**长度**随 `P` 插值（`Animatable` 形状，通路 A）；`.resting` 下长度不插值、段内着色层的
**不透明度**在 0 / 1 间淡变（通路 B，取 `reveal.animation(for: .resting)`，即 `easeInOut`）。二者由同一个 `coreMotionPresentation`
分支选择，同一次 `progress` 变化**只走其一**。

### 6.5 能耗闸：不适用

`EnergyState` 管的是常驻渲染层（`CoreMotionToken.swift` 逐字「只看 Reduce Motion，不看能耗——能耗闸只管常驻渲染层（`EnergyState`）。」）。
本组件两类动效都是一次性过渡 ⇒ 不接 `EnergyState`。「进行中」不做脉冲的理由之一即在此。

### 6.6 纪律台账（S-5）

- `CoreMotionTokenDisciplineGuard.ledger` 登记 `"Components/Timeline/Timeline.swift": .gated`（动画调用点落在
  `TimelineStackLayout.swift` 时该文件同样登记）。
- 通路 B 的 `withAnimation(CoreMotionToken.reveal.animation(for: presentation))` 调用点在 `.gated` 覆盖范围内，**单列**一条说明
  「`.resting` 分支只动不透明度」，便于评审对照 §6.4。
- `transformLedger` 登记入场缩放调用点（理由：「只在 `.animated` 下、挂载后滚入时触发；`.resting` / `.hidden` 不触发」）。
- ⚠️ 该守卫**不覆盖** `Shape` 的 `animatableData` 与 `keyframeAnimator` 闭包（其文档注释已列为已知不覆盖）⇒ 通路 A 与入场缩放的
  RM 分支**只能**由 §9.5 在飞帧判据兜。

## 7. f：无障碍不回退，且状态播报在行上

PRD FR-1 f 逐字「装饰元素不进无障碍树，但状态要播报在行上」。

### 7.1 基线（P9，`f0f03c2` 画廊，iOS 26.4）

- `.vertical`：每行两个元素——节点 `GenericElement label='Info'`（10×10）与内容 `StaticText label='已创建'`，**状态在节点元素上、与标题分离**。
- `.alternate`：内容在左的行，读序为内容先于节点（`再一条` 在 `Warning` 之前）——R6 在旧实现上已成立。
- `.horizontal`：**五个节点元素全部排在五条内容之前**（`Info, Success, Warning, Error, Neutral, 已创建, 审核通过, …`）——
  按几何行序读，状态与行完全脱钩。
- `.grouped`：`StaticText label='已创建' value='Info'`——状态在行上（合并后的内容元素）。

⇒ 旧实现在 `.vertical` / `.alternate` / `.horizontal` 下本来就**不满足**「播报在行上」（状态是一个独立的 10×10 元素）。
「不回退」的比较基准是「状态可被读到」，新设计在此之上补足「在行上」。

### 7.2 候选读数（P10，三行：Created / Deployed（内含 `Retry` 按钮）/ Archived，`Success, In Progress` 为第 2 行）

| 候选 | 读数 | 满足 f？ |
|---|---|---|
| 第 1 版：状态 + 阶段挂节点元素 | `GenericElement label='Success' value='In Progress'` + `Heading 'Deployed'` + … | 否：状态在独立元素上（与基线同病） |
| (a) 节点隐藏，值挂内容子视图（不成元素） | 值被**复制到每个子元素**：`Heading 'Deployed' value='Success, In Progress'`、`StaticText '2h ago'` 同值、`Button 'Retry'` 同值 | 形式上是，但冗余（同一状态读三遍） |
| (a2) 节点隐藏，内容 `.accessibilityElement(children: .combine)` + 值 | 一行一个元素：`label='Deployed, 2h ago' value='Success, In Progress'`；`Retry` 变成该元素的 `custom_actions: ['Retry']`；`--point` 命中行内任一处都落到这个元素 | **是**；代价：内容里的可交互元素不再能单独聚焦（改走「操作」转子） |
| (a4) 节点隐藏，值挂**标题**元素（结构件 init 自己构造标题） | `Heading 'Deployed' value='Success, In Progress'`；`2h ago`、`Retry` 仍是独立元素（`--point` 各自命中、无值） | **是**（行首元素即标题）；只对有 `title` 的行可用 |
| (a3) 内容 `.accessibilityElement(children: .contain)` + 值 | 值挂在一个 `Group` 上；`--point` 命中的是子元素、**不带值** ⇒ VoiceOver 读不到状态 | 否 |
| (b) 容器 `.accessibilityChildren { 子视图代理 + combine + 值 }` | 标签与值正确，但**帧全错**：行元素落在 x=172 / 16 / 169，`Retry` 的帧 370×625 | 否：聚焦框与命中测试错位 |
| (c) 真实父视图 `HStack { 节点; 内容 }.accessibilityElement(children: .combine)` | 与 (a2) 读数相同，帧覆盖节点 | 是，但要逐行父视图 ⇒ 放弃单遍 `Layout`（§3.1 否决项） |

(a2)、(a4) 在**两种模型**下读数相同（P10 `Oa2` / `Na2` 逐字一致）——无障碍方案不决定 U1。但原方案下调用方 `.accessibilityHidden(true)`
隐藏一行时，容器画的节点元素仍可命中（§0 P6 表）——I-1 方案下行的全部元素一起消失。

### 7.3 定案（含 U8）

- **默认圆点一律 `.accessibilityHidden(true)`**（装饰）；连线 `.accessibilityHidden(true)`。
- **状态键**（`Timeline.accessibilityLabelKey(for:)`：`Info` / `Success` / `Warning` / `Error` / `Neutral`）与**阶段键**
  （`Completed` / `In Progress` / `Upcoming`，进 `en.lproj/Localizable.strings`、`bundle: .module`）以「, 」连接成一个 `accessibilityValue`。
  活动流只有状态键。自定义节点的行按 **U18 定案**：init 传了 `status` ⇒ 带状态键（挂载点同下）；不传 ⇒ 不带状态键（与旧实现
  「自定义节点不播报」一致）；带阶段时两种情况都带阶段键。
- 值挂在哪里按 **U8 定案**：有 `title` 的行挂**标题元素**（a4，结构件 init 自己构造标题、行内其它元素保持独立可聚焦）；
  无 `title` 的纯富内容行挂**合并后的内容元素**（a2，内容 `.accessibilityElement(children: .combine)` + 值）；默认圆点隐藏。
- **自定义节点**不隐藏、不改写：它是调用方的内容（头像的名字、图标的 label 由调用方决定），调用方要它不进树就自己施 `.accessibilityHidden`。
  传了 `status` 的自定义节点行，节点里自带 label 的图标会与状态键重复，文档引导调用方隐藏图标（U18）。
- **`.grouped` 与其它布局同一规则**（二选一定案：有 `title` 的行**改为 a4**，不保持 a2）：挂载点只由「有无 `title`」决定、与布局无关，
  挂载点纯函数少一维；a4 保住行内按钮独立可聚焦。无 `title` 的行仍是 a2，与基线（`value='Info'` 挂在合并后的内容元素上）同形。
  代价：`.grouped` 有标题行的内容不再合并成一个元素（时间、描述各自可聚焦），登记 BREAKING（PR 2）。
- **`.horizontal` 的读序**（R6 的横向版本）：a4 下各列元素独立，按几何读序可能先读完同一 y 上的各列标题、再读各列时间——状态随标题、
  仍「在行上」，但列内阅读被打散。PR 2 前置实验 E2-4 在 iOS 用 `axe describe-ui --point` 逐元素命中对比「a4」与「a4 + 内容子视图
  `.accessibilityElement(children: .contain)`」的读序；定案规则：a4 单独即按列读 ⇒ 不加；否则 `.horizontal` 下给内容子视图加 `.contain`
  （值仍挂在标题元素上，不挂在 `.contain` 的 `Group` 上——那是 P10 (a3) 读不到值的形态）。
- 结构件标题 `.isHeader`（新能力，VoiceOver 转子可按条目跳转）。
- R1（`.grouped` 的值施在 `Subview` 代理外层是否进树）由 P10 `Oa` / `Oa2` 解决：施在 `Subview` 上的 `accessibilityValue` / `combine`
  **进树**。
- R6：`.alternate` 读序按几何（基线已如此）；在 (a4) / (a2) 下读序变化不影响「状态随行」，只影响行内元素先后，登记不处置。
- 纯函数：`(status?, 有无自定义节点, phase, 有无 title)` → `(值键序列, 挂载点)`，覆盖上表每一行（§9.3）。PR 2 建立它（状态键与挂载点），
  PR 3 **扩展同一个函数**加阶段键，不另建。

## 8. 迁移面清单

### 8.1 调用点（grep 口径与计数，`f0f03c2`）

口径：`grep -cE '(^|[^A-Za-z])Timeline\('`（排除 `TimelineView(` 与 Effects 里 `AnimatedMeshTimeline(` / `OrbitingLogosTimeline(` /
`SphereSurfaceTimeline(` 这类前缀；**不按** `Timeline(items:` 匹配——会漏换行写法）；`TimelineItem(` 用
`grep -oE '(^|[^A-Za-z])TimelineItem\(' | wc -l`。

| 文件 | `Timeline(` | `TimelineItem(` | 备注 |
|---|---|---|---|
| `App/Sources/ComponentData.swift` | 4 | 8 | 含换行写法 1 处；`private static var items: [TimelineItem]` 改成 `@ViewBuilder` 属性 |
| `App/Sources/Previews.swift` | 5 | 9 | 含换行写法 1 处；共享 fixture `PreviewSnapshotFixtures.timelineItems`（逐字 `static var timelineItems: [TimelineItem] {`，被 3 处引用）改为 `@ViewBuilder static var timelineRows: some View` |
| `scripts/downstream-probe/Sources/DownstreamProbe/PublicVisibility.swift` | 1 | 2 | `consumeTimeline()` 改写：覆盖 4 个 init、`step:`、`progress:`、`phase(forStep:)`、`timelinePhase` 读取；该 job 带 `-warnings-as-errors` |
| `Tests/OhMyDesignTests/TimelineTests.swift` | 11 | 19 | 结构断言（`timeline.items`、`item.node`、`isLastItem`）随类型消失重写；`#398` 的 `LegacyTimeline` 改依赖测试内旧类型拷贝；**保留**「按 asset 名断言」那一族（CLAUDE.md 的免疫机制第 1 类点名了 `TimelineTests`） |
| `Tests/OhMyDesignTests/DynamicTypeLayoutTests.swift` | 1 | 2 | `#if os(iOS)`，只在 iOS 腿跑 |
| `Sources/OhMyDesign/Components/Timeline/Timeline.swift` | 7 | 13 | 本体 + `#Preview` 画廊 |

`ComponentJudgeRulesTests.swift` 里的 `public struct TimelineItem {` 是判据自证的合成源码字符串，**字符串不改**；按 U12 定案，
PR 2 在该组的 `// MARK:` 标题里注明它是**合成夹具**、与 registry 里 `TimelineItem` 的真实分类（`prescriptive`，不进 J-2）无关。

**补漏**（S-2 / S-3 / S-4，第 1 版漏列；全仓 `grep -rlE 'TimelineItem|Timeline\(|TimelineLayout|nodeColumnWidth|timelineItems'` 逐个过）：

| 落点 | 处置 | PR |
|---|---|---|
| `docs/README.md` 组件索引 `Timeline` 行（指向 `snapshots/…_Timeline.png` 与 `components/timeline.md`） | 行本身不改；新条目 `TimelineItem` 挂到这一行的映射**写在** `Tests/OhMyDesignTests/ComponentRegistryGuard.swift` 的硬编码字典 `readmeRowCoverage` 里（照 `"SettingsRow"` → `["SettingsRow", "SettingsRowChevron"]` 先例加 `"Timeline"` 一项，附 reason），不改 README | 2 |
| `docs/snapshots/OhMyDesignPreview_Previews.swift_Timeline{,_Layouts,_Alternate_Widths}.{png,json}` 三组 | 重生成；新 `#Preview` 各新增一组 | 1–3 |
| `Sources/OhMyDesign/Resources/en.lproj/Localizable.strings` | 新增 `Completed` / `In Progress` / `Upcoming` 三键；`AccessibilityStringLiteralGuard` 要求 a11y 文案走键（不新增 `docs/a11y-exemptions.json` 豁免） | 3 |
| `AGENTS.md` / `CLAUDE.md` 里点名 `TimelineTests` 的免疫机制第 1 类（「断言的是 asset 名」） | 不改；PR 2 重写 `TimelineTests` 时须保留该族断言，否则这两处散文失真（无机器判据，人工复核） | 2 |
| `docs/component-contract.md` / `docs/contract-defects.md` 以 `TimelineItem` 的 `node:` 为例的段落 | 引文不变；PR 2 合入前 grep 复核上下文仍为真；按 U12 定案，公约 D1 行（范例列逐字 `@ViewBuilder node: () -> Node,`）加注一句：它是 D1 的**形状**范例，`TimelineItem` 自身登记为 `prescriptive` / `tiebreaker`、不进 J-2 定义域 | 2 |
| `Sources/OhMyDesign/Components/Timeline/Timeline.swift` 两处过时文档注释 | `node:` 参数的尺寸约束段（逐字「**尺寸约束**：节点方框固定 24×24pt（`Timeline.nodeColumnWidth`）且**不裁剪**——」起那一段）与 `.vertical` 的「左侧固定节点列」（逐字 `/// 默认：左侧固定节点列 + 右侧内容，节点间竖向连线（现状形态）。`）改为自适应列宽的说法 | 1 |
| `App/Sources/Previews.swift` 对 `TimelineAlternateRowLayout` 的注释（逐字「由 `TimelineAlternateRowLayout` **无存储状态**这一结构事实保证」） | 类型并进 `TimelineStackLayout` 后改指新类型（同样无存储状态） | 1 |
| `docs/component-contract-revisions.md`、`docs/issues/337-census.md` | 史料，不改 | —— |
| `docs/reachable-type-registry.json` | 不涉及：它登记带文本参数的非组件可达类型；`TimelineProgress` / `TimelinePhase` 无文本参数（**推断**：PR 3 跑 `ReachableTypeRegistryGuard` 兜住） | —— |
| `CoreMotionTokenDisciplineGuard` 台账 | §6.6 | 4 |

### 8.2 文档与判据

| 落点 | 处置 | PR |
|---|---|---|
| `QuotedEvidenceGuard` 的 5 条（`grep -c 'Components/Timeline/Timeline.swift'` = 5） | `@ViewBuilder node: () -> Node,` ×2、`private var nodeContent: some View` ×2 保持；`static let nodeColumnWidth: CGFloat = 24` ×1 换成 `static let minimumNodeExtent: CGFloat = 24`，registry 引文同步 | 1 |
| `ComponentTextParamGuard` | `Tests/OhMyDesignTests/ComponentTextParamGuard.swift` 逐字 `#expect(result.localizedByType.count == 21,` → **23**：新增 `TimelineItem.init#title` 与 `TimelineItem.init#description`（③④ 两个 init 命中同一个键只算一条，`ComponentJudgeRulesTests.swift` 逐字「两个重载命中同一个键只算一条」）；同句注记追加「`#420` TimelineItem 的 title / description 使 21 变为 23」。`time: Text?` 判 `.notText`，不进任何桶。U13 定案不加 `StringProtocol` 重载 ⇒ `TimelineItem` 条目 `textParams: []` | 2 |
| `docs/component-registry.json` `Timeline` | `notes`：§5.2 两处（PR 1）；逐字「TimelineItem.content/node 均为 @ViewBuilder，无固定 String 文本参数。」在 PR 2 后失真（`title` / `description` 是 `LocalizedStringKey`）⇒ PR 2 改写；追加 `#420` 段：组合式 API、阶段正交、`node:` 是 D1 形状但 `TimelineItem` 登记为 prescriptive（PR 2 / 3）。`styleEnum` 仍 `TimelineLayout` | 1–3 |
| registry 新条目 `TimelineItem` | 它成为公开 `View` ⇒ `registryCoversOhMyDesignTypes` 要求登记；`ComponentRegistryGuard.swift` 逐字 `#expect(entries.filter { $0.repo == "ohmydesign" }.count == 58,` → 59；README 映射改 `ComponentRegistryGuard.swift` 的 `readmeRowCoverage`（§8.1）。按 U12 定案：`kind: prescriptive`、`decidedBy: tiebreaker`、`needsExtensionPoint: false`，J-2 仍 16（§8.4） | 2 |
| `docs/components/timeline.md` | 重写 API / 用法 / 布局 / 视觉 token / 无障碍 / 规模（§3.8）/ 逐子视图语义表与可点击行写法（§1.3）/ 被包裹行的降级（§1.5）/ 入场只在挂载后滚入时播（§6.3）；删 `Timeline.applyGroupedStatusValue(_:item:)` 这个不存在的函数名 | 1–4 |
| `docs/BREAKING-CHANGES.md` | 新增「未发布（相对 `v0.11.0`）——Issue #420」一节，逐 PR 追加；PR 2 写入 §1.3 的逐子视图语义表、整行包 `Button` 的降级（U16）、写了 `status:` 的自定义节点行新增状态播报（U18）、`.grouped` 有标题行改 a4（§7.3） | 1–4 |
| `docs/design-digest.md` | `scripts/design-digest.py` 重生成；`FLOORS` 按实际增量改并注 `#420` | 2 / 3 |
| PRD FR-1 | PR 2 合入时在 FR-1 注明命名、阶段取值（U1 定案：每行 `step` + 容器 `progress`） | 2 |
| 历史 plan / spec | 史料，不改 | —— |

### 8.3 像素不变的射程

**有意保留**（对照原样拷贝的旧实现，§9.1 闸门；一律在 `.resting` 呈现下渲染，§6.3）：

- `.vertical` / `.alternate` / `.grouped`，纯活动流，节点 ≤ 24×24，内容高 ≥ 16pt；
- `.horizontal` 同上条件下，连线像素以外逐点相同；
- 带阶段时 `completed` 行的默认圆点与活动流逐点相同。

**有意改变**（另立新基线、登记 BREAKING）：`.horizontal` 连线；大于 24pt 的节点的列宽 / 行高 / 连线端点；内容高 < 16pt 的非末行多出
`min(8, 16 − 内容高)`（0–8pt）；`.alternate` 中按槽宽排版后仍宽于槽的固定宽内容改为向外溢出（§3.4；文字换行不变）；`content:` 里并列的多个视图
统一竖排、左对齐、无间距（§1.3 单一容器，PR 1 起生效；旧实现按布局不同：`.vertical` 并排、`.horizontal` 竖排隔 sm 逐个居中、`.alternate` 整行不显示）；
空节点（`node:` 闭包什么都不产出）保留 24pt 空盒、该行连线在空盒处断开 24pt（有意定案），多视图节点叠在同一个盒里（旧实现：`.vertical` 前者整格消失、
内容左移，后者拆成并排的多个 24pt 格；`.horizontal` 多视图节点竖直堆叠；`.alternate` 两者都整行不显示——都是旧实现的缺陷，闸门里以「旧实现 + 24pt 空盒 / + `ZStack`」为对照）；
`.horizontal` 多视图内容的新外观目前无判据（`multiViewContentStacks` 只测 `.vertical`）；
带阶段的全部新外观；节点入场动效；`.alternate` 中非行子视图处连线截断（旧实现没有非行子视图这回事）。

### 8.4 `TimelineItem` 的登记分类：按公约走一遍（I-7 → U12）

`docs/component-contract.md` 把 `TimelineItem` 的 `node:` 当 D1 外观槽范例（D1 行的范例列逐字 `@ViewBuilder node: () -> Node,`），
判据自证夹具也用这个形状（`ComponentJudgeRulesTests.swift` 逐字 `styleSlot: "TimelineItem.node", needsExtensionPoint: true`）。
`TimelineItem` 第一次成为登记单位，照 §1 判定法走：

1. 弃用条款 / 祖父条款：不命中（未弃用；无已发布的自有样式协议）。
2. 步骤 1（Apple 原生样式协议）：无——没有「时间线条目」对应的系统控件与 `*Style` 协议。
3. 步骤 2（≥2 个非皮肤的业界替代形态；最小基线 Apple HIG / Material / Fluent / Ant Design + 一个最贴近的产品）：
   - Apple HIG、Material Design 3、Fluent 2：**无时间线组件**（查无对应条目）；
   - Ant Design `Timeline.Item`：`dot`（自定义节点）= 同一槽内的画法变化 ⇒ **装饰，不计**；`color` ⇒ 装饰；
     `label`（时间放在轴的另一侧）⇒ 空间关系改变 ⇒ **排布，计 1**；`mode="alternate" / "right"` ⇒ 排布，但由兄弟组件
     `Timeline` 的 `TimelineLayout` 承担（`.alternate` 已在其登记表条目里）⇒ **按作用域条款排除**；
   - 产品：MUI Lab `TimelineOppositeContent`（与 Ant `label` 同一形态，**不另计**）；GitHub PR 时间线「事件行（小图标 + 单行）vs
     评论卡片（头像在轴外 + 带页眉的卡片）」——卡片的边框背景是装饰，页眉条（作者 + 时间）是**增一个槽**，计 1，但它更像
     「行里放了一个卡片组件」而非条目自身的替代形态，**举得犹豫**。
   - ⇒ 站得住的非皮肤候选 1 个、犹豫 1 个 ⇒ **不满足 ≥2**；「长相即含义」的理由也说不清 ⇒ 落**步骤 4 tiebreaker**。
4. 结论（**U12 定案**）：`kind: prescriptive`、`decidedBy: tiebreaker`、`needsExtensionPoint: false` ⇒ **不进 J-2 定义域，仍为 16**。
   `node:` 槽照旧存在并由 `QuotedEvidenceGuard` 的引文登记守着「签名逐字在」，但**不**由 J-2 判它。
5. 未采纳的备选：`kind: semantic`、`decidedBy: step2`、`styleSlot: "TimelineItem.node"`、`needsExtensionPoint: true` ⇒ J-2 定义域 **16 → 17**
   （`ComponentExtensionPointGuard.swift` 逐字 `#expect(result.inspected.count == 16,` 与同句的 16 个组件名清单要改，CLAUDE.md 那条
   「降到 16」的注记同步），公约 D1 范例由散文变成机器可判的实例。代价：步骤 2 须补足第二个站得住的候选（带可核验来源），否则这是
   「通往不可逆结论的路举证最弱」的那种登记（公约步骤 2 自己点名的反模式）。
6. ⚠️ 不可取的第三条路：把 `styleSlot: "TimelineItem.node"` 加在 **`Timeline`** 条目上——`judgeExtensionPoints` 按
   `ComponentJudgeRules.swift` 逐字 `} else if let slot = entry.styleSlot {` 先于 `} else if let styleEnum = entry.styleEnum {` 裁决，
   填了 `styleSlot` 会让 `TimelineLayout` 的 D2 接线检查**静默不再执行**。

## 9. 判据计划

纪律：判据能被变异打红；变异不照判据的形状构造；每次变异先 `git diff` 确认落到了文件里再跑。

**资源色约束**：默认圆点取 `StatusColors`（asset catalog），macOS native 腿上解析为全透明 ⇒ 状态色相关位图判据只在 catalog 已编译的腿上跑
（沿用 `TimelineNodeColorRenderTests` 的 `.enabled(if: assetCatalogIsCompiled, …)`）；macOS 腿的几何 / 形态判据用不走 catalog 的颜色
（`status: .neutral`、自定义节点 `Color.black`、`.tint(.black)`）；取色映射继续用 asset 名断言，双腿都跑。

**呈现约束**（§6.3）：所有 `ImageRenderer` / 托管窗口的**静态**位图判据写 `.environment(\.coreMotionPresentationOverride, .resting)`（钉住呈现，与系统 RM 设置无关）。

**位图容差**：「应相同」用 `expectBitmapsEquivalent(maxChannelDelta: 2)`；「应不同」= 逐通道最大偏差 > 8 **且**差异像素数 ≥ 预期区域面积一半。

### 9.1 几何（PR 1）

| 判据 | 腿 | 形式 |
|---|---|---|
| §3.7 纯函数表逐行 | 双腿 | 纯函数；含 `infinity` / `-infinity` / `nan` / 负数 / 空数组；`alternateSlotWidth` 断言原样保留 |
| 列宽 = 最宽节点 | macOS | `.vertical` 三行，节点 `Color.black` 24×24 / 40×56 / 20×20，内容纯色块；三行内容左缘相等且 = 40 + md |
| 高节点不被穿过 | macOS | 不依赖 `progress`（PR 1 还没有阶段）：第 2 行节点是 40×56 的透明框、只在顶部画 10×10 黑块，连线为 `dividerDefault`；中轴列上 40×56 盒内部（黑块以下）无连线像素、连线首像素 y = 盒下沿（±1） |
| 连线终点 = 下一盒上沿 | macOS | 连线末像素 y = 下一盒上沿 − 1（±1） |

**连线像素的判定法**（`dividerDefault` 是半透明系统分隔色）：白底、`.light`；「连线像素」= 中轴列上与背景**逐通道最大差落在 [d / 2, 2d]** 的像素（上界排除压在中轴上的黑色节点），
`d` 是同一张图里两行之间连线中段（离任何节点都 ≥ 8pt 处）的实测差值。判据先断言 `d ≥ 6`（连线在该背景上可辨），不满足即判红
「无法下结论」，不判绿；首 / 末像素取中轴列上连续连线像素段的两端。
| `.alternate` 中轴一致 | macOS | 各行节点色块水平中心列相同且 = 行宽 / 2（±1） |
| `.horizontal` 横轴与内容顶 | macOS | 盒高 24 / 56 混排：节点中心行相同；内容顶行相同 = 56 + sm；连线在横轴行上 |
| RTL | macOS | `.vertical` RTL 图 = LTR 图水平翻转（≤ 噪声） |
| **旧实现闸门**（`Legacy420*`） | 双腿（iOS 另加五档状态色） | PR 1 父提交的渲染类型原样拷进测试 target、改名；§8.3「有意保留」矩阵 × {light, dark} × {`.vertical`, `.alternate`, `.grouped`} 新旧各渲一张，`expectBitmapsEquivalent(maxChannelDelta: 2)`；`.horizontal` 先遮掉连线带再比 |
| `.horizontal` 确有连线 | macOS | 新旧对照的连线带「应不同」 |
| 容器总高度 | 双腿 | 闸门在 `Timeline` 下方放 2pt 标记，新旧标记行相同（`.horizontal` 同理）；变异「`isLast` 接线错」须红 |
| 空节点 / 多视图节点 | macOS + 闸门 | `node:` 为 `if` 不成立：本行照常成行（盒 24）、内容不落到容器中心；多视图节点叠在同一个盒里居中。闸门两腿对照「旧实现 + 24pt 空盒 / + `ZStack`」；纯函数 `pairRows(parts:)`：缺节点 / 缺内容的行不丢 |
| 多视图内容 | macOS | 两个内容视图左缘相等、第二个顶 = 第一个底；下一行顶 = 两者之和 + lg |
| 内容 < 16pt 的行 | macOS | 内容高 10 ⇒ 下一行顶 = 32 |
| `.alternate` 溢出规则 | macOS | 长文本在左 / 右槽内换行、不越过槽外缘（LTR / RTL）；220pt 色块内缘贴槽内缘、向外越过槽外缘、中轴节点不被盖住；RTL 图 = LTR 图翻转（中轴 1pt 连线列除外） |

**`Legacy420*` 闸门的生命周期（I-5 定案）**：**保留到 PR 4 最后一个 commit 删除**（不在 PR 2 末删除）。理由：§9.3 的
「不传 `progress` 与旧实现同图」、§9.5 的「入场 `initialValue` 写成 0.86 ⇒ 闸门红」两条判据都要它；改用「PR 2 末固化基线位图」要把 PNG
提交进测试资源，跨机器字体 / 渲染差异会让它变成脆性判据，而 `Legacy420*` 是同进程同宿主渲染、天然免疫。代价是拷贝件在测试 target
多驻两个 PR。`#398` 的三条旧圆点对照是另一回事，**保留**，只改它依赖的旧类型拷贝。

补充变异（终审 BLOCK 后）：节点不包单一容器（多视图节点判据与闸门红）；`pairRows` 丢缺件行（纯函数红；与前一条同时施时空节点判据红）；
`.alternate` 内容提议改回 `nil`（溢出规则长文本判据红）；`isLast` 恒 `false`（闸门标记行红）；`.horizontal` 容器高不计内容（闸门标记行红）；
行高改回旧式 `max(24, 内容高 + lg)`（「内容 < 16pt」红）；内容不包单一容器（多视图内容红）。

计划变异：列宽逐行各算（「列宽 = 最宽节点」红）；行高只看内容（「高节点不被穿过」红）；连线起点写回常量 24（「高节点不被穿过」红、闸门仍绿）；
节点提议改 `.unspecified`（闸门红）；`.alternate` 仍调单参数 metrics（「中轴一致」红）；`.horizontal` 内容顶取本列盒高（「内容顶一致」红）；
去掉 `nodeColumnWidth` 的 `nan` 防御（纯函数红）。

### 9.2 API 迁移（PR 2）

| 判据 | 形式 |
|---|---|
| 配对与行序 | `ImageRenderer` 渲染每行内容为不同宽度色块的夹具（含 `ForEach` / `if` / 非行子视图 / 调用方多视图节点闭包 / **多视图内容** / **空内容与 `if false` 内容**）：量内容左缘 / 顶沿顺序；多视图节点仍只占一个节点盒；多视图内容竖排在同一内容格里（左缘相等、顶沿递增、间距 0）；空内容行的节点照常画、后续行不错位 |
| 行上修饰作用于节点 | `.opacity(0.5)` 施在行上：节点色块与内容色块**都**半透（P6 同形）；变异见下 |
| 行被包进 `VStack` | 节点与内容仍出现（降级可见） |
| 解析前通路 | 自定义节点与内容各放一个读内部环境键 `timelineLayoutContext` 的探针，读数画成不同宽度色块：两处都读到传给 `Timeline` 的 `layout`；`Timeline` 外读到默认值（PR 3 在同一通路上加 `timelinePhase`，届时本条扩为「`timelinePhase` 两槽有值」） |
| `.grouped` 不摆节点 | 位图：无节点像素；iOS `axe --point` 在节点位置命中不到任何元素（手工读一次，写 PR 正文） |
| 旧实现闸门 | §9.1 同一矩阵，新 API 写法 |
| J-2 / registry / README / 引文 / 文案 | `ComponentExtensionPointGuard`（仍 16，U12）、`ComponentRegistryGuard`（59）、`QuotedEvidenceGuard`、`ComponentTextParamGuard`（23）、`BoolExemptionGuard` |

**PR 1 已踩过的同一风险**（`Group(subviews:)` 解析后照样会遇到）：节点闭包什么都不产出（`if false`）或产出多个视图时，容器看到的是
0 个或多个节点子视图。PR 2 的配对判据必须含这两个夹具，并断言：零子视图的节点行照常成行（盒取下限 24）、内容不落到容器中心、后续行不错位；
多视图节点只占一个盒。未被放置的子视图会被 `Layout` 默认放在容器中心——判据要查「中心区域没有内容像素」，不能只量已知行。
另两处 PR 1 走不到、PR 2 可能触发的隐患：`pairRows` 对同一行的重复部件「取先到者」会让后到者成为未放置子视图、静默落到中心——PR 2 判据要能把「出现重复部件」
本身判红（debug 下 `assertionFailure` 或查中心区域）；连线按 `rows.rows` 的位置下标取、不是行号，行号有空洞时会错位——PR 2 改由 `step` 配对时要按行号取。

变异：行的 body 不给节点包单一容器（「节点闭包本来就是一个视图」）——预期多视图节点夹具的配对判据红；**内容不包单一容器**（「`content:`
已经是 `@ViewBuilder`」）——预期多视图内容夹具的配对判据红；容器改为对 `Subview` 施 `.environment(\.timelineLayoutContext, …)`（「更 SwiftUI
的写法」）——预期解析前通路判据红（P1b）；改回「容器画节点」——预期「行上修饰作用于节点」红。PR 1 的 §9.1 几何变异在 PR 2 **重跑一遍**
（fixture 改用新 API 写法后，判据仍须被同一批变异打红）。

### 9.3 阶段真值表（PR 3）

| 判据 | 形式 |
|---|---|
| 真值表逐行 | 纯函数：`phase(forStep:)` × {`.notStarted`, `.inProgress(at: -1 / 0 / 2 / 末 / 末+1 / 空档)`, `.completed`} × `step` ∈ {连续、有空档、重复、非单调、部分为 `nil`}；段着色与 `P` 同表 |
| 着色接线 | macOS 位图：`.tint(.black)`、5 行、`.inProgress(at: 2)`：前两段黑、后两段 `dividerDefault`；`.completed` 全黑；不传 `progress` 与 `Legacy420*` 同图 |
| 形态接线 | macOS 位图：`status: .neutral` 三阶段三张图两两「应不同」；`completed` 与活动流「应相同」 |
| `timelinePhase` 两槽有值 | 扩 §9.2「解析前通路」那条：探针改读 `timelinePhase`，两槽都按阶段；`Timeline` 外恒 `nil` |
| 无障碍取值 | 纯函数（扩 PR 2 建立的同一个挂载点函数）：`(status?, 有无自定义节点, phase, 有无 title)` → `(值键序列, 挂载点)`，覆盖 §7.3；iOS `axe describe-ui --point` 手工读一次（整树输出含隐藏元素，不可用来判隐藏；§0），读数写 PR 正文与 `timeline.md`「不在 CI」清单 |

变异：照 reui 写成 `s <= k` 判已完成（进行中行被判成已完成）——真值表红；段着色看行 `j` 而非行 `j+1`——着色接线红；不传 `progress` 时当
`.completed`——闸门红；带阶段时自定义节点行漏了阶段键——无障碍纯函数红。

### 9.4 与 `Steps` 不共用类型

源码判据：`Timeline` 目录下不出现 `StepsProgress` / `StepItem`，`Steps` 目录下不出现 `TimelineProgress` / `TimelinePhase`；
`git diff` 核 `Sources/OhMyDesign/Components/Steps/` 零改动。

### 9.5 动效与 Reduce Motion（PR 4）

在飞帧判据只在 macOS 腿（`CoreMotionTokenInFlightTests` 已登记原因：iOS 的 `layer.render(in:)` 拍不到进行中的帧），承重量取结构量：

| 判据 | 形式 |
|---|---|
| 推进会生长（RM 关） | `HostedWindow`，5 行、`.tint(.black)`，`(at: 0)` → `(at: 3)`：中轴列黑色长度出现 ≥ 2 个不在段边界上的中间值；拍不到按 `observeControlMotion` 的「无法下结论」处理 |
| 推进不生长（RM 开） | 同上 `.resting`：只出现段边界值 |
| 回退从远端收 | `(at: 3)` → `(at: 1)`：中间长度单调不增 |
| 圆点与连线同步 | 同一组帧里，第 `j` 行圆点的形态变化帧 ≥ 第 `j−1` 段填满的帧（§6.2；若 PR 4 首个 commit 的探针证伪 `P` 下发可插值，本条改为登记不同步） |
| 入场按视口触发 | `HostedWindow` + `ScrollView`，第 8 行初始在屏外：滚入时该行节点宽度出现 ≥ 2 个介于 0.86× 与 1× 之间的中间值 |
| 挂载时可见不播 | 同一夹具，第 1 行挂载时已可见：挂载后采样全程中间值个数 = 0 |
| 入场无闪帧 | 同上，滚入后采到的**第一帧**节点宽度 < 1×（P8：同步触发下首帧已是缩小态；推迟触发的变异下首帧为 1×） |
| 不重播 | 滚出再滚回：中间值个数 = 0 |
| 无滚动宿主挂载不播 | 无 `ScrollView`：挂载后采样全程中间值个数 = 0（U17） |
| 入场 RM 不播 | `.resting`：滚入时中间值个数 = 0 |
| 静止帧 | 绝对测量、不依赖 `Legacy420*`：`.resting` 与 `.animated` 两种呈现下 `ImageRenderer` 渲染，默认圆点（`status: .neutral`，非资源色）非背景像素宽 = 10（±1）、20pt `Color.black` 自定义节点黑像素宽 = 20（±1） |
| 源码台账 | `CoreMotionTokenDisciplineGuard` 的 `.gated` 与 `transformLedger` 条目 |

变异：推进用 `.animation(CoreMotionToken.reveal.animation, value: position)`（绕过 `coreMotionPresentation`）——「RM 开不生长」红；入场改挂
`.onAppear`——「按视口触发」红；闩锁放进会被重建的子视图——「不重播」红；trigger 推迟到下一轮 runloop（「避免在回调里改状态」）——
「入场无闪帧」红；闩锁不区分挂载窗口（首个 `true` 一律播）——「挂载时可见不播」「无滚动宿主挂载不播」与「静止帧」`.animated` 一侧红；
入场 `initialValue` 写成 0.86——「静止帧」与闸门红。删除 `Legacy420*` 的 commit **之后**再做一次 0.86 变异，「静止帧」须单独判红
（闸门已不在，它是唯一兜底）。

### 9.6 强制检查（每个 PR）

macOS `swift test`（读 `Test run with N tests` 总数）、iOS `xcodebuild -scheme OhMyDesign-Package`（`.xcresult` 顶层 `passedTests`）、
预览宿主（核 `Debug-iphonesimulator` + `Compiling ComponentData.swift` + `in target 'OhMyDesignPreview'` 步数非 0；P9 构建读数为 61 步）、
`scripts/downstream-probe`、MainActor 棘轮、`design-digest.py`。

## 10. 拆 PR 建议

| PR | 内容 | 公开 API | 承重验证 |
|---|---|---|---|
| **1 几何内核** | `TimelineStackLayout` + §3.7 纯函数；**仍由旧 `[TimelineItem]` 数据喂**（容器构造节点，过渡态）；节点盒自适应、连线端点取实际几何；`.horizontal` 连线；`nodeColumnWidth` → `minimumNodeExtent`；§5.2 更正传播；`Legacy420*` 闸门 | 不变（`TimelineLayout` 加 `nonisolated` 除外） | §9.1；快照重生成 |
| **2 组合式 API 迁移** | `Timeline<Content>` + `Group(subviews:)` + `ContainerValues` 角色配对；`TimelineItem` 变 `View`、**自己画节点**、四个 init、结构件、`step:`；移除旧 init；§8.1 全部调用点；registry 新条目（`prescriptive` / `tiebreaker`，U12）+ 计数；活动流与部署日志两个参考形态；BREAKING；digest | **破坏性** | §9.2；预览宿主、probe、棘轮 |
| **3 阶段** | `TimelineProgress` / `TimelinePhase` / `init(progress:)` / `timelinePhase`；静态形态与连线着色；阶段无障碍（§7.3）；路线图参考形态 | 加法 | §9.3、§9.4 |
| **4 动效** | 推进补间（同一 `P`）、入场闩锁、RM 两条通路、纪律台账；**删除 `Legacy420*`** | 无 | §9.5 |

依赖线性（2 依赖 1 的几何，3 依赖 2 的容器，4 依赖 3 的 `P`）。⚠️ PR 1 的「容器构造节点」是过渡实现，PR 2 改为行构造；几何判据
不依赖谁构造节点，故 PR 1 的判据在 PR 2 **同判据、fixture 改写**（夹具从 `Timeline(items:)` 改成组合式写法，断言不变），并重跑 PR 1 的几何变异。

## 11. 被否决的替代方案

1. **对解析后的 `Subview` 逐个注入环境值**：P1b / P1d 实测进不了 body。（第 1 版把这条等同于「reui Context 的直译」，是误读——reui
   下发的是统一的 `activeStep`，对应 P5 / P6 的解析前通路，见 §1.3。）
2. **容器画节点（第 1 版定案）**：行上修饰碰不到节点、包进 `VStack` 后节点静默消失、隐藏一行留下可聚焦的状态元素（P6 / P10）。
3. **`PreferenceKey` / `onGeometryChange` 求最宽节点**：两遍布局、首帧跳动（§3.1）。
4. **只用 `alignmentGuide` 对齐中轴**：拿不到最宽值（§3.1）。
5. **自定义 result builder、行不是 `View`**：要自己实现 `ForEach` / `if` 的 builder 支持，调用方熟悉的写法全要换。
6. **「进行中」呼吸 / 脉冲**：常驻渲染层，要接 `EnergyState`。
7. **`.scrollTransition` 做入场**：双向、重播、滚出时缩回读作「未到达」（§6.3）。
8. **入场 trigger 推迟到下一轮 runloop**：`ImageRenderer` 干净了，但真实界面闪一帧终态（P8b）。
9. **保留 `Timeline(items:)` 作过渡 shim**：PRD 已定案移除；`[TimelineItem]` 这个类型本身不成立。
10. **行内结构件做成独立子组件视图**：多 3 条 registry、3 个 README 映射（U7 定案理由）。
11. **改名 `TimelineEntry` + `indicator:`**：公约 D1 / 内容槽两个范例要改写、`QuotedEvidenceGuard` 多动 4 条，无语义收益（U2 定案理由）。
12. **无障碍 `.accessibilityChildren` 合成行元素**：帧全错（P10 (b)）。
13. **无障碍 `.contain` + 值**：值挂在不可聚焦的 `Group` 上，读不到（P10 (a3)）。
14. **把 `styleSlot` 登记在 `Timeline` 条目上**：会让 `TimelineLayout` 的 D2 检查静默失效（§8.4 第 6 条）。

## 12. 风险、未决与定案

### 风险

- **R1**（已解决）`.grouped` 与内容子视图上的无障碍值是否进树：P10 实测进树。
- **R2** 入场闪帧的观测器是 `cacheDisplay`（强制同步渲染），与屏幕合成帧是否逐帧一致未测；判据以它为准，真机观感交视觉评审。
- **R3** P4 / P8 只在 macOS 测；iOS 上 `onScrollVisibilityChange` 的首帧行为、嵌套滚动、同步触发是否无闪帧均为推断。
- **R4**（改写）本设计**架构上排斥惰性**：单个容器级 `Layout` 必须拿到全部子视图。n = 300 重排约 17ms、n = 1000 约 160–355ms（§3.8）；
  要惰性需另一条管线（显式列宽 + `LazyVStack`），不在本 issue。
- **R5** 节点入场闩锁是行内节点视图的 `@State`，身份跟随调用方 `ForEach` 的 id / 结构身份（I-1 方案下不再经 `subview.id` 转手）。
- **R6** `.alternate` 下读序按几何（P9 基线已如此）；「状态随行」不受影响。
- **R7** P1b 描述的是当前 SwiftUI 行为；I-1 方案不依赖它。
- **R8** 逐子视图语义：行上的 `.padding` / `.background` / `.onTapGesture` 对节点与内容各施一次（P6）——文档引导布局修饰写进 `content:`。
- **R9** 最短连线 `m` 让「内容高 < 16pt」的旧布局变高，可能被下游快照捕获。
- **R10** P1–P5 未开 `defaultIsolation(MainActor)`；P6–P8 开了，除 `LayoutValueKey` 须 `nonisolated` 外无差异。四个 init 加 `step:`
  后的重载解析仍待 PR 2 第一个 commit 编译验证。
- **R11** 非单调 / 重复 `step` 由调用方负责，不做运行期校验（§4.1）。
- **R12** 同一 `P` 驱动圆点形态依赖「解析前环境值在动画事务里变化会被行内 `Animatable` 插值」（推断，§6.2）。
- **R13** U17 的「挂载窗口」依赖「挂载时可见行的首次可见性回调落在下一轮 runloop 之前」（推断，§6.3），PR 4 E4-0 先核；iOS 上同理未测（并入 R3）。

### 未决（可后续加法）

- `.completed(through:)`：「前 k 行完成、暂无进行中」这一态；现在用 `.inProgress(at:)` 指向空档 `step` 近似。
- 惰性管线（显式 `nodeColumnWidth:` + `LazyVStack`）、错峰入场。
- 连线与节点之间的间隙（现为 0），交视觉评审。

### 已定案（2026-09-24）

「定案方式」列：**用户拍板**＝用户逐条确认推荐项；**用户拍板（批量）**＝用户确认「其余按 spec 推荐定案」，未逐条讨论；
**按证据定案**＝第 2 版已由实测 / 源码读定下，未进拍板。所有拍板项都取了推荐项，正文无需按备选改写。

| # | 问题 | 定案 | 定案方式 | 依据 | 受影响章节 |
|---|---|---|---|---|---|
| **U1** | 阶段取值与渲染管线 | **每行 `step` + 容器 `progress`**（reui 模型；行自己画节点）。未采纳：行序推导（须容器画节点）、逐行显式 `phase:` | 用户拍板 | P6 / P10：行自己画节点才能让行上的 `.transition` / `.redacted` / `.opacity` / `.accessibilityHidden` 同时作用于节点，包进 `VStack` 时节点不再静默消失；行不知道自己的行序（P1b）⇒ 只能用 `step` 或显式 `phase`，`step` 少让调用方自己算阶段。接受的代价：调用方写 `step`；逐子视图修饰语义（R8） | §1、§4.1、§6.2 |
| **U8** | 状态 + 阶段挂在哪 | 有 `title` 挂**标题元素**（a4）；无 `title` 挂**合并后的内容元素**（a2）；默认圆点隐藏 | 用户拍板 | P10：a4 下行内其它元素保持独立可聚焦；a2 把行内按钮变 `custom_actions`；挂节点元素与基线同病（P9） | §7.3、§9.3 |
| **U12** | `TimelineItem` 登记分类 | `prescriptive` / `tiebreaker` / `needsExtensionPoint: false` ⇒ J-2 仍 **16**；公约 D1 范例处加注「形状范例、非 J-2 实例」；`ComponentJudgeRulesTests` 的 `TimelineItem` 夹具注明为合成夹具（均为 PR 2 登记改动） | 用户拍板 | §8.4：步骤 2 只找到 1 个站得住的非皮肤候选 | §8.1、§8.2、§8.4、§9.2 |
| **U13** | 数据驱动标题 | 只给 `LocalizedStringKey`；纯运行期文本走 `content:` + `Text(verbatim:)`。未采纳：`StringProtocol` 重载、`title: Text` | 用户拍板 | 公约 §4：B 类新增用 `LocalizedStringKey`；插值可本地化动词、运行期值原样代入 | §1.2、§1.6、§8.2 |
| **U3** | 未开始 / 进行中的默认圆点 | 色相仍取 `status`；未开始 = 同色空心环；进行中 = 实心 + 同色外环 | 用户拍板（批量） | 保 `status` 与阶段正交；中性灰会让「未开始的 danger」读不出 danger | §4.2 |
| **U4** | 入场重播 | 每个身份只播一次 | 用户拍板（批量） | P4：可见性回调双向；重播读作「刚到达」 | §6.3 |
| **U5** | RM 下的入场 | 完全不播 | 用户拍板（批量） | 入场不承载信息 | §6.4 |
| **U9** | 节点下方最短连线 `m` | `CoreSpacing.sm`（8pt） | 用户拍板（批量） | §3.3 | §3.3、§8.3 |
| **U10** | 阶段对调用方的暴露 | `@Environment(\.timelinePhase)`（`node:` 与 `content:` 两槽都有值）+ 公开 `phase(forStep:)` | 用户拍板（批量） | P6；改 `node:` 闭包签名要动公约 D1 范例与引文 | §1.2、§4.3 |
| **U14** | 调用方能否关入场动效 | 本 issue 不新增 API；随 `coreMotionPresentation` 走；U17 之后导出图片无须注入覆盖 | 用户拍板（批量） | 覆盖键已 `public`；专用 API 可后续加法 | §6.3 |
| **U16** | 可点击行的写法 | `Button` / `NavigationLink` 放进 `content:`；整行包 `Button` 不受支持，文档写清降级样子 | 用户拍板 | 行被包裹即成非行子视图（§1.5）；行上 `.onTapGesture` 挂两次（§1.3） | §1.3、§1.5 |
| **U17** | 入场何时播 | 只在 `Timeline` 挂载后滚入视口才播；挂载时已可见的行（与无滚动宿主时全部行）不播 | 用户拍板 | 消掉 P8「同步触发 ⇒ `ImageRenderer` 画缩小态」的冲突；首屏不必为已在眼前的内容做入场 | §6.1、§6.3、§9.5 |
| **U18** | 自定义节点行的状态播报 | ② / ④ init 的 `status: StatusLevel? = nil`；传了就把状态键挂到行上（调用方自行隐藏图标 label），不传不播 | 用户拍板 | 部署日志类形态的状态要能读到；不传时与旧实现「自定义节点不播报」一致 | §1.2、§7.3、§8.1 |
| U2 | 命名 | 沿用 `TimelineItem` + `node:` | 按证据定案 | §1.2：改名只增成本（公约范例 + 4 条引文），无语义收益 | §1.2 |
| U6 | 非行子视图 | 按内容摆放、无节点、不参与阶段；header / footer 由它承担 | 按证据定案 | §1.5：I-1 方案下「计入行序」一支已无意义 | §1.5 |
| U7 | 行内结构件 | init 参数（标题 → 时间 → 描述 → 富内容） | 按证据定案 | 独立子组件多 3 条 registry / 3 个映射，只承担两个取值 | §1.2 |
| U11 | 已到达连线颜色 | `.tint` | 按证据定案 | 与 `Steps` 同源；按 `status` 着色破坏「阶段管连线、状态管色相」的正交 | §4.1 |
| U15 | 行修饰碰不到节点 | 并入 U1，I-1 方案下已解决 | 按证据定案 | P6 / P10 | §1.3 |
| —— | 命名统一 | `TimelinePhase.upcoming` ↔ 阶段键 `Upcoming`；`TimelineProgress.notStarted` 描述整条时间线，保留 | 按证据定案 | 第 1 版阶段键写 `Not Started`、枚举写 `.upcoming`，二者不一致 | §4、§7.3 |
| I-5 | `Legacy420*` 生命周期 | 保留到 PR 4 最后一个 commit 删除 | 按证据定案 | §9.1 | §9.1、§10 |
