# OhMyDesign 现状盘点：Timeline / Tree / 按钮状态 / 滑动确认

调查范围：`/Users/evan/Repositories/work-spec/oh-my-design`，分支 `main`（工作树里 `App/OhMyDesignPreview.xcodeproj/project.pbxproj` 的未提交改动、`.claude/worktrees/` 均未触碰）。仅取证，不做设计提案。未运行 `swift build` / `swift test`。

所有源码/JSON 引用均为「文件路径 + 逐字引文」。凡未查到的一律写明「没查到」/「grep 无结果」，不用「应该」「大概」填补。

---

## A. 现有 Timeline

### A.1 源码位置与公开 API

唯一源文件：`Sources/OhMyDesign/Components/Timeline/Timeline.swift`（`find Sources -iname "*Timeline*"` 只命中这一个）。

**`TimelineItem`**（`public struct TimelineItem: Identifiable`）：

```swift
public struct TimelineItem: Identifiable {
    public let id: UUID
    let status: StatusLevel
    let node: AnyView?
    let content: AnyView
```

只有 `id` 是 `public` 存储属性；`status`/`node`/`content` 均非 public。两个 public init：

```swift
public init<Content: View>(
    id: UUID = UUID(),
    status: StatusLevel = .info,
    @ViewBuilder content: () -> Content
)
```

```swift
public init<Node: View, Content: View>(
    id: UUID = UUID(),
    status: StatusLevel = .info,
    @ViewBuilder node: () -> Node,
    @ViewBuilder content: () -> Content
)
```

**`TimelineLayout`**（`public enum TimelineLayout: Sendable, Equatable`）——**四个 case，均已实现，不是"没有"**：

```swift
public enum TimelineLayout: Sendable, Equatable {
    /// 默认：左侧固定节点列 + 右侧内容，节点间竖向连线（现状形态）。
    case vertical
    /// 左右交替：内容在中轴两侧交替排布。
    /// 业界来源：Ant Design Timeline 的 `mode="alternate"`。
    case alternate
    /// 横向：节点沿水平轴排列，内容在节点下方。
    /// 业界来源：PowerPoint SmartArt 的 Basic Timeline / Final Cut Pro 的横向事件时间线。
    case horizontal
    /// 无连线的分组列表：删掉节点列与连线，只留内容；本形态下 `TimelineItem.node:` 槽不生效。
    case grouped
}
```

**`Timeline`**（`public struct Timeline: View`）：

```swift
public struct Timeline: View {
    let items: [TimelineItem]
    let layout: TimelineLayout

    public init(items: [TimelineItem], layout: TimelineLayout = .vertical) {
        self.items = items
        self.layout = layout
    }

    public var body: some View {
        switch self.layout {
        case .vertical: self.verticalBody
        case .alternate: self.alternateBody
        case .horizontal: self.horizontalBody
        case .grouped: self.groupedBody
        }
    }
```

`items`/`layout` 均非 public——外部无法反射读取已传入的 `Timeline` 实例的这两个值（测试靠 `@testable import` 才能读，`TimelineTests.swift` 里 `timeline.items.count` 走这条路）。

### A.2 颜色 token

- 节点色 `Timeline.nodeColor(for:in:)`：`Color.statusAccentEmphasis`（info）、`Color.statusSuccessEmphasis`（success）、`Color.statusAttentionForeground`（浅色 warning）/`Color.statusAttentionEmphasis`（暗色 warning）、`Color.statusDangerEmphasis`（danger）、`Color.contentSecondary`（neutral）。
- 连线：`Rectangle().fill(Color.dividerDefault)`。
- Preview 另用：`Color.statusSuccessEmphasis`、`Color.statusDangerEmphasis`、`Color.surfaceCanvas`（背景）。

### A.3 尺寸来源——完全硬编码，不读 `controlSize`

对 `Timeline.swift` 全文 grep `controlSize` 无命中。逐字：

```swift
nonisolated static let nodeColumnWidth: CGFloat = 24
static let nodeDiameter: CGFloat = 10
```

间距走 `CoreSpacing.md`/`.lg`/`.none`/`.xxs` token；连线宽度 `CoreBorderWidth.thin`。

### A.4 连线/节点画法

节点：`Circle().fill(...).frame(width: Timeline.nodeDiameter, height: Timeline.nodeDiameter)`（`TimelineNodeView`）；自定义节点直接替换为传入的 `node` 视图，套进 24×24 的 `.frame`，**不裁剪**。

连线（`TimelineConnector`）：

```swift
struct TimelineConnector: View {
    var body: some View {
        Rectangle()
            .fill(Color.dividerDefault)
            .frame(width: CoreBorderWidth.thin)
            .frame(maxHeight: .infinity)
            .padding(.top, Timeline.nodeColumnWidth)
    }
}
```

