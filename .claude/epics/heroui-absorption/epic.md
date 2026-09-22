---
name: heroui-absorption
status: in-progress
created: 2026-09-22T01:21:37Z
updated: 2026-09-22T06:02:25Z
progress: 20%
prd: .claude/prds/heroui-absorption.md
github: https://github.com/wxlpp/oh-my-design/issues/372
---

# Epic: heroui-absorption

## Overview

对照 HeroUI v3 吸收 11 项能力（13 条 FR），全部落在 `OhMyDesign` 主 target；不新增 target、
不改 `Package.swift`。契约细节以 PRD 为准（已过 codex 两轮交叉审），本 epic 只做拆解、依赖与冲突面。
对照依据：`heroui-analysis.md`（同目录）。

## Architecture Decisions

- **环境值优先**：字段校验态（`fieldValidation` / `fieldRequirement`）、surface 有效层级都走 `@Entry`，
  不给组件加 Bool / 状态参数；与 `\.toastHost`、`\.coreAccent` 同形。
- **换皮不重造**：进度环是 `ProgressViewStyle`，按压反馈是 `ButtonStyle`，sheet 是 presentation modifier；
  `TextField` / `Toggle` / sheet 本体仍用原生。
- **破坏性变更允许但必须登记**：`StatusLevel.neutral`、`ToastItem.message → title`、`ToastDuration`、
  `BannerStyleConfiguration` 字段、`Avatar` 默认固定直径——各 issue 在 `docs/BREAKING-CHANGES.md`
  的「未发布」下各自加一节。
- **选择色从环境 `coreAccent` 派生**（TagGroup），角标色固定 `statusDangerEmphasis`（与系统角标一致）。

## Technical Approach

### Frontend Components
- 新增：`FormField`、`TagGroup`、`View.anchoredBadge`、`.coreCircular`、`.pressableRow` / `.pressableCard`、
  `View.coreSheetPresentation()`、`FieldValidation` / `FieldRequirement` / `ToastDuration` / `ToastAction` /
  `AvatarSize` / `AnchoredBadgeContent` 等支撑类型。
- 改造：`PinCode`、`TagInput`、`SearchField`、`CheckBoxToggleStyle`、`RadioGroup`、`StatusLevel` 及其消费者
  （`Banner` / `Toast` / `Timeline`）、`Banner`、`Toast`、`Badge`、`Tag`、`Avatar`、`AvatarGroup`、
  `SurfaceModifier`、`CoreControlMetrics`。

### Backend Services
无。

### Infrastructure
无新 target / CI 改动。守卫台账（component-registry、bool 基线、digest FLOORS、QuotedEvidence、
MainActor 棘轮）按各 issue 的真实增量更新。

## Implementation Strategy

Issue 级 PR 进 `epic/heroui-absorption`，每个 issue 私有 worktree。第一波并行 6 个无依赖 issue，
第二波 4 个依赖项。UI 类 issue 收尾在模拟器截图交视觉评审。外部评审用 codex（Copilot 至 2026-10-01 不可用）。

## Task Breakdown Preview

| # | task | FR | size | 依赖 |
|---|---|---|---|---|
| #373 | 字段校验基础层 + `FormField` | FR-1 | M | — |
| #374 | 5 个控件接入校验态 + `SearchField` 禁用透传 / 回车键 | FR-2、FR-3 | M | #373 |
| #375 | `StatusLevel.neutral`（原子，含全部消费者） | FR-4 | S | — |
| #376 | Banner 补齐（title / actions / dismiss，a11y 拆元素） | FR-5 | M | #375 |
| #377 | Toast 补齐（API 改名、ToastAction、ToastDuration、状态机） | FR-6 | L | #375 |
| #378 | Badge / Tag / Avatar 尺寸体系 + `AvatarSize` | FR-7 | M | — |
| #379 | `anchoredBadge` modifier | FR-8 | S | — |
| #380 | `TagGroup` | FR-9 | M | #378 |
| #381 | `.coreCircular` 进度环 + 按压反馈 ButtonStyle | FR-10、FR-11 | S | — |
| #382 | surface 有效层级 + `coreSheetPresentation()` | FR-12、FR-13 | M | — |

## Dependencies

- 冲突面（共享文件，合并时按「未发布」节各自追加、rebase 解决）：`docs/BREAKING-CHANGES.md`、
  `docs/component-registry.json`、`docs/README.md`、`docs/design-digest.md`、`App/Sources/ComponentData.swift` /
  `Previews.swift`、bool 基线——几乎所有 issue 都会碰，**不据此串行**，只要求每个 PR 合入前 rebase 到最新 epic 分支并重跑守卫。
- 真实源码冲突：#376 与 #377 都依赖 #375 改过的 `Banner.swift` / `Toast.swift`；#376 只改 Banner、#377 只改 Toast，
  可在 #375 合入后并行。#374 独占 `SearchField.swift`。#378 与 #380 同触 `Tag.swift`（#380 在后）。
  #378 与 #381/#382 同触 `CoreControlMetrics.swift` / `CoreButtonMetrics.swift` 的可能性低，出现时后合者 rebase。

## Success Criteria (Technical)

- PRD Success Criteria 全部满足（以行为判据为主）。
- 每个 issue PR：macOS `swift test` + iOS Simulator xcresult 全绿、预览宿主构建、downstream-probe 构建、
  MainActor 棘轮豁免数不增。
- epic 分支合入 main 前全量复跑一次上述验证。

## Estimated Effort

S×3、M×6、L×1，约 8–12 个 agent 工作日；两波并行后日历时间约 3–4 天。

## Tasks Created
- [ ] 373.md - 字段校验基础层 + FormField (parallel: true)
- [ ] 374.md - 5 个控件接入校验态 + SearchField 修复 (parallel: true, depends #373)
- [ ] 375.md - StatusLevel.neutral（原子，含全部消费者） (parallel: true)
- [ ] 376.md - Banner 补齐 (parallel: true, depends #375)
- [ ] 377.md - Toast 补齐 (parallel: true, depends #375)
- [ ] 378.md - Badge / Tag / Avatar 尺寸体系 (parallel: true)
- [ ] 379.md - anchoredBadge modifier (parallel: true)
- [ ] 380.md - TagGroup (parallel: true, depends #378)
- [ ] 381.md - coreCircular 进度环 + 按压反馈 ButtonStyle (parallel: true)
- [ ] 382.md - surface 有效层级 + coreSheetPresentation (parallel: true)

Total tasks: 10
Parallel tasks: 6（第一波：#373、#375、#378、#379、#381、#382；#375 合入后 #376/#377，#373 后 #374，#378 后 #380）
Sequential tasks: 4（#374、#376、#377、#380）
Estimated total effort: 85 hours
