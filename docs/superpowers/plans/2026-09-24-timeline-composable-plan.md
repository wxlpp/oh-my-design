# Timeline 组合式 API（#420）实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 `Timeline(items:layout:)` 换成组合式 API（行是 `View`、自己画节点），补两维自适应节点盒、`.horizontal` 连线、
阶段维度（每行 `step` + 容器 `progress`）、阶段推进与节点入场动效，无障碍状态播报在行上。

**Spec:** `docs/superpowers/specs/2026-09-24-timeline-composable-design.md`（先读；本计划的「§」均指 spec 章节）。
§12 已全部定案：U1 每行 `step` + 容器 `progress`；U8 有标题挂标题元素、无标题挂合并内容元素、默认圆点隐藏；
U12 `TimelineItem` 登记 `prescriptive` / `tiebreaker`、J-2 仍 16；U13 标题只给 `LocalizedStringKey`；其余按推荐项。

**拆分：4 个独立可合并的 PR**，顺序固定、不并行（后一个依赖前一个的合入态）。

| PR | 内容 | 公开 API 变化 | 与 epic 分支的关系 |
|---|---|---|---|
| 1 | 内部几何（`TimelineStackLayout` + 纯函数）+ `.horizontal` 连线 + `minimumNodeExtent` 改名 + 更正传播 + `Legacy420*` 闸门 | 签名不变（`TimelineLayout` 加 `nonisolated` 除外） | 用本分支 `issue-420-timeline-composable`，先 rebase 到最新 `origin/epic/structure-components`，PR base = `epic/structure-components` |
| 2 | 组合式 API 迁移：`Timeline<Content>` + `TimelineItem` 变 `View` + 四个 init + `step:` + 全部调用点 + 登记 | **破坏性** | PR 1 合入后从最新 `origin/epic/structure-components` 切 `issue-420-pr2-composable` |
| 3 | 阶段：`TimelineProgress` / `TimelinePhase` / `init(progress:)` / `timelinePhase` + 静态形态 + 连线着色 + 阶段无障碍 | 加法 | PR 2 合入后从最新 `origin/epic/structure-components` 切 `issue-420-pr3-phase` |
| 4 | 动效：推进补间（同一 `P`）+ 入场闩锁 + RM 两条通路 + 纪律台账；**最后一个 commit 删除 `Legacy420*`** | 无 | PR 3 合入后从最新 `origin/epic/structure-components` 切 `issue-420-pr4-motion` |

---

## 通用约定（每个 PR 都适用）

### 分支与基线

- spec 的基线是 `f0f03c2`；写本计划时 `origin/epic/structure-components` 已前进到 `27fb971`（`#431`），其间
  Timeline 相关文件零改动，下面四个计数在 `27fb971` 上复核未变。**每次切分支后都重跑一遍**，数不对就先改计划里的数再开工：

  ```bash
  grep -n 'localizedByType.count ==' Tests/OhMyDesignTests/ComponentTextParamGuard.swift          # 期望 21
  grep -n 'repo == "ohmydesign" }.count ==' Tests/OhMyDesignTests/ComponentRegistryGuard.swift     # 期望 58
  grep -n 'inspected.count ==' Tests/OhMyDesignTests/ComponentExtensionPointGuard.swift             # 期望 16
  grep -c 'Components/Timeline/Timeline.swift' Tests/OhMyDesignTests/QuotedEvidenceGuard.swift       # 期望 5
  ```

- PR 1 开工前：`git fetch origin && git rebase origin/epic/structure-components`（本分支此时只有 spec / plan 文档 commit，
  预期无冲突；已推送过 ⇒ 推送用 `--force-with-lease`）。
- PR 2–4：上一个 PR 合入后 `git fetch origin`，从 **`origin/epic/structure-components`**（不是本地 epic 分支——合 PR 后本地分支会失真）
  开新 worktree。开完先 grep 上一个 PR 引入的符号确认基线对：PR 2 查 `TimelineStackLayout`、`minimumNodeExtent`；
  PR 3 查 `Timeline<Content`（泛型容器）与 `step: Int?`；PR 4 查 `TimelineProgress`、`timelinePhase`。
- 提交只 `git add <具体路径>`，**禁 `git add -A`**（仓内有一份长期未提交的 pbxproj 改动）。
- PR 1–3 正文写 `Part of #420`，不写关闭关键字；引用语境里也不出现 `Closes #N` 这类串。
- 派实现 subagent 时写明：注释里不得出现评审编号（I-5 / S-6 / U8 这类）与实测流水；收工 `grep -nE '\b[ISU]-?[0-9]+\b'` 过一遍改动文件。

### 文件 → 类型对照（`--filter` / `-only-testing` 只认类型名）

`27fb971` 上 grep 读到（`grep -nE '^(@MainActor )?struct ' <文件>`）：

