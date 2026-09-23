# Tree 密度与外观配置（#429）实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让 `Tree` 读 `controlSize` 变密、提供 `.automatic` / `.navigator` 两种外观预设（可复刻 VS Code Explorer）、
整行右键菜单，最后展平渲染换 `LazyVStack`。

**Spec:** `docs/superpowers/specs/2026-09-23-tree-style-design.md`（先读；本计划的「§」均指 spec 章节）。

**拆分（S-1）：4 个独立可合并的 PR**，每个都对 `epic/structure-components` 单独开、单独验证、单独评审。
顺序固定（后一个依赖前一个的合入态），不并行；`#423` 同批文件，本序列期间不并行开工。

| PR | 内容 | 公开 API 变化 |
|---|---|---|
| 1 | `controlSize` 密度（含 chevron 槽、复选框密度） | 无（行为变化：读 `controlSize`） |
| 2 | `TreeStyle` 配置 + `.navigator`（悬停、整行选中、参考线）+ 画廊 VS Code 示例 + 登记 / 文档 / PRD | `TreeStyle`、`View.treeStyle(_:)` |
| 3 | `rowContextMenu` | `Tree.rowContextMenu(_:)` |
| 4 | 展平 + `LazyVStack`（含一次性 `Legacy422` 闸门与 iOS `axe` 前置实验） | 无 |

---

## 通用约定（每个 PR 都适用）

### 分支

- PR 1 用本分支 `issue-429-tree-style`（已含 spec + plan 两个 commit）。
- PR 2–4：上一个 PR 合入后 `git fetch origin`，从 **`origin/epic/structure-components`** 开新分支 / worktree
  （`issue-429-pr2-style` 等）。⚠️ 本地 epic 分支合 PR 后会失真：开完先 grep 上一个 PR 引入的符号
  （PR 2 查 `TreeRowMetrics`，PR 3 查 `TreeStyle`，PR 4 查 `rowContextMenu`）确认基线对。
- 提交只 `git add <具体路径>`，**禁 `git add -A`**（仓内有一份长期未提交的 pbxproj 改动）。
- 派实现 subagent 时写明：注释里不得出现评审编号（I-3 / S-5 这类）、不得写实测流水；收工 grep 一遍。

### 类型名（`--filter` / `-only-testing` 只认类型名，先 grep 再用）

```bash
grep -rn "struct .*Tests\|@Suite" Tests/OhMyDesignTests/TreeTests.swift Tests/OhMyDesignTests/TouchTargetTests.swift \
  Tests/OhMyDesignTests/CheckBoxMixedTests.swift Tests/OhMyDesignTests/FieldValidationControlsTests.swift \
  Tests/OhMyDesignTests/SymbolNumericMotionTests.swift
```

`805f40f` 上读到的类型名（**文件名 ≠ 类型名**，下面左列是文件、右列才是 `--filter` / `-only-testing` 用的类型）：

| 文件 | 类型 |
|---|---|
| `TreeTests.swift` | `TreeFlattenTests` / `TreeTruthTableTests` / `TreeKeyboardTests` / `TreeNestedStyleTests` / `TreeAccessibilityTests` / `TreeMotionTests` / `TreeInteractionReducerTests` / `TreeLazinessTests` / `TreeHostedWiringTests`（`#if os(macOS)`）/ `TreeRenderTests` |
| `TouchTargetTests.swift` | `TouchTargetTests`（整个在 `#if os(iOS)` 里，macOS 上零条） |
| `CheckBoxMixedTests.swift` | `CheckBoxIndicatorTests` / `CheckBoxMixedRenderTests` / `CheckBoxMixedWriteBackTests` / `CheckBoxLegacyAppearanceTests` |
| `FieldValidationControlsTests.swift` | `FieldValidationControlsAppearanceTests` / `FieldControlFollowUpTests`（这两个含 CheckBox 格）/ `FieldAccessibilityLabelPolicyTests` / `SearchFieldWrapperStrokeTests` |
| `SymbolNumericMotionTests.swift` | `SymbolNumericContentTransitionTests` / `SymbolNumericInFlightTests`（`#if os(macOS)`）等 |

⚠️ `TreeTests` / `CheckBoxMixedTests` / `FieldValidationControlsTests` / `SymbolNumericMotionTests` 都是**文件名**，
传给 `--filter` / `-only-testing` 会静默零条。

### 验证口径（分层）

