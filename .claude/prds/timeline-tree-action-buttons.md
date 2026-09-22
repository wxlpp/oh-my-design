---
name: timeline-tree-action-buttons
description: Timeline 改组合式 API、新增 Tree、新增 StatefulButton 与 SlideToConfirm（对照 reui.io 与 Aceternity）
status: backlog
created: 2026-09-22T20:52:48Z
---

# timeline-tree-action-buttons

## Executive Summary

用户提出四件事：现有 `Timeline` 表达力不足需重做（参考 reui.io）、缺 `Tree`（参考 reui.io）、
按钮缺业务状态（参考 Aceternity stateful-button）、缺滑动确认按钮。

对照取证后（`scratchpad/reui-refs.md`：三个参考实现的源码逐字抓取 + 一份 SwiftUI 滑动按钮源码逐行核对）
得出两条修正预设的事实，本 PRD 据此定范围：

1. **reui 的 Timeline 零动效**——它是纯 CSS 状态样式切换，源码里没有任何 `transition` / `animation`。
   可借的是它的**模型**（`activeStep` + 每项 `step`，`step <= activeStep` 即已完成）与**组合式子组件**分解，
   不是动效。动效是本仓自己要加的（已登记为 `tripled-analysis.md` P2 第 9 条）。
2. **reui 的 Tree 自身不含任何行为**——没有 `onKeyDown` / `onClick`，键盘与选择全部来自
   `@headless-tree/core`。所以 Tree 的行为契约不引 reui，改引 **W3C ARIA Navigation Treeview Pattern**
   （headless-tree 自陈遵循它）。

四项按「结构」与「动作」分两组，共用 `CoreMotionToken`（#407）与 `symbolReplacement`（#408）。

## Problem Statement

- **Timeline 的表达力被 API 形态锁死**。现状 `Timeline(items: [TimelineItem], layout:)`，`TimelineItem` 只有
  `status: StatusLevel` + 单个 `content` 富内容槽。由此产生四个连带缺口（均有代码依据，见
  `scratchpad/repo-survey-timeline-tree-button.md` A 节）：
  - 没有 header / footer 槽，也没有时间戳 / 标题 / 描述的分层——全部塞进同一个 `content` 由调用方自己排；
  - 自定义节点必须 ≤ 24×24pt（`static let nodeColumnWidth: CGFloat = 24`），超出会上下溢出、被连线穿过
    ⇒ reui 那种「头像作节点」的活动流形态**画不出来**；
  - 状态借用 `StatusLevel`（info / success / warning / danger / neutral），**没有**「已完成 / 进行中 / 未开始」
    这一维；状态只驱动圆点颜色，不驱动连线，也没有「进行中」的强调；
  - 组件零动效（全文 grep `withAnimation` / `coreAnimation` 无命中），文档甚至教调用方传稳定 id 来**避免**
    误触发动画。
  ⚠️ **交替布局不是缺口**——`TimelineLayout` 的 `.vertical` / `.alternate` / `.horizontal` / `.grouped`
  四态早在 #60 就已实现并有测试。
- **没有任何层级组件**。`InsetGroupedSection` 与 `DisclosureGroup` 的 `.core` style 都只支持单层；
  全仓无递归组件先例。文件树、权限树、组织架构这类层级数据当前无处落。
- **按钮只有交互反馈，没有业务状态**。`ButtonRoleStyleRole` 的五个 role 只覆盖 normal / pressed / disabled
  三种配色。`loading` 只存在于 `AsyncButton`（一个 View，不是 `ButtonStyle`，用系统默认 spinner）；
  **success / failure 视觉态完全不存在**——`AsyncButton` 出错只转发 `onError` 或弹 Toast，按钮本身外观不变。
- **没有高代价动作的确认控件**。删除账户 / 支付这类动作现在只能用 `confirmationDialog`，
  缺少 Apple 自家「滑动来关机」那种需要持续手势的形态。