| 文件 | 类型 | 平台 |
|---|---|---|
| `Tests/OhMyDesignTests/TimelineTests.swift` | `TimelineTests` / `TimelineNodeColorRenderTests` | 后者 `.enabled(if: assetCatalogIsCompiled, …)` ⇒ macOS native 腿 skip，只在 iOS 腿真跑 |
| `Tests/OhMyDesignTests/DynamicTypeLayoutTests.swift` | `DynamicTypeLayoutTests` | 整个 `#if os(iOS)` ⇒ macOS 零条 |
| `Tests/OhMyDesignTests/QuotedEvidenceGuard.swift` | `QuotedEvidenceGuard` | 双腿 |
| `Tests/OhMyDesignTests/BareLineRefGate.swift` | `BareLineRefGate` | 双腿 |
| `Tests/OhMyDesignTests/ComponentRegistryGuard.swift` | `ComponentRegistryGuard` | 双腿 |
| `Tests/OhMyDesignTests/ComponentTextParamGuard.swift` | `ComponentTextParamGuard` | 双腿 |
| `Tests/OhMyDesignTests/ComponentExtensionPointGuard.swift` | `ComponentExtensionPointGuard` | 双腿 |
| `Tests/OhMyDesignTests/ComponentJudgeRulesTests.swift` | `ComponentJudgeRulesTests` | 双腿 |
| `Tests/OhMyDesignTests/BoolExemptionGuard.swift` | `BoolExemptionGuard` | 双腿 |
| `Tests/OhMyDesignTests/AccessibilityStringLiteralGuard.swift` | `AccessibilityStringLiteralGuard` | 双腿 |
| `Tests/OhMyDesignTests/ReachableTypeRegistryGuard.swift` | `ReachableTypeRegistryGuard` | 双腿 |
| `Tests/OhMyDesignTests/CoreMotionTokenDisciplineGuard.swift` | `CoreMotionTokenDisciplineGuard` | 双腿 |
| `Tests/OhMyDesignTests/CoreMotionTokenInFlightTests.swift` | `CoreMotionTokenInFlightTests`（提供 `observeControlMotion` / `HostedWindow` 用法先例） | 见该文件 |
| `Tests/OhMyDesignTests/MainActorStaticRatchetGuard.swift` | `MainActorStaticRatchetGuard` | 双腿 |
| `Tests/OhMyDesignTests/DesignDigestSyncGuard.swift` | `DesignDigestSyncGuard` | 双腿 |
| `Tests/OhMyDesignTests/SnapshotArtifactGuard.swift` | `SnapshotArtifactGuard` | 双腿 |

本计划**新建**的类型（名字一律以 `Timeline` 开头，使 `--filter 'OhMyDesignTests\.Timeline'` 一条命中全部；落地后先 grep 复核再传给
`-only-testing`——打错名是静默 no-op）：

| PR | 新文件 | 新类型 | 平台 |
|---|---|---|---|
| 1 | `Tests/OhMyDesignTests/TimelineGeometryTests.swift` | `TimelineGeometryPureTests`（§3.7 纯函数）/ `TimelineGeometryRenderTests`（§9.1 位图） | 纯函数双腿；位图按 spec 定 macOS 腿（`#if os(macOS)`） |
| 1 | `Tests/OhMyDesignTests/TimelineLegacy420.swift` | 旧实现拷贝：`Legacy420Timeline` / `Legacy420TimelineItem` / `Legacy420TimelineNodeView` 等（非 suite） | —— |
| 1 | `Tests/OhMyDesignTests/TimelineLegacy420GateTests.swift` | `TimelineLegacy420GateTests` | 双腿（iOS 另加五档状态色） |
| 2 | `Tests/OhMyDesignTests/TimelineCompositionTests.swift` | `TimelineCompositionTests` | 类型双腿编译；其中位图用例逐条 `#if os(macOS)`，配对 / 挂载点纯函数双腿 ⇒ iOS 腿条数非零 |
| 3 | `Tests/OhMyDesignTests/TimelinePhaseTests.swift` | `TimelinePhaseTruthTableTests` / `TimelinePhaseRenderTests` / `TimelineAccessibilityValueTests` / `TimelineStepsIsolationGuard` | `TimelinePhaseRenderTests` 整个 `#if os(macOS)`（不进 iOS `-only-testing`）；其余双腿 |
| 4 | `Tests/OhMyDesignTests/TimelineMotionTests.swift` | `TimelineMotionInFlightTests` | `#if os(macOS)`（iOS 的 `layer.render(in:)` 拍不到在飞帧，`CoreMotionTokenInFlightTests` 同理由） |

⚠️ `TimelineTests` 是文件名也是类型名，但 `TimelineNodeColorRenderTests` 不是文件名；`TimelinePhaseTests` / `TimelineMotionTests` /
`TimelineGeometryTests` 是**文件名**，传给 `--filter` / `-only-testing` 会静默零条。

### 验证口径（分层）

1. **迭代**：`swift test --filter 'OhMyDesignTests\.Timeline'` + 本 PR 相关守卫类型名（例：`--filter 'QuotedEvidenceGuard|ComponentRegistryGuard'`）。
   每次核输出里 `Test run with N tests` 的 **N > 0**。
2. **收尾 macOS**：全量 `swift test 2>&1 | tee <scratchpad>/420-prN-macos.log`，读 `Test run with N tests in M suites passed`，
   N 与切分支时在 epic 头上跑的基线比较，增减逐条解释写进 PR 正文。console 全文存盘（SwiftPM 腿没有别处可取逐条结果）。
   ⚠️ **与 iOS `xcodebuild` 不并行**（抢 CPU 会让在飞帧判据采样失真，PR 4 尤甚）。
3. **收尾 iOS**（macOS 跑完之后）：
   ```bash
   xcodebuild test -scheme OhMyDesign-Package \
     -destination "platform=iOS Simulator,id=$UDID" \
     -only-testing:OhMyDesignTests/<类型名> [...本 PR 表里逐个列出] \
     -resultBundlePath <scratchpad>/420-prN-ios.xcresult
   xcrun xcresulttool get test-results summary --path <scratchpad>/420-prN-ios.xcresult
   xcrun xcresulttool get test-results tests --path <scratchpad>/420-prN-ios.xcresult | grep -c '<每个类型名>'
   ```
   取**顶层** `passedTests`（不是 `devicesAndConfigurations[].passedTests`），必须非零；再逐个类型名在 `tests` 输出里核到至少一次
   （防某个 `-only-testing` 打错名静默丢掉）。xcodebuild 空等先查 keychain（加 `CODE_SIGNING_ALLOWED=NO -IDEPackageEnablePrebuilts=NO`）。
