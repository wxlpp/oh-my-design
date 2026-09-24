# Timeline

组合式时间线：容器 `Timeline` + 行 `TimelineItem`。行**自己画节点**（默认圆点或 `node:` 槽），
节点与内容作为两个子视图交给容器排布；容器里不是 `TimelineItem` 的直接子视图（分组标题、页脚等）
是没有节点的**非行子视图** / Composable timeline: a `Timeline` container of `TimelineItem` rows.

节点状态色**直接复用 `StatusLevel`**（`info/success/warning/danger/neutral`），不新增公开状态语义
枚举；连线颜色复用 `Color.dividerDefault`。承接
`.claude/epics/semi-mobile-components/phase0-decisions.md` §1 的架构决定。
`#420` 起为组合式 API（设计见 `docs/superpowers/specs/2026-09-24-timeline-composable-design.md`）；
旧的 `Timeline(items:layout:)` 与数据载体 `TimelineItem` 已移除，迁移见 `docs/BREAKING-CHANGES.md`。

## API

### Timeline

```swift
Timeline(layout: TimelineLayout = .vertical, @ViewBuilder content: () -> Content)                                   // 纯活动流
Timeline(layout: TimelineLayout = .vertical, progress: TimelineProgress, @ViewBuilder content: () -> Content)     // 带阶段
```

`content` 里按声明顺序写行与非行子视图；`ForEach` / `if` 生成的行照常识别。
不传 `progress` 的时间线没有阶段，外观与 `#420` 之前相同（行写了 `step` 也不生效）。

### TimelineItem（四个 init）

| init | 节点 | 结构件 | `status` |
|---|---|---|---|
| ① `TimelineItem(step:status:content:)` | 默认圆点 | 无 | `StatusLevel = .info`：决定圆点色相，恒播报 |
| ② `TimelineItem(step:status:node:content:)` | 自定义 | 无 | `StatusLevel? = nil`：只管无障碍，传了才播报 |
| ③ `TimelineItem(_:time:description:step:status:content:)` | 默认圆点 | 标题 → 时间 → 描述 → 富内容（缺省空） | 同第一行 |
| ④ `TimelineItem(_:time:description:step:status:node:content:)` | 自定义 | 同上（无富内容写 `content: {}`） | 同第二行 |

| 参数 | 类型 | 说明 |
|---|---|---|
| `title` | `LocalizedStringKey` | `.coreFont(.callout)` + `contentPrimary`，标题元素（`.isHeader`）。数据驱动标题用插值（`"\(name) pushed \(n) commits"`）；纯运行期文本（无可本地化部分）不走标题，放进 `content:` 写 `Text(verbatim:)` |
| `time` | `Text?` | 格式化数据，如 `Text(date, style: .relative)`；`.coreFont(.footnote)` + `contentSecondary` |
| `description` | `LocalizedStringKey?` | `.coreFont(.footnote)` + `contentSecondary` |
| `step` | `Int?` | 该行的步骤号：在 `Timeline(progress:)` 内与 `progress` 一起决定本行阶段（见《阶段》）；`nil` 的行没有阶段。按声明顺序递增书写；纯活动流不写 |
| `node` | `@ViewBuilder` | 自定义节点，收到 `24×24pt` 提议，节点盒取报告尺寸、下限 24pt |
| `content`（init ①②，无结构件） | `@ViewBuilder` | 行内容；并列的多个视图竖排、左对齐、间距 0 |
| `content`（init ③④，结构件） | `@ViewBuilder` | 描述下方的富内容；与标题 / 时间 / 描述同在 `VStack(spacing: CoreSpacing.xxs)` 里，并列的多个视图间距 `xxs` |

行身份由 SwiftUI 结构身份 / 调用方 `ForEach` 的 id 决定（不再有 `id:` 参数）。

### 阶段：`TimelineProgress` / `TimelinePhase` / `timelinePhase`

```swift
public nonisolated enum TimelineProgress: Sendable, Hashable {
    case notStarted, inProgress(at: Int), completed
    public func phase(forStep step: Int) -> TimelinePhase
}
public nonisolated enum TimelinePhase: Sendable, Hashable, CaseIterable {
    case completed, inProgress, upcoming
}
extension EnvironmentValues { public internal(set) var timelinePhase: TimelinePhase? }
```

