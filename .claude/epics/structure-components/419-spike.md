# #419 spike：Tree 实现路径三选一 + 键盘射程实测

契约：`.claude/prds/timeline-tree-action-buttons.md` 的 **FR-2a**。
本文只产结论，**没有任何生产代码落进 `Sources/`**。可复现装置在
`419-probe/`（丢弃型探针，非 Swift Package 成员，CI 不构建，源码守卫不扫）。

## 0. 结论摘要

- **推荐路径：A（递归 `DisclosureGroup(isExpanded:)`）+ 自写键盘层**。
  理由一句话：A 免费拿到的「受控展开 / 默认展开到第 N 层 / 持久化复原」在两条腿上
  全部实测成立，而它唯一的缺口（零原生键盘）用的那层代码**与完全自定义路径逐字相同**
  ——本 spike 里 `A-keys` 与 `C-custom` 跑的就是同一个 `TreeKeyHandler`
  ⇒ 选 A 相对选 C 的净成本是 **0 行键盘代码**，净收益是不必手写行布局 / 缩进 / 展开动画。
- **硬下限四项（上下移动焦点、左右折叠展开、Space 切换选中、Enter 激活）在两条腿上全部满足**
  ——`A-keys` 与 `C-custom` 模式各自实测通过（iOS 真 HID + macOS 真 HID）。
  ⚠️ 但**完整的 W3C 左 / 右语义只验证了一半**：三分支里的第二支
  （→ 已展开时移到首个子节点、← 已折叠 / 叶子时移到父节点）本轮按键序列没触发到
  ⇒ 已写代码、**未验证**，实现期必须补单测（§3.2）。
- **B（`List(selection:)`）被否**，但**不是**因为「原生行为全都拿不到」：macOS 上它免费给了
  相当多（见 §2.4）。否掉它的是两条硬事实：(1) iOS 上它给 **0**；(2) 它**不能嵌进 `ScrollView`**。
- W3C 原文核实后**发现 PRD 有 4 处实质偏差**（§4），其中「`Shift+方向键` 扩展选区」
  和「单选模式下 Space 的职责」两条要改 PRD。

## 1. 实测环境与手法

| 项 | 值 |
|---|---|
| 工具链 | Apple Swift 6.3（`swiftlang-6.3.0.123.5`）/ Xcode 26.4（`17E192`） |
| macOS 腿 | Darwin 25.3.0，`defaults read NSGlobalDomain AppleKeyboardUIMode` = **2** |
| iOS 腿 | iPhone 17 Pro，iOS 26.4（`23E244`）模拟器，本次专建、跑完 `simctl delete` |
| iOS 按键注入 | `axe` 1.7.1 的 `key` / `key-combo` / `type`（模拟器真 HID） |
| macOS 按键注入 | `osascript` 驱动 System Events `key code`（真 HID 级 CGEvent 打进前台 app） |
| 观测量 | app 侧逐条写 `events.tsv`（每个到达 `onKeyPress` 的键 + 每次状态变化）与 `state.json`；iOS 另取 `axe describe-ui` 的无障碍树与截图 |

⚠️ **`onKeyPress` 一律返回 `.ignored`（`passthrough`）**，所以同一次运行里既能看到
「键有没有送到 app」，也能看到「原生控件拿它做了什么」。要测「能不能压制原生行为」时
才切 `handled`。

⚠️ **一条关于手法本身的事实，比任何读数都重要**：本次开工时用户屏幕是锁着的
（`ioreg -n Root -d1` 里 `CGSSessionScreenIsLocked=Yes`），窗口拿不到 key 状态，
真 HID 打不进去。我先用**进程内合成 `NSEvent` + `NSApp.postEvent`** 顶了一轮，
**得出了一个错的结论**（§6）。屏幕解锁后全部 macOS 读数用真 HID 重测。
⇒ **进程内合成事件不能代替真 HID**：`characters` / `charactersIgnoringModifiers` 是
调用方自己填的，菜单 key-equivalent 的路径也不一样。

`CGEvent.postToPid(getpid())` 那条路在锁屏 + 非前台下 **17/17 全部丢失**，不可用。

## 2. 三条路径对照

「证据」列里的 `run=` 指 `419-probe` 的一次运行（`<腿>-<模式>-<capture>-<tag>`）。
`KEY=n` 指该次运行里到达 `onKeyPress` 的按键条数（本次扫的是 18 个键位）。

### 2.1 受控展开 / 默认展开到第 N 层 / 持久化

