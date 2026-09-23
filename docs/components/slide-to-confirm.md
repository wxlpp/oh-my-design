# SlideToConfirm

滑到底才触发的高代价动作确认（删除账户 / 支付这类）。形态取 iOS「滑动来关机」：一条 Liquid Glass 胶囊轨道 +
一个白色圆形指示器 + 指示器右侧带流光的提示文案：
按住指示器拖到轨道尽头松手 ⇒ 执行 action；执行期间指示器停在尽头、内部换成进度指示；
action 返回后指示器回到起点。RTL 下整条轨道镜像：指示器从右端出发、向左滑到尽头。

## 设计定案 / Design decisions

### 阈值：纯距离，必须真滑到底

- 触发条件只有一条：**松手时的实际位移 ≥ 容器宽 − 指示器宽 − 2×间距**（即指示器能走的全程
  `travel`；位移在拖动中被夹在 `[0, travel]`，所以「≥ travel」就是「拖到了尽头」）。
- ⚠️ **显式不采速度补偿**。参考实现 `no-comment/SlideButton` 在 `predictedEndTranslation`
  （按松手速度外推的预测终点）超过容器整宽时也算确认——「没滑到底但甩得快」会触发。
  本控件给高代价动作用，那等于把误触门槛降低了。**不要照着先例「补上」它**：
  源码里判定函数上有同一句注释，判据「快速甩到一半松手不触发」专门钉着这一条
  （样本的 `predictedEndTranslation` 取容器宽的数倍）。
- 容器宽度尚未量到（`travel == 0`）时任何位移都不触发。

### 三个阶段与可交互性

| 阶段 | 指示器位置 | 指示器内容 | 手势 | 无障碍激活 |
|---|---|---|---|---|
| **待命**（含拖动中） | 跟手，夹在 `[0, travel]` | 箭头符号 | ✅（起点须落在指示器上） | ✅ |
| **执行** | 停在尽头 | 进度指示 | 挂着但只吸收：会话作废 | ❌（替代 `Button` 为 disabled） |
| **回位** | 由尽头回到起点 | 箭头符号 | 挂着但只吸收：会话作废 | ❌（替代 `Button` 为 disabled） |

- **拖动手势挂在整条轨道上**，会话在第一次拖动变化时裁决、整段不变：起点落在指示器（含两侧间距）上
  且门闩开着 ⇒ 有效会话；否则只**吸收**——不位移、松手不触发、不给触觉。吸收的意义是横滑不漏给系统
  返回手势（iOS 26 的全内容区返回手势会把轨道空白处的右滑当成 pop）。
- **iOS 上只认领横向占主导的滑动**（`SlideToConfirmPanArbitration.claims`：|dx| > |dy|，按下点起算）：
  纵向起手的触摸手势直接放弃，交给外层 `ScrollView`——不开会话、不吸收。为此 iOS 用 UIKit 平移识别器
  （`UIGestureRecognizerRepresentable`，在 `gestureRecognizerShouldBegin` 里裁决），macOS 仍用 `DragGesture`。
  ⚠️ 实测 SwiftUI 的 `DragGesture` 挂在轨道上时，轨道上起手的纵向滑动一律滚不动页面，
  换成 `.simultaneousGesture` 也一样；去掉手势页面就能滚。所以不能只在会话裁决里加方向条件，得换识别器。
  ⚠️ 平移识别器在认领那一刻把位移清零（实测 axe 从 x = 54 横滑，认领时位置已到 83、位移读 0，
  全程只累计 284 pt < 294），所以位移与起点都从 `shouldReceive` 记下的按下点算。
- 执行 / 回位期间手势**不停用**（停用了横滑就会落到返回手势上），正确性交给会话裁决与门闩。
- ⚠️ **门闩关闭期间开始的会话整段作废**：即便 action 返回、回位走完、门闩已开之后才松手，也不触发
  （对应下表「执行」行的「不排队」）。无障碍激活同样把进行中的会话作废。

- **所有输入路径共用同一道门闩**：拖动松手与无障碍激活都向同一个 `SlideToConfirmGate` 申请运行号；
  门闩**只认运行号**，不读阶段或任何视觉态。门闩在准入时关上，**直到这次运行的 action 返回、
  且回位走完**才打开 ⇒ 连续激活（手势 + 无障碍、无障碍 × 2、迟到的 `onEnded`）只执行一次。
