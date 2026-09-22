---
name: heroui-absorption
description: 对照 HeroUI v3 吸收 P1 + P2 共 11 项组件能力，保留 HIG 原生观感、墨色 accent 与「换皮不重造」
status: backlog
created: 2026-09-22T01:14:14Z
---

# heroui-absorption

## Executive Summary

以 HeroUI v3（React / React Native）组件库为参照，给 OhMyDesign 补齐 11 项能力：字段校验态与
`FormField` 容器、Toast 与 Banner 的内容结构、小件尺寸体系、锚定徽标、可选标签组、确定进度环、
按压反馈样式、surface 嵌套感知、sheet 预设，以及 `SearchField` 的禁用透传缺陷。前提不变：
Apple HIG 原生观感、墨色 accent、SwiftUI 有原生控件的只换皮不重造。对照依据见
`.claude/epics/heroui-absorption/heroui-analysis.md`（P1 / P2 各项的源码取证与 HeroUI 出处）。
允许破坏性变更（仍在 0.x），全部登记进 `docs/BREAKING-CHANGES.md`。

## Problem Statement

对照 HeroUI 暴露出本仓几块结构性缺口：

- **没有字段级校验态**：`Sources/OhMyDesign` 无任何 invalid / required 语义，`PinCode` /
  `TagInput` / `SearchField` / `CheckBoxToggleStyle` / `RadioGroup` 都无法表达「输入有误」，
  调用方只能 `.tint(.red)` 假装；`Form` 之外也没有「标签 + 说明 + 错误」的字段容器。
- **反馈组件内容结构太薄**：`ToastItem` 只有单行 `message`（`lineLimit(1)`），无说明、无动作、
  无常驻、计时不可暂停；`Banner` 只有 `level` + 单个 `label` 槽，无标题、无动作、不可关闭；
  共用的 `StatusLevel` 没有中性档，中性提示只能借 `.info`。
- **小件不跟随尺寸**：`Badge` / `Tag` / `Avatar` 源码零处读 `\.controlSize`，而
  `CoreControlMetrics` 五档表已现成，`AvatarGroup` 已按 `controlSize` 算尺寸，两边口径不一。
- **常见形态缺件**：贴在头像 / 图标角上的红点与计数（SwiftUI `.badge()` 只对 `List` 行与
  `TabView` 生效）；可选中的标签组（filter chips）；确定进度圆环（`.core` 只画线性）。
- **交互反馈与层级缺位**：`Color.pressedBackground` 已定义但零消费，`SettingsRow` / `ListRow` /
  `Card` 包进 `Button` 只得到系统整块变淡；`.surface(_:)` 不写环境，`Card` 套 `Card` 两层同色；
  `CoreRadius.xLarge` 自陈「为 Sheet 预留」却零消费。
- **缺陷**：`SearchField` 未把 `\.isEnabled` 透传给 `UISearchTextField` / `NSSearchField`，
  `.disabled()` 应为无效（源码层结论，实现时须先运行期复现）。

## User Stories

**US-1 表单开发者**：我想给任意输入控件标注「必填」与「校验失败 + 原因」，控件与标签自动变成错误态，
VoiceOver 读到错误原因。
- 验收：`FormField` 内放系统 `TextField` 与本仓 `PinCode`，设 `.fieldValidation(.invalid(Text("…")))`
  后，标签与错误行以 danger 色显示、`PinCode` 描边变 danger；错误出现时播报一次；设回 `.valid`
  错误行淡出。`.fieldRequirement(.required)` 显示星号。

**US-2 应用开发者**：我想弹出带说明和「撤销」按钮的 toast，重要的 toast 不自动消失，退出页面时
一次清掉全部。
- 验收：`ToastItem(title:description:level:duration:action:)` 渲染两行文本与一个动作按钮；
  `.persistent` 不自动消失；手指按住期间不计时；`ToastHost.dismissAll()` 清空队列。

**US-3 应用开发者**：我想显示带标题、正文、操作按钮且可关闭的横幅，并能用中性档。
- 验收：`Banner` 支持 title / message / actions / onDismiss；`StatusLevel.neutral` 在 Banner、
  Toast、Timeline、以及所有 `StatusLevel` 消费处都有定义好的外观。

**US-4 设计系统消费者**：我希望 `.controlSize(.small)` 同样作用于 Badge、Tag、Avatar。
- 验收：五档 `ControlSize` 下三件的字号 / 内边距 / 尺寸随档变化，`AvatarGroup` 内的 `Avatar`
  与组的尺寸口径一致。

