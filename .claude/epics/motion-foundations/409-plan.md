# #409 计划：TagGroup / TagInput 增删与选中动画（修 offset 身份）

契约：`.claude/prds/motion-foundations.md` FR-5。依赖 `#407` 的 `CoreMotionToken` 与
`CoreMotionTokenDisciplineGuard`（台账式纪律）。范围限于 `Sources/OhMyDesign/Components/{Tag,TagGroup,TagInput}`
与 `Tokens/CoreMotionToken.swift`（新增一个 internal 的集合项转场入口）。

## 前提：`#407` 的结论直接约束本任务

`407-plan.md` 的 spike 表逐项实测「框架一处都不替我们降级」——含 `.move(edge:)` / `.scale(scale:)`
与自定义 `hasMotion == true` 转场。⇒ 本任务的插入 / 移除转场**必须自己按呈现裁决分支**，
不能写一个带位移 / 缩放的转场然后指望 Reduce Motion 下系统替换成 `.opacity`。

## 1. 身份修正（先做，独立于动画）

`TagInput.swift:38` 现为 `ForEach(Array(self.tags.enumerated()), id: \.offset)`。`tags` 是
`[String]`、`allowDuplicates: true` 时允许重复，所以不能直接用 `id: \.self`。

**定案：「值 + 该值的出现序号」组合身份**（internal 类型，公开 API 不变）：

```swift
struct TagInputChip: Identifiable, Hashable {
    struct ID: Hashable { let value: String; let occurrence: Int }
    let value: String
    let occurrence: Int
    let index: Int
    var id: ID { ID(value: self.value, occurrence: self.occurrence) }
}

extension TagInput {
    static func chips(for tags: [String]) -> [TagInputChip]
}
```

- 唯一标签（默认 `allowDuplicates: false`）⇒ 身份**完全稳定**，删中间项不影响任何存活项。
- 重复标签 ⇒ 只有**同值的后续出现**会在前一个同值项被删时降序号；不同值的项不受影响。
  这一格的限制写进 `docs/components/tag-input.md` 与 `BREAKING-CHANGES`（不是「没有限制」，
  而是「限制从『删任何中间项都错位』收窄到『删重复项时该值的后续出现换身份』」）。
- 删除仍按 `index`（`removingTag(at:from:)` 原样保留，`#400` 的两条重复项判据不动）。

## 2. 动画落点

| 变化 | token | 取法 | Reduce Motion |
|---|---|---|---|
| TagInput chip 增删 | `reveal` | `transformAnimation(for:)` | `nil` ⇒ 直接出现 / 消失，零位移 |
| TagGroup 标签增删 | `reveal` | `transformAnimation(for:)` | 同上 |
| TagGroup 选中态切换 | `selection` | `.coreAnimation(.selection, value:)` | 同时长 `easeInOut` 纯色插值（包围盒不变，无需去掉变换） |

增删用 `transformAnimation(for:)`（`.animated` ⇒ 曲线，否则 `nil`）而不是 `animation(for:)`：
增删必然带来 `FlowLayout` 重排，重排是**位移**；给 resting 一条 `easeInOut` 只会把位移变慢，
不会消掉它。`nil` 是唯一能让 RM 下零位移的取法，也是派单允许的「直接出现 / 消失」。

选中态切换只改底色与描边色（尺寸、包围盒都不变）⇒ 纯色插值在 RM 下是合规降级，用 `animation(for:)`。

转场值本身放 `Tokens/CoreMotionToken.swift`（台账策略 `.tokenSource`，曲线 / 变换常量的法定住处）：

```swift
extension MotionPresentation {
    nonisolated var collectionItemTransition: AnyTransition   // animated: .scale + .opacity；resting: .opacity
}
```

internal，不动 digest / MainActor 棘轮的公开面。

## 3. `Tag` 选中外观改为单分支（为了可插值）

`Tag.chrome` 现在是 `if let selectionChrome { fill + overlay(stroke) } else { fill }` 两个分支——
两棵不同的子树之间没有可插值的量，选中切换只能突变。改成单分支：

```swift
let fill = self.selectionChrome?.fill ?? self.color.opacity(Self.backgroundOpacity)
let stroke = self.selectionChrome?.stroke ?? .clear
shape.fill(fill).overlay(shape.strokeBorder(stroke, lineWidth: CoreBorderWidth.thick))
```