4. **公开 API 有变的 PR（1 的 `nonisolated`、2、3）加跑**：
   - 预览宿主：`rm -rf App/.derivedData` 后
     `xcodebuild -project App/OhMyDesignPreview.xcodeproj -scheme OhMyDesignPreview -destination "platform=iOS Simulator,id=$UDID" -derivedDataPath App/.derivedData build`，
     日志核三样：`Debug-iphonesimulator`、`Compiling ComponentData.swift` / `Compiling Previews.swift`、`in target 'OhMyDesignPreview'` 步数非 0。
     只看 `BUILD SUCCEEDED` 不作数。
   - `cd scripts/downstream-probe && swift build -Xswiftc -warnings-as-errors`。
   - MainActor 棘轮：先 `swift build --build-tests`，再 `scripts/mainactor-static-ratchet.sh`，预期无新增豁免（spec §1.2：不新增公开 `static` 存储成员）。
   - `scripts/api-surface-diff.sh`：PR 1 只应出现 `TimelineLayout` 的 `nonisolated`；PR 3 只增不删；PR 4 为空。
5. **digest**（每个 PR）：`python3 scripts/design-digest.py`；基数不符按实际增量改 `FLOORS` 并加 `# #420：…` 逐项写明；跑 `DesignDigestSyncGuard`。
6. **最终读数晚于最后一次改动**：改了文档也要重跑（`QuotedEvidenceGuard` / `ComponentRegistryGuard` / `BareLineRefGate` 读文档）。
7. RTK 会折叠成功构建输出：grep `warning:` 之类走 `rtk proxy`。

### 模拟器纪律

- **不碰已启动的设备**（`xcrun simctl list devices booted` 里的一律不 shutdown / erase / 装卸 app）。
- 每个 PR 自建专用设备，用完删：
  ```bash
  xcrun simctl list runtimes | grep 'iOS 26'          # 取 runtime id
  UDID=$(xcrun simctl create "omd-420-prN" "iPhone 17 Pro" <runtime-id>)
  xcrun simctl boot "$UDID"
  ...                                                  # 测试 / 预览宿主 / 快照 / axe 全用这个 UDID
  xcrun simctl shutdown "$UDID" && xcrun simctl delete "$UDID"
  ```
- 按 id 寻址（本机同名设备多台，`name=` 形态会硬红）；快照走 `SIMULATOR_ID=$UDID scripts/run-snapshots.sh`。
- 带模拟器的实现 agent 最多并发 2 个。

### 判据与变异纪律

- 判据能被变异打红；**变异模仿「真实会犯的错」，不照判据的形状构造**（不去改判据读的那个常量）。
- 每次变异前后 `git diff --stat` 确认落到了文件，再跑判据；变异后仍绿是两义的，先排除「没改到」。
- 还原用带断言的字符串替换（替换前断言变异串恰出现一次）+ 与变异前参考副本 `cmp`；**不用 `git checkout -- <file>` / `git stash`**。
- 每条变异的「文件 + 改法 + 哪条判据红 + 红的那一行输出」记进 PR 正文。

### `Legacy420*` 闸门生命周期（spec §9.1，I-5 定案）

| PR | 动作 |
|---|---|
| 1 | 从 **PR 1 的父提交**（rebase 后的 epic 头）把旧渲染类型原样拷进 `TimelineLegacy420.swift`，改名 `Legacy420*`、自包含（常量写字面量 24，不引用 `Timeline.minimumNodeExtent`——拷贝不能跟着新实现走）；建 `TimelineLegacy420GateTests` |
| 2 | 拷贝**不动**；闸门的「新」一侧改用新 API 写法（同一矩阵） |
| 3 | 拷贝不动；加「不传 `progress` 与 `Legacy420*` 同图」 |
| 4 | 加「入场 `initialValue` 写成 0.86 ⇒ 闸门红」变异；**最后一个 commit** 删除 `TimelineLegacy420.swift` 与 `TimelineLegacy420GateTests.swift`，同 commit 把「静止帧」判据改成自参照（`.resting` 渲染 vs `.hidden` 渲染），删后 `grep -rn 'Legacy420' Sources Tests App` 为零 |

⚠️ 每个 PR 收尾都跑 `grep -c 'struct Legacy420' Tests/OhMyDesignTests/TimelineLegacy420.swift`，PR 1–3 与 PR 4 倒数第二个 commit 必须非零。
`#398` 的 `LegacyTimeline`（`TimelineTests.swift` 里，前缀不同）是另一回事，**保留**。

### 登记同步总表（每个 PR 收尾前逐项过；不相关的在 PR 正文写「本 PR 不涉及」）