容器在解析子视图**之前**下发 `progress`，每行用**自己的 `step`** 算阶段（与 reui 的「容器下发 `activeStep`、每项自带 `step`」同一模型）；
阶段与行序无关，非行子视图不参与。`phase(forStep:)` 是行与调用方共用的同一个纯函数。

| `progress` | 行阶段（`step == nil` 的行一律 `nil`） |
|---|---|
| 不传 | `nil`（不读 `step`） |
| `.notStarted` | `upcoming` |
| `.inProgress(at: k)` | `step < k` → `completed`；`step == k` → `inProgress`；`step > k` → `upcoming` |
| `.completed` | `completed` |

- `k` 不等于任何行的 `step`（越界或落在空档）时没有进行中的行；`.inProgress(at: 末 step + 1)` 与 `.completed` 画法相同、作为值不相等。
- 非单调 / 重复的 `step` 逐行照表各自判（可能两行同时进行中），语义由调用方负责，不做运行期校验。
- **连线着色看它通向的那一行**：后一行 `completed` 或 `inProgress` ⇒ `.tint`，否则 `dividerDefault`；后一行 `step == nil` 视为未到达。
  `step` 连续时与 `Steps` 的连线规则同义（`Steps` 按行序、这里按 `step`；二者不共用类型）。
  ⚠️ **未设置 `.tint` 时取宿主 App 的 AccentColor**（macOS 为用户在系统设置里选的强调色），不是本库的墨色 `accent`；
  **`.coreAccent(_:)` 改不了连线色**，要统一色调请在 `Timeline` 外层写 `.tint(_:)`。纯活动流（不传 `progress`）的连线全是 `dividerDefault`。
- 段系数与 `phase(forStep:)` 同源、逐个整数判定：后一行阶段不是 `upcoming` ⇒ 1，否则 0（后一行 `step == nil` 或不传 `progress` 恒为 0），
  与上一条逐段等价。连续的推进位置 `P`（`step` 空间，spec §6.2）只在推进动效（`#420` PR 4）里引入。
- **`timelinePhase`**：在 `Timeline(progress:)` 内、带 `step` 的 `TimelineItem` 的 `node:` 与 `content:` **两个槽**里都有值；
  无 `step` 的行、非行子视图、不传 `progress` 的 `Timeline` 与 `Timeline` 外恒为 `nil`。只读（`internal(set)`）。
  嵌套时也成立：`Timeline` 在解析子视图前先把它置空（逐字 `.environment(\.timelinePhase, nil)`），外层行内容里的内层时间线，
  其非行子视图读不到外层行的阶段。
- **状态与阶段正交**，任意组合都画得出：例如 `status: .danger` + `upcoming` 是红色空心圆点，可表达「有风险的未到里程碑」；
  这种组合是否合用、表达什么由调用方决定，组件不禁止也不改色。
- **`.grouped` + `progress:`**：屏幕上**不显示**阶段（不摆节点、不画连线），VoiceOver **仍读出**阶段键（挂载点规则与其它布局相同）。
- **默认圆点形态**（色相仍取 `status`，阶段只管形态）：

  | 阶段 | 形态 |
  |---|---|
  | `nil`（活动流）/ `completed` | 实心圆 Ø10（与 `#420` 之前逐点相同） |
  | `inProgress` | **靶心**：实心圆 Ø10 + 透明间隙 + 同色实线外环（不降不透明度）。外径逐字 `static let inProgressRingDiameter: CGFloat = Self.nodeDiameter + 2 * (Self.inProgressRingGap + CoreBorderWidth.thick)`，间隙 `CoreSpacing.xxs`（2pt），外径 18pt，仍在 24pt 盒内；静态强调，不做脉冲 |
  | `upcoming` | 同色空心圆 Ø10，线宽 `CoreBorderWidth.thick` |

- 外环间隙是**挖空**：外环是描边环，圆点与环之间什么都不画，露出的是 `Timeline` 身后的背景——放在卡片、带色表面上也不会露出一圈
  固定背景色的色块（`TimelineInProgressRingContrastTests` 以红底核间隙像素即底色）。外环与圆点同色同不透明度 ⇒ 对背景的对比度与
  实心圆点同档，读数见《视觉 Token》。
