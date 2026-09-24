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

## 开工补充（2026-09-24，epic 同步 main 于 `843f884` 之后）

开工前实读现状，以下几条覆盖或细化上文。

### 上游固定版本

- paper-design/shaders：commit `43cd68db79fa0b1759f72ffc941b3238e2a3954c`（开工当日 `main`）。
  各 `.metal` 分节头写「paper `packages/shaders/src/shaders/<name>.ts` @ `43cd68d`」+ 修改清单。
  ⚠️ 开工第一步把这 7 个 `.ts` 与 `shader-utils.ts` 同 #280 核验时读到的特征行比一遍（参数名、描述句），
  不一致就停下回 provenance（#280 没记 commit，只能按特征行对）。
- StarNest：`GabeRundlett/shadertoy-api-shaders` @ `f6d538adf936` 的 `shaders/XlfGRj.json`
  `renderpass[0].code`（即 provenance ② 读过的那一版）。

### 命名

沿用已落地件的裸名（`Plasma` / `InkSmoke` / `DotGrid`），**不加 `Background` 后缀**：
`StarNest` / `Voronoi` / `Swirl` / `SimplexNoise` / `ColorPanels` / `DotOrbit` / `SmokeRing` / `Metaballs`。
`.metal` 入口统一 `ohMyDesign<Name>`（`ShaderEntryPointGuard` 的前缀判据）。

### 形参面

- 公开面：`tint: Color = .accent`、一个语义档位枚举（名称按件定，如 `Density` / `Scale`，三档）、
  `motion: ShaderMotion = .regular`。**不**照搬上游 uniform 列表（`.metal` 文件头既有纪律）。
- 调色：`ShaderRamp` 三档映射上游颜色数组（`colorBack` ← `ramp.low`；`colors` ← `mid` / `high` 按需循环）。
  上游「最多 N 色 + colorsCount」收成固定三色，属 §4(b) 修改，逐件写进分节头。

### 移植时必改的两处（逐件标注为修改）

1. **噪声纹理 → 程序化 hash**：paper 的 `textureRandomizer*` 读 `u_noiseTexture`；`colorEffect` 不带纹理，
   改用 `cd::hash21` / `cd::hash22`（#261 已重写、已登记出处）。
2. **`fwidth` → `cd::edgeWidth`**：`[[stitchable]]` 可见函数里没有屏幕空间导数，沿用既有替代。

### NFR-7 能耗闸（本 task 首个 commit，影响全部程序化背景）

现状：`ProceduralBackground` 只有 Reduce Motion 冻结，**没有接能耗闸**（已落地 6 件同样没有）。
在骨架上接 `EnergyState.resolve(...).presentation(reduceMotion:)`：
`.hidden` ⇒ 只画底色（不建 `TimelineView`）、`.resting` ⇒ 冻结、`.animated` ⇒ 按 `policy.minimumInterval` 调度。
判定抽成 `static` 纯函数，注入 `scenePhaseOverride` / `lowPowerModeOverride` 伪值逐格断言。
⚠️ 「`.hidden` 画底色而非什么都不画」须写明理由（背景层完全透明会露出宿主底色、布局跳变），并对照
`EnergyPolicy.swift` 的 `drawsAnything` 语义在 doc 注释里说清差异。

### 署名（逐件）

- paper 7 件：`ACKNOWLEDGEMENTS.md` 的 paper 段把「部分落地 · `#283`」扩到 8 件（halftone + 7），逐件列 `.ts` 路径与修改摘要。
- Ashima Arts / Stefan Gustavson（MIT）：`Swirl` / `SimplexNoise` 用到 `shader-utils.simplexNoise` ⇒ 新增 MIT 通知段（现 ACK 没有）。
- iq（MIT）：`Voronoi` 的两趟边界算法 ⇒ 既有 iq 段追加适用件。
- StarNest（MIT）：启用 ACK 里的占位段；按 provenance ② 的两条瑕疵如实写（形式不完整的 MIT 授予）。
- `docs/shader-provenance.md`：8 件状态改「已落地」，写落地 commit。

### 登记与计数（按实跑结果改，不预估）

registry `components` +8（`ComponentRegistryGuard` 条数、`kind` / `decidedBy` 按 5 个既有背景件的 `tiebreaker` 口径逐件判）、
README 的 Shaders 子表、digest（`components` / `enums` / `enumcases`）、`ShaderEntryPointGuard` 手工清单、
`ShaderLibraryLoadTests` 函数清单、`RenderProofTests.Background`、画廊 `shaderEntries`、downstream-probe 的 Shaders 值类型调用点（若 #284 未做则只加本批）。

### 执行顺序与分批

1. T0：能耗闸（骨架 + 纯函数测试）。
2. T1：批 A（`Metaballs` / `DotOrbit` / `Voronoi` / `SmokeRing`）——逐件：移植 → Swift 包装 → `#Preview` → 档位测试 → render proof（非纯色 + 随时间变化）→ 署名 → 登记。每件一个 commit。
3. T2：批 B（`Swirl` / `SimplexNoise` / `ColorPanels` / `StarNest`），同上。
4. T3：画廊、README、digest、provenance 收口。

### 验证补充

- 每件 render proof 的变异：把该件 `.metal` 的时间项替换成常数 ⇒ 「随时间变化」判红；
  把一个空间项替换成常数 ⇒ 「非纯色」仍应绿或红要逐件说明（不是所有 shader 都只靠一个空间项）。
- 预览宿主构建（清 derivedData、核三样）；画廊加了 8 个条目。
