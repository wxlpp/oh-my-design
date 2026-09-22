# #407 计划：动效 token + Reduce Motion 纪律（含实测 spike）

契约：`.claude/prds/motion-foundations.md` FR-1 / FR-2 / FR-3。范围只在 `Sources/OhMyDesign`（Effects / Charts 不动行为；Effects 只改五处 `properties` 上的文档注释，按更正传播约定同步 `hasMotion` 的实测结论）。

## FR-1 spike 结论（先做，决定下面的写法）

环境：Xcode 26.4、iOS 26.4 模拟器（iPhone 17 Pro，专属设备）、macOS 26（本机）。
iOS 侧用 `xcrun simctl spawn <udid> defaults write com.apple.Accessibility ReduceMotionEnabled -bool true`
打开 RM 并重启模拟器；探针 app 屏上同时打印 `\.accessibilityReduceMotion` 与
`UIAccessibility.isReduceMotionEnabled`，两者都为 `true` 才采数。
取证方式：`simctl io recordVideo` 录屏 → `AVAssetImageGenerator` 按 20 fps 抽帧 → 逐帧按色相统计色块
的包围盒 / 像素数（探针脚本与原始 tsv 在 scratchpad，不入仓）。
macOS 侧没有改本机系统设置，只用 `.environment(\._accessibilityReduceMotion, true)` 注入。

| 项 | RM 关 | RM 开 | 结论 |
|---|---|---|---|
| 自定义 `Transition`，`properties.hasMotion == true`（位移 160 pt） | 左移 160 pt，`body` 收到 `.willAppear` / `.didDisappear` | **逐帧同样左移**；`body` 计数 `in:24,out:25`，与 `hasMotion == false` 的对照组逐项相同 | **未被替换成 `.opacity`** |
| 系统 `.move(edge:)` / `.scale(scale:)` | 位移 / 缩放 | **逐帧同样位移 / 缩放** | 未降级。三者的 `properties.hasMotion` 实测：move `true`、scale `true`、offset `true`、opacity `false` |
| 隐式 `.animation(_:value:)` 驱动同一组转场 | 同上 | 同上 | 与 `withAnimation` 无差别，未降级 |
| macOS，注入 RM，`hasMotion == true` 转场 | `body` 收到 in / out | `body` **仍**收到 in / out | 未替换 |
| `symbolEffect(.bounce, value:)` | 星形包围盒 154 → 192 px 再回落 | **同样 154 → 192 px** | **不自动降级** |
| `.contentTransition(.symbolEffect(.replace))`（square ↔ checkmark.square.fill） | 勾以描画方式出现 | **同样描画**（中间帧可见半截勾） | **不自动降级** |
| `.contentTransition(.numericText())` | 数字纵向滚动 + 模糊（字形包围盒纵向外扩约 20 px） | **同样滚动 + 模糊** | **不自动降级** |

⇒ **本仓所有 RM 降级都要自己做，框架一处都不替我们做。** 后续 FR 的写法全部按「显式分支」处理，
不存在「系统已降级、不重复包」的点。

`hasMotion` 那句话的出处（均为「按文档语义预期、未实测」口径）：
`docs/components/transition-cluster-3d-elastic.md`「两道闸」一节、`docs/components/particle-transition.md`
「两道闸」一节、`docs/components/mask-reveal-transitions.md`「两道闸」表（该处写成「真正生效的那道」）、
`docs/component-registry.json` 对应 transition 条目的 `notes`（particle / flip / rotate3D / swoosh / boing /
skid / wipe / blinds / clock / glare / dissolve 等），以及 blur / filmExposure / snapshot 三处
「`hasMotion` 必须是 `false`，否则框架会换成 opacity」。按更正传播约定三处落点（源码注释 / docs / registry）
一起改：结论改为「实测框架不替换，内层 RM 门控是生产路径上真正生效的那道」。

## FR-2 公开 API（`Sources/OhMyDesign/Tokens/CoreMotion.swift`）

```swift
public nonisolated enum CoreMotion: Sendable, CaseIterable {
    case press, selection, reveal, scroll
    public var duration: TimeInterval { get }
    public var animation: Animation { get }
    public func animation(for presentation: MotionPresentation) -> Animation?
}
public extension EnvironmentValues {
    var coreMotionPresentation: MotionPresentation { get }   // RM ⇒ .resting，否则 .animated
}
public extension View {
    func coreAnimation(_ motion: CoreMotion, value: some Equatable) -> some View
}
```

