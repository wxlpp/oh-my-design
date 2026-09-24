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

### 移植时的修改（逐件写进 `.metal` 分节头，属 §4(b) 修改标注）

1. **噪声纹理 → 程序化 hash**（Voronoi / DotOrbit / SmokeRing / Metaballs 四件）：paper 的 `textureRandomizer*` 读
   `u_noiseTexture`；改用 `cd::hash21` / `cd::hash22`（与 paper `randomR/GB` 同为 `floor` 语义）。
   `dot-orbit.ts:82` 的 `randomR(vec2(rand.x, rand.y))` 在上游就恒为常数，照搬、不"顺手修"；
   Metaballs 的 1D `noise(float)` 用 `cd::hash21(float2(i, 0))`；SmokeRing 的 `valueNoise` 复用 `cd::valueNoise`（按复用登记，不复制）。
2. **`fwidth` 经 `cd::edgeWidth`**（Metaballs / DotOrbit / Swirl / SimplexNoise 四件）：`fwidth` 在 `colorEffect` 里可用
   （DotGrid / LiquidChrome 已在用），改走 `cd::edgeWidth` 只为加 `1e-4` 下限、避免 0/0。Voronoi / ColorPanels 用 `u_scale`
   解析 AA，SmokeRing / StarNest 不涉及。
3. **`colorBandingFix` 丢弃**（五件带它）：它的 `12.9898 / 78.233 / 43758.5453123` 常量组 ACK 已登记为「本仓任何代码都不含」
   的预防性留痕，保持该句为真；丢弃列为修改。
4. **颜色数组 → 三档**：见下《调色映射》。
5. Voronoi 分节头原样保留 `voronoi.ts:14` 的 `Original algorithm: …/ldl3W8`（§4(c) 的 attribution notice）；
   Swirl / SimplexNoise 的分节头放一行 `Copyright (C) 2011 by Ashima Arts` + 指向 ACK 的 MIT 段。

### 调色映射（逐件，FR-8：`.metal` 零硬编码色）

| 件 | 映射 |
|---|---|
| Metaballs / DotOrbit / SmokeRing / Swirl | `colorBack` ← `ramp.low`；`colors` ← `mid` / `high` 循环 |
| ColorPanels | 同上；固定 2–3 色时 `panelsNumber` 恒为 12、normalizer 为 1，写进分节头 |
| Voronoi | gap ← `low`、cell ← `mid`、glow ← `high` |
| SimplexNoise | 无 `colorBack`；三档作阶梯色，**档位枚举承载 `stepsPerColor`**，否则与 `FractalClouds` 难以区分 |
| StarNest | 上游**无颜色输入**（`vec3(s, s*s, s*s*s*s)` 是硬编码色调）⇒ 改为标量（`length(v)`）经 `cd::ramp3`；丢掉上游按距离的冷暖色调，写进分节头 |

### Bool 纪律

Shaders 的 1 条预算已被 `View.refractiveGlass#isEnabled` 用掉 ⇒ **本批 0 条**。ColorPanels 的 `u_edges` 折进档位枚举或不暴露。
新档位枚举一律 `public nonisolated enum`（照 `Plasma.Density`，否则撞 MainActor 棘轮）。

### NFR-7 能耗闸（本 task 首个 commit；影响 5 个走 `ProceduralBackground` 的既有件）

- 形态：`EnergyState.resolve(...).presentation(reduceMotion:)` 三态 →
  `.animated` ⇒ `TimelineView(.animation(minimumInterval: policy.minimumInterval))`；
  `.resting`（RM）⇒ 暂停、时间归零（既有行为）；
  `.hidden`（后台 / inactive）⇒ **暂停 `TimelineView`、保留最后一帧**（不归零、不画底色、不整层不建）。
- ⚠️ 这偏离 `AnimatedMeshGradient` / `ProcessingSweep` 的先例（`.hidden` ⇒ `EmptyView()`）与 `RenderPolicy.drawsAnything`
  的 doc（「整层不建」），理由写进 doc 注释：背景件是内容的衬底，`.inactive` 时画面仍可见（控制中心 / App 切换器），
  整层消失或闪成平色都会被看见；暂停的 `TimelineView` 不再产生帧，满足「停摆」的能耗目的。