## User Stories

- 作为设计系统使用者，我希望用组合子组件拼出活动流 / 部署日志 / 路线图三种形态的时间线，
  而不是把它们全塞进一个 `content` 闭包里自己排版。
  **验收**：三种形态各有一个 `#Preview` 与画廊条目，均不需要调用方自写 `Layout` 或手算缩进。
- 作为设计系统使用者，我希望展示文件树 / 权限树，并能控制默认展开到第几层。
  **验收**：`Tree` 的展开态是调用方持有的 `Set<ID>`，可读可写可持久化；「默认展开前两层」不需要调用方逐节点枚举。
- 作为开启「减弱动态效果」的用户，我希望以上新动效全部降级。
  **验收**：每条新动效都有 RM 分支与判据，见 NFR。
- 作为使用 VoiceOver 的用户，我希望滑动确认按钮**不需要真的拖拽**也能触发。
  **验收**：`SlideToConfirm` 经 `.accessibilityRepresentation` 暴露为普通 `Button`，激活后走同一条 action 通路；
  有判据钉住这条替代路径存在。
- 作为终端用户，我希望提交按钮能告诉我「在处理 / 成功了 / 失败了」，而不是只有一个转圈。
  **验收**：`StatefulButton` 四态各有视觉表达，状态切换有播报（不是纯视觉动画）。

## Functional Requirements

### 组一：结构组件

**FR-1 `Timeline` 改为组合式 API（破坏性变更）**

用户已定案：**改成组合式，接受破坏性变更**。现有 `Timeline(items:layout:)` 与两个 `TimelineItem` init 移除。

新形态参照 reui 的子组件分解，但**按 SwiftUI 惯例落地**（不照搬 Context + `data-*` 那套）：
容器 `Timeline` + 行 `TimelineRow` + 行内可选构件（指示器 / 时间 / 标题 / 描述 / 富内容）。
具体命名与分解由实现期任务级 spec 定，须满足：

- 四种布局**全部保留**（`.vertical` / `.alternate` / `.horizontal` / `.grouped`），现有 `TimelineAlternateRowLayout`
  的几何判据（`alternateSlotWidth` / `alternateRowMetrics`，含 `infinity` / `nan` / 负数防御）继续有效。
- **指示器列宽由最宽的指示器推导，不再是写死的 24pt** ⇒ 头像作指示器必须画得对（这是当前最硬的那条约束）。
- **新增「时间线阶段」一维**：已完成 / 进行中 / 未开始。取值方式二选一由实现定案并在文档写明：
  容器持有 `activeStep` 由行的位置推导（reui 的做法），或逐行显式给定。**`StatusLevel` 这一维保留**
  ——活动流 / 部署日志要的是逐项 success / danger，与「进行中」是正交的两件事，不可合并。
- **`.horizontal` 补画节点间连线**。⚠️ 这一条**推翻**登记表里那句「横向连线是尚无需求驱动的增强，不是缺口」
  ——用户现在明确说 Timeline 设计不行，重做就是处置它的时机；登记表那条 `notes` 必须同步改掉。
- 阶段推进动效：连线由「按状态二选一填色的静态 `Rectangle`」改为随阶段补间推进，节点入场缩放。
  走 `CoreMotionToken.reveal`；「进入视口才播」用原生 `.scrollTransition`（不要自造 observer）。
- ⚠️ **无障碍不得回退**：reui 把指示器与连线标为 `aria-hidden`（纯装饰）。本仓现有
  `accessibilityLabelKey` 把 `StatusLevel` 播报出去，**这个能力必须保留**——装饰元素不进无障碍树，
  但状态要播报在行上。

⚠️ **与 `Steps` 的边界**（`Components/Steps/Steps.swift` 已存在 `StepItem` / `StepsAxis` /
`StepsIndicatorStyle` / `StepsPresentation`）：`Timeline` 是**展示型**（回顾已发生的事），
`Steps` 是**流程型**（引导用户走完一个向导）。Timeline 不吸收 Steps 的向导行为，
Steps 不因本 epic 改动。两者的阶段推进动效可共用同一个 token，但**不共用类型**。