- 复用已有裁决类型 `MotionPresentation`（`EnergyPolicy.swift`），不新造 RM 枚举；无 Bool 入参。
- `.resting`：`press` / `selection` / `reveal` 退为同时长 `easeInOut`（淡变用）；`scroll` 退为 `nil`（直接跳到位）。
  `.hidden` 一律 `nil`。位移 / 缩放 / 旋转本身由调用点按 `coreMotionPresentation` 去掉。
- 取值：`press` = `.snappy(duration: 0.16)`（现有 4 处里 3 处已是它）；`selection` = `.snappy(duration: 0.22)`
  （`UnderlinedTabBar` 现值）；`reveal` = `.smooth(duration: 0.25)`（与 `ToastDefaults` 的 0.25 s 退场计时同源）；
  `scroll` = `.smooth(duration: 0.35)`（整页位移行程长，比 selection 慢一档）。`.bouncy` 有意不用。
- 名字冲突：类型名与 Apple 的 CoreMotion 框架同名。实测（scratch 包）同时 `import` 两者时
  `CoreMotion.press` 正常、`CMMotionManager()` 正常，但**模块限定写法** `CoreMotion.CMMotionManager`
  报 `type 'CoreMotion' has no member 'CMMotionManager'`。登记进 docs，并作为待决点上报。

## 迁移清单（核心库全部写死的动画参数）

| 文件:行 | 旧值 | 新 token | 行为差异 |
|---|---|---|---|
| `Modifier/ButtonBackgroundModifier.swift:24` | `.snappy(duration: 0.16)` | `press` | 无；RM 下不缩放，改变暗 0.7 |
| `Modifier/TelegramGlassButtonModifier.swift:41` | `.snappy(duration: 0.16)` | `press` | 无；RM 下不缩放，改变暗 0.7 |
| `Components/Button/styles/PressableButtonStyles.swift:55` | `.easeOut(duration: 0.15)` | `press` | 曲线 easeOut → snappy，0.15 → 0.16 s |
| `Components/Button/styles/CoreBorderlessButtonStyle.swift:16` | `.easeInOut`（默认时长） | `press` | 按压变色变快、曲线换成 snappy |
| `Components/Button/AsyncButton.swift:61` | `.snappy(duration: 0.16)` | `press` | 无 |
| `Components/SegmentedControl/SegmentedControl.swift:100` | `.easeInOut(duration: 0.18)` | `selection` | 0.18 easeInOut → 0.22 snappy；RM 下滑块不滑、原地淡变 |
| `Components/TabBar/UnderlinedTabBar.swift:37` | `.snappy(duration: 0.22)` | `selection` | 无；RM 下下划线不滑、原地淡变 |
| `Components/TabBar/UnderlinedTabBar.swift:50` | `.snappy(duration: 0.2)` | `scroll` | 0.2 snappy → 0.35 smooth；RM 下直接跳 |
| `Components/CheckBox/CheckBox.swift:41` | `.easeOut(duration: 0.25)` | `selection` | 0.25 easeOut → 0.22 snappy（#408 会重写该处） |
| `Components/Radio/Radio.swift:80` | `.easeOut(duration: 0.25)` | `selection` | 同上 |
| `Components/FormField/FormField.swift:104` | `.easeInOut(duration: 0.2)` | `reveal` | 0.2 easeInOut → 0.25 smooth |
| `Components/Style/CoreDisclosureGroupStyle.swift:31` | `.snappy`（默认时长） | `reveal` | 曲线换成 smooth 0.25；RM 下 chevron 不转、直接到位 |
| `Components/Carousel/Carousel.swift:81,100` | `withAnimation {}`（`.default`） | `scroll` | 曲线换成 smooth 0.35；RM 下点页点直接跳 |
| `Components/Toast/Toast.swift:112,375,376` | `easeInOut(0.25)` | `reveal` | 曲线 easeInOut → smooth（时长同）；RM 下滑入 / 滑出 / HUD 缩放改纯淡变 |
| `Components/Skeleton/Skeleton.swift:38` | `.default` | `reveal` | 曲线换成 smooth 0.25 |
| `Modifier/SpinningModifier.swift:64,75,92` | `.default` | `reveal` | 同上；RM 下 `.topBar` 顶条不扫动、静止居中 |

循环周期常量（`SkeletonShimmerMath.duration` 1.4 s、`TopBarIndicator.period` 1.1 s）不是过渡曲线，留在组件内；
二者都已在 RM 下不建 `TimelineView`。

## FR-3 判据（`Tests/OhMyDesignTests/CoreMotionDisciplineGuard.swift`）

1. **动画只经 `CoreMotion` 取**：核心库每个 `withAnimation(` / `.animation(` 的实参必须引用 `CoreMotion`
   （或是字面 `nil`）；无参 `withAnimation {` 判红；曲线构造字面量（`.snappy` / `.smooth` / `.bouncy` / `.spring` /
   `.easeIn…` / `.linear(` / `.interactiveSpring` / `Animation.default`）只许出现在 `Tokens/CoreMotion.swift`。
