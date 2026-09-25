# GlassOrb

玻璃珠放大镜 / A glass orb magnifier：一个跟手的圆形透镜，在圆内做随距离衰减的放大。

源码：`Sources/OhMyDesignShaders/GlassOrb.swift`（`OhMyDesignShaders` product）。

⚠️ 用原生 `swift build` 消费本 product 时须加 `--build-system swiftbuild`：原生构建不编译 `.metal`，shader 会静默失效。

## API

`View.glassOrb(...)`：

| 参数 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| size | GlassOrbSize | `.regular` | 透镜尺寸档位；每档直径都 ≥ 44pt（它是被拖动的手柄） |
| magnification | GlassOrbMagnification | `.regular` | 放大倍率档位 |

## GlassOrbSize

语义枚举，不暴露裸的"半径像素数"。半径（点）：

- `small`（24pt，直径 48pt）
- `regular`（44pt）
- `large`（72pt）

## GlassOrbMagnification

语义枚举。放大倍率：

- `gentle`（1.6）
- `regular`（2.4）
- `strong`（4.0）

## 手势与使用边界

`DragGesture(minimumDistance: 0)`，按下即定位，抬手后停在原处；未发生手势时落在视图正中。
该手势挂在整个内容上且 `minimumDistance: 0`，会无条件吞掉本视图上的拖拽——放进 `ScrollView` /
`List` 里，本视图所在区域划不动；叠在按钮、滑块等可交互内容上，那些手势收不到事件。本 modifier
的适用面是静态展示内容（图片、文本、渐变），不是可滚动容器里的行，也不是交互控件的外壳。

## 无障碍

- **Reduce Motion**：本 modifier 没有时间输入（放大由几何与手势驱动），按 FR-12 属"冻结时间、
  保留空间"里空间的那一半 ⇒ 手势跟随不受该偏好影响。
- **Reduce Transparency**：取消变焦柔化，退化成均匀放大镜（功能保留）——圆内放大倍率是常数、
  边界是硬边。
- 本 modifier 不隐藏任何东西：FR-13 管的是"shader 装饰层"，本 modifier 作用在调用方的内容上，
  把它移出无障碍树会连内容一起吃掉。

## 使用示例

```swift
Text("OhMyDesign").font(.largeTitle)
    .glassOrb()

Image("map").resizable()
    .glassOrb(size: .large, magnification: .strong)
```

## 来源 / Provenance

移植自 [Inferno](https://github.com/twostraws/Inferno) 的 `WarpingLoupe.metal`
（Paul Hudson 等，MIT），逐条差异见 `OhMyDesignShaders.metal` 的 `ohMyDesignGlassOrb`
文档注释。MIT 全文见 `ACKNOWLEDGEMENTS.md`《Inferno — Warping Loupe（`View.glassOrb`，
**已落地** · `#283`）》一节，及 `docs/shader-provenance.md`
《③ `GlassOrb`（MIT · Inferno）—— ⚠️ **推论未被推翻，但其前提被证明比上一版说的弱**》。
