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
  `CoreRadius.xLarge` 自陈「为 Sheet 预留」，在 `Sources/OhMyDesign` 生产代码里零消费。
- **缺陷**：`SearchField` 未把 `\.isEnabled` 透传给 `UISearchTextField` / `NSSearchField`，
  `.disabled()` 应为无效（源码层结论，实现时须先运行期复现）。

## User Stories

**US-1 表单开发者**：我想给任意输入控件标注「必填」与「校验失败 + 原因」，控件与标签自动变成错误态，
VoiceOver 读到错误原因。
- 验收：`FormField` 内放系统 `TextField`（加 `.fieldAccessibilityHint()`）与本仓 `PinCode`，
  设 `.fieldValidation(.invalid(Text("…")))` 后，标签与错误行以 danger 色显示、`PinCode` 描边变 danger，
  两者的真实输入节点都读到错误原因；错误出现时播报一次；设回 `.valid` 错误行淡出。
  `.fieldRequirement(.required)` 显示星号。

**US-2 应用开发者**：我想弹出带说明和「撤销」按钮的 toast，重要的 toast 不自动消失，退出页面时
一次清掉全部。
- 验收：`ToastItem(title:description:level:duration:action:)` 渲染标题、说明与一个动作按钮，
  三种 presentation 与 AX5 大字号下均不截断动作；`.persistent` 不自动消失；手指按住或拖拽期间不计时、
  松手后按剩余时长继续；`ToastHost.dismissAll()` 清空当前与排队项，之后立即 `show` 能正常显示。

**US-3 应用开发者**：我想显示带标题、正文、操作按钮且可关闭的横幅，并能用中性档。
- 验收：`Banner` 支持 title / message / actions / onDismiss；`StatusLevel.neutral` 在 Banner、
  Toast、Timeline、以及所有 `StatusLevel` 消费处都有定义好的外观。

**US-4 设计系统消费者**：我希望 `.controlSize(.small)` 同样作用于 Badge、Tag、Avatar。
- 验收：五档 `ControlSize` 下三件的字号 / 内边距 / 尺寸随档变化，`AvatarGroup` 内的 `Avatar`
  与组的尺寸口径一致；需要任意直径时用 `Avatar(name:size: .fixed(100))`。

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

**能力 → FR 映射**（11 项能力、13 条 FR）：字段校验 = FR-1 + FR-2；SearchField 修复 = FR-3；
Banner = FR-4 + FR-5；Toast = FR-6；尺寸 = FR-7；锚定徽标 = FR-8；TagGroup = FR-9；进度环 = FR-10；
按压反馈 = FR-11；surface 嵌套 = FR-12；sheet 预设 = FR-13。

**FR-1 字段校验基础层**：新增 `public enum FieldValidation: Equatable { case valid; case invalid(Text) }`
与 `public enum FieldRequirement { case optional, required }`，经 `@Entry` 环境值下发，公开
`View.fieldValidation(_:)` / `View.fieldRequirement(_:)`；嵌套时按 SwiftUI 惯例最近一层生效，
推荐施加在 `FormField` 上。新增 `FormField` 容器：label（必填星号取 `statusDangerForeground`）、
可选 description、错误行（来自 `fieldValidation`，`.transition(.opacity)`）。无障碍契约：
- label 与控件用 `accessibilityLabeledPair` 关联；必填以「必填」追加到 label 的可访问文本。
- description 与错误原因**不由容器挂 hint**——容器不知道真实输入节点；容器经环境值把 description
  文本传下去，由「真实输入节点」自己挂：FR-2 的 5 个自有控件在内部挂；系统控件（`TextField` 等）由调用方
  在控件上加公开 modifier `View.fieldAccessibilityHint()`（读同一组环境值，自有控件内部也走它）。
  系统控件的 danger 描边**不自动出现**——错误态由 `FormField` 的 label 与错误行表达。
- 播报：仅在 `valid → invalid` 转变、或 invalid 的错误文本变化时播报一次；首次渲染即 invalid、
  视图重建（值未变）不播报。
- 视觉优先级：disabled > invalid > focused。

**FR-2 控件接入校验态 + FR-3 `SearchField` 修复（同一个 issue，两者同改 SearchField）**：
`PinCode`、`TagInput`、`SearchField`、`CheckBoxToggleStyle`、`RadioGroup` 读取 `fieldValidation`，
invalid 时描边 / 图标取 danger 语义 token，并把错误原因与 description 挂到各自的真实输入节点
（`PinCode` 为逐格节点，`TagInput` 为输入框而非删除按钮）。FR-3：`updateUIView` / `updateNSView`
透传 `isEnabled`（先运行期复现）；iOS `returnKeyType = .search`。

