# HeroUI v3 对照 OhMyDesign：可吸收点分析

日期：2026-09-22。只读分析，不改仓库。

## 0. 取证边界

- **HeroUI 侧**：各组件页 `https://heroui.com/en/docs/{native,react}/components/<slug>` 经抓取工具全部返回 404（curl 直接访问是 200 的 HTML，但内容为 RSC 流、不可读），改抓官方提供的 `https://heroui.com/native/llms-full.txt`（43,653 行）与 `https://heroui.com/react/llms-full.txt`（168,018 行），每个组件的 Anatomy / API Reference 表都在里面，与组件页同源（每节头部标了 `**Source**: raw.githubusercontent.com/heroui-inc/heroui/.../<slug>.mdx`）。下文引用的 HeroUI prop 名全部逐字取自这两份文件。
- **本仓侧**：逐个读了 `Sources/OhMyDesign/` 下所有组件源文件、`Sources/OhMyDesign/{Colors,Tokens,Modifier,Environment}/`、`docs/components/*.md` 的 API 表、`docs/DESIGN-FOUNDATION.md`、`docs/component-contract.md` §1–§3。`Sidebar` / `BottomInputBar`（含 `CoreMenuButton`）按指示当作不存在。
- 下文对本仓现状的每条断言都附源文件路径；对 HeroUI 的断言附 llms-full 节名。没读到的标「未核实」。

## 1. 结论摘要

按「保留 Apple HIG 原生观感 + 墨色 accent + 换皮不重造」的前提筛过。工作量 S ≈ 半天内、M ≈ 1–3 天、L ≈ 一周级。

### P1

1. **表单字段组合（FormField：label / description / error + `fieldValidation` 环境值）** —— HeroUI 的 `TextField` / `ControlField` / `Label` / `Description` / `FieldError` 那一族。本仓完全没有「字段级校验态」这一层，`PinCode` / `TagInput` / `SearchField` / `CheckBoxToggleStyle` / `RadioGroup` 都读不到 invalid；`FormField` 容器 + `@Entry var fieldValidation` 一次补齐。**M**
2. **Toast 内容结构与生命周期补齐**（description 第二行、action 按钮、`ToastDuration.persistent`、`dismissAll()`、拖拽时暂停计时）—— HeroUI native `Toast.Title/Description/Action/Close` + `duration: number | 'persistent'`。本仓 `ToastItem` 只有单行 `message`（`lineLimit(1)`）且计时不可暂停。**M**
3. **Banner 补 title/description 与 actions 槽 + 可选 dismiss** —— HeroUI `Alert.Indicator/Content/Title/Description`。本仓 `Banner` 只有 `level` + 单个 `label` 槽，`BannerStyleConfiguration` 只暴露 `label` / `level`。**M**
4. **`Badge` / `Tag` / `Avatar` 接入 `controlSize`** —— HeroUI 所有小件都有 `size: sm|md|lg`；本仓这三件源码里零处读 `\.controlSize`（`AvatarGroup` 反而读了）。SwiftUI 的五档 `ControlSize` 比 HeroUI 三档更好，只是没接。**S**

### P2

5. **锚定式徽标 modifier（HeroUI React `Badge` + `Badge.Anchor` + `placement`）** —— 本仓 `Badge` 实际是 HeroUI 的 `Chip`（独立胶囊标签）；「贴在头像 / 图标角上的红点 / 计数」这一形态本仓没有，SwiftUI 的 `.badge()` 只作用于 `List` 行与 `TabView`。做成 `View.anchoredBadge(_:placement:)`（名字避开 SwiftUI `.badge`）。**S**
6. **可选中的 `TagGroup`（filter chips）** —— HeroUI native `TagGroup` 的 `selectionMode: 'none'|'single'|'multiple'` + `disabledKeys` + `onRemove`。本仓 `Tag` 只有 removable、`TagInput` 只管输入，没有「一组可选标签」；SwiftUI 无原生对应。基于既有 `Tag` + `FlowLayout` 组装，选中态用 `accentSubtleBackground`（墨色淡染，不上彩色）。**M**
7. **`.coreCircular` 确定进度的 `ProgressViewStyle`**（HeroUI `ProgressCircle`）—— 本仓 `CoreProgressViewStyle` 只画线性确定态，不确定态回退系统圆形；iOS 上 `ProgressView(value:)` 配 `.circular` 不画确定环（未核实：以 iOS 18 行为为准），确定态圆环在本仓只有 Charts 的 `RingChart`（活动环语义，且要 `import OhMyDesignCharts`）。走形态 A（原生协议）。**S/M**
8. **按压反馈 `ButtonStyle`（`.pressable` / `.row`）给卡片与自绘行用** —— HeroUI `PressableFeedback`（scale + highlight）与 `ListGroup.Item`（pressable 行）。本仓按压缩放只封在 `buttonBackground`（`Modifier/ButtonBackgroundModifier.swift`，internal），`SettingsRow` / `ListRow` / `Card` 自己没有按压态；调用方把它们包进 `Button` 会得到系统默认 `.automatic` 的整块变淡。做两个 `ButtonStyle`：行用 `tertiaryFill` 高亮、卡片用 `CoreButtonMetrics.pressedScale`。**S**
9. **嵌套 surface 的环境感知**（HeroUI `Surface` 的 "Nested Surfaces" + "in Surface, use `variant=secondary`"）—— 本仓 `.surface(_:)` 不写任何环境值，`Card` 套 `Card` 两层同色（`surfaceCard` = `secondarySystemGroupedBackground`），`surfaceElevated`（`tertiarySystemGroupedBackground`）今天只有 `.sidebar` 一个消费点。补 `@Entry var surfaceKind`，`Card` / `InsetGroupedSection` 嵌套时自动升一档。**S/M**
10. **系统 sheet 的 `.core` 预设 modifier**（HeroUI `BottomSheet` / `Dialog` 只取「token 预设」这一层）—— 不重造 sheet，做 `View.coreSheetPresentation()` 把 `presentationCornerRadius(CoreRadius.xLarge)` / `presentationDragIndicator` / `presentationBackground(Color.surfaceRaised)` 打包；`docs/DESIGN-FOUNDATION.md` 自陈 `CoreRadius.xLarge`（22）「当前零消费，为 Dialog / Modal / Sheet 预留」。**S**
11. **`SearchField` 不响应 `.disabled()`**（顺带发现）—— HeroUI `SearchField` 根上有 `isDisabled` 级联到子件；本仓 `SearchField.swift` 里没有任何 `isEnabled` 读取，`UIViewRepresentable` / `NSViewRepresentable` 不会自动把 SwiftUI 的 `\.isEnabled` 传给 `UISearchTextField` / `NSSearchField`（未在运行期复现，源码层结论）。**S**

### P3