| 落点 | PR 1 | PR 2 | PR 3 | PR 4 |
|---|---|---|---|---|
| `QuotedEvidenceGuard`（Timeline 5 条：保 4 改 1） | 改 1：registry 那条逐字 `static let nodeColumnWidth: CGFloat = 24` → `static let minimumNodeExtent: CGFloat = 24`；另 4 条（`@ViewBuilder node: () -> Node,` ×2、`private var nodeContent: some View` ×2）不动 | 4 条仍须命中：新 init ② / ④ 的签名里保留逐字 `@ViewBuilder node: () -> Node,`，`TimelineNodeView` 留在 `Timeline.swift` 且保留 `private var nodeContent: some View`；本 PR 新增的逐字引文（公约加注、timeline.md）逐条登记 | 新增引文逐条登记 | 同左 |
| `docs/component-registry.json` `Timeline.notes` | 「横向连线不是缺口」那两句（逐字「⚠️ 这条是**有意不开** issue 的：横向连线是一个尚无需求驱动的增强，不是缺口；要做时再开，别把它读成待办。」及前一句）改写为一句「原判被 PRD FR-1 d 推翻，`#420` 已画出横向连线」；「左侧固定 24pt 节点列」一句同步（spec §5.2） | 逐字「TimelineItem.content/node 均为 @ViewBuilder，无固定 String 文本参数。」改写（`title` / `description` 为 `LocalizedStringKey`）；追加 `#420` 段（组合式 API、`node:` 是 D1 形状但 `TimelineItem` 登记为 prescriptive） | 追加阶段正交一句 | 不涉及 |
| registry 新条目 `TimelineItem`（58 → 59） | 不涉及 | `kind: prescriptive`、`decidedBy: tiebreaker`、`needsExtensionPoint: false`、`textParams: []`；`ComponentRegistryGuard` 逐字 `.count == 58,` → 59；README 映射照 `SettingsRow` → `SettingsRowChevron` 先例把 `TimelineItem` 挂到 `Timeline` 行 | 不涉及 | 不涉及 |
| `ComponentTextParamGuard` `localizedByType` 21 → 23 | 不涉及 | `TimelineItem.init#title` / `TimelineItem.init#description`；同句注记追加「`#420` TimelineItem 的 title / description 使 21 变为 23」 | 不涉及 | 不涉及 |
| `ComponentExtensionPointGuard` | 不涉及 | 仍 16（U12），跑一遍确认泛型 `Timeline<Content>` 仍被识别为宿主 | 不涉及 | 不涉及 |
| 公约 `docs/component-contract.md` D1 行 + `ComponentJudgeRulesTests` 夹具 | 不涉及 | D1 行范例后加注：它是 D1 的**形状**范例，`TimelineItem` 自身登记为 `prescriptive` / `tiebreaker`、不进 J-2 定义域；`ComponentJudgeRulesTests` 形态 D 那组的 `// MARK:` 标题注明「`TimelineItem` 源码串为合成夹具，与 registry 真实分类无关」（源码串本身不改）。`docs/contract-defects.md` 里以 `TimelineItem.node` 为例的段落 grep 复核仍为真 | 不涉及 | 不涉及 |
| `docs/BREAKING-CHANGES.md` | **新建**一节「未发布（相对 `v0.11.0`）——Issue #420：Timeline 组合式 API」（插在最新一节之上），写 PR 1 的可见变化：`.horizontal` 画连线、> 24pt 节点撑宽列 / 行高、内容高 < 16pt 的非末行多出 `CoreSpacing.sm`、`TimelineLayout` 变 `nonisolated` | 追加：移除 `Timeline(items:layout:)` 与旧 `TimelineItem` init、`id:` 参数、迁移写法（`Timeline(layout: x) { A; B }`）、行上修饰作用于节点（逐子视图语义） | 追加：新增阶段 API（加法，列出以便查阅） | 追加：节点入场动效、阶段推进动效；`ImageRenderer` 导出须注入 `.resting` |
| `docs/components/timeline.md` | 删「⚠️ `.horizontal` **不画节点间连线**」与「（无连线，可横向滚动）」，按「更正只留一层」写一句「原写不画连线，`#420` 起画」；节点盒自适应；规模（spec §3.8） | API / 用法全文重写；删不存在的 `Timeline.applyGroupedStatusValue(_:item:)`；布局修饰写进 `content:` 的引导 | 阶段真值表、默认圆点形态、无障碍（U8 两种挂载点）、`axe --point` 手工读数进「不在 CI」清单 | 动效、RM 降级、`ImageRenderer` 须注入 `coreMotionPresentationOverride(.resting)` |
| README 索引 / 快照（`docs/README.md` Timeline 行 + `docs/snapshots/…_Timeline{,_Layouts,_Alternate_Widths}.{png,json}`） | 三组重生成（专用模拟器 + `run-snapshots.sh`）；跑 `SnapshotArtifactGuard` | 行不改；活动流、部署日志两个新 `#Preview` 各新增一组 | 路线图 `#Preview` 新增一组 | 重生成后与 PR 3 合入态逐一比对应**无差异**（有差异 = 快照取到了入场第 0 帧，见 PR 4 前置实验 E4-3） |
| `Sources/OhMyDesign/Resources/en.lproj/Localizable.strings` | 不涉及 | 不涉及 | 新增 `Completed` / `In Progress` / `Upcoming`；跑 `AccessibilityStringLiteralGuard`，不新增 `docs/a11y-exemptions.json` 豁免 | 不涉及 |
| `AGENTS.md` / `CLAUDE.md` | grep `Timeline` 复核 | 两处都在免疫机制第 1 类点名 `TimelineTests`（「断言的是 **asset 名**（经 `assetName`），不解析」）：重写后 `TimelineTests` **类型**里必须仍有按 asset 名断言的判据；若挪到别的类型，两处同步改名 | grep 复核 | grep 复核 |
| `App/Sources/ComponentData.swift`（`Timeline(` 4 处 / `TimelineItem(` 8 处）+ `App/Sources/Previews.swift`（5 / 9 处） | 不改调用（签名不变）；`Previews.swift` 对 `TimelineAlternateRowLayout` 的注释（逐字「由 `TimelineAlternateRowLayout` **无存储状态**这一结构事实保证」）改指 `TimelineStackLayout` | 全部迁移：`private static var items: [TimelineItem]` → `@ViewBuilder` 属性；`PreviewSnapshotFixtures.timelineItems`（逐字 `static var timelineItems: [TimelineItem] {`，3 处引用）→ `@ViewBuilder static var timelineRows: some View`；grep 口径用 spec §8.1（含换行写法） | 路线图形态进画廊与 `#Preview` | 不涉及 |
| `scripts/downstream-probe/Sources/DownstreamProbe/PublicVisibility.swift` `consumeTimeline()` | 不涉及 | 改写：覆盖四个 init、`step:` | 补 `progress:`、`phase(forStep:)`、`timelinePhase` 读取 | 不涉及 |
| `Sources/OhMyDesign/Components/Timeline/Timeline.swift` 过时文档注释 | 两处：`node:` 参数的尺寸约束段（逐字「**尺寸约束**：节点方框固定 24×24pt（`Timeline.nodeColumnWidth`）且**不裁剪**——」起到「归 Phase 3 视觉评审裁决」止）改为「节点盒按最宽节点自适应、下限 24」；`.vertical` 的逐字 `/// 默认：左侧固定节点列 + 右侧内容，节点间竖向连线（现状形态）。` 去掉「固定」。另 spec §5.2 的 `.horizontal` 一句补「节点间有连线」 | 旧 init 文档随 init 删除；新 init 全部配 `///` 摘要 + `- Parameters` | 新类型文档注释 | 不涉及 |
| `CoreMotionTokenDisciplineGuard` 台账 | 不涉及 | 不涉及 | 不涉及 | `"Components/Timeline/Timeline.swift": .gated`（动画调用点落在 `TimelineStackLayout.swift` 时同样登记）+ `transformLedger` 入场缩放条目 |
| PRD `.claude/prds/timeline-tree-action-buttons.md` FR-1 | 不涉及 | 注明命名沿用、阶段取值为每行 `step` + 容器 `progress` | 不涉及 | 不涉及 |
| `ReachableTypeRegistryGuard` | 不涉及 | 跑 | 跑（兜 spec §8.1「`TimelineProgress` / `TimelinePhase` 不涉及」这条推断） | 不涉及 |

