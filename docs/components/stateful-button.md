# StatefulButton

四态动作按钮：`idle` / `loading` / `success` / `failure`。四态是**一个枚举**
（`StatefulButtonState`），不是四个 Bool ——任意两态互斥，Bool 组合能表达出
`loading && success` 这类无意义状态。

配件符号槽在 `idle` 时不存在，在三个非静息态各画一个不同的 SF Symbol；
槽的出现 / 消失让按钮宽度变化，走 `CoreMotionToken.press.transformAnimation(for:)`
（**布局类入口**，Reduce Motion 下为 `nil`）；槽内符号之间的切换走
`.contentTransition(.symbolEffect(.replace))`。

## API

```swift
// 自管模式 / Self-managed
public init(
    successDwell: Duration = StatefulButtonState.defaultDwell,
    failureDwell: Duration = StatefulButtonState.defaultDwell,
    action: @escaping @MainActor @Sendable () async throws -> Void,
    @ViewBuilder label: () -> Label
)

// 托管模式 / Host-managed
public init(
    state: StatefulButtonState,
    action: @escaping @MainActor @Sendable () async throws -> Void,
    @ViewBuilder label: () -> Label
)

// Label == Text 便利重载（文案参数是 LocalizedStringKey）
public init(_ titleKey: LocalizedStringKey, successDwell: Duration = …, failureDwell: Duration = …, action: …)
public init(_ titleKey: LocalizedStringKey, state: StatefulButtonState, action: …)
```

停留时长的默认值是 2 s，逐字取自源码
`nonisolated static let defaultDwell: Duration = .seconds(2)`
（`Sources/OhMyDesign/Components/Button/StatefulButton.swift`），与参考实现
Aceternity `stateful-button` 的 `delay: 2` 一致；两个停留时长可分别配置。

外观（形状 / 底色 / 内边距 / 前景色）完全由外层 `ButtonStyle` 决定
——`.solid()` / `.light()` / `.borderless()` / `.circularGlass` 都能用，
本组件自己只决定配件槽画哪个符号、槽多宽（槽宽取
`CoreControlMetrics.iconSize(for:)`，随 `controlSize` 变化）。

## 状态机

### 谁是视觉态的唯一写入方

| 模式 | 触发方式 | 视觉态的唯一写入方 | 组件会不会自己写 `loading` |
|---|---|---|---|
| 自管 | 不传 `state` | **组件** | 会 |
| 托管 | 传 `state` | **调用方** | **不会**，组件一次都不写 |

两种模式下**防重入门闩都由组件持有**，且门闩与视觉态是两份独立状态。

### 自管模式：事件 → 状态

| 当前态 | 事件 | 新态 | 说明 |
|---|---|---|---|
| `idle` | 点击 | `loading` | 门闩开 → 准入，发一个运行号 |
| `loading` | 点击 | `loading` | 门闩关 → **忽略**，不重入、不排队 |
| `loading` | action 正常返回 | `success` | 门闩开；随后停留 `successDwell` |
| `loading` | action 抛非取消错误 | `failure` | 门闩开；随后停留 `failureDwell` |
| `loading` | action 抛 `CancellationError` | `idle` | 静默，不给失败回执、不进停留 |
| `success` / `failure` | 停留结束 | `idle` | 只有**仍拥有显示权**的那次运行才复位 |
| `success` / `failure` | 点击 | `loading` | 门闩此时已开 ⇒ **立即开始新一轮**，旧停留被作废 |
| `loading` | 离屏（`onDisappear`） | `loading` | `Task` 取消 + 收回显示权；**门闩不开**，直到这次运行自己结束 |
| `loading`（已离屏作废） | action 结束（任意结果） | `idle` | 门闩开；结果不给回执、不进停留 |
| `loading`（已离屏作废） | 点击 | `loading` | 门闩仍关 → **忽略**（action 不响应取消时仍在跑，放行就是并发重入） |
| `success` / `failure` | 离屏 | `idle` | 停留随 `Task` 取消而中止，直接复位，不会卡在回执态 |

### 托管模式：事件 → 状态

| 事件 | 组件做什么 | 视觉态 |
|---|---|---|
| 点击（门闩开） | 准入，起 `Task` 执行 action | **不动**——由调用方在自己的 action 里写 |
| 点击（门闩关） | **忽略** | 不动 |
| action 结束（成功 / 失败 / 取消） | 只开门闩 | **不动** |
| 停留 | **不做**——停留与复位是调用方的事 | 不动 |
| 离屏 | `Task` 取消 + 收回显示权；门闩**仍关**到旧运行结束 | 不动 |

⇒ 托管模式下 `successDwell` / `failureDwell` 不起作用，因此那个 `init` 不收这两个参数。