**FR-4 `StatusLevel.neutral`（原子）**：新增 case，**同一个改动内**完成全部 exhaustive switch 消费处
（至少 `Banner`、`Toast`、`Timeline`，含 `Timeline` 的无障碍文案）的外观定义；中性取 content / fill
语义 token，不取资源色。下游 exhaustive switch 的源码破坏登记进 BREAKING-CHANGES。

**FR-5 Banner 补齐**（依赖 FR-4）：`BannerStyleConfiguration` 增 `title: Text?`、`actions: AnyView?`、
`dismiss: (() -> Void)?`；现有泛型 `label` 保留为正文槽（configuration.label 语义不变），新增
`Banner(level:title:message:actions:onDismiss:)` 便利 init；`Plain` / `Bordered` 两个 style 渲染新槽。
Banner 无状态：`onDismiss` 只回调，由调用方移除。动作与关闭按钮是独立的可聚焦、可激活节点，
新增槽后 Banner 不再把全部子元素合并为单一元素。自定义 `BannerStyle` 的迁移写进 BREAKING-CHANGES。

**FR-6 Toast 补齐**（依赖 FR-4；按状态机改造估算）：
- API：`ToastItem.message` 改名 `title`，增 `description: String?` 与 `action: ToastAction?`；
  便利入口改为 `show(_ title:description:level:duration:)`；`ToastDefaults.duration` 改为 `ToastDuration`；
  `duration` 为 `public enum ToastDuration: Sendable { case seconds(TimeInterval); case persistent }`，
  `seconds` 非正值按 `ToastDefaults` 的缺省时长处理。新旧签名映射写进 BREAKING-CHANGES。
- 并发：`ToastItem` 保持 `nonisolated` + `Sendable`；`ToastAction` 为 `Sendable`，持有
  `@MainActor @Sendable () -> Void`，在主 actor 执行；验收「后台构造、主线程展示与执行」。
- 交互：点动作 = 执行动作后关闭；整条点击关闭保留；有动作时整条不再是单一按钮元素，动作与关闭可独立聚焦。
- 状态机：按住或拖拽都暂停计时，松手按剩余时长恢复，手势取消同样恢复；`.persistent` 在被关闭前阻塞队列
  （文档写明）；`dismissAll()` 清空当前与排队项，退场动画中调用也成立，清空后立即 `show` 正常显示。
  显示计时与退场等待不得再共用同一任务字段而互相覆盖。

**FR-7 尺寸体系**：`Badge` / `Tag` 读 `\.controlSize`，字号 / 内边距 / 图标尺寸取 `CoreControlMetrics`
（不够时在该文件补查询函数）；`Tag` 关闭钮随档。`Avatar`：在 `CoreControlMetrics` 新增五档头像直径表，
`Avatar(name:size:)` 的 `size: AvatarSize` 缺省 `.automatic`（取 controlSize 档）、另有 `.fixed(CGFloat)`；
`AvatarGroup` 与之共享同一张表、不改写传入子视图（子视图经环境 controlSize 自然对齐）。
今天 `Avatar` 可被外部 `.frame` 任意拉伸，改为默认固定直径属于布局破坏，登记并给出 `.fixed` 迁移（如 100pt 用法）。

**FR-8 `anchoredBadge`**：`View.anchoredBadge(_ content: AnchoredBadgeContent, placement: …)`，
content 至少含 `.dot` / `.count(Int, max: Int)` / `.text(String)`；取色 `statusDangerEmphasis`
+ `contentOnEmphasis`（与系统角标一致，不跟随 accent）；count 为 0 时不显示；计数并入宿主可访问值。
名字避开 SwiftUI `.badge`。

**FR-9 `TagGroup`**（依赖 FR-7）：基于 `Tag` + `FlowLayout`；`selectionMode` 枚举（none / single / multiple）；
`Binding<Set<ID>>` 选择；禁用集合。不变量：
- 基数约束只计**当前数据里存在的 ID**；不在数据里的未知 ID 原样保留、永不被组件增删。
- single 模式点已选项 = 取消（允许空选）；点未选项 = 把「数据内已选集合」替换为该项（未知 ID 不动）；
  外部写入多个数据内 ID 时照样渲染，下一次用户点选才归一。
