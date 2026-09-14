# #337 实施计划：裸行号引用守卫（形态 2）

## 已定形态

**形态 2（引文逐字核）**：散文引用源码必须带被引原文，判据核原文仍在文件中——
比核行号强（行号漂了不假红）。依据 = 普查数据（129 失真中 77 是纯行号漂移、被引文字仍在）。
复用 `#316` `SingleSourceOfTruthGuard` 的 `factSites` 形态（显式登记 + 逐条回扫）。

## 步骤

### 1. 复跑普查（现 main），产出逐条清单

```bash
grep -rnoE '[A-Za-z0-9_/.-]+\.swift:[0-9]+(-[0-9]+)?' docs/ CLAUDE.md README.md AGENTS.md
```

（评论口径：160 条 / 129 失真 / 18 成立 / 13 跨仓。开工树与 `a4afd16` 不同，数目会有出入——
以复跑为准，**别照抄评论里的数**。）逐条核验档位，落成清单文件（`docs/issues/337-census.md`
或计划内附件），每行：引用 / 被引内容现状 / 档位 / 修法。

### 2. 修 129（按档位）

- **77 纯漂移**（被引文字还在同文件）：按形态 2 改写——保留「文件 + 被引原文」、
  删裸行号（或把行号降为附注）。⚠️ 这些改写本身就是新守卫的登记源。
- **26 整段被删**：删除引用，或换成仍存在的证据（issue 点名的 `RingChart` `SectorMark`
  类比句已删 ⇒ 把 `component-registry.json` `RingChart.notes` 与 `contract-defects.md`
  里的承重证据换成仍然存在的东西，不得换一个同样脆弱的新引用）。
- **25 重构顶掉**：按现状重写（如 `BorderlessButtonStyle` → `CoreBorderlessButtonStyle`）。
- **1 抄错**：改正。
- **13 跨仓**：如实登记（列表写进守卫文件或 docs），不追进他仓。

### 3. ⚠️ 优先修 `docs/contract-defects.md:1436`

J-2 描述被 `5241175` 推翻：现 `ComponentJudgeRules.swift` **四分支**
（`nativeProtocol` / `customStyleProtocol` / `styleSlot` / `styleEnum`）。
这句话现在会让读文档的人得出与 `#312` 相反的结论，必须按现状重写。

### 4. 装守卫（形态 2）

- 新 suite（`Tests/OhMyDesignTests/`，如 `ProseQuoteGuardTests` + 登记表）：
  登记项 = {文档文件, 源文件, 被引原文}；判据 = 原文（空白归一后）仍在该源文件中存在。
- 登记范围：第 2 步改写后的**全部**活文档源码引用（18 条原成立的 + 77 条改写后的）。
- 判据按「整段逐字（dense）+ 名字」匹配，**不得**按行号 / 形状（本任务的敌人就是行号）。
- 扫描根走 `GuardScanRoots.allRoots`（三 target 全覆盖）。
- 变异实证**换族**：
  (a) 从源码删掉被引原文 ⇒ 红；
  (b) 改文档里被引原文一个字 ⇒ 红；
  (c) 遮蔽族：在源码被引处**上方加内容**、改等价拼写——判据应照绿（它不依赖行号/形状）；
  (d) 不在登记表里的引用不判红（射程正确性）。
  每处变异先断言「变异真的落到了文件里」再跑判据（CLAUDE.md 规矩）。

### 5. 文档收尾

- `CLAUDE.md`「更正传播」节的「全靠人工」句改指新守卫（⚠️ 改了 CLAUDE.md 要跑
  `AgentGuideSyncGuard` 相关 suite）。
- 关闭评论引用普查清单与判据名。

## 验收

- 129 条逐条修复（清单留档）；`RingChart` 承重证据换新。
- `contract-defects.md:1436` 按四分支现状重写。
- 新守卫带换族变异实证，macOS native + iOS Simulator 两条腿全绿。