| 问题 | A 递归 `DisclosureGroup` | B `List(selection:)` | C 完全自定义 |
|---|---|---|---|
| 展开态是调用方持有的 `Set<ID>`，**可读** | **能** | **能**（同 A，层级同样由递归 `DisclosureGroup` 表达） | **能** |
| **可写**（UI 操作写回调用方 `Set`） | **能**，逐层实测：`axe tap --id row-alpha` → `EXPAND alpha -> true set=["alpha"]`；再 `--id row-alpha-one`（第 2 层）→ `set=["alpha","alpha-one"]`（`run=ios-persist` phase1） | **能**，且 macOS 原生左右箭头也会写它：`EXPAND alpha -> true set=["alpha"]`（`run=hid-B-sentinel-passthrough-tab2d1` 第 13–14 行） | **能**，右箭头 → `EXPAND alpha-one -> true`（`run=ios-C-custom-passthrough-base` 第 9–10 行） |
| 默认展开到第 N 层 | **能**。同一份树、只改 `SPIKE_EXPAND_DEPTH`：depth1 → `expanded=[]`、可见 3 行；depth2 → `["alpha","gamma"]`、可见 6 行；depth3 → `["alpha","alpha-one","gamma"]`、可见 8 行（`run=ios-A-core-passthrough-{depth1,base,depth3}`） | 同 A | 同 A |
| 持久化并复原 | **能**。phase1 点开两层后落盘 `["alpha","alpha-one"]`；phase2 **不传** depth 重启 → `LAUNCH restored expanded=["alpha","alpha-one"]`，`visibleRows` 恢复到 3 层 8 行（`run=ios-persist`） | 同 A | 同 A |

⇒ **三条路径在「受控展开」这一维上没有差别**。`OutlineGroup` 被排除的那三件事
（默认展开到第 N 层 / 程序化展开 / 持久化）三条路径都能做。

**`OutlineGroup` 的排除本 spike 独立核实过，而且拿到了比文档更强的证据**：
iOS 26.4 SDK 的 `SwiftUI.swiftinterface` 里 `OutlineGroup` 共 **8 个 public init**
（`_root:children:content:` / `_data:children:content:` 各 ×（有无 `id:`）×（值 / `Binding`）），
**没有任何一个带展开态参数**。
文件：`$(xcrun --sdk iphonesimulator --show-sdk-path)/System/Library/Frameworks/SwiftUI.framework/Modules/SwiftUI.swiftmodule/arm64-apple-ios-simulator.swiftinterface`，
`OutlineGroup` 的 8 个 init 分布在第 3120/3121、3127/3128、3146/3147、3153/3154 行
（四个 `extension` 块，块首分别在 3119、3126、3145、3152）。

### 2.2 免费拿到的原生行为（逐项，不整体表态）

| 原生行为 | A 递归 `DisclosureGroup` | B `List(selection:)` | C 完全自定义 |
|---|---|---|---|
| 展开 / 折叠**动画** | 有，但**不是系统的**：`.core` 样式下动画由 `CoreDisclosureGroupStyle` 自己 `withAnimation(CoreMotionToken.reveal…)` 驱动；`.automatic` 下才是系统的（PRD 已登记，本 spike 未另测动画曲线） | 同 A（层级仍由 `DisclosureGroup` 表达） | **无**，要自己写 |
| chevron | 有，`.core` 下是自绘 `chevron.forward` + `.tint`；`.automatic` 下是系统的。**两者肉眼可分**：`run=ios-A-core-passthrough-base` 截图里第 1 层 chevron 是蓝色（`.core`）、第 2 层是黑色 + label 变蓝（系统 `.automatic`） | 同 A | **无** |
| 无障碍**播报展开态** | **`.core` 下有，`.automatic` 下没有**（实测方向与直觉相反，见下方⚠️） | 同 A | **无** |
| 行选择高亮 | **无** | **有**（macOS；iOS 需 edit mode，本 spike 未测 edit mode） | **无** |
| 键盘（iOS 26） | **无**（`KEY=18` 全部穿透、`expanded` 不变，`run=ios-A-auto-passthrough-base`） | **无**（详见 §2.4） | **无** |
| 键盘（macOS 26） | **无**（`KEY=18` 全部穿透、`expanded` 不变，`run=hid-A-auto-passthrough-base`） | **有相当多**（详见 §2.4） | **无** |

⚠️ **无障碍播报展开态：系统 `.automatic` 样式反而没有，`.core` 才有。**
`axe describe-ui` 逐节点对照（depth2，`row-alpha` 是展开的父节点）：

| 样式 | `row-alpha`（Button）的 `AXValue` |
|---|---|
| `.automatic`（系统） | `null`（`run=ios-A-auto-passthrough-base`） |
| `.core` | `"Expanded"`（`run=ios-A-core-passthrough-base`）；depth1 下同一节点为 `"Collapsed"`（`run=ios-A-core-passthrough-depth1`） |

`.core` 那一份来自 `CoreDisclosureGroupStyle` 里显式写的
`.accessibilityValue(isExpanded ? Text("Expanded"…) : Text("Collapsed"…))`。
⚠️ **但不要据此说「系统样式不播报展开态」**：`axe describe-ui` 的节点里**根本没有
traits 字段**（只有 `role` / `role_description` / `subrole` / `AXValue` / `custom_actions`），
所以「系统有没有加一个展开态 trait」这件事我**证不了否**，只能说 `AXValue` 为 `null`。
`docs/components/core-control-styles.md` 第 23 行登记的是「换皮后系统不再自动为这个自绘
`Button` 播报展开态，已显式补 `.accessibilityValue`（"Expanded" / "Collapsed"，走 `bundle: .module`）」
——**与本次读数逐项吻合**，本次只是把「已显式补」那半句测出来了。

