# FractalClouds

分形云层背景 / A fractal cloud layer background. FBM + 域扭曲。

源码：`Sources/OhMyDesignShaders/FractalClouds.swift`（`OhMyDesignShaders` product）。

⚠️ 用原生 `swift build` 消费本 product 时须加 `--build-system swiftbuild`：原生构建不编译 `.metal`，shader 会静默失效。

## API

| 参数 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| tint | Color | `.dataAccent` | 调色基色，三档斜坡由它推导 |
| density | Density | `.regular` | 云的细腻程度 |
| motion | ShaderMotion | `.calm` | 运动速度档位 |

## Density

语义枚举，不暴露"scale + octaves + warp"三个裸旋钮：

- `soft`
- `regular`
- `turbulent`

## 动效与能耗

背景由 `ProceduralBackground` 承载（`Sources/OhMyDesignShaders/ShaderSupport.swift`），公共骨架规则：

- 运动速度由 `ShaderMotion` 四档（`still` / `calm` / `regular` / `lively`）控制时间缩放；`.still`
  时间缩放为 0。
- Reduce Motion 开启时冻结在某一帧，保留视觉、去掉运动，而不是停止渲染或换成静态图。
- 后台 / inactive 时暂停渲染并保留最后一帧，回前台时动画原点顺延暂停时长接着走，不从头重放。
- 低电量模式下降低刷新频率。

## 无障碍

装饰层：`ProceduralBackground.body` 链尾带 `.accessibilityHidden(true)`（FR-13）。

## 使用示例

```swift
FractalClouds().ignoresSafeArea()

FractalClouds(tint: .teal, density: .turbulent, motion: .regular)
```

## 来源 / Provenance

整数 hash 为 Thomas Wang / Nathan Reed 的 GPU 版本，格点 seed 素数出自 Teschner et al. 2003，
单级域扭曲结构属 Inigo Quilez《Domain Warping》一族（站点级 MIT，已追到兼容许可）；本件自身
（`ohMyDesignFractalClouds`）尚未指认到具体上游，裁定为「待追溯（低指纹）」，不作原创声称。
逐条见 `ACKNOWLEDGEMENTS.md`《`OhMyDesignShaders` 的共享原语与公开配方》表格「域扭曲的
`q`/`r` 三级级联」一行，与 `docs/shader-provenance.md`《⚠️ 清偿条款：已落地件的 `待追溯` 怎么办
（第 5 轮终审 C4）》下表 B 的 `FractalClouds` 行。