- **自定义节点**不叠加任何阶段画法：调用方读 `@Environment(\.timelinePhase)` 自行决定（例如未开始的图标降低不透明度）。
  在 `#Preview` 里看自定义节点某一阶段的样子，包一层带阶段的时间线即可：
  `Timeline(progress: .inProgress(at: 0)) { TimelineItem(step: 0) { MyNode() } content: {} }`。
- 连线的着色层逐字 `.fill(.tint)`，盖在 `dividerDefault` 底线之上；不传 `progress` 时不画着色层（与 `#420` 之前逐像素相同，
  `TimelineLegacy420GateTests` 以「各行写了 `step`、外层 `.tint(.black)`、不传 `progress`」对照旧实现兜住）。

### `TimelineLayout`（`#60` 形态 D2「配置枚举」）

决定「这组节点怎么**排**」，与 `TimelineItem` 的 `node:` 外观槽（「单个节点画成什么」）**正交**
——槽管单节点画法，够不着容器级排布。

| case | 说明 | 业界来源 |
|---|---|---|
| `.vertical` | 默认：左侧节点列（列宽取最宽节点、下限 24pt）+ 右侧内容，节点间竖向连线 | —— |
| `.alternate` | 左右交替：节点恒在**中轴**，行的内容按行序奇偶在两侧交替（非行子视图不计入奇偶） | Ant Design Timeline `mode="alternate"` |
| `.horizontal` | 横向：节点沿水平轴排列，节点间有连线，内容在节点下方（可横向滚动） | PowerPoint SmartArt Basic Timeline / Final Cut Pro 横向事件线 |
| `.grouped` | 无连线的分组列表：删掉节点列与连线，只留内容 | Apple 邮件 / 信息的日期分组、GitHub 活动流 |

⚠️ **正交性的代价**（有意的静默，传了不生效**不报错**）：`.grouped` 不摆节点子视图 ⇒
`node:` 槽**不生效**（行仍构造节点，容器不摆它；切回其余布局时照常显示）。
`.horizontal` 原写不画节点间连线，`#420` 起画（连线端点取自容器级布局算出的节点盒边沿，不再依赖纵向 padding）。

### 非行子视图与被包裹的行

`Timeline { … }` 里不是 `TimelineItem` 的直接子视图没有节点，header / footer 一律由它承担：

| 布局 | 非行子视图 | 连线 |
|---|---|---|
| `.vertical` | 摆在内容列 | 节点列上的连线**贯穿**（二者不相交） |
| `.alternate` | 跨满整行、居中 | 在它的**上沿截断、下沿续接** |
| `.horizontal` | 自成一列，内容顶与各列对齐 | 横轴连线**贯穿**该列 |
| `.grouped` | 照常 | —— |

**被包裹的行**（把 `TimelineItem` 包进 `VStack` / `Button` / 自定义容器）对容器也是非行子视图，按上表摆放：
行 body 里的节点与内容**都还在**，按包裹容器自己的排法摆（`VStack` 下节点在上、内容在下），节点不在中轴 / 横轴上；
`.grouped` 下它自带的节点**照常显示**（容器认不出被包住的节点）。连线着色跳过它（它不参与行的配对）。

### 施在行上的修饰（逐子视图语义）

行的 body 产出两个子视图（节点、内容），施在行上的修饰对二者**各施一次**——与 `Group { A; B }.padding()` 同一语义：

| 修饰类别 | 例 | 施在行上的效果 | 写法 |
|---|---|---|---|
| **布局** | `.padding` / `.frame` / `.offset` | 节点盒与内容各加一次；节点盒变大会撑宽整列（`.padding(10)` 让节点盒 24→44） | 写进 `content:` |
| **视觉** | `.opacity` / `.background` / `.redacted` / `.transition` / `.accessibilityHidden` | 节点与内容各施一次——整行一起半透 / 打码 / 转场 / 隐藏；`.background` 会铺成两块 | 可施在行上；要整行一块背景请写进 `content:` |
| **行为** | `.onAppear` / `.task` / `.onTapGesture` / `.contextMenu` / `.swipeActions` | **挂两次**：`.onAppear` / `.task` **执行两次**；`.contextMenu` / `.swipeActions` 两个子视图各挂一份；点节点与点内容各触发一次 | **勿施在行上**，写进 `content:`（或施在 `Timeline` 外层） |

