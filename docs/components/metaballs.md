# Metaballs

一组彩色小球绕中心游走、彼此融合成黏连的有机形状 / A group of colored balls that drift and blend
into an organic blob shape.

源码：`Sources/OhMyDesignShaders/Metaballs.swift`（`OhMyDesignShaders` product）。

⚠️ 用原生 `swift build` 消费本 product 时须加 `--build-system swiftbuild`：原生构建不编译 `.metal`，shader 会静默失效。

## API

| 参数 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| tint | Color | `.dataAccent` | 调色基色，三档斜坡由它推导 |
| count | Count | `.regular` | 小球的数量与大小 |
| motion | ShaderMotion | `.regular` | 运动速度档位 |

## Count

语义枚举，不暴露「个数 + 尺寸」两个裸旋钮：

- `few`
- `regular`
- `many`

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
Metaballs().ignoresSafeArea()

Metaballs(tint: .teal, count: .many, motion: .lively)
```

## 来源 / Provenance

移植自 paper-design/shaders 的 `packages/shaders/src/shaders/metaballs.ts`
@ `43cd68d`（Apache-2.0），修改逐项写在 `OhMyDesignShaders.metal` 的分节头。署名与许可全文见
`ACKNOWLEDGEMENTS.md`《paper-design/shaders（Apache-2.0）—— `View.halftone` + `#282` 的移植
背景，**部分落地**》一节（`Metaballs` 在「已落地的件」清单内），及 `docs/shader-provenance.md`
《§B 追到 `paper-design/shaders` 的 11 个 —— 8 个正向裁定 Apache-2.0 + 3 个待追溯》。
