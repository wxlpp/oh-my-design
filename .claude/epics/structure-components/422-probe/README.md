# `422-probe` —— Tree 键盘层的真 HID 装置，**不是生产代码**

issue #422 的键盘验证装置。手法与脚本**沿用 `419-probe`**（真 HID：iOS 走 `axe`、
macOS 走 System Events），差别只有三处：app 渲染的是**生产 `Tree`**、按键序列按
W3C 三分支重排、驱动脚本会在 `events.tsv` 里插 `# MARK <label>` 行，好把状态变化
逐条对回具体哪一下按键。

- **不属于 Swift Package**：`Package.swift` 不引用它，CI 不构建它，源码守卫不扫 `.claude/`。
- 观测量**只有公开绑定**：`expanded` / `selection` / `checked` / `onActivate`。
  焦点是 Tree 的内部状态，探针**看不到**——所以每一步「焦点移动」都靠紧跟其后的一次
  `Space`（切换焦点行的选中态）间接读出来。这是有意的：不为了观测去改公开 API。
- `ProbeRootView` 上挂了一个**哨兵** `onKeyPress`（恒 `.ignored`），只能分辨
  「键有没有送到 app」。⚠️ 它**分辨不了**「Tree 接没接」：两条腿实测哨兵（祖先）的
  handler **先于** Tree 的 handler 执行，且 Tree 返回 `.handled` 时哨兵照样收到
  （见下方《虚拟焦点形态的读数》）。要判 Tree 接没接，只能临时在 `Tree.swift` 的
  `onKeyPress` 里往 stderr 打一行（macOS 用 `open --stderr`，iOS 用
  `simctl launch --console-pty`），**不提交**。

## 怎么跑

```bash
CHECKOUT=$PWD                                   # 仓库 checkout（或 worktree）根
export PROBE_ROOT=/path/to/a/scratch/dir
mkdir -p "$PROBE_ROOT" && cp -R .claude/epics/structure-components/422-probe/. "$PROBE_ROOT"/
cd "$PROBE_ROOT"
sed -i '' "s|OHMYDESIGN_CHECKOUT|$CHECKOUT|" project.yml
xcodegen generate

# macOS 腿（需要屏幕已解锁 + 终端有「辅助功能」权限）
xcodebuild -project TreeProbe.xcodeproj -scheme TreeProbeMac -destination 'platform=macOS' \
  -derivedDataPath dd-mac build CODE_SIGNING_ALLOWED=YES -IDEPackageEnablePrebuilts=NO
PROBE_ROOT=$PWD ./hid-mac.sh run1 1          # 第二个参数是前奏 Tab 次数
python3 check.py out/mac-run1/events.tsv     # 逐步对预期表，输出 steps_ok=N/32

# iOS 腿
export PROBE_UDID=$(xcrun simctl create probe-422 \
  com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro com.apple.CoreSimulator.SimRuntime.iOS-26-4)
xcrun simctl boot "$PROBE_UDID"
xcodebuild -project TreeProbe.xcodeproj -scheme TreeProbeiOS \
  -destination "platform=iOS Simulator,id=$PROBE_UDID" \
  -derivedDataPath dd-ios build CODE_SIGNING_ALLOWED=NO -IDEPackageEnablePrebuilts=NO
PROBE_ROOT=$PWD ./drive-ios.sh run1
xcrun simctl delete "$PROBE_UDID"
```

`hid-mac.sh` 在 app 没能置前时**拒绝发键并退出 3**（否则按键会打进当前终端）。
实测它**会**真的触发：同一条命令连跑两次，第一次 `FRONTMOST=Terminal` 被拒，
第二次才成功——遇到就重跑一次。

## 本轮实测到的（macOS 腿，2026-09-23）

⚠️ **以下三条都是 macOS 真 HID 读数，iOS 腿本轮还没跑**（会话被打断）。

1. **macOS 方向键到达 `onKeyPress` 时 `modifiers.rawValue == 96`**
   （= `.numericPad` 32 | `.function` 64），Home / End / Space / Return 是 `0`。
   ⇒ `419-spike` 只登记了 `.numericPad`，**漏了 `.function`**；照那条写出来的黑名单
   （`subtracting([.numericPad, .capsLock])`）在真 HID 上让**每一个方向键**都落进
   「按了修饰键 ⇒ 交回系统」那一支，整条方向键静默失效。
   本轮因此把判据改成**白名单取交集**（只认 shift / control / option / command）。
   证据：`out/mac-run2/events.tsv` 里每一下方向键都只有一条 `SENTINEL … rawValue: 96`、
   没有任何 `EXPAND` / `SELECT`。
2. **逐行 `@FocusState` 的形态在 macOS 上会把键盘焦点整个丢掉。**
   run2 / run4 实测：`Tab` → 容器拿到焦点 → 第一下 `Space` 正常（`SELECT +["a"]`，
   即 W3C「无选中 → 焦点落第一个节点」这条规则生效），**但那一次赋值把 `@FocusState`
   移到行上之后，连哨兵都再也收不到任何键**（run4 的 `events.tsv` 在
   `P1-space` 之后只有 `# MARK` 行，一条 `SENTINEL` 都没有）。
   ⇒ 改成 **ARIA activedescendant 形态**：容器是唯一可聚焦元素（`.focusable()` +
   `.focused($isFocused)`），「焦点在哪一行」是 Tree 自己的 `@State`（虚拟焦点），
   行不再 `.focusable()`。**这条改动之后的 macOS 重测本轮没跑完**（见下）。