**可点击的行**：把 `Button` / `NavigationLink` 放进 `content:`（无结构件时整块内容做按钮 label）。
**整行包 `Button` 不受支持**：`Button { … } label: { TimelineItem(…) }` 对容器是一个被包裹的行——节点与内容竖叠、没有节点列、
连线着色跳过它，且点击区域覆盖节点。

## 预览 / Preview

运行 `scripts/run-snapshots.sh`（默认模式）后，预览图落地 `docs/snapshots/`——但前提是该组件已在 `App/Sources/Previews.swift` 注册（导出文件名形如 `OhMyDesignPreview_<组件名>.png`）；组件源码内自带的 `#Preview` 仅用于开发期本地预览，或经 `KEEP_LIBRARY_SNAPSHOTS=1 scripts/run-snapshots.sh` 导出到本地 scratch 目录做逐组件视觉核对（不写入 docs/snapshots，见 `.claude/epics/semi-mobile-components/phase0-decisions.md` §3）。
`App/Sources/Previews.swift` 另有 `Timeline Activity`（活动流）与 `Timeline Deploy Log`（部署日志）两个参考形态。

## 使用示例 / Usage

```swift
// 默认圆点 + 结构件
Timeline {
    TimelineItem("已创建", time: Text(created, style: .relative), status: .info)
    TimelineItem("审核通过", description: "由审核员 A 通过", status: .success)
    TimelineItem("处理失败", status: .danger) {
        Button("重试") { retry() }          // 可点击的部分放进 content:
    }
}

// 活动流：头像大于 24pt 下限，撑宽节点列；非行子视图当分组标题
Timeline {
    Text("Today").coreFont(.footnote)
    ForEach(events) { e in
        TimelineItem("\(e.actor) pushed \(e.count) commits", time: Text(e.date, style: .relative)) {
            Avatar(name: e.actor, size: .fixed(40))
        } content: {}
    }
    TimelineItem {                          // 纯运行期文本走 content: + Text(verbatim:)
        Text(verbatim: serverSummary).coreFont(.callout)
    }
}

// 部署日志：自定义图标节点 + status（状态随标题播报，图标自身的 label 请隐藏）
Timeline {
    ForEach(deploys) { d in
        TimelineItem("Deployed \(d.version)", time: Text(d.date, format: .dateTime), status: d.ok ? .success : .danger) {
            Image(systemName: d.ok ? "checkmark.circle.fill" : "xmark.octagon.fill")
                .accessibilityHidden(true)
        } content: {
            Text(d.commit).coreFont(.caption).monospaced()
        }
    }
}

// 订单进度：带阶段，每行写 step；自定义节点经 timelinePhase 自行变化
Timeline(progress: .inProgress(at: 2)) {
    TimelineItem("已下单", time: Text(verbatim: "09:00"), step: 0, status: .success)
    TimelineItem("已付款", time: Text(verbatim: "09:02"), step: 1, status: .success)
    TimelineItem("配送中", description: "预计今天送达", step: 2, status: .info)
    TimelineItem("已签收", step: 3, status: .info)
}
.tint(.green)                              // 已到达段的连线颜色；不写则取宿主 App 的 AccentColor

struct PhaseIcon: View {                   // 自定义节点读本行阶段
    @Environment(\.timelinePhase) private var phase
    var body: some View {
        Image(systemName: self.phase == .completed ? "checkmark.circle.fill" : "circle")
            .accessibilityHidden(true)
    }
}

// 其余三种排布
Timeline(layout: .alternate) { rows }
Timeline(layout: .horizontal) { rows }
Timeline(layout: .grouped) { rows }   // node: 槽在此形态下不生效
```

## 布局

`.vertical` / `.alternate` / `.horizontal` 由同一个容器级 `Layout`（`TimelineStackLayout`）单遍排版，
节点、内容、连线都是它的子视图：

