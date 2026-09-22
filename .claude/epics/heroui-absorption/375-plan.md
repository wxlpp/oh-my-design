# Issue #375 plan — StatusLevel.neutral

## 公开 API
- `public nonisolated enum StatusLevel: Sendable, Equatable` 新增 `case neutral`（仅加 case，不加其他一致性）。

## 消费者（`git grep` 全量：Sources / App / scripts / Tests；Effects、Charts target 无引用）
| 位置 | switch | neutral 取值 |
|---|---|---|
| `Components/Banner/Banner.swift` `bannerIcon(for:)` | 图标 | `text.bubble.fill` |
| `Components/Banner/Banner.swift` `bannerPalette(for:)` | 前景 / 背景 / 描边 | `contentPrimary` / `secondaryFill` / `borderDefault` |
| `Components/Toast/Toast.swift` `ToastView.icon` / `foregroundColor` | 图标 / 前景 | `text.bubble` / `contentPrimary` |
| `Components/Timeline/Timeline.swift` `nodeColor(for:)` | 圆点色 | `contentSecondary` |
| `Components/Timeline/Timeline.swift` `accessibilityLabelKey(for:)` | VoiceOver 文案键 | `"Neutral"`（登记进 `en.lproj/Localizable.strings`） |

全部取第 3 层系统语义色（content / fill / border），不取资源色。
为可测，`bannerIcon` / `bannerPalette` / `BannerPalette` 从 private 降为 internal；
`ToastView` 的 icon / 前景色抽成 internal `static func icon(for:)` / `foregroundColor(for:)`。

## 测试（Swift Testing，行为断言）
- `BannerTests`：neutral 调色板 == 上表 token；三者 `assetName == nil` 且明暗两档 `resolve` α > 0；neutral 图标与其他四档互异。
- `ToastHostTests`（或新 `ToastLevelVisualTests`）：neutral 前景 == `contentPrimary`、非资源色；图标互异。
- `TimelineTests`：`nodeColor(.neutral) == .contentSecondary` 且非资源色；`accessibilityLabelKey(.neutral) == "Neutral"`；`groupedStatusKey` 覆盖 neutral。
- `SharedFoundationTests.accessibilityLabelKeysResolve`：键表加 `"Neutral"`。

## 文档 / 登记
- `docs/components/{banner,toast,timeline}.md` 补 neutral。
- `docs/BREAKING-CHANGES.md` 未发布区新增一节：下游对 `StatusLevel` 的 exhaustive switch 源码破坏，迁移为补 `.neutral` 分支或 `@unknown default`/`default`。
- 预览：`Banner.swift` / `Toast.swift` / `Timeline.swift` `#Preview` 与 `App/Sources/{ComponentData,Previews}.swift` 加 neutral 示例。
- `docs/component-registry.json`：无新组件，不改条目（除非 notes 里列举四档需同步）。
- downstream-probe：只构造 / 比较、无 exhaustive switch，预期不需改；构建验证。
