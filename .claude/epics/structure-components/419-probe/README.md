# `419-probe` —— spike 探针，**不是生产代码**

issue #419（Tree 实现路径三选一 + 键盘射程实测）的可复现装置。结论见
`../419-spike.md`；本目录只负责让那份结论里的每个数都能被重新跑出来。

- **不属于 Swift Package**：`Package.swift` 不引用它，CI 不构建它，任何源码守卫
  （`GuardScanRoots.allRoots`）都不扫 `.claude/`。
- **不要往这里加生产代码**，也不要从 `Sources/OhMyDesign/` 引用它。

## 它是什么

一个 `xcodegen` 生成的丢弃型工程，两个 app target（`TreeSpikeiOS` / `TreeSpikeMac`）
共用同一份 `Sources/`，依赖仓库自身的 `OhMyDesign` product（`project.yml` 里
`path: OHMYDESIGN_CHECKOUT`，由下方那条 `sed` 替换成 checkout 的绝对路径）。

app 由环境变量驱动，每次运行只跑一种模式，把逐条按键与状态快照写成
`events.tsv` / `state.json`，所以读数可以脚本核对，不靠肉眼看界面。

| 环境变量 | 作用 |
|---|---|
| `SPIKE_MODE` | `P-probe` / `P-textfield` / `A-auto` / `A-core` / `A-keys` / `A-inset` / `B-list` / `B-inscroll` / `B-sentinel` / `C-custom` |
| `SPIKE_CAPTURE` | `passthrough`（`onKeyPress` 返回 `.ignored`，可同时观察原生行为）或 `handled`（返回 `.handled`，用来测能否压制原生行为） |
| `SPIKE_EXPAND_DEPTH` | 启动时把展开集设成「展开到第 N 层」（根为第 1 层） |
| `SPIKE_PERSIST_ON_CHANGE` | 每次展开态变化就落盘，用于持久化实验 |
| `SPIKE_RESTYLE_NESTED` | 递归时重新 `.disclosureGroupStyle(.core)`，用于测样式重置 |
| `SPIKE_CONTAINER_FOCUS=0` | 不给容器 `.focusable()`，用来测原生控件自己能不能拿到焦点 |
| `SPIKE_LIST_FOCUS_ONLY=1` | 只给 `List` `.focused()` 而不给 `.focusable()` |
| `SPIKE_SENTINEL_ALWAYS_IGNORE=1` | 哨兵视图恒返回 `.ignored`，这样 Tab 不会被它吃掉 |
| `SPIKE_SELFDRIVE=1` | 仅 macOS：进程内合成 `NSEvent` 自驱按键。**只在屏幕锁屏、真 HID 不可用时用**，读数不可当平台事实（见 `../419-spike.md`「我自己犯的错」一节） |

## 怎么跑

```bash
CHECKOUT=$PWD                                      # 仓库 checkout（或 worktree）根
export SPIKE_ROOT=/path/to/a/scratch/dir           # 放 TreeSpike.xcodeproj 的地方
mkdir -p "$SPIKE_ROOT" && cp -R .claude/epics/structure-components/419-probe/. "$SPIKE_ROOT"/
cd "$SPIKE_ROOT"
sed -i '' "s|OHMYDESIGN_CHECKOUT|$CHECKOUT|" project.yml   # 把 local package 指回 checkout
xcodegen generate

# macOS 腿（需要屏幕已解锁 + 终端有「辅助功能」权限）
xcodebuild -project TreeSpike.xcodeproj -scheme TreeSpikeMac -destination 'platform=macOS' \
  -derivedDataPath dd-mac build CODE_SIGNING_ALLOWED=YES -IDEPackageEnablePrebuilts=NO
./hid-mac.sh A-keys passthrough 2 tab1 1 --env SPIKE_RESTYLE_NESTED=1

# iOS 腿
export SPIKE_UDID=$(xcrun simctl create spike-419 \
  com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro com.apple.CoreSimulator.SimRuntime.iOS-26-4)
xcrun simctl boot "$SPIKE_UDID"
xcodebuild -project TreeSpike.xcodeproj -scheme TreeSpikeiOS \
  -destination "platform=iOS Simulator,id=$SPIKE_UDID" \
  -derivedDataPath dd-ios build CODE_SIGNING_ALLOWED=NO -IDEPackageEnablePrebuilts=NO
./drive-ios.sh A-keys passthrough 2 base 0 SIMCTL_CHILD_SPIKE_RESTYLE_NESTED=1
./persist-ios.sh
xcrun simctl delete "$SPIKE_UDID"
```

`hid-mac.sh` 在 spike app 没能置前时**拒绝发键并退出 3**——否则按键会打进当前终端。

## 已知的探针自身缺陷

- `LAUNCH` 那行的 `source=expanded-persisted.json` 是写死的字符串：传了
  `SPIKE_EXPAND_DEPTH` 时展开集其实来自该环境变量，标签是假的。
  **持久化的证据是 `persist-ios.sh` 的 phase1/phase2 两段，不是这行标签。**
- `P-textfield` 模式的对照实验被 `TextField` 默认自动大写污染，结论不成立
  （`../419-spike.md`「我无法解释的」第 1 条）。
