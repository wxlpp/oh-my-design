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
    nonisolated func numericRoll(from previous: Int, to next: Int) -> ContentTransition
        // animated ⇒ .numericText(countsDown: next < previous)，否则 .identity
}
```

- 都是 internal，不扩公开表面 ⇒ 不动 registry / digest / MainActor 豁免。
- 方向由「新旧值」算出，不收 Bool 入参（`numericRoll(from:to:)` 而非 `countsDown:`）。
- 放在 token 文件里，与 `slidingIndicatorID` / `transformAnimation` 同一节形态：
  「RM 裁决 → 具体降级取值」只在这一个文件里写。

### `anchoredBadge`

1. **计数滚动**：`.contentTransition(...)` 施于计数胶囊的 `Text`。方向要在**数字变化那一次事务里**
   就已经正确，而 `onChange` 比 body 晚一拍 ⇒ 镜像一层显示值：

   ```swift
   struct BadgeCountRoll: Equatable, Sendable { let previous: Int; let value: Int }
   static func nextRoll(_ current: BadgeCountRoll?, value: Int?, isVisible: Bool) -> BadgeCountRoll?
   ```

   - `value == nil`（非 `.count`）或 `!isVisible` ⇒ `nil`（不显示时清空，避免「隐藏后再出现」闪一帧旧数字）
   - `current == nil` ⇒ `(value, value)`（首次出现，无方向）
   - 否则 ⇒ `(current.value, value)`

   body 里显示 `roll?.value ?? 实际值`；`onChange(of: countValue, initial: true)` 推进 `roll`；
   `.coreAnimation(.reveal, value: roll)` 驱动。9→10 与 10→9 在同一次事务里拿到正确方向。
2. **出现 / 消失**：`.transition(...)`，`animated` ⇒ `.scale + .opacity`（iOS 角标惯例），
   `resting` ⇒ `.opacity`。种类经纯函数 `appearanceKind(motion:)` 取（`AnchoredBadgeTransitionKind`
   枚举，形态照 `ToastOverlay.transitionKind` 的先例，因为 `AnyTransition` 不是 `Equatable`、断不了）。
   由 `.coreAnimation(.reveal, value: content.isVisible)` 驱动。
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

1. 真值表：`symbolReplacement` / `numericRoll(from:to:)` 在三种 `MotionPresentation` 下的取值；
   先断言 `ContentTransition.numericText(countsDown: true) != .numericText(countsDown: false)`
   ——否则方向断言是恒真的（`ContentTransition` 的 `Equatable` 是 SDK 实现，不预设）。
2. `AnchoredBadgeModifier.nextRoll` 逐条：9→10 向上、10→9 向下、隐藏清空、再出现无方向、非 `.count` 为 `nil`。
3. `AnchoredBadgeModifier.appearanceKind(motion:)` 三档。
4. `RadioGroup.indicatorStyles` 四种组合（钉住 #374 的取色）。
5. 静态外观：
   - CheckBox / Radio 由既有 `FieldControlFollowUpTests.choiceControlsEnabledUnchanged`（精确相等）
     与 `FieldValidationControlsAppearanceTests` 的三条（含 disabled 整体 0.4，#400）兜住，不另写；
   - `anchoredBadge` 新增 `LegacyAnchoredBadgeModifier`（改动前原样拷贝）进
     `Tests/OhMyDesignTests/LegacyMotionRendering.swift`，对 dot / count / count 截断 / text ×
     rectangle / circle × light / dark 逐像素对照。
6. 进行中的帧（macOS 腿，`CoreMotionTokenInFlightTests` 的 `outsideEndpoints` / 端点包络手法）：
   - 徽标计数 8→9（**同宽**，排除胶囊宽度插值这个混淆量）：RM 关时有帧落在端点包络外，RM 开时为 0；
   - CheckBox 勾选切换：同上。**RM 开时若因取色插值而非零**，改用「帧是否落在逐像素包络外」判别
     （纯交叉淡变恒在包络内，`.replace` 的描画会出界）；两者都判不出来就**如实记缺口**、
     只留真值表，并按 #407 的约定 `.enabled(if:)` + 打印原因。
   - iOS 腿不跑（`layer.render(in:)` 取模型层，拍不到进行中的帧）。

每条新判据都做变异并在报告里列结果（至少：`symbolReplacement` 恒返回 `.identity`、
`numericRoll` 恒 `countsDown: false`、`nextRoll` 不清空隐藏态、`indicatorStyles` 把 ring 写成 dot、
台账条目删掉、`transformCallees` 回退）。

## 文档 / 登记落点

- `docs/components/anchored-badge.md`：新增「动效」节（计数滚动方向、出现 / 消失转场、RM 降级）。
- `docs/components/radio.md`：`视觉 Token（与 CheckBox 成对）`一节的「选中态：`largecircle.fill.circle`」
  **已失真**（源码是 `circle.inset.filled`），连同「只有两张图的交叉淡变」一起改；补符号替换与 RM。
- `docs/DESIGN-FOUNDATION.md`「动效」节的 RM 降级表补三行。
- `docs/BREAKING-CHANGES.md` 最上面新节 `## 未发布（相对 \`v0.11.0\`）——Issue #408：…`（行为变更，无签名破坏）。
- 预览宿主：`AnchoredBadgePreview` 加一行可交互计数（±1 / 置 9 / 置 99），`RadioGroupPreview` 加
  CheckBox 与禁用态，供截图。
- registry / digest / bool 豁免 / MainActor 豁免：**无新增公开符号 ⇒ 不动**（报告里给出核对命令）。

## 待定案（实现中若成立会在报告里单列）

- `.palette` 两层同色是否与单色逐像素相同（见上，含退路）。
- RM 开时 CheckBox / Radio 的取色是否仍插值（决定进行中判据能不能钉到「0 帧出界」）。
