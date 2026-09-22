---
name: motion-foundations
status: in-progress
created: 2026-09-22T14:24:50Z
updated: 2026-09-22T14:24:50Z
progress: 0%
prd: .claude/prds/motion-foundations.md
github: https://github.com/wxlpp/oh-my-design/issues/406
---

# Epic: motion-foundations

对照 UI TripleD 的 P1（分析见同目录 `tripled-analysis.md`）。

| task | FR | 依赖 | 文件 |
|---|---|---|---|
| #407 动效 token + Reduce Motion 纪律（含 spike） | FR-1、FR-2、FR-3 | — | Tokens/CoreMotion.swift（新）、现有动效点、新判据 |
| #408 原生符号 / 数字动效接入小件 | FR-4 | #407 | AnchoredBadgeModifier、CheckBox、Radio |
| #409 TagGroup / TagInput 动画 | FR-5 | #407 | TagInput、TagGroup、Tag |

#407 先行；#408 与 #409 文件不重叠，#407 合入后并行。

## Tasks Created
- [ ] 407.md - 动效 token + Reduce Motion 纪律 (parallel: false)
- [ ] 408.md - 原生符号 / 数字动效接入小件 (parallel: true, depends #407)
- [ ] 409.md - TagGroup / TagInput 动画 (parallel: true, depends #407)