登记后每处更正都 grep 残留：`不画节点间连线`、`无连线`（排除 `.grouped` 合法用法）、`nodeColumnWidth`（排除 `BREAKING-CHANGES.md` 历史节与
`docs/issues/337-census.md` 史料）、`尚无需求驱动`、`TimelineAlternateRowLayout`、`timelineItems`、`Timeline(items:`。

---

## PR 1：内部几何 + 横向连线（公开签名不变）

**前置实验**

- [ ] E1-1 基线：切分支后跑「分支与基线」四条 grep；全量 `swift test` 记 N（存盘），作为本 PR 的比较基准。
- [ ] E1-2 过渡态可行性：旧 `[TimelineItem]` 数据喂容器级 `Layout`（容器构造节点）——`Timeline.body` 里用 `ForEach(items)` 产出节点 / 内容 /
  连线子视图并以 `layoutValue` 标角色；scratch 编译一次确认 `LayoutValueKey` 须 `nonisolated`（spec P6 ③）。不进仓库。

**改动文件**

- 新建 `Sources/OhMyDesign/Components/Timeline/TimelineStackLayout.swift`：`TimelineStackLayout: Layout`（四个 layout 分支中的三个；`.grouped` 仍走 `VStack`）
  + spec §3.7 纯函数（`nodeBox(reported:)`、`nodeColumnWidth(boxWidths:)`、`verticalRowHeight(box:content:isLast:)`、
  `alternateRowMetrics(forRowWidth:nodeColumnWidth:)`、`horizontalAxis(boxHeights:)`、`connectorSpan(from:to:)`；`pairParts(roles:)` 留到 PR 2）。
- `Sources/OhMyDesign/Components/Timeline/Timeline.swift`：`nonisolated static let nodeColumnWidth` → `minimumNodeExtent`；
  旧 `alternateRowMetrics(forRowWidth:)` 转调双参数版；删除 `TimelineAlternateRowLayout`（并进 `.alternate` 分支）；
  节点提议 24×24、报告尺寸决定盒；`.horizontal` 画连线；`TimelineLayout` 加 `nonisolated`；三处文档注释（见总表）。
- `Tests/OhMyDesignTests/TimelineTests.swift`：`alternateSlotWidth` 断言原样保留；`Timeline.nodeColumnWidth` 引用改 `minimumNodeExtent`；
  `#398` 的 `LegacyTimeline*` 拷贝改用字面量 24（拷贝不跟新常量）。
- 新建 `TimelineGeometryTests.swift`、`TimelineLegacy420.swift`、`TimelineLegacy420GateTests.swift`。
- 登记：总表 PR 1 列（`QuotedEvidenceGuard` 改 1、registry notes、timeline.md、BREAKING 新节、`Previews.swift` 注释、快照三组）。

**判据**（spec §9.1）

