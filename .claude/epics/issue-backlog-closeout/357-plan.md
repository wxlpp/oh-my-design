# #357 实施计划：coreAccent on-accent 通路

## 已定裁决（用户，2026-09-14）

`coreAccent(_:on:)`：可选 `on` 参数；**缺省时按 accent 在当前外观下的亮度自动选黑 / 白**；
显式传 `on` 覆盖。静态 token `contentOnAccent` 保留作回退，分层前提不破。

## 设计要点

- 新 `@Entry var coreAccentOn: Color? = nil`（`nil` = 派生）——名字自拟但要避开
  `coreAccent` 的遮蔽警告（CLAUDE.md 已有同类注记，沿用 `resolvedAccent` 的命名风格）。
- 派生函数（internal，放 `CoreAccentEnvironment.swift` 或 `Utils/ColorExtension.swift`）：
  `onAccent(for: Color, in: EnvironmentValues) -> Color` —— 在当前环境 resolve accent 得
  RGBA，算相对亮度 L；L < 0.5 → `.white`，否则 `.black`。验算：墨色 accent 在 light 下
  L=0 → white（= systemBackground light ✓）、dark 下 L=1 → black（= systemBackground
  dark ✓）；系统蓝 L≈0.41 → 两档都 white ✓（这正是修复点）；黄 L≈0.93 → 两档都 black ✓。
- 消费点改读环境解析后的 on-accent：
  - `ButtonRoleStyleRole.onColor`：它是 static 计算属性、拿不到环境——改法是把 on-accent
    从样式侧传入（样式已有 `@Environment(\.coreAccent)` 先例，同理加 `@Environment(\.coreAccentOn)`），
    `onColor` 保留为「静态 token 回退」（`contentOnAccent`），新加
    `resolvedOnColor(accent:on:environment:)` 类 helper 供样式调用。⚠️ 实现者先读
    `ButtonStyleDefaultTests.swift` 与五个 style 的现状再定最小改动面。
  - `InkSegmentedControlStyle` 选中段文字：同理。
- ⚠️ 派生需要 `EnvironmentValues` 解析 `Color`——ButtonStyle 的 `makeBody` 里
  `@Environment(\.self)` 是否可用要实测（样式已有 `@Environment` 先例）；不可用就把
  派生包进一个 internal View 层 helper。

## 步骤

1. 读现状：`Colors/CoreAccentEnvironment.swift`、`ButtonRoleStyleRole.swift`、
   `Components/SegmentedControl/InkSegmentedControlStyle`（或实际路径）、
   `ButtonStyleDefaultTests.swift`（#356 的对比度表口径在 `onColor` 文档注释）。
2. 实现：环境键 + modifier 参数 + 派生函数 + 两个消费点。
3. 判据（纯函数级，不依赖渲染）：派生函数在 (accent, scheme) 组合下的输出断言——
   墨色 × light/dark、蓝 × light/dark、黄 × light/dark，共 6 组；加「显式 on 覆盖」断言。
   ⚠️ 判据别在 macOS native 腿 `resolve(in:)` asset catalog 色（CLAUDE.md 硬规则）；
   用系统色 / 静态色组合，两条腿都能跑。
4. 文档三处同步：`CoreAccentEnvironment.swift` 文档注释（删「本版本不提供 on-accent
   钩子」）、`docs/DESIGN-FOUNDATION.md` accent 衍生族一节、`docs/BREAKING-CHANGES.md`
   新增未发布章节条目。
5. `scripts/downstream-probe` 补新签名调用点（source-compatible，加一个调用即可）。
6. 验证：`swift build` + `swift test`（macOS native）→ `xcodebuild test -scheme
   OhMyDesign-Package -destination 'platform=iOS Simulator,id=<UDID>'`（判据若两腿通用
   则此腿作证据）→ `scripts/mainactor-static-ratchet.sh`（新公开成员）→
   `cd scripts/downstream-probe && swift build`。

## 验收

- `.coreAccent(.blue)` 下 `solid(.primary)` 按钮明暗两档前景可读——以派生函数 6 组断言 +
  （若 #356 有 render 判据先例）同口径对比度为据。
- 墨色 accent 行为与现状一致（派生恰好复现 `systemBackground`）。
- issue 里三处登记文档全部同步；BREAKING-CHANGES 有未发布条目。