- ⚠️ **「动作已完成但回位未完成」这个窗口不可再次触发**（定案，不留给实现自选）。
  理由：指示器此时还不在起点，准入等于让「正在往回走的指示器」同时代表一次新的执行；
  而本控件的承诺是一次完整的滑动对应一次执行。回位时长取 `CoreMotionToken.reveal.duration`
  （0.25 s）；Reduce Motion 下回位不补间，回位窗口为 0，action 返回即开闸。

### 事件 → 状态

| 当前阶段 | 事件 | 新阶段 | 说明 |
|---|---|---|---|
| 待命 | 拖动变化 | 待命 | 位移 = `clamp(translation, 0, travel)`，不补间；RTL 下 translation 先乘 −1 |
| 待命 | 起点不在指示器上的拖动 / 松手 | 待命 | 吸收，不位移、不触发、不给触觉 |
| 待命 | 松手，位移 ≥ `travel` | 执行 | 准入、发运行号；确认触觉；起 `Task` 跑 action |
| 待命 | 松手，位移 < `travel`（含反向、甩一半） | 待命 | 弹簧回弹到起点、**不**触发；位移 > 0 时给回弹触觉 |
| 待命 | 手势被打断（系统取消 / 宿主中途 `.disabled` / 离屏） | 待命 | 回到起点，不触发、不给触觉——被取消的手势没有 `onEnded`，只有 `@GestureState` 复位 |
| 待命 | 无障碍激活 | 执行 | 同一道门闩；进行中的拖动会话作废 |
| 执行 | 拖动 / 松手 / 无障碍激活 | 执行 | 门闩关 ⇒ **忽略**，不排队：这期间开始的拖动会话在开闸后松手也不触发 |
| 执行 | action 正常返回 | 回位 | 播报 `Success` |
| 执行 | action 抛非取消错误 | 回位 | 播报 `Failed`；外观与成功相同（本控件没有失败态，见下） |
| 执行 | action 抛 `CancellationError` | 回位 | **静默**，不当失败 |
| 执行 | 离屏 | 执行 | `Task` 取消；门闩**不开**，直到 action 真正返回 |
| 回位 | 任何输入 | 回位 | 忽略 |
| 回位 | 回位走完（或 `Task` 已取消） | 待命 | 开闸 |

### 抛错、取消、`.disabled`、离屏

- **抛错**：回到起点、播报 `Failed`。本控件**没有**失败视觉态——PRD 定案「执行中进度 + 完成后回位」，
  旧分析里「成功态用 `.transition(.scale.combined(with: .opacity))`」**不采**，失败同理不另起一态。
  需要拿到 `Error` 本身时在 action 内 `catch` 处理后再 `throw`。
- **取消**：`CancellationError` 静默回位，不播报失败（与 `AsyncButton` / `StatefulButton` 一致）。
- **离屏**（含导航返回）：取消在跑的 `Task`——这一条写在公开文档注释里，接入方不可中断的工作
  须在 `action` 内另起非结构化 `Task`；但**不开闸**——取消只是请求，不响应取消的 action 仍在跑，
  此时开闸会让回屏后的滑动并发重入（与 `AsyncButton` 在 `Task` 的 `defer` 里才复位同理）。
  action 返回后回位等待随 `Task` 取消立即结束，门闩随之打开。
- **宿主 `.disabled`**：待命时手势不响应（手势的 `isEnabled` 只读宿主环境值）、替代 `Button` 为 disabled（`isEnabled` 环境值自然继承）、
  整个控件不透明度降到 0.4；拖动中途被禁用 ⇒ 手势被取消 ⇒ 按「被打断」处理；
  执行中被禁用 ⇒ **不取消** action，照常回位，回到待命后保持禁用。
- **不引入隐式超时**：action 永不返回，控件就一直停在执行阶段（同 `StatefulButton`）。

### 外观