| 判据 | 类型 | 腿 |
|---|---|---|
| §3.7 纯函数逐行（含 `infinity` / `-infinity` / `nan` / 负数 / 空数组） | `TimelineGeometryPureTests` | 双腿 |
| 列宽 = 最宽节点（24×24 / 40×56 / 20×20，三行内容左缘相等且 = 40 + md） | `TimelineGeometryRenderTests` | macOS |
| 高节点不被穿过；连线终点 = 下一盒上沿（±1） | 同上 | macOS |
| `.alternate` 中轴一致（= 行宽 / 2，±1） | 同上 | macOS |
| `.horizontal` 横轴与内容顶（盒高 24 / 56 混排，内容顶 = 56 + sm） | 同上 | macOS |
| RTL = LTR 水平翻转 | 同上 | macOS |
| 旧实现闸门：§8.3「有意保留」矩阵 × {light, dark} × {`.vertical`, `.alternate`, `.grouped`}，`expectBitmapsEquivalent(maxChannelDelta: 2)`；`.horizontal` 遮连线带再比；`.horizontal` 连线带「应不同」 | `TimelineLegacy420GateTests` | 双腿（iOS 另加五档状态色） |

所有静态位图注入 `coreMotionPresentationOverride(.resting)`；macOS 腿用不走 asset catalog 的颜色（`status: .neutral`、`Color.black`、`.tint(.black)`）。

**计划变异**（每条都是「会顺手写出来的错」）：列宽逐行各算；行高只看内容；连线起点写回常量 24；节点提议改 `.unspecified`（「Shape 按理想尺寸画更干净」）；
`.alternate` 仍调单参数 metrics；`.horizontal` 内容顶取本列盒高；去掉 `nodeColumnWidth(boxWidths:)` 的 `nan` 防御。预期红的判据见 spec §9.1 末段。

**验证**

- 迭代：`swift test --filter 'OhMyDesignTests\.Timeline|QuotedEvidenceGuard|ComponentRegistryGuard|BareLineRefGate'`。
- 收尾：全量 macOS → iOS `-only-testing:` `OhMyDesignTests/TimelineTests`、`OhMyDesignTests/TimelineNodeColorRenderTests`、
  `OhMyDesignTests/TimelineGeometryPureTests`、`OhMyDesignTests/TimelineLegacy420GateTests`、`OhMyDesignTests/DynamicTypeLayoutTests`
  （几何改了行高）→ 预览宿主（`TimelineLayout` 加 `nonisolated`）→ probe → 棘轮 → `api-surface-diff.sh` → digest。
- 视觉：新旧快照对比图（`.horizontal` 连线）交视觉评审。

---

## PR 2：组合式 API 迁移（破坏性）

**前置实验**（第一个 commit，scratch 探针，不进仓库）

- [ ] E2-1（R10）四个 init 加 `step: Int? = nil` 后重载解析：在开了 `-default-isolation MainActor` 的 scratch 里编译
  `TimelineItem { … }`、`TimelineItem { … } content: { … }`、`TimelineItem("A")`、`TimelineItem("A") { Text("rich") }`、
  `TimelineItem("A", step: 1) { … } content: {}`，确认无歧义；有歧义则停下回 spec 调签名。
- [ ] E2-2 泛型宿主识别：先落 `Timeline<Content>` 空壳 + 旧 init 删除前，跑 `ComponentExtensionPointGuard` 确认仍 16、`Timeline` 仍被识别为 `TimelineLayout` 的宿主。
- [ ] E2-3（spec §3.6 推断）`.grouped` 下未摆放的节点子视图不进无障碍树：专用模拟器 + `axe describe-ui --point` 在节点位置命中测试（整树输出含隐藏元素，不可用来判），读数写 PR 正文。

**改动文件**

- `Timeline.swift`：`Timeline<Content: View>` + `Group(subviews:)` 解析前下发 `layout`；`ContainerValues` 角色（`.node` / `.content`）、`step`、`status`；
  `TimelineItem<Node, Content>: View` 自己产出「节点（包单一容器）→ 内容」两个子视图；四个 init（spec §1.2）；结构件（标题 `.coreFont(.callout)` +
  `.isHeader`，时间 / 描述 `.coreFont(.footnote)`）；删旧 `TimelineItem` struct、`Timeline(items:layout:)`、`isLastItem`、`groupedStatusKey(for:)` 改形。
  标题 / 描述只接 `LocalizedStringKey`（U13）。`TimelineNodeView` 与 `private var nodeContent: some View` 留在本文件。
- `TimelineStackLayout.swift`：加 `pairParts(roles:)`；从 `containerValues` 配对；非行子视图按 spec §1.5 摆放、`.alternate` 截断连线。
- 无障碍（U8，状态键部分）：默认圆点 `.accessibilityHidden(true)`；有 `title` 的行把状态键挂标题元素（a4）；无 `title` 的行内容 `.combine` + 值（a2）；自定义节点行不带状态键。阶段键留到 PR 3。
- 调用点：`App/Sources/ComponentData.swift`、`App/Sources/Previews.swift`、`scripts/downstream-probe/…/PublicVisibility.swift`、
  `Tests/OhMyDesignTests/TimelineTests.swift`（结构断言重写，**保留**按 asset 名断言那一族）、`DynamicTypeLayoutTests.swift`、`TimelineLegacy420GateTests.swift`（新侧）、
  `Timeline.swift` 自身 `#Preview` 画廊。活动流、部署日志两个参考形态进 `Previews.swift` 与画廊。
- 登记：总表 PR 2 列全部（registry 59、`TimelineItem` 条目、21 → 23、公约 D1 加注、`ComponentJudgeRulesTests` MARK、`Timeline.notes` 更正、BREAKING、timeline.md、快照、AGENTS / CLAUDE 复核、PRD FR-1、digest）。

**判据**（spec §9.2，类型 `TimelineCompositionTests`）