### 2.3 ⚠️ A 的一条隐藏代价（本 spike 新发现，必须写进 plan）

**`DisclosureGroupStyle` 在 `configuration.content` 内部被重置回 `.automatic`
⇒ 嵌套的 `DisclosureGroup` 不继承外层自定义样式。**

控制实验（同一份代码、只切一个环境变量）：

| `SPIKE_RESTYLE_NESTED` | `row-alpha`（第 1 层） | `row-alpha-one`（第 2 层，折叠中） |
|---|---|---|
| 未设 | `AXValue="Expanded"` | `AXValue=None` |
| `=1`（递归时重新 `.disclosureGroupStyle(.core)`） | `AXValue="Expanded"` | **`AXValue="Collapsed"`** |

`run=ios-A-core-passthrough-base` vs `run=ios-A-core-passthrough-restyled`。
截图侧同向：未设时第 2 层是系统 chevron（黑色 + label 变蓝），设了之后与第 1 层一致。

⇒ **实现期必须在递归的每一层重新 `.disclosureGroupStyle(.core)`**。
失效方向是**静默**的：不加也能编译、也能展开，只是第 2 层起外观与无障碍值都悄悄换人。

### 2.4 B 的原生键盘：macOS 给得不少，iOS 给零

这一格花了最多功夫，因为**第一次测出来是「B 什么都不给」，那是焦点没进 `List` 的假象**。
判别装置：在 `List` 外面放一个自带 `onKeyPress` 的哨兵视图（`B-sentinel` 模式），
按 Tab 次数决定焦点落在哪，靠**按键日志里的 `site=` 字段**读出焦点到底在谁身上。

**macOS，焦点在 `List` 内部**（`run=hid-B-sentinel-passthrough-tab2` 与 `-tab2b`，**2/2 复现**；
`-tab2d1` 是全折叠起点的补测）：

| 键 | 原生做了什么 | 键还到得了 `onKeyPress` 吗 |
|---|---|---|
| ↓ / ↑ | **移动单选**（`LIST_SEL ["alpha"]` → `["alpha-one"]` → `["alpha"]`），选择跟随焦点 | 到 |
| → | **展开折叠中的父节点**，并写回调用方 `Set`（`EXPAND alpha -> true set=["alpha"]`）；已展开时无动作 | 到 |
| ← | **折叠已展开的父节点**（`EXPAND alpha -> false set=[]`） | 到 |
| **Space** | **切换展开**（`EXPAND alpha -> true`）——⚠️ **与 W3C 推荐模型相反**（原文是切换选中） | 到 |
| Shift+↓ / Shift+↑ | **扩展 / 收缩选区**（`["alpha","alpha-one"]` → `["alpha"]`） | 到 |
| 字母 | **原生 type-select**（`g` → `LIST_SEL ["gamma"]`） | 到 |
| **Cmd+A** | **全选**（`LIST_SEL` 变成全部 6 项） | ❌ **到不了**——日志里没有 `mods=[command]` 那一条 |
| Ctrl+A | 有副作用（选择移到 `alpha-one`） | 到 |
| Home / End | **无动作** | 到 |
| Enter | **无动作** | 到 |

**能不能压制？** 切 `SPIKE_CAPTURE=handled`（`run=hid-B-sentinel-handled-tab2h2`）：
18 键全部 `decision=handled`，而 `EXPAND` / `LIST_SEL` 的原生副作用**全部消失**
——只剩一条 `LIST_SEL ["alpha","beta","gamma"]`，正是那个键事件拿不到的 **Cmd+A**。
⇒ **除 Cmd+A 外，B 的原生行为都能被 `onKeyPress` 返回 `.handled` 覆盖；Cmd+A 覆盖不了。**
（Cmd+A 只在焦点落在 `List` 内时被吃掉；落在普通 `.focusable()` 视图上时它正常送达
——`run=hid-B-sentinel-passthrough-tab1` 第 17 行、`run=hid-P-probe-passthrough-base` 第 14 行。
合理解释是 SwiftUI 默认 Edit 菜单的 Select All 只在第一响应者能 `selectAll:` 时才生效，
但这条解释**我没有独立验证**。）

**iOS，同一套装置**（`run=ios-B-sentinel-passthrough-tab{0,1,2}`）：

- Tab **一次也没把焦点移出哨兵**：三次运行里全程没有一条 `SENTINEL focused=false`，
  18–20 个键**全部** `site=sentinel`。
- `expanded` / `listSelection` 全程不变，`LIST_SEL` 事件 **0** 条。
- 另两种给焦点的写法也一样：外层 `.focusable()` + `.focused()` → `KEY=18` 全部穿透、
  `listSelection` 不变（`run=ios-B-list-passthrough-focused`）；只给 `.focused()` 不给
  `.focusable()` → `KEY=0`（`run=ios-B-list-passthrough-listfocus`）。