12. `Skeleton` 增加 `pulse` 动效档（HeroUI `variant: 'shimmer'|'pulse'|'none'`），走 D2 枚举 `SkeletonAnimation`，`none` 顺带成为 reduce-motion 之外的显式关闭口。**S**
13. `Separator` 增加 `axis`（HeroUI `orientation` + `thickness`）——或在文档里明说竖向用系统 `Divider()`。**S**
14. `UnderlinedTabBar` / `SegmentedControl` 支持逐项禁用与 `Label`（图标 + 文字）——HeroUI `Tabs.Trigger.isDisabled` / "With Icons"。本仓两者 `title: (Item) -> String` 只吃字符串。**S/M**
15. `KeyCap`（HeroUI React `Kbd` + `Kbd.Abbr`）—— 只对 macOS / iPad 硬键盘有意义；本仓 `captionMono` token 已有，缺一个描边小方块。**S**
16. `InlineCode`（HeroUI `Typography.Code`：等宽 + 淡底 + 小圆角的行内片）—— `typography.md` 墓碑把 Typography 判出局是对的，但「行内代码片」这一件 `.coreFont(.captionMono)` 给不了底色。**S**
17. `.scrollShadow(edges:)`（HeroUI `ScrollShadow`）—— iOS 26 的 `scrollEdgeEffectStyle` 只管系统 chrome 下的边缘；内容区局部列表的渐隐没有原生。要 `.mask`，须登记到 `MaskSiteRegistryGuard`（`CLAUDE.md` 硬规则）。**M**
18. `Gauge` 的 `.core` `GaugeStyle`（对 HeroUI `Meter`）—— 原生 `Gauge`（iOS 16+）就是 Meter 语义；只做换皮。**S**
19. `RangeSlider`（HeroUI `Slider` 的 range 模式）—— SwiftUI 无原生双滑块。HIG 也没有这个控件，谨慎；只在有真实消费方时做。**M**

## 2. 新组件候选表

「原生情况」列按 iOS 26 / macOS 26 SwiftUI。建议列三选一：新增 / `.core` style / 不做。

