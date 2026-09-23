# SlideToConfirm

滑到底才触发的高代价动作确认（删除账户 / 支付这类）。形态是一条胶囊轨道 + 一个圆形指示器：
按住指示器拖到轨道尽头松手 ⇒ 执行 action；执行期间指示器停在尽头、内部换成进度指示；
action 返回后指示器回到起点。

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
| **待命**（含拖动中） | 跟手，夹在 `[0, travel]` | 箭头符号 | ✅ | ✅ |
| **执行** | 停在尽头 | 进度指示 | ❌ | ❌（替代 `Button` 为 disabled） |
| **回位** | 由尽头回到起点 | 箭头符号 | ❌ | ❌（替代 `Button` 为 disabled） |

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
| 待命 | 拖动变化 | 待命 | 位移 = `clamp(translation, 0, travel)`，不补间 |
| 待命 | 松手，位移 ≥ `travel` | 执行 | 准入、发运行号；确认触觉；起 `Task` 跑 action |
| 待命 | 松手，位移 < `travel`（含反向、甩一半） | 待命 | 弹簧回弹到起点、**不**触发；位移 > 0 时给回弹触觉 |
| 待命 | 手势被打断（系统取消 / 宿主中途 `.disabled` / 离屏） | 待命 | 回到起点，不触发、不给触觉——被取消的手势没有 `onEnded`，只有 `@GestureState` 复位 |
| 待命 | 无障碍激活 | 执行 | 同一道门闩；进行中的拖动会话作废 |
| 执行 | 拖动 / 松手 / 无障碍激活 | 执行 | 门闩关 ⇒ **忽略**，不排队 |
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
- **离屏**：取消在跑的 `Task`，但**不开闸**——取消只是请求，不响应取消的 action 仍在跑，
  此时开闸会让回屏后的滑动并发重入（与 `AsyncButton` 在 `Task` 的 `defer` 里才复位同理）。
  action 返回后回位等待随 `Task` 取消立即结束，门闩随之打开。
- **宿主 `.disabled`**：待命时手势不响应、替代 `Button` 为 disabled（`isEnabled` 环境值自然继承）、
  指示器与文案换成禁用配色；拖动中途被禁用 ⇒ 手势被取消 ⇒ 按「被打断」处理；
  执行中被禁用 ⇒ **不取消** action，照常回位，回到待命后保持禁用。
- **不引入隐式超时**：action 永不返回，控件就一直停在执行阶段（同 `StatefulButton`）。

### 动效与 Reduce Motion

- 指示器位移（回弹、回位）走 `CoreMotionToken.reveal.transformAnimation(for:)`：`.smooth` 族弹簧
  （按定义 bounce 为 0），Reduce Motion 下为 `nil` ⇒ **直接到位**。拖动中的跟手位移不补间。
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
- 进入执行播报 `Loading`；action 返回播报 `Success` / `Failed`；取消与首帧不播。
- RTL：轨道固定为左 → 右滑动（未做镜像）。

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
- 强调色读 `coreAccent`（指示器底色）与 `coreAccentOn`（指示器内前景，缺省按亮度自动选）；
  轨道 `secondaryFill`，文案 `contentSecondary`，禁用时换 `accentDisabled(from:)` / `contentDisabled`。
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
  动效键只在离散事件上变（拖动变化不变 ⇒ 跟手不补间）。
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
- **渲染**：执行阶段指示器前沿比待命帧右移约一个全程（±2 pt）；同一待命态两次渲染在噪声以内相同。
- **动画进行中（macOS 腿）**：驱动编排器、逐帧量指示器前沿（全帧近黑像素的最小横坐标）：
  回弹与回位两个场景，RM 关时互异中间位置 ≥ 2 且没有任何一帧越出起止区间（容差 1 px），
  RM 开时中间位置为 0。iOS 腿上 `layer.render(in:)` 拍不到进行中的帧，这两条只在 macOS 腿跑。
  ⚠️ 「不越出起止区间」**分不出 `.smooth` 与 `.snappy`**：把 token 换成 `.press`（`.snappy`）后这两条照绿，
  没有观测到越界。它能抓的是明显的过冲，不是「选了哪一族曲线」。
- **视图接线（源码级）**：`@GestureState` + `updating`、`onChanged`、带预测终点样本的 `onEnded`、
  `onChange(of: dragging)` 转交打断、`onDisappear`、`accessibilityRepresentation` 里的
  `Button` + `.disabled` + `accessibilityValue`。单测进程里合成事件驱动不了 SwiftUI 手势，
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
| 执行中在尽头指示器上再横滑 | 仍只 `Confirmed 1` |

## 已知缺口（如实登记）

- **手势回调的先后没有机器判据**：「正常松手时 `onEnded` 先于 `@GestureState` 复位触发的
  `onChange`」按 SwiftUI 的更新顺序推断，上表的模拟器正例说明这条路径在 iOS 26.4 上走得通；
  编排层按两种顺序都不出错设计（`release` 不要求拖动会话仍在）。「手势被系统中途取消」
  没有在模拟器上构造出来，只有编排层判据。
- **辅助技术实读只到无障碍树**：上表读到了替代元素的角色 / 名称 / 状态 / 禁用；VoiceOver 实际朗读、
  语音控制 / 切换控制下的激活与焦点保持没有实测；硬件键盘可达性**另行验证**，
  不能由 `accessibilityRepresentation` 推出。
- **RTL 未镜像**：轨道固定左 → 右（`layoutDirection` 在组件内部钉为 `.leftToRight`）。
  没有核实 `DragGesture` 的位移在 RTL 下是否已被镜像，所以不照参考实现乘方向系数。
- **轨道空白处的横滑会触发系统返回手势**：拖动手势只挂在指示器上。iOS 26 模拟器上用 `axe swipe`
  实测，在导航栈页面里从轨道空白处（指示器以外）向右横滑，页面被 pop；执行中发生时离屏会取消
  正在跑的 action（与 `AsyncButton` 同语义）。是否让整条轨道吸收横向拖动，本 issue 未处置。
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
