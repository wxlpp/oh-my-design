# #312 实施计划：组件样式扩展点 + 两条落点裁定

裁定与设计的唯一依据是 `312-spec.md`（已过一轮设计评审并按评审修订）。本计划只定执行顺序、分工与验证。
⚠️ 本文件是 tracked 的 md：不得逐字写 `SingleSourceOfTruthGuard.factSites` 登记的短语。

## 已定裁决（spec §0）

- `OrbitingLogos`：翻至出口 1（`step2` / `semantic` / 需要扩展点），走修订回路（`## #312` 节 + R-49 + 公约注记）。
- `D-299-1` 重核：只登记、**不改落点**（原计划阶段 1b「计 ⇒ 退回步骤 4」作废，理由 spec §2.4）；
  `RadarChart` 3 → 2 不翻；`ActivityHeatmap` 口径未定（双平台不翻 / iOS 单平台会翻）；`RingChart` 至少会翻。
- 本 issue 不走 `D-299-1` 修订回路；翻转与五个枚举同 PR；`RingChart.segmentCount` 固定 10。
- 五条全走 D2：`RadarChartLayout` / `RingChartLayout` / `ActivityHeatmapLayout` / `BeforeAfterSliderLayout` / `OrbitingLogosLayout`。

## 阶段 A：五个组件并行实现（各自 worktree，分支基于本分支）

每个组件一个实现者，只触：该组件源码（含同文件 helper，`OrbitingLogos` 另触 `OrbitRing.swift`）、
新判据文件、该组件的 `docs/components/*.md`（API 块 + 「布局形态扩展点」节 + spec §4.5 要求写明的取舍）。
**不触**：`docs/component-registry.json`、`ComponentExtensionPointGuard`、contract 三文档、README、
BREAKING-CHANGES、downstream-probe、design-digest（全部归阶段 B，避免冲突）。
在 registry 未改前，J-2 红名单仍与已知集合相等 ⇒ 各 worktree 的 `swift test` 应保持全绿。

每个实现者的验证：`swift build`；`swift test --filter <新判据类型名>`；再跑与该文件相关的既有守卫
（`ReduceMotionGuard` / `MicroInteractionReduceMotionGuard` / `SingleSourceOfTruthGuard` / `EffectsColorLiteralGuard` /
`QuotedEvidenceGuard` / 该组件既有测试）并以 `Test run with N tests` 非零为准；每个 layout 渲染一张 PNG 到
scratchpad（不入库）供视觉评审。

## 阶段 B：集成与同步（合并阶段 A 后，一个起草者）

按 spec §1.3 / §2.6 / §4 逐条：registry 五条 `styleEnum` + `OrbitingLogos` 三字段翻转 + notes；
`ComponentExtensionPointGuard` 收缩（`inspected.count` 17、红名单与跟进常量删除、裸 `#expect`、五条 D2 正向断言）；
`ComponentJudgeMutationTests` 三处；`contract-defects.md` 新 `## #312` 节 + `D-299-1` 重核段 + 副本注记；
`component-contract.md` 注记；`component-contract-revisions.md` R-49 + R-48 追加行；`CLAUDE.md` / `AGENTS.md` 计数；
`docs/README.md` 索引；`BREAKING-CHANGES.md` 未发布节；downstream-probe；`design-digest.py` `FLOORS` + 重生成；
epic / PRD / 任务文件最终态。

## 阶段 C：交付验证

1. `swift test --xunit-output`（全量，文档全部改完之后跑）；
2. iOS Simulator 腿 `xcodebuild test -scheme OhMyDesign-Package … -resultBundlePath`，读顶层 `passedTests`；
3. `swift build --build-tests && scripts/mainactor-static-ratchet.sh`；
4. `cd scripts/downstream-probe && swift build -Xswiftc -warnings-as-errors`；
5. `python3 scripts/design-digest.py && git diff --exit-code -- docs/design-digest.md`；
6. 两条 `swift package describe` 隔离判据；
7. 变异实证：删一条 `styleEnum` ⇒ J-2 红；改名一个枚举 ⇒ J-2 红（每处变异先断言落地）。
   给 `prescriptive` 条目填 `styleEnum` **今天不判红**（spec §4.1），不作为变异项。
8. 视觉评审（ios-visual-reviewer）看阶段 A 的各形态 PNG。

然后交付评审（superpowers-reviewer，finishing 焦点）→ PR（base = `epic/issue-backlog-closeout`）→ auto-fix。