⇒ **iOS 26 上 `List(selection:)` 的行既不在 Tab 焦点链上，也不响应任何硬件键盘导航 / 选择。**
（本机 Full Keyboard Access 未开——这是默认值；开了之后如何，未测，见 §7。）

### 2.5 容器嵌套

| 问题 | A | B | C |
|---|---|---|---|
| 能嵌进 `ScrollView` / `VStack` | **能**。A 的三个模式全部跑在 `ScrollView { VStack { … } }` 里，渲染与按键读数正常 | **不能**。`run=ios-B-inscroll-passthrough-embed`：`List` 外面套 `ScrollView` 后，**无障碍树里一条树行都没有**，只剩上下两个哨兵文本，`y=92` 与 `y=129` ⇒ `List` 被压成约 17pt、什么都没画 | **能** |
| 与 `InsetGroupedSection` 并存 | **能**，但有代价。`run=ios-A-inset-passthrough-embed`：树整棵进了 `InsetGroupedSection`，section header 与下方 sibling 文本（`y=283`）都在。⚠️ 两条视觉代价：叶子行（裸 `Text`）被**水平居中**（`row-beta` 的 frame 是 `x=184 width=35`，其余行 `x=11/23`），分隔线只插在**顶层**行之间 ⇒ 树行必须自己 `.frame(maxWidth: .infinity, alignment: .leading)` | **推论：不能**（由上一行实测的「`List` 不能进 `ScrollView`」推出，**本身未单独实测**） | **能** |
| 直接作原生 `List` 行 | 能（A 的 `DisclosureGroup` 本来就能住在 `List` 里，B 模式就是这么搭的） | 它**就是** `List` | 能 |

### 2.6 硬下限四项可达性

| 路径 | iOS | macOS |
|---|---|---|
| A + 自写键盘层（`A-keys`） | **4/4**（`run=ios-A-keys-passthrough-base`） | **4/4**（`run=hid-A-keys-passthrough-tab1`） |
| C（`C-custom`） | **4/4**（`run=ios-C-custom-passthrough-base`） | **4/4**（`run=hid-C-custom-passthrough-tab1`） |
| B 靠原生 | ❌ **0/4**（iOS 什么都没有） | **2/4**：↓↑ ✅（移动的是单选，选择跟随焦点）、←→ ✅、**Space ❌**（做的是切换展开，不是切换选中）、**Enter ❌**（无动作） |

`A-keys` 与 `C-custom` 用的是**同一个** `TreeKeyHandler.handle(_:state:rows:focus:setFocus:site:)`
（`419-probe/Sources/SpikePaths.swift`），两条腿逐条读数见 §3。

### 2.7 推荐路径与理由

**推荐 A（递归 `DisclosureGroup(isExpanded:)`）+ 自写键盘层。**

1. A 与 C 在「受控展开 / depth N / 持久化」上**实测无差别**（§2.1），所以这一维不构成取舍。
2. A 的键盘缺口与 C 的键盘缺口**一样大**（都是零），补它的代码**逐字相同**
   ——本 spike 的 `A-keys` 与 `C-custom` 共用一个 handler，两条腿逐项读数完全一致（§3.2）。
   ⇒ **选 A 不比选 C 多写一行键盘代码**，但少写行布局、缩进、展开动画与 chevron。
3. A 相对 C 的**唯一**额外风险是 §2.3 那条样式重置，**已定位、解法一行**
   （递归时重新 `.disclosureGroupStyle(.core)`），且有机器可读的判别量
   （第 2 层节点的 `AXValue` 从 `None` 变 `"Collapsed"`）。
4. B 被否于两条硬事实：**iOS 给 0**（§2.4）、**不能嵌进 `ScrollView`**（§2.5）。
   它在 macOS 上给的那些确实可观，但其中 Space 的语义**与 W3C 推荐模型相反**，
   而且要按 W3C 改就得返回 `.handled` 把原生行为全压掉（§2.4 已验证可压）
   ——压完之后剩下的仍是自己写一遍，等于 A/C 的键盘层，只是还背上了 `List` 的容器约束。

⚠️ **推荐不等于「原生外观」**：走 A 免费拿到的是**系统的展开态接口与嵌套能力**，
chevron 与展开动画来自 `CoreDisclosureGroupStyle`，不是系统原生（PRD 已定案的前提，本 spike 同向）。

## 3. 键盘射程逐项实测

两条腿都是**真 HID**。`onKeyPress(phases: .down)` 挂在树容器上，行用
`.focusable()` + `.focused($focus, equals: id)`。

### 3.1 按键**送达** `onKeyPress` 的情况