- **节点盒**：节点收到 `24×24pt` 的提议（`Circle()` 这类弹性视图因此仍画成 24pt），节点盒取它
  报告的尺寸、下限 `24pt`，节点在盒内居中。≤ 24×24 的节点（默认圆点、SF Symbol、20pt 圆）与旧实现逐点相同；
  更大的节点（如 40pt 头像）不再溢出，而是撑宽整列 / 撑高本行。
- **`.vertical`**：节点列宽取所有节点盒里最宽的那个（跨行统一，内容左缘对齐）；内容从
  `列宽 + CoreSpacing.md` 起。非末行行高 `max(盒高 + CoreSpacing.sm, 内容高 + CoreSpacing.lg)`，末行
  `max(盒高, 内容高)`——内容高 ≥ 16pt 时与旧式 `max(24, 内容高 + lg)` 相同；更矮的内容行多出一小段
  （节点下方至少留 `sm` 的连线）。连线从本行节点盒**实际下沿**画到下一行节点盒**实际上沿**，不穿过高节点。
- **`.alternate`**：`弹性左槽 | 节点列 | 弹性右槽`，节点列宽同上跨行取最大、中轴恒在行宽一半处；
  内容按行序奇偶换边，行高与连线端点同 `.vertical`。两侧内容收到槽宽提议：文字按槽宽换行、落在槽内；
  按槽宽排版后仍宽于槽的固定宽元素内缘贴槽内缘、向外（远离中轴）溢出，不压节点，越出容器的部分会被屏幕 / `ScrollView` 裁掉。
- **`.horizontal`**：外层 `ScrollView(.horizontal)`；横轴在最高节点盒的一半处，所有节点中心落在横轴上，
  内容顶统一在 `最高盒高 + CoreSpacing.sm`；列宽 `max(盒宽, 内容理想宽)`、列间距 `CoreSpacing.lg`；
  连线在横轴上，从前一盒右沿画到后一盒左沿。
- **`.grouped`**：`VStack(spacing: CoreSpacing.md)`，只摆内容子视图与非行子视图，不摆节点子视图、不画连线。
- **配对**：容器按解析顺序把「节点紧跟内容」认作一行；孤立的节点 / 内容子视图（行被拆开时）按非行子视图摆放，
  不会被丢掉或落到容器中心。连线按行的顺序号取，隔着非行子视图照样连到下一行。
- 连线画在节点与内容**之下**（容器先发射连线、再发射行的子视图）：节点溢出盒外、压在中轴上的部分不被连线色覆盖。
- RTL 下整体水平镜像（自定义 `Layout` 自动镜像）。
- 节点与内容在行的 body 里各包一个容器（节点 `ZStack`、内容 `VStack(alignment: .leading, spacing: 0)`）：`node:` 闭包什么都不产出时保留 24pt 空盒（该行上下的连线在空盒处断开 24pt），并列多个视图时叠在同一个盒里居中；
  `content:` 里并列的多个视图竖排；空内容（`content: {}` 或 `if` 不成立）得到 0 高的内容，行照常成对、节点照常绘制。
- 内容**只收到宽度提议、不收到高度提议**（节点固定收到 `24×24` 提议）⇒ 纵向贪婪的内容（裸 `Color`、
  `.frame(maxHeight: .infinity)`）缩到理想高度（裸 `Color` 为 10pt），不会撑满容器；要固定高度请显式写 `.frame(height:)`。

## 规模

容器级 `Layout` **架构上不支持惰性**；量级读数、超长时间线的建议与留门评估见
`docs/superpowers/specs/2026-09-24-timeline-composable-design.md` §3.8「规模与惰性」。

## 视觉 Token

- 节点盒：提议 `24×24pt`，取节点报告尺寸、下限 `24pt`；节点列宽取最宽节点；默认圆点直径 `10pt`
- 默认圆点颜色：`StatusColors` emphasis 档，按 `StatusLevel` 映射——
  `info → statusAccentEmphasis` / `success → statusSuccessEmphasis` /
  `warning → statusAttentionEmphasis` / `danger → statusDangerEmphasis`；
  `neutral` 不取状态色，取 `contentSecondary`