## 防重入门闩

门闩是一个独立的值类型（`StatefulButtonGate`），只认自己发出的**运行号**，
**不读任何视觉态**。

这一条是刻意的：托管模式下视觉态由调用方写，如果拿它当门闩，调用方在 action 执行期间
把 `state` 改回 `.idle` 就能重入。判据 `StatefulButtonTests` 里那条
「门闩不看视觉态」逐一穷举了 5 种起始态（`nil` + 四个 case），每种都先准入一次、
再以 `host: .idle` 点第二次，必须全部被拒。

- **failure 能立即重试**：action 结束就开门闩，停留只是显示期 ⇒ 失败停留期间点击立刻重跑。
- **success 停留期间点击**同理：立刻开始新一轮，按钮当场回到 `loading`，
  上一轮的停留复位因为已失去显示权而不再生效。
- **连续点击不排队**：被忽略就是被忽略，不会在 action 结束后补跑一次。

## 取消、离屏与过期任务

继承 `AsyncButton` 的两条语义（逐字对照 `Sources/OhMyDesign/Components/Button/AsyncButton.swift`
的 `.onDisappear { self.task?.cancel() }` 与它对 `CancellationError` 的静默处置）：

- **离屏**取消在跑的 `Task`，并收回这次运行的显示权；
- action 抛 `CancellationError` **不**产生 `failure` 回执，自管模式下静默回 `idle`。

⚠️ **离屏不开门闩**。取消只是请求，不响应取消的 action 会继续跑；门闩只由这次运行自己结束时打开，
与 `AsyncButton` 在 `Task` 的 `defer` 里才复位同理。离屏后回屏、旧 action 仍未返回时点击会被忽略；
自管模式下此时如实显示 `loading`，旧运行结束后回 `idle`（不给回执）。

**过期任务的结果不能改变外观**：每次准入都拿一个递增的运行号，
写回视觉态之前先核这次运行是否仍拥有显示权。
所以「外部复位（离屏、或新一轮抢走显示权）之后旧任务才完成」时，
它的成功 / 失败结果与停留复位**都不生效**。

### 编排的判据覆盖面

点击 → 准入 → action → 落定 → 停留 → 复位、以及离屏的「取消 `Task` + 收回显示权」收在 internal 的
`StatefulButtonRunner` 里，视图只做两处接线（`Button` 的 action 与 `onDisappear`）。
`StatefulButtonRunnerTests` 注入可控挂起的 action 与停留 sleep，直接驱动编排器、不靠挂钟等待：
自管一轮走完上表、运行中离屏 action 收到取消且旧运行结束前再点被忽略、停留期间离屏立即回 `idle`、
托管模式不停留。

⚠️ 视图到编排器的两处接线**只有源码级判据**：单测进程里合成鼠标点击（`NSWindow.sendEvent`）
激活不了 SwiftUI `Button`（连一个普通 `Button` 都不行），无障碍树里也找不到它，无从按下。

## 超时

本组件**不引入隐式超时**——action 跑多久是调用方的事，promise 不 resolve 就一直 `loading`
（参考实现也是这个行为）。需要超时时在 action 内自己竞速、超时抛错 ⇒ 按钮进 `failure`，
停留结束后回 `idle`。

⚠️ **前提：被竞速的操作必须协作式响应取消。** `withThrowingTaskGroup` 在子任务抛错后会取消其余子任务，
但**要等它们全部结束才返回**。被竞速的操作若不理会取消，超时错误要等它自己跑完才抛得出来
——操作永不返回，按钮就永远停在 `loading`。`Task.sleep`、`URLSession` 的 async API 都响应取消：

```swift
StatefulButton("Upload") {
    try await withThrowingTaskGroup(of: Void.self) { group in
        group.addTask { try await upload() }   // upload() 必须在取消时尽快抛错返回
        group.addTask {
            try await Task.sleep(for: .seconds(10))
            throw UploadTimeout()
        }
        try await group.next()
        group.cancelAll()
    }
}
```

底层是回调式 API 时，用 `withTaskCancellationHandler` 把取消转给它自己的 cancel，
由它的完成回调（取消时也会回调一次）去 resume continuation。`CancelHandle` 处理
「取消先于回调式任务创建」的竞态：