| 键位 | iOS 26.4（`axe`） | macOS 26（System Events） | 备注 |
|---|---|---|---|
| ↓ / ↑ | ✅ `mods=[]` | ✅ **`mods=[numericPad]`** | ⚠️ **macOS 方向键自带 `.numericPad`** ⇒ 判「没按修饰键」**不能**写 `press.modifiers.isEmpty` |
| ← / → | ✅ `mods=[]` | ✅ `mods=[numericPad]` | 同上 |
| Home / End | ✅ `mods=[]` | ✅ `mods=[]` | 两端一致，**不带** `numericPad` |
| Space | ✅ `chars=" "` | ✅ `chars=" "` | |
| Enter | ✅ `chars="\r"` | ✅ `chars="\r"` | |
| Shift+↓ / Shift+↑ | ✅ `mods=[shift]` | ✅ `mods=[shift+numericPad]` | |
| Ctrl+A | ✅ `mods=[control] chars="a"` | ✅ `mods=[control] chars="a"` | |
| Cmd+A | ✅ `mods=[command]` | ✅ **除焦点在 `List` 内时**（§2.4） | |
| 字母（type-ahead） | ✅ | ✅ | |
| Shift+8（`*`） | ✅ 但 **`chars="8"` `mods=[shift]`** | ✅ **`chars="*"` `mods=[shift]`** | 两端**读数不同**，成因未定（§7 第 1 条） |
| Shift+G | ✅ 但 **`chars="g"`** | ✅ **`chars="G"`** | 同上 |
| F2 | ✅ `key=U+F705` | ✅ `key=U+F705` | 键**可达**，但重命名 UI 不在本 epic 范围 |
| Tab | ✅ 送达，但**焦点不动** | ✅ 送达，**且焦点会动** | iOS 上 Tab 三次都没移动焦点（§2.4） |

### 3.2 行为逐项达成情况（`A-keys` / `C-custom` 同一个 handler）

| 行为 | iOS | macOS | 证据（事件日志里的那一行） |
|---|---|---|---|
| ↓/↑ 移动焦点 | ✅ | ✅ | `FOCUS focus=alpha-one` → `alpha-two` → `alpha-one` |
| → 折叠时展开 | ✅ | ✅ | `EXPAND alpha-one -> true set=["alpha","alpha-one","gamma"]` |
| → 已展开时移到首个子节点 | ⚠️ 未验证 | ⚠️ 未验证 | handler 里有这一支（`moveFocus(to: i+1)`），但**本轮 18 键的固定序列没有触发它**——右箭头那一下落在折叠节点上 ⇒ **不能记成已支持** |
| ← 展开时折叠 | ✅ | ✅ | `EXPAND alpha-one -> false set=["alpha","gamma"]` |
| ← 已折叠 / 叶子时移到父节点 | ⚠️ 未验证 | ⚠️ 未验证 | handler 里有这一支（`setFocus(row.parentID)`），但**本轮序列没有触发它** ⇒ **不能记成已支持** |
| Home / End | ✅ | ✅ | `FOCUS focus=alpha` / `FOCUS focus=gamma-one` |
| **Space 切换选中** | ✅ | ✅ | `SELECT toggle gamma-one -> ["gamma-one"]` |
| **Enter 激活** | ✅ | ✅ | `ACTIVATE gamma-one` |
| Shift+↓/↑ 切换相邻项选中并移焦 | ✅ | ✅ | `SELECT toggle gamma -> ["gamma","gamma-one"]` + `FOCUS focus=gamma` |
| Ctrl+A / Cmd+A 全选 | ✅ | ✅ | `SELECT selectAll -> [全部 6 项]` |
| type-ahead（单字符） | ✅ | ✅ | `g` → `FOCUS focus=gamma-one` → 再按 `G` → `FOCUS focus=gamma`（轮转） |
| type-ahead **区分大小写 / shifted 符号** | ❌ | ✅ | iOS 上 `chars` 丢 shift（§3.1）⇒ 只能按 base 字符匹配 |
| `*` 展开同级 | ❌ | 可行但未实现 | iOS 上拿不到 `*` 字符 ⇒ 登记 Out of Scope（§5） |

⚠️ 上表两条「未验证」是**按键脚本的覆盖缺口**：handler 里有代码、类型上走得通，但本轮
18 键的固定序列没把焦点摆到能触发它们的位置。**它们不计入「已支持」，实现期必须补单测。**
⚠️ 这两条恰好是 W3C 右 / 左箭头三分支里的第二支（§4.4 的定案表要求它们）
⇒ **硬下限里「左右折叠展开」已验证，但完整的 W3C 左右语义只验证了一半。**

## 4. 选择模型定案（回 W3C 原文核实）

来源：<https://www.w3.org/WAI/ARIA/apg/patterns/treeview/>，2026-09-23 抓取，
"Keyboard Interaction" 一节。以下引号内均为**原文逐字**。

### 4.1 PRD 读法被原文**证实**的部分

- 两套模型确实互斥，推荐那套不需要修饰键：
  > "Selection in multi-select trees: Authors may implement either of two interaction models to support multiple selection: a recommended model that does not require the user to hold a modifier key, such as Shift or Control, while navigating the list or an alternative model that does require modifier keys to be held while navigating in order to avoid losing selection states."
- 推荐模型里 Space 的职责：
  > "Space: Toggles the selection state of the focused node."
- 普通方向键不改变展开态：
  > "Down Arrow: Moves focus to the next node that is focusable without opening or closing a node."
- `Ctrl+A` 全选：
  > "Control + A (Optional): Selects all nodes in the tree. Optionally, if all nodes are selected, it can also unselect all nodes."