**FR-2 新增 `Tree`（自实现递归 + 受控展开）**

用户已定案：**自己递归 + 每节点展开绑定**（而非包 `OutlineGroup`）。理由须写进文档：
`OutlineGroup(data, children:)` 虽可脱离 `List` 使用，但官方文档明写
「All generated disclosure groups begin in the collapsed state」，且它不暴露展开态
⇒ 「默认展开到第 N 层」「程序化展开某节点」「持久化展开态」三件事都做不到。
⚠️ 这与本仓「换皮不重造控件」的定案有张力，**必须在 `docs/` 里写明为什么这次破例**，
并如实登记代价：选择与键盘导航不再由 `List` 免费提供，得自己做。

能力范围（用户已勾选四项）：

- **展开 / 折叠**：展开态为调用方持有的 `Set<ID>`；提供「默认展开到第 N 层」的便捷构造。
- **单选 / 多选**：⚠️ 模式必须是**枚举**，不得是 `multiSelect: Bool`（本仓公开 API 禁 Bool 入参，
  `BoolExemptionGuard` 会判红）。选中态配色从环境 `coreAccent` 派生（与 `TagGroup` 选中态同一条通路）。
- **复选框含父节点三态**：⚠️ **前置改动**——`Components/CheckBox/` 全文 grep
  `mixed` / `indeterminate` / `partial` **零命中**，CheckBox 现在没有中间态。要先给它加，
  而它有逐像素测试与 `#408` 刚落地的 `symbolEffect(.replace)` 符号替换 ⇒ 这是跨组件改动，
  新旧外观必须逐像素对照，且三态**不得**用 Bool 表达。
- **键盘导航**：契约取 **W3C ARIA Navigation Treeview Pattern**（不引 reui，它自身无键盘代码）：
  上 / 下移动焦点；**左** = 展开时折叠、已折叠时移到父节点；**右** = 折叠时展开、已展开时移到首个子节点；
  Home / End 跳首末；Shift + 方向键扩展选区；Ctrl+Space 切换当前项；Ctrl+A 全选。
- **搜索过滤与命中高亮**：按关键词过滤，自动展开到命中节点并高亮匹配片段。

**FR-2a 键盘导航先验实测（spike，结论写进 plan 与 docs）**

FR-2 的键盘那一项射程未知，**必须先实测再定承诺**：`onKeyPress` / `.focusable()` /
`FocusState` 在 iOS 26 模拟器（外接键盘）与 macOS 上，对一个**自定义递归层级**分别能做到什么；
`Ctrl+Space` / `Ctrl+A` 这类组合键在两端是否都能拿到；type-ahead 是否需要隐藏输入框。
⚠️ **实测不支持的部分如实降级为 Out of Scope 并写明**，不得写成「已支持」。

### 组二：动作按钮

**FR-3 新增 `StatefulButton`**

用户已定案：**新组件**（而非扩 `AsyncButton`、也不做成 `ButtonStyle`）。四态：
idle / loading / success / failure。⚠️ 态必须是**枚举**，不得拆成多个 Bool。

参考实现的行为逐条取舍（Aceternity 源码逐行读出的事实，见 `reui-refs.md` 3.4）：

