# Halftone

半调网屏 / A halftone screen：把内容层按网格取样，用点的大小表示明暗，输出成油墨 + 纸两色的印刷
观感。

源码：`Sources/OhMyDesignShaders/Halftone.swift`（`OhMyDesignShaders` product）。

⚠️ 用原生 `swift build` 消费本 product 时须加 `--build-system swiftbuild`：原生构建不编译 `.metal`，shader 会静默失效。

## API

`View.halftone(...)`：

| 参数 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| dot | HalftoneDot | `.regular` | 网点粗细档位 |
| ink | Color | `.contentPrimary` | 油墨色；随系统外观 / 对比度自动适配；不能走 `.tint` 通路 |
| paper | Color | `.clear` | 纸色；默认印在透明背景上只有墨点是实心的，传一个实色即得到"整块纸"的观感 |

## HalftoneDot

语义枚举，不暴露裸的"格宽 + 点半径"两个旋钮；三档的关系是"格子越粗、单点越大"。网格边长（点）：

- `fine`（4pt）
- `regular`（8pt）
- `coarse`（16pt）

单色网屏的惯例角度固定为 45°（印刷业通行取值），不作为公开参数。

## 无障碍

- **不吃时间**：半调是对内容层的空间重排，没有时间输入 ⇒ 按 FR-12 无需 Reduce Motion 降级。
- **Reduce Transparency**：本 modifier 不模拟任何半透明材质——半调是对内容层的空间重排（点的
  大小编码明暗），不是玻璃 / 毛玻璃那类"让你看见后面有东西"的材质暗示，该偏好在本件上没有对应
  的失效面，无降级。
- 本 modifier 不隐藏任何东西。

## 使用示例

```swift
Image("portrait").resizable().scaledToFit()
    .halftone()

Text("SALE").font(.system(size: 120, weight: .black))
    .halftone(dot: .coarse, ink: .accent)
```

## 来源 / Provenance

移植自 [paper-design/shaders](https://github.com/paper-design/shaders) 的
`packages/shaders/src/shaders/halftone-dots.ts`（Apache-2.0），逐条修改标注见
`OhMyDesignShaders.metal` 的 `ohMyDesignHalftone` 文档注释。hash 一族追到 Inigo Quilez（MIT）
与 Dave Hoskins（MIT），两份第三方通知由本仓自行补上。署名与许可全文见 `ACKNOWLEDGEMENTS.md`
《paper-design/shaders（Apache-2.0）—— `View.halftone` + `#282` 的移植背景，**部分落地**》
一节（含 Apache-2.0 全文、`NOTICE`、以及「Inigo Quilez — MIT」「David Hoskins — MIT」两个
小节），及 `docs/shader-provenance.md`《⑥-C：`Halftone` 的 hash 追到 Dave Hoskins 与
iq（**两条都 MIT**）》。