```swift
import Synchronization

final class CancelHandle: Sendable {
    private let state = Mutex<(cancelled: Bool, action: (@Sendable () -> Void)?)>((false, nil))

    func install(_ action: @escaping @Sendable () -> Void) {
        let runNow = self.state.withLock { state in
            if state.cancelled { return true }
            state.action = action
            return false
        }
        if runNow { action() }
    }

    func cancel() {
        let action = self.state.withLock { state in
            state.cancelled = true
            defer { state.action = nil }
            return state.action
        }
        action?()
    }
}

func upload() async throws {
    let handle = CancelHandle()
    try await withTaskCancellationHandler {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            let task = legacyUploader.start { error in   // 恰好回调一次，取消时带取消错误
                if let error { continuation.resume(throwing: error) } else { continuation.resume() }
            }
            handle.install { task.cancel() }
        }
    } onCancel: {
        handle.cancel()
    }
}
```

⚠️ **不要**在 `onCancel` 里直接 resume continuation：底层回调之后还会再 resume 一次，
checked continuation 重复 resume 会崩溃。

操作既不响应取消、也没有 cancel 入口时，task group 竞速**给不出**超时。
能做的只有不等它：让它在 group 之外继续跑，超时即返回——但此时 action 已结束、门闩已开，
再点会与仍在跑的旧操作**并发**，这层防重入要调用方自己兜。

## 与 `AsyncButton` 的分工

`AsyncButton` **保留不动**。两者不是新旧关系：

| 需求 | 用哪个 |
|---|---|
| 只要「正在跑」的系统 spinner，结果不需要在按钮上留痕 | `AsyncButton` |
| 需要连续自转的 spinner | `AsyncButton` |
| 出错想自动弹 toast / 走 `onError` 回调拿到 `Error` | `AsyncButton` |
| 需要 success / failure 的视觉回执 | `StatefulButton` |
| 需要把视觉态交给调用方托管（例如态来自服务端推送） | `StatefulButton` |
| 需要「过期任务不改外观」这条保证 | `StatefulButton` |

`StatefulButton` **有意不引入常驻自转动效**：`loading` 用一个静态符号占配件槽，
好让 `loading → success` / `loading → failure` 成为一次真正的符号替换；
代价是 loading 期间没有连续运动。需要连续运动的场景走 `AsyncButton`。

`StatefulButton` 不转发 `Error`：想拿到错误本身就在 action 内 `catch` 处理完再 `throw` 出来，
失败态照样出现。

## 动效与 Reduce Motion

态切换驱动的是**宽度 / 布局**（配件槽出现或消失），所以动效入口必须是布局类的那一条：

```swift
.animation(CoreMotionToken.press.transformAnimation(for: self.motionPresentation), value: state)
```

- `transformAnimation(for:)` 在 `.resting` / `.hidden` 下返回 **`nil`** ⇒ 宽度**直接跳到位**。
  这与 #408 对 `anchoredBadge` 的定案同源，那里逐字写着「胶囊宽度也**不补间**（位数变化时
  直接跳到新宽度——补间等于横向位移，不该在 RM 下发生）」。
- ⚠️ **不要改回 `.coreAnimation(.press, value:)`**：那条入口走
  `CoreMotionToken.animation(for:)`，在 `.resting` 下返回的是**同时长 `easeInOut` 而不是
  `nil`**，宽度会照常补间。
  库内 5 处布局类动效（`AnchoredBadgeModifier` / `TagInput` / `TagGroup` /
  `UnderlinedTabBar` / `CoreDisclosureGroupStyle`）用的都是 `transformAnimation(for:)`。
  `.coreAnimation` 留给**颜色 / 不透明度**类（包围盒不变），例如 `TagGroup` 的选中态淡变。
- ⚠️ **不要把无障碍 modifier 写成 `if let … { content.accessibilityValue(v) } else { content }`**：
  那会产生 `_ConditionalContent`，`idle` ↔ 非 `idle` 时整棵 `Button` 子树换身份被重建，
  宽度过渡在 animated 下也不补间（配件槽直接出现）。`idle` 恒挂同一个 modifier、给空值。
- 触发值就是 `StatefulButtonState`，所以四个 case 两两不等是**判据保护的不变量**
  （`==` 若被改写成恒真，`.animation(_:value:)` 分辨不出任何两态、永不触发）。
- 符号槽内的切换走 `.contentTransition(self.motionPresentation.symbolReplacement)`，
  `.resting` / `.hidden` 下退化为 `ContentTransition.identity`。
- 该文件在 `CoreMotionTokenDisciplineGuard` 的台账里登记为 `.gated`，
  `contentTransition` 调用点另有逐点登记。

### 判据覆盖面

in-flight 采样（macOS 腿，`HostedWindow` + `cacheDisplay` 逐帧取「两端之外」的像素数）两条：

- `idle → loading`（宽度 / 布局过渡）：animated 臂 > 0（经 `observeControlMotion` 重试），
  resting 臂 == 0。摘掉动效入口、退回 `.coreAnimation`、把无障碍 modifier 改回条件分支、
  把 `==` 改成恒真，都会让它判红。它证的是「这次布局过渡有中间帧」，不单独区分宽度补间
  与配件符号的淡入——两者都会产生两端之外的像素。