3. ~~`Space` 在旧形态下走的是 tap handler、不是键盘层~~ —— 原写「`Space` 既进了哨兵
   （说明 Tree 的 `onKeyPress` 没接它）又产生了 `SELECT`」，**括号里的推断实测为假**：
   哨兵先于 Tree 执行、且 Tree 接住后哨兵照样收到 ⇒ 这个观测在两种假设下相同，
   旧形态下 `Space` 到底走哪条通路**无法由它判定**。

## 虚拟焦点形态的读数（2026-09-23，两条腿）

`check.py` 逐步对下表（前奏 + 01–31 共 32 步，不计哨兵行）：

| 腿 | 运行 | `steps_ok` |
|---|---|---|
| macOS（System Events 真 HID） | 修复 chevron 热区前 6 次（其中 4 次插桩）、后 3 次（提交态代码 + 原版探针） | 8 次 **32/32**；**1 次 15/32**（见下） |
| iOS 26.4 模拟器（`axe` 真 HID） | 插桩 1 次 + 提交态 2 次 | 3 次 **32/32** |

- **Space / Enter 真的到了 Tree 的 `onKeyPress`**：插桩那两次（macOS / iOS 各一），stderr 里
  每一下 `Space` / `Return` / 方向键 / Home / End / Shift+↓ / Ctrl+A 都有 Tree 一行
  `result=handled`，`g` 与 `Tab` 是 `result=ignored`（交回系统）。
- **派发顺序**：同一条 stderr 流里，每一下键都是哨兵那行在前、Tree 那行在后。
- **修饰键**：macOS 方向键 `rawValue 96`、Home / End `64`、Shift+↓ `98`；iOS 方向键 `0`、Shift+↓ `2`，
  Ctrl+A 两端都是 `4`。
- **iOS 点一行会把键盘焦点交给容器**：插桩读数是 `tap select a` 紧接 `isFocused false->true`。
  变异：删掉 `select(_:)` 里的 `claimKeyboardFocus()` → 点击照样 `SELECT +a`，但之后
  **0 下键**到达（哨兵 0、Tree 0）⇒ 这一调用在 iOS 上起作用，且**没有单测能兜它**。
- **macOS 那 1 次失败**：新构建二进制的首次启动，前奏 `Space` 正常，第一下 `↓` 之后整个窗口
  再没收到任何键（哨兵也没有）。同一二进制随后再跑全部 32/32；成因**未查明**，也未复现。
- **iOS chevron 热区**：`describe-ui` 读出 chevron 按钮 frame 只有 12×7 pt，真点击偏离中心
  10 pt 就落到相邻的父行复选框上、把整棵子树的叶子**静默勾上**。已改为 24×44 的命中槽
  （`TreeDisclosureSlot`），复测槽内 5 个点全部落到展开 / 折叠上。

## 按键序列与预期（两条腿共用，前奏不同）

起点：`expanded = {a, c}`（depth 2），`selection = {}`，`mode = multiple`，
可见行 `[a, a1, a2, b, c, c1]`。前奏把焦点与 `selection` 收敛到「focus = a、sel = {a}」：
iOS 点一下 `row-a`（Tab 在 iOS 上不移焦点，419 spike 实测），macOS 一次 `Tab` + 一次 `Space`。

| 步 | 键 | 预期观测 | 对应契约 |
|---|---|---|---|
| 01–06 | ↓ Space ↓ Space ↑ Space | sel 依次 `{a,a1}` / `{a,a1,a2}` / `{a,a2}` | ↓↑ 只移焦点 |
| 07 | → | `EXPAND +a1` | → 折叠父节点展开、焦点不动 |
| 08–09 | → Space | sel `+a1x` | → **已展开时移到首个子节点**（419 spike 未验证的那一支） |
| 10–11 | → Space | sel `-a1x` | → 叶节点 does nothing（焦点不动） |
| 12–13 | ← Space | sel `+a1` | ← **子级叶节点移到父节点**（419 spike 未验证的那一支） |
| 14 | ← | `EXPAND -a1` | ← 已展开父节点折叠 |
| 15–16 | ← Space | sel `-a` | ← 子级折叠父节点移到父节点 |
| 17 | ← | `EXPAND -a` | ← 已展开父节点折叠 |
| 18–19 | ← Space | sel `+a` | ← **根级折叠节点 does nothing**（漏这支会在根上误移焦点） |
| 20–21 | End Space | sel `+c1` | End = 最后一个**可见**行 |
| 22–23 | Home Space | sel `-a` | Home = 首行 |
| 24 | Return | `ACTIVATE a` | Enter 激活，与选中分开 |
| 25 | Shift+↓ | sel `+b` | Shift+↓ 移焦 + 切换选中（可选项） |
| 26 | Ctrl+A | sel ∪ 全部可见行 | Ctrl/Cmd+A 全选可见（可选项） |
| 27–29 | End ↓ Space | sel `-c1` | ↓ 在最后一行 does nothing |
| 30 | g | **无事件** | type-ahead 未实现，键须交回系统 |
| 31 | Tab | **无事件** | 不吞 Tab |