`.alternate` 用自定义 `Layout`（`TimelineAlternateRowLayout: Layout`，实现 `sizeThatFits`/`placeSubviews`）：弹性左槽｜固定节点列｜弹性右槽，节点中心恒为行宽一半。`.horizontal` 用 `ScrollView(.horizontal) { HStack { ... } }`，**不画节点间连线**（源码注释与文档均确认，属"有意搁置"，见 A.7）。`.grouped` 用 `VStack`，无节点列无连线。

### A.5 `#Preview`

文件内两个 `#Preview`（Light/Dark），均渲染同一个 `TimelinePreviewGallery`：

1. 默认圆点节点，5 种 `StatusLevel`（info/success/warning/danger/neutral）。
2. 自定义节点：`Image(systemName: "checkmark.circle.fill")`、`Circle().fill(.blue).frame(width: 20, height: 20)`、`Image(systemName: "xmark.circle.fill")`。
3. 注释 `// MARK: \`#60\` 形态 D2 新增的三种排布` 下：`.alternate`（含单条无连线场景）、`.horizontal`、`.grouped`（含默认节点与自定义节点两种子场景）。

没有任何展示"进行中动画"、"loading"、"拖拽/滑动"的场景。

### A.6 `docs/components/timeline.md`（已逐字读取，148 行）

- `节点状态色**直接复用 \`StatusLevel\`**（info/success/warning/danger/neutral），不新增公开状态语义枚举`。
- API 表格列出 `TimelineItem` 与 `Timeline` 两个 designated init。
- `TimelineLayout` 四 case 对照业界来源表格（同源码注释）。
- 明确记载两处**有意的静默失效**：`.grouped` 下 `TimelineItem.node:` 槽"传了不生效**不报错**"；`.horizontal` 不画连线，"横向连线属独立形态，本轮不引入"。
- 视觉 token：节点方框 24×24pt、默认圆点直径 10pt；浅色 warning 对比度例外（`statusAttentionEmphasis` 浅色金黄对分组背景约 2:1，改用 `statusAttentionForeground` 达 4.36:1/4.87:1）；连线 `Color.dividerDefault` + `CoreBorderWidth.thin`（1pt，"对 phase0『连线对齐 separator』决策的有意偏离"）。
- Accessibility：默认圆点带 label（Info/Success/Warning/Error/Neutral，danger 播报为 "Error"）；自定义 `node` 不叠加该 label；`.grouped` 下用 `accessibilityValue` 补回状态语义。
  - ⚠️ 文档提到的函数名 `Timeline.applyGroupedStatusValue(_:item:)` 与源码里实际找到的 `Timeline.groupedStatusKey(for:)` 不完全一致——可能是文档相对源码的措辞漂移，未深究成因。

### A.7 `docs/component-registry.json` 登记项

```json
"component": "Timeline",
"repo": "ohmydesign",
"kind": "semantic",
"decidedBy": "step2",
"nativeProtocol": null,
"customStyleProtocol": null,
"styleSlot": null,
"styleEnum": "TimelineLayout",
"needsExtensionPoint": true,
"textParams": [],
```

`notes` 要点（逐字节选）：
- 判定为 `semantic` 组件（非纯规定性），扩展点已通过 `TimelineLayout`（`#60` 落地）满足。
- `「左侧固定 24pt 节点列 + 右侧内容」（Timeline.nodeColumnWidth，逐字 static let nodeColumnWidth: CGFloat = 24）`。
- **`.horizontal` 本轮不画节点间连线……横向连线属独立形态，尚无承接 issue……这是**有意不开**issue 的：横向连线是一个尚无需求驱动的增强，不是缺口。**

⚠️ 登记表里还有一条**不相关的同名词条** `"component": "DelegationTimeline"`（`"repo": "storyui"`）——属于另一个仓库（`storyui`），与本仓 `Sources/OhMyDesign/Components/Timeline/Timeline.swift` 无关，排查时不要误认。

### A.8 测试覆盖

- **`Tests/OhMyDesignTests/TimelineTests.swift`**（唯一专测文件，488 行），两个 `@Suite`：
  - `"Timeline"`：纯结构/逻辑断言，不碰像素——`nodeColor(for:in:)` 按 `StatusLevel×ColorScheme` 映射到 asset 名字符串比较（如 `"status-accent-emphasis"`）；`accessibilityLabelKey` 映射；两种 init 的字段存储；`Timeline.isLastItem` 边界情况；`items`/`layout` 原样保留；`.grouped` 下 `node` 槽"不生效 ≠ 被改写"；四种布局 `.body` 可求值不 crash；`alternateSlotWidth`/`alternateRowMetrics` 几何计算（含 `infinity`/`nan`/负数防御）。
  - `"Timeline 默认圆点取色"`（`TimelineNodeColorRenderTests`，`@MainActor`，**`.enabled(if: assetCatalogIsCompiled, ...)`**——即 CLAUDE.md 记载的"198 个 asset catalog 常量在 macOS native 腿全透明"那条坑的显式跳过）：这里**真做像素比较**——`ImageRenderer` 渲染 `CGImage`，与同文件内联复刻的 `LegacyTimeline`（"改动前"旧实现）逐字节比对；另有浅色 warning 圆点对三种系统背景色的非文本对比度 ≥ 3:1 断言。
