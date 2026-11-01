# SelectionCard

带自定义说明内容的单选卡片。外部持有选择值，组件使用原生 Button 提交单个值，不提供自己的选择存储或多选模式。

```swift
SelectionCard(value: "focus", selection: $selection) {
    VStack(alignment: .leading) {
        Label("专注", systemImage: "circle.lefthalf.filled")
        Text("留白更多，让思路安静").font(.caption)
    }
}
.disabled(isUnavailable)
```

## 契约

- 相同 Binding 的卡片互斥选择；重复选择当前项不清空、不重复写入。
- 禁用读取系统环境，原生 Button 与操作入口均拒绝写入。
- 选中状态有固定位置的勾号和 selected trait，不只依赖颜色；装饰符号不进入朗读。
- label 内容由调用方提供，包括本地化、字体和说明；不得嵌套其他交互控件。
- 内容自然换行；至少 44pt 命中高度。网格列数和组标题归调用方，窄窗口/大字号应切为单列。
- 使用 coreAccent 的浅色底与边框，正文保持中性色。按压复用 pressableCard，Reduce Motion 沿用其降级；选中只做颜色淡变，不做位置滑动或持续动画。

## 使用边界

适合少量需要解释的选择，不替代长列表 Picker、紧凑 SegmentedControl 或 RadioGroup。当前为规定性卡片形态；内容通过 label 槽变化，不引入自有 style 协议。

## Gallery

「带说明的选择」可测试三项互斥和禁用；「材质与强调」「内容卡片组合」复用已有基础组件，不改变 Card/floatingGlass 的默认外观。示例内容不读取用户数据。
