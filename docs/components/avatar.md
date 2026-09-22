# Avatar

彩色首字母占位头像 / Color placeholder avatar with initial.

## API

| 参数 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| name | String | - | 用户名，用于取首字符与背景色哈希 |
| size | AvatarSize | .automatic | `.automatic` 按环境 `\.controlSize` 取直径；`.fixed(CGFloat)` 指定任意直径（负值按 0） |

### 尺寸

`Avatar` 渲染为**固定边长**的正方形，外部 `.frame` 不再拉伸它（只决定它在更大区域里的摆放）。
`.automatic` 的五档直径来自 `CoreControlMetrics.avatarDiameter(for:)`：

| controlSize | mini | small | regular | large | extraLarge |
|---|---|---|---|---|---|
| 直径（pt） | 20 | 24 | 32 | 40 | 48 |

`AvatarGroup` 共用同一张表，组内的 `Avatar` 经环境 `controlSize` 与组尺寸自动一致。
需要表外尺寸（如个人主页的 100pt 大头像）用 `.fixed(100)`。

## 预览 / Preview

运行 `scripts/run-snapshots.sh`（默认模式）后，预览图落地 `docs/snapshots/`——但前提是该组件已在 `App/Sources/Previews.swift` 注册（导出文件名形如 `OhMyDesignPreview_<组件名>.png`）；组件源码内自带的 `#Preview` 仅用于开发期本地预览，或经 `KEEP_LIBRARY_SNAPSHOTS=1 scripts/run-snapshots.sh` 导出到本地 scratch 目录做逐组件视觉核对（不写入 docs/snapshots，见 `.claude/epics/semi-mobile-components/phase0-decisions.md` §3）。

## 使用示例 / Usage

```swift
Avatar(name: "Alice")                       // regular 档：32pt
    .clipShape(Circle())

Avatar(name: "Alice")                       // large 档：40pt
    .controlSize(.large)
    .clipShape(Circle())

Avatar(name: "Alice", size: .fixed(100))    // 任意直径
    .clipShape(Circle())
```

## 视觉 Token

- 边长：`AvatarSize.automatic` → `CoreControlMetrics.avatarDiameter(for:)`；`.fixed(d)` → `d`
- 首字符字号：`CoreControlMetrics.avatarInitialFontSize(forDiameter:)`（直径的 7/12，粗体，不随 Dynamic Type 缩放——字号必须装进固定边长）
- 前景色：`Color.white`
- 背景色：由 `Color(text: name)` 从姓名哈希稳定派生
- 圆角：由调用方 `.clipShape(Circle())` 保证（`AvatarGroup` 内自动裁圆）