| 判据 | 形式 |
|---|---|
| 配对与行序（含 `ForEach` / `if` / 非行子视图 / 调用方多视图节点闭包） | 位图量内容左缘 / 顶沿；多视图节点只占一个盒；`pairParts` 纯函数双腿 |
| 行上修饰作用于节点 | `.opacity(0.5)` 施在行上：节点、内容都半透 |
| 行被包进 `VStack` | 节点与内容仍出现 |
| `timelinePhase` 两槽读数恒 `nil`（PR 3 前没有 `progress`） | 读环境的探针画成色块 |
| `.grouped` 不摆节点 | 位图无节点像素 + E2-3 手工读数 |
| 旧实现闸门（新 API 写法） | `TimelineLegacy420GateTests` |
| 状态值挂载点（a4 / a2 / 自定义节点无状态键） | 纯函数双腿 |
| 登记 | `ComponentExtensionPointGuard`（16）、`ComponentRegistryGuard`（59）、`QuotedEvidenceGuard`、`ComponentTextParamGuard`（23）、`BoolExemptionGuard`、`ComponentJudgeRulesTests` |

**计划变异**：行的 body 不给节点包单一容器（「节点闭包本来就是一个视图」）→ 多视图节点配对红；容器对 `Subview` 施 `.environment`（「更 SwiftUI 的写法」）→ PR 3 的
`timelinePhase` 判据会红，本 PR 用一个读自定义环境键的探针先钉住解析前通路；改回「容器画节点」→ 「行上修饰作用于节点」红；无 `title` 的行把值挂在未 `.combine` 的内容上 → 挂载点纯函数红。

**验证**

- 迭代：`swift test --filter 'OhMyDesignTests\.Timeline|ComponentRegistryGuard|ComponentTextParamGuard|ComponentExtensionPointGuard|ComponentJudgeRulesTests|QuotedEvidenceGuard|BoolExemptionGuard'`。
- 收尾：全量 macOS → iOS `-only-testing:` `TimelineTests`、`TimelineNodeColorRenderTests`、`TimelineGeometryPureTests`、`TimelineLegacy420GateTests`、
  `TimelineCompositionTests`、`DynamicTypeLayoutTests`、`ComponentRegistryGuard`、`QuotedEvidenceGuard`（均带 `OhMyDesignTests/` 前缀）→ 预览宿主（核三样）→ probe → 棘轮 → `api-surface-diff.sh` → digest。

---

## PR 3：阶段（加法）

**前置实验**：无新增（U8 的挂载形态已由 spec P10 实测）。开工前核 `Legacy420` 仍在。

**改动文件**

- `Timeline.swift`：`public nonisolated enum TimelineProgress`（含 `phase(forStep:)`）、`public nonisolated enum TimelinePhase`、
  `init(layout:progress:content:)`、`EnvironmentValues.timelinePhase`（手写 `EnvironmentKey` + `public internal(set)`，不用 `@Entry public var`）；
  解析前下发 `progress`；行用自己的 `step` 算阶段并给 `node:` / `content:` 两槽都施；默认圆点三形态（spec §4.2，U3）。
- `TimelineStackLayout.swift`：段着色看后一行（`.tint` / `dividerDefault`），`P` 计算（静态）。
- 无障碍：阶段键以「, 」接在状态键后；自定义节点行只带阶段键。
- `Localizable.strings` 三键；路线图参考形态进 `Previews.swift` 与画廊；probe 补阶段 API。
- 登记：总表 PR 3 列。

**判据**（spec §9.3 / §9.4）

| 判据 | 类型 |
|---|---|
| 真值表逐行（`.notStarted` / `.inProgress(at: -1 / 0 / 2 / 末 / 末+1 / 空档)` / `.completed` × 连续 / 空档 / 重复 / 非单调 / 部分 `nil`），段着色与 `P` 同表 | `TimelinePhaseTruthTableTests` |
| 着色接线（`.tint(.black)`、5 行、`.inProgress(at: 2)`；`.completed` 全黑；不传 `progress` 与 `Legacy420*` 同图——这条放进 `TimelineLegacy420GateTests`） | `TimelinePhaseRenderTests` + `TimelineLegacy420GateTests` |
| 形态接线（`status: .neutral` 三阶段两两「应不同」，`completed` 与活动流「应相同」） | `TimelinePhaseRenderTests` |
| `timelinePhase` 两槽有值、`Timeline` 外恒 `nil` | `TimelineCompositionTests`（改 PR 2 那条） |
| 无障碍取值纯函数（`status × 有无自定义节点 × phase × 有无 title` → 值键序列 + 挂载点）；iOS `axe --point` 手工读一次 | `TimelineAccessibilityValueTests` |
| 与 `Steps` 不共用类型：`Timeline` 目录无 `StepsProgress` / `StepItem`，`Steps` 目录无 `TimelineProgress` / `TimelinePhase`；`git diff --stat origin/epic/structure-components -- Sources/OhMyDesign/Components/Steps/` 为空 | `TimelineStepsIsolationGuard` + 手工 |

**计划变异**：照 reui 写成 `s <= k` 判已完成 → 真值表红；段着色看行 `j` 而非 `j+1` → 着色接线红；不传 `progress` 当 `.completed` → 闸门红；
自定义节点行漏阶段键 → 无障碍纯函数红。

**验证**