- `Ctrl+Space` 确实属于**另一套**模型：
  > "Control + Space: Toggles the selection state of the focused node."（列在 "Alternative selection model" 之下）
- 叶节点上按右键：
  > "When focus is on an end node, does nothing."

### 4.2 与 PRD 现有描述的**实质差异**（以原文为准）

**D1 ⚠️「`Shift+方向键` 扩展选区」措辞不对。** 原文是 **toggle**，不是 extend：
> "Shift + Down Arrow (Optional): Moves focus to and toggles the selection state of the next node."

真正「扩展一段连续区间」的键是另一个，PRD 完全没提：
> "Shift + Space (Optional): Selects contiguous nodes from the most recently selected node to the current node."

⇒ PRD 该行应改成「`Shift+方向键`（可选）：移动焦点并**切换**目标节点的选中态」。
⚠️ 这不是措辞洁癖：`toggle` 在已选区里会**取消选中**，`extend` 不会
——本 spike 的 handler 实现的是 `toggle`，macOS `List` 原生做的是 `extend`（§2.4），两者行为可分。

**D2 ⚠️ 单选模式下 Space 在原文里**没有定义**，选择是 Enter 的职责。**
Space 只出现在 "Selection in multi-select trees" 之下。单选的职责原文交给 Enter：
> "Enter: activates a node, i.e., performs its default action. For parent nodes, one possible default action is to open or close the node. In single-select trees where selection does not follow focus (see note below), the default action is typically to select the focused node."

⇒ PRD 写的「**Enter 激活**（触发调用方的 action，与选择分开）」在**单选模式下与原文相左**
（原文说单选树里 Enter 的默认动作 typically 就是选中）。
PRD 的硬下限又要求 Space 切换选中 ⇒ **等价于在单选模式下也采用多选模型的按键分工**。
这是个可以做的决定，但**必须在 PRD 里写明是有意偏离 W3C 单选指引**，不能继续写成「契约取 W3C」。

**D3 ⚠️「初始焦点落在哪」不需要 PRD 另定，原文已定，且单选 / 多选不同：**
> "When a single-select tree receives focus: If none of the nodes are selected before the tree receives focus, focus is set on the first node. If a node is selected before the tree receives focus, focus is set on the selected node."
> "When a multi-select tree receives focus: If none of the nodes are selected before the tree receives focus, focus is set on the first node. If one or more nodes are selected before the tree receives focus, focus is set on the first selected node."

⇒ 多选是「**第一个被选中的**节点」，不是「任一被选中的」。

**D4 ⚠️ PRD 的「左 = 展开时折叠、已折叠时移到父节点」漏了叶节点与根边界，照它实现会在根上误移焦点：**
> "Left arrow: When focus is on an open node, closes the node. When focus is on a child node that is also either an end node or a closed node, moves focus to its parent node. When focus is on a root node that is also either an end node or a closed node, does nothing."

⇒ 三分支（不是两分支），且**根级**的叶 / 折叠节点上左键**什么都不做**。

### 4.3 其余原文要点（PRD 未写，建议补进 spec）

- `End` 有个限定词 `Home` 没有：
  > "End: Moves focus to the last node in the tree that is focusable without opening a node."
  > "Home: Moves focus to the first node in the tree without opening or closing a node."
  ⇒ End 是**最后一个可聚焦（即可见）节点**，不是数据里的最后一个。
- type-ahead 在原文里是 **recommended**、不是 optional，且含多字符连打：
  > "Type-ahead is recommended for all trees, especially for trees with more than 7 root nodes: Type a character: focus moves to the next node with a name that starts with the typed character. Type multiple characters in rapid succession: focus moves to the next node with a name that starts with the string of characters typed."
  ⇒ PRD 把 type-ahead 列为「可降级」与原文的 recommended 有落差；本 spike 实测 iOS 上
  只能做**不区分大小写的单字符**（§3.2），所以落差是实现约束造成的，要如实登记（§5）。
- `*`：
  > "* (Optional): Expands all siblings that are at the same level as the current node."
- 焦点与选择是两件事（PRD 的「两套独立状态」定案与原文同向）：
  > "in multi-select trees, which enable the user to select more than one item for an action, the selected state is always independent of the focus."
  > "It is important that the visual design distinguish between items that are selected and the item that has focus."
- 原文建议额外提供按钮，这条对本组件的 API 有影响：
  > "If selecting or unselecting all nodes is an important function, implementing separate controls for these actions, such as buttons for "Select All" and "Unselect All", significantly improves accessibility."
- alternative 模型的完整分工（PRD 只提到 `Ctrl+Space`）：
  > "Alternative selection model -- Moving focus without holding the Shift or Control modifier unselects all selected nodes except for the focused node"
  含 `Shift+↓/↑`、`Control+↓/↑`、`Control+Space`、`Shift+Space`、`Ctrl+Shift+Home/End`、`Ctrl+A`。

### 4.4 定案

**采用 W3C 推荐（无修饰键）多选模型**，并按 D1–D4 改 PRD：

