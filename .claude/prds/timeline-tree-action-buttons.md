---
name: timeline-tree-action-buttons
description: Timeline 改组合式 API、新增 Tree、新增 StatefulButton 与 SlideToConfirm（对照 reui.io 与 Aceternity）
status: backlog
created: 2026-09-22T20:52:48Z
updated: 2026-09-22T22:10:00Z
---

# timeline-tree-action-buttons

## Executive Summary

用户提出四件事：现有 `Timeline` 表达力不足需重做（参考 reui.io）、缺 `Tree`（参考 reui.io）、
按钮缺业务状态（参考 Aceternity stateful-button）、缺滑动确认按钮。

取证产物（都已落进仓库，不在会话里）：
`.claude/epics/structure-components/reference-implementations.md`（三个参考实现的源码逐字抓取 +
一份 SwiftUI 滑动按钮源码逐行核对）、`repo-survey.md`（本仓现状盘点）、
`prd-review-round1.md`（本 PRD 首轮对抗式评审全文）。

**四条修正了预设的事实**，本 PRD 据此定范围：

1. **reui 的 Timeline 零动效**——纯 CSS 状态样式切换，源码里没有任何 `transition` / `animation`。
   可借的是它的**模型**（`activeStep` + 每项 `step`）与**组合式子组件**分解，不是动效。
2. **reui 的 Tree 自身不含任何行为**——没有 `onKeyDown` / `onClick`，键盘与选择全部来自
   `@headless-tree/core`。所以 Tree 的行为契约不引 reui，改引 **W3C ARIA Treeview Pattern**。
3. **父节点三态不需要新控件模型**（首轮评审指出，已核官方文档）：
   `ToggleStyleConfiguration.isMixed` 自 iOS 16 / macOS 13 就存在，
   `Toggle(sources:isOn:label:)` 从一组绑定自动派生 on / mixed / off。
   ⇒ 缺口只是「现有 `CheckBoxToggleStyle` 没有呈现系统的 mixed 态」，不是「CheckBox 没有三态能力」。
4. **`Timeline` 的连线不读状态**——`TimelineConnector` 是**无条件** `.fill(Color.dividerDefault)`。
   ⚠️ 「按状态二选一填色」是 **`Steps`** 的行为（`Steps.swift` 的 `if self.progress(for: index) == .done`
   分支）。`tripled-analysis.md` 原把两者合并描述，本轮已更正该文件。

**按用户定案分成两个 epic，共用本 PRD**：

| epic | 覆盖 | 理由 |
|---|---|---|
| `structure-components` | FR-1（Timeline）、FR-2 / FR-2a（Tree） | 重、含破坏性变更、含一个射程未知的 spike |
| `action-buttons` | FR-3（StatefulButton）、FR-4（SlideToConfirm） | 轻、无破坏性变更，可先出，不被上面拖着 |

## Problem Statement

- **Timeline 的表达力被 API 形态锁死**。现状 `Timeline(items: [TimelineItem], layout:)`，`TimelineItem` 只有
  `status: StatusLevel` + 单个 `content` 富内容槽。由此产生四个连带缺口（均有代码依据，见 `repo-survey.md` A 节）：
  - 没有 header / footer 槽，也没有时间戳 / 标题 / 描述的分层——全部塞进同一个 `content` 由调用方自己排；
  - **节点槽是两个维度都写死的 24pt 方框**（`.frame(width: Timeline.nodeColumnWidth, height:
    Timeline.nodeColumnWidth)`），且连线起点由 `.padding(.top, Timeline.nodeColumnWidth)` 定、
    `.alternate` 的行高也直接纳入这个常量。⇒ **大于该槽的指示器（如头像）没有正确的自适应布局**
    ——会上下溢出、上沿侵入上一行、下沿被连线穿过。
    ⚠️ 射程写准：24pt 以内的头像**画得出来**，问题出在超过固定槽之后。
  - 状态借用 `StatusLevel`（info / success / warning / danger / neutral），**没有**「已完成 / 进行中 / 未开始」
    这一维；且状态**只驱动圆点颜色**，不驱动连线（连线无条件用 `dividerDefault`），也没有「进行中」的强调；
  - 组件零动效（全文 grep `withAnimation` / `coreAnimation` 无命中），文档甚至教调用方传稳定 id 来**避免**
    误触发动画。
  ⚠️ **交替布局不是缺口**——`TimelineLayout` 的四态早在 #60 就已实现并有测试。