1. **迭代**：`swift test --filter 'OhMyDesignTests\.Tree'`（命中全部 `Tree*` suite）+ 本 PR 相关的其他类型名
   （如 `--filter CheckBoxLegacyAppearanceTests`）。每次都核输出里 `Test run with N tests` 的 **N > 0**。
2. **收尾 macOS**：全量 `swift test`，读 `Test run with N tests in M suites passed` 一行，N 与上一个 PR 合入态比较
   （增减要能逐条解释）。console 全文存盘到 scratchpad（SwiftPM 腿没有别处可取逐条结果）。
3. **收尾 iOS**：
   ```bash
   xcrun simctl list devices available   # 在「-- iOS 26.x --」段下挑一台 iPhone，记下 UDID
   xcodebuild test -scheme OhMyDesign-Package \
     -destination "platform=iOS Simulator,id=$UDID" \
     -only-testing:OhMyDesignTests/<类型名> [...逐个列出] \
     -resultBundlePath <scratchpad>/pr<N>-ios.xcresult
   xcrun xcresulttool get test-results summary --path <scratchpad>/pr<N>-ios.xcresult
   ```
   取**顶层** `passedTests`，必须非零且与本次列出的类型的预期条数吻合（`-only-testing` 打错名字是静默 no-op）。
   xcodebuild 空等先查 keychain（加 `CODE_SIGNING_ALLOWED=NO -IDEPackageEnablePrebuilts=NO`）。
   模拟器并发最多 2 个。
4. **公开 API 变化的 PR（2、3）加跑**：
   - 预览宿主：清 `App/.derivedData` 后
     `xcodebuild -project App/OhMyDesignPreview.xcodeproj -scheme OhMyDesignPreview -destination "platform=iOS Simulator,id=$UDID" -derivedDataPath App/.derivedData build`，
     日志里核三样：`Debug-iphonesimulator`、`Compiling ComponentData.swift`、`in target 'OhMyDesignPreview'` 步数非 0。
     只看 `BUILD SUCCEEDED` 不作数。
   - `cd scripts/downstream-probe && swift build`。
   - MainActor 棘轮：先 `swift build --build-tests`，再 `scripts/mainactor-static-ratchet.sh`，预期无新增豁免。
   - `python3 scripts/design-digest.py`：按实际增量改 `FLOORS`，注释行加 `# #429：…` 逐项写明。
5. **最终读数晚于最后一次改动**：改了文档也要重跑（`QuotedEvidenceGuard` / `ComponentRegistryGuard` 在读文档）。
6. RTK 会折叠成功构建输出：grep `warning:` 之类要走 `rtk proxy`。

### 变异纪律

变异改的是「真实会犯的错」，不改判据读的那个常量；每次变异前后 `git diff --stat` 确认落到了文件；
还原用「带断言的字符串替换」（替换前断言变异串恰出现一次）+ 与变异前拷贝的参考副本 `cmp`，
**不用 `git checkout -- <file>` / `git stash`**（基线未提交时会连修复一起删）。
每条变异的「文件 + 改法 + 哪条判据红 + 红的输出一行」记进 PR 正文。

### 登记同步点（每个 PR 收尾前逐项过一遍，不相关的写「本 PR 不涉及」）

- 「更正传播」三处：源码文档注释、`docs/components/tree.md`、`docs/component-registry.json` 的 `Tree.notes`；
  改完 grep 旧说法残留（`CoreSpacing.md`、`height(for: .regular)`、`showsFocusRing`、`DisclosureGroup`、「不给扩展点」）。
- `Tests/OhMyDesignTests/QuotedEvidenceGuard.swift`：被引原文（`Tree.swift` / `TreeCore.swift` / `TreeInteraction.swift`
  的片段、`TreeTests.swift` 的判据名）若改动，登记与文档里的原文同 PR 同步。
- `docs/BREAKING-CHANGES.md`：改写「未发布（相对 `v0.11.0`）——Issue #422」小节，不另开小节。
- `scripts/design-digest.py` 的 `FLOORS`。
- 快照 `docs/snapshots/OhMyDesignPreview_Previews.swift_Tree.{png,json}`（画廊变了才重生成：`scripts/run-snapshots.sh`）。
- `CoreMotionTokenDisciplineGuard` 台账：新文件含动效调用点就要登记；Tree 仍 `gated`。

---

## PR 1：`controlSize` 密度

### 改动文件

- `Sources/OhMyDesign/Components/Tree/TreeCore.swift`：新增 internal `TreeRowMetrics`（spec §1.2 的推导，
  含 `pitch` 平台下限 §1.3）与 `static func resolve(_ size: ControlSize, platformFloor:)`。