| HeroUI 组件（N=Native, R=React） | SwiftUI 原生情况 | 建议 | 理由 | 放哪个 target |
|---|---|---|---|---|
| TextField + Label + Description + FieldError（N/R）、ControlField（N）、Fieldset（R） | `Form` + `Section(header:footer:)` + `LabeledContent` 覆盖「标签 + 说明」，但**没有字段级 invalid 态**，也没有独立于 `Form` 的字段容器 | **新增 `FormField`**（容器 + `@Entry var fieldValidation`），控件本身仍用系统 `TextField` / `Toggle` | `docs/components/core-control-styles.md`「诚实略过：Toggle / TextField」已定案不重造控件；HeroUI 的价值在**字段状态在容器与子件之间的传播**（Label 变红、Description 可 `hideOnInvalid`、FieldError 带入场动画、`isRequired` 星号），这层 SwiftUI 没有。校验态用枚举 `FieldValidation { valid, invalid(Text) }` 而不是 `isInvalid: Bool`（`component-contract.md` §3 禁 Bool 参数） | OhMyDesign |
| Badge（R，`Badge.Anchor` + `placement: top-right…`） | `.badge()` 只对 `List` 行 / `TabView` 生效；内容区头像角标无原生 | **新增 modifier `anchoredBadge`** | 本仓 `Badge`（`Components/Badge/Badge.swift`）是独立标签，等价 HeroUI `Chip`；缺的是「叠在锚点角上」的定位形态。红点 / 计数上色走 `statusDangerEmphasis`（固定饱和色 + `contentOnEmphasis` 白字），不跟随墨色 accent——与 iOS 系统角标一致 | OhMyDesign |
| TagGroup（N/R，`selectionMode` / `disabledKeys` / `onRemove` / `renderEmptyState`） | 无（`Picker` 不是 chips） | **新增 `TagGroup`** | 复用 `Tag` + `FlowLayout`（`Layout/FlowLayout.swift`）。选中态：`accentSubtleBackground` 底 + `borderSelected` 描边（都已存在于 `Colors/InteractionColors.swift` / `BorderColors.swift`）。`selectionMode` 做 enum，`disabledKeys` 用 `Set<ID>` | OhMyDesign |
| ProgressCircle（R） | `ProgressView(value:)` + `.circular` 在 iOS 上不画确定环（未核实） | **`.core` style：`CoreCircularProgressViewStyle`** | 形态 A；`configuration.fractionCompleted` 画 `.tint` 圆弧，nil 时回退系统 spinner。`RingChart` 是活动环语义、在 Charts target，不是通用进度 | OhMyDesign |
| Meter（R） | `Gauge`（iOS 16+）就是 Meter | **`.core` `GaugeStyle`**（低优先） | 换皮不重造；只统一轨道色 `surfaceCanvasInset` 与 `.tint` 填充 | OhMyDesign |
| PressableFeedback（N） | `ButtonStyle` 就是这个扩展点 | **`.core` style：两个 `ButtonStyle`** | scale 复用 `CoreButtonMetrics.pressedScale`（`Tokens/CoreButtonMetrics.swift`），highlight 用 `tertiaryFill`；不做 Android ripple | OhMyDesign |
| Surface（N/R） | 无 | **不新增组件，补环境值** | 本仓已有 `View.surface(_:)` + `SurfaceKind`（`Modifier/SurfaceModifier.swift`），缺的只是嵌套感知，见 §4 | OhMyDesign |
| BottomSheet（N）、Dialog（N）、Modal / Drawer / AlertDialog（R） | `.sheet` + `presentationDetents` / `.alert` / `.confirmationDialog` / `.fullScreenCover` 全部原生 | **不做组件；做 `coreSheetPresentation()` 预设** | 消费 `CoreRadius.xLarge`；HeroUI 的 `isSwipeable` / `Overlay variant: blur` 都是原生 sheet 自带的行为 | OhMyDesign |
| Popover（N/R）、Tooltip（R） | `.popover`（iOS 26 在 iPhone 也可弹）；macOS `.help(_:)` 即 tooltip | **不做** | `Modifier/SurfaceModifier.swift` 的 `.panel` 注释已明确「菜单 / popover 不在 `SurfaceKind` 射程，走系统」；iOS HIG 没有 tooltip | — |
| Menu / SubMenu（N）、Dropdown（R） | `Menu`（含嵌套 `Menu` 作子菜单）、`.contextMenu` | **不做** | 同上；`MenuStyle` 在 iOS 上无 `makeBody` 定制点，连 `.core` 都做不了（macOS 才有，未核实是否值得） | — |
| Select（N，`presentation: popover / bottom-sheet / dialog`）、ComboBox / Autocomplete（R） | `Picker`（`.menu` / `.navigationLink` / `.wheel`）、`.searchable` + suggestions | **不做** | HeroUI 三种 presentation 对应 iOS 的 menu picker / 下一级页面 / sheet 里的 `List`，全是原生组合 | — |
| Switch（N/R）、ToggleButton（R） | `Toggle`、`.toggleStyle(.button)` | **不做** | `core-control-styles.md` 已定案：自定义 `ToggleStyle` 丢原生手势 / haptic | — |
| Checkbox / CheckboxGroup（N/R）、RadioGroup（N/R） | macOS 有 `.checkbox` / `.radioGroup`，iOS 无 | **已有**（`CheckBoxToggleStyle`、`RadioGroup`），只补 invalid 态（并入 P1 的 `fieldValidation`） | — | — |
| Slider（N，含 range） | `Slider` 单值原生；双滑块无 | **单值不做；`RangeSlider` P3 观望** | HIG 无此控件 | OhMyDesign（若做） |
| Accordion（N/R）、Disclosure / DisclosureGroup（R） | `DisclosureGroup` + 本仓 `.core` style | **不做**（单开互斥由调用方用 `isExpanded` 绑定实现） | `Components/Style/CoreDisclosureGroupStyle.swift` 已是形态 A；HeroUI 多出的 `variant: 'surface'` 就是 `.surface(.grouped)` 包一层 | — |
| Tabs（N/R） | `TabView` 管页面；栏本身本仓已有 | **已有**：`UnderlinedTabBar`（= HeroUI `secondary` 下划线）、`SegmentedControl`（= `primary` 填充）；补禁用项 / `Label` | HeroUI 把栏与 `Tabs.Content` 绑在一起；SwiftUI 里内容切换由调用方 `switch selection` 更自然，不必绑 | — |
| ButtonGroup（R）、ToggleButtonGroup（R）、Toolbar（R） | `ControlGroup`、`.toolbar` | **不做**（可选 P3：`ControlGroupStyle` 的 `.core`） | `ControlGroupStyle` 有公开 `makeBody`，形态 A 可行，但没有消费方 | — |
| CloseButton（N/R） | iOS 26 `Button(role: .close)`（未核实具体可用性）+ `.buttonStyle(.glass)`；本仓 `.circularGlass` | **不做** | — | — |
| LinkButton（N）、Link（R） | `Link`、本仓 `.borderless()` | **不做** | `Colors/ContentColors.swift` 的 `contentLink` 注释登记了「单色体系下链接无下划线」缺口，那是 token 层的事 | — |
| Spinner（N/R） | `ProgressView()`；本仓 `ProgressIndicator` | **已有** | HeroUI 的 `color: success/warning/danger` 语义色 spinner 不采 | — |
| Skeleton / SkeletonGroup（N/R） | `.redacted` 只对 Text/Image 有效 | **已有**；`SkeletonGroup` 的「集中 `isLoading`」本仓 `Skeleton(isLoading:placeholder:content:)` 容器已等价 | 补 `pulse` 档见 §3 | — |
| Avatar / AvatarGroup（N/R） | 无 | **已有**；`Avatar` 缺图片 + fallback 链，见 §3 | — | — |
| Alert（N/R）→ Banner；Toast（N/R）→ Toast；Chip（N/R）→ Badge/Tag；Card / ListGroup / Separator → Card / SettingsRow+InsetGroupedSection+ListRow / Separator | — | **已有**，见 §3 | — | — |
| InputOTP（N/R）→ PinCode；SearchField（N/R）→ SearchField；InputGroup（N/R，prefix/suffix） | `TextField` 无 prefix/suffix 槽 | PinCode / SearchField 已有；**InputGroup 不单独做**，归入 `FormField` 的可选 `leading` / `trailing` 槽 | HeroUI 的 `isDecorative`（触摸穿透 + 对读屏隐藏）是个好细节，对应 `.allowsHitTesting(false)` + `.accessibilityHidden(true)` | OhMyDesign |
| Typography（N/R） | `Text` + 本仓 `.coreFont` | **不做**（`docs/components/typography.md` 墓碑成立）；只补 `InlineCode` 小件 | — | OhMyDesign |
| Kbd（R） | 无 | **新增 `KeyCap`**（P3） | macOS / iPad 硬键盘快捷键提示；`captionMono` + `borderMuted` 描边 + `CoreRadius.small` | OhMyDesign |
| ScrollShadow（N/R） | iOS 26 `scrollEdgeEffectStyle` 只管系统栏下的边缘 | **P3 `.scrollShadow(edges:)`** | 必须走 `.mask` ⇒ 登记 `MaskSiteRegistryGuard`，遮罩基色用 `Color.maskOpaque`（`CLAUDE.md`「遮罩基色」段） | OhMyDesign |
| Breadcrumbs / Pagination（R） | `NavigationStack` 返回链 / 无限滚动 | **不做** | HIG 不用面包屑；分页在移动端由滚动承担 | — |
| Table（R）、Calendar / DateField / DatePicker / DateRangePicker / RangeCalendar / TimeField（R）、ColorArea / ColorField / ColorPicker / ColorSlider / ColorSwatch / ColorSwatchPicker（R）、NumberField（R） | `Table`、`DatePicker` / `MultiDatePicker`、`ColorPicker`、`Stepper` + `TextField(value:format:)` 全部原生 | **不做** | React Aria 为 Web 补的原生缺件，Apple 平台本来就有 | — |
| Form（R） | `Form` | **不做** | — | — |

## 3. 现有组件优化表

优先级沿用 §1。「不照搬」列是与 HIG / 墨色 / 本仓公约冲突的部分。