- **没有任何接受层级数据的组件**。⚠️ 本条上一版写「`DisclosureGroup` 的 `.core` style 只支持单层」，
  **为假**（首轮评审指出）：`CoreDisclosureGroupStyle` 只重排 label / content、「展开状态仍由系统驱动」，
  不限制嵌套。真实缺口是**没有任何组件接受层级数据结构**——用 `DisclosureGroup` 表达树，
  递归、缩进、展开态管理、选择、键盘全要调用方自己手写。
- **按钮只有交互反馈，没有业务状态**。`ButtonRoleStyleRole` 的五个 role 只覆盖 normal / pressed / disabled
  三种配色。`loading` 只存在于 `AsyncButton`（一个 View，不是 `ButtonStyle`，用系统默认 spinner）；
  **success / failure 视觉态完全不存在**——`AsyncButton` 出错只转发 `onError` 或弹 Toast，按钮本身外观不变。
- **没有高代价动作的确认控件**。删除账户 / 支付这类动作现在只能用 `confirmationDialog`，
  缺少 Apple 自家「滑动来关机」那种需要持续手势的形态。

## User Stories

- 作为设计系统使用者，我希望用组合子组件拼出活动流 / 部署日志 / 路线图三种形态的时间线。
  **验收**：三种形态各有 `#Preview` 与画廊条目，均不需要调用方自写 `Layout` 或手算缩进；
  其中活动流用**大于旧 24pt 槽**的头像作指示器，且行高、连线端点都随之正确适配。
- 作为设计系统使用者，我希望展示文件树 / 权限树，并能控制默认展开到第几层。
  **验收**：展开态是调用方持有的 `Set<ID>`，可读可写可持久化；「默认展开到第 2 层」不需要逐节点枚举
  （「第 2 层」的计数口径在文档中定义：根为第 1 层）。
- 作为开启「减弱动态效果」的用户，我希望以上新动效全部降级。**验收**：每条新动效都有 RM 分支与判据。
- 作为使用 VoiceOver / 语音控制 / 切换控制的用户，我希望滑动确认按钮**不需要真的拖拽**也能触发，
  且能听到它当前是否可用、是否正在执行。
  **验收**：见 FR-4 的无障碍条款——替代元素的角色 / 名称 / 状态 / 实际激活结果都有判据。
- 作为终端用户，我希望提交按钮能告诉我「在处理 / 成功了 / 失败了」，而不是只有一个转圈。
  **验收**：四态各有视觉表达，状态切换有无障碍播报（不是纯视觉动画）。

## Functional Requirements

### epic `structure-components`

**FR-1 `Timeline` 改为组合式 API（破坏性变更）**

用户已定案：**改成组合式，接受破坏性变更**。现有 `Timeline(items:layout:)` 与两个 `TimelineItem` init 移除。

新形态参照 reui 的子组件分解，但**按 SwiftUI 惯例落地**（不照搬 Context + `data-*` + Tailwind 变体级联）：
容器 + 行 + 行内可选构件（指示器 / 时间 / 标题 / 描述 / 富内容）。命名与分解由任务级 spec 定，须满足：

- **a. 四种布局全部保留**（`.vertical` / `.alternate` / `.horizontal` / `.grouped`），现有
  `TimelineAlternateRowLayout` 的几何判据（`alternateSlotWidth` / `alternateRowMetrics`，
  含 `infinity` / `nan` / 负数防御）继续有效。
- **b. 指示器尺寸自适应，两个维度都要**：列宽由最宽指示器推导，**行高由该行指示器高度与内容高度共同决定**，
  **连线端点从指示器实际几何推导**（不再是 `.padding(.top, 24)` 这样的常量）。
  ⚠️ 只改列宽不解决问题——高指示器照样会被连线穿过。
  验证须覆盖非正方形指示器，以及 vertical / alternate / horizontal 三种布局；`grouped` 无节点列，是例外。
- **c. 新增「时间线阶段」一维**（已完成 / 进行中 / 未开始），`StatusLevel` 这一维**保留**且与之正交
  ——活动流 / 部署日志要的是逐项 success / danger，与「进行中」是两件事。
  须在 spec 里给出**阶段真值表**：阶段取值方式（容器 `activeStep` 推导 / 逐行显式，二选一并说明）、
  「进行中」如何判定、连线段归属哪一侧的阶段、全部完成与全部未开始两个边界、阶段**回退**时的表现、
  以及**不使用阶段**的纯活动流模式下连线如何着色。