- `Sources/OhMyDesign/Components/Tree/Tree.swift`：`Tree` 读 `@Environment(\.controlSize)`，算一次 metrics 交给
  `TreeContext`；`TreeRowView` 的 `minHeight` / 缩进改取 metrics；根 `VStack` 的 spacing 取 `metrics.rowSpacing`；
  `TreeDisclosureControl` 接 metrics，chevron 字号 `compactIconSize(for:)`；`TreeDisclosureSlot` 宽高改取
  `metrics.disclosureWidth` / `metrics.rowHeight`（不再写死）。
- `TreeDisclosureGroupStyle` 的行间距：**在它自己的 body 里读 `controlSize`** 推出 `rowSpacing`，**不给它加构造参数**
  ——`QuotedEvidenceGuard.swift` 登记的引文 `content.disclosureGroupStyle(TreeDisclosureGroupStyle())` 因此原样保留。
  （若 `DisclosureGroupStyle` 的 `makeBody` 里读不到环境，就让它返回一个读 `@Environment(\.controlSize)` 的内部视图；
  仍不可行才改构造签名，并把引文改写与 registry `notes` 同步挪进 PR 1，在 PR 正文写明。）
- `Sources/OhMyDesign/Components/CheckBox/CheckBox.swift`：`CheckBoxBody` 读 internal 环境值
  `checkBoxLayout: CheckBoxLayout?`（字形尺寸 + 最小高度），`nil` 时取值与今天逐字相同（spec §1.4）。
- `Tree.swift` 的 `checkBox(_:)`：注入 `CheckBoxLayout(glyph: iconSize(for: size), minHeight: pitch)`。
  ⚠️ 注入**只施在 Tree 自建的那个 `Toggle` 上**，不施在行或 `Tree` 容器上——调用方放进行内容的 `CheckBox`
  不得被改尺寸（spec §1.4 第 4 条）。
- `Tests/OhMyDesignTests/TreeTests.swift`：新增 metrics / 渲染行距 / 缩进判据（放进既有 `TreeRenderTests`
  或新 suite `TreeDensityTests`——新 suite 的类型名写进 PR 正文）。
- `Tests/OhMyDesignTests/TouchTargetTests.swift`：Tree 两条参数化到 `ControlSize.allCases`；加「带复选框的行」一条；
  `TreeDisclosureControl` 的构造签名随之改。
- `CheckBox` 公开行为不变不另写判据：靠既有的 `CheckBoxLegacyAppearanceTests.matchesLegacy` 与
  `FieldValidationControlsAppearanceTests.validMatchesLegacyPixels` 的 CheckBox 格（参照物都是写死 `.regular` 的旧实现拷贝）。
- 文档：`docs/components/tree.md`「外观」改为推导表 + D3/D4 取舍 + 「密集档位行内容宜用 Text/Label/Image」；
  `docs/BREAKING-CHANGES.md` #422 小节加「读 `controlSize`」一条；registry `Tree.notes` 里若有写死尺寸的描述同步。

### 判据清单（spec §7.1）

- [ ] `TreeRowMetrics` 五档取值（纯函数，双腿）；`.regular` 一列逐项等于 #422 现值；单调不减。
- [ ] macOS：叶行五档渲染行距 = 表值。
- [ ] macOS：**带复选框**的叶行 `.small` 行距 = 22。
- [ ] macOS：**父行**（有 chevron）`.small` 行距 = 22。
- [ ] 双腿：父子两行色块左缘列差 = `indentation`（`.small` / `.regular`）。
- [ ] iOS：`TouchTargetTests` Tree 行 / chevron 槽 / 带复选框行，五档都 ≥ 44。
- [ ] `CheckBox` 公开行为不变：`CheckBoxLegacyAppearanceTests.matchesLegacy`、`FieldValidationControlsAppearanceTests`
  的 CheckBox 格全绿；`CheckBoxIndicatorTests` / `CheckBoxMixedRenderTests` / `CheckBoxMixedWriteBackTests` 全绿。
  （不写「未注入 = 注入 `nil`」：同一分支，恒真。）

### 计划变异（非判据形状）