- 判定抽成 `static` 纯函数（presentation → paused / minimumInterval / 是否归零），**保留** `elapsed(at:origin:motion:reduceMotion:)`
  原签名（`AccessibilityBehaviorTests` 四条不动），两者组合。`.accessibilityHidden(true)` 三态都保留。
- ⚠️ `ImageRenderer` 离屏渲染没有 Scene，`scenePhase` 读到 `.background` ⇒ `RenderProofTests` 的渲染入口统一注入
  `.environment(\.scenePhaseOverride, .active)`（Effects 测试的先例），同一 commit 落地。
- T0 验收：纯函数逐格（`scenePhaseOverride` × `lowPowerModeOverride` × RM）+ **iOS 腿跑一遍**（`.xcresult` 顶层 `passedTests`）
  再开 T1。

### 登记与计数（按实跑结果改，不预估）

registry `components` +8（`ComponentRegistryGuard` 条数；`kind` / `decidedBy` 按 5 个既有背景件的 `tiebreaker` 口径逐件判）、
README 的 Shaders 子表、digest（`components` / `enums` / `enumcases`）、`ShaderLibraryLoadTests.entryPoints` 手工清单
及其显示名「八个入口」、`PlasmaTests.swift` 头注的测试计数、`RenderProofTests.Background`。
⚠️ **不**登记 `docs/reachable-type-registry.json`：该表只收有文案参数的类型（J1：空 `textParams` 应删整条），本批无文案参数。
⚠️ 画廊 `shaderEntries` 与 downstream-probe 留给 #284（probe 的 manifest 还没链 `OhMyDesignShaders`；画廊该节注释已写明 B-4 复用），
本 task 只保证预览宿主仍能构建。

### render proof 的时间通道

各新 public struct 加 internal `originOverride: Date?`（默认 `nil`，透传给 `ProceduralBackground`），
`RenderProofTests.Background` 能构造带它的实例 ⇒ 「随时间变化」参数化到全部件，不再手写 `library.ohMyDesign…(...)`。
变异逐件做：时间项 → 常数 ⇒ 该件「随时间变化」判红。

### 署名（逐件）

- paper 7 件：`ACKNOWLEDGEMENTS.md` paper 段扩到 8 件（halftone + 7），逐件列 `.ts` 路径 @ `43cd68d` 与修改摘要。
- Ashima Arts / Stefan Gustavson（MIT）：新增通知段（Swirl / SimplexNoise）。
- iq（MIT）：既有段追加 Voronoi。
- StarNest（MIT）：ACK 占位段**重写**（现段仍写着已被第 6 轮终审撤回的「五个独立移植逐字一致」），按 provenance ② 的两条瑕疵如实写。
  ⚠️ **人工目视确认 `shadertoy.com/view/XlfGRj` 原页许可头是硬 AC、只能由用户做**（站点对 agent 403）：
  StarNest 排在批 B 最后；未确认前 provenance 标「待人工目视」，**epic → main 前向用户转手**，ACK 照抄用户读到的页面写法。
- `docs/shader-provenance.md`：8 件状态改「已落地」，写落地 commit。

### 执行顺序与分批

1. T0：能耗闸（骨架 + 纯函数 + render harness 注入 `.active`）→ iOS 腿验证。
2. T1：批 A（Metaballs / DotOrbit / Voronoi / SmokeRing），逐件：移植 → Swift 包装（含 `originOverride`）→ `#Preview` → 档位测试 → render proof → 署名 → 登记，每件一个 commit。
3. T2：批 B（Swirl / SimplexNoise / ColorPanels / StarNest），同上；StarNest 的性能：档位直接驱动 `volsteps` / `iterations`（上游 20 × 17），写进分节头并交 #284 的性能基准。
4. T3：README、digest、provenance、ACK 收口；预览宿主构建。

### 验证补充

- 每件 render proof 变异：时间项 → 常数 ⇒「随时间变化」判红。
- iOS 腿在 T0 后、T1 后、T2 后各跑一次（render proof 只在 iOS）。