- 例外：**浅色**下 `warning` 取 `statusAttentionForeground`（与浅色 Banner warning 图标同色）——
  `statusAttentionEmphasis` 的浅色金黄对分组背景只有约 2:1，达不到非文本对比度 3:1；
  改后对 `systemGroupedBackground` 4.36:1、`systemBackground` 4.87:1（iOS 解析值）。暗色仍取 emphasis，不变
- 进行中外环（靶心）：外径 18pt = 圆点 10 + 2 ×（间隙 `CoreSpacing.xxs` + 线宽 `CoreBorderWidth.thick`），与圆点同色不降不透明度。
  外环像素对背景的对比度与实心圆点逐项相同（iOS 26.4 模拟器、`TimelineInProgressRingStatusContrastTests` 渲染取像素）：

  | 外观 · 状态 | `systemGroupedBackground` | `systemBackground` | `secondarySystemGroupedBackground` |
  |---|---|---|---|
  | 亮 · `info` | 4.65:1 | 5.19:1 | 5.19:1 |
  | 亮 · `neutral` | 3.29:1 | 3.44:1 | 3.44:1 |
  | 亮 · `warning` | 4.36:1 | 4.87:1 | 4.87:1 |
  | 暗 · `info` | 4.53:1 | 4.53:1 | 3.67:1 |
  | 暗 · `neutral` | 6.36:1 | 6.36:1 | 5.94:1 |
  | 暗 · `warning` | 4.52:1 | 4.52:1 | 3.66:1 |
  ⚠️ `neutral` 亮色在 iOS 上对 3:1 只有 0.29–0.44 的余量：外环对比度判据将来变红时，先查系统色（`secondaryLabel`）是否被 OS 调整，别去改阈值。

  status 资源色在 macOS `swift test` 腿上解析为全透明，这张表只在 iOS 腿上有判据；macOS 腿用 `.neutral`（系统 `secondaryLabel`）核同一条
  「外环 ≥ 3:1 且与圆点同档」，并在红底上核间隙即底色。
- 连线：`Color.dividerDefault`（= 系统 `separator` 色），`CoreBorderWidth.thin`（1pt）宽度——
  竖向长连线用 1pt 比 separator hairline（0.5pt）观感更实，是对 phase0「连线对齐 separator」
  决策的有意偏离（与 Steps 横向连线同源，指示性连线需强于分隔线；phase0/013 统一记录）
- 行间距：内容下方 `CoreSpacing.lg`、节点下方至少 `CoreSpacing.sm`（最后一条不追加）；节点列与 content 横向间距 `CoreSpacing.md`

## Accessibility

- **默认圆点隐藏**（装饰），连线隐藏。**状态播报在行上**：状态键（`Timeline.accessibilityLabelKey(for:)`：
  `info/success/warning/danger/neutral` → `"Info"/"Success"/"Warning"/"Error"/"Neutral"`，`bundle: .module`）
  作为 `accessibilityValue` 挂在——
  - 有标题的行：**标题元素**（`Heading '已创建' value='Info'`）；行内时间、描述、按钮仍各自独立可聚焦；
  - 无标题的行：**合并后的内容元素**（内容 `.accessibilityElement(children: .combine)` + 值）；代价是内容里的按钮
    不再单独聚焦，改走「操作」转子。
  挂载点只由「有无标题」决定，与布局无关（`.grouped` 同一规则）。
- **自定义节点**不隐藏、不改写：头像的名字、图标的 label 由调用方决定，不要它进树请自己 `.accessibilityHidden(true)`。
  自定义节点的 init 传了 `status:` 才播报状态（挂载点同上）；此时节点里自带 label 的图标（`Image(systemName:)` 会读出符号名）
  请隐藏，否则同一状态读两遍。不传则不播报（与 `#420` 前「自定义节点不播报」一致）。
- **阶段键**（带阶段时）：`completed / inProgress / upcoming` → `"Completed"/"In Progress"/"Upcoming"`（`Localizable.strings`，`bundle: .module`），
  以「, 」接在状态键之后并入同一个值（`Heading '已付款' value='Success, Completed'`），挂载点同上。自定义节点行不传 `status` 时
  只带阶段键（此时无标题的内容同样合并成一个带值元素）；`step == nil` 的行不带阶段键。
