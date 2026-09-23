---
name: action-buttons
status: backlog
created: 2026-09-23T01:14:22Z
updated: 2026-09-23T01:14:22Z
progress: 0%
prd: .claude/prds/timeline-tree-action-buttons.md
github: https://github.com/wxlpp/oh-my-design/issues/415
---

# Epic: action-buttons

PRD `timeline-tree-action-buttons` 的 FR-3 / FR-4（另一半在 epic `structure-components`，共用同一份 PRD）。
两项都是**新增组件、无破坏性变更**，所以与重的那一半拆开、可先出。

取证材料在 `.claude/epics/structure-components/`（两个 epic 共用，按路径引用，不复制）：
- `reference-implementations.md` 第 3 节 = Aceternity stateful-button 源码与状态机逐行分析；
  第 4 节 = 滑动确认的三个实现调研（其中 `no-comment/SlideButton` 是逐行读过的 SwiftUI 源码）
- `prd-review-round1.md` / `prd-review-round2.md` = PRD 两轮对抗式评审

| task | FR | 依赖 | 文件 |
|---|---|---|---|
| StatefulButton | FR-3 | — | Components/Button/StatefulButton.swift（新） |
| SlideToConfirm | FR-4 | — | Components/SlideToConfirm/（新） |

两项文件不重叠、可并行。都依赖 `CoreMotionToken`（epic #406 已合入 main）。

## 两项共同的硬约束

- 状态必须是**枚举**，不得拆成多个 Bool，也不得新增公开 Bool 入参（`BoolExemptionGuard`）。
- 文案参数走 `LocalizedStringKey`（`ComponentTextParamGuard`）。
- 新组件要登记 `docs/component-registry.json` + `docs/components/<name>.md`，
  并**逐项裁决**是否进入 `ComponentExtensionPointGuard` 的定义域
  （当前逐字写 `#expect(result.inspected.count == 16,` 并列出 16 个组件名——不要按新增数量直接加）。
- 动效走 `CoreMotionToken`，且必须过 `CoreMotionTokenDisciplineGuard` 的逐调用点台账
  （每处动画驱动要么引用 token、要么恰好是 `nil`）。
- Reduce Motion 降级要有判据；in-flight 采样只在 macOS 腿，承重量取结构量而非具体读数。

## Tasks Created
- [ ] 417.md - StatefulButton (parallel: true)
- [ ] 418.md - SlideToConfirm (parallel: true)