| 部位 | 取值 | 理由 |
|---|---|---|
| 轨道 | `secondaryFill` 胶囊作玻璃的内容，外挂 `.glassEffect(.regular, in: Capsule(style: .continuous))` | 关机滑块的轨道是压在内容上的半透明材质；iOS 26 / macOS 26 上对应 Liquid Glass。垫 `secondaryFill`：玻璃压在纯色背景上几乎不可见（macOS 深色外观截图里整条轨道消失），垫一层系统填充色才看得出轨道。取 `.regular` 不取 `.interactive()`：整条轨道都吸收拖动，交互玻璃会在每次按下时整条形变，抢指示器的戏 |
| 指示器底色 | `Color.surfaceRaised`，整个指示器子树钉 `.environment(\.colorScheme, .light)` | 关机滑块的指示器两种外观下都是白的。`surfaceRaised` 在浅色外观下解析为白（iOS `secondarySystemGroupedBackground` / macOS `controlBackgroundColor`），不写色相字面量、不用 asset catalog 色 |
| 箭头 / 执行中的进度 | 环境 `coreAccent`（`foregroundStyle` 与 `.tint` 同取）；在浅色岛里与 `surfaceRaised` 对比不足 3:1 时退回 `Color.inkPrimary`（`Color.legibleAccent(_:on:in:)`，WCAG 对比度，3:1 是非文字图形的下限） | 宿主 `.coreAccent(.blue)` ⇒ 箭头变蓝；`.white` / `.yellow` / `.mint` 在白底上看不见 ⇒ 退回墨色。⚠️ 默认 accent 是墨色，**深色外观下解析为白**，白底白箭头会看不见 ⇒ 这正是指示器钉浅色外观的原因：墨色在浅色岛里解析为黑。⚠️ **进度取色只在 iOS 生效**：macOS 的系统圆形 `ProgressView` 不响应 `.tint`，白底上是浅灰（见《已知缺口》） |
| 指示器阴影 | `coreShadow(.medium)` | 白底压在浅色玻璃上时靠它分层。⚠️ shadow token 是 asset catalog 色，macOS `swift test` 腿上解析为全透明 ⇒ 没有任何位图判据依赖它 |
| 文案 | 放在「指示器右侧剩余区域」居中：左留白 = 指示器 + 2×间距，右留白 = 2×间距（RTL 下经 `.leading` / `.trailing` 自动镜像）；底色 `contentSecondary` | 待命时不与指示器重叠；拖动时透明度 = 1 − 位移 / 全程，执行阶段（位移 = 全程）为 0 ⇒ 文案隐去 |
| 流光 | 文案的前景是一段线性渐变：`contentSecondary → contentPrimary → contentSecondary`，高光带宽为文案宽的 0.6，每 2.4 s 从起点一侧外沿扫到另一侧外沿 | 不用 `.mask`：渐变直接作前景样式，不引入遮罩点位与位移调用点。方向朝指示器前进的方向，RTL 下从右往左——⚠️ SwiftUI **不**按布局方向镜像渐变的 `UnitPoint`（macOS 实测：同一中心值在 LTR / RTL 下高光落在同一位置），所以方向由 `SlideToConfirmShimmer.bandCenter(progress:layoutDirection:)` 自己换算 |
| 禁用 | 整个控件不透明度 0.4（同 `.circularGlass` / `.pressableCard` 的禁用值），不画流光 | |

流光的开关是一个纯函数 `SlideToConfirmShimmer.sweeps(...)`：**同时**满足「两道闸裁出 `.animated`、启用、
待命阶段、文案在屏」才扫；任一条不满足就不建 `TimelineView`（不是建了再暂停）。两道闸走库里共享的裁决点
`EnergyState.presentation(reduceMotion:)`：能耗闸在前（场景不活跃 ⇒ `.hidden`），Reduce Motion 在后——
后者取自 `coreMotionPresentation`（不直接读 `accessibilityReduceMotion`，核心库动效纪律要求如此，
测试的 `coreMotionPresentationOverride` 也因此照样生效）。本文件因此登记进
`MicroInteractionReduceMotionGuard.energyGatedFiles`。低电量下按 `RenderPolicy.minimumInterval` 降到 15 fps。
「在屏」由文案容器上的 `onAppear` / `onDisappear` / `onScrollVisibilityChange` 维护。

### 动效与 Reduce Motion

- 指示器位移（回弹、回位）走 `CoreMotionToken.reveal.transformAnimation(for:)`：`.smooth` 族弹簧
  （按定义 bounce 为 0），Reduce Motion 下为 `nil` ⇒ **直接到位**。拖动中的跟手位移不补间。