未选态多出一圈 `Color.clear` 描边（不画任何像素）⇒ 静态外观须**逐像素**对照旧实现，
判据见下（`LegacyTag`）。

## 4. 守卫台账

`CoreMotionTokenDisciplineGuard.ledger` 新增两条，都是 `.gated`（两个文件都真读
`\.coreMotionPresentation` 并据此分支）：

- `Components/TagInput/TagInput.swift: .gated`
- `Components/TagGroup/TagGroup.swift: .gated`

`transformLedger`：不新增——`.scale(scale:)` / `.opacity` 作为转场的 callee 名不在
`MotionSiteCollector.transformCallees` 里，本任务不引入 `offset(` / `scaleEffect(` /
`matchedGeometryEffect(` 调用点。（会实跑判据确认，不靠推断。）

`Tag.swift` 不进台账：改后仍无任何动画触发与变换调用。

## 5. 测试清单（`Tests/OhMyDesignTests/`）

**身份（真值表，macOS + iOS 双腿）** — `TagInputTests` 追加：
1. `chips(for:)` 对唯一标签给出逐项互异身份；
2. 重复标签得到 `(值, 序号)` 互异身份；
3. **删中间项：存活项身份逐项不变**（旧 offset 身份会让其后每一项换身份——把实现改回
   `enumerated().offset` 当场判红）；
4. 删重复项：只有同值后续出现降序号，异值项不变（如实钉住限制，不假装没有）；
5. `index` 与 `removingTag(at:from:)` 对齐：按身份找回的下标删掉的就是那一项。

**「不许改回 offset 身份」的兜底** — 新增一条源码判据（清单式、自证合成输入）：
`TagInput.swift` 不得出现 `enumerated()` / `id: \.offset`。真值表证明**函数**对，
这条证明**视图真的在用它**——两者缺一都留洞。

**静态外观逐像素（macOS + iOS 双腿）** — 新增 `LegacyTagRendering.swift`（`Tag` 改动前原样拷贝）：
6. `Tag` 未选 / 选中 × light / dark × 五档 `controlSize` × `removable` 开关，与 `LegacyTag` 逐像素相等
   （`expectBitmapsEqual`；同一棵树同一份输入，不放容差）；
7. `TagInput` 与 `LegacyTagInput`（改 `Tag` 后需改用 `LegacyTag`）静息态逐像素相等；
8. `#400` 的 invalid 下划线、`#378` 的五档尺寸、`#380` 的选中不变量判据一条不改、全绿。

**动效配置（真值表，双腿）**：
9. `MotionPresentation.collectionItemTransition` 在 `.animated` / `.resting` 下取值不同，
   且 `.resting` 一侧的 `properties.hasMotion == false`（`.animated` 一侧为 `true`）
   —— 这是转场「带不带位移」的唯一可判据量；
10. 增删动画在 `.resting` 下恒为 `nil`、`.animated` 下为 `CoreMotionToken.reveal.animation`；
11. 选中动画在两种呈现下都非 `nil`（纯色插值不必关掉）。

**动画进行中（仅 macOS 腿，`CoreMotionTokenInFlightTests` 同款托管窗口 + `.enabled(if:)` / 打印原因）**：
12. TagInput 删中间 chip：RM 关时存在「既不等于起点也不等于终点」的中间帧；RM 开时**每一帧**
    都等于起点或终点（`nil` 动画 ⇒ 无中间态）。对照组观测不到运动时按 `#407` 的
    `observeControlMotion` 约定记 inconclusive，不放行。
13. TagGroup 选中切换：两种呈现下都有中间帧（色插值），且**墨迹包围盒逐帧不变**
    （证明选中动画不含几何变化，所以 RM 下不需要关掉）。

## 6. FlowLayout 重排

不改 `FlowLayout`。增删时存活项的位置由 `placeSubviews` 的新解与外层动画共同决定——
是否平滑、移除中的 chip 在转场期间是否仍占位，**以实测为准**：在托管窗口里逐帧量存活项的
x 起点，写进 `docs/components/tag-input.md` 与报告。做不到平滑就写明现象与限制，不改布局器。

## 7. 文档 / 登记落点

- `docs/components/tag-input.md`：改写「chip 迭代」一节（现文写的是 `id: \.offset` 的理由，
  已被本任务推翻）+ 新增「增删动效」与重复标签限制；