- **`Tests/OhMyDesignTests/DynamicTypeLayoutTests.swift`**——`#if os(iOS)`（macOS 上空 suite）：`timelineGrowsWithDynamicTypeWithoutOverlap` 只比较 `.large` 与 `.accessibility5` 下的总渲染高度，不测具体像素/重叠细节。
- **`Tests/OhMyDesignTests/ComponentExtensionPointGuard.swift`**：把 `Timeline` 列入 J-2 定义域的 16 个具名组件清单（结构性判据，非行为测试）。
- **`Tests/OhMyDesignTests/QuotedEvidenceGuard.swift`**：登记了几条"文档引用源码原文须仍在源码里"的判据，引用点含 `@ViewBuilder node: () -> Node,`、`static let nodeColumnWidth: CGFloat = 24` 等（纯文档-源码一致性判据）。
- `ComponentJudgeRulesTests.swift` 里出现的 `Timeline`/`TimelineItem` 是判据规则本身的 fixture 字符串，不是真测组件行为。
- `OhMyDesignEffectsTests` 下命中的均是系统 `TimelineView`（SwiftUI 计时器类型）或无关变量名，未发现真正测试 `OhMyDesign.Timeline` 组件本体的内容。

### A.9 局限性（如实记录，均有代码依据）

- **没有 header/footer/description 插槽**：`init` 只接受 `items:`/`layout:`，无 `@ViewBuilder header:`/`footer:`；`TimelineItem.content` 是唯一的富内容槽。
- **左右交替布局：已支持，不是局限**——`.alternate` 已实现且有测试覆盖（`alternateSlotWidth`），需要更正"现在做不到"的预设认知。
- **节点可自定义，但有硬约束**：`TimelineItem(node:content:)` 可完全替换默认圆点，但节点必须 ≤ 24×24pt——超出会"上下溢出方框、上沿侵入上一行、下沿被连线穿过"（源码注释原文）。不支持自适应更大节点。
- **状态表达完全借用 `StatusLevel`**（info/success/warning/danger/neutral），**不存在**"完成/进行中/未开始"这种时间线专属三态；状态只驱动默认圆点颜色，不驱动连线颜色、节点大小，也没有"进行中"的脉冲/高亮强调。
- **无动效**：对 `Timeline.swift` 全文 grep `glassEffect`/`coreAnimation`/`CoreMotionToken`/`withAnimation` 均无命中，组件本身不含任何动画声明。文档甚至提醒"若由外部可变状态驱动，调用方应显式传入稳定 id，否则每次刷新重建 `TimelineItem` 会产生新 identity，引发不必要的插入/删除动画"——即默认是**主动避免**动画误触发，而非提供动效能力。
- **`.horizontal` 不画节点间连线**：已知且**刻意搁置**的缺口（登记表原文见 A.7），"尚无需求驱动的增强，不是缺口"。若 PRD 涉及横向 Timeline 增强，这是现成候选点。
- **`items`/`layout` 非 public**：外部拿到 `Timeline` 实例后无法反射读取已传入配置，SwiftUI 常见模式，非严重局限，但设计 Tree 时可能需要注意同类先例。

---

## B. 按钮体系现状

### B.1 `Sources/OhMyDesign/Components/Button/` 文件清单

```
Sources/OhMyDesign/Components/Button/AsyncButton.swift
Sources/OhMyDesign/Components/Button/ButtonRoleStyleRole.swift
Sources/OhMyDesign/Components/Button/styles/CircularGlassButtonStyle.swift
Sources/OhMyDesign/Components/Button/styles/CoreBorderlessButtonStyle.swift
Sources/OhMyDesign/Components/Button/styles/ExtendedFloatButtonStyle.swift
Sources/OhMyDesign/Components/Button/styles/LightButtonStyle.swift
Sources/OhMyDesign/Components/Button/styles/PressableButtonStyles.swift
Sources/OhMyDesign/Components/Button/styles/SolidButtonStyle.swift
```

6 个 `ButtonStyle`/`PrimitiveButtonStyle`：`SolidButtonStyle`、`LightButtonStyle`、`CoreBorderlessButtonStyle`（`PrimitiveButtonStyle`）、`CircularGlassButtonStyle`、`ExtendedFloatButtonStyle`、`PressableRowButtonStyle`/`PressableCardButtonStyle`（同文件并列）。另有 `AsyncButton`——不是 `ButtonStyle`，是包裹 `Button` 的独立 View。

**`SolidButtonStyle`**：