**US-5 应用开发者**：我想在头像或图标右上角挂未读红点或计数。
- 验收：`.anchoredBadge(.count(120, max: 99))` 显示 `99+`，`.dot` 显示红点，位置由枚举决定，
  a11y 把计数并入宿主的描述。

**US-6 应用开发者**：我想做一组可单选 / 多选的筛选标签。
- 验收：`TagGroup` 绑定 `Set<ID>`，按 `selectionMode` 单选 / 多选 / 不可选，支持禁用项；
  选中态为 accent 淡底 + 选中描边，VoiceOver 报「已选中」。

**US-7 应用开发者**：我想用系统 `ProgressView(value:)` 显示确定进度圆环。
- 验收：`.progressViewStyle(.coreCircular)` 画圆弧、颜色随 `.tint`，`value == nil` 时回退系统 spinner。

**US-8 应用开发者**：我想让自绘行和卡片在按下时有 iOS 原生式反馈。
- 验收：两个公开 `ButtonStyle`——行样式按下铺 `pressedBackground` 高亮、卡片样式按下按
  `CoreButtonMetrics.pressedScale` 缩放；禁用时不响应。

**US-9 应用开发者**：我想在卡片里再放卡片时自动分出层级，并一行代码得到符合本库风格的 sheet。
- 验收：`.surface(.content)` 内的 `Card` 自动取 `surfaceElevated`；`coreSheetPresentation()`
  设置圆角 `CoreRadius.xLarge`、拖拽指示条与 raised 背景。

**US-10 应用开发者**：`SearchField().disabled(true)` 应当不可输入且外观变灰。
- 验收：运行期复现缺陷后修复；回车键显示为「搜索」。

## Functional Requirements

**FR-1 字段校验基础层**：新增 `public enum FieldValidation: Equatable { case valid; case invalid(Text) }`
与 `public enum FieldRequirement { case optional, required }`，经 `@Entry` 环境值下发，公开
`View.fieldValidation(_:)` / `View.fieldRequirement(_:)`。新增 `FormField` 容器：label（必填星号
取 `statusDangerForeground`）、可选 description、错误行（来自 `fieldValidation`，`.transition(.opacity)`），
错误出现时 `AccessibilityNotification.Announcement`，description 挂为控件 `accessibilityHint`。

**FR-2 控件接入校验态**：`PinCode`、`TagInput`、`SearchField`、`CheckBoxToggleStyle`、`RadioGroup`
读取 `fieldValidation`，invalid 时描边 / 图标取 danger 语义 token。

**FR-3 `SearchField` 修复**：`updateUIView` / `updateNSView` 透传 `isEnabled`；iOS `returnKeyType = .search`。

**FR-4 `StatusLevel.neutral`**：新增 case，并为所有 exhaustive switch 消费处定义外观（中性取
`content` / `fill` 语义 token，不取资源色）。

**FR-5 Banner 补齐**：`BannerStyleConfiguration` 增 `title`、`actions`、`dismiss`（可选）；`Banner`
新增对应 init；`PlainBannerStyle` / `BorderedBannerStyle` 渲染新槽；关闭用可选闭包而非 Bool。

**FR-6 Toast 补齐**：`ToastItem` 增 `description` 与 `ToastAction`（label + 闭包）；
`duration` 改为 `public enum ToastDuration { case seconds(TimeInterval); case persistent }`；
`ToastHost.dismissAll()`；拖拽中暂停计时；队列仍一次一条。

**FR-7 尺寸体系**：`Badge` / `Tag` / `Avatar` 读 `\.controlSize`，字号 / 内边距 / 图标尺寸取
`CoreControlMetrics`；`Tag` 关闭钮尺寸随档；`Avatar` 尺寸与 `AvatarGroup` 同源。

**FR-8 `anchoredBadge`**：`View.anchoredBadge(_ content: AnchoredBadgeContent, placement: …)`，
content 至少含 `.dot` / `.count(Int, max: Int)` / `.text(String)`；取色 `statusDangerEmphasis`
+ `contentOnEmphasis`；count 为 0 时不显示。名字避开 SwiftUI `.badge`。

**FR-9 `TagGroup`**：基于 `Tag` + `FlowLayout`；`selectionMode` 为枚举（none / single / multiple）；
`Binding<Set<ID>>` 选择；禁用集合；选中态 `accentSubtleBackground` + `borderSelected`。

**FR-10 `.coreCircular`**：公开 `ProgressViewStyle`，确定态圆弧取 `.tint`（`TintShapeStyle`），
不确定态回退系统样式；遵守 `.core` 强调色走 `.tint` 通路的规则。

**FR-11 按压反馈样式**：两个公开 `ButtonStyle`（行 / 卡片），尊重 `\.isEnabled`，reduce motion 下
卡片不缩放只变暗。