| Aceternity 的做法 | 本仓取舍 |
|---|---|
| idle → loading → success → 停留 2 s → 回 idle，顺序 `await` 驱动 | **采**这条状态流；停留时长给默认值并可配 |
| loader 与 check 顺序显隐（非交叉淡变），各 0.2 s | 改用 `.contentTransition(.symbolEffect(.replace))`（#408 已落地的通路），不自己写顺序动画 |
| 按钮宽度随图标显隐自动 layout 过渡 | **采**，走 `CoreMotionToken` |
| **没有防重复点击的锁**——loading 期间再点会并发重入 | **不采，明确修掉**：loading 期间必须拒绝再次触发 |
| **没有失败态** | **补上** failure 态（Aceternity 只有三态） |
| **零 `aria-*` / 无播报**，状态变化对屏幕阅读器完全不可见 | **不采**：四态切换必须有无障碍播报 |
| loading 无超时，promise 不 resolve 就永远转圈 | 不引入隐式超时（那是调用方的事），但文档写明这一点并给 recipe |

与 `AsyncButton` 的关系：`AsyncButton` **保留不动**（它是「把 async 闭包接成按钮」的便捷件）。
`StatefulButton` 的态可由调用方托管，也可由它自管。两者在文档里写清何时用哪个。

**FR-4 新增 `SlideToConfirm`**

`tripled-analysis.md` A 表第 8 条已做过设计级论证，本 PRD 据新证据**修正其中两点**：

- **阈值不只看距离**。原设计只写「滑到 90%」。逐行读过的 SwiftUI 先例（`no-comment/SlideButton`）
  是**两者取或**：实际位移超过「容器宽 − 指示器尺寸 − 2×间距」**或** `predictedEndTranslation`
  （SwiftUI 手势自带的、按释放速度外推的预测终点）超过容器整宽 ⇒ **快速甩动没滑到底也算确认**。
  本仓采这条速度补偿；具体系数实现期定，须写明依据。
- **无障碍替代路径用 `.accessibilityRepresentation`**，而不是原设计写的 `accessibilityAction`。
  先例的做法是把整个滑块对辅助技术暴露成一个普通 `Button`（并在非 idle 态 `.disabled`），
  激活即走同一条 action。这是调研到的唯一一个**源码证实**做了替代路径的实现。
  ⚠️ 只能滑的控件对开启辅助功能的用户是**不可达**的，所以这条不是可选项。

其余：拖拽中途位移夹在合法区间内不可过冲；未达阈值时弹簧回弹且**不**触发 action；
触发后指示器内换成进度指示、action 走完再回位；`.sensoryFeedback` 在确认与回弹两处给不同反馈。
RM 下手势本身不受影响（手势驱动），但**回弹与触发后的转场要降级**。

## Non-Functional Requirements

沿用前三个 epic 的约定：

- 公开 API **无 Bool 入参**（`BoolExemptionGuard`）；只用第 3 / 4 层语义色；新组件文案参数走
  `LocalizedStringKey`（`ComponentTextParamGuard`）。
- 静态外观的像素判据**对照原样拷贝的旧实现**；资源色断言只在编译 catalog 的那条腿
  （macOS native 腿上那 198 个 asset catalog 常量恒解析为全透明）。
- 判据必须能被变异打红，且**变异不得照着判据的形状构造**；变异后先确认它真的落到了文件里。
- 双腿全绿：macOS `swift test` + iOS `xcodebuild test -scheme OhMyDesign-Package`（权威条数取
  `.xcresult` **顶层**计数）；另加预览宿主、`scripts/downstream-probe`、MainActor 静态棘轮、`design-digest.py`。
- **新组件的登记面**：`docs/component-registry.json` + `docs/components/<name>.md` +
  `ComponentRegistryGuard` / `ComponentExtensionPointGuard` 那一串判据。⚠️ 其中有**固定计数**的断言
  （如 `ComponentExtensionPointGuard.inspected.count`，当前实测 17），加组件必须同步这些数。
- 动效难以用静态位图证明：承重判据用「动画值 / transition 配置的单元判据」+「在飞帧采样」，
  且**承重量取互异中间位置的个数这类结构量，不取具体读数**（读数随机器负载变化、不可复现）。
  只能人工看的部分在报告里写明。
- 破坏性变更逐条登记 `docs/BREAKING-CHANGES.md`，并同步 `App/Sources/ComponentData.swift` 画廊与
  `scripts/downstream-probe`。