```swift
public func makeBody(configuration: Configuration) -> some View {
    let isPressed = configuration.isPressed
    let backgroundColor = self.role.resolvedColor(accent: self.coreAccent, isEnabled: self.isEnabled, isPressed: isPressed)

    configuration.label
        .buttonChrome(shape: Capsule(style: .continuous), controlSize: self.controlSize)
        .foregroundStyle(self.foregroundColor)
        .buttonBackground(
            shape: Capsule(style: .continuous),
            fill: backgroundColor,
            border: Color.borderMuted,
            isPressed: isPressed,
            pressedOpacity: 0.92
        )
}
```

`@Environment`：`coreAccent`、`coreAccentOn`、`colorScheme`、`isEnabled`、`controlSize`。状态只区分 `isEnabled`/`isPressed`。

**`LightButtonStyle`**：`@Environment(\.coreAccent)`、`\.isEnabled`、`\.controlSize`；同样只有 enabled/disabled/pressed。

**`CoreBorderlessButtonStyle`**（`PrimitiveButtonStyle`，自己用手势模拟按压态）：

```swift
@GestureState private var isPressed = false
...
private var pressedStateGesture: some Gesture {
    DragGesture(minimumDistance: 0)
        .updating(self.$isPressed) { _, isPressed, _ in
            isPressed = true
        }
}
```

`makeBody` 里 `.animation(.easeInOut, value: self.isPressed).simultaneousGesture(self.pressedStateGesture).onTapGesture(count: 1, perform: configuration.trigger)`。

**`CircularGlassButtonStyle`** / **`ExtendedFloatButtonStyle`**：均只有 `@Environment(\.isEnabled)`，禁用态是整体 `.opacity(0.4)`，无 `controlSize` 环境联动（`CircularGlassButtonStyle` 只有构造参数 `size: ControlSize`，非环境读取）。

### B.2 `ButtonRoleStyleRole`（`Components/Button/ButtonRoleStyleRole.swift`）

```swift
public nonisolated enum ButtonRoleStyleRole: Sendable, Equatable {
    case primary
    case secondary
    case tertiary
    case warning
    case danger
```

5 个 case，**全部是语义/品牌角色，不是"运行状态"**。暴露属性：`color`（primary→`.accent`，secondary→`.secondaryAccent`，tertiary→`.neutralAccent`，warning→`.warning`，danger→`.danger`）、`activeColor`（对应 `*Pressed`/`*Active`）、`disabledColor`（对应 `*Disabled`/`*Disable`）、`onColor`（恒 `.contentOnAccent`）、`resolvedOnColor(...)`（仅 `.primary` 走 `Color.onAccent(for:in:)` 动态判黑白）、`resolvedColor(isEnabled:isPressed:)`。

**整个 role/颜色体系只覆盖 normal / pressed / disabled 三态，且是交互反馈层面，不是业务语义状态（loading/success/error/进行中）。**

### B.3 loading / success / error / progress 现状

`grep -rniE "loading|isLoading" Sources/OhMyDesign/Components/Button/` 只命中 `AsyncButton.swift`。loading 态**只存在于 `AsyncButton` 这一个 View，不是任何 `ButtonStyle` 的能力**：

```swift
} label: {
    ZStack {
        self.label
            .opacity(self.isRunning ? 0 : 1)
            .accessibilityHidden(self.isRunning)
        if self.isRunning {
            ProgressView()
                .progressViewStyle(.circular)
                .controlSize(.small)
                .accessibilityHidden(true)
        }
    }
    .accessibilityElement(children: .combine)
    .animation(.snappy(duration: 0.16), value: self.isRunning)
}
.allowsHitTesting(!self.isRunning)
.modifier(LoadingAccessibilityModifier(isLoading: self.isRunning))
```

用的是系统默认 `.circular` style，**不是**本仓 `.core`/`.coreCircular`（`CoreProgressViewStyle`/`CoreCircularProgressViewStyle`，`Sources/OhMyDesign/Components/Style/CoreProgressViewStyle.swift`）。`Components/Style/` 与 `Components/Button/` 之间**没有任何互相引用**（grep 已核对，无结果）；`docs/components/core-control-styles.md` 通篇未提及与按钮的结合点。

`grep -rniE "success|\berror\b|progress" Sources/OhMyDesign/Components/Button/` 命中的全部是 `AsyncButton` 的 `onError:` 回调与上面的 `ProgressView()`——**没有任何 success 态**，也没有"错误态改变按钮外观"的代码：`AsyncButton` 抛错时唯一反应是转给 `onError` 回调，或 `toastHost?.show(error.localizedDescription, level: .danger)` 弹 Toast，**按钮自身外观不变**，恢复原 label 即视为"成功"，无反馈动效。

`docs/component-registry.json` 里 `AsyncButton` 条目的 `notes` 原文提到"自动忙碌反馈（isRunning 时 spinner 替换 label）是 AsyncButton 存在的定义性理由"——**登记表自己承认 loading 反馈是 `AsyncButton` 独有能力，非按钮体系通用能力**。