- **d. `.horizontal` 补画节点间连线**。⚠️ 这一条**推翻**登记表里那句「横向连线是尚无需求驱动的增强，
  不是缺口」——重做就是处置它的时机；那条 `notes` 必须同步改掉。
- **e. 阶段推进动效**：连线随阶段补间推进（现状是无条件 `dividerDefault` 的静态 `Rectangle`），
  节点入场缩放，走 `CoreMotionToken.reveal`。
  ⚠️ **「进入视口才播」与阶段推进是两件事，必须分开定义**：`.scrollTransition` 是**双向**的
  （滚入滚出都作用），不是一次性入场事件。spec 须明确：再次滚入是否重播、无 `ScrollView` 宿主时的行为、
  嵌套滚动、以及 RM 下这两类动效各自的降级。
- **f. 无障碍不得回退**：reui 把指示器与连线标为 `aria-hidden`（纯装饰）。本仓现有 `accessibilityLabelKey`
  把 `StatusLevel` 播报出去，**这个能力必须保留**——装饰元素不进无障碍树，但状态要播报在行上；
  新增的阶段维度同样要可被辅助技术读到。

**FR-1 的迁移面（必须逐条处置）**

⚠️ 不是每一条漏掉都会让 CI 判红：`QuotedEvidenceGuard` 与 downstream-probe 会红，
但活文档措辞失真、登记表 `notes` 过时这类**没有机器判据**（`CLAUDE.md`「更正传播」一节明说
两族 `notes` 的守卫都只看长度、不校验真伪）⇒ 那几条要靠人工复核。

- `App/Sources/ComponentData.swift` **4 个**调用点、`App/Sources/Previews.swift` **5 个**调用点
  （含 `PreviewSnapshotFixtures.timelineItems` 这个共享 fixture）。
  ⚠️ 上一版写的是 3 / 4，**少算了各一处**：口径用的 `grep "Timeline(items:"` 只匹配单行写法，
  漏掉了 `Timeline(` 换行后再写参数的两处（`ComponentData.swift` 与 `Previews.swift` 各一）。
  ⇒ **数调用点用 `grep "Timeline("` 并排除 `TimelineView`**，别按参数名匹配。
- `scripts/downstream-probe`（独立 SwiftPM 包，只有 CI 的 downstream-probe job 覆盖它）。
- **`Tests/OhMyDesignTests/QuotedEvidenceGuard.swift` 登记了 5 条指向 Timeline 源码的原文**
  （`@ViewBuilder node: () -> Node,` ×2、`private var nodeContent: some View` ×2、
  `static let nodeColumnWidth: CGFloat = 24` ×1，共 5 条，分别被 `docs/contract-defects.md` /
  `docs/component-contract.md` / `docs/component-registry.json` 引用）。
  ⇒ 删掉这些符号会让该判据判红，**三份引用它的活文档也必须同步改**。
  ⚠️ 这一条上一版漏了，是首轮评审抓出来的。
- `docs/components/timeline.md` + `docs/component-registry.json` 的 `Timeline` 条目
  （含那条要推翻的 `.horizontal` `notes`），按 `CLAUDE.md`「更正传播」约定三处落点同步。
- ⚠️ **像素不变的射程要划清**：NFR 那条「对照原样拷贝的旧实现逐像素不变」**只适用于有意保留外观的部分**
  （如默认圆点在 `.vertical` 下的呈现）。新增连线、自适应尺寸、新布局行为**不可能**与旧实现逐像素相同
  ——这些另立新基线，并在 BREAKING-CHANGES 里写明哪些外观是有意变的。

⚠️ **与 `Steps` 的边界**：`Timeline` 是**展示型**（回顾已发生的事），`Steps` 是**流程型**（引导走完向导）。
Timeline 不吸收 Steps 的向导行为，Steps 不因本 epic 改动。两者的阶段推进动效可共用同一个 token，
**但不共用类型**。

**FR-2 新增 `Tree`（受控展开）**

用户已定案：**自己递归 + 每节点展开绑定**（而非包 `OutlineGroup`）。