- 迭代：`swift test --filter 'OhMyDesignTests\.Timeline|AccessibilityStringLiteralGuard|ReachableTypeRegistryGuard|QuotedEvidenceGuard|ComponentRegistryGuard'`。
- 收尾：全量 macOS → iOS `-only-testing:` 上 PR 的列表 + `TimelinePhaseTruthTableTests`、`TimelineAccessibilityValueTests`、
  `TimelineStepsIsolationGuard`、`AccessibilityStringLiteralGuard` → 预览宿主 → probe → 棘轮 → `api-surface-diff.sh`（只增）→ digest。
- 视觉：三阶段默认圆点（进行中外环不透明度草案 0.4）截图交视觉评审。

---

## PR 4：动效（最后一个 commit 删除 `Legacy420*`）

**前置实验**（第一个 commit 之前，scratch，不进仓库）

- [ ] **E4-1（S-6 / R12）圆点与连线同步探针**：解析前下发的 `P_step` 环境值在 `withAnimation` 事务里变化时，行内 `Animatable` 圆点的 `animatableData`
  是否被插值。托管窗口 `cacheDisplay` 每 8ms 采一帧，`(at: 0)` → `(at: 3)`，量第 `j` 行圆点形态变化帧与第 `j−1` 段填满帧。
  **核不过** ⇒ 圆点退回独立 `.coreAnimation(.reveal, value: phase)`，spec §6.2 与 timeline.md 登记「不同步」，§9.5「圆点与连线同步」判据改为登记项。结论与读数写 PR 正文。
- [ ] E4-2（R3，非阻塞）iOS 上 `onScrollVisibilityChange` 首帧 / 同步触发是否闪帧：专用模拟器录屏手工观察一次，读数写 PR 正文与 timeline.md「不在 CI」清单。
- [ ] E4-3 快照入场帧：`run-snapshots.sh` 的渲染路径是否会取到入场第 0 帧（spec §6.3：`.animated` 下 `ImageRenderer` 会取到）。若会，给快照宿主注入
  `coreMotionPresentationOverride(.resting)`，而不是改组件。

**改动文件**

- `TimelineStackLayout.swift` / `Timeline.swift`：连线段 `Animatable`（通路 A 长度插值）；`.resting` 下通路 B 只动不透明度（`CoreMotionToken.reveal.animation(for: presentation)`）；
  圆点按 E4-1 结论接同一 `P_step` 或独立插值；入场：`onScrollVisibilityChange(threshold: 0.5)` + 节点视图 `@State` 闩锁 + 回调里**同步**置 trigger +
  `keyframeAnimator(initialValue: 1)`，只在 `.animated` 下触发。
- `Tests/OhMyDesignTests/CoreMotionTokenDisciplineGuard.swift` 台账两处。
- 新建 `TimelineMotionTests.swift`（`TimelineMotionInFlightTests`）。
- 登记：总表 PR 4 列。
- **最后一个 commit**：删 `TimelineLegacy420.swift`、`TimelineLegacy420GateTests.swift`；「静止帧」`.resting` 一侧改为自参照；grep `Legacy420` 为零。

**判据**（spec §9.5，`TimelineMotionInFlightTests`，macOS）：推进会生长（RM 关）；推进不生长（RM 开，只出现段边界值）；回退从远端收（单调不增）；
圆点与连线同步（按 E4-1）；入场按视口触发（第 8 行滚入出现 ≥ 2 个中间值）；入场无闪帧（滚入后第一帧 < 1×）；不重播；无滚动宿主挂载即播；
入场 RM 不播；静止帧（`.resting` = 终态；`.animated` 下 `ImageRenderer` 取到入场第 0 帧）；源码台账（`CoreMotionTokenDisciplineGuard`）。
拍不到中间帧按 `observeControlMotion` 的「无法下结论」处理，不判绿。

**计划变异**：推进用 `.animation(CoreMotionToken.reveal.animation, value: position)` 绕过 `coreMotionPresentation` → 「RM 开不生长」红；入场改挂 `.onAppear` →
「按视口触发」红；闩锁放进会被重建的子视图 → 「不重播」红；trigger 推迟到下一轮 runloop（「避免在回调里改状态」）→ 「入场无闪帧」红；
入场 `initialValue` 写成 0.86 → 「静止帧」`.resting` 一侧与 `TimelineLegacy420GateTests` 红（**必须在删闸门的 commit 之前做**）。

**验证**

- 迭代：`swift test --filter 'OhMyDesignTests\.Timeline|CoreMotionTokenDisciplineGuard|CoreMotionTokenInFlightTests'`。在飞帧判据单独跑、不与其他构建并行。
- 收尾：全量 macOS（与 iOS 不并行）→ iOS `-only-testing:` PR 3 列表（去掉 `TimelineLegacy420GateTests`）+ `CoreMotionTokenDisciplineGuard`
  （`TimelineMotionInFlightTests` 在 iOS 上不编译，不列）→ `api-surface-diff.sh`（应为空）→ digest → 快照重生成比对无差异。
- 视觉：入场与推进录屏交视觉评审（spec R2：`cacheDisplay` 与屏幕合成帧是否逐帧一致未测）。
- 删闸门后收尾一次：`grep -rn 'Legacy420' Sources Tests App docs` 只剩 BREAKING / spec / plan 的文字提及。

---

## 风险回指

spec §12 的 R1–R12 不在此重复；与本计划执行顺序直接相关的三条：

- R10 → PR 2 的 E2-1（第一个 commit 前）。
- R12 → PR 4 的 E4-1（核不过有退路，不阻塞 PR 4）。
- R4（架构排斥惰性）→ 不在本 issue；timeline.md 规模一节在 PR 1 写明 n = 300 / 1000 的量级与「超长时间线另起管线」。