**结论——按钮现在完全没有表达的状态：**
1. **success（成功反馈）**：`Components/Button/` 全目录 grep 无任何命中。
2. **error（按钮自身外观层面）**：错误反馈完全外包给调用方 `onError` 或 Toast，按钮本身不变色、不显示错误图标。
3. **loading 作为 `ButtonStyle` 能力**：不存在；仅存在于独立 View `AsyncButton`，用系统默认 spinner，`ButtonRoleStyleRole` 五个 role 与六个 `ButtonStyle` 完全不知道"运行中"这个概念。
4. `ButtonRoleStyleRole` 的 normal/pressed/disabled 三态是唯一状态维度，且只服务交互反馈色。

### B.4 `PressableButtonStyles.swift`

逐字核实"只装饰 label、不接 role、不改前景色、不读 controlSize"的说法属实：

```swift
/// 只装饰 label——不接 role 色板、不改前景色、不读 `controlSize`、不加内边距，
/// 适合把整条 `SettingsRow` / `ListRow` 做成可点击行。禁用时不给按压反馈并整体变淡。
public struct PressableRowButtonStyle: ButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        PressableRowBody(label: configuration.label, isPressed: configuration.isPressed)
    }
}
```

`PressableRowBody` 只读 `@Environment(\.isEnabled)`；`PressableCardBody` 多一个 `\.accessibilityReduceMotion`。`body` 只做 `overlay(Color.pressedBackground)` 或 `.scaleEffect(...)` + `.opacity(...)`，**没有任何颜色取自 `ButtonRoleStyleRole`**，验证属实。状态覆盖：idle / 按下 / 禁用（`disabledOpacity = 0.4`），reduceMotion 下多一档 `reducedMotionPressedOpacity = 0.7`——仍是交互反馈层面，非业务状态。

### B.5 文档与登记表

`docs/components/button.md`、`pressable-button-styles.md` 全文均**未出现"状态"章节**、无 loading/success/error 字样。`docs/component-registry.json` 中按钮相关条目只有 `AsyncButton`、`FullScreenButton`（独立组件）、`TelegramGlassButtonModifier`（`Solid`/`Light`/`CircularGlass` 三个 style 共享的玻璃结构 modifier）——**`SolidButtonStyle`/`LightButtonStyle`/`CoreBorderlessButtonStyle`/`CircularGlassButtonStyle`/`ExtendedFloatButtonStyle`/`PressableRowButtonStyle`/`PressableCardButtonStyle` 这 7 个 style 类型本身，登记表里没有任何一条以它们的名字登记**（如实记录此缺口，未做成因推断）。

---

## C. 手势与滑动类现状

### C.1 全仓 `DragGesture` 命中（三个 target）

`Sources/OhMyDesignCharts` 无命中。共 4 处：

**`Sources/OhMyDesign/Components/Rating/Rating.swift`**（拖拽评分，非滑动确认语义）：

```swift
.gesture(
    DragGesture(minimumDistance: 0)
        .onChanged { drag in
            guard self.measuredWidth > 0 else { return }
            let x = self.layoutDirection == .rightToLeft
                ? self.measuredWidth - drag.location.x
                : drag.location.x
            self.value = Self.steppedValue(
                atRelativeX: x,
                totalWidth: self.measuredWidth,
                count: self.count,
                step: self.step
            )
        },
    isEnabled: self.isEnabled
)
```

无 `@GestureState`、无阈值、无回弹——纯位置映射到评分值。

**`Sources/OhMyDesign/Components/Button/styles/CoreBorderlessButtonStyle.swift`**：见 B.1，`DragGesture(minimumDistance: 0)` 只当按压检测用，不涉及位移/阈值。

**`Sources/OhMyDesignEffects/BeforeAfterSlider.swift`**（对比滑块，纯位置映射非确认语义）：

```swift
.gesture(
    DragGesture(minimumDistance: 0)
        .onChanged { value in
            self.hasInteracted = true
            let axis = BeforeAfterSweep.axis(for: self.layout)
            let extent = axis == .vertical ? proxy.size.height : proxy.size.width
            let coordinate = axis == .vertical ? value.location.y : value.location.x
            self.fraction = BeforeAfterSweep.fraction(dragCoordinate: coordinate, extent: extent)
        }
)
```

无 `@GestureState`、无阈值/触发判断（连续跟手，没有"松手才生效"这一步）。动画只用在 intro sweep 和松手回到初始态：`withAnimation(.easeInOut(duration: sweep.duration)) { self.fraction = sweep.peak }`。

**`Sources/OhMyDesign/Components/Toast/Toast.swift`**——唯一具备"滑动+阈值+触发+回弹"完整语义的实现，见 C.2。

### C.2 Toast 的 swipe-to-dismiss（全仓唯一"滑动才触发"实现）

