# #408 计划：原生符号 / 数字动效接入小件

契约：`.claude/prds/motion-foundations.md` FR-4。范围只在 `Sources/OhMyDesign`
（`Modifier/AnchoredBadgeModifier.swift`、`Components/CheckBox/CheckBox.swift`、
`Components/Radio/Radio.swift`，加 `Tokens/CoreMotionToken.swift` 的内容过渡入口）。

依赖 #407 的结论：**框架在 Reduce Motion 下不替我们降级任何一个点**——`symbolEffect(.replace)`
照常描画、`.contentTransition(.numericText())` 照常纵向滚动（#407 spike 逐帧实测）。⇒ 本任务三处
全部显式分支。

## 设计

### 内容过渡入口（`Tokens/CoreMotionToken.swift` 新增一节）

```swift
extension MotionPresentation {
    nonisolated var symbolReplacement: ContentTransition            // animated ⇒ .symbolEffect(.replace)，否则 .identity
    nonisolated func numericRoll(to value: Int) -> ContentTransition
        // animated ⇒ .numericText(value: Double(value))，否则 .identity
}
```

⚠️ **本节原写 `numericRoll(from previous: Int, to next: Int)` + `.numericText(countsDown:)`，已作废**
（PRD FR-4 于 main 的 `8d1e534` 按 #408 实测改口径）：`countsDown:` 要求方向在数字变化的**同一次事务**里
给出，而 `onChange` 晚一拍 ⇒ 必须在 modifier 里镜像一层显示值。镜像的代价是计数晚一帧落地，
而且镜像的状态变化不在动画触发集里、滚动动画整个不播（实测）。现在方向交给框架，本库只担保
「喂进去的就是当前计数」。

- 都是 internal，不扩公开表面 ⇒ 不动 registry / digest / MainActor 豁免。
- 无 Bool 入参。
- 放在 token 文件里，与 `slidingIndicatorID` / `transformAnimation` 同一节形态：
  「RM 裁决 → 具体降级取值」只在这一个文件里写。

### `anchoredBadge`

1. **计数滚动**：`.contentTransition(.numericText(value:))` 施于计数胶囊的 `Text`，喂当前计数、方向由框架判。
   计数与文字同出于 `case .count` 的那一次绑定，**没有镜像、没有晚一帧**。
   驱动动画的是**贴在胶囊上**的 `.animation(CoreMotionToken.reveal.transformAnimation(for:), value: count)`
   （RM 下为 `nil`）。
2. **出现 / 消失**：`.transition(...)`，`animated` ⇒ `.scale + .opacity`（iOS 角标惯例），
   `resting` ⇒ `.opacity`。种类经纯函数 `appearanceKind(motion:)` 取（`AnchoredBadgeTransitionKind`
   枚举，形态照 `ToastOverlay.transitionKind` 的先例，因为 `AnyTransition` 不是 `Equatable`、断不了）。
   由 `.coreAnimation(.reveal, value: content.isVisible)` 驱动。
   ⚠️ **两处驱动必须分开、且计数那一处必须贴在胶囊上**（两次实测得到的定案，别再并回去）：
   并成一个 `.coreAnimation(.reveal, value: content)` 时，RM 下胶囊宽度会随位数变化被插值
   （横向位移，端点包络外像素实测 17–28）；把计数那一处提到外层时，它的 `nil` 会压掉出现 / 消失的淡变
   （RM 下退场实测一帧都不播）。
3. `.dot` / `.text` 不加内容过渡（红点无数字；文案是调用方 `LocalizedStringKey`，滚动读不出方向）。

### `CheckBox`

两张 `Image` 的 `if / else` 合成**一张** `Image(systemName: isOn ? "checkmark.square.fill" : "square")`
+ `.contentTransition(motionPresentation.symbolReplacement)`。取色沿用
`appearance.indicatorColor(normal: isOn ? .contentPrimary : .contentSecondary)`——与旧实现逐分支同值。
不加 `.bounce`：#407 已定案「有意不提供 `.bouncy` 档」，弹跳与墨色 accent 的安静观感冲突。

### `RadioGroup`

`indicator(selected:appearance:)` 现有的 `if selected && appearance == .invalid` 分支会**断掉视图身份**，
`.symbolEffect(.replace)` 在跨分支时播不出来 ⇒ 合成一张始终 `.palette` 的 `Image`，两层色经纯函数取：

```swift
static func indicatorStyles(selected: Bool, appearance: FieldAppearance) -> (dot: Color, ring: Color)
```

| 状态 | dot | ring | 与旧实现 |
|---|---|---|---|
| 选中 + invalid | `contentPrimary` | `statusDangerForeground` | `.palette(contentPrimary, danger)`，同值（#374） |
| 选中 + 其他 | `contentPrimary` | `contentPrimary` | 旧为单色 `contentPrimary` |
| 未选中 | `indicatorColor(normal: contentSecondary)` | 同 dot | 旧为单色同值 |

⚠️ **前置实测**：「`.palette` + 两层同色」是否与单色渲染逐像素相同，用既有的
`FieldControlFollowUpTests.choiceControlsEnabledUnchanged`（`expectBitmapsEqual`，精确相等）验。
**不相同就退回**：保留 `if selected && invalid` 分支、两个分支各挂 `.contentTransition`，并如实登记
「invalid 下切换选中时符号替换播不出来」这一缺口。

## 判据

`CoreMotionTokenDisciplineGuard` 台账：

- `ledger`：`CheckBox.swift` / `Radio.swift` 由 `fadeOnly` 改 `gated`（`contentTransition(` 在
  `transformCalls` 里，fadeOnly 会判红；两文件都要读 `\.coreMotionPresentation`）；
  新增 `Modifier/AnchoredBadgeModifier.swift: .gated`。