| 键 | 定案行为 | 来源 |
|---|---|---|
| ↓ / ↑ | 移动焦点，不改变展开态、不改变选择 | 原文 |
| → | 折叠时展开（焦点不动）；已展开时移到首个子节点；叶节点无动作 | 原文三分支 |
| ← | 展开时折叠；**子级**的叶 / 折叠节点移到父节点；**根级**的叶 / 折叠节点无动作 | 原文三分支（修正 D4） |
| Home | 移到第一个节点 | 原文 |
| End | 移到**最后一个可见**节点 | 原文（修正含义，见 §4.3） |
| Space | 切换焦点节点的选中态 | 原文（推荐模型） |
| Enter | 激活（调用方 action），**与选择分开** | ⚠️ **有意偏离**原文单选指引，见 D2 |
| Shift+↓ / Shift+↑ | 移动焦点并**切换**目标节点选中态（可选） | 原文（修正 D1 措辞） |
| Ctrl+A / Cmd+A | 全选（可选）；范围按 PRD 已定案的「可见节点」 | 原文 + PRD |
| 初始焦点 | 无选中 → 第一个节点；有选中 → 单选落在被选节点、多选落在**第一个**被选节点 | 原文（补 D3） |

## 5. Out of Scope（实测做不到的，逐条写明做不到什么 + 证据）

1. **type-ahead 区分大小写 / 匹配 shifted 符号。**
   做不到什么：iOS 上无法从 `KeyPress` 拿到 shift 翻译后的字符。
   证据：iOS 真 HID 下 `Shift+8` → `chars="8" mods=[shift]`、`Shift+G` → `chars="g" mods=[shift]`。
   逐次数过：`chars="8" mods=[shift]` 出现在 **12 次** iOS 运行里、`chars="g" mods=[shift]`
   出现在 **11 次**（差的那一次是 `ios-P-probe-passthrough-base`，它跑在 `shift+g`
   这一步加进脚本之前）；覆盖 `P-probe` / `A-auto` / `A-core` / `A-keys` / `B-list` /
   `B-sentinel` / `C-custom` **7 个模式**，且 `axe key-combo` 与 `axe type` 两条注入路径读数相同。
   同一 API 在 macOS 真 HID 下给 `"*"` / `"G"`。
   ⇒ type-ahead 只做**不区分大小写的单字符**匹配。**成因未定，见 §7 第 1 条。**
2. **`*`（展开当前节点的全部同级）。**
   做不到什么：iOS 上判不出「用户按的是 `*`」——只能看到 `chars="8" mods=[shift]`，
   而这条组合在别的键盘布局上不是 `*`。证据同上。
3. **多字符快速连打的 type-ahead。** 未实测（本轮只发单字符），不做。
4. **`Shift+Space` 连续区间选择、`Ctrl+Shift+Home` / `Ctrl+Shift+End`。** 未实测，不做。
5. **用 Tab 把焦点送进 / 带出树（iOS）。**
   做不到什么：iOS 上 Tab 完全不移动焦点。
   证据：`run=ios-B-sentinel-passthrough-tab{0,1,2}` 三次运行、全程无一条
   `SENTINEL focused=false`，Tab 键本身送达但焦点不变；`run=ios-C-custom-passthrough-base`
   末行 Tab 后也没有新的 `FOCUS` 事件。
   ⇒ **iOS 上树的初始焦点只能程序化给（`FocusState`）**，不能指望 Tab。
6. **`F2` 重命名。** 键**可达**（两端都收到 `U+F705`），做不到的不是取键，是重命名 UI
   不在本 epic 范围 ⇒ 按 PRD 原样登记为 Out of Scope（**理由与 PRD 写的不同，PRD 里
   「除实测证明成本很低否则不做」的那个前提本 spike 已证伪：取键成本为零**）。
7. **macOS 上把 Cmd+A 改成别的语义（当焦点在 `List` 内时）。**
   做不到什么：该键事件根本不到 `onKeyPress`，返回 `.handled` 压不住。
   证据：`run=hid-B-sentinel-handled-tab2h2` 里 18 键全 `handled`，原生副作用全灭，
   只剩一条 `LIST_SEL [全部]` 来自 Cmd+A。**仅在 B 路径下成立**；A / C 路径不受影响
   （`run=hid-A-keys-passthrough-tab1` 第 29 行 Cmd+A 正常送达）。
8. **B 路径（`List`）整体。** 做不到什么：不能嵌进 `ScrollView`（`run=ios-B-inscroll-*`
   实测树行从无障碍树里整批消失），iOS 上零键盘行为（第 5 条 + §2.4）。
9. **「焦点与选择的关系在原生辅助技术里呈现成什么」——未回答。**
   本 spike 只取了 `axe describe-ui` 的**静态 AX 树**，**没有跑 VoiceOver**，
   也没有对选中态加 `.accessibilityAddTraits(.isSelected)` 并验证播报。
   ⚠️ PRD FR-2a 明确问了这一条，它**没有被本 spike 回答**，不要当已完成。