⚠️ **理由要写准**（上一版把两个独立选择绑在了一起，首轮评审指出）：
被排除的只是 `OutlineGroup(_:children:content:)` 这条路径——官方文档明写
「All generated disclosure groups begin in the collapsed state」，且它不暴露展开态
⇒「默认展开到第 N 层」「程序化展开某节点」「持久化展开态」三件事做不到。
**但这不等于必须放弃全部原生控件**：递归的 `DisclosureGroup(isExpanded:)` 具备受控展开，
且**不限制嵌套**（`CoreDisclosureGroupStyle` 只重排 label / content，「展开状态仍由系统驱动」）。
⚠️ **但换皮的代价要写准**（本轮定向复审指出上一版说过头了）：`CoreDisclosureGroupStyle` 自己画
`DisclosureChevron` 并自己 `withAnimation(.snappy)` ⇒ **chevron 与展开动画都不是系统原生的**；
`docs/components/core-control-styles.md` 还明确登记了一项已知代价：
「换皮后系统不再自动为这个自绘 `Button` 播报展开态」。
⇒ 走这条路能免费拿到的是**系统的展开态接口与嵌套能力**，不是原生外观与原生无障碍播报。
⇒ **实现路径由 FR-2a 的 spike 比较后定案**，候选三条：① 递归 `DisclosureGroup(isExpanded:)`（首选评估）；
② `List(selection:)` 承载受控层级；③ 完全自定义。
**不得预先宣称「选择与键盘导航全部要重做」**——哪些原生行为能保留由 spike 给证据。

能力范围（用户已勾选四项）：

- **展开 / 折叠**：展开态为调用方持有的 `Set<ID>`；提供「默认展开到第 N 层」的便捷构造（根为第 1 层）。
- **单选 / 多选**：⚠️ 模式必须是**枚举**，不得是 `multiSelect: Bool`（`BoolExemptionGuard` 会判红）。
  选中态配色从环境 `coreAccent` 派生（与 `TagGroup` 选中态同一条通路）。
- **复选框含父节点三态**：改用系统能力（见 Executive Summary 第 3 条）——
  `CheckBoxToggleStyle.makeBody` 增读 `configuration.isMixed` 并呈现第三种符号
  （Apple 自己的示例用 `minus.circle.fill`；本仓应取与 `checkmark.square.fill` 同族的形状）；
  Tree 的父行用 `Toggle(sources:isOn:)` 让系统从后代绑定派生 mixed。
  ⚠️ 这条**不新增任何公开 Bool 入参**——`isMixed` / `isOn` 是**读** `configuration`，
  与「禁止新增含糊的公开 Bool 参数」那条纪律不冲突，实现 agent 不要把它误读成禁止读系统状态。
  CheckBox 旧外观（on / off × enabled / disabled / invalid）须逐像素不变。
- **键盘导航**：契约取 **W3C ARIA Treeview Pattern**。⚠️ 该 pattern 有**两套互斥的多选模型**（此读法来自首轮评审对 W3C 原文的引用，**本轮未独立核对原文**，
  FR-2a 的 spike 须回原文确认再定案）。本 PRD 暫选其**推荐模型**：**Space 切换当前项的选中**，普通方向键**只移动焦点、不改变选择**；
  `Shift+方向键` 扩展选区；`Ctrl+A` 全选。上一版写的 `Ctrl+Space` 属另一套模型，已弃用。
  另定：**Enter 激活**（触发调用方的 action，与选择分开）、初始焦点落在哪、叶节点上按右键的边界行为。
  方向键语义：上 / 下移动焦点；**左** = 展开时折叠、已折叠时移到父节点；
  **右** = 折叠时展开、已展开时移到首个子节点；Home / End 跳首末。