- [ ] `TreeDisclosureSlot` 恢复写死 `height(for: .regular)`（「只改了行、忘了 chevron 槽」）→ 父行行距判据红。
- [ ] 删掉 Tree 对复选框的布局注入（`CheckBoxBody` 仍读环境）→ 带复选框行距判据红。
- [ ] 平台下限条件写反（`#if os(macOS)` 施 44）→ iOS 触控判据红、macOS 行距判据红。
- [ ] 行宿主缩进改回 `CoreSpacing.md` → `.small` 缩进位图判据红。
- [ ] `CheckBoxBody` 的 `nil` 分支写成 `iconSize(for: .small)` → `CheckBoxLegacyAppearanceTests.matchesLegacy` 与
  `FieldValidationControlsAppearanceTests` 的 CheckBox 格红。

### 验证口径

- 迭代：`--filter 'OhMyDesignTests\.Tree'`、`--filter 'CheckBox(Indicator|MixedRender|MixedWriteBack|LegacyAppearance)Tests'`、
  `--filter 'FieldValidationControlsAppearanceTests|FieldControlFollowUpTests'`、
  `--filter 'SymbolNumericContentTransitionTests|SymbolNumericInFlightTests'`、`--filter CoreMotionTokenDisciplineGuard`、
  `--filter QuotedEvidenceGuard`。每次核 `Test run with N tests` 的 N > 0。
- 收尾：全量 macOS；iOS `-only-testing` 逐个列：全部 `Tree*` suite（`TreeHostedWiringTests` 在 iOS 上为空，不列）、
  `TouchTargetTests`、`CheckBoxIndicatorTests`、`CheckBoxMixedRenderTests`、`CheckBoxMixedWriteBackTests`、
  `CheckBoxLegacyAppearanceTests`、`FieldValidationControlsAppearanceTests` + 本 PR 新 suite；xcresult 顶层计数非零且吻合。
- 公开 API 不变 ⇒ 预览宿主 / downstream-probe / 棘轮 / digest 不强制；digest 跑一次确认 FLOORS 未动。

---

## PR 2：`TreeStyle` 配置 + `.navigator`

### 前置实验（进实现前，scratch，不入库）

- [ ] **升协议兼容性编译探针，在本仓 target 里做**（spec §2.1 / R4；独立模块上的读数已在 spec §2.1 兼容表）：
  库侧两版作为**临时文件**放进 `Sources/OhMyDesign/`（开着 `defaultIsolation(MainActor)`，不提交）——
  v1 `public struct TreeStyle` + `nonisolated static var automatic / navigator` + `func treeStyle(_: TreeStyle)`；
  v2 `public protocol TreeStyle { associatedtype Body: View; @ViewBuilder func makeBody(configuration:) -> Body }` +
  两个 `where Self ==` 静态成员 + **非泛型** `func treeStyle(_: any TreeStyle)`。调用方放在
  `scripts/downstream-probe` 的临时文件里，分别对两版编译四种写法：`.treeStyle(.navigator)`、
  `.treeStyle(flag ? .navigator : .automatic)`（预期两版都过）、`TreeStyle.navigator`（预期 v2 不过）、
  `let s: TreeStyle = .navigator`（预期 v2 仅警告）。同时记下编译器是否要求 `nonisolated public struct` /
  `Sendable`（`nonisolated` 静态成员返回该类型、`@Entry` 默认值两处）。读数写进 PR 正文与 spec §2.1。
  **若 `.treeStyle(.navigator)` 或三元写法在 v2 不过 ⇒ 停，回 spec 重议 D2。** 探针完删掉临时文件、确认 `git status` 干净。

### 改动文件

- 新文件 `Sources/OhMyDesign/Components/Tree/TreeStyle.swift`：`public struct TreeStyle`（无公开 init / 属性 /
  `Equatable`）、internal `TreeAppearance`、`nonisolated public static var automatic / navigator`、internal
  `@Entry var treeStyle`、`public extension View { func treeStyle(_:) }`；internal `TreeRowConfiguration`
  （字段见 spec §2.3，含 `showsFocusIndicator`、`isHovered`，无闭包）；`AutomaticTreeRow`、`NavigatorTreeRow`；
  参考线 x 的 internal 纯函数。
- `Tree.swift`：`TreeRowView` 拆成行宿主（组件外层：`frame(minHeight: pitch)`、`contentShape`、点选手势、
  无障碍、`@State isHovered` + `.onHover`）+ `switch appearance`；`TreeContext.showsFocusRing` 改名
  `showsFocusIndicator`；chevron 的 `.tint` 由外观决定（`.navigator` 施 `contentSecondary`）。
- `App/Sources/ComponentData.swift`：Tree 画廊加 VS Code 示例（`.treeStyle(.navigator)` + `.controlSize(.small)` +
  文件图标 `Label`）。