```swift
private var interactionGesture: some Gesture {
    DragGesture(minimumDistance: 0)
        .updating(self.$isPressing) { _, pressing, _ in
            pressing = true
        }
        .updating(self.$isDragging) { value, dragging, _ in
            if abs(value.translation.height) > 0 || abs(value.translation.width) > 0 {
                dragging = true
            }
        }
        .onChanged { value in
            guard self.presentation != .centeredHUD else { return }
            let dy = value.translation.height
            self.dragOffset = self.allowsDrag(dy) ? dy : dy * ToastDefaults.reverseDragDamping
        }
        .onEnded { value in
            guard self.presentation != .centeredHUD else { return }
            let dy = value.translation.height
            let pastThreshold = abs(dy) >= ToastDefaults.swipeDismissThreshold
            if pastThreshold, self.allowsDrag(dy) {
                self.onDismiss()
            }
            self.dragOffset = .zero
        }
}

private func allowsDrag(_ dy: CGFloat) -> Bool {
    switch self.edge {
    case .top: dy <= 0
    case .bottom: dy >= 0
    }
}
```

阈值常量（`ToastDefaults`）：

```swift
static let swipeDismissThreshold: CGFloat = CoreSpacing.xxl
static let reverseDragDamping: CGFloat = 0.5
static let dismissSlideDistance: CGFloat = 60
```

反方向拖拽被 `reverseDragDamping`（0.5）阻尼。用了两个 `@GestureState`（`isPressing`、`isDragging`），具体消费点未深挖。回弹动画的精确挂载点**没查到**（`.animation(value: dragOffset)` 未在片段中确认到，属证据缺口）。

**结论**：Toast 是全仓唯一具备"滑动超过阈值才确认动作、否则回弹"语义骨架的组件，可作滑动确认按钮的最近参照；但阈值/阻尼/触发逻辑都写死在 Toast 内部，不是抽出来的可复用 modifier 或 gesture 类型。

### C.3 `CoreMotionToken`——**关键发现：main 分支上不存在**

`find . -name "CoreMotionToken.swift"` 在 `main` 工作树上无结果；`git cat-file -e HEAD:Sources/OhMyDesign/Tokens/CoreMotionToken.swift` 返回 "does not exist in HEAD"。

证据链：`.claude/epics/motion-foundations/epic.md` 记录 issue #407 `status: closed`，对应 PR #411；`git log --oneline --all` 有 `473c16e Issue #407: CoreMotionToken + Reduce Motion discipline (#411)`，但 `git merge-base --is-ancestor 473c16e HEAD` 返回非祖先。`gh pr view 411` 确认 `baseRefName: "epic/motion-foundations"`——PR #411 合入的是 epic 分支，不是 main。main 上的 `6318aea docs(ccpm): #407 closed (PR #411)` 只改了 CCPM 台账文件，**没有带源码**。

即：**`CoreMotionToken` 目前只存在于 `origin/epic/motion-foundations` 分支，尚未合入 main**。写 PRD 若要依赖它，需先确认该 epic 何时并入 main。

在 `origin/epic/motion-foundations:Sources/OhMyDesign/Tokens/CoreMotionToken.swift` 上取得的逐字内容：

```swift
public nonisolated enum CoreMotionToken: Sendable, CaseIterable {
    case press      // 0.16s snappy
    case selection  // 0.22s snappy
    case reveal     // 0.25s smooth
    case scroll     // 0.35s smooth

    public var duration: TimeInterval {
        switch self {
        case .press: 0.16
        case .selection: 0.22
        case .reveal: 0.25
        case .scroll: 0.35
        }
    }

    public var animation: Animation {
        switch self {
        case .press, .selection: .snappy(duration: self.duration)
        case .reveal, .scroll: .smooth(duration: self.duration)
        }
    }

    public func animation(for presentation: MotionPresentation) -> Animation? {
        switch presentation {
        case .animated: self.animation
        case .resting: self == .scroll ? nil : .easeInOut(duration: self.duration)
        case .hidden: nil
        }
    }
}
```

`MotionPresentation` **不是**这个文件新定义的——`main` 分支上已存在于 `Sources/OhMyDesign/Environment/EnergyPolicy.swift`：

```swift
public nonisolated enum MotionPresentation: Sendable, Equatable, CaseIterable {
    case hidden
    case resting
    case animated
}
```

`View.coreAnimation(_:value:)`（epic 分支）：

```swift
public extension View {
    func coreAnimation(_ motion: CoreMotionToken, value: some Equatable) -> some View {
        self.modifier(CoreAnimationModifier(motion: motion, value: value))
    }
}

private struct CoreAnimationModifier<Value: Equatable>: ViewModifier {
    let motion: CoreMotionToken
    let value: Value

    @Environment(\.coreMotionPresentation) private var presentation

    func body(content: Content) -> some View {
        content.animation(self.motion.animation(for: self.presentation), value: self.value)
    }
}
```

### C.4 `coreAnimation(` 调用点