- **搜索过滤与命中高亮**：按关键词过滤，自动展开到命中节点并高亮匹配片段。
- **密度与外观配置**（`#429` 修订）：两种外观共用环境 `controlSize` 推导的度量——**最小行高**、行间距、
  展开槽宽、缩进、chevron 与复选框字形（推导表见 `docs/superpowers/specs/2026-09-23-tree-style-design.md`
  §1.2–§1.4）。行高是下限，行内容可以把行撑高；iOS 上行、展开控件与 Tree 自建复选框的命中高度都 ≥ 44pt。
  复选框的密度适配**只作用于 Tree 自建的复选框**；独立 `CheckBox` 与调用方放进行内容里的 `CheckBox`
  行为与外观都不变。
  `TreeStyle` **封闭配置**（`.automatic` / `.navigator`，经 `View.treeStyle(_:)` 注入）——**不是协议**，
  升协议的兼容路径（modifier 取 `any TreeStyle`）见同一 spec §2.1。⚠️ 本轮定案的只是「非协议」这一 **API 形态**；
  封闭预设是否算公约扩展点、悬停等差异如何分类，仍由 `docs/contract-defects.md` 的 `D-429-1` 待公约 owner 裁定——
  本轮不改登记分类，J-2 计数不变。
  两种外观的验收：`.automatic` 在 `.regular` 下保留既有外观；`.navigator` 按 spec §2.5 画——含缩进区的整行
  选中 / 悬停底色、选中优先于悬停、焦点内描边、连续且随 RTL 镜像的缩进参考线、中性色 chevron；
  底色、悬停、选中是**三档阶梯**（选中必须比悬停更偏离底色、两者一眼分得清，明暗两档都成立）。
  验收覆盖五档密度、两种外观下行为与无障碍取值一致、点缩进区选中该行，按 spec §7.1–§7.5。
  行为（键盘、选择归约、三态勾选、焦点、无障碍、命中区）留在组件内，外观只决定画法。
- **整行右键菜单**（`#429` 修订，**后续 PR 3 交付**）：`rowContextMenu` 的目标集合——右键的行**已选中**时，
  取选中集合与树的可见行的交集；**否则**只取右键那一行。「可见」指展开 / 过滤之后的行序列，不是视口内可见。
  唤起菜单不改变选中、焦点或交互来源；不设置时不挂菜单。验收按 spec §4、§7.6。

**FR-2 的行为真值表（本 PRD 定案，不留给实现期自选）**

首轮评审指出这几项不是互相独立的功能，只写「spec 须给出」仍允许两种都能「满足 PRD」的实现
⇒ 在此逐行定案。每一行都要有判据；**实现期若认为某行定错了，回来改 PRD，不要就地另做一套**。

| 行为 | 定案 | 依据 |
|---|---|---|
| 行选中与复选框 | **两套独立状态** | 「当前高亮哪一行」是导航语义、「勾了哪些」是数据语义；reui 权限树示例也明说两者是独立点击目标 |
| 点击 mixed 父节点 | **全选**（级联到全部后代）；再点一次**全不选** | 与 Finder / Xcode 的多选层级一致；系统 `Toggle(sources:)` 的 `isOn.toggle()` 语义也是这样 |
| 父节点自身 | **只由后代推导，不单独进选择集合** | 叶子才承载数据；父节点本身也是可选数据时，调用方把它建成叶子 |
| 搜索期间的展开 | **不写进调用方的持久化 `Set<ID>`**，只临时展开 | 否则搜一次就永久改了用户的展开偏好 |
| 清空搜索 | **恢复搜索前的展开态** | 与上一行是同一个决定的两面 |
| 过滤后「全选」 | **范围是可见节点** | 「全选」作用在用户看得见的集合上；作用到全树会静默勾上看不见的项 |
| 焦点节点被过滤隐藏 | 移到**最近的仍可见祖先**；无祖先则移到首个可见节点 | 焦点不能落到不可见节点上，也不应直接丢失 |

**FR-2a 实现路径与键盘先验实测（spike，结论写进 plan 与 docs）**

两件事一起测：

1. **实现路径**：三条候选（见 FR-2）各自能否满足受控展开 + 持久化，以及各自能免费拿到哪些原生行为。
2. **键盘射程**：`onKeyPress` / `.focusable()` / `FocusState` 在 iOS 26 模拟器（外接键盘）与 macOS 上，
   对选定的实现路径分别能做到什么；`Shift+方向键` / `Ctrl+A` 这类组合键两端是否都能拿到；
   焦点与选择的关系在原生辅助技术里呈现成什么。

⚠️ **spike 必须带一条硬下限，否则它会变成「把做不到的都移出范围后依然通过验收」**：
**上下移动焦点、左右折叠展开、Space 切换选中、Enter 激活**这四项是**必须支持**的；
`Shift+方向键` / `Ctrl+A` / type-ahead / `F2` 重命名属**可降级**项，实测不支持则如实登记为 Out of Scope。