- `scripts/downstream-probe/Sources/DownstreamProbe/PublicVisibility.swift`：在 View body 里调用
  `.treeStyle(.navigator)` 与 `.treeStyle(.automatic)`（不把 `TreeStyle` 当类型存储，保持升协议兼容）。
- 测试：`TreeTests.swift` 新增 suite（如 `TreeStyleRenderTests`、`TreeHoverTests`、`TreeGuideLineTests`，类型名进 PR 正文）；
  `TreeHostedWiringTests` 参数化；新增源码判据（SwiftSyntax，放 `TreeTests.swift` 或独立 `TreeHoverMotionGuard.swift`）。
- 文档与登记：
  - `docs/component-registry.json` `Tree.notes` 追加 spec §6.2 的三点（step3 ⇒ 不要求扩展点，`TreeStyle` 是装饰预设、
    不在 A–D 射程内、待 `D-429-1`；两外观差异逐项落 `#422` 装饰档原文「连线 / 选中块 / 尺寸 / 缩进引导线」，
    悬停按补充规则 1 单独论证并如实写灰区；升协议兼容路径含 `any TreeStyle` modifier）。
    `kind` / `decidedBy` / `needsExtensionPoint` 不动；`ComponentExtensionPointGuard` 不动。
  - `docs/contract-defects.md`：按既有条目格式新增 `## #429` / `### D-429-1：规定性组件的装饰预设（封闭外观配置）是否属扩展点`
    （撞上公约哪一条 / 撞法 / 判据侧现状 / 本轮处置），首例 `TreeStyle`，含悬停灰区，待公约 owner 裁定。
  - 仓库根 `CLAUDE.md`《组件 style 协议》节补一句：`TreeStyle` 是刻意的封闭配置例外（非协议），理由见 spec §2.1，
    除非按那里的兼容路径升级（modifier 取 `any TreeStyle`），勿改成协议。
  - `docs/components/tree.md`：新增「外观配置」节（`.automatic` / `.navigator` 画法、只示范 `.treeStyle(.navigator)`
    用法）、「悬停」说明；「判定法」追加三点；「判据覆盖到哪」补悬停 / 两外观接线。
  - `.claude/prds/timeline-tree-action-buttons.md` FR-2：spec §6.3 第 1、4 条（第 2 条留给 PR 4）。
  - `docs/BREAKING-CHANGES.md` #422 小节：命中区扩到整行；新增 `TreeStyle` / `View.treeStyle(_:)`。
  - `design-digest.py` FLOORS、快照重生成。
  - 核 README 组件索引与 `ComponentRegistryGuard` 的入口点桶：`View.treeStyle` 是否需要 README 行
    （`knownReadmeEntryPointRows` 等），按判据结果补。

### 判据清单

- [ ] `.automatic` 在 `.regular` 下与 PR 1 合入态逐像素一致（spec §7.2）：照 `CheckBoxLegacyAppearanceTests` 的做法，把 PR 1 合入态的
  `TreeRowView` 及其依赖原样拷进测试 target、改名作参照，同进程新旧各渲一张比；读数进 PR 正文后，本 PR 最后一个 commit 删拷贝。既有 `TreeRenderTests` 全绿。
- [ ] `TreeHostedWiringTests`：既有两条（`expansionTransactionsFollowTheEnvironment`、`keysWriteTheReducedStateBack`）对
  `[.automatic, .navigator]` 参数化；**新增**「点复选框勾选」「点行选中」两条（同样参数化），`TreeHostedHarness` 加 `@State checked`
  与 `TreeHostedLog.checked`。两外观下绑定终态逐项相等（spec §7.3）。
- [ ] 点**缩进区**选中该行，两种外观都成立。
- [ ] 两外观无障碍取值相同（iOS；读不到登记真 HID 项）。
- [ ] 结构判据：`TreeRowConfiguration` 无函数类型字段。
- [ ] `.navigator` 悬停 / 未悬停位图不同；选中 + 悬停 = 仅选中（spec §7.4）。
- [ ] 悬停切换不带动画——整行层（`label` 内 `.transaction` 探针，三档 `MotionPresentation`）。
- [ ] 悬停切换不带动画——源码层：`NavigatorTreeRow`（以实际类型名为准）与行宿主类型内不得出现任何 `animation(` /
  `coreAnimation(` / `withAnimation`（按名禁调用，不做实参数据流分析）。