- **main 分支：0 个调用点**（token 本身不在 main 上）。
- **epic/motion-foundations 分支：11 处**，分布在 `AsyncButton.swift`、`CoreBorderlessButtonStyle.swift`、`CheckBox.swift`、`FormField.swift`、`Radio.swift`、`Skeleton.swift`、`TagGroup.swift`、`SpinningModifier.swift` 及 token 文件自身——即该 epic 已把按钮按压/loading 动画迁到 `coreAnimation`，但尚未到 main。

（附带：`AsyncButton.swift` 在 main 上已存在，提供的 loading 能力已在 B.3 详述，此处不重复。）

---

## D. 加新组件要过的门

### D.1 `docs/component-registry.json` 结构

顶层两字段：`components`（数组，82 条）、`entryPoints`（数组，26 条）。

`components` 每条 schema（对应 `Tests/OhMyDesignTests/ComponentRegistryGuard.swift` 的 `Entry`）：`component, repo, kind, decidedBy, nativeProtocol, customStyleProtocol, styleSlot, styleEnum, needsExtensionPoint, textParams: [{name, category}], notes`。Timeline 条目见 A.7。

`entryPoints` 每条 schema：`target, host, member, notes`，示例：

```json
{"target": "OhMyDesignEffects", "host": "View", "member": "shake",
 "notes": "trigger 值变化时左右抖动，承载状态语义（如 PinCode 输错）；a11y 通告由调用方提供。..."}
```

### D.2 判据逐条核实（全部已 grep 确认真实存在于 `Tests/`）

**`ComponentRegistryGuard`**（`Tests/OhMyDesignTests/ComponentRegistryGuard.swift`）——多个测试的集合：
- `registrySchemaIsValid`：字段取值域校验（`validKinds = ["semantic","prescriptive","excluded"]`；`kind=="semantic"` 必须 `needsExtensionPoint==true`；`nativeProtocol`/`customStyleProtocol`/`styleSlot`/`styleEnum` 至多填一个非空）。
- `scannerFindsComponentTypes` / `registryCoversOhMyDesignTypes`：用 swift-syntax 解析三个 target 源码，采集所有 `public struct: View`（排除 `Layout`/`Shape`/`InsettableShape`，排除名字以 `Demo`/`Preview`/`PreviewHost` 结尾的类型），与登记表做**双向差集**——源码有登记表没有（`missing`）判红，登记表有源码没有（`ghosts`）也判红。**新增 `public struct Tree: View` 会被扫描器自动采到，必须同轮登记，否则判红。**
- `readmeIndexReconcilesWithRegistry` / `registryEntriesAreCoveredByReadme`：`docs/README.md` 组件索引表要与登记表互相覆盖。
- `readmeSnapshotsExist`：README 索引引用的 `docs/snapshots/*.png` 必须真实存在。

**`ComponentTextParamGuard`**（同文件）：`publicInitTextParamsAreClassified`——public init 的裸 `String`/`LocalizedStringKey`/`LocalizedStringResource` 参数必须在登记表 `textParams` 里有 A/B/C/`by-type` 分类；有固定计数断言（如 `registryTextParams == 33`），**新增文本参数必须同轮改这些数字**，否则判红。

**`ChromeTextLiteralGuard`**：只扫 `GuardScanRoots.newTargetRoots`（`OhMyDesignEffects` + `OhMyDesignCharts`，**不含主 target `OhMyDesign`**）。禁止在 `Text/Label/Button/Toggle/.../DatePicker` 等构造器或 `navigationTitle` 等 modifier 里写死带字母的裸字符串字面量（`isProse` 判据：含字母即算文案）。豁免通道：改成 init 参数（B 类）、走 `String(localized:bundle:)` 指向本 target 自己的 String Catalog、或用 `Text(verbatim:)`（会被清点打印但不算违规）。**Tree 若放进主 target `OhMyDesign` 不受此判据约束；若放进 Effects/Charts 才受约束。**

**`BoolExemptionGuard` + `BoolParameterScanner`**（`Tests/OhMyDesignTests/BoolExemptionGuard.swift` + `BoolParameterScanner.swift`）：
- 扫描器 `scanBoolParams` 用 swift-syntax 采集三个 target 所有 public `init`/函数/subscript/enum case 关联值 的 `Bool` 类型参数（含 `Bool?`；`inout Bool`/`@autoclosure () -> Bool` 归为 `boolCarrying` 单独清点，不算违规）。
- 豁免机制：`docs/bool-exemptions.json`，每条 schema 是 `{parameter: "Owner.decl#param", reason, decidedBy, decidedOn}`，`reason` 必须 ≥40 字符、必须含"删除"二字（要求先论证删不掉才能豁免）、不能含空话词（"TODO"/"历史遗留"等）。
- 棘轮：`docs/bool-exemptions-baseline.json` 的 `maxEntries`/`sourceSites`/`perTarget` 与豁免清单条目数**严格相等**（`<=` 也不行），新增豁免必须同轮抬高上限并写 `raisedBy/raisedOn/rationale`。
- **结论：新组件公开 API 一律不许有裸 `Bool` 参数**，路径是先用 enum/style 协议/modifier/环境值替代（`docs/component-contract.md` 第 3 节"配置开关的四条替代路径"），实在不行才走豁免（需论证 + 抬棘轮）。