**FR-12 surface 嵌套**：`.surface(_:)` 写入 `@Entry` 当前层级；`Card` 在 content 层内自动升一档到
`surfaceElevated`；macOS 保持描边区分（系统色在 macOS 塌缩，已有文档裁决）。

**FR-13 `coreSheetPresentation()`**：打包 `presentationCornerRadius(CoreRadius.xLarge)`、
`presentationDragIndicator(.visible)`、`presentationBackground(Color.surfaceRaised)`。

## Non-Functional Requirements

- **NFR-1 公约**：遵守 `docs/component-contract.md`——公开入参禁 Bool（用枚举 / 可选闭包 / 环境值），
  新公开符号登记 `docs/component-registry.json`，文本参数按 A/B 类登记。
- **NFR-2 并发**：Swift 6 严格并发；新增公开 `static` 成员跑 `scripts/mainactor-static-ratchet.sh`，
  需要 `nonisolated` 的给出，不新增豁免。
- **NFR-3 色彩**：只用第 3、4 层语义 token；不引入彩色 variant 矩阵；不给静置控件加玻璃。
- **NFR-4 无障碍**：新组件与新状态有 VoiceOver 标签 / 值 / trait；触控目标 ≥ 44pt 的既有判据继续成立。
- **NFR-5 双平台**：iOS 26 / macOS 26 都能编译；平台差异用既有 `#if canImport` 形态。
- **NFR-6 验证**：macOS `swift test` + iOS Simulator xcresult 双腿；预览宿主构建；
  `scripts/downstream-probe` 构建；UI 类改动在模拟器截图交视觉评审。
- **NFR-7 文档**：每项更新 / 新建 `docs/components/*.md`，破坏性变更进 `docs/BREAKING-CHANGES.md`，
  预览宿主画廊加入新组件 / 新状态。

## Success Criteria

- 11 项 FR 全部落地，对应 issue 全部关闭，epic 合入 main。
- `git grep -n "\\.controlSize" Sources/OhMyDesign/Components/{Badge,Tag,Avatar}` 每个文件 ≥ 1 处命中（今天为 0）。
- `Color.pressedBackground`、`CoreRadius.xLarge` 各至少 1 处非定义消费（今天为 0）。
- `Sources/OhMyDesign` 出现 `FieldValidation` 且被 5 个既有控件消费。
- 两条 CI 腿（SwiftPM、iOS Simulator）与 downstream-probe、Bool 棘轮全绿；MainActor 棘轮豁免数不增。
- 每个新组件 / 新状态在预览宿主可见，并通过一次视觉评审（无 Blocker）。

## Constraints & Assumptions

- iOS 26+ / macOS 26+，不加可用性回退。
- 允许破坏性变更（0.x），登记即可；下一个 minor 发布。
- 系统控件不重造：`TextField` / `Toggle` / `Menu` / `Picker` / sheet 本体继续用原生。
- 假设 `CoreControlMetrics` 现有五档表足以覆盖 Badge / Tag 的尺寸需求；不够时在该文件补查询函数，
  不在组件里硬编码。
- `SearchField` 的禁用缺陷是源码层推断，实现前须运行期复现；复现不出则改为登记，不硬改。

## Out of Scope

- 分析报告的 P3 各项（Skeleton pulse、Separator axis、Tab 逐项禁用 / 图标、KeyCap、InlineCode、
  scrollShadow、Gauge `.core`、RangeSlider）。
- 报告附录的文档漂移（`tag.md` 圆角、旧 token 名、`button.md` glass 句）。
- 替换 `docs/component-contract.md` 里以 Sidebar 组件为正典例的条目。
- HeroUI 的彩色 variant 矩阵、默认玻璃底、Toast 堆叠、hover / focus-visible 等 Web 交互。
- Select / Menu / Popover / Dialog / Switch / Slider / DatePicker / Table 等有原生对应的组件本体。

## Dependencies

- 对照依据：`.claude/epics/heroui-absorption/heroui-analysis.md`。
- 既有基础：`Tokens/CoreControlMetrics.swift`、`Layout/FlowLayout.swift`、`Modifier/SurfaceModifier.swift`、
  `Colors/InteractionColors.swift`、`Components/StatusLevel.swift`、`Components/Style/CoreProgressViewStyle.swift`。
- issue 间依赖：FR-2 依赖 FR-1；FR-6 依赖 FR-4；FR-9 依赖 FR-7；其余可并行。
- 外部评审：Copilot 本月不可用（至 2026-10-01），外部视角改用本机 `codex` CLI。
