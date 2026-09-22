---
name: ui-followups
status: in-progress
created: 2026-09-22T10:50:10Z
updated: 2026-09-22T13:32:31Z
progress: 100%
prd: .claude/prds/ui-followups.md
github: https://github.com/wxlpp/oh-my-design/issues/397
---

# Epic: ui-followups

处理 #384。三组文件互不重叠，可并行（本机上限 2 个 agent）：

| task | FR | 文件 |
|---|---|---|
| 001 状态视觉 | A1–A3 | Banner、Timeline、Colors |
| 002 浮层与层级 | B1–B4 | Toast、FloatingGlassModifier、SurfaceModifier |
| 003 输入控件 | C1–C6 | PinCode、TagInput、Radio、CheckBox、SearchField |

共享文件（BREAKING-CHANGES、digest、App 预览）冲突按两边保留 + 实际值重算处理。

## Tasks Created
- [ ] 398.md - 状态视觉 (parallel: true)
- [ ] 399.md - 浮层与层级 (parallel: true)
- [ ] 400.md - 输入控件 (parallel: true)
