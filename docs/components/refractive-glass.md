# RefractiveGlass

把内容渲染成一片折射玻璃 / Renders content as a sheet of refractive glass：圆角矩形区域内做透镜
位移 + 边缘高光。

源码：`Sources/OhMyDesignShaders/RefractiveGlass.swift`（`OhMyDesignShaders` product）。

⚠️ 用原生 `swift build` 消费本 product 时须加 `--build-system swiftbuild`：原生构建不编译 `.metal`，shader 会静默失效。

⚠️ **与 Apple 的 `.glassEffect()` 是两回事**：`.glassEffect()` 是 iOS 26 的 Liquid Glass 材质、
系统实现、随外观自动适配；本 modifier 只在需要可控折射强度 / 色散时用，命名刻意避开
`glass` 单独成词，防止与系统 API 混淆。

## API

`View.refractiveGlass(...)`：

| 参数 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| corner | CGFloat | `CoreRadius.medium` | 玻璃面板的圆角 |
| strength | RefractiveGlassStrength | `.regular` | 折射强度档位 |
| rim | Color | `.accent.opacity(0.55)` | 边缘高光色；传 `.clear` 关掉高光 |
| isEnabled | Bool | `true` | 关掉效果时保持 View 身份不变（走 `layerEffect` 的 `isEnabled`，不是 `if` 分支） |

## RefractiveGlassStrength

语义枚举，不暴露"位移像素数 + 色散系数"两个裸旋钮：

- `subtle`（色散为 0——弱折射配色散会显脏）
- `regular`
- `pronounced`

## 无障碍

本 modifier 不吃时间：折射由几何驱动而非动画，因此不需要 Reduce Motion 降级
（按 FR-12，`layerEffect` 类冻结时间输入、保留空间输入——这里没有时间输入）。本 modifier
作用于调用方的内容本身，不隐藏任何东西。

## 使用示例

```swift
Image("photo")
    .resizable()
    .refractiveGlass(corner: CoreRadius.large)

Text("OhMyDesign")
    .refractiveGlass(strength: .pronounced)
```

## 来源 / Provenance

本 modifier 的折射数学主体（位移 + 通道色散）尚未指认到具体上游，裁定为「待追溯（低指纹）」，
不作原创声称；调用的 `roundedBoxSDF` 已追到 Inigo Quilez（MIT），须署名。逐条见
`ACKNOWLEDGEMENTS.md`《`OhMyDesignShaders` 的共享原语与公开配方》表格「`ohMyDesignRefractiveGlass`
的位移 + 通道色散主体」一行，及 `docs/shader-provenance.md`
《⚠️⚠️ `coreDesignRefractiveGlass` 主体的追溯（#281 执行，**强档义务的兑现**）》专节。
