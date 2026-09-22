# Issue #373 计划：字段校验基础层 + FormField（PRD FR-1）

## 文件清单

- 新增 `Sources/OhMyDesign/Components/FormField/FieldValidation.swift`
  —— 两个枚举、`@Entry` 环境值、三个公开 modifier、内部决策函数（hint 拼装、外观优先级、播报状态机）。
- 新增 `Sources/OhMyDesign/Components/FormField/FormField.swift` —— 容器。
- `Sources/OhMyDesign/Resources/en.lproj/Localizable.strings` 增两条键：`"%@, required"`、`"%@, %@"`。
- 新增测试 `Tests/OhMyDesignTests/FormFieldTests.swift`（macOS + iOS 两腿）。
- 文档：`docs/components/form-field.md`、`docs/README.md` 组件索引、`docs/component-registry.json`
  `components[]` 加 `FormField`；无破坏性变更 ⇒ 不动 `BREAKING-CHANGES.md`。
- 预览宿主：`App/Sources/ComponentData.swift`（id `form-field`）、`App/Sources/Previews.swift`。
- 守卫台账：按 `swift test` 实际红项同步（design digest、FLOORS 等），不放宽。

## 公开 API

```swift
public nonisolated enum FieldValidation: Equatable, Sendable { case valid; case invalid(Text) }
public nonisolated enum FieldRequirement: Equatable, Sendable { case optional; case required }

public extension EnvironmentValues {
    @Entry var fieldValidation: FieldValidation = .valid
    @Entry var fieldRequirement: FieldRequirement = .optional
}

public extension View {
    func fieldValidation(_ validation: FieldValidation) -> some View
    func fieldRequirement(_ requirement: FieldRequirement) -> some View
    func fieldAccessibilityHint() -> some View
}

public struct FormField<Content: View>: View {
    public init(_ label: LocalizedStringKey, description: LocalizedStringKey? = nil, @ViewBuilder content: () -> Content)
    @_disfavoredOverload
    public init<S: StringProtocol>(_ label: S, description: S? = nil, @ViewBuilder content: () -> Content)
}
```

- description 经 internal `@Entry var fieldDescription: Text?` 下传（#374 同模块直接读）。
- `fieldAccessibilityHint()`：读 `fieldValidation` + `fieldDescription`，错误原因在前、description 在后；
  两者皆无时 `accessibilityHint(_:isEnabled: false)`，保持视图结构稳定（避免 hint 出现 / 消失时
  改变控件 identity 丢焦点）。#374 的自有控件在真实输入节点内部调用同一个 modifier。
- 外观优先级 `FieldAppearance.resolve(isEnabled:validation:isFocused:)`：disabled > invalid > focused > normal。
  FormField 容器看不到子控件焦点，传 `isFocused: false`；focus 参数留给 #374 自有控件。
- 播报：`FieldValidationAnnouncer.observe(_:)` 状态机——首次观察不播；valid→invalid 播；invalid 文本变化播；
  相同值重复观察不播。FormField 经 `onChange(of:initial: true)` 驱动。

## 技术风险与替代

1. `accessibilityLabeledPair`：iOS 14+ / macOS 11+，SDK 26.4 接口中存在（已查 swiftinterface）。
   关联是否生效以 iOS 腿的无障碍树测试为准（UIHostingController 遍历元素，断言 TextField 元素的
   label / hint）。
2. 播报需要 `String`：`AccessibilityNotification.Announcement` 只接受 `String` / `AttributedString` /
   `NSAttributedString`，而 PRD 定 `invalid(Text)`。SwiftUI 无公开 `Text → String` API；采用
   `Text._resolveText(in:)`（SwiftUICore 中 `public`、下划线前缀，iOS 14+ / macOS 11+）。
   替代方案（需 PRD 改定，交由派单方决定）：把关联值改为 `LocalizedStringResource`，可用
   `String(localized:)` 解析，代价是失去 `Text` 的富文本 / verbatim 灵活性。
3. 「必填」追加文案：本仓只有 `en.lproj`，键为 `"%@, required"`（英文源语言），不新增 zh 本地化。

## 测试清单

- `FieldValidationAnnouncer`：首次 invalid 不播；同值重建不播；valid→invalid 播一次；invalid 文本变化播；
  invalid→valid 不播；valid→valid 不播。
- `FieldAppearance`：disabled 压过 invalid；invalid 压过 focused；label / 错误行 / 星号取色映射
  （结构相等，不走 resolve）。
- `FieldAccessibilityHint`：错误在前、description 在后；二者皆无为 nil。
- `FormFieldAccessibility.label`：optional 原样；required 追加。
- 环境值：modifier 写入、嵌套最近一层生效（经探针视图读环境）。
- 布局：invalid 渲染高度 > valid（错误行存在 / 移除），ImageRenderer，两腿可跑。
- iOS 腿：无障碍树中 TextField 元素的 hint 含错误原因与 description；labeledPair 关联后的 label；
  label 元素的可访问文本含 required；错误行像素出现 danger 色（资源色只在 iOS 腿可断言）。

## 登记 / 文档落点

- `components[]`：`FormField`，按公约第 1 节判定（见登记表 notes）；textParams `label` / `description` 均 B。
- modifier 与枚举属主 target 扩展入口 / 辅助类型，按 AD-2 不进登记表。

## 实测结论（实现期补记）

- `accessibilityLabeledPair`：SDK 26.4 可编译（iOS 14+ / macOS 11+）。进程内单测拿不到 SwiftUI 无障碍树
  （无 AT 客户端时 `_UIHostingView` 不暴露子元素，macOS `NSHostingView` 同样只有根 AXGroup），
  故改用 AXe 读 iOS 26.4 模拟器上的预览宿主：TextField 节点 `help` = 错误原因 + description（顺序正确），
  label 元素为 `Email, required`；但 TextField 节点 `AXLabel` 为 null——labeledPair 未把 label 并入输入节点。
  PRD 契约保留（labeledPair 照挂），该限制登记进 `docs/components/form-field.md`，是否追加补救交派单方裁定。
- 登记：步骤 2 枚举落出口 1（需扩展点），与 PRD 无扩展点冲突 ⇒ 暂记 `pendingStep2`（承接 #373），交派单方裁定。

## 派单方裁定后的改动（resolve open points）

- `fieldAccessibilityHint()` 改名 `fieldAccessibility()`：同时设输入节点的 label（字段 label + 必填说明）与 hint；AXe 实测 TextField 暴露 `Email, required` + 错误原因。
- 新增 D2 `FormFieldLayout { stacked, inline }`（init `layout:` 参数，缺省 `.stacked`），登记改判 `semantic` / `step2`，`pendingStep2` 台账复原为空。
- `FieldValidation.invalid` 关联值改为 `LocalizedStringResource`：显示 `Text(_:)`、播报 `String(localized:)`，不再用下划线 API。
- `docs/snapshots` 新增 `FormField` 快照；description / 错误行对 VoiceOver 保持可见，文档登记可能的重复朗读。