### epic `action-buttons`

**FR-3 新增 `StatefulButton`**

用户已定案：**新组件**（而非扩 `AsyncButton`、也不做成 `ButtonStyle`）。四态：idle / loading / success / failure。
⚠️ 态必须是**枚举**，不得拆成多个 Bool。

参考实现的行为逐条取舍（Aceternity 源码逐行读出，见 `reference-implementations.md` 3.4）：

| Aceternity 的做法 | 本仓取舍 |
|---|---|
| idle → loading → success → 停留 2 s → 回 idle，顺序 `await` 驱动 | **采**这条状态流；停留时长给默认值并可配 |
| loader 与 check 顺序显隐（非交叉淡变），各 0.2 s | 改用 `.contentTransition(.symbolEffect(.replace))`（#408 已落地的通路） |
| 按钮宽度随图标显隐自动 layout 过渡 | **采**，走 `CoreMotionToken` |
| **没有防重复点击的锁**——loading 期间再点会并发重入 | **不采，明确修掉**（见下方状态机条款） |
| **没有失败态** | **补上** failure 态（Aceternity 只有三态） |
| **零 `aria-*` / 无播报** | **不采**：四态切换必须有无障碍播报 |
| loading 无超时，promise 不 resolve 就永远转圈 | 不引入隐式超时（那是调用方的事），但文档写明并给 recipe |

**状态机必须闭合**（首轮评审指出四个枚举 case 不构成状态机）。spec 须分别给出**托管**与**自管**
两套「事件 → 状态」表，并明确：

- **唯一写入方**是谁（托管模式下组件是否可以自己写 loading）；
- **防重入门闩不得依赖可被外部修改的视觉状态**——否则外部把态改回 idle 就能重入；
- failure 的停留时长与**能否立即重试**；
- success 停留期间点击的处理；
- **取消与离屏**：`AsyncButton` 已有 `.onDisappear { self.task?.cancel() }` 与 `catch is CancellationError`，
  新组件是否继承这套语义要写明；
- **过期任务**：外部复位后旧任务才完成，它的结果是否还能改变按钮外观。

与 `AsyncButton` 的关系：`AsyncButton` **保留不动**。两者在文档里写清何时用哪个。

**FR-4 新增 `SlideToConfirm`**

`tripled-analysis.md` **P2 第 8 条 / A 表第 4 行**已做过设计级论证
（⚠️ 上一版把引用位置写成「A 表第 8 条」，是错的）。本 PRD 相对它做**一处策略调整**：

- **无障碍替代路径用 `.accessibilityRepresentation`**，而不是原设计写的 `accessibilityAction`。
  先例（`no-comment/SlideButton`，逐行读过源码）把整个滑块对辅助技术暴露成一个普通 `Button`
  并在非 idle 态 `.disabled`，激活即走同一条 action。
  ⚠️ **这是策略调整，不是「旧方案被证明是错的」**——`accessibilityAction` 也能提供替代操作，
  选前者是因为它让替代路径成为控件的**唯一**无障碍表示，不会与滑块自身的手势语义并存而产生歧义。

**阈值：纯距离，必须真滑到底**（用户定案）。

- 触发条件只有一条：实际位移 ≥ 容器宽 − 指示器宽 − 2×间距。
- ⚠️ **不采**先例里的速度补偿（`predictedEndTranslation` 超过容器整宽也算确认）。
  理由：本控件是给高代价动作用的，「没滑到底但甩得快」会确认意味着误触门槛实际被降低；
  先例证明「有人这样实现」，不构成「适合高代价确认」的依据。
  ⚠️ **这条要写进源码注释与文档**——否则下一个人会照着先例「补上」它。
- 验收**必须含负例**：快速甩到一半松手（不确认）、反向拖动、拖到阈值前一点松手、
  拖动中途被打断。只有正例的验收不成立。

**执行与重入边界**（首轮评审指出原稿只写了触发后表现、没定义契约）。spec 须规定：

- 拖动 / 执行 / 回位**三个阶段各自的可交互性**；
- **所有输入路径（手势与无障碍激活）共用同一道执行门闩**，连续激活只执行一次；
- action 抛错 / 被取消如何结束；宿主 `.disabled` 时的表现；离屏与手势中断；
- 「动作已完成但回位未完成」这个窗口里能否再次触发（须明确，不可留给实现自选）。

