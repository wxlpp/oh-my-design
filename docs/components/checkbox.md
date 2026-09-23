# CheckBox

复选框 / CheckBox，以 `CheckBoxToggleStyle: ToggleStyle` 的形态提供——**不是**自造组件，
而是系统 `Toggle` 的一个样式（原生协议这条分支的样本，见 `docs/component-contract.md` 的附录 A.0）。
与 `Components/Radio/`（`RadioGroup`）视觉成对：同一套 token、方框换圆点。

```swift
Toggle("同意用户协议 / Accept terms", isOn: $isOn)
    .toggleStyle(CheckBoxToggleStyle())
```

## 三态 / Three states

指示符有 **三** 个态，不是两个。第三个态（mixed / 部分选中）**不是本库造的模型**——
`ToggleStyleConfiguration.isMixed` 自 iOS 16 / macOS 13 就在系统 API 里，本库只是读它。

| 态 | 何时出现 | symbol | 取色（normal 外观） |
|---|---|---|---|
| off | 全部绑定为 `false` | `square` | `contentSecondary` |
| mixed | 一组绑定里真假混杂 | `minus.square.fill` | `contentPrimary` |
| on | 全部绑定为 `true` | `checkmark.square.fill` | `contentPrimary` |

判定逐字写在 `Sources/OhMyDesign/Components/CheckBox/CheckBox.swift`：`if isMixed { return .mixed }`
——**mixed 压过 `isOn`**。这不是可选口径：mixed 态下 `isOn` 读到什么由框架决定，
先看 `isMixed` 才不依赖那个未定的取值。

### symbol 取值的理由

`case .mixed: "minus.square.fill"`：

- **同族**。已有两态是 `square` / `checkmark.square.fill`，都在方框族里；换成圆族
  （Apple 自己的 mixed 示例用的是 `minus.circle.fill`）会与 `RadioGroup` 的 `circle` /
  `circle.inset.filled` 撞车，读者会把它读成单选。
- **`.fill`**。mixed 与 on 一样「已作用」，所以跟 on 同为实心、同取 `contentPrimary`；
  只有 off 是空心 + `contentSecondary`。
- **减号**是 mixed 的惯用记号——Apple 的示例选的正是减号，本库只换了外框形状。

## 调用方怎么得到 mixed

**不通过任何本库 API**。用系统的 `Toggle(sources:isOn:label:)`：它从一组
`Binding<Bool>` 自动派生 on / mixed / off，并把结果放进 `configuration.isMixed`。

```swift
struct ConsentForm: View {
    @State private var terms = false
    @State private var privacy = true

    var body: some View {
        VStack(alignment: .leading, spacing: CoreSpacing.md) {
            // 一真一假 ⇒ 这一行画 mixed；点它会把两个绑定一起写成同一个值
            Toggle(sources: [$terms, $privacy], isOn: \.self) {
                Text(verbatim: "全选 / Select all")
            }

            Toggle("用户协议 / Terms", isOn: $terms)
            Toggle("隐私政策 / Privacy", isOn: $privacy)
        }
        .toggleStyle(CheckBoxToggleStyle())
    }
}
```

⚠️ **`CheckBox` 没有、也不会有 `isMixed` 入参**：mixed 是从数据派生的状态，不是调用方
拨的开关；本库的公开 API 一律无 Bool 入参。要自己控制三态就自己组一组绑定喂给 `sources:`。

## 动效 / Motion

符号切换走 `.contentTransition(self.motionPresentation.symbolReplacement)`
（`CoreMotionToken` 通路，逐调用点登记在 `CoreMotionTokenDisciplineGuard` 的
`transformLedger` 里）。三态之间任意切换都用同一条通路：

| Reduce Motion | 行为 |
|---|---|
| 关 | `ContentTransition.symbolEffect(.replace)`，新符号描画出现 |
| 开 | `ContentTransition.identity`，直接换图，不描画 |

静息外观与 Reduce Motion 无关（三态 × light / dark 都有逐像素判据）。
包裹层的补间走 `.coreAnimation(.selection, value:)`，触发值是**三态枚举**而不是
`isOn`——否则 off ↔ mixed 的切换不会补间。

## 校验态 / Validation

接 `FieldValidation`（`View.fieldValidation(_:)`）：`invalid` 时指示符改取
`statusDangerForeground`，`disabled` 压过 `invalid` 并把整行降到 `FieldAppearance.disabledControlOpacity`。
三态共用同一条取色通路，mixed 没有例外。

## 验证边界 / Verification boundaries

- **`invalid` 的外观判据只在 iOS Simulator 腿作数**：`statusDangerForeground` 走 asset
  catalog，在 macOS `swift test` 上解析为全透明 ⇒ 指示符一个像素都不画，「新旧两张相等」
  会凭空成立。`CheckBoxLegacyAppearanceTests` 把 invalid 那两格显式 skip 并打印原因，
  normal / disabled 四格两条腿都跑。
- **「三态渲染两两不同」不足以钉住画的是哪个符号**：三态的取色本来就不同
  （off 取 `contentSecondary`），只比「有差别」时，把符号退回按 `isOn` 二选一**仍然全绿**
  （实测）。钉住符号的是 `eachStateDrawsItsOwnSymbol`——与一份把符号 / 取色**写死成字面量**
  的同构视图树逐像素对照。

## API

### `CheckBoxToggleStyle`

无参构造，无配置项。三态的符号与取色都不可配置——那是设计系统的决定，不是调用点的选择。

## 预览 / Preview

组件源码内自带 `#Preview`（含一个 `Toggle(sources:)` 的三态示例），用于开发期本地预览。
