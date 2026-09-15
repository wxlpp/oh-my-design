---
name: issue-backlog-closeout
status: in-progress
created: 2026-09-14T00:33:25Z
updated: 2026-09-15T19:45:58Z
progress: 100%
prd: .claude/prds/issue-backlog-closeout.md
github: https://github.com/wxlpp/oh-my-design/issues/363
---

# Epic: issue-backlog-closeout

承接 5 条遗留 open issue（`#240` / `#357` / `#337` / `#317` / `#312`）。
需求规格全部在 issue 正文与评论里（普查、裁决、约束均已就位），本 epic 只做
任务拆解、依赖排序与执行追踪。

## 任务分解（5 条，全部已有 GitHub issue，任务文件按 issue 号命名）

| # | task | size | 依赖 | 备注 |
|---|---|---|---|---|
| `#240` | BREAKING-CHANGES 三缺口核验 + v0.7.0 日期修正 + 关闭 | XS | 无 | 第 1/2 条已由 PR #323 交付，第 3 条由 v0.10.0 changelog 归版；剩日期一行 |
| `#357` | coreAccent on-accent 通路（已裁决：派生缺省 + on 可覆盖） | M | 无 | 触 `CoreAccentEnvironment.swift` / `ButtonRoleStyleRole` / `InkSegmentedControlStyle` / 判据 |
| `#337` | 裸行号引用守卫（形态 2 引文逐字核）+ 129 条修复 | M | 无 | 普查已做完（160 条 / 129 失真 / 13 跨仓）；与 `#312` 冲突面见下 |
| `#317` | 位图 1-LSB 偶发红：判据形态改容差 / 换钉性质 | M | 无 | 15 跑 4 红取样；先查离屏渲染确定性再定形态 |
| `#312` | 4 组件形态 D 扩展点 + OrbitingLogos 裁定 | L | `#337`（冲突面串行） | 来源已留档（HTTP 200 实测 + 正文存 `docs/issues/`） |

## 冲突面与并行性

- `#337` ↔ `#312`：同触 `docs/contract-defects.md` 与 `docs/component-registry.json`
  ⇒ `conflicts_with`，串行执行，`#337` 先行（它修的那处 `contract-defects.md:1436`
  被推翻描述直接关系 `#312` 的形态 D 结论）。
- `#240` / `#357` / `#317` 互相独立，与上两者冲突面为零 ⇒ 可并行。

## 集成拓扑（Issue 级 PR）

```
main
 └── epic/issue-backlog-closeout          ← 本 epic 集成分支（off main）
       ├── issue-240-*（worktree）→ PR → 合入
       ├── issue-357-*（worktree）→ PR → 合入
       ├── issue-337-*（worktree）→ PR → 合入
       ├── issue-317-*（worktree）→ PR → 合入
       └── issue-312-*（worktree）→ PR → 合入
（全部合入后）epic → main —— auto 模式硬停点，等用户确认
```

## 关键裁决与证据（本 epic 开工时已就位）

- `#357` API 裁决（用户，2026-09-14）：派生缺省 + `on` 参数可覆盖。
- `#312` `OrbitingLogos` 来源：2026-09-14 实测 HTTP 200、正文含 `OrbitingItem` 的
  `radiusX` / `radiusY` props 逐字（留档 `/tmp/animata.html`，随 PR 进 `docs/issues/`）。
  按 `D-299-2` 字面 ⇒ 计入 2 ≥ 2 ⇒ 出口 1；最终态 J-2 定义域 17 条、红名单空集并删除。
- `#337` 形态选定：形态 2（引文逐字核），依据 = 普查数据（129 失真中 77 是纯行号漂移，
  被引文字仍在 ⇒ 形态 2 对这 77 条免疫）。
