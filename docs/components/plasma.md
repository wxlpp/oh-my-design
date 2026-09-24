# Plasma

程序化等离子背景 / A procedural plasma background. 适合作 onboarding / paywall / 启动页的底层。

源码：`Sources/OhMyDesignShaders/Plasma.swift`（`OhMyDesignShaders` product）。

⚠️ 用原生 `swift build` 消费本 product 时须加 `--build-system swiftbuild`：原生构建不编译 `.metal`，shader 会静默失效。

## API

| 参数 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| tint | Color | `.dataAccent` | 调色基色，三档斜坡由它推导 |
| density | Density | `.regular` | 视觉密度 |
| motion | ShaderMotion | `.regular` | 运动速度档位 |

## Density

语义枚举，不暴露"频率 + 叠加层数"两个裸旋钮：

- `subtle`
- `regular`
- `dense`

## 动效与能耗

背景由 `ProceduralBackground` 承载（`Sources/OhMyDesignShaders/ShaderSupport.swift`），公共骨架规则：

- 运动速度由 `ShaderMotion` 四档（`still` / `calm` / `regular` / `lively`）控制时间缩放；`.still`
  时间缩放为 0。
- Reduce Motion 开启时冻结在某一帧（`ProceduralBackground.elapsed` 在 `reduceMotion` 为真时返回 0），
  保留视觉、去掉运动，而不是停止渲染或换成静态图。
- 后台 / inactive 时暂停渲染并保留最后一帧（`.hidden` 呈现态下 `TimelineView` 暂停），回前台时动画
  原点顺延暂停时长接着走，不从头重放。
- 低电量模式下降低刷新频率（由 `EnergyState` / `RenderPolicy` 决定 `minimumInterval`）。

## 无障碍

装饰层：`ProceduralBackground.body` 链尾带 `.accessibilityHidden(true)`（FR-13，"纯装饰层。承载状态语义的效果由调用方提供
a11y 通告"）。

## 使用示例

```swift
ZStack {
    Plasma().ignoresSafeArea()
    content
}

Plasma(tint: .teal, density: .dense, motion: .lively)
```

## 来源 / Provenance

四相正弦叠加参考自 Lode Vandevenne《Lode's Computer Graphics Tutorial — Plasma》（代码部分
BSD-2-Clause），裁定为「参考算法思路」，不作原创声称；逐条见 `ACKNOWLEDGEMENTS.md`
《`OhMyDesignShaders` 的共享原语与公开配方》表格「`Plasma` 的四相正弦叠加」一行，与
`docs/shader-provenance.md`《⚠️ 清偿条款：已落地件的 `待追溯` 怎么办（第 5 轮终审 C4）》下
表 A 同名行。