- 切换 `selectionMode` 不改写绑定；禁用项不可切换但可显示为已选；
- 本轮不支持在 TagGroup 内删除（避免嵌套按钮）；每个标签是带 `.isSelected` trait 的按钮，键盘可聚焦。
- 选中色：底色与描边**从环境 `coreAccent` 派生**（不用静态 `accentSubtleBackground` / `borderSelected`），
  标签内容色仍由调用方决定；验收含自定义 `coreAccent`。

**FR-10 `.coreCircular`**：公开 `ProgressViewStyle`，确定态圆弧取 `.tint`（`TintShapeStyle`），
不确定态回退系统样式；遵守 `.core` 强调色走 `.tint` 通路的规则。

**FR-11 按压反馈样式**：两个公开 `ButtonStyle`（行 / 卡片），入口形如 `.pressableRow` / `.pressableCard`。
它们**只装饰调用方的 label**：不接 role 色板、不按 controlSize 改布局——这是对《按钮样式模式》的
有意例外，写进 `docs/components/`。尊重 `\.isEnabled`；reduce motion 下卡片不缩放只变暗。

**FR-12 surface 嵌套 + FR-13 sheet 预设（同一个 issue）**：
- `.surface(_:)` 写入 `@Entry` 当前有效层级（base / raised / elevated），逐角色：
  · `canvas` / `canvasSubtle`：层级重置为 base，背景保持各自现值；
  · `content` / `grouped` / `card`：层级 = 父层级 + 1（封顶 elevated），**只有这三者的背景随层级变**
    （raised → `surfaceCard` 现值，elevated → `surfaceElevated`）；
  · `panel` / `sidebar` / `control` / `floating`：不改层级，背景保持各自现值（`surfacePanel` /
    `surfaceSidebar` / `surfaceInteractive` / `surfaceOverlay`）。
  描边与圆角仍由角色决定（grouped 仍无描边）。`Card` 保持 `.surface` 薄封装，不另写逻辑。
  `SurfaceKindAlphaContractGuard` 等按 kind 取色的判据随之按「角色 × 层级」更新，不得放宽。
- macOS 系统色在 raised / elevated 塌缩（既有文档裁决），有描边的角色靠描边区分；grouped 嵌套 grouped
  在 macOS 无视觉区分，登记为已知限制。
- `coreSheetPresentation()` 打包 `presentationCornerRadius(CoreRadius.xLarge)`、
  `presentationDragIndicator(.visible)`、`presentationBackground(Color.surfaceRaised)`，
  并把 sheet 内容的有效层级设为 raised。

## Non-Functional Requirements

- **NFR-1 公约**：遵守 `docs/component-contract.md`——公开入参禁 Bool（用枚举 / 可选闭包 / 环境值）。
  登记按公约分类落点，**不是**「所有新公开符号都进登记表」：组件（`FormField`、`TagGroup`）进
  `components[]` 并附判定记录；style 实现（`.coreCircular`、按压样式）与辅助类型、主 target 的扩展入口
  按公约与现有守卫各自的规则处理，不得为满足登记而扩大扫描器范围或造幽灵条目。新增文本参数逐个按公约
  第 4 节定 A / B / C 类与类型。
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

- 11 项能力 / 13 条 FR 全部落地，对应 issue 全部关闭，epic 合入 main。
- 行为验收（主判据）：Badge / Tag / Avatar 在五档 `ControlSize` 下渲染尺寸单调变化（测试断言尺寸，
  不是 grep）；TagGroup 选中色随自定义 `coreAccent` 变化；FormField + 5 个控件的 invalid 态在
  iOS 腿可见且播报次数符合 FR-1；Toast 状态机各场景（暂停 / 恢复 / persistent / dismissAll 后 show）有测试。
- 辅助检查：`Color.pressedBackground` 与 `CoreRadius.xLarge` 在 **`Sources/OhMyDesign` 生产代码**
  各至少 1 处消费（今天均为 0；`xLarge` 仅在 Effects target 预览里出现）。
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
- issue 间依赖（逻辑依赖 + 共享文件）：FR-2/FR-3 依赖 FR-1；FR-4 原子完成全部 `StatusLevel` 消费者后，
  FR-5 与 FR-6 才开始（二者都改 Toast / Banner 相邻代码，按文件归属可并行）；FR-9 依赖 FR-7；
  FR-12 与 FR-13 同 issue。其余（FR-1、FR-4、FR-7、FR-8、FR-10、FR-11、FR-12/13）可并行。
- 外部评审：Copilot 本月不可用（至 2026-10-01），外部视角改用本机 `codex` CLI。