- [ ] 悬停状态在行级（容器无 hover 存储属性；`.onHover` 只在行宿主）。
- [ ] 悬停不重算整棵树（`content` 调用计数只有该行增加）——**仅当合成悬停可行**；否则降级为真 HID 登记项。
- [ ] 参考线对齐 chevron 中心（位图，≤ 1pt，`.small` / `.regular`）；跨行连续；根数 = `level - 1`；RTL 镜像（spec §7.5）。
- [ ] `onHover` 真接线：先试托管窗口合成 `mouseMoved` / `mouseEntered`，读数进 PR 正文；**不可行 ⇒ 不写该判据**，
  登记为真 HID 项（写进 tree.md「不在 CI」清单），连同「悬停不重算整棵树」一起降级。

### 计划变异（非判据形状）

- [ ] `NavigatorTreeRow` 整行背景加 `.animation(CoreMotionToken.selection.animation(for:), value: isHovered)`（走 token，能过动效纪律守卫）→ 源码层判据红。
- [ ] 同一个 `.animation(..., value: isHovered)` 加在包住 `label` 的层上 → 整行层判据也红。
- [ ] 同一句改写成局部别名 `let hovered = isHovered` + `.animation(…, value: hovered)` → 源码层判据仍红。
- [ ] `.onHover` 写入包进 `withAnimation(...)` → 源码层判据红。
- [ ] 悬停状态上提为容器 `@State hoveredID` → 「行级」源码判据红；「不重算整棵树」只在合成悬停可行时存在、才会红。
  覆盖面如实写进 PR 正文与 tree.md：合成悬停不可行时只剩源码判据一道网，且它按名字（`hover`）匹配，换名即漏。
- [ ] `.onTapGesture` 挪进 `NavigatorTreeRow`、挂在缩进之内 → `.navigator` 的「点缩进区选中」红。
- [ ] 配置加 `let toggleExpansion: () -> Void` → 结构判据红。
- [ ] 参考线 x 漏掉行内横向 padding → 「对齐 chevron 中心」红。
- [ ] 去掉参考线上下外溢 → 「跨行连续」红；循环写 `1...level` → 「根数」红；改用 `Path` 绝对 x → RTL 红。
- [ ] `.automatic` 选中块圆角换 `CoreRadius.medium`；`.padding(.leading)` 挪到背景之前 → 像素一致判据红。

### 验证口径

- 迭代：`--filter 'OhMyDesignTests\.Tree'`、`--filter CoreMotionTokenDisciplineGuard`、`--filter ComponentRegistryGuard`、
  `--filter ComponentExtensionPointGuard`（确认仍 16）、`--filter QuotedEvidenceGuard`、`--filter BoolExemptionGuard`、
  `--filter MainActorStaticRatchetGuard`。
- 收尾：全量 macOS；iOS `-only-testing`：`TouchTargetTests`、`TreeRenderTests`、`TreeAccessibilityTests` + 本 PR 新增的
  非 macOS 专属 suite；xcresult 顶层计数。
- 公开 API 变化 ⇒ 预览宿主（三样核对）、downstream-probe、MainActor 棘轮、digest 全跑。
- 快照：`scripts/run-snapshots.sh` 重生成 Tree 快照，人工看一眼 VS Code 示例（UI 改动：截图交视觉评审 agent，若项目配置了）。

---

## PR 3：`rowContextMenu`

### 改动文件

- `Tree.swift`：`private var rowMenu: ((Set<ID>) -> AnyView)?`；`public func rowContextMenu<M: View>(@ViewBuilder _ menu: @escaping (Set<ID>) -> M) -> Tree`
  （返回改了该字段的副本，文档注释写明目标集合语义、折叠隐藏的选中项不入目标、builder 随 body 逐行求值）（PR 3 终审后改为延迟到取菜单时求值，见 spec R6）；
  容器 body 里**每次 body 预算一次** `selectedVisible = selection ∩ Set(rows.map(\.id))` 传给行宿主（行上只做
  `selectedVisible.contains(id) ? selectedVisible : [id]`，不逐行重做交集）；行宿主 `if let menu` 才挂 `.contextMenu`。
  `Tree` 仍三个泛型。
- `TreeInteraction.swift`（或 `TreeCore.swift`）：`nonisolated enum TreeContextMenu { static func targets(for:selection:visibleIDs:) -> Set<ID> }`。
- 调用点核实（spec §4）：`ComponentData.swift` / `PublicVisibility.swift` / `TreeTests.swift` 里三处
  `Tree<[…], String, Text>.expandedIDs` 不需改；`TreeNestedStyleTests.theRootAppliesTheStyleToo` 的类型串断言与本 PR 无关。