- **流光**是常驻循环动效：`TimelineView(.animation)` + 按时间线性推进的纯相位函数（与 `Skeleton` 扫光、
  `.spinning(presentation: .topBar)` 同一先例；`CoreMotionToken` 没有循环档，不引入曲线字面量）。
  Reduce Motion 下**不画流光**（文案静止为 `contentSecondary`），禁用 / 执行 / 回位 / 场景不活跃 / 离屏同样不画。
- 指示器内「箭头 ↔ 进度」的切换是纯淡变（`CoreMotionToken.press.animation(for:)`），
  包围盒不变，Reduce Motion 下保留淡变（与库内淡变类先例一致）。
- **触觉**：确认与回弹两处，`.sensoryFeedback` 给不同反馈（确认 `.impact(weight: .heavy)`、
  回弹 `.selection`）。只由拖动手势产生——无障碍激活不给确认触觉；
  被打断不给回弹触觉。Reduce Motion 不影响触觉。

### 无障碍

- 整个控件经 `.accessibilityRepresentation` 暴露为一个普通 `Button`：
  - **角色**：按钮；**名称**：调用方的 label；
  - **状态**：执行阶段 `accessibilityValue` 为 `Loading`，其余阶段为空值；
  - **禁用语义**：执行 / 回位阶段 `.disabled`，宿主 `.disabled` 经环境值继承；
  - **激活**：与手势共用同一道门闩（上表）。
- ⚠️ Apple 明确 `accessibilityRepresentation` 会**完全替换**原有无障碍表示，
  所以状态、名称、禁用语义都写在替代 `Button` 上，不指望从视觉子树继承。
- 替代表示是**恒定**的同一个 `Button`（不按阶段条件式挂载）⇒ 阶段切换不换元素身份，
  焦点留在原处。
- **操作提示**：替代 `Button` 带 `accessibilityHint`「Double-tap to confirm」（本地化键已注册）——
  名称是「Slide…」这类文案，只读名称会误导辅助技术用户去找滑动手势。
- 进入执行播报 `Loading`；action 返回播报 `Success` / `Failed`；取消与首帧不播。

### RTL

- 按 `Rating` / `CoreDisclosureGroupStyle` 的先例做真正的镜像，不再把组件内部钉成 `.leftToRight`；
  label 继承宿主方向，箭头用 `chevron.forward`（随方向翻转）。
- 实测（iOS 26.4 模拟器，`-AppleTextDirection YES -NSForceRightToLeftWritingDirection YES`，
  在手势回调里临时打印）：RTL 下向左拖 160 pt，`translation.width` 读到 **−160**，`location.x` 同向递减
  ⇒ `DragGesture` 的位移与位置**不镜像**，按物理方向计。所以手势一侧乘方向系数（RTL 为 −1），
  起点横坐标换成 `width − x`。
- 与之相反，`.offset(x:)` **会**被镜像：RTL 渲染判据第一版把渲染位移也乘了 −1，执行帧里指示器
  被推出画面、找不到指示器而判红 ⇒ 渲染侧直接用逻辑位移。

## API

```swift
public init(
    action: @escaping @MainActor @Sendable () async throws -> Void,
    @ViewBuilder label: () -> Label
)

// Label == Text 便利重载（文案参数是 LocalizedStringKey）
public init(_ titleKey: LocalizedStringKey, action: @escaping @MainActor @Sendable () async throws -> Void)
```

- 无 Bool 入参。尺寸读环境 `controlSize`：指示器直径取 `CoreControlMetrics.height(for:)`
  （`.regular` 为 44 pt），间距 `CoreSpacing.xs`，轨道高 = 指示器 + 2×间距；宽度撑满父视图提议。
- 强调色读 `coreAccent`：箭头与执行中的进度（仅 iOS）取它，对比不足 3:1 时退回墨色（指示器底色恒为浅色岛里的 `surfaceRaised`，见上方《外观》）；
  `coreAccentOn` 不参与。轨道 Liquid Glass，文案 `contentSecondary` + 流光，禁用时整体不透明度 0.4。
- label 同时是轨道上的提示文案与无障碍按钮的名称。