| 本仓组件（源文件） | HeroUI 对应 | 可借鉴点（具体） | 不照搬点 | 优先级 |
|---|---|---|---|---|
| `Toast` / `ToastHost` / `ToastItem`（`Components/Toast/Toast.swift`） | Toast（N：`Toast.Title/Description/Action/Close`、`duration: number \| 'persistent'`、`maxVisibleToasts`、`hide('all')`、`isSwipeable`；R：`toast.promise`、`pauseAll/resumeAll`、计时在 hover / focus 时暂停） | ① `ToastItem` 增 `description: String?`（第二行，`contentSecondary`），`message` 的 `lineLimit(1)` 改成 title 1 行 + description 2 行；② `action: ToastAction?`（label + 闭包），渲染成 `.borderless()` 按钮，避免调用方只能「点整条关闭」；③ `duration` 改成 `enum ToastDuration { case seconds(TimeInterval); case persistent }`，persistent 时不排 `scheduleDismiss`；④ `ToastHost.dismissAll()`；⑤ 拖拽中暂停 `dismissTask`（HeroUI 的「hover/focus 暂停计时」在触屏上对应「手指按住不计时」）；⑥ `AsyncButton` 的 `_runThrowing` 已经在 `onError == nil` 时自动弹 danger toast——这是 `toast.promise` 的一半，可再补「进行中 → 成功」的可选 toast（走参数，不是默认） | HeroUI 的堆叠卡片（`scale.value [1, 0.97]` / `translateY [0, 10]` 露一角）不采：iOS 通知式反馈一次一条，本仓队列语义（`queue.first` 才渲染）保持；`variant: 'accent'` 不采（accent 是墨色，没有「强调色 toast」的概念）；`placement: 'top start / top end'`（React）是桌面角落定位，本仓 `edge` 二选一够用 | P1 |
| `Banner` + `BannerStyle`（`Components/Banner/Banner.swift`） | Alert（N/R：`Alert.Indicator / Content / Title / Description`、`status: default \| accent \| success \| warning \| danger`、"With Action Buttons"、`Alert.Indicator` 可换自定义图标） | ① `BannerStyleConfiguration` 增 `title: Text?` 与 `actions: AnyView?`（现只有 `label` / `level`），默认 style 渲染「图标 + 标题（`headline`）+ 正文 + 底部 / 尾部动作行」；② `onDismiss: (() -> Void)?` 出现时渲染 `xmark` 关闭钮（可选闭包，不是 `dismissible: Bool`）；③ `StatusLevel`（`Components/StatusLevel.swift`）加 `.neutral` case：HeroUI `status: 'default'` 是中性通知，本仓 `Badge` 有 `.neutral` 而 `Banner` / `Toast` / `Timeline` 共用的 `StatusLevel` 没有，中性提示今天只能借 `.info`；④ 图标槽做成 D1 外观槽（`indicator:`），与 `TimelineItem.node:` 同形 | HeroUI 的 `status: 'accent'` 不采（同上）；Alert 的 `role="alert"` 在 SwiftUI 对应 `AccessibilityNotification.Announcement`，只在 Banner 动态出现时才该播，不要写死 | P1 |
| `Badge`（`Components/Badge/Badge.swift`）、`Tag`（`Components/Tag/Tag.swift`）、`Avatar`（`Components/Avatar/Avatar.swift`） | Chip（`size: sm/md/lg`、`variant: primary/secondary/tertiary/soft`、`color`）、Avatar（`size`） | ① 三件都读 `@Environment(\.controlSize)`：`Badge` / `Tag` 的字号走 `CoreControlMetrics.fontToken(for:)`、内边距走 `horizontalPadding / verticalPadding`（`Tokens/CoreControlMetrics.swift` 已有五档表，`AvatarGroup` 已按 `controlSize` 算 `avatarSize`，`Avatar` 自己却是固定 48pt 位图 + `.resizable()`），让 `AvatarGroup { Avatar(...) }` 两边尺寸口径一致；② `Tag` 的关闭钮 `removeIconSize` 写死 `iconSize(for: .small)`，应随 `controlSize` | HeroUI Chip 的 `variant × color` 5×4 彩色矩阵不采——本仓 `Badge` 五档 `BadgeVariant` 走 `status*Subtle / *Border`（`Colors/StatusColors.swift`）已够，`Tag` 由调用方给色是刻意的（源码注释「语义完全来自调用方选的颜色」）；`Chip.Background` 的 glass 底不采（chrome 类小件不上玻璃，本仓 `Tag` 注释「无默认玻璃」） | P1（S） |
| `Avatar`（同上） | Avatar（N：`Avatar.Image` 加载态 / 失败自动切 `Avatar.Fallback`，`delayMs` 防闪、`useAvatar().status: loading/loaded/error`、默认 person 图标） | ① `Avatar` 现只有 `init(name:)` 首字母 + 姓名哈希色；补 `init(name:image:)` / `init(name:url:)`（后者用 `AsyncImage`），加载中 / 失败回落到首字母；② fallback 延迟（`delayMs` → `Duration`）避免图片瞬时加载时闪一下字母；③ 图片失败时保留 `Image(size:label:)` 的 `accessibilityLabel = name`（现有做法正确，别丢） | `color: accent/success/warning/danger` 头像底色不采（姓名哈希色已是本仓决定，且头像不该承载状态语义）；`variant: 'soft'` 不采 | P2 |
| `AvatarGroup`（`Components/AvatarGroup/AvatarGroup.swift`） | AvatarGroup（R：`max` / `isGrid` / `overlap: 'clip' \| 'ring'` / `AvatarGroup.Count` 显式总数 / 无默认 `role="group"`） | ① 本仓 `AvatarGroupLayout`（overlapped / spaced / grid / countOnly）已**超过** HeroUI；唯一可补：显式总数（服务端给的 `total`）——HeroUI 用 `AvatarGroup.Count` 且「不被 `max` 截断」，本仓 `overflow = subviews.count - max` 只能数子视图；② HeroUI 明确「有语义的组要 `role=group` + `aria-label`」，本仓 `linearRow` 的 `HStack` 没有 `accessibilityElement(children: .contain)` + 组名 | `overlap: 'clip'`（新月裁切）不采：本仓用 `surfaceCanvas` 描边分隔，与 iOS 系统头像堆叠一致 | P3 |
| `Skeleton` / `SkeletonLine` / `SkeletonRect` / `SkeletonCircle`（`Components/Skeleton/Skeleton.swift`） | Skeleton / SkeletonGroup（`variant: 'shimmer' \| 'pulse' \| 'none'`、`isSkeletonOnly`、shimmer 1500ms / pulse 1000ms `minOpacity 0.5`） | ① 补 `pulse`（整体 0.5↔1 透明度呼吸）与 `none`：D2 枚举 `SkeletonAnimation`，经环境值下发（`View.skeletonAnimation(_:)`），`Skeleton` 容器与独立 `.skeletonShimmer()` 都读；pulse 比 shimmer 便宜，多行同屏时可当低功耗档，可与 `Environment/EnergyPolicy.swift` 的 `RenderPolicy.reduced` 联动（`reduced` ⇒ 自动降到 pulse）；② `isSkeletonOnly`（加载完隐藏整组以免空容器占位）本仓不需要——`Skeleton` 有 `content:` 槽，不存在「只有占位没有内容」的用法 | shimmer 高光色可配（`shimmer.highlightColor`）不采：`FillColors.swift` 已把 `skeletonHighlight` 定为 `skeletonBase.mix(with: .white, by: 0.5)`，是 token 决定 | P3 |
| `ProgressIndicator`（`Components/ProgressIndicator/ProgressIndicator.swift`）、`CoreProgressViewStyle`（`Components/Style/CoreProgressViewStyle.swift`）、`spinning`（`Modifier/SpinningModifier.swift`） | Spinner、ProgressBar（`isIndeterminate`）、ProgressCircle、Meter（R） | ① `.core` 的不确定态目前回退到系统圆形 spinner（源码 `else` 分支）；`SpinningModifier.swift` 里的 `TopBarIndicator` 已是一条不确定线性条（`barWidthRatio 0.3`、`period 1.1`），可抽成 `.core` 不确定态的线性画法，让 `ProgressView().progressViewStyle(.core)` 真的是线性；② 确定态圆环见 §2 `CoreCircularProgressViewStyle`；③ HeroUI 的 `valueLabel` / `formatOptions` 对应 `ProgressView(value:label:currentValueLabel:)`，本仓 `.core` 已渲染 `currentValueLabel`，够了 | `color: success/warning/danger` 进度条不采——本仓 `.core` 的强调色走 `.tint` 通路（`CLAUDE.md` FR-12），调用方 `.tint(.red)` 即可 | P2 |
| `PinCode`（`Components/PinCode/PinCode.swift`） | InputOTP（N：`InputOTP.Group` + `Separator` 分组、`SlotCaret` 闪烁光标、`placeholder` 逐格占位字符、`pattern`（digits / chars / both）、`isInvalid`、`pasteTransformer`、`onChange`） | ① 分组：`groups: [Int]`（如 `[3, 3]`）在组间插 `Separator` 视觉（"-"），HeroUI 的 6 位 OTP 默认就是 3+3；② 焦点格的闪烁 caret（`opacity [0,1]` 500ms）：本仓焦点格只有描边加粗（`CoreBorderWidth.thick` + `.tint`），空格没有光标，用户不知道在输入；③ `pattern`：本仓 `sanitizedValue` 写死 ASCII 数字，字母数字验证码（如邀请码）用不了——做成 `enum PinCodeCharacterSet { digits, alphanumeric }`；④ invalid 态：描边走 `statusDangerBorder`，并入 `fieldValidation` 环境值；⑤ `pasteTransformer` 对应粘贴「123-456」自动去连字符——`sanitizedValue` 的过滤已顺带做到，只是 `alphanumeric` 模式下要重新定义 | `SlotBackground` 玻璃底不采；`SlotValue` 的 `FlipInXDown` 翻转入场——iOS 系统 OTP 没有这种动效，`HIG` 输入反馈越安静越好，最多 `.contentTransition(.numericText())`；不做 `textInputProps` 直通（本仓公开 API 禁止单端符号，`pin-code.md`「NFR-2」） | P2 |
| `SearchField`（`Components/SearchField/SearchField.swift`） | SearchField（N：根 `isDisabled / isInvalid / isRequired` 级联；`SearchField.SearchIcon` / `ClearButton` 可省，省了就不留内边距；`accessibilityRole="search"`、`returnKeyType="search"`） | ① **`isEnabled` 未透传**：`updateUIView` / `updateNSView` 没有 `field.isEnabled = context.environment.isEnabled`（源码里零处 `isEnabled`）；② `returnKeyType = .search`：`makeUIView` 没设，回车键仍显示 "return"（未在模拟器核实）；③ invalid 态并入 `fieldValidation`（原生控件描边走 `layer.borderColor` 或外层 `overlay`）；④ `placeholder` 已做了空串回退的 a11y 名，保留 | 放弃手搓的决定是对的（源码注释列了 6 条理由），HeroUI 的 compound 拆件（`SearchIcon` / `ClearButton` 可省）在原生 `UISearchTextField` 上是系统行为，不需要开槽 | P2（S） |
| `SegmentedControl` + `SegmentedControlStyle`（`Components/SegmentedControl/SegmentedControl.swift`）、`UnderlinedTabBar`（`Components/TabBar/UnderlinedTabBar.swift`） | Tabs（N：`variant: primary`（填充 thumb，= 本仓 SegmentedControl）/ `secondary`（下划线，= UnderlinedTabBar）、`Tabs.Trigger.isDisabled`、`Tabs.ScrollView.scrollAlign: start/center/end/none`、"With Icons"、`Tabs.Separator` 在非相邻选中时显示、`Tabs.Indicator` spring `stiffness 1200 / damping 120`） | ① 逐项禁用：两者的 `items: [Item]` 没有禁用集；补 `disabled: Set<Item>` 参数（`Segment` 结构体加 `isDisabled`，属公约 §3 例外「Style Configuration 上的状态描述 Bool」）；② 图标 + 文字：`title: (Item) -> String` 之外加 `label: (Item) -> Label` 重载，`GlassSegmentedControlStyle` 的 iOS 原生分支用 `insertSegment(with: UIImage)` 或退到 SwiftUI 分支；③ `UnderlinedTabBar` 的 `scrollTo(anchor: .center)` 写死居中，HeroUI 给了 `scrollAlign`，D2 枚举可补（低价值）；④ HeroUI `Tabs.Separator`「相邻选中时隐藏分隔线」这个细节，本仓 `PlainSegmentedControlStyle` 段间没有分隔线，不需要 | 把 `Tabs.Content`（面板）并进组件——SwiftUI 里内容切换由调用方 `switch` 或 `TabView(selection:)` 更自然；`primary` 变体的 `ListBackground` 玻璃已经在本仓（`segmentedGlassChrome`），不必再抽象 | P3 |
| `Card`（`Components/Card/Card.swift`）、`View.surface(_:)` + `SurfaceKind`（`Modifier/SurfaceModifier.swift`） | Card（N：`Card.Header / Body / Title / Description / Footer`，`variant: default/secondary/tertiary/transparent` 继承 Surface）、Surface（N/R：`variant` 三级 + `transparent`，"Nested Surfaces"，React 有 `SurfaceContext` 供子件读当前级别） | ① 嵌套感知：`.surface(_:)` 写 `@Entry var surfaceKind`，`Card` 在 `.content` 里再出现时自动取 `surfaceElevated`（`Colors/SurfaceColors.swift` 已有，只有 `.sidebar` 消费）；macOS 上 `windowBackgroundColor == controlBackgroundColor`（`DESIGN-FOUNDATION.md` `#239` 实测）⇒ macOS 靠描边区分，与文档裁决一致，不要为此拉阶梯；② `Card` 的 header / footer 槽：HeroUI 的 `Card.Footer`「底部动作行」在 iOS 分组卡片里对应「按钮行 + 上方分隔线」，可做 `Card(header:footer:)` 便利 init，分隔线复用 `Separator`；③ `variant: 'transparent'` 对应本仓 `.surface(.canvas)`（`border: .clear`），已有 | `Card.Title` / `Card.Description` 这类**排版子件**不采——SwiftUI 里 `Text(...).coreFont(.headline)` 就是它，`typography.md` 墓碑的理由同样适用；`elevation` 别再扩（`Card.swift` 自陈已是「单点越界」） | P2 |
| `Separator`（`Components/Separator/Separator.swift`） | Separator（N：`orientation`、`variant: thin/thick`、`thickness`） | ① `axis: Axis`（竖向用于工具栏 / 并排按钮之间），厚度仍走 `1 / displayScale` hairline；或文档明说竖向用 `Divider()`（系统 `Divider` 会按父容器轴自动竖向）；② `variant: thick` 对应本仓 `dividerOpaque`（`BorderColors.swift`），可作 D2 枚举 `SeparatorEmphasis { subtle, opaque }` | 自由 `thickness: number` 不采（走 `CoreBorderWidth` 档位） | P3 |
| `SettingsRow` / `InsetGroupedSection`（`Components/SettingsRow/SettingsRow.swift`、`Components/InsetGroupedSection/InsetGroupedSection.swift`）、`ListRow`（`Components/ListRow/ListRow.swift`）、`Descriptions` + `CoreLabeledContentStyle` | ListGroup（N：`ListGroup.Item` 是 Pressable，`ItemPrefix / ItemContent / ItemTitle / ItemDescription / ItemSuffix`，`ItemSuffix` 默认 chevron、传 children 覆盖；"With PressableFeedback"） | ① 行的按压态：`SettingsRow` 有 `.contentShape(Rectangle())` 但无按压反馈，包进 `Button` 用系统 `.automatic` 样式会整行变淡而不是 iOS 设置那种 `tertiaryFill` 高亮——补 `ButtonStyle` `.settingsRow`（highlight 用 `Color.pressedBackground` = `tertiaryFill`，`Colors/InteractionColors.swift` 已定义但零消费）；② `ListRow` 只在 macOS `onHover` 时铺 `surfaceCanvasSubtle`，iOS 触摸没有反馈，同一 style 解决；③ HeroUI `ItemSuffix` 「默认 chevron，传内容即覆盖」= 本仓 `accessory` 槽 + `SettingsRowChevron`，等价；④ `InsetGroupedSection` 的 `Group(subviews:)` 自动分隔线已经比 HeroUI 好（HeroUI 要手写分隔） | HeroUI `ListGroup.ItemTitle/ItemDescription` 排版子件不采（`SettingsRow` 的 `title / subtitle` 参数已是等价物） | P2 |
| `SolidButtonStyle` / `LightButtonStyle` / `CoreBorderlessButtonStyle` / `ButtonRoleStyleRole`（`Components/Button/`）、`AsyncButton`（`Components/Button/AsyncButton.swift`） | Button（N：`variant: primary/secondary/tertiary/outline/ghost/danger/danger-soft`、`size`、`isIconOnly`、`feedbackVariant: scale-highlight/scale-ripple/scale/none`、"Loading State with Spinner"、`Button.Background` 主题玻璃）、ButtonGroup、CloseButton、LinkButton | ① 变体对照：HeroUI `danger-soft` ≈ `.light(role: .danger)`，`ghost` ≈ `.borderless()`，`outline` 本仓没有（描边 + 透明底）——可作 `OutlineButtonStyle`，但 iOS 26 系统按钮里 `.bordered` 即是「淡底」而非「描边」，HIG 不推描边按钮，**不建议补**；② `isIconOnly`（正方形 / 圆形命中区）：本仓只有 `.circularGlass` 承担图标按钮，非玻璃的图标按钮没有等宽等高的形状——可给 `solid / light` 加 D2 枚举 `shape: .capsule / .circle`（不是 Bool），`buttonChrome` 按 `iconSize` 撑成正方形；③ 语义指引：HeroUI Design Principles「Primary 一屏一个、Tertiary 用于取消 / 跳过、Danger 破坏性」可写进 `docs/components/button.md`，本仓 `ButtonRoleStyleRole` 的 secondary / tertiary 今天只有色阶定义没有使用指引；④ `AsyncButton` 的 loading 形态（label 隐藏 + spinner）与 HeroUI 一致，`allowsHitTesting(false)` 也对——HeroUI 没做的、本仓做了的是 `onDisappear` 取消任务，保留 | `feedbackVariant: scale-ripple`（Android ripple）不采；`Button.Background` 玻璃底默认挂在 secondary / tertiary 上不采（本仓玻璃只在浮层）；HeroUI 的 `size: sm/md/lg` 三档比本仓 `ControlSize` 五档少，不动 | P3 |
| `CheckBoxToggleStyle`（`Components/CheckBox/CheckBox.swift`）、`RadioGroup` / `RadioOption`（`Components/Radio/Radio.swift`） | Checkbox（N：`isInvalid` 显示 danger 色、`hitSlop 6`、勾选 SVG path 描画动画、`scale [1, 0.96]` 按压）、RadioGroup（N：`RadioGroup.Item` + `Label` + `Description`，`isInvalid`，`Radio.IndicatorThumb scale [1.5, 1]`） | ① invalid 态（并入 `fieldValidation`）：方框 / 圆点用 `statusDangerForeground`；② `RadioOption` 只有 `title: String`，HeroUI 每项可带 `Description`——加 `subtitle: String?`（`SettingsRow` 同形）；③ `CheckBoxToggleStyle` 用 `.onTapGesture` 切换，未核实 VoiceOver 双击是否仍能切换（自定义 `ToggleStyle` 的 a11y 由系统包，通常可以，但值得在 iOS 腿加一条判据）；④ `hitSlop`：两者都已用 `frame(minHeight: 44)` + `contentShape`，够 | 勾选路径描画动画、`borderRadius [8, 0]` 变形不采：本仓用 SF Symbols `checkmark.square.fill`，可用 `.contentTransition(.symbolEffect(.replace))` 做系统级替换动效即可 | P3 |
| `Rating` / `RatingDisplay` / `RatingStyle`、`Steps`、`Timeline`、`Carousel`、`StateLabel`、`FlowLayout`、`Descriptions` | HeroUI 无对应（Rating / Steps / Timeline / Carousel 都不在 v3 组件表里） | 无可借鉴；反过来这几件是本仓相对 HeroUI 的超集 | — | — |
| `Effects`（`Sources/OhMyDesignEffects/*`：shake / jump / spin / ping / shine / 16 种转场 / Confetti / Haptic 等） | HeroUI 只有 `animation` prop（Reanimated 配置对象）与 `PressableFeedback`，没有表达性动效层 | ① HeroUI 的 `animation="disable-all"` 级联关闭是一个**环境值**模式：本仓 Effects 已有 `EnergyPolicy` / `RenderPolicy`（`Environment/EnergyPolicy.swift`）按低电量 / 后台降帧，但没有「调用方主动关闭子树全部动效」的入口——可加 `@Entry var motionPreference: .system / .reduced / .none`，Skeleton / Carousel / Effects 都读它（现在三处各自读 `accessibilityReduceMotion`，散） | — | P3 |
| `Charts`（`RadarChart` / `RingChart` / `ActivityHeatmap` / `NetworkGraph`） | HeroUI 无图表 | 无 | — | — |