## 6. 我自己犯的错（登记，不抹掉）

- **错的结论**：屏幕锁屏期间改用进程内 `NSApp.postEvent` 注入，得出「macOS 上
  `command+a` 不会送到 `onKeyPress`（16/17 送达）」。
  **纠正**：屏幕解锁后用真 HID（System Events）重测，`command+a` 正常送达
  （`run=hid-P-probe-passthrough-base` 第 14 行；该次运行发 18 键、`onKeyPress` 收 18 键）。
- **同一机制下的第二个错**：合成事件报 `Shift+8` → `chars="8"`，被我一度读成
  「macOS 也丢 shift」。**纠正**：真 HID 下是 `chars="*"`。
  成因清楚：合成 `NSEvent` 的 `characters` / `charactersIgnoringModifiers`
  是我自己填的字段，**这个读数测的是我的代码，不是平台**。
- ⇒ 留一条教训在这里：`419-probe/` 的 `SPIKE_SELFDRIVE` 那条路**只在真 HID 不可用时**
  用来判「有没有一条通路」，**不能**用它的 `mods` / `chars` 字段下平台结论。

## 7. 我无法解释的 / 未核实的

1. **iOS 的 `KeyPress.characters` 为什么丢 shift。**
   现象：iOS 真 HID 下 `Shift+8`→`"8"`、`Shift+G`→`"g"`（`mods` 里有 `shift`），
   macOS 真 HID 下同一 API 给 `"*"`、`"G"`。iOS 侧 7 个模式、12 / 11 次运行、
   2 条注入路径（`axe key-combo` 与 `axe type`）读数一致（计数见 §5 第 1 条）。
   两个假设分不开：(a) UIKit/SwiftUI 的平台差异；(b) 模拟器 HID 注入层没做 shift 翻译。
   **我的对照实验失败了**：`P-textfield` 模式里 `axe type "gG*"` 打进 `TextField` 的是
   `" GG*"`——被默认自动大写污染，证不了 (a)/(b)；而 `axe key 10`（HID 字母键）对文本
   系统**根本没送字符**（只有 `axe key 44` 的空格进了字段），所以那条路也用不了。
   ⇒ 实现期按**保守**处置：type-ahead 与 `*` 都不依赖 `press.characters` 的大小写
   （§5 第 1、2 条）。要定案成因，得在**真机**上用**真键盘**复测一次。
2. **macOS 上「程序化初始焦点是否立即生效」不稳定，成因未查明。**
   同一份注入脚本、同一个 build：`P-probe`（18 键）与 `A-auto`（18 键）**0 个 Tab** 就收全；
   而 `C-custom`（**2/2 次**都是 0 键）、`B-list`（0 键）、`B-sentinel`（0 键）
   **0 个 Tab 收不到任何键**，补发一次真实 Tab 后立刻全部正常
   （`run=hid-C-custom-passthrough-{base,base2}` vs `-tab1`；
   `run=hid-B-sentinel-passthrough-tab0` vs `-tab1`）。
   我按「单个 `.focusable()`」vs「逐行 `.focused(_:equals:)`」分过一次，**分不开**
   （`B-list` / `B-sentinel` 的哨兵都是单个 `.focusable()` 却也收不到）。
   可能与脚本化激活（`open -n -a` + osascript 置前）而非真人点击有关，未证。
   ⚠️ 这条**没有影响任何结论**：所有「某路径做得到 X」的判定都是在按键确实送达的运行上做的；
   它影响的是「实现期 macOS 上树的初始焦点要不要额外兜一手」，那需要真人交互复测。
3. **`axe describe-ui` 的节点没有 traits 字段** ⇒ 「系统 `.automatic` 样式到底有没有给
   disclosure header 加展开态 trait」我**证不了否**（§2.2 的⚠️）。要定这一条得跑
   VoiceOver 或 `XCUIElement` 的 traits。
4. **macOS `AppleKeyboardUIMode`**：本机是 **2**（Tab 只到文本框与列表）。
   `=3`（全键盘访问）下，A 路径里 `DisclosureGroup` 自绘的 chevron `Button` 是否进 Tab 链
   **未测**——我不愿改用户的全局系统设置。本机值下的读数：`run=hid-A-auto-passthrough-tabin`
   （`SPIKE_CONTAINER_FOCUS=0` + 3 次 Tab）**0 键、`expanded` 不变**。
5. **iOS Full Keyboard Access** 默认关，开启后 `List` 行是否进焦点链、方向键是否生效，未测。
6. **macOS `List` 里 Space 的完整语义**：只在选择落在**父节点**上测过（切换展开）。
   落在**叶子**上时 Space 做什么，未测。
7. **展开动画曲线本身未测**：§2.2 那一行的「`.core` 的动画来自 `CoreMotionToken.reveal`」
   是读源码得到的，不是实测动画时长 / 曲线。
8. **`InsetGroupedSection` 里叶子行被居中**（`row-beta` frame `x=184`）——现象实测到了，
   成因（`Group(subviews:)` 的行布局还是裸 `Text` 没撑满）**未查**。