- 结构件标题带 `.isHeader`，VoiceOver 转子可按条目跳转。
- `.horizontal`：读序**按列**（本列节点 → 标题 → 时间 → 描述，再下一列）。做法两层：
  - 有标题的行、以及未合并的无标题行（自定义节点、不传 `status`）的内容子视图额外 `.accessibilityElement(children: .contain)`；
    值仍挂在标题元素上（`.contain` 的容器本身不承载值——那种挂法 VoiceOver 读不到）；
  - 整条横向时间线是一个 `.contain` 容器，每个子视图带 `accessibilitySortPriority`（纯函数 `TimelineStackLayout.readingPriorities(slots:partCount:)`：
    按槽序递减、行内节点先于内容、非行子视图占一个槽）。不这样做时，未隐藏的自定义节点（头像）在几何上高于所有内容，会排在所有列的内容之前。
    优先级是施在已有子视图上的修饰，不重组子视图，单遍布局不变。
  - `.horizontal` 下直接子视图（`TimelineItem` 或非行子视图）的 `accessibilitySortPriority` 由容器接管：调用方在直接子视图上自设的排序优先级与容器的哪层生效**未验证、不保证**；行内容内部自设的优先级被该行的 `.contain` 限定在本列，不受影响。整条横向的容器级 `.contain` 是否必需也未验证（去掉它只有源码判据红、无 axe 读数），当作保险层保留。
  其余布局不加。
- **默认圆点 + 无标题 + 空内容**（`TimelineItem(status: .danger) {}`）：状态值挂在一个无 label、0×0 的元素上
  （读数见下）；VoiceOver 能否聚焦它未验证。要播报状态请给内容，或改用带标题的 init。
- 值的取法与挂载点是纯函数 `Timeline.accessibility(status:hasCustomNode:hasTitle:phase:)`，由 `TimelineCompositionTests`
  （无阶段）与 `TimelineAccessibilityValueTests`（带阶段）逐格覆盖。

### 接线判据覆盖到哪

- **iOS 腿（进程内无障碍树）**：`UIHostingController` 的 `accessibilityElements` 在托管窗口里读得到 SwiftUI 的无障碍节点，
  **前提是模拟器的「应用无障碍」开关已打开**——干净模拟器（CI）上它是关的，树恒为空（iOS 26.4 新建模拟器实测 0 个元素）；
  `axe describe-ui` 跑过一次就会打开它并持久化到设备（重启不复位、`simctl erase` 才复位），所以跑过 axe 的本地模拟器会假绿。
  判据因此在建树前经 `libAccessibility` 私有符号 `_AXSApplicationAccessibilitySetEnabled` 自行打开，打不开即判红（不跳过）；
  私有符号只在测试 target，随系统版本失效时这两条会红而不是空转。
  `TimelineCompositionTests` 据此核：标题元素的 label / 值 / `.isHeader`、无标题默认圆点行合并成一个带值元素、
  自定义节点不传 `status` 的行不合并也无值、横向语境下内容各成 `.contain` 容器（用 `timelineLayoutContext = .horizontal`
  直接渲染行，不经 `ScrollView`）。`TimelineAccessibilityValueTests` 同一通路核带阶段的值（`Error, Completed` /
  `Success, In Progress`、自定义节点不传 `status` 只带 `Upcoming`、无 `step` 的行无值）。
- **`.horizontal` 的整体读序没有进程内判据**：`ScrollView` 的 `PlatformGroupContainer` 在单测进程里不给出子节点，
  排序优先级只能靠下面的 `axe` 手工读数；机器判据只有纯函数 `readingPriorities` 与源码接线判据。
- **macOS 腿**：`NSHostingView` 只给出根 `AXGroup`（KVC 读 `accessibilityChildren`），读不到子树。两条腿都跑源码接线判据：
  内容槽各分支挂着合并 / 值 / `.contain`，横向容器挂着优先级与 `.contain`，每个辅助修饰落到对应的 SwiftUI 修饰。

### 不在 CI 的手工读数