## 4. 横切模式

### 4.1 表单字段状态传播（建议吸收，P1）

HeroUI native 的 `TextField` / `ControlField` / `SearchField` / `TagGroup` / `RadioGroup` / `InputOTP` 根上都有同一组 prop：`isDisabled` / `isInvalid` / `isRequired`，子件 `Label`（`isRequired` 画星号、`isInvalid` 变 danger）、`Description`（`hideOnInvalid`）、`FieldError`（`isInvalid` 控显隐 + `FadeIn 150ms / FadeOut 100ms`）通过 "form-item-state context" 自动消费，且 `Description.nativeID` ↔ `aria-describedby` 把说明文字挂到控件的可访问描述上。

本仓现状：
- `isDisabled` 已由 SwiftUI `\.isEnabled` 原生承担（`SolidButtonStyle` / `PinCode` / `Rating` 都读）。
- **`isInvalid` / `isRequired` 没有任何对应**：grep 全仓 `Sources/OhMyDesign` 没有 `invalid` / `required` 语义；`PinCode` 的错误只能靠调用方 `.tint(.red)` 假装。
- 「说明文字」在 `Form` 里由 `Section(footer:)` 承担，`Form` 之外只有 `SectionFooter`（`Components/Section/SectionFooter.swift`），与控件之间没有 a11y 关联。

