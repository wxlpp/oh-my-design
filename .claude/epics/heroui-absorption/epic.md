---
name: heroui-absorption
status: backlog
created: 2026-09-22T01:21:37Z
updated: 2026-09-22T01:21:37Z
progress: 0%
prd: .claude/prds/heroui-absorption.md
github: (will be set on sync)
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
| 001 | 字段校验基础层 + `FormField` | FR-1 | M | — |
| 002 | 5 个控件接入校验态 + `SearchField` 禁用透传 / 回车键 | FR-2、FR-3 | M | 001 |
| 003 | `StatusLevel.neutral`（原子，含全部消费者） | FR-4 | S | — |
| 004 | Banner 补齐（title / actions / dismiss，a11y 拆元素） | FR-5 | M | 003 |
| 005 | Toast 补齐（API 改名、ToastAction、ToastDuration、状态机） | FR-6 | L | 003 |
| 006 | Badge / Tag / Avatar 尺寸体系 + `AvatarSize` | FR-7 | M | — |
| 007 | `anchoredBadge` modifier | FR-8 | S | — |
| 008 | `TagGroup` | FR-9 | M | 006 |
| 009 | `.coreCircular` 进度环 + 按压反馈 ButtonStyle | FR-10、FR-11 | S | — |
| 010 | surface 有效层级 + `coreSheetPresentation()` | FR-12、FR-13 | M | — |

## Dependencies

- 冲突面（共享文件，合并时按「未发布」节各自追加、rebase 解决）：`docs/BREAKING-CHANGES.md`、
  `docs/component-registry.json`、`docs/README.md`、`docs/design-digest.md`、`App/Sources/ComponentData.swift` /
  `Previews.swift`、bool 基线——几乎所有 issue 都会碰，**不据此串行**，只要求每个 PR 合入前 rebase 到最新 epic 分支并重跑守卫。
- 真实源码冲突：004 与 005 都依赖 003 改过的 `Banner.swift` / `Toast.swift`；004 只改 Banner、005 只改 Toast，
  可在 003 合入后并行。002 独占 `SearchField.swift`。006 与 008 同触 `Tag.swift`（008 在后）。
  006 与 009/010 同触 `CoreControlMetrics.swift` / `CoreButtonMetrics.swift` 的可能性低，出现时后合者 rebase。

## Success Criteria (Technical)

- PRD Success Criteria 全部满足（以行为判据为主）。
- 每个 issue PR：macOS `swift test` + iOS Simulator xcresult 全绿、预览宿主构建、downstream-probe 构建、
  MainActor 棘轮豁免数不增。
- epic 分支合入 main 前全量复跑一次上述验证。

## Estimated Effort

S×3、M×6、L×1，约 8–12 个 agent 工作日；两波并行后日历时间约 3–4 天。

## Tasks Created
- [ ] 001.md - 字段校验基础层 + FormField (parallel: true)
- [ ] 002.md - 5 个控件接入校验态 + SearchField 修复 (parallel: true, depends 001)
- [ ] 003.md - StatusLevel.neutral（原子，含全部消费者） (parallel: true)
- [ ] 004.md - Banner 补齐 (parallel: true, depends 003)
- [ ] 005.md - Toast 补齐 (parallel: true, depends 003)
- [ ] 006.md - Badge / Tag / Avatar 尺寸体系 (parallel: true)
- [ ] 007.md - anchoredBadge modifier (parallel: true)
- [ ] 008.md - TagGroup (parallel: true, depends 006)
- [ ] 009.md - coreCircular 进度环 + 按压反馈 ButtonStyle (parallel: true)
- [ ] 010.md - surface 有效层级 + coreSheetPresentation (parallel: true)

Total tasks: 10
Parallel tasks: 6（第一波：001、003、006、007、009、010；003 合入后 004/005，001 后 002，006 后 008）
Sequential tasks: 4（002、004、005、008）
Estimated total effort: 85 hours
