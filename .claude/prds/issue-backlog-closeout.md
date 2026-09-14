---
name: issue-backlog-closeout
description: 收口库内 5 条遗留 issue（#240/#357/#337/#317/#312），全部为已定规格的缺陷 / 承接任务
status: active
created: 2026-09-14T00:33:25Z
---

# issue-backlog-closeout

## Executive Summary

把 OhMyDesign 仓库 5 条 open issue 逐条落地并关闭：`#240`（BREAKING-CHANGES 三缺口收尾）、
`#357`（coreAccent 饱和色深色反色，API 已裁决）、`#337`（散文裸行号引用无机器兜底，
普查已做完 160 条 / 129 失真）、`#317`（macOS 位图逐字节判据偶发差 1 LSB）、
`#312`（4 个组件的形态 D 扩展点 + OrbitingLogos 落点裁定）。
shaders epic 尾部（`#282` / `#284` / `#243`）是**另一个 epic**（`shipswift-shaders`），不在本 epic 内。

## Problem Statement

仓库 open issue 分两类：一类是**已登记未修的已知缺陷**（`#357` 注册于 `#356` spec R-5、
`#337` 与 `#317` 是评审 / 实测抓到的偶发缺陷，`#240` 是发布记录失真），
一类是**有承接义务的交付任务**（`#312` 是 J-2 红名单的承接点，红名单里每条
`notes` 都写着它的号码，关不掉就永远欠着）。
全部 5 条都有现成规格（issue 正文 + 评论里的普查 / 裁决），无需新需求澄清；
除 `#357` 外不涉及新的产品决定。

## User Stories

1. 作为库下游，我读 `docs/BREAKING-CHANGES.md` 时能拿到**与 git tag 一致**的发布记录。
   验收：tag 清单与 `git for-each-ref` 逐条一致（含日期）；v0.9.0 / v0.10.0 章节存在；
   「未发布」章节已归版。（`#240`）
2. 作为库下游，我给宿主传**饱和色**强调色时，按钮前景在明暗两档都保持可读。
   验收：`.coreAccent(.blue)` 下 `solid(.primary)` 前景 / 背景对比在 light 与 dark 均达标，
   有一条测试判据钉住。（`#357`）
3. 作为维护者，我在散文里引用源码时，被引文字被删 / 漂移后**判据会红**，而不是
   等到下一个读者发现「证据没了、结论还在生效」。（`#337`）
4. 作为 CI 使用者，macOS 全量 `swift test` 不再有「位图逐字节相等」的偶发红。
   验收：判定形态改为对离屏渲染舍入不敏感的等价性质，且提高取样量证明红率收敛。（`#317`）
5. 作为组件消费者，`RadarChart` / `RingChart` / `ActivityHeatmap` / `BeforeAfterSlider`
   有**可演进的**样式扩展点（形态 D），`OrbitingLogos` 的落点已裁定并留痕。
   验收：J-2 红名单收缩为空集、`extensionPointFollowUpIssue` 与聚合断言删除；
   登记表 `notes` 与 `docs/components/*.md` 同步。（`#312`）

## Functional Requirements

- FR-1（`#357`）：`View.coreAccent(_:on:)` 新增可选 `on` 参数（用户裁决：派生缺省 + 可覆盖）；
  缺省时按 accent 亮度自动选黑 / 白（墨色行为与现状逐字节一致）；
  显式传 `on` 覆盖自动选择。消费点：`ButtonRoleStyleRole.onColor`（五 role）与
  `InkSegmentedControlStyle` 选中段文字，改为读环境解析后的 on-accent。
- FR-2（`#337`）：按形态 2（引文逐字核）装守卫——散文引用源码必须带被引原文，
  判据核原文仍在该文件中（复用 `#316` `factSites` 形态）；129 条已失真引用逐条修复
  （77 纯漂移 / 26 整段被删 / 25 重构顶掉 / 1 抄错），13 条跨仓引用如实登记；
  `contract-defects.md:1436` 被推翻的 J-2 描述（现 4 分支含 `styleSlot` / `styleEnum`）一并修正。
- FR-3（`#317`）：查明 `expectBitmapsEqual` 离屏渲染在 macOS 上是否保证逐字节确定；
  若不保证，判据形态改为容差 / 感知比较 / 换钉等价性质，而非把偶发红当噪声重跑。
- FR-4（`#312`）：4 条组件各落地一处**形态 D** 扩展点（槽 / 枚举，禁形态 B public 协议——
  `D-299-1` 排序约束仍有效）；`OrbitingLogos` 落点裁定并留痕（台账 + `docs/contract-defects.md`）；
  `knownMissingExtensionPoints` 收缩为空集并删除 `extensionPointFollowUpIssue` + 聚合断言。
- FR-5（`#240`）：tag 清单日期与 `git for-each-ref` 对齐（v0.7.0 07-26 → 07-27），
  三条缺口核验留证后关闭。

## Non-Functional Requirements

- 所有改动遵循本仓验证纪律：`swift test`（macOS native）+ `xcodebuild -scheme
  OhMyDesign-Package`（iOS Simulator）两条腿；触及公开 API 的同步
  `scripts/downstream-probe` 与 `scripts/mainactor-static-ratchet.sh`；预览宿主
  `App/` 手动构建。
- 判据的变异实证必须**换族攻击**（不是照着判据形状构造变异）。
- `#312` 的扩展点不得发布形态 B public 协议（不可逆风险，issue 排序约束）。
- 新增公开成员检查 MainActor 隔离棘轮与 Bool 纪律（如适用）。

## Success Criteria

1. 5 条 issue 全部关闭，关闭评论附核验证据（命令输出 / 判据名）。
2. `swift test` 与 iOS Simulator 腿全绿；新增判据有换族变异实证。
3. J-2 红名单空集化后 `ComponentExtensionPointGuard` 及其聚合断言随行删除，不留孤儿。

## Constraints & Assumptions

- `#357` 已裁决（派生缺省 + `on` 参数可覆盖），不重新裁决。
- `#312` 的 `OrbitingLogos` 来源今天（2026-09-14）已实测 HTTP 200 并留档正文
  （`docs/issues/` 先例：`234-a11y-smoke.md`）；裁定依据以留档为准，不再依赖在线页面。
- `#337` 的普查口径沿用评论里的约定：只查活文档（`docs/` + 仓根 `*.md`），
  `.claude/` 下历史档不查；跨仓引用（13 条）如实登记，不追进他仓。
- 任务级 spec / plan 由内环产出（`.claude/epics/issue-backlog-closeout/<N>-spec.md` /
  `<N>-plan.md`），本 PRD 不重复。
- epic 分支 `epic/issue-backlog-closeout` off main；每个 Issue 私有 worktree；
  PR base = epic 分支；**禁内环直接合 main**。

## Out of Scope

- `#282` / `#284` / `#243`（shaders epic 尾部）——另一个 epic，另行处理。
- `待追溯` shader 的重开（`#243` 已写明：追到兼容许可才另开 task）。
- `#240` 评论里登记的「0.8.0 节『两次先例』 vs 0.3.0 节自述」冲突——已登记未收，不在本 epic 射程。
- `#337` 的 13 条跨仓引用（`wxlpp/oh-my-story`）——只登记，不修改他仓。

## Dependencies

- 内环依赖（逐条见 task 文件）：`#312` 与 `#337` 同触 `docs/contract-defects.md` /
  `docs/component-registry.json` ⇒ `conflicts_with`，顺序执行（`#337` 先行）。
- 外部：无。真机（iPhone 26.6.1）已可用，`#312` / `#317` 如需实机证据可用。