建议形态（贴合 `component-contract.md`）：
- `public enum FieldValidation: Equatable { case valid; case invalid(Text) }` + `@Entry var fieldValidation: FieldValidation = .valid`（§3.4 环境值路径；不是 `isInvalid: Bool`）。
- `public enum FieldRequirement { case optional, required }` + `@Entry`。
- `FormField<Label, Control, Description>` 容器：`label` 走 `contentSecondary` + required 星号 `statusDangerForeground`，`description` 走 `footnote` + `contentMuted`，error 行从 `fieldValidation.invalid(text)` 取、带 `.transition(.opacity)`，并对控件 `.accessibilityHint(description)`，error 出现时 `AccessibilityNotification.Announcement`。
- 消费方：`PinCode` 焦点 / 边框色、`CheckBoxToggleStyle` / `RadioGroup` 图标色、`SearchField` 外描边、`TagInput` 输入框描边。

### 4.2 Surface 层级与嵌套感知（建议吸收，P2）

HeroUI：`Surface variant: default / secondary / tertiary / transparent` 是**纯突出度阶梯**，`Card` / `ListGroup` / `Accordion(variant: 'surface')` 都继承它；文档明说「Surface 里的表单件用 `variant="secondary"`」——即子件按所在层选低一档强调。React 侧有 `SurfaceContext` 让子件读当前层。

