# LiquidChrome

液态铬背景 / A liquid chrome background. 域扭曲后的坐标喂给正弦带，形成金属反射那种窄亮高光带 +
宽暗过渡。

源码：`Sources/OhMyDesignShaders/LiquidChrome.swift`（`OhMyDesignShaders` product）。

⚠️ 用原生 `swift build` 消费本 product 时须加 `--build-system swiftbuild`：原生构建不编译 `.metal`，shader 会静默失效。

## API

| 参数 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| tint | Color | `.dataAccent` | 调色基色，三档斜坡由它推导 |
| density | Density | `.regular` | 带的疏密 |
| motion | ShaderMotion | `.calm` | 运动速度档位 |

## Density

语义枚举：

- `wide`
- `regular`
- `fine`

## 动效与能耗

背景由 `ProceduralBackground` 承载（`Sources/OhMyDesignShaders/ShaderSupport.swift`），公共骨架规则：

- 运动速度由 `ShaderMotion` 四档（`still` / `calm` / `regular` / `lively`）控制时间缩放；`.still`
  时间缩放为 0。
- Reduce Motion 开启时冻结在某一帧，保留视觉、去掉运动，而不是停止渲染或换成静态图。
- 后台 / inactive 时暂停渲染并保留最后一帧，回前台时动画原点顺延暂停时长接着走，不从头重放。
- 低电量模式下降低刷新频率。

带边用 `fwidth` 做屏幕空间抗锯齿，避免高频带在缩放下出现摩尔纹。

## 无障碍

装饰层：`body` 链尾带 `.accessibilityHidden(true)`（FR-13）。

## 使用示例

```swift
LiquidChrome().ignoresSafeArea()

LiquidChrome(tint: .teal, density: .fine, motion: .regular)
```

## 来源 / Provenance

本件（`ohMyDesignLiquidChrome`）自身尚未指认到具体上游，裁定为「待追溯（低指纹）」，不作原创声称。
共享原语各有明确出处：`wangHash` 出自 Thomas Wang / Nathan Reed（CC-BY-4.0），`hash21`/`hash22`
的素数出自 Teschner et al. 2003，域扭曲结构属 Inigo Quilez（MIT）一族，`edgeWidth` 为无可归属上游的
通用惯用法。逐条见 `ACKNOWLEDGEMENTS.md`《`OhMyDesignShaders` 的共享原语与公开配方》表格，与
`docs/shader-provenance.md`《⚠️ 清偿条款：已落地件的 `待追溯` 怎么办（第 5 轮终审 C4）》下表 B 的
`LiquidChrome` 行。
