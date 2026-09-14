# #312 实施计划：组件样式扩展点 + 两条落点裁定

## 现状（开工时）

- `NetworkGraph` 已由 `#355` 以形态 D2 落地（红名单 5 → 4），本 issue 剩 4 条组件。
- `OrbitingLogos` 来源 2026-09-14 实测 HTTP 200、正文含 `OrbitingItem` 的
  `radiusX` / `radiusY` / `tiltAngle` props（留档 `/tmp/animata.html`，随 PR 进 `docs/issues/`）。
- `contract-defects.md` 的 J-2 描述失真已由 `#337` 先行修复（本 issue 开工时确认已合入）。

## 阶段 1：两条落点裁定（先裁定、后实现）

### 1a. `OrbitingLogos` 翻转裁定

- 把留档正文提取成可读文本存 `docs/issues/312-animata-orbiting-items.md`（注明抓取日期 /
  HTTP 200 / 关键 prop 行号），登记进 `docs/contract-defects.md` 的 `## #299` 节
  （`D-299-2` 与《`#315` 终审后复核》段）。
- 按 `D-299-2` 字面裁定：候选 4 来源已可核验、「同一组件 + 两个 props 决定轨道形状」
  成立 ⇒ 计入 2 ≥ 2 ⇒ **出口 1 ⇒ `semantic` ⇒ 需要扩展点**。
- 留痕改动：registry 三字段（`decidedBy` / `kind` / `needsExtensionPoint`）、
  J-2 红名单 +1（4 → 5）、`inspected.count` 16 → 17、`withKnownIssue` 文案、
  `R-48` 判定表——⚠️ 按 CLAUDE.md 更正传播约定 grep 三处落点。

### 1b. `D-299-1` 全口径重核（`RadarChart` / `ActivityHeatmap`）

谓词已放宽为「宿主平台框架的具名 API」，但这两条的「不命中」论证只查了 Swift Charts。
按 issue 给的两个具名反例做起点，逐条裁定：

| 条目 | 反例 | 要裁的问题 |
|---|---|---|
| `ActivityHeatmap` 候选 1（日历月视图） | `UICalendarView` + `UICalendarViewDecoration`（每日装饰） | UIKit 是「宿主平台框架」吗？「每日装饰」能否承载热力格（候选形态差异是否完整覆盖）？ |
| `RadarChart` 候选 2（径向柱状） | `SectorMark(angle:innerRadius:outerRadius:)`（逐 mark 可变 outerRadius） | `SectorPlot` 的逐元素 `MarkDimensions` 是否让候选「单一具名 API 直接可用」成立？ |

⚠️ 裁定的**标准**要与排除 `RingChart` 候选 2 时用的标准同构（「只能用 N 个手拼」vs
「单一具名 API 直接用」），结论写进 `docs/contract-defects.md` 的 `## #299` 节。
两种结果都合法，但**逐条留痕**：
- 裁定「计」⇒ 该组件计入数 3 → 1 < 2 ⇒ **落点退回步骤 4** ⇒ 不建扩展点、registry
  三字段按步骤 4 落盘（`decidedBy: D-299-1 修订` 之类，形态照既有条目）。
- 裁定「不计」⇒ 保持出口 1，进入阶段 2。

⚠️ 阶段 1b 的裁定结论直接决定阶段 2 的清单，**裁定文本本身是本 issue 的交付物**。

## 阶段 2：形态 D 扩展点（对阶段 1 裁定后仍处出口 1 的组件）

- 每条按「完整承载判定时枚举的候选形态差异」设计槽 / 枚举（候选清单见 issue 正文与
  登记表 `notes`；`BeforeAfterSlider` 计入 2：左右并排 / 上下并排）。
- ⚠️ **全部走形态 D**（`styleSlot` / `styleEnum`）——`D-299-1` 修订回路未走完，
  禁形态 B public 协议。形态 D 成立条件：填了不覆盖比不填更糟。
- 参考先例：`#355` 的 `NetworkGraph`（形态 D2）与登记表里已有 6 个形态 D 组件。

## 阶段 3：判据收缩与同步

1. `ComponentExtensionPointGuard.knownMissingExtensionPoints` 收缩为空集；
   `extensionPointFollowUpIssue` 与聚合断言一并删除；`withKnownIssue` 块按自身注释的
   到期机制删除。
2. `docs/components/*.md` 与登记表 `notes` 同步。
3. 变异实证：把某个已填扩展点的字段删掉 ⇒ 判据红；给一个非 semantic 条目乱加
   扩展点字段 ⇒ 判据红。每处变异先断言落地再跑。

## 验证

- `swift build` + `swift test`（macOS native）+ iOS Simulator 腿 xcodebuild。
- 判据计数（`inspected.count` 等）以实跑为准；改断言值要逐条写依据。
- `docs/component-registry.json` 的 schema 判据（`ComponentRegistryGuard`）全绿。

## 完成判据（issue 原文 4 条）

1. 各条扩展点在登记表填上且源码真实存在（或按 1b 裁定退回步骤 4 并留痕）；
2. 红名单空集化 + 到期机制删除；
3. `docs/components/*.md` 与登记表同步；
4. `OrbitingLogos` 裁定留痕（台账 + `docs/contract-defects.md`）。