本仓：`SurfaceKind`（`Modifier/SurfaceModifier.swift`）是**角色枚举**（canvas / content / control / floating / grouped / panel）+ 三个「兼容别名」（canvasSubtle / sidebar / card），角色与阶梯混在一起；`.surface(_:)` 不写环境，子件不知道自己在哪一层。iOS 系统色三档（`systemGroupedBackground` / `secondary…` / `tertiary…`）恰好就是 HeroUI 的三级阶梯，本仓 token 层（`SurfaceColors.swift` 的 `surfaceCanvas / surfaceRaised / surfaceElevated`）已经对齐，缺的只是**容器写环境 + 子容器读环境自动升档**。

不采：HeroUI 的命名（default / secondary / tertiary）——本仓命名已按角色定案，改名是破坏性变更；`transparent` 已有 `.canvas`。

### 4.3 尺寸体系

HeroUI：所有组件统一 `size: 'sm' | 'md' | 'lg'`（Design Principles 第 5 条「Predictable Behavior」）。本仓走 SwiftUI `ControlSize` 五档 + `CoreControlMetrics`（`Tokens/CoreControlMetrics.swift`）的 5 个查询函数，机制更好；问题是**覆盖不全**：`Badge` / `Tag` / `Avatar` / `Banner` / `Toast` / `StateLabel` 都不读 `controlSize`（grep 结果为零）。建议：把「读 `\.controlSize`」列为 `ComponentRegistryGuard` 一类的登记项，至少 chrome 类小件（Badge / Tag / Avatar / StateLabel）先接。

### 4.4 Variant 命名：语义优先

HeroUI Design Principles 第 1 条：`primary / secondary / tertiary / danger` 按**意图**命名，不按外观（solid / flat / bordered）。本仓两套并存：`ButtonRoleStyleRole`（primary / secondary / tertiary / warning / danger）是语义的，但 style 入口 `.solid` / `.light` / `.borderless` 是外观命名。这不冲突（SwiftUI 自己的 `.bordered` / `.borderedProminent` 也是外观命名），**不建议改**；可借鉴的只是把 HeroUI 那张「Primary 一屏一个 / Tertiary 用于取消」的使用规则写进 `docs/components/button.md`。

### 4.5 颜色派生：与本仓公式对照

HeroUI Colors：`--accent` 的 hover = `color-mix(accent 90%, accent-foreground 10%)`（朝前景走）、soft 底 = `accent 15% transparent`、soft 前景 = `color-mix(color 70–80%, foreground 30–40%)`（Accessible）或 92/8（Vibrant，文档自认可能不过 WCAG）。
本仓 `Colors/InteractionColors.swift`：hover = `mix(with: .surfaceBase, by: 0.18)`（**朝背景走**，因为 accent 是明度极值的墨色）、pressed 0.30、subtle 底 `opacity(0.08)`、disabled `opacity(0.22)`。方向相反是墨色 accent 的必然，无需对齐。可借鉴的一点：HeroUI 把 **soft 前景**（淡底上的字）单独定义并保证对比度，本仓 `Badge` 的淡底 + `status*Foreground` 是资源色定案的，`Tag` 的 `color.opacity(0.12)` 底 + 原色字则**没有对比度保证**（调用方传浅色会不可读）——可给 `Tag` 补一条「前景按亮度 mix 到 `inkPrimary`」的派生，与 `Color.onAccent(for:in:)`（`Colors/CoreAccentEnvironment.swift`）同一思路。

### 4.6 表单字段专属色（`--field-*`）

HeroUI 把输入类控件的底 / 占位 / 前景 / hover 单列为 `--field-background` 等，与按钮 / 卡片隔离。本仓 `surfaceInteractive`（= `tertiaryFill`）同时喂 `LightButtonStyle` 底与 `PinCode` 格底。iOS HIG 里文本框在分组列表内是 cell 底、独立摆放时用 `tertiarySystemFill`，与本仓一致；**不建议**新增 field 族，只在 `FormField` 落地时确认 `SurfaceKind.control` 是输入类的唯一出口。

### 4.7 Focus ring