2. **含动效的文件必须登记 RM 策略（双向差集）**：台账 `[相对路径: 策略]`，策略三选一：
   `gated`（经 `\.coreMotionPresentation` 读 RM 并分支）、`fadeOnly`（只有透明度 / 颜色插值，不得出现任何位移 /
   缩放 / 旋转 / matchedGeometry / move / scale 转场）、`staticTransform`（有常量变换但不带任何动画触发）。
3. **RM 只有一个读取入口**：除 `Tokens/CoreMotion.swift` 外，核心库不得直接读 `\.accessibilityReduceMotion`。
4. 扫描器自证：合成输入逐条打红（未登记文件、无参 `withAnimation`、字面曲线、fadeOnly 里混进 `scaleEffect`、
   gated 文件不读入口）。

行为判据（每个 gated 点一条，优先渲染 / 纯函数，不靠 grep）：`PressFeedback.chrome` / `.card` 在 `.resting` 下
scale = 1、opacity = 0.7；Toast 转场种类 / 退场位移 / HUD 缩放在 `.resting` 下为淡变 / 0 / 1；Segmented /
UnderlinedTabBar 的滑动指示在 `.resting` 下关闭；Disclosure chevron 在 `.resting` 下旋转不补间；TopBar 在
`.resting` 下不扫动；`CoreMotion` 取值与 `animation(for:)` 映射；`EnvironmentValues.coreMotionPresentation`
随 `_accessibilityReduceMotion` 注入翻转；静息外观：按钮背景与 Telegram 对照原样拷贝的旧实现逐像素相等
（按下态缩放后 ±1 LSB 有界等价），Segmented / UnderlinedTabBar / Disclosure / Toast 断言 RM 开关下静息位图相同
（RM 关路径只换了几何 ID 的类型与曲线，未另拷旧实现）。

## 文档 / 登记落点

`docs/DESIGN-FOUNDATION.md` 新增「动效」节；`docs/components/{toast,segmented-control,underlined-tab-bar,
pressable-button-styles,button,spinning,carousel,core-control-styles,skeleton,form-field}.md` 按实际改动同步；
Effects 三份 transition 文档 + registry notes 更正 `hasMotion`；`scripts/design-digest.py` 新增 motion 节并按
实际值调 FLOORS；`docs/BREAKING-CHANGES.md` 新节 `未发布（相对 v0.11.0）——Issue #407`（`v0.11.0` 已发布，
派单写的 `v0.10.0` 已过时）；MainActor 豁免不增。

## 待决点

- 类型名 `CoreMotion` 与 Apple 框架同名（见上）。备选 `CoreMotionToken`；按派单先用 `CoreMotion`。

## 实现后取证（iOS 26.4 模拟器录屏，30 fps 抽帧，像素为 @3x）

| 动效 | RM 关 | RM 开 |
|---|---|---|
| Segmented 滑块 A → C（`.ink`） | 暗色块 x 起点逐帧 18 → 199 → 454 → 613 → 687 → 722，途经 B | x 起点只有 18 与 722 两个值，中间一帧两处同时半透明（原地交叉淡变） |
| 按压缩放（`TelegramGlassButtonModifier`） | 描边包围盒 47–399 → 58–388（缩放 0.94） | 包围盒恒为 47–399，只有暗像素数下降（变暗） |
| `.spinning(.topBar)` 顶条 | 暗条 x 逐帧右移 ≈ 42 px / 帧 | 暗条恒在 384–701（居中静止） |
| Toast 退场 / 入场 | 胶囊下沿 y 167 → 131 → 72 → 1（上滑出）、入场 101 → 167（下滑入） | 下沿恒为 166–167，只有像素数下降 / 回升（原地淡变） |

单测侧：`CoreMotionInFlightTests`（仅 macOS 腿——iOS 上 `layer.render(in:)` 拍不到进行中的帧）在托管窗口里
逐帧采样，Segmented / UnderlinedTabBar / Toast / Disclosure chevron 四处在 RM 开时「途经像素」为 0、RM 关时为正；
把 Segmented / UnderlinedTabBar 的几何 ID 改回固定串、或把 chevron 的补间改回无条件，对应判据当场判红。

⚠️ iOS 上 `SegmentedControl` 的默认 `.glass` 样式是原生 `UISegmentedControl`，本库的 RM 分支只作用于
`.plain` / `.ink` 这两条 SwiftUI 路径；原生控件的动效由 UIKit 自己处理。