阈值判定在源码里就是这一句，上方的注释逐字为
`// 不要加 predictedEndTranslation 速度补偿：高代价确认不该因甩得快而降低门槛。`
（`Sources/OhMyDesign/Components/SlideToConfirm/SlideToConfirm.swift`）。

## 判据覆盖面

测试在 `Tests/OhMyDesignTests/SlideToConfirmTests.swift` 与 `SlideToConfirmRunnerTests.swift`
（类型名 `SlideToConfirmTests` / `SlideToConfirmRunnerTests` / `SlideToConfirmInFlightTests`）。

- **阈值（纯函数）**：正例（恰为全程、超过全程）与四个负例——快速甩到一半（预测终点取整宽的 1 倍多、
  4 倍与 ∞）、反向拖动、阈值前 0.5 / 1 / 4 pt、拖到底后被打断；未量到宽度时不触发。
- **夹紧**：12 个输入（含 ±∞、NaN）的位移全部落在 `[0, travel]`。
- **门闩与事件表**：运行号门闩的准入 / 拒绝 / 只认本次运行号；回位阶段的激活与滑到底都被拒；
  动效键只在离散事件上变（拖动变化不变 ⇒ 跟手不补间）。「门闩不读阶段」是设计定案，**没有**判据钉着它。
- **拖动会话**：指示器命中区的边界；起点在轨道空白处的会话不位移、不触发、不给触觉、不改动效键；
  门闩关闭期间开始的会话、被无障碍激活作废的会话，开闸后继续拖再松手都不触发；
  打断先于松手到达时松手仍按会话裁决判定。编排层另有两条：起点在空白处滑满全程不起 `Task`；
  执行中在尽头指示器上开始的拖动、开闸后才松手，action 仍只调起一次。
- **手势认领（纯函数）**：`SlideToConfirmPanArbitration.claims` 横向严格占主导才认领；纯纵向、正斜 45°、零位移都不认领。
  iOS 识别器经它裁决、位移从按下点算，这两处只有源码接线判据（下方「视图接线」）。
- **RTL**：纯函数层——向左滑满全程触发、向右不触发，右端是指示器起点、左端不是；
  渲染层——RTL 下待命指示器前沿在右半边，执行帧向左移约一个全程（±2 pt）。
- **编排（走真实 `SlideToConfirmRunner`）**：注入可控挂起的 action 与回位 sleep，
  不靠挂钟：滑到底 → 执行一次 → 回位停留 `reveal.duration` → 开闸；四个负例经编排路径不起 `Task`；
  手势 / 无障碍三种交错只执行一次；回位窗口不可再触发；抛错 → `failed`、取消 → `cancelled`，都开闸；
  执行中离屏 → action 收到取消、返回前再激活被拒、返回后开闸；Reduce Motion 下不停留。
- **触觉**：确认与回弹两种反馈互异；被打断、位移为 0 的松手、无障碍激活都不产生触觉事件。
  ⚠️ macOS 上 `.impact(weight: .heavy)` 与 `.impact(weight: .light)` 比较**相等**（实测两者都打印为
  `impactWeight(light, 1.0)`），所以回弹选 `.selection` 而不是轻档 impact。
- **播报**：走真实视图 + 记录型 poster：一轮成功 / 失败 / 取消的序列为
  `Loading, Success, Loading, Failed, Loading`；以执行阶段作首帧出现时不播。
  播报由独立的事件序号驱动，不从阶段差分推出——回位停留为 0（Reduce Motion）时
  「回位 → 待命」在同一次运行里连续发生、中间不渲染，按阶段差分会丢掉 `Success` / `Failed`。
- **渲染**：执行阶段指示器前沿比待命帧右移约一个全程（±2 pt）；同一待命态两次渲染在噪声以内相同
  （两帧都钉 `coreMotionPresentationOverride = .resting`，不受宿主 Reduce Motion 设置影响）。
  指示器寻址：**深色外观**下取「横向与纵向都连续近白 ≥ 14 pt」的像素里最小的横坐标——白色圆盘两个方向都满足，
  流光里的白色字形横向不够长、玻璃高光边纵向不够厚。浅色外观下白指示器与画布同色，找不到，所以渲染判据一律用深色。
