# TagGroup

可选标签组（filter chips）/ Selectable group of tag chips.

基于 `Tag` + `FlowLayout`：标签自动折行，选中态画在 `Tag` 自己的圆角矩形上（圆角、尺寸随 `\.controlSize` 五档变化）。

## API

```swift
public enum TagGroupSelectionMode: Hashable, Sendable, CaseIterable { case none, single, multiple }

public struct TagGroup<Data: RandomAccessCollection, ID: Hashable, Label: View>: View {
    public init(
        _ data: Data,
        id: KeyPath<Data.Element, ID>,
        selection: Binding<Set<ID>>,
        selectionMode: TagGroupSelectionMode = .multiple,
        disabled: Set<ID> = [],
        color: Color,
        spacing: CGFloat = CoreSpacing.xs,
        @ViewBuilder label: @escaping (Data.Element) -> Label
    )
}

// Data.Element: Identifiable 时可省略 id:
TagGroup(items, selection: $selection, color: .contentPrimary) { Text($0.name) }
```

| 参数 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| data | RandomAccessCollection | - | 标签数据源 |
| id | KeyPath<Element, ID> | `\.id`（Identifiable 便利 init） | 稳定标识 |
| selection | Binding<Set<ID>> | - | 已选 ID 集合 |
| selectionMode | TagGroupSelectionMode | `.multiple` | `none` / `single` / `multiple` |
| disabled | Set<ID> | `[]` | 禁用项 |
| color | Color | - | 标签内容色，同 `Tag(color:)`：文字与未选态 12% 衬底 |
| spacing | CGFloat | `CoreSpacing.xs` | 标签与行间距（传给 `FlowLayout`） |
| label | (Element) -> Label | - | 标签主体，常为 `Text` / `Label` |

## 选择语义

- **`data` 内的 ID 必须唯一。** 重复 ID 会让 `ForEach` 的身份与选择语义都不确定；DEBUG 构建检测到重复时
  经 `OSLog`（subsystem `OhMyDesign`，category `TagGroup`）输出一条警告，不中断运行。

- **基数只计当前 `data` 里的 ID。** 绑定里不在数据中的 ID（例如翻页后不可见的已选项）原样保留，
  组件永不增删它们。
- `single`：点未选项 = 把「数据内已选集合」替换为该项；点已选项 = 取消，允许空选。
  外部写入多个数据内 ID 时照样全部画成已选，下一次用户点选才归一到 ≤ 1 个。
- `multiple`：点击逐项切换。
- `none`：纯展示，标签不是按钮、不可聚焦；绑定里已选的项仍画出选中态（并带 `.isSelected` trait）。
- 切换 `selectionMode` 不改写绑定。
- 禁用项不可切换，但已选时仍显示选中态；整块 0.4 不透明度。
- 本轮不支持在 TagGroup 内删除标签（`Tag` 的关闭钮是按钮，嵌进标签按钮会形成嵌套按钮）。

## 外观

- 选中：底色 `accentSubtleBackground(from: coreAccent)`、2pt（`CoreBorderWidth.thick`）描边 `accentSelectedBorder(from: coreAccent)`，
  两者都从**环境 `coreAccent`** 派生（公式在 `Colors/InteractionColors.swift`），
  `.coreAccent(_:)` 换色即跟随；默认墨色 accent 下是淡灰底 + 墨色描边。
- 标签内容色由 `color` 决定，选中不改变文字颜色。
- 选中外观只作用于标签自身的底与描边，不向调用方的 label 子树传递——label 里嵌套的独立 `Tag` 保持自己的外观。
- 按下 0.7 不透明度。

## 动效（#409）

- **选中态切换**：走 `.coreAnimation(.selection, value: selection)`（`CoreMotionToken.selection`，0.22 s）。
  两种呈现裁决下都**保留**动画——选中只换底色与描边色，尺寸与包围盒不变，纯色插值不是位移类动效，
  按 HIG 无需在 Reduce Motion 下关掉。判据
  `TagMotionInFlightTests.tagGroupSelectionInterpolatesWithoutGeometryChange` 在 macOS 托管窗口里逐帧
  采样，既要求两种呈现下都拍到中间帧，也要求中间帧的变化像素**不越出最终变化区**（越出即意味着有几何位移）。
  ⚠️ 实现上是两个 chrome 子树的**交叉淡变**（`Tag` 的选中 / 未选 chrome 是 `if let` 两个分支），
  不是单个 fill 的颜色插值；实测两种写法都能拍到中间帧，因此没有为了「可插值」而改写 `Tag`。
- **标签增删**：`data` 变化时走 `CollectionItemTransition` + `CoreMotionToken.reveal`，
  经 `transformAnimation(for:)` ⇒ **Reduce Motion 下为 `nil`**，标签直接出现 / 消失、`FlowLayout` 不做补间重排
  （理由与 `tag-input.md`「增删动效」一节相同：重排是位移，只有 `nil` 能做到零位移）。
- **静息外观不随呈现裁决变化**：五档 `controlSize` × 选中与否 × light / dark 下，注入
  `.animated` / `.resting` / `.hidden` 三种裁决的位图在光栅化噪声内相同（判据
  `TagStaticAppearanceTests.tagGroupIgnoresPresentationWhenSettled`，Δ ≤ 1、差异 ≤ 0.2%，
  噪声来自同进程连渲次序，理由写在该判据的 `expectSettledMatch` 文档注释里）。
- ⚠️ **`data` 与 `selection` 在同一次更新里一起变时**，两条 `animation` 链里内层那条（按 `data` 的 ID
  列表触发）说了算：Reduce Motion 下它是 `nil`，于是**选中态的淡变也被一起吞掉**（实测 macOS 托管窗口
  0.5 s 采样：`.animated` 下 22 / 52 帧是中间帧，`.resting` 下 0 / 42）。这一格没有机器判据、
  也不打算加——两种结果（淡变 / 直接到位）都在 HIG 允许范围内，登记在此免得下次被当成 bug 排查。

## 无障碍与触控

- `single` / `multiple` 下每个标签是按钮，带 `.isButton`，已选时加 `.isSelected`（VoiceOver 读「已选」），
  可被键盘聚焦（Full Keyboard Access / 硬件键盘）。
- 命中区：每个标签的点击形状在宽、高两轴都外扩到至少 44pt，视觉与布局尺寸仍是 `Tag` 本身（不撑高行、不挤开邻居）。
  ⚠️ 默认 4pt 间距下，相邻标签（同行左右、上下两行）的外扩命中区会重叠，重叠处由排在后面的标签响应；需要严格分离时加大 `spacing`。

## 使用示例 / Usage

```swift
struct Filter: Identifiable, Hashable { let id: String }
let filters = ["Swift", "Kotlin", "Rust"].map(Filter.init(id:))
@State var selected: Set<String> = ["Swift"]

TagGroup(filters, selection: $selected, color: .contentPrimary) { Text($0.id) }

TagGroup(filters, selection: $selected, selectionMode: .single, disabled: ["Rust"], color: .contentPrimary) {
    Text($0.id)
}
.coreAccent(.blue)
.controlSize(.small)
```

横向单行滚动：放进 `ScrollView(.horizontal)` 即可——`FlowLayout` 在无界宽度提议下排成单行。

## 预览 / Preview

运行 `scripts/run-snapshots.sh`（默认模式）后，预览图落地 `docs/snapshots/`（`App/Sources/Previews.swift` 的 `#Preview("TagGroup")`）。
预览宿主画廊 id：`tag-group`（none / single / multiple、禁用项、自定义 coreAccent、五档尺寸）。