- `docs/components/tag-group.md`：新增「动效」节（选中切换 / 增删 / RM 降级）；
- `docs/components/tag.md`：选中外观改单分支的说明；
- `docs/component-registry.json`：`TagInput` / `TagGroup` / `Tag` 三条 `notes` 各追加一句
  （更正传播三落点之一，`ComponentRegistryGuard` 只查长度，真伪靠人工评审）；
- `docs/BREAKING-CHANGES.md`：新节 `## 未发布（相对 v0.11.0）——Issue #409：…`；
- `App/Sources/ComponentData.swift`：`tag-input` / `tag-group` 画廊加「增删」演示按钮
  （截图要能拍到删中间项）；
- `scripts/design-digest.py`：本任务不新增公开 token / 组件 / 枚举 / viewext ⇒ FLOORS 预期不变，
  实跑确认（若有变化按实际值改并在报告写明依据）。

## 8. 验证

`rtk proxy swift build` / `rtk proxy swift test`；`swift build --build-tests && bash scripts/mainactor-static-ratchet.sh`；
`cd scripts/downstream-probe && swift build`；iOS `xcodebuild test -scheme OhMyDesign-Package`
（带 `CODE_SIGNING_ALLOWED=NO -IDEPackageEnablePrebuilts=NO`，读 `.xcresult` 顶层计数）；
预览宿主构建；截图 light / dark（TagInput 增删含删中间项、TagGroup 选中切换、五档尺寸）。
每条新判据给出变异结果（先确认变异真的落盘，再跑判据）。

## 实现后的偏离（与上面计划不同的三处）

1. **`Tag` 一字未动**（计划第 3 节作废）。计划里「两个 chrome 子树之间没有可插值的量，选中切换只能突变」
   **实测为假**：把 `chrome` 改回 `if let` 两分支后，`TagMotionInFlightTests.tagGroupSelectionInterpolatesWithoutGeometryChange`
   在 `.animated` 与 `.resting` 下**照样**拍到中间帧（SwiftUI 对分支切换做交叉淡变）⇒ 改写的理由不成立。
   ⇒ 撤回改写，`LegacyChromeTag`（为逐像素对照写的旧实现拷贝）连同 `FieldValidationControlsTests`
   里那一处引用一起删掉——参照与被测同源时那种「相等」是同义反复。
2. **静态外观判据换了形态**。既然 `Tag` 没动，逐像素对照的对象改成「同一棵树、三种呈现裁决」：
   `TagStaticAppearanceTests` 钉住五档 `controlSize` × 选中与否 × light / dark 下
   `.animated` / `.resting` / `.hidden` 的静息位图相同。TagInput 与旧实现的逐像素对照由既有的
   `FieldValidationControlsAppearanceTests.validMatchesLegacyPixels(.tagInput)`（对照 `LegacyTagInput`，
   下标身份、无转场、无动画）承担，TagGroup 由既有的 `unselectedTextMatchesPlainTag` /
   `selectedTextMatchesDerivedReference` 承担。
   ⚠️ 容差不是 `expectBitmapsEqual`：实测同一份输入在同一进程里连渲多张时，**前几张**与稳定输出差
   1 个 LSB（`mini` 档 TagInput 197120 B 帧上 4 / 19 字节），而 `render3` 与另两种裁决的图逐字节相同
   ⇒ 噪声来自渲染次序。取 Δ ≤ 1、差异 ≤ 0.2%（`TagGroupTests` 同款），是实测噪声的 20 倍。
3. **转场做成具体 `Transition` 类型**（计划写的是 `AnyTransition`）。`AnyTransition` 没有可内省的量，
   truth table 无处落脚；`CollectionItemTransition` 把缩放 / 透明度抠成两个纯函数，逐相位可判。
   代价：它是核心库第一个自有 `Transition`，顶到了 `#292` 的 `TransitionPropertiesGuard`
   ——该判据原先只在 `Tests/OhMyDesignEffectsTests/` 里找运行时 `hasMotion` 断言，而本类型是 internal、
   那个 target 看不见它。⇒ 把该判据的 `runtimeExpectationRoots` 扩成两个测试根（严格超集，
   原有 `>= 12` 的下界照旧成立），并按它的要求做三件事：登记 `roster`、写运行时断言、
   在 `docs/DESIGN-FOUNDATION.md` 裁定 `hasMotion` 取值与内层门控的先后关系。
