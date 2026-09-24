# StarNest

体积分形星云 / A volumetric fractal star nebula：一路穿行的星尘与暗物质。

源码：`Sources/OhMyDesignShaders/StarNest.swift`（`OhMyDesignShaders` product）。

⚠️ 用原生 `swift build` 消费本 product 时须加 `--build-system swiftbuild`：原生构建不编译 `.metal`，shader 会静默失效。

## API

| 参数 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| tint | Color | `.dataAccent` | 调色基色，三档斜坡由它推导 |
| depth | Depth | `.regular` | 体积深度，同时决定渲染成本 |
| motion | ShaderMotion | `.regular` | 运动速度档位 |

## Depth

语义枚举，同时决定渲染成本：

- `shallow`
- `regular`
- `deep`（成本随全屏像素 × 体积步数 × 迭代数线性增长，`.deep` 即上游的 20 × 17）

浅色外观下是浅底深星；要深色星空，在该区域写 `.environment(\.colorScheme, .dark)`（本件不替调用方
翻转外观）。

## 动效与能耗

背景由 `ProceduralBackground` 承载（`Sources/OhMyDesignShaders/ShaderSupport.swift`），公共骨架规则：

- 运动速度由 `ShaderMotion` 四档（`still` / `calm` / `regular` / `lively`）控制时间缩放；`.still`
  时间缩放为 0。
- Reduce Motion 开启时冻结在某一帧，保留视觉、去掉运动，而不是停止渲染或换成静态图。
- 后台 / inactive 时暂停渲染并保留最后一帧，回前台时动画原点顺延暂停时长接着走，不从头重放。
- 低电量模式下降低刷新频率。

## 无障碍

装饰层：`body` 链尾带 `.accessibilityHidden(true)`（FR-13）。

## 使用示例

```swift
StarNest().ignoresSafeArea()
    .environment(\.colorScheme, .dark)

StarNest(tint: .teal, depth: .deep, motion: .lively)
```

## 来源 / Provenance

移植自「Star Nest」by Pablo Roman Andrioli（Kali），Shadertoy `XlfGRj`，作者在源码头声明 MIT；
修改逐项写在 `OhMyDesignShaders.metal` 的分节头。署名与许可全文见 `ACKNOWLEDGEMENTS.md`
《Star Nest —— `StarNest`，**已落地** · `#282`》一节，及 `docs/shader-provenance.md`
《② `StarNest`（MIT · Shadertoy `XlfGRj`）—— ✅ **确认**（一手内容 · 归档载体）》。