- **外观**：文案区域在各档 `controlSize` × 五种宽度下都不与待命指示器重叠、宽度 = 全程 − 2×间距（纯函数）；
  执行阶段文案透明度为 0、回位后回到 1；箭头取色真值表（`.yellow` / `.white` / `.mint` 退回墨色，`.blue` / `.red` / 默认墨色不退）；流光开关真值表（经 `EnergyState.presentation(reduceMotion:)` 裁决：Reduce Motion / 场景不活跃 /
  场景在后台 / 禁用 / 执行 / 回位 / 离屏都关，低电量不关）；流光进度随时间线性、按周期回绕，高光带从外侧进、外侧出，RTL 反向；
  渲染层——同一进度下 LTR 高光质心在文案左半、RTL 在右半；动效开 + 场景活跃时两帧文案不同，Reduce Motion /
  禁用时两帧在噪声以内相同（只在 macOS 腿：iOS 单测宿主里动效开时两帧也相同，实测）；浅色岛里 `surfaceRaised` 与墨色对比 ≥ 7:1；深色外观下 `.coreAccent(.red)` /
  `.blue` 的指示器区各自偏红 / 偏蓝、默认墨色与 `.yellow`（退回墨色）下白底里有深色箭头像素（只数四个方向 14 pt 内
  都碰得到白色的深色像素——圆盘外接方框四角的深色画布不算），指示器之外两帧相同；
  源码接线——轨道上的 `.glassEffect`、流光开关的实参、只在开关为真时建 `TimelineView`、在屏状态的三处维护、
  指示器的浅色岛与 `coreAccent` 取色、禁用不透明度。
- **位移曲线（两级）**：接线级——源码里必须有
  `.animation(CoreMotionToken.reveal.transformAnimation(for: self.motionPresentation), value: core.motionKey)`
  这一行（下方「视图接线」）；值级——`reveal.transformAnimation(for: .animated)` 等于
  `.spring(duration: 0.25, bounce: 0)`。两级合起来才说明「回弹 / 回位用的是 bounce 为 0 的曲线」：
  接线级只核用了哪个 token，值级只核那个 token 的取值。
- **操作提示**：`Double-tap to confirm` 键已注册且取值逐字一致（值级）；替代 `Button` 挂着它（接线级）。
- **动画进行中（macOS 腿）**：驱动编排器、逐帧量指示器前沿（同上方的白色圆盘寻址，深色外观）：
  回弹与回位两个场景，RM 关时互异中间位置 ≥ 2 且没有任何一帧越出起止区间（容差 1 px），
  RM 开时中间位置为 0。起止前沿都要连续两次 settle 读数相同才采用（上限 10 次）：一次 settle 约 0.24 s，
  追不完 `reveal` 弹簧的尾巴，起点读早了，后续朝尽头的残余位移会被记成越界。iOS 腿上 `layer.render(in:)` 拍不到进行中的帧，这两条只在 macOS 腿跑。
  ⚠️ 「不越出起止区间」**分不出 `.smooth` 与 `.snappy`**：把 token 换成 `.press`（`.snappy`）后这两条照绿，
  没有观测到越界。它能抓的是明显的过冲，不是「选了哪一族曲线」。
- **视图接线（源码级）**：iOS 平移识别器的四处（`shouldReceive` 记按下点、`gestureRecognizerShouldBegin` 经 `claims`、
  位移从按下点算、`isEnabled` 随宿主）与它转交编排器的三路；macOS `@GestureState` + `updating`、带起点与方向系数的 `onChanged`、
  带预测终点样本的 `onEnded`、手势 `isEnabled` 只读宿主环境值、整条轨道的 `contentShape`、上面那行 `.animation`、
  `onChange(of: dragging)` 转交打断、`onDisappear`、`accessibilityRepresentation` 里的
  `Button` + `accessibilityHint` + `.disabled` + `accessibilityValue`。单测进程里合成事件驱动不了 SwiftUI 手势，
  无障碍树也观测不到（见 `stateful-button.md`《无障碍》已知缺口二的实测），这一层只能在源码上核。

### 模拟器实测（一次性，不是回归判据）

iOS 26.4 模拟器、预览宿主画廊 `slide-to-confirm` 页，`axe swipe` 发真实触摸、`axe describe-ui` 读无障碍树
（轨道 346 pt 宽 ⇒ 全程 294 pt；指示器起点中心 x = 54）：