**无障碍条款**（首轮评审指出「存在替代路径」不等于可访问）。Apple 明确：
`accessibilityRepresentation` 会**完全替换**原有无障碍表示 ⇒ 原视觉子树里的信息不会自动保留。
所以替代 `Button` 必须自带：动作名称、当前执行状态、正确的禁用语义，且状态切换后焦点仍可预测。
判据要检**可访问元素的角色 / 名称 / 状态与真实激活结果**，不是只检「replacement 存在」。
覆盖 VoiceOver / 语音控制 / 切换控制；硬件键盘可达性**另行验证**，不能由这个 modifier 自动推出。

其余：拖动中途位移夹在合法区间内不可过冲；未达阈值时弹簧回弹且**不**触发 action；
触发后指示器内换成进度指示、action 走完再回位（⚠️ 旧分析里「成功态用
`.transition(.scale.combined(with: .opacity))`」这一项**本 PRD 不采**，改为「执行中进度 + 完成后回位」，
此处为显式取舍而非遗漏）；`.sensoryFeedback` 在确认与回弹两处给不同反馈。
RM 下手势本身不受影响（手势驱动），但**回弹与触发后的转场要降级**。

## Non-Functional Requirements

- 公开 API **无 Bool 入参**（`BoolExemptionGuard`）；只用第 3 / 4 层语义色；新组件文案参数走
  `LocalizedStringKey`（`ComponentTextParamGuard`）。
  ⚠️ 这条约束的是**新增的公开参数**，不约束读取系统 `configuration` 上的 Bool（见 FR-2 三态那条）。
- 静态外观的像素判据**对照原样拷贝的旧实现**，**射程限于有意保留外观的部分**（见 FR-1 迁移面最后一条）。
- 资源色断言只在编译 catalog 的那条腿（macOS native 腿上那 198 个 asset catalog 常量恒解析为全透明）。
- 判据必须能被变异打红，且**变异不得照着判据的形状构造**；变异后先确认它真的落到了文件里。
- 双腿全绿：macOS `swift test` + iOS `xcodebuild test -scheme OhMyDesign-Package`（权威条数取
  `.xcresult` **顶层**计数）；另加预览宿主、`scripts/downstream-probe`、MainActor 静态棘轮、`design-digest.py`。
- **新组件的登记面**：`docs/component-registry.json` + `docs/components/<name>.md` +
  `ComponentRegistryGuard` / `ComponentExtensionPointGuard` 那一串判据，外加 `QuotedEvidenceGuard`
  （若活文档引了新组件的源码原文）。
  ⚠️ 其中有**精确计数**的断言，加组件时要**逐项裁决是否进入该定义域**，不要按新增数量直接加：
  `ComponentExtensionPointGuard` 当前写 `#expect(result.inspected.count == 16, ...)` 并逐项列出 16 个组件名。
  （⚠️ 这个数刚漂过一次：`#312` 落地时确为 17，`39fecab` 移除 `Sidebar` / `BottomInputBar` 后降到 16，
  而 `CLAUDE.md` / `AGENTS.md` 的注记停在 17 没跟上，本轮已同步。
  **17 在当时是对的，失真的是那条注记**——`docs/components/orbiting-logos.md` 里的「J-2 定义域 17 条」
  是 `#312` 的历史记账，正确、不要改成 16。）
- 动效难以用静态位图证明：承重判据用「动画值 / transition 配置的单元判据」+「在飞帧采样」，
  且**承重量取互异中间位置的个数这类结构量，不取具体读数**（读数随机器负载变化、不可复现）。
  只能人工看的部分在报告里写明。
- 破坏性变更逐条登记 `docs/BREAKING-CHANGES.md`。

## Success Criteria

- **Timeline**：三种参考形态（活动流 / 部署日志 / 路线图）各有 `#Preview` 与画廊条目；
  活动流的头像指示器**大于旧 24pt 槽**且行高、连线端点正确适配（非正方形指示器同样验证）；
  四种布局全部仍可用，`.horizontal` 现在画出节点间连线；阶段真值表的每一行都有对应判据。
- **Tree**：能以「默认展开到第 2 层」启动，展开态可被外部读写；FR-2 行为真值表七行各有判据；
  键盘四项硬下限全部支持，可降级项按 FR-2a 实测结论显式登记。
