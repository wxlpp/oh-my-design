# #282 实施计划：8 个可落地 colorEffect 背景

## 前置（均已就绪）

- `#271` 已裁决（NFR-7 通用能耗策略表**下沉到 OhMyDesign**，见 0.10.0 BREAKING-CHANGES
  章节）⇒ 不再二选一：`import OhMyDesign` 复用下沉后的策略表。开工时先读
  `docs/BREAKING-CHANGES.md` 的 0.10.0 #271 章节 + 在源码里定位表与类型的现址。
- `#279` / `#280` 已关闭（扫描根已收口；可落地 11 → 10，Water 掉档，`N_B` 重估 6）。
- epic 分支已与 main 集成（OhMyDesignShaders 命名）。

## 成员（8 个，按《统一裁定表》）

| shader | 裁定 | 上游 | Swift 名（自拟，登记表用） |
|---|---|---|---|
| `StarNest` | MIT | Pablo Roman Andrioli（Kali），Shadertoy | `StarNestBackground` |
| `Voronoi` | Apache-2.0 | paper `voronoi.ts` → iq | `VoronoiBackground` |
| `Swirl` | 同上 | paper `swirl.ts` | `SwirlBackground` |
| `SimplexNoise` | 同上 | paper `simplex-noise.ts` | `SimplexNoiseBackground` |
| `ColorPanels` | 同上 | paper `color-panels.ts` | `ColorPanelsBackground` |
| `DotOrbit` | 同上 | paper `dot-orbit.ts` | `DotOrbitBackground` |
| `SmokeRing` | 同上 | paper `smoke-ring.ts` | `SmokeRingBackground` |
| `Metaballs` | 同上 | paper `metaballs.ts` | `MetaballsBackground` |

⚠️ `Starfield` ≠ `StarNest`（前者已撤回，`807f074`）；`NeuroNoise` 不在本表；`Water` 已掉档。

## 实现形态（沿用 #261 / #283 先例，先读那 9 个已落地件）

- 每个 = `public struct … : View` + 对应 `.metal` 函数 + `#Preview`；可 `.background { }`。
- `.metal` 侧零硬编码色（FR-8），调色板走参数；tint 以参数传入、默认值取第 3 层语义
  token（#261 实证 shader 读不到 `.tint`）。
- **Reduce Motion**：冻结在某一帧（保留视觉、去掉运动），不是停止渲染。
- **NFR-7 后台 / 低电量**：读 OhMyDesign 下沉后的策略表 + `lowPowerModeOverride` /
  `scenePhaseOverride` 两个可注入键；**注入伪值测试**可证。
- **像素采样 render proof**（`RenderProofTests` 形态）：metallib 加载 + 函数解析
  ≠ 画得出来（`Float` 精度教训——`timeIntervalSinceReferenceDate` ≈ 8.1e8 在 `Float`
  下吞掉空间项）；每个 shader 都要证明「采样像素不恒等」。
- 署名义务（Apache-2.0 档）：LICENSE 全文 + `NOTICE`（`Powered by Paper Shaders:
  https://shaders.paper.design`）+ 修改标注（§4(b)）+ 逐 shader 的 `.metal` 文件头注明
  paper 对应 `.ts` 路径；`StarNest` 走 MIT 档（ACK 条目引用其 Shadertoy 出处）。
- **Bool 纪律**（AD-H）：本 epic 豁免预算 ≤ 1 条净增——开工先查
  `docs/bool-exemptions.json` 现状与棘轮脚本流程。
- 登记：8 个 public 类型进 `docs/component-registry.json`（三 target 全走，AD-2 原样适用）
  与 `docs/reachable-type-registry.json`；`EffectsColorLiteralGuard` 对本批零违规。
- 画廊：`App/Sources/ComponentData.swift` 补 8 个条目（⚠️ 串行写入窗口已随 `#256`
  关闭解除，但要确认主 checkout 侧无未合入的 App 改动——在 epic 分支 worktree 内写）。

## 验证（要有输出为证）

1. `swift build`（原生）+ `swift test --skip OhMyDesignShadersTests`（原生腿）绿。
   ⚠️ 已知 flake：位图判据偶发 1 LSB 红（#317），无关时重跑确认并记录。
2. `swift test --build-system swiftbuild --filter OhMyDesignShadersTests` 绿（macOS 本机）。
3. `xcodebuild test -scheme OhMyDesign-Package -destination 'platform=iOS Simulator,id=<UDID>'`
   ——RenderProofTests 是 `#if os(iOS)`，必须走这条腿才有 render proof 证据。
   权威条数取 .xcresult 顶层 passedTests。
4. 隔离判据三条 + `scripts/mainactor-static-ratchet.sh` + `cd scripts/downstream-probe && swift build`。
5. 变异实证（render proof）：把一个 shader 的时间项设成常数 ⇒ 采样恒等 ⇒ 判红；恢复。

## 完成判据（task 文件 DoD）

- Code implemented；Tests written and passing（含注入伪值的后台/低电量断言 + 像素采样）；
- 署名义务四条逐条落地；Code reviewed（走 superpowers-reviewer）。