HeroUI（React Aria）按 `:focus-visible` 自动画环；native 版没有 focus ring 概念。本仓 `View.focusRing(visible:color:width:cornerRadius:)`（`Modifier/FocusRingModifier.swift`）要调用方手传 `visible`，且 preview 只在 `canImport(UIKit)` 下。macOS 原生控件由系统画环，SwiftUI 自定义可聚焦视图可读 `@Environment(\.isFocused)`。建议：加一个零参数重载读 `\.isFocused` 自动显隐（S），其余不动；iOS 触屏无 focus ring 是 HIG 行为，不补。

### 4.8 动效总开关

HeroUI 的 `animation="disable-all"` 级联 + Provider 全局关闭 + 自动尊重 Reduce Motion。本仓：`Skeleton` / `Carousel` 各自读 `accessibilityReduceMotion`，Effects 走 `EnergyPolicy`（低电量 / 后台）。缺一个「调用方主动关闭」的环境入口；见 §3 Effects 行。不采 HeroUI 逐动画的 `timingConfig` 对象（SwiftUI 的 `.animation(_:value:)` 已是覆盖机制）。

### 4.9 Compound 组件 → SwiftUI 形态映射（供实现时对表）

| HeroUI 形态 | 本仓对应形态（`component-contract.md`） | 先例 |
|---|---|---|
| `X.Background`（主题玻璃底，`background={null}` 移除） | 不映射；玻璃只在 `.floatingGlass` / `TelegramGlassButtonModifier` | — |
| `X.Indicator`（默认图标，children 覆盖） | D1 外观槽（`@ViewBuilder` 有默认画法） | `TimelineItem.node:` |
| `X.Title` / `X.Description`（排版子件） | 不映射；`Text + .coreFont` | `typography.md` 墓碑 |
| `variant` 封闭枚举 | D2 配置枚举 | `ToastPresentation` / `StepsPresentation` |
| Context / hook（`useX()`） | `@Entry` 环境值 | `\.toastHost`、`\.coreAccent` |
| `isSelected` / `isDisabled` render props | Style Configuration 上的状态 Bool（§3 例外） | `SegmentedControlStyleConfiguration.Segment.isSelected` |
| `asChild` | 无需（SwiftUI 泛型 `Label: View` 即是） | — |

## 5. 明确不建议吸收的清单与理由

| 项 | 理由 |
|---|---|
| 彩色 `color: accent / success / warning / danger` 铺满 Button / Chip / Avatar / Spinner / Progress / Badge 的变体矩阵 | 本仓 accent 是墨色，「强调色 = 品牌色」的前提不成立；状态色只在 `StatusColors` 五族里用于**状态**（Badge / Banner / Toast / Timeline），不用于装饰性上色。`CLAUDE.md`：图表 / tag 走 `dataAccent`，刻意不跟随 accent |
| 主题玻璃底默认挂在 Button（secondary / tertiary）/ Chip / Avatar / Checkbox / Switch / Slider 轨道 / OTP 格 / Tabs 列表上（`X.Background`） | 本仓定案：Liquid Glass 只用于浮层（`FloatingGlassModifier` / `TelegramGlassButtonModifier` / `SegmentedControl` 外壳 / `Carousel` 页点），静置控件与 chrome 不上玻璃；`Tag.swift` 注释「无默认玻璃、无装饰性材质」 |
| `PressableFeedback.Ripple`（Android ripple） | 非 Apple 交互语言 |
| Toast 堆叠卡片（`scale 0.97` / `translateY 10` 露角、`maxVisibleToasts 3`）、桌面六角定位 | iOS 反馈一次一条；本仓队列模型（`queue.first` 才渲染）保持 |
| 逐动画 `timingConfig` / `springConfig` 配置对象、`isAnimatedStyleActive` | SwiftUI 的 `.animation(_:value:)` / `.transaction` 已是覆盖机制；本仓 Effects 也不暴露 |
| Web / RN 专属交互：hover 态、`:focus-visible` 环、`hotkey Alt+T` 聚焦 toast 区、`FullWindowOverlay` / `Portal` / `disableFullWindowOverlay` | 触屏无 hover（`ListRow` 的 `onHover` 只对 macOS 有效，保留即可）；SwiftUI 的 overlay 由 `.sheet` / `.popover` / `.overlay` 层级承担，无 portal 概念 |
| `Tabs.Content` / `Card.Title` / `Card.Description` / `ListGroup.ItemTitle` / `Alert.Title` 这类**排版或布局子件** | SwiftUI 里就是 `Text` + `.coreFont`；`typography.md` 已定案 parity |
| Select / Menu / Popover / Dialog / BottomSheet / Tooltip / Switch / Slider / DatePicker / ColorPicker / Table / NumberField / Form / Toolbar / ButtonGroup / Link / CloseButton 组件本体 | 全部有原生对应；`component-contract.md` §2「A 永远优先于 B」与 `CLAUDE.md`「换皮不重造」。其中 `Menu` 在 iOS 连 `.core` 都做不了（`MenuStyle` 无公开 `makeBody`，未核实 macOS 侧） |
| Breadcrumbs / Pagination | HIG 不用面包屑；分页由滚动承担 |
| Button `outline` 变体 | iOS 26 系统按钮无描边样式，`.bordered` 是淡底；HIG 不推描边按钮 |
| `size: sm/md/lg` 三档尺寸体系 | 本仓 `ControlSize` 五档更细，且是系统环境值 |
| `Typography` 组件（含 `Typography.Heading` 自动 `header` role） | 墓碑成立；`SectionHeader` 已加 `.accessibilityAddTraits(.isHeader)`，标题 role 由调用方在 `Text` 上加即可 |
| `Kbd` 的完整 `keyValue` 表（`command / shift / … / pageup`） | 若做 `KeyCap`，符号映射用 SwiftUI `KeyEquivalent` / `EventModifiers` 推导，不复制字符串表 |
| HeroUI "Vibrant Palette"（92/8 混色、自认可能不过 WCAG） | 本仓 `ButtonRoleStyleRole.onColor` 注释已按实测对比度定案，不引入低对比选项 |

## 附：本仓文档小漂移（顺带发现，非 HeroUI 相关）

- `docs/components/tag.md`「圆角：`CoreRadius.small`（3pt）」——`Tokens/CoreRadius.swift` 里 `small = 6`。
- `docs/components/badge.md` / `tag.md` / `banner.md` / `toast.md` 的「视觉 Token」仍写 `CoreTypography.bodySmallFont` / `bodyMediumFont` / `titleLargeFont`，这些名字在 `Tokens/CoreTypography.swift` 里已不存在（0.3.0 改名为 `footnote` / `callout` / `title` 等）。
- `docs/components/button.md`「LightButton 暗色：`.glassEffect(.regular)`」——`CLAUDE.md`《按钮样式模式》已声明该句实测为假，doc 未同步。