- **Tree 密度与外观**（`#429`）：五档 `controlSize` 的最小行高逐档有判据（iOS 命中高度 ≥ 44pt）；
  `.automatic` 与 `.navigator` 下行为逐条一致（含点缩进区选中）；`.navigator` 的三档阶梯（底色 < 悬停 < 选中）
  在明暗两档、iOS 与 macOS 两条腿上都有判据。
- **CheckBox**：呈现系统 mixed 态；on / off × enabled / disabled / invalid 旧外观逐像素不变。
- **StatefulButton**：托管与自管两套状态表各自有判据；loading 期间重复点击不重入，
  且**把态从外部改回 idle 也不能重入**（这条单独构造）；四态切换有无障碍播报。
- **SlideToConfirm**：四个负例（快速甩一半、反向拖、阈值前一点、中途打断）全部不触发；
  手势与无障碍激活连续触发只执行一次；替代 `Button` 的角色 / 名称 / 状态 / 激活结果有判据。
- 所有新动效在 RM 下降级且有判据；六条强制检查全绿。

## Constraints & Assumptions

- iOS 26+ / macOS 26+；Swift 6 严格并发；三个 target 均开 `.defaultIsolation(MainActor.self)`。
- 允许行为与 API 层面的破坏（FR-1 是明确的破坏性变更），逐条登记。
- 本机同时最多 **2 个**带模拟器的实现 agent；`xcodebuild` 带
  `CODE_SIGNING_ALLOWED=NO -IDEPackageEnablePrebuilts=NO`。
- 全部落在 `OhMyDesign` 主 target（不进 Effects / Charts）；`OhMyDesign` 的
  `target_dependencies` 必须恒为 `[]`。
- ⚠️ **参考实现是 React**，其 API 形态（Context + `data-*` + Tailwind 变体级联）不照搬；
  借的是子组件分解与状态模型。

## Out of Scope

- **Tree 的拖拽重排**与**懒加载子节点**（用户未勾选）。`TreeDragLine` 那类插入指示线不做。
  ⚠️ 射程写准（上一版说过头了）：取证材料里**没有**找到拖拽重排、也没有找到 headless-tree
  那套**行多选**（`Shift+方向键` / 全选）的完整示例；但**复选框勾选形态是有的**
  ——权限树示例（`c-tree-7`）就是多个叶子复选框的受控勾选，且材料里明说「勾选与展开/选中是两套独立的点击目标」。
  ⚠️ 「7 个示例都没有行多选」这一条**未独立证实**（材料只存了其中两份完整源码），按未核实处理。
- Tree 的 `F2` 重命名与 type-ahead——属 FR-2a 的可降级项，除实测证明成本很低否则不做。
- 「单击父行即展开」——是**行为**不是外观，不进 `TreeStyle`（公约《边界条款：样式不得携带行为》），
  另开 `#431` 在 `Tree` 上加行为参数（`#429` 修订）。
- `SlideToConfirm` 的速度补偿确认（显式不采，理由见 FR-4）。
- `Steps` 组件的任何改动（边界见 FR-1）；`AsyncButton` 的重构或废弃。
- `tripled-analysis.md` 里其余 P2 / P3 项（CountUpText、TypingIndicator、FloatButton 展开、
  Marquee、RotatingText、staggered 入场等）。
- reui 的 `render` prop 多态渲染（Radix `asChild` 那一套）——SwiftUI 无对应需求。
- 把 Timeline 的阶段模型强行统一进 `Steps`。

## Dependencies

- ⚠️ **两个 epic 都依赖 epic #406（motion-foundations）先合入 `main`**：FR-1 / FR-3 / FR-4 都要用
  `CoreMotionToken`（#407）与 `MotionPresentation.symbolReplacement`（#408），
  而这两样目前只在 `epic/motion-foundations` 分支上。
  ⇒ 两条 epic 分支都必须从 #406 合入后的 `main` 开出。
- FR-2 的三态复选框依赖 CheckBox 先增读 `configuration.isMixed`（同一 epic 内的前置任务）。
- FR-2 的实现路径与键盘射程依赖 FR-2a 的实测结论。
- 取证产物已落进仓库（不再只在会话里）：
  `.claude/epics/structure-components/{reference-implementations,repo-survey,prd-review-round1}.md`。
  `action-buttons` epic 复用同一批材料，按上述路径引用。