| 操作 | 读数 |
|---|---|
| 进页面（待命） | `AXButton` / label `Slide to delete account` / value 空 / `enabled=True`；宿主 `.disabled` 那一行 `enabled=False` |
| 快速甩到一半（54 → 200，0.08 s） | `Confirmed 0` |
| 反向（54 → 5） | `Confirmed 0` |
| 阈值前一点（54 → 336，位移 282 < 294） | `Confirmed 0` |
| 滑到底（54 → 390），0.3 s 后读 | value `Loading`、`enabled=False` |
| 同上，约 3 s 后读 | value 空、`enabled=True`、`Confirmed 1` |

轨道整条吸收横滑之后的一轮（同一宿主；把画廊示例的 action 临时拉长到 6 s 以覆盖 axe 每次调用约
0.6–1 s 的间隔，实测后已还原）：

| 操作 | 读数 |
|---|---|
| 轨道空白处（x = 150）向右横滑到屏幕边，连做 3 次 | 页面未 pop，`Confirmed 0` |
| 对照：同样的横滑落在轨道上方的说明文字上 | 页面被 pop（说明 axe 的横滑确实会触发返回手势） |
| 滑到底（54 → 395），t = 0.72 s 读 | value `Loading`、`enabled=False` |
| 执行中：t ≈ 1.6 s 在尽头指示器上向右横滑、t ≈ 2.2 s 向左横滑、t ≈ 2.8 s 在轨道空白处向右横滑；t = 2.84 s 读 | 页面未 pop，仍 `Loading`、`Confirmed 0` |
| t = 7.18 s 读 | value 空、`enabled=True`、`Confirmed 1`；t = 9.52 s 再读仍为 1 |
| 甩一半 / 反向 / 阈值前一点（同上表三种） | `Confirmed 0` |
| 替代元素 | `help` 读到 `Double-tap to confirm` |

宿主 `.disabled`（直达预览 `PREVIEW_COMPONENT_ID=slide-to-confirm`，无导航栈；禁用那一行的 action
临时改成给计数加 100、实测后还原）：禁用行上从指示器起滑满全程两次，7.5 s 后 `Confirmed 0`；
对照同样的横滑落在可用行上 ⇒ `Confirmed 1`。

RTL（直达预览，伪语言启动参数）：向右横滑指示器、从轨道空白处向左滑满、从指示器向左甩一半都保持
`Confirmed 0`；从右端指示器向左滑满 ⇒ `Loading`，截图里执行中的指示器停在左端，约 7 s 后 `Confirmed 1`。

换成平移识别器之后的一轮（iOS 26.4 模拟器，专用设备；画廊 `slide-to-confirm` 页在 `ScrollView` 里，
页面最大滚动量约 207 pt；读「Slide to delete account」按钮的 y 坐标判滚动）：

| 操作 | `DragGesture` 构建 | 平移识别器构建 |
|---|---|---|
| 轨道空白处（x = 250）纵向上滑 | y 不变（351.7），页面**没滚** | y 351.7 → 144.3，页面滚动 |
| 轨道空白处纵向下滑（已滚到底后） | y 不变（144.3），连做 3 次 | y 144.3 → 351.7 |
| 指示器上（x = 54）纵向上滑 / 下滑 | 下滑 y 不变 | 351.7 → 144.3 → 351.7 |
| 对照：同样的纵滑起手于轨道外的文字 / 空白 | 页面滚动 | —— |
| 轨道空白处（x = 150）向右横滑，连做 3 次 | —— | 页面未 pop，`Confirmed 0` |
| 甩一半 / 反向 / 阈值前一点（54 → 336） | —— | `Confirmed 0` |
| 滑到底（54 → 395） | —— | 立即读 value `Loading`、`enabled=False`；3 s 后 `Confirmed 1` |
| 对照：同样的横滑落在说明文字上 | —— | 页面被 pop |
| RTL（直达预览）：右滑指示器 / 空白处左滑 / 从右端指示器左滑满 | —— | `0` / `0` / `Loading` → `Confirmed 1` |

## 已知缺口（如实登记）