## Success Criteria

- `Timeline` 的三种参考形态（活动流含头像指示器 / 部署日志含状态徽章 / 路线图）各有 `#Preview` 与画廊条目，
  且**头像指示器不溢出**（当前 24pt 硬约束下画不出来，这是可度量的前后差）。
- `Timeline` 四种布局全部仍可用，`.horizontal` 现在**画出**节点间连线。
- `Tree` 能以「默认展开到第 2 层」启动，展开态可被外部读写；四项勾选能力各有判据；
  键盘导航按 FR-2a 的实测结论交付，**未能支持的项显式登记为 Out of Scope**。
- CheckBox 新增中间态，旧外观逐像素不变。
- `StatefulButton` 在 loading 期间重复点击**不重入**（有判据）；四态切换有无障碍播报（有判据）。
- `SlideToConfirm` 的 `.accessibilityRepresentation` 替代路径有判据；速度补偿分支有判据
  （构造一次「距离不足但速度足够」的手势）。
- 所有新动效在 RM 下降级且有判据；六条强制检查全绿。

## Constraints & Assumptions

- iOS 26+ / macOS 26+；Swift 6 严格并发；三个 target 均开 `.defaultIsolation(MainActor.self)`。
- 允许行为与 API 层面的破坏（FR-1 是明确的破坏性变更），逐条登记。
- 本机同时最多 **2 个**带模拟器的实现 agent；`xcodebuild` 带
  `CODE_SIGNING_ALLOWED=NO -IDEPackageEnablePrebuilts=NO`。
- 全部落在 `OhMyDesign` 主 target（不进 Effects / Charts）——四项都是系统原生观感的组件，
  且 `OhMyDesign` 的 `target_dependencies` 必须恒为 `[]`。
- ⚠️ **参考实现是 React**，其 API 形态（Context + `data-*` 属性 + Tailwind 变体级联）不照搬；
  借的是子组件分解与状态模型。

## Out of Scope

- **Tree 的拖拽重排**与**懒加载子节点**（用户未勾选）。`TreeDragLine` 那类插入指示线不做。
  ⚠️ reui 自己的 7 个示例里也**没有**一个展示拖拽或多选的视觉反馈（已核实），无可对照的现成形态。
- Tree 的重命名（`F2`）与 type-ahead——除 FR-2a 实测证明成本很低，否则不做。
- `Steps` 组件的任何改动（边界见 FR-1）。
- `AsyncButton` 的重构或废弃。
- `tripled-analysis.md` 里其余 P2 / P3 项（CountUpText、TypingIndicator、FloatButton 展开、
  Marquee、RotatingText、staggered 入场等）。
- reui 的 `render` prop 多态渲染（Radix `asChild` 那一套）——SwiftUI 无对应需求。
- 把 Timeline 的阶段模型强行统一进 `Steps`。

## Dependencies

- ⚠️ **本 epic 依赖 epic #406（motion-foundations）先合入 `main`**：FR-1 / FR-3 / FR-4 都要用
  `CoreMotionToken`（#407）与 `MotionPresentation.symbolReplacement`（#408），
  而这两样目前**只在 `epic/motion-foundations` 分支上，尚未进 main**。
  ⇒ `epic/timeline-tree-action-buttons` 必须从 #406 合入后的 `main` 开出，否则拿不到 token。
- FR-2 的三态复选框依赖 CheckBox 先加中间态（同一 epic 内的前置任务）。
- FR-2 的键盘那一项依赖 FR-2a 的实测结论。
- 取证产物：`scratchpad/reui-refs.md`（参考实现源码）、
  `scratchpad/repo-survey-timeline-tree-button.md`（本仓现状）。
  ⚠️ 两份都在 session scratchpad 里，**epic 分解时应把仍需引用的结论搬进 `.claude/epics/` 下的
  长期产物**，否则 session 结束后引用悬空。