- **收紧 `MotionSiteCollector.transformCallees`**：加 `contentTransition` / `symbolEffect`。
  现状这两个 callee 只被文件级的 `fadeOnly` 禁令看着，登记为 `gated` 的文件里**再加一个没门控的**
  `.contentTransition(.numericText())` 不会判红。加进去之后每个点都要在 `transformLedger` 里
  写明门控理由（三条新条目）。

新测试 `Tests/OhMyDesignTests/SymbolNumericMotionTests.swift`：

1. 真值表：`symbolReplacement` / `numericRoll(to:)` 在三种 `MotionPresentation` 下的取值；
   先断言 `ContentTransition.numericText(value: 9) != .numericText(value: 10)`
   ——否则「喂进去的就是当前计数」是恒真的（`ContentTransition` 的 `Equatable` 是 SDK 实现，不预设）。
2. 真实 modifier 上的计数序列（`AnchoredBadgeSequenceTests`，两条腿）：进位 / 递减 / 跨截断 / 退场 /
   退场后再出现 / 出现，各在 RM 开与关下跑，比**整数几何描述子**（胶囊底色的宽高与像素数）
   ——位图逐字节比在这套 harness 的分辨率下噪声与信号同量级（数字错一位只差 104 / 64000 字节，
   而滚动过的文字光栅化残差 54–119 字节）。⚠️ **原计划里的 `nextRoll` 状态机判据随镜像一并删除**。
3. `AnchoredBadgeModifier.appearanceKind(motion:)` 三档。
4. `RadioGroup.indicatorStyles` 四种组合（钉住 #374 的取色）。
5. 静态外观：
   - CheckBox / Radio 由既有 `FieldControlFollowUpTests.choiceControlsEnabledUnchanged`（精确相等）
     与 `FieldValidationControlsAppearanceTests` 的三条（含 disabled 整体 0.4，#400）兜住，不另写；
   - `anchoredBadge` 新增 `LegacyAnchoredBadgeModifier`（改动前原样拷贝）进
     `Tests/OhMyDesignTests/LegacyMotionRendering.swift`，对 dot / count / count 截断 / text ×
     rectangle / circle × light / dark 逐像素对照。
6. 进行中的帧（macOS 腿，`CoreMotionTokenInFlightTests` 的 `outsideEndpoints` / 端点包络手法）：
   - 徽标计数 8→9（同宽）/ 10→9 / 9→10：RM 关时有帧落在端点包络外，RM 开时为 0。
     ⚠️ **99→100 不进这一组**：文字变成 `99+` 后不是纯数字，实测滚不起来（对照组观测不到运动）。
   - 徽标出现（0→3）与退场（5→0）：量「与徽标不显示那一帧相比有变化」的像素跨度（与 alpha 无关，
     只与几何有关），RM 关时先窄后宽 / 先宽后窄，RM 开时全程满宽只淡入淡出。
   - ⚠️ **空采样必须是失败哨兵**：观测量走 `scaleShortfall` / `rollPeak`，它们在「一帧都没采到画出来的帧」
     时返回 `-1`；直接拿 `fullWidth - minWidth` 会让空采样比真实缩放还大、对照组从此恒绿。
     合成输入自证（`emptySamplingCannotPass`）逐条钉住这一点。
   - CheckBox 勾选切换：三种度量实测都分不开（见测试文件的类型注释），**如实记缺口**、只留真值表。
   - iOS 腿不跑进行中的帧（`layer.render(in:)` 取模型层）；终态与序列两条腿都跑。

每条新判据都做变异并在报告里列结果（至少：`symbolReplacement` 恒返回 `.identity`、
`numericRoll` 丢掉计数 / 不看 RM、把镜像加回来、`indicatorStyles` 把 ring 写成 dot、
台账条目删掉、`transformCallees` 回退、空采样哨兵被拆掉）。

## 文档 / 登记落点

- `docs/components/anchored-badge.md`：新增「动效」节（计数滚动方向、出现 / 消失转场、RM 降级）。
- `docs/components/radio.md`：`视觉 Token（与 CheckBox 成对）`一节的「选中态：`largecircle.fill.circle`」
  **已失真**（源码是 `circle.inset.filled`），连同「只有两张图的交叉淡变」一起改；补符号替换与 RM。
- `docs/DESIGN-FOUNDATION.md`「动效」节的 RM 降级表补三行。
- `docs/BREAKING-CHANGES.md` 最上面新节 `## 未发布（相对 \`v0.11.0\`）——Issue #408：…`（行为变更，无签名破坏）。
- 预览宿主：`AnchoredBadgePreview` 加一行可交互计数（±1 / 置 9 / 置 99），`RadioGroupPreview` 加
  CheckBox 与禁用态，供截图。
- registry / digest / bool 豁免 / MainActor 豁免：**无新增公开符号 ⇒ 不动**（报告里给出核对命令）。

## 待定案 —— 实现后的结论

- `.palette` 两层同色**与单色不等价**：`circle.inset.filled` 差 1 LSB / 171 px，
  `checkmark.square.fill` 逐通道差到 191（勾被同色实心层吃掉）⇒ Radio 保留 `invalid + 选中` 那条
  `.palette` 分支，代价是该组合下切换选中时符号替换播不出来（已登记）。
- RM 开时 CheckBox / Radio 的取色**仍在插值**，进行中判据钉不到「0 帧出界」⇒ 符号替换只留真值表，
  缺口写在测试文件的类型注释里。