- `scripts/downstream-probe/.../PublicVisibility.swift`：新增一处 `.rowContextMenu { targets in … }`。
- `App/Sources/ComponentData.swift`：VS Code 示例挂 `.rowContextMenu`。
- 测试：新 suite `TreeContextMenuTests`；`TreeLazinessTests` 加「带菜单渲染」一格。
- 文档：`tree.md` 新增「右键菜单」节；BREAKING #422 小节加 `rowContextMenu`；registry notes 若提到右键同步；
  PRD FR-2 能力范围补右键一句（若 PR 2 未写）；digest FLOORS。
- 核 README 组件索引的入口点行与 `ComponentRegistryGuard` 的 `knownReadmeEntryPointRows`：`Tree.rowContextMenu(_:)`
  是否需要 README 行，按判据结果补（与 PR 2 对 `View.treeStyle` 做的同一项检查）。

### 判据清单（spec §7.6）

- [ ] `targets`：在选中集 → 选中 ∩ 可见；不在 → 单元素；树外 ID 不传出；折叠隐藏的本树 ID 不传出。
- [ ] 接线：每个已构建行收到的目标集合都正确、调用次数 ≥ 1（builder 实参捕获；次数不钉死）。
- [ ] 未调用 `rowContextMenu` 时不挂菜单：**运行时探针**——macOS 托管窗口对行所在点取 `NSView.menu(for:)`（合成右键事件），
  或读行 AX 元素动作列表是否含 `AXShowMenu`。⚠️ 实现前先验证探针可区分：对正确实现与「无条件挂空 `.contextMenu`」
  各跑一次，读数不同才采用；相同 ⇒ 换探针或登记真 HID 项。读数进 PR 正文。
- [ ] 带菜单渲染时折叠子树 `children` 读取仍为 0。
- [ ] 右键不改状态：纯函数层；视图层登记真 HID 项。

### 计划变异（非判据形状）

- [ ] `targets` 写成 `selection.union([id])` → 目标集合判据红。
- [ ] `targets` 直接返回 `selection`（不求交）→ 树外 / 折叠隐藏两格红。
- [ ] 用 `treeIDs` 代替可见集求交 → 惰性判据红。
- [ ] 行宿主无条件挂 `.contextMenu { rowMenu?(targets) }` → 「未设置不挂」红。

### 验证口径

- 迭代：`--filter 'OhMyDesignTests\.Tree'`、`--filter QuotedEvidenceGuard`、`--filter ComponentRegistryGuard`、`--filter BoolExemptionGuard`。
- 收尾：全量 macOS；iOS `-only-testing`：`TreeContextMenuTests`、`TreeLazinessTests`、`TreeRenderTests`、`TouchTargetTests`；xcresult 顶层计数。
- 公开 API 变化 ⇒ 预览宿主、downstream-probe、MainActor 棘轮（方法非 static，预期无变化，仍跑）、digest。

---

## PR 4：展平 + `LazyVStack`

### 前置实验（先做，读数进 PR 正文）

- [ ] **iOS `axe describe-ui` 对照**（spec §5.4）：在 PR 3 合入态上，预览宿主 Tree 画廊（含复选框、展开到第 3 层）
  读一次 `describe-ui` 全文存盘；展平后同一屏再读一次；逐元素比对元素数、类型、label、value、traits。
  有差异 ⇒ 先登记到 tree.md「无障碍与触控」并在 PR 正文说明取舍，再继续。
- [ ] `Legacy422` 拷贝范围：实现完成后跑 `git diff --stat <PR4 父提交>..HEAD -- Sources/OhMyDesign/Components/Tree/`
  得到**被改动的文件**，再逐文件读 `git diff <PR4 父提交>..HEAD -- <文件>` 的 hunk，列出被改动 / 删除的**类型**
  （`--stat` 只到文件粒度）。

### 改动文件

- `TreeCore.swift`：`TreeRenderItem<Element, ID>`（`Identifiable`，不 `Equatable`）；`TreeFlatten.items(...)` 一次遍历；
  `TreeFlatten.rows(...)` 改为 `items(...).map(\.row)`（`TreeRow` 与其 `Equatable` 不动，spec §5.3）。
- `Tree.swift`：body 改为 `LazyVStack(alignment: .leading, spacing: metrics.rowSpacing) { ForEach(items) { TreeRowHost(...) } }`；
  `onChange(of: rows)` 用 `items.map(\.row)`；删除 `TreeBranch` / `TreeNestedStyle` / `TreeDisclosureGroupStyle`；
  类型文档注释去掉「走递归 `DisclosureGroup(isExpanded:)`」。
