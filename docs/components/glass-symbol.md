# GlassSymbol

渲染成折射玻璃的 SF Symbol / An SF Symbol rendered as refractive glass.

源码：`Sources/OhMyDesignShaders/GlassSymbol.swift`、`Sources/OhMyDesignShaders/GlassSymbolStyle.swift`（`OhMyDesignShaders` product）。

符号先铺成由 `tint` 推导的渐变背衬，再施加 `View.refractiveGlass(...)` 的折射。Reduce Transparency
下经 `layerEffect` 的 `isEnabled` 关掉折射，退回实心渐变符号。

⚠️ 用原生 `swift build` 消费本 product 时须加 `--build-system swiftbuild`：原生构建不编译 `.metal`，
折射会静默失效。

## API

| 参数 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| systemName | String | - | SF Symbol 名 |
| tint | Color | `.accent` | 渐变背衬的基色 |
| strength | RefractiveGlassStrength | `.regular` | 折射强度 |
| accessibilityLabel | Text? | `nil` | 无障碍标签；`nil` 时当作纯装饰、移出无障碍树 |

## 外观扩展点：`GlassSymbolStyle`

形态对齐 `ButtonStyle` / `RatingStyle`：

| 符号 | 说明 |
|---|---|
| `protocol GlassSymbolStyle` | `makeBody(configuration:)` 返回最终外观 |
| `GlassSymbolStyleConfiguration.symbol` | 已施加渐变背衬、折射与 Reduce Transparency 降级的符号本体 |
| `GlassSymbolStyleConfiguration.tint` | 背衬基色，供附加层取色 |
| `PlainGlassSymbolStyle` | 默认实现：只渲染符号本体 |
| `View.glassSymbolStyle(_:)` | 为子树中的所有 `GlassSymbol` 设置外观 |

本包只发 `PlainGlassSymbolStyle`。等级标签、进度环这类成就徽章外观由调用方自写 style：

```swift
struct TierBadgeStyle: GlassSymbolStyle {
    let tier: LocalizedStringKey

    func makeBody(configuration: Configuration) -> some View {
        configuration.symbol
            .overlay(alignment: .bottom) {
                Text(self.tier)
                    .font(.caption2.bold())
                    .padding(.horizontal, CoreSpacing.xs)
                    .background(configuration.tint.opacity(0.85), in: Capsule())
                    .foregroundStyle(.white)
            }
    }
}

GlassSymbol("trophy.fill", accessibilityLabel: Text("金牌成就"))
    .glassSymbolStyle(TierBadgeStyle(tier: "x3"))
```

无障碍修饰（`accessibilityLabel` / `accessibilityHidden` / `.isImage` trait）留在 `GlassSymbol` 外层，
不经过 style：自定义 style 加的文字不会进无障碍树，语义由 `accessibilityLabel` 参数承担。

## `#368` 判定

公约步骤 2 的候选枚举与来源核验在 `#368` 补做，落**出口 1**（`decidedBy: step2` / `kind: semantic` /
`needsExtensionPoint: true`）：计入的非皮肤候选是「符号 + 分级 / 计分文本标签」（GitHub Achievements /
Xbox / PlayStation）与「符号 + 进度层」（Google Play Games / Apple Watch / Xbox）两族，均属三分法的**槽**差异。
候选加的位置今天什么都不画（D1 只认外观槽）、标签文本与进度值是开放数据（D2 封闭枚举装不下）⇒ 走形态 B。
候选、来源 URL 与逐字引文见 `docs/component-registry.json` 的 `GlassSymbol.notes`，
公约层面的留痕见 `docs/contract-defects.md` 的 `## #368` 节与 `docs/component-contract-revisions.md` 的 `R-50`。
