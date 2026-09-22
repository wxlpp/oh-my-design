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
- 按下 0.7 不透明度。

## 无障碍与触控

- `single` / `multiple` 下每个标签是按钮，带 `.isButton`，已选时加 `.isSelected`（VoiceOver 读「已选」），
  可被键盘聚焦（Full Keyboard Access / 硬件键盘）。
- 命中区：每个标签的点击形状纵向外扩到至少 44pt 高，视觉与布局尺寸仍是 `Tag` 本身（不撑高行）。
  ⚠️ 默认 4pt 行距下，相邻两行的外扩命中区会重叠，重叠处由后一行响应；需要严格分离时加大 `spacing`。

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