iOS 26.4 模拟器、画廊 `PREVIEW_COMPONENT_ID=timeline`、`axe describe-ui`（`#420` PR 2 读数；整树输出也列出屏幕外的元素）。⚠️ 整树输出**包含**
`.accessibilityHidden(true)` 的元素，判「隐藏没隐藏」只用 `--point` 命中测试。

- **默认圆点与连线不可命中**：`--point` 落在圆点 / 连线上，命中的是根 `Group`（整屏帧），不是圆点元素。
- **状态值在行上**：`.vertical` 标题行 `Heading 'Deployed 1.4.0' value='Success'`（时间、提交号各自是无值的 `StaticText`）；
  无标题行 `StaticText 'CI summary from server: 3 checks passed' value='Info'`（合并后的内容元素）。
- **`.grouped` 不摆的节点不进树**：`.grouped` 里一行未隐藏的自定义节点 `Image(systemName: "star.fill")`，整树输出里**没有**这个
  图标元素（整树连隐藏元素都列，缺席即不在树里）；在它本该在的位置 `--point` 命中的是该行内容 `StaticText '自定义节点行'`。
- **`.horizontal` 读序**：三列、每列标题 + 时间。只做标题挂值时，整树顺序是三个标题在前、三个时间在后（按几何行读）；
  给内容加 `.contain` 后顺序变为「标题 1、时间 1、标题 2、时间 2 …」，`--point` 命中标题仍带值（`Heading '已创建' value='Info'`）⇒ 采用后者。
- 自定义节点里调用方已 `.accessibilityHidden(true)` 的图标（部署日志）`--point` 不可命中。
- **`.horizontal` 活动流**（画廊里的横向形态：非行标题 `Today`、两行 40pt 头像 + 标题 + 时间、一行无标题默认圆点、
  一行不传 `status` 的无标题头像行 `Kai`）。只给内容加 `.contain`、不加排序优先级时：`Image 'Evan'`、`Image 'Mia'`、`Image 'Kai'`
  排在最前，其后才是 `Today` 与各列内容。加排序优先级后整树为一个分组：`Today` → `Image 'Evan'` → 分组[`Heading 'Evan pushed 3 commits'`、`2h ago`]
  → `Image 'Mia'` → 分组[…] → `StaticText 'CI summary from server: 3 checks passed' value='Info'` → `Image 'Kai'` → 分组[`Kai`、`left a review`]。
  只有标题行的三列横向形态仍按列读（多一层匿名分组），`--point` 命中标题仍带值（`Heading '已创建' value='Info'`）。
- **阶段键**（`#420` PR 3 读数，iOS 26.4 专用模拟器，画廊同上）：订单进度 `.inProgress(at: 2)` 整树依次为
  `Heading '已下单' value='Info, Completed'`、`'已付款' 'Info, Completed'`、`'配送中' 'Info, In Progress'`（描述 `StaticText` 无值）、
  `'已签收' 'Info, Upcoming'`；自定义节点、不传 `status` 的三行只带阶段键：`Heading '打包' value='Completed'`、`'出库' 'In Progress'`、
  `'派送' 'Upcoming'`；横向路线图 `Q1 Alpha` / `Q2 Beta` `'Info, Completed'`、`Q3 GA` `'Info, In Progress'`、`Q4 v2` `'Info, Upcoming'`。
  `--point` 命中 `(75, 841)` 得 `Heading '已下单' 'Info, Completed'`；命中该行已完成圆点 `(28, 842)` 与其下方连线 `(28, 860)` 都落到根 `Group`（整屏帧）
  ——阶段形态的圆点与着色连线同样不进树。
- **默认圆点 + 无标题 + 空内容**：画廊里 `TimelineItem(status: .danger) {}` 在整树里是 `GenericElement`，无 label、`value='Error'`、帧 0×0
  （在屏幕外，未做 `--point`）；下一行 `StaticText 'Next row' value='Success'` 正常。

## 已知缺口

- **阶段键的拼接语序写死**：状态键与阶段键以「, 」硬拼接（状态在前）。将来加入 RTL 或其它语序的语言时，应改用本地化表里既有的
  `"%@, %@"` 格式键，让译文决定顺序与分隔符。本 PR 不改。
