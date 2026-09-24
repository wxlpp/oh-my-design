# DotGrid

规则点阵背景 / A regular dot grid background，可选同心波呼吸。

源码：`Sources/OhMyDesignShaders/DotGrid.swift`（`OhMyDesignShaders` product）。

⚠️ 用原生 `swift build` 消费本 product 时须加 `--build-system swiftbuild`：原生构建不编译 `.metal`，shader 会静默失效。

## API

| 参数 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| tint | Color | `.dataAccent` | 调色基色，三档斜坡由它推导 |
| spacing | Spacing | `.regular` | 点距 |
| motion | ShaderMotion | `.still` | 运动速度档位；`.still` 时完全静态（呼吸振幅为 0），适合作纹理底 |

## Spacing

语义枚举，不暴露"格数 + 半径"两个裸旋钮：

- `loose`
- `regular`
- `tight`

## 动效与能耗

背景由 `ProceduralBackground` 承载（`Sources/OhMyDesignShaders/ShaderSupport.swift`），公共骨架规则：

- 运动速度由 `ShaderMotion` 四档（`still` / `calm` / `regular` / `lively`）控制时间缩放；`.still`
  时间缩放为 0，默认档就是 `.still`。
- Reduce Motion 开启时冻结在某一帧，保留视觉、去掉运动，而不是停止渲染或换成静态图。
- 后台 / inactive 时暂停渲染并保留最后一帧，回前台时动画原点顺延暂停时长接着走，不从头重放。
- 低电量模式下降低刷新频率。

点的边缘用 `fwidth` 做屏幕空间抗锯齿，因此在任何分辨率下边宽一致（不是固定像素值）。

## 无障碍

装饰层：`body` 链尾带 `.accessibilityHidden(true)`（FR-13）。

## 使用示例

```swift
DotGrid().ignoresSafeArea()

// 带同心波呼吸
DotGrid(spacing: .tight, motion: .calm)
```

## 来源 / Provenance

网格 + 抗锯齿圆盘是公开形态，不作「自研实现，非移植」的声称。本件（`ohMyDesignDotGrid`）实际
只调用 `edgeWidth`（`fwidth` 的下限兜底，无可归属上游的通用惯用法），自身裁定为
「待追溯（低指纹）」。逐条见 `ACKNOWLEDGEMENTS.md`《`OhMyDesignShaders` 的共享原语与公开配方》
表格，与 `docs/shader-provenance.md`《⚠️ 清偿条款：已落地件的 `待追溯` 怎么办（第 5 轮终审 C4）》
下表 B 的 `DotGrid` 行。