- **Liquid Glass 轨道没有位图判据**：macOS `swift test` 腿的离屏渲染里玻璃一个像素都不画（实测轨道区域与画布
  逐像素同色），只有源码接线判据核「`.glassEffect` 挂在轨道上」；观感靠模拟器 / macOS 截图人工看。
- **流光依赖场景阶段**：能耗闸读 `\.scenePhase`，不在 SwiftUI `Scene` 里（例如测试宿主）时它不是 `.active`，
  流光不画——实测托管窗口里不注入 `scenePhaseOverride` 时两帧逐像素相同。纯 UIKit 宿主里嵌
  `UIHostingController` 的情形**未实测**。
- **macOS 上执行中的进度不跟随强调色**：系统圆形 `ProgressView` 在 macOS 上不响应 `.tint`，白底上是浅灰
  （评审读数约 `#A7A7A7`，对比约 2.4:1，本轮未复测）。库里没有可着色的不确定态进度（`CoreCircularProgressViewStyle`
  的不确定态同样回退系统 spinner），自绘要另起一套循环动效与 Reduce Motion 处置，本轮不做。
- **浅色外观下指示器与轨道的分层靠阴影**：白色指示器压在浅色玻璃上，边界主要由 `coreShadow(.medium)` 给出。

- **手势回调的先后没有视图层判据（macOS）**：「正常松手时 `onEnded` 先于 `@GestureState` 复位触发的
  `onChange`」按 SwiftUI 的更新顺序推断（iOS 改用平移识别器后，松手与取消是互斥的两个状态，不再有这个先后问题）；
  core 按两种顺序都能判定（打断只把会话标成已结束，裁决留给松手消费，有纯函数判据）。
  代价：若打断先到，指示器会先按打断回弹、再因松手进入执行 ⇒ **成功的一滑可能出现视觉回跳**。
  「手势被系统中途取消」没有在模拟器上构造出来，只有编排层判据。
- **「执行中开始、开闸后松手」没有真实触摸实测**：会话从尽头开始，要在开闸后仍以「位移 ≥ 全程」松手，
  直线横滑得从尽头再往前拖一个全程，出了屏幕；只有纯函数与编排层判据。
- **宿主 `.disabled` 时横滑会漏给返回手势**：手势随宿主禁用而停用，实测在导航栈页面里从禁用行的
  指示器向右横滑，页面被 pop（`DragGesture` 构建上测的；平移识别器同样随宿主停用，未复测）。action 不会被触发（见上方直达预览那一轮）。
- **辅助技术实读只到无障碍树**：上表读到了替代元素的角色 / 名称 / 状态 / 禁用；VoiceOver 实际朗读、
  语音控制 / 切换控制下的激活与焦点保持没有实测；硬件键盘可达性**另行验证**，
  不能由 `accessibilityRepresentation` 推出。
- **轨道以外的横滑仍归系统返回手势**：离屏会取消正在跑的 action（公开文档注释已写明）。
- **Dynamic Type**：文案 `lineLimit(1)`，AX 字号下长文案会被截断——轨道高度跟 `controlSize` 而不跟字号，
  这是有意的取舍；完整文案仍是替代按钮的名称，辅助技术读得到。
- **Reduce Motion 下的淡变**：指示器内箭头 ↔ 进度保留淡变，这是按「包围盒不变的淡变在 RM 下保留」
  的库内先例定的，不是遗漏。

## 使用示例 / Usage

```swift
SlideToConfirm("Slide to delete account") {
    try await api.deleteAccount()
}

// 自定义 label、换强调色与尺寸
SlideToConfirm {
    try await checkout.pay()
} label: {
    Label("Slide to pay", systemImage: "creditcard")
}
.controlSize(.large)
.coreAccent(.blue)

// 需要拿到错误本身：在 action 内处理后再抛出，控件照常回位并播报 Failed
SlideToConfirm("Slide to publish") {
    do {
        try await publish()
    } catch {
        self.errorMessage = error.localizedDescription
        throw error
    }
}
```

## 预览 / Preview

- 库内：`SlideToConfirm.swift` 里的 `#Preview("SlideToConfirm")`。
- 预览宿主画廊：`Button` 分类下的 `slide-to-confirm` 条目；快照
  `docs/snapshots/OhMyDesignPreview_Previews.swift_SlideToConfirm.png`。
