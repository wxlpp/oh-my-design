---
name: motion-foundations
description: 动效 token + 核心库 Reduce Motion 纪律，并把原生动效 API 接进现有小件（对照 UI TripleD 的 P1）
status: active
created: 2026-09-22T14:40:00Z
---

# motion-foundations

## Executive Summary

对照 UI TripleD（`.claude/epics/motion-foundations/tripled-analysis.md`）得出：本仓最缺的不是新组件，而是动效基础设施。
三个 target 中 `contentTransition` / `symbolEffect` / `scrollTransition` 使用为 0；`Tokens/` 没有任何动画 token，
时长散落在约 12 处字面量；核心库只有少数组件读 Reduce Motion。本 epic 做三件事：建立 `CoreMotion` 动效 token 与
Reduce Motion 纪律（含机器判据）、把原生符号 / 数字动效接进小件、给 TagGroup / TagInput 加增删与选中动画。

## Problem Statement

- 动效参数无单一来源：同类交互（按压、滑块、入场）各写各的时长与曲线，改一处漏一处。
- Reduce Motion 覆盖不全：Toast 滑入、TopBarIndicator、SegmentedControl / UnderlinedTabBar 滑块、按压缩放等未分支（清单以实测为准）。
- 小件的状态变化生硬：anchoredBadge 计数突变；CheckBox / Radio 用两张 `Image` 淡变；TagInput 以 `id: \.offset` 为身份，删除中间项时动画错位。

## User Stories

- 作为设计系统使用者，我希望组件动效节奏一致、改一个 token 全库跟随。
- 作为开启「减弱动态效果」的用户，我希望所有位移 / 缩放类动效降级为淡变或静态，而不是照常播放。
- 作为终端用户，我希望计数变化、勾选、增删标签时有清晰但克制的反馈。

验收：见各 FR；所有动效在 Reduce Motion 下有明确降级且有判据。

## Functional Requirements

**FR-1 先验实测（spike，结论写进 plan 与 docs）**：在 iOS 26 模拟器与 macOS 上实测并记录：
(a) `symbolEffect`（`.bounce` / `.replace`）在 Reduce Motion 开启时是否自动降级；
(b) `.contentTransition(.numericText())` 在 Reduce Motion 下的表现；
(c) Effects 文档所称「`hasMotion: true` 转场在 RM 下被框架替换成 `.opacity`」是否成立。
后续 FR 的降级策略按实测结果定：系统已降级的不重复包一层；未降级的由本库显式分支。

**FR-2 `CoreMotion` token**：`Tokens/CoreMotion.swift`，公开一小组语义化动画（例如 `quick` / `standard` / `emphasized` / `selection`，
以 SwiftUI 原生 `.snappy` / `.smooth` / `.bouncy` 族为基础，时长给出依据），并提供一个把 Reduce Motion 纳入的取值入口
（例如 `CoreMotion.animation(_:reduceMotion:)` 或环境感知 modifier）。命名与形态由实现定，须遵守公约（无 Bool 入参、
MainActor 棘轮不增豁免）。核心库现有写死的动画参数迁到 token（逐处列出，行为差异登记）。

**FR-3 Reduce Motion 纪律 + 判据**：核心库所有位移 / 缩放 / 旋转类动效在 Reduce Motion 下降级（淡变或静态）；
新增一条与 Effects 的 `MicroInteractionReduceMotionGuard` 同族的源码判据，防止新增动效绕过纪律（清单式判据优先，
避免正则追写法）。

**FR-4 原生符号 / 数字动效接入小件**：
- `anchoredBadge` 计数变化用 `.contentTransition(.numericText(value:))`（框架自己判方向，无需镜像显示值、无晚一帧；
  原定 `countsDown:` 经 #408 实测推翻：它要求方向在数字变化的同一次事务里给出，`onChange` 晚一拍），出现 / 消失有 transition；
- CheckBox / Radio 的指示符号切换改为 `.contentTransition(.symbolEffect(.replace))`（必要时加轻量 `.bounce`），
  替代两张 `Image` 淡变；
- 默认 / 静态外观逐像素不变（对照原样拷贝的旧实现），Reduce Motion 行为按 FR-1 结论。

**FR-5 TagGroup / TagInput 动画**：先把 TagInput 的 ForEach 身份从 `\.offset` 改为稳定身份（重复标签的处理写明），
再加增删（insertion / removal transition）与 TagGroup 选中态切换动画；Reduce Motion 下降级。FlowLayout 重排时不跳动（或写明限制）。

## Non-Functional Requirements

沿用上两个 epic 的约定：无 Bool 公开入参；只用第 3/4 层语义色；像素判据对照原样拷贝的旧实现；资源色断言只在编译 catalog 的腿；
变异可打红；macOS + iOS 双腿、预览宿主、downstream-probe、MainActor 棘轮。动画本身难以用静态位图证明，
动效行为用「动画值 / transition 配置的单元判据 + 模拟器录屏或逐帧截图」作证据，并在报告里写明哪些只能人工看。

## Success Criteria

- 核心库内写死的动画参数全部走 `CoreMotion`（判据可查）；Reduce Motion 纪律有机器判据且全绿。
- FR-4 / FR-5 的动效在模拟器录屏中可见，Reduce Motion 开启时按规则降级。
- 三个任务 PR 合入 epic，epic 集成验证全绿。

## Constraints & Assumptions

iOS 26+ / macOS 26+；允许行为层面的变化（登记 BREAKING-CHANGES）；本机同时最多 2 个实现 agent；
xcodebuild 带 `CODE_SIGNING_ALLOWED=NO -IDEPackageEnablePrebuilts=NO`。

## Out of Scope

分析报告的 P2 / P3（CountUpText、TypingIndicator、TypewriterText 增强、FloatButton 展开、SlideToConfirm、
Steps / Timeline 连线动画、Segmented 曲线与 TabBar 触感等）；Effects target 的迁移（只在核心库落地 token）。

## Dependencies

FR-2 / FR-3 依赖 FR-1；FR-4 / FR-5 依赖 FR-2（使用 token）。
