---
name: structure-components
status: in-progress
created: 2026-09-23T01:14:48Z
updated: 2026-09-23T15:55:15Z
progress: 57%
prd: .claude/prds/timeline-tree-action-buttons.md
github: https://github.com/wxlpp/oh-my-design/issues/416
---

# Epic: structure-components

PRD `timeline-tree-action-buttons` 的 FR-1 / FR-2 / FR-2a（另一半在 epic `action-buttons`，共用同一份 PRD）。
这一半**重**：含一次破坏性 API 变更，含一个射程未知的 spike，含本仓第一个递归组件。

同目录的取证材料（两个 epic 共用）：
- `reference-implementations.md` —— reui Timeline / Tree 的完整源码与 API 表；
  Tree 的键盘行为**不在 reui 文档里**，取自 `@headless-tree/core`，来源已标注
- `repo-survey.md` —— 本仓 Timeline / 按钮体系 / 手势 / 新组件登记面的现状盘点
- `prd-review-round1.md` / `prd-review-round2.md` —— PRD 两轮对抗式评审（两轮都抓出过现状声称为假）

| task | FR | 依赖 | 文件 |
|---|---|---|---|
| Tree 实现路径与键盘射程 spike | FR-2a | — | 只产结论文档，不落生产代码 |
| Timeline 改组合式 API（破坏性） | FR-1 | — | Components/Timeline/、App/Sources/\*、docs、downstream-probe |
| CheckBox 增读系统 mixed 态 | FR-2 前置 | — | Components/CheckBox/CheckBox.swift |
| Tree 本体（展开 / 选择 / 三态 / 键盘） | FR-2 | spike、CheckBox | Components/Tree/（新） |
| Tree 搜索过滤与命中高亮 | FR-2 | Tree 本体 | Components/Tree/ |

spike 与 Timeline、CheckBox 三项互不重叠，可**并行起步**；Tree 本体等 spike 与 CheckBox；
Tree 搜索接在 Tree 本体之后（同一批文件，不并行）。

## 三条会咬人的约束（都是评审抓出来的，别重新踩）

1. **Timeline 的迁移面比看起来大**。除了 `App/Sources/ComponentData.swift`（4 处）与
   `App/Sources/Previews.swift`（5 处，含共享 fixture `PreviewSnapshotFixtures.timelineItems`）、
   `scripts/downstream-probe`，还有 **`QuotedEvidenceGuard` 登记的 5 条指向 Timeline 源码的原文**
   （`@ViewBuilder node: () -> Node,` ×2、`private var nodeContent: some View` ×2、
   `static let nodeColumnWidth: CGFloat = 24` ×1），分别被 `docs/contract-defects.md` /
   `docs/component-contract.md` / `docs/component-registry.json` 引用 ⇒ 删这些符号会让判据判红，
   **三份活文档必须同步改**。
   ⚠️ 数调用点用 `grep "Timeline("` 并排除 `TimelineView`，**不要**按参数名 `Timeline(items:` 匹配
   ——那样会漏掉换行写法（上一版 PRD 就是这么少算了各一处）。
2. **父节点三态不需要新控件模型**。`ToggleStyleConfiguration.isMixed` 自 iOS 16 / macOS 13 即存在，
   `Toggle(sources:isOn:label:)` 从一组绑定自动派生 on / mixed / off。
   ⇒ CheckBox 那一项只是 `makeBody` 增读 `configuration.isMixed` 并呈现第三种符号；
   Tree 的父行用 `Toggle(sources:)`。**读 `configuration` 上的 Bool 不违反禁 Bool 入参那条纪律。**
3. **走递归 `DisclosureGroup` 免费拿到的不是原生外观**。`CoreDisclosureGroupStyle` 自绘
   `DisclosureChevron`、自行 `withAnimation(.snappy)`，且 `docs/components/core-control-styles.md`
   已登记「换皮后系统不再自动为这个自绘 `Button` 播报展开态」⇒ 免费拿到的是**系统的展开态接口与嵌套能力**，
   不是原生 chevron / 动画 / 无障碍播报。spike 要按这个前提比较三条路径。

## Tasks Created
- [x] 419.md - Tree 实现路径与键盘射程 spike (parallel: true)
- [ ] 420.md - Timeline 改组合式 API (parallel: true)
- [x] 421.md - CheckBox 增读系统 mixed 态 (parallel: true)
- [x] 422.md - Tree 本体 (parallel: false, depends #419 + #421)
- [ ] 423.md - Tree 搜索过滤与命中高亮 (parallel: false, depends #422)
- [x] 429.md - Tree 密度与样式扩展点：controlSize + TreeStyle (parallel: false, depends #422, conflicts #423)
- [ ] 431.md - Tree 单击父行展开 / 折叠（行为枚举参数） (parallel: false, depends #429, conflicts #423)
