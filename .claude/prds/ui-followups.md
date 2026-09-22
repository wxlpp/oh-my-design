---
name: ui-followups
description: 处理 #384 登记的 heroui-absorption 评审跟进项（状态视觉、浮层与层级、输入控件）
status: active
created: 2026-09-22T10:50:10Z
---

# ui-followups

## Executive Summary

收口 #384 里 heroui-absorption 评审登记的 9 组视觉 / 既有问题（约 14 个修复点），不新增组件。
用户已拍板两处默认外观变更：Banner 容器改圆角；danger 图标统一为圆形。

## Problem Statement

评审（视觉 + codex）指出但超出各自 Issue 范围的问题，详见 #384 正文与评论 1–9。

## User Stories

- 作为设计系统使用者，我希望各状态档的视觉重量一致、图标成组、在任何底色上都成立。
- 作为使用辅助功能的用户，我希望大字号下文字不被从单词中间折断、禁用控件能看出禁用。

验收：每个修复点有像素 / 布局 / AXe 证据（见 FR），valid / 默认外观的非目标区域与改动前一致。

## Functional Requirements

**A 状态视觉（Banner / Timeline / Colors）**
- FR-A1 neutral Banner 底色改为不透明：第 2 层桥接 `systemGray5`（iOS `UIColor.systemGray5` / macOS 等价），第 3 层新增 `statusNeutralSubtle`；不再用半透明 `tertiaryFill`。
- FR-A2 Banner 容器改圆角 `CoreRadius.medium`（Plain 与 Bordered 都是），描边随形状；视觉破坏登记 BREAKING-CHANGES。
- FR-A3 浅色 Timeline warning 圆点对比度 ≥ 3:1（非文本对比度），做法由实现定（加深取色或加描边），暗色不回退。

**B 浮层与层级（Toast / FloatingGlass / Surface）**
- FR-B1 Toast danger 图标改为 `exclamationmark.circle`（与 Banner 的 `.circle.fill` 成组）。
- FR-B2 AX 字号下胶囊形态的长单词不再从中间折行：AX 字号下图标缩小 / 挪入标题行，让文字列拿到足够宽度（以 AX5 截图证明）。
- FR-B3 `floatingGlass`：全宽横幅形态不画四周 hairline 且顶部延伸进状态栏；HUD 形态不透出底层文字（提高不透明度或换材质），胶囊形态观感不回退。
- FR-B4 elevated 层的 `.content` 与 `.grouped` 区分：elevated 层 `.content` 描边改 `.clear`（与 grouped 合流），raised 层不变。

**C 输入控件（PinCode / TagInput / Radio / CheckBox / SearchField）**
- FR-C1 TagInput invalid 下划线覆盖整个字段宽度（含 chips 行）。
- FR-C2 Radio invalid 时只有圆环变红，选中实心点保持正常色。
- FR-C3 PinCode 获焦 + invalid 的格子与其他 invalid 格可区分（截图证明）。
- FR-C4 PinCode 隐藏 TextField 不再在浅色下留下数字残影（结构不变、键盘与粘贴行为不变）。
- FR-C5 CheckBox / Radio 在 `.disabled()` 下整体变淡（与系统控件一致），不改 enabled 外观。
- FR-C6 SearchField 在不限高容器中不被纵向拉伸（固有高度），调用方不再需要 `fixedSize`。

## Non-Functional Requirements

沿用 heroui-absorption 约定：无 Bool 公开入参；只用第 3/4 层语义色；像素判据用 `expectBitmapsEqual` / 有界 `expectBitmapsEquivalent`；资源色断言只在编译 catalog 的腿；变异可打红；macOS + iOS 双腿、预览宿主、downstream-probe、MainActor 棘轮。

## Success Criteria

#384 列出的 9 组全部处理并在 #384 逐条回复落点；三个任务 PR 合入 epic 后 epic 全量验证全绿。

## Constraints & Assumptions

允许视觉破坏（登记即可）。本机同时最多 2 个实现 agent；xcodebuild 带 `CODE_SIGNING_ALLOWED=NO -IDEPackageEnablePrebuilts=NO`。

## Out of Scope

#391（托管 sheet 测试互扰）；新组件；#384 以外的问题。

## Dependencies

#384；已合入的 heroui-absorption（main `752ce2f`）。