**`ExtensionEntryPointGuard`**：管 `public extension View { func xxx() }` 这类扩展方法（不是类型），**只覆盖新 target**（`newTargetRoots`），登记在 `entryPoints`。Tree 若不提供 `View` 扩展方法（只是普通 `public struct Tree: View`），不受此判据约束。

**`ComponentExtensionPointGuard`**（`Tests/OhMyDesignTests/ComponentExtensionPointGuard.swift`）：`semanticComponentsHaveExtensionPoint`——对 `kind=="semantic"` 的组件，必须能在源码里证实四种扩展点之一：原生协议（`nativeProtocol`）、自有 style 协议（`customStyleProtocol`）、`styleSlot`、或 `styleEnum`（如 Timeline 的 `TimelineLayout`）。`result.inspected.count == 16` 是固定计数（含 Timeline），**Tree 若判定为 semantic，需新增扩展点并把这个数改成 17，否则判红**。

**`GuardScanRoots`**：`allRoots`（三个 target 全覆盖，供 `ComponentRegistryGuard`/`BoolExemptionGuard` 用）；`newTargetRoots`（仅 Effects+Charts，供 `ChromeTextLiteralGuard`/`ExtensionEntryPointGuard` 用）；`targetNames = ["OhMyDesign","OhMyDesignEffects","OhMyDesignCharts"]`。

### D.3 `docs/components/` 登记说明

没有单独的"如何登记新组件"模板文件。规范性文档是 `docs/component-contract.md`（1683+ 行），核心是判定法（步骤 1-3：Apple 原生协议？→ 换皮候选 ≥2 个？→ 视觉即含义即规定性）与"样式扩展点四选一"（A 原生协议 > B 自有协议 > D 配置枚举 > C 承认差异不开）。`docs/components/timeline.md` 是同类单文件文档的实例（见 A.6）。

### D.4 层级/递归组件先例——**仓库内没有任何既有实现**

**`InsetGroupedSection`**（`Sources/OhMyDesign/Components/InsetGroupedSection/InsetGroupedSection.swift`）：

```swift
public init(
    header: LocalizedStringKey? = nil,
    footer: LocalizedStringKey? = nil,
    dividerInset: SettingsDividerInset = .iconAligned,
    @ViewBuilder content: () -> Content
)
```

内部用 `Group(subviews: self.content) { rows in ... }` 遍历子视图插分隔线——**完全平坦，不支持嵌套/递归**，没有子分组概念。

**`CoreDisclosureGroupStyle`**（`Sources/OhMyDesign/Components/Style/CoreDisclosureGroupStyle.swift`）：只给系统 `DisclosureGroup` 换皮（chevron + 缩进），`makeBody` 没有针对嵌套场景的特殊处理；嵌套展开依赖 SwiftUI 原生 `DisclosureGroup` 自身组合能力（内容里再放一个 `DisclosureGroup` 即可），本仓代码没有为此写额外逻辑。

全仓 grep `OutlineGroup`：仅命中 `docs/components/core-control-styles.md`（**Sources 下零命中**，未逐字确认该文档提到 OutlineGroup 的上下文）。全仓 grep "recursive/递归"：无 Sources 命中。

**结论：Tree 组件会是本仓第一个处理层级数据的组件，没有可复用的既有模式。**

⚠️ **本行原写「`InsetGroupedSection` 和 `DisclosureGroup` 的 `.core` style 都只覆盖单层」，对后者为假**（PRD 首轮评审指出）：`CoreDisclosureGroupStyle` 只重排 `configuration.label` / `configuration.content`、「展开状态仍由系统驱动」，**不限制嵌套**。准确的缺口是「没有任何组件**接受层级数据结构**」——用 `DisclosureGroup` 表达树时，递归、缩进、展开态管理、选择、键盘全要调用方手写。
⚠️ 换皮的代价另记：该 style 自绘 `DisclosureChevron` 并自行 `withAnimation(.snappy)`，chevron 与展开动画都不是系统原生的；`docs/components/core-control-styles.md` 已登记「换皮后系统不再自动为这个自绘 `Button` 播报展开态」。

---

## 已知证据缺口（如实登记，未填平）

- A.6：`docs/components/timeline.md` 中 `applyGroupedStatusValue(_:item:)` 与源码实际的 `groupedStatusKey(for:)` 函数名不一致，成因未查。
- C.2：Toast swipe-to-dismiss 的回弹动画精确挂载点（`.animation(value: dragOffset)`）未在读到的片段中确认，具体位置没查到。
- C.2：`isPressing`/`isDragging` 两个 `@GestureState` 在 Toast 内的具体视觉消费点未深挖。
- D.3：`docs/components/timeline.md` 之外，未逐一确认所有组件是否都各有对应的 `docs/components/<slug>.md`（未做穷举）。