- `loading → success`（符号替换）：resting 臂 == 0，animated 臂 > 0。
  ⚠️ 这条的 animated 臂读数偏低不代表「动得少」：符号替换特效画在 `cacheDisplay` 拍不到的层里，
  摘掉 `.contentTransition` 后读数反而上升（做过判别实验）。

iOS 腿上 `layer.render(in:)` 取的是模型层、拍不到进行中的帧，这两条只在 macOS 腿跑。

## 无障碍

- 角色：底层就是 `Button`，键盘 / 语音控制 / 切换控制的激活路径与普通按钮一致，
  且与触摸路径**共用同一道门闩**。
- 名称：调用方的 label（`accessibilityLabel`）。
- 状态：`accessibilityValue` 按态给出本地化文案——`idle` 给**空值**，
  `loading` / `success` / `failure` 分别是 `Loading` / `Success` / `Failed`
  （都已注册进 `Sources/OhMyDesign/Resources/en.lproj/Localizable.strings`）。
- 播报：每次进入 `loading` / `success` / `failure` 都经 `AccessibilityNotification.Announcement`
  主动播一次同一份文案（回 `idle` 与首帧不播）。不依赖「VoiceOver 会不会自动读焦点元素的
  value 变化」——那条没有证据，且焦点不在按钮上时一定读不到。托管模式下调用方写态同样触发。
  ⚠️ `Announcement` 是全局播报、不看焦点：托管模式下批量改多行的态会连播多次，
  这种场景不要用本组件。
- 配件符号 `accessibilityHidden(true)`——它是状态的视觉表示，语义已由 value 承担，
  再读一遍是重复。
- ⚠️ **已知缺口一**：`loading` 期间按钮**没有**被标成 disabled。这是与 `AsyncButton` 一致的
  选择（不谎报可用性），代价是辅助技术用户在 `loading` 期间激活按钮不会得到「被拒绝」的反馈
  ——他听到的是 value 仍为 `Loading`。
- ⚠️ **已知缺口二（判据覆盖面，如实登记）**：**没有任何机器判据验证 VoiceOver 实际读到了什么**。
  单测进程里 SwiftUI 的无障碍树观测不到——实测 macOS 的 `NSHostingView` 只给出
  `KeyViewProxy` / `_FocusRingView` 两个 `AXUnknown` 子节点、无 label 无 value；
  iOS 的 `_UIHostingView` 连子视图都没有、`accessibilityElementCount()` 恒为 **0**
  （同一份托管视图的位图渲染正常，所以不是「没渲染」）。成因未查明，
  最可能是 SwiftUI 只在进程里有 AX 客户端时才建这棵树，而单测进程没有。
  ⇒ 现有覆盖是四层**替代**判据，都不等于「辅助技术实读」：
  ① 态 → `Text` 的值级真值表（`idle` 在模型层无值，接线处补空值）；
  ② 三个键都已注册进 `Localizable.strings`（缺键时读到的是原始 key）；
  ③ 源码级接线判据（态文本接在 `Button` 整体上、由 `StatefulButtonState` 派生、
  配件符号 `accessibilityHidden(true)`）；
  ④ 播报判据：注入记录型 poster，驱动托管态走一串切换，核播报序列与文案逐项相等；
  另以三个非静息态各作首帧出现，核一次都不播（这两条是行为级的，不是源码 grep）。
  真正的实读验证（含「`idle` 的空 value 对 VoiceOver 是否等同于无 value」）需要 XCUITest
  或人工开 VoiceOver，本 issue 未做。

## 使用示例 / Usage

```swift
// 自管：一行接上业务动作
StatefulButton("Send message") {
    try await api.send(draft)
}
.buttonStyle(.solid())

// 停留时长按场景调
StatefulButton("Save", successDwell: .milliseconds(600), failureDwell: .seconds(3)) {
    try await store.save()
}

// 托管：态来自外部（例如服务端推送 / 全局 store）
StatefulButton("Deploy", state: self.deployState) {
    self.deployState = .loading
    do {
        try await deploy()
        self.deployState = .success
    } catch is CancellationError {
        self.deployState = .idle      // 离屏取消不是失败，别给 failure 回执
        throw CancellationError()
    } catch {
        self.deployState = .failure
        throw error
    }
}
```

## 预览 / Preview

- 库内：`StatefulButton.swift` 里三个 `#Preview`（自管四态 / 托管态 / 四态静息对照）。
- 预览宿主画廊：`Button` 分类下的 `stateful-button` 条目。