- `Tests/OhMyDesignTests/TreeTests.swift`：删除 `TreeNestedStyleTests`（含 `:562` 那条）；新增构建计数判据；
  临时加 `Legacy422*` 拷贝（`TreeBranch` / `TreeNestedStyle` / `TreeDisclosureGroupStyle` / **`TreeContext`** / 当时的行宿主，
  及 diff 列出的其他类型）与位图闸门 suite `Legacy422ParityTests`。
- `Tests/OhMyDesignTests/QuotedEvidenceGuard.swift`：删 / 改 `content.disclosureGroupStyle(TreeDisclosureGroupStyle())` 那条登记。
- `docs/component-registry.json` `Tree.notes`：步骤 1 里「本组件因此在递归的每一层重施样式，逐字 …」一句改写为
  「`#429` 起展平渲染，不再递归 `DisclosureGroup`」（与 QuotedEvidenceGuard 登记同 commit）。
- `docs/components/tree.md`：「惰性」节补 `LazyVStack` 与「不在 `ScrollView` 里退化为全量」；无障碍节按前置实验结果改；
  删除递归描述。
- `.claude/prds/timeline-tree-action-buttons.md` FR-2：spec §6.3 第 2 条（推翻路径 A 的理由）。
- `docs/BREAKING-CHANGES.md` #422 小节：行不再是 `DisclosureGroup` 的 label（按前置实验读数写）。

### 判据清单（spec §7.7）

- [ ] 构建计数：`ScrollView` 300pt 视口、200 子节点展开父节点，构建行数 < 20。
- [ ] 行身份（macOS 托管窗口）：每行 `onAppear` 记 ID；展开一个中间父节点后，新出现的 ID 集合恰为被插入的子行。
- [ ] `Legacy422ParityTests`：spec §5.6 矩阵，尺寸相同、逐通道偏差 ≤ 2；iOS 为权威腿、macOS 辅证。
- [ ] 既有 `TreeFlattenTests` / `TreeKeyboardTests` / `TreeLazinessTests` / `TreeHostedWiringTests` 全绿。
- [ ] iOS `axe` 对照读数进 PR 正文。

### 计划变异（非判据形状）

- [ ] 容器换回 `VStack` → 构建计数红。
- [ ] 保留 `LazyVStack` 但恢复根层 `DisclosureGroup` 嵌套 → 构建计数红。
- [ ] `items` 改成层序（广度优先）遍历 → `Legacy422` 闸门红、键盘判据红。
- [ ] `ForEach` 的 id 改用下标 → 行身份判据红（新出现的是尾部下标上的行）。⚠️ 不指望 `Legacy422` 闸门抓它：
  `ImageRenderer` 每次全新构建，身份错位画不出差别。

### 一次性闸门的收尾（同一 PR 最后一个 commit）

- [ ] 把 `Legacy422ParityTests` 两条腿的读数（矩阵格数、最大偏差、iOS xcresult 顶层计数）写进 PR 正文。
- [ ] 删除 `Legacy422*` 拷贝与该 suite；全量 macOS + iOS 再跑一遍（最终读数晚于最后一次改动）。

### 验证口径

- 迭代：`--filter 'OhMyDesignTests\.Tree'`、`--filter Legacy422ParityTests`、`--filter QuotedEvidenceGuard`、
  `--filter ComponentRegistryGuard`、`--filter CoreMotionTokenDisciplineGuard`。
- 收尾：全量 macOS；iOS `-only-testing`：`Legacy422ParityTests`（删除前）、`TreeRenderTests`、`TreeAccessibilityTests`、
  `TouchTargetTests`、`TreeLazinessTests` + 新构建计数 suite；xcresult 顶层计数。
- 公开 API 不变，但删除了内部类型 ⇒ 预览宿主仍跑一次（三样核对）；downstream-probe、digest 跑一次确认无变化。
- 快照：重生成 Tree 快照，与 PR 3 合入态对比（应只有 ≤ 1 LSB 差）。

---

## 评审节点

- 每个 PR 实现完成、提交后：`superpowers-reviewer`（executing-plans 焦点，给 BASE/HEAD SHA）。
- 每个 PR 开之前：`superpowers-reviewer`（finishing 焦点，完整 diff）。
- 开 PR 后：`auto-fix-pr-after-implementation`。
