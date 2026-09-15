# #312 裁定与设计规格：OrbitingLogos 落点 · D-299-1 全口径重核 · 五个组件的形态 D 扩展点

基线：`issue-312-extension-points` @ `52412ce`（= `epic/issue-backlog-closeout`）。写于 2026-09-16；同日按设计评审（C-1 / I-1…I-4 / S-1…S-8）修订。

证据分三档，全文逐条标注：
- **【实测】** 我在本机跑过命令、读过文件原文（引文逐字）。
- **【转述】** 来自仓内文档 / issue 正文的声称，本轮未独立复核。
- **【设计】** 我的设计判断，不是事实。

---

## 0. 结论摘要

| 裁定 | 一句话结论 |
|---|---|
| **A. `OrbitingLogos` 落点** | **翻到出口 1**（`decidedBy: step2` / `kind: semantic` / `needsExtensionPoint: true`）。候选 4 的来源已随 `416d06c` 留档进仓（`docs/issues/animata-orbiting-items-3d-2026-09-14.html`，HEAD 的祖先、已跟踪），来源义务与 `D-299-2` 的两种读法都过 ⇒ 计入 ≥2。09-07 那次 403 **不再构成阻碍**：纪律要求的是「真的查过」，留档就是查过的证据，不依赖今天能否取页。翻转走修订回路（新 `## #312` 节 + R-49 + 公约现状注记），落点清单见 §1.3。 |
| **B. `D-299-1` 全口径重核** | 两条具名反例**都不构成**与排除 `RingChart` 候选 2 同构的「单一具名 API 直接承担」：`SectorMark` 的半径是布局尺寸（`MarkDimension`），不是数据通道，径向柱状仍是手拼；`UICalendarView` 只在 iOS 存在（`MacOSX26.sdk` 无 UIKit，`MultiDatePicker` 在 macOS `unavailable`），对 iOS 26+ / macOS 26+ 双平台的设计系统不是完整承担者。⇒ `RadarChart` 3 → 2 不翻（按「本职」判据，信心中）；`ActivityHeatmap` **口径未定**——双平台口径 3 → 2 不翻、iOS 单平台口径 3 → 1 会翻；`RingChart` **至少**会翻（与 `D-299-1` 真源「至少」口径一致，不写回「唯一」）。**`312-plan.md` 阶段 1b「裁定『计』⇒ 落点退回步骤 4」不成立**：条件 ① 未经修订回路扩宽前，重核结论只能登记进 `D-299-1` 的代价表，落点按现行字面保持出口 1。 |
| **C. 形态 D 设计** | 五个组件全部走 **D2 配置枚举**（`RadarChartLayout` / `RingChartLayout` / `ActivityHeatmapLayout` / `BeforeAfterSliderLayout` / `OrbitingLogosLayout`），每个枚举的 case 与判定时计入的候选一一对应、默认 case = 现状画法、`public nonisolated enum … : Sendable, Equatable, CaseIterable`、`init` 加带默认值的 `layout:` 参数（位于闭包参数之前，见 §3.0），BREAKING-CHANGES 登记一节。逐 case 渲染规格与判据见 §3。 |

**需用户决策的事项**（本文不自行假定）：

1. **是否在本 issue 顺带走完 `D-299-1` 的修订回路**（§2.5）。我的建议是**不走**：走回路要先把「宿主平台框架」这个谓词成文（含平台口径、「本职形态」判据），并回写公约 §1 作用域条款，那是另一件事；本 issue 只把重核结果登记进代价表。代价：`RingChart` 的 `RingChartLayout` 会在「已确证若扩宽就会翻」的状态下发布，处置方案见 §3.2.5。
2. **`OrbitingLogos` 翻转与其扩展点是否同一 PR 落地**（§1.4）。建议同一 PR、同一提交，避免红名单经历 4 → 5 → 0 的中间态。
3. **`RingChartLayout.segmentedRings` 的分段数固定为 10**（§3.2.2）——Ant Design 的 `steps` 是调用方可配的；固定值是有意的取舍（保持枚举无关联值、`CaseIterable` 可合成）。若用户要可配，须现在决定（事后加关联值是 source-breaking）。

---

## 1. 裁定 A：`OrbitingLogos` 落点

### 1.1 结论

**翻到出口 1。** 登记表三字段：`decidedBy: tiebreaker → step2`、`kind: prescriptive → semantic`、`needsExtensionPoint: false → true`；扩展点形态见 §3.5。

### 1.2 依据

**(a) 公约步骤 2 的操作化门槛与来源义务**【实测，`docs/component-contract.md`】：

> ⚠️ **操作化门槛**：能**当场举出 ≥2 个业界真实存在的替代形态**才算「会」（**替代 = 不含组件当前的形态**）。

> ⚠️ **来源义务覆盖任何计入 ≥2 的候选**（不只是「≥3」分支）：每个候选都要给**可核验的来源**——**设计体系名 + 具体形态**，或**产品名 + 场景**。

**(b) 现行落盘的计入数与它的唯一缺口**【实测，`docs/contract-defects.md` 《`#315` 终审后复核》段】：

> ⇒ **后果**：候选 4 现在**过得了来源义务**；而且它是「**同一个组件**、两个 props 决定轨道是圆还是椭圆」（`radiusX == radiusY` 即圆）⇒ 连 `D-299-2` 那把「须是本组件的另一种长相」的尺子也过得了。⇒ **按公约字面，`OrbitingLogos` 的计入数应为 2（候选 1 多轨道分布 + 候选 4 椭圆轨道）≥ 2 ⇒ 落出口 1 ⇒ `semantic` + `needsExtensionPoint`**，而不是本 PR 落盘的步骤 4。

同段给出的「本轮不翻」主理由逐字：「**① 下游连锁应当单独过一次评审（这是主理由）**」与「**② 这是一条到期项**」——两条都指向本 issue：本 issue 就是那次单独评审。可逆性一条已被同段自行降级（「本条留在此处只作留痕，**不再作为推迟的依据**」）。

**(c) 来源已留档，且留档本身可核验**【实测】：

- 文件 `docs/issues/animata-orbiting-items-3d-2026-09-14.html`，355.8 KB，`git ls-files --error-unmatch` 返回 TRACKED；提交 `416d06c 2026-09-14 docs(issues): #312 OrbitingLogos 来源留档——Animata Orbiting Items 3D（HTTP 200，2026-09-14 抓取）`；`git merge-base --is-ancestor 416d06c HEAD` 为真，对 `epic/issue-backlog-closeout` 亦为真。
- 从留档 HTML 剥掉标签后逐字读到（python 提取，命令见附录 A）：
  - 组件自述：“List component with orbiting items. The items orbit around the center of an element in 3D Ellipse.”
  - props 接口：`interface OrbitingItems3DProps { /** * The radius of the ellipse on X-axis in percentage, relative to the container. */ radiusX : number ; /** * The radius of the ellipse on Y-axis in percentage, relative to the container. */ radiusY : number ; /** * The angle at which ellipse is tilted to x-axis. */ tiltAngle : number ; …`
  - 内部子组件 `function OrbitingItem ({ index , radiusX , radiusY , totalItems , tiltAngle , duration , children , } …`。
  与 `D-299-2` 复核段记的三句 props 说明逐字一致。

**(d) 09-07 那次 403 是否仍构成阻碍——不构成**【实测 + 推理】：

- issue 评论（2026-09-07）的阻碍逻辑是：「按『只写真的查过的来源』与『实测的数必须能复现』两条纪律，我不能据一份自己读不到的页面去翻一个落点」，并给出三条出路，其中第 2 条逐字：「**留档**：若真能取到 200，**当场把正文存下来**（`docs/issues/` 或 PR 附件），而不是只记一句『实测 200』」。
- 留档正是那条出路。留档后「查过」由仓内文件证明，「可复现」由任何人读该文件证明，两条纪律都不再依赖取页成功。
- 附带读数（**不是**依据）：本机今日 `curl -s -o /dev/null -w "%{http_code} %{size_download}" --max-time 15 https://animata.design/docs/list/orbiting-items-3-d` 得 `200 362024`。这只说明今天取得到，取页结果本就不稳定（09-05 200 / 09-07 403 / 09-14 200 / 09-16 200），与裁定无关。

**(e) `D-299-2` 的读法不必在本 issue 裁**：两种读法下计入数分别为 2（同组件版本读法：候选 1 + 4）与 4（操作化门槛字面：候选 1–4），都 ≥ 2，落点相同。`D-299-2` 仍作为公约缺陷留待修订回路。但它**影响 D2 的 case 集合**（§3.5.1）。

**(f) 为什么这不是「事后补写翻转」**：公约「事后补写的效力边界」逐字：「要翻转，必须走**公约修订回路**——记入 `docs/contract-defects.md` → 回写本公约 → 在 `docs/component-contract-revisions.md` 逐条留痕——**不能只改一条 `notes`**」。本裁定按该回路走（§1.3），不是 notes 补写。

### 1.3 修订回路的逐处落点

| # | 文件 / 位置 | 要写什么 |
|---|---|---|
| 1 | `docs/contract-defects.md` 新增 `## #312` 节（文件头规矩逐字「零缺陷也要写『零缺陷』」） | 三段：**裁定 A 留痕**（结论 + 依据 (b)(c)(d) + 留档路径与 commit）；**裁定 B 重核表**（§2.6 的表）；**D-312-1**（若用户同意登记，见 §3.2.5）。 |
| 2 | 同文件 `D-299-2` 末尾与《`#315` 终审后复核》段末尾 | 各追加一行「**`#312` 处置（只增不删）**：已按本段字面翻转，见 `## #312`」。只增不删——本文件惯例（`D-59-1` 节自陈「本段原文一字未改」）。 |
| 3 | `docs/component-contract-revisions.md` 新增 **R-49** | 7 字段齐全：来源试点 `#312`；撞上「事后补写的效力边界」+ 步骤 2 来源义务；改动前逐字 = 公约 §1 实测状态段那句「1 条（`OrbitingLogos`）落**步骤 4**；判定法结论已产出、扩展点实现未跟上，移交 `#312`。」；改动后 = 追加的现状注记；落点 = 公约三处注记；连带改动 = registry 三字段 + `styleEnum` + J-2 判据 + 组件文档；验证 = 判据实跑读数。 |
| 4 | 同文件 `R-48` 的「`#315` 终审后的逐条更正」表 | **追加一行**（不改既有 `OrbitingLogos` 行）：「`OrbitingLogos` \| 已知过期项（计入 1 ⇒ 步骤 4） \| **`#312` 已裁定翻至出口 1**，见 R-49 \| `#312`」。R-48 那句「本条台账写于 `#299` 本轮、尚未合并 ⇒ 上表直接改」的前提已不成立（PR #315 已合并），故只增不改。 |
| 5 | `docs/component-contract.md` 三处现状注记（`grep -n "#312" docs/component-contract.md` 命中 :327-329 / :1042-1047 / :1717） | 各**追加**一句「⚠️ **再一次更新（`#312` 收口）**：`OrbitingLogos` 经修订回路翻至出口 1（R-49），J-2 定义域 **17** 条；五条扩展点全部以形态 D2 落地，`knownMissingExtensionPoints` **回到空集**、`withKnownIssue` 块按到期机制删除。」原句一字不动（living document 不写行号）。:1598 那句「第 6 条 `OrbitingLogos` 落步骤 4，仍不进定义域」属 `#270`/`#299` 当时记录，同样只追加注记。 |
| 6 | `docs/component-registry.json` `OrbitingLogos` | 三字段翻转 + `styleEnum: "OrbitingLogosLayout"`；`notes` 追加「`#312` 裁定」段（留档路径、计入 2 ⇒ 出口 1、D2 落地）。**必须保留**逐字指针 `` `docs/contract-defects.md` 的 `D-299-2` ``（`SingleSourceOfTruthGuard.d2SitesPointBack` 断言）；**不得**写入 `sourceOnly` 短语（`3D Ellipse` / `基数统一为 2` / `第 2 轮终审 F-4` 等，逐字清单在 `SingleSourceOfTruthGuard.sourceOnly`）。 |
| 7 | `Tests/OhMyDesignTests/ComponentExtensionPointGuard.swift` | `inspected.count == 16` → `== 17`；失败文案的 16 个名字清单加 `OrbitingLogos`（按字母序插在 `NetworkGraph` 后）。红名单处置见 §4.1。 |
| 8 | `docs/components/orbiting-logos.md` | 新增小节「`#312` 裁定：`tiebreaker` → `step2`（出口 1）」（只增不改，与 `network-graph.md` 的 `#299` 重判小节同形）+ 新增「扩展点（`#312` · 形态 D2）」节 + API 块加 `layout:`。**保留**逐字指针 `` `docs/contract-defects.md` 的 `D-299-2` ``（`landingSitesD2` 断言）。 |
| 9 | `CLAUDE.md` :64 与 `AGENTS.md` :66 | 「`ComponentExtensionPointGuard` 的 `inspected.count`（**实测 16**…）」→ 17。两份必须同改（`AgentGuideSyncGuard`）。 |
| 10 | `docs/README.md` :184 | `OrbitingLogos(_:logo:center:)` → `OrbitingLogos(_:colors:rotationPeriod:layout:logo:center:)`（按该表现有写法只列标签）。 |

**写着「翻转移交 #312」「4 条 → 5 条」「16 → 17」的副本清单**【实测，命令与命中见附录 B】：

| 文件:行 | 句子 | 处置 |
|---|---|---|
| `docs/contract-defects.md:2661` | 「…翻转移交 `#312`。」 | 追加一层注记「已由 `#312` 兑现」（不改写） |
| `docs/contract-defects.md:2685` | 「**本轮处置：不翻转落点，如实登记，翻转移交 `#312`。**」 | 同上 |
| `docs/contract-defects.md:2690` | 「（实测 16 → 17）、`knownMissingExtensionPoints`（实测 5 条 → 6 条 —— ⚠️ **`#312` 之后这两个数各减一**…翻转是 **4 条 → 5 条**…）」 | 同上；勿再叠第三层数字，只写「已兑现，最终态见 `## #312`」 |
| `docs/contract-defects.md:2721` | 「⇒ **整行冻结**，过期项在表后注记 + 翻转移交 `#312`。」 | 同上 |
| `docs/component-contract-revisions.md:2154` | R-48 更正表 `OrbitingLogos` 行 | 追加新行指向 R-49（落点 4） |
| `docs/component-contract-revisions.md:2230-2232` | 「`inspected.count` 实测 16 → 17、红名单 5 → 6…翻转是 **4 条 → 5 条**…」 | 追加注记 |
| `docs/component-registry.json:531`（`OrbitingLogos.notes`） | 同一段样板（含「翻转移交 `#312`」「4 条 → 5 条」「16 → 17」） | notes 是活文本，按 `NetworkGraph.notes` 先例改写为「已由 `#312` 落地 …（曾…）」 |
| `docs/components/orbiting-logos.md:264 / :290 / :320-322` | 同一段样板三处 | 追加 `#312` 小节，原句保留 |
| `.claude/epics/issue-backlog-closeout/312.md:24,45-46` / `312-plan.md:20` / `epic.md:52` / `.claude/prds/issue-backlog-closeout.md:58` | 任务文件里的「16 → 17」「4 → 5」 | 非活文档，直接改成最终态 |

### 1.4 落地顺序建议【设计】

翻转 + 扩展点 + 判据收缩放**同一提交**：registry 三字段翻转的那一刻 `OrbitingLogos` 进入 J-2 定义域，若此时源码没有 `OrbitingLogosLayout`，只能靠把它塞进 `knownMissingExtensionPoints`（红名单 4 → 5）过渡——那是本 issue 要清空的集合，没必要先长后删。若用户坚持裁定先行单独提交，则过渡态须同时：红名单 +1、`notes` 写 `#312`（`extensionPointFollowUpIssue` 聚合断言）、`withKnownIssue` 文案改「5 条」。

---

## 2. 裁定 B：`D-299-1` 全口径重核

### 2.1 同构标准

排除 `RingChart` 候选 2 时的原话【实测，`D-299-1` 判定表 `RingChart` 行】：

> 候选 2 分段进度条 —— Swift Charts 无「分段进度」概念，只能用 N 个 `BarMark` 手拼

以及 F-2 段的对比句：

> ⚠️ **这两条与排除 `RingChart` 候选 2 时用的标准不同类**：那里的理由是「只能用 N 个 `BarMark` 手拼、不是现成能力」，而这两条是**单一具名 API 直接用**。

把它操作化成三条，缺一即「不计」（前两条是原标准的展开，第三条是本轮补的、需经回路成文）：

1. **具名**：宿主平台框架里有一个具名 API；
2. **本职**：该 API 的本职形态就是候选形态——**数据到几何的映射由框架完成**，调用方不必手工归一化 / 用 N 个通用 mark 拼出该概念（这正是 `ProgressView(value:)` 与「N 个 `BarMark` 手拼」的分野）；
3. **平台**【设计，待成文】：在本设计系统声明的全部宿主平台上可用（`CLAUDE.md` 逐字「目标平台为 iOS 26+ / macOS 26+」）。理由：作用域条款的本意是「想要那种观感」的正确答案是**换用那个承担者**（公约原文），macOS 消费者换不了 UIKit。`D-299-1` 已计入的三个承担者（`BarMark` / `LineMark` / `ProgressView(value:)`）都满足本条，故本条与既有判定同向。

### 2.2 `RadarChart` 候选 2（径向柱状）↔ `SectorMark(angle:innerRadius:outerRadius:)`

**事实**【实测，`iPhoneOS26.4.sdk` 的 `Charts.swiftmodule/arm64e-apple-ios.swiftinterface`】：

- `SectorMark` 唯一 init：`nonisolated public init(angle: Charts.PlottableValue<some Plottable>, innerRadius: Charts.MarkDimension = .automatic, outerRadius: Charts.MarkDimension = .automatic, angularInset: CoreFoundation.CGFloat? = nil)` —— 只有 `angle` 是 `PlottableValue`（进比例尺 / 轴）；半径是 `MarkDimension`。
- `MarkDimension` 的存储逐字：`case automatic` / `case fixed(CoreFoundation.CGFloat)` / `case ratio(CoreFoundation.CGFloat)` / `case inset(CoreFoundation.CGFloat)` —— 布局尺寸，不接数据域。
- `SectorPlot` 的 `MarkDimensions<DataElement>`（iOS 18+）确有逐元素形态：`public static func ratio(_ keyPath: Swift.KeyPath<DataElement, CoreFoundation.CGFloat>) -> Charts.MarkDimensions<DataElement>`（`fixed` / `inset` 同款）。**`D-299-1` 表里「`SectorPlot` 更给出逐元素的 `MarkDimensions<DataElement>`」这句成立**，本轮核实。但 keyPath 指向的是 `CGFloat` **比例**，调用方要自己把值除以最大值——没有径向比例尺、没有径向轴。

**「径向柱状」的两种读法**：

- AntV G2 `radial` 的自述（registry `notes` 逐字）：“A special polar coordinate system obtained by transposing polar coordinates, commonly used for radial bar charts” —— 转置极坐标：每个类目一条**弧形条**，值编码在**扫过角**上、各条起点对齐。`SectorMark` 把各扇区**依次首尾相接**排满一圈，没有「每条从 0° 起画」的入口 ⇒ 这一读法下 Swift Charts **根本表达不了**。
- 玫瑰图读法（每维一根从圆心向外的条、等角宽、值编码在半径）：`ForEach { SectorMark(angle: .value(_, 1), outerRadius: .ratio(v / vMax)) }` 或 `SectorPlot(data, angle: …, outerRadius: .ratio(\.normalized))` 能画。但半径映射由调用方手工归一化、无轴、无网格，`SectorMark` 的本职是饼 / 环（按占比切分角度）。

**裁定：不计。** 两种读法下都不满足 2.1 第 2 条：要么表达不了，要么是「拿饼图 mark 把半径当布局尺寸手拼一个径向柱状」，与「N 个 `BarMark` 手拼分段进度」同类。信心：**中**——这是判断题，不是事实题；反对意见（「`SectorPlot` 一次调用就出 N 个扇区，够直接了」）有立足点，故本条务必登记进 `D-299-1` 供抽查，不当既定事实传播。

⇒ `RadarChart` 全口径：只有候选 3（`BarMark`）命中 ⇒ 3 → 2 ≥ 2，**不翻**。

### 2.3 `ActivityHeatmap` 候选 1（日历月视图）↔ `UICalendarView` + `UICalendarViewDecoration`

**事实**【实测】：

- `UICalendarView.h`：`UIKIT_EXTERN API_AVAILABLE(ios(16.0)) API_UNAVAILABLE(watchos, tvos) NS_SWIFT_UI_ACTOR` / `@interface UICalendarView : UIView`；`#pragma mark - Decorations`；delegate 方法 `- (nullable UICalendarViewDecoration *)calendarView:(UICalendarView *)calendarView decorationForDateComponents:(NSDateComponents *)dateComponents;`（逐日装饰）；另有 `wantsDateDecorations` 与 `reloadDecorationsForDateComponents:animated:`。
- `UICalendarViewDecoration.h`：`- (instancetype)initWithImage:(nullable UIImage *)image color:(nullable UIColor *)color size:(UICalendarViewDecorationSize)size;`（三档 `Small / Medium / Large`）与 `+ (instancetype)decorationWithCustomViewProvider:(UIView *(^)(void))customViewProvider;`（任意视图）。⇒ **热力格的色阶强度可以承载**：逐日回一个按桶取色的 decoration（或自定义视图），四档桶正对应色阶。
- **macOS 侧**：`MacOSX26.sdk/System/Library/Frameworks/UIKit.framework` **不存在**（`ls` 报 No such file）；SwiftUI 的 `MultiDatePicker` 在 iOS 与 macOS 两份 swiftinterface 里都标 `@available(macOS, unavailable)`，且它没有装饰 API；AppKit `NSDatePicker.h` 的 `grep -ci decorat` = **0**。

**裁定：平台分叉。**

- iOS 单平台口径：**计**。装饰是文档化的现成能力，`UICalendarView` 的本职就是月视图，逐日装饰把「每日读数排成月历」这一候选形态直接承担了（候选来源 Apple Activity History 页本身就是这个形态）。
- 双平台口径（2.1 第 3 条）：**不计**。macOS 上没有任何承担者，「换用那个承担者」对本包一半的宿主不成立。

哪一种口径适用，正是 `D-299-1` 未成文的谓词内容，本 issue 不能自行定。⇒ **结论待口径成文**：按 2.1 第 3 条（待成文）不计 ⇒ 3 → 2 不翻；按 iOS 单平台口径计 ⇒ 3 → 1 会翻。两者并列登记，不择一。

### 2.4 `312-plan.md` 阶段 1b 的矛盾：重核结论不能直接改落点

`312-plan.md` 逐字：「裁定『计』⇒ 该组件计入数 3 → 1 < 2 ⇒ **落点退回步骤 4** ⇒ 不建扩展点」。**这条不成立**，依据：

- `D-299-1` 的处置段逐字：「**本轮处置**：**不改落点**。`#299` 按公约**字面**走完判定法（三个候选均未被排除 ⇒ 非皮肤候选数 3 ≥ 2 ⇒ 出口 1），**没有**拿一条未成文的规则去翻转结论 —— 那正是『事后补写的效力边界』小节禁止的形态。缺陷登记于此，是否把作用域条款的条件 ① 扩成『本设计系统的具名组件**或宿主平台框架的具名 API**』，另走修订回路。」
- 作用域条款现行字面条件 ① 逐字：「**被点名的兄弟组件必须真实存在于 `docs/component-registry.json`**」。`SectorMark` / `UICalendarView` 都不在登记表 ⇒ 条款**援引不了** ⇒ 候选不能被排除 ⇒ 计入数不变 ⇒ 落点不变。
- 「计 / 不计」回答的是一个**反事实**（「若条件 ① 被扩宽，这条候选会不会被排除」），它只喂 `D-299-1` 的代价表（逐字「若将来条件 ① 被扩宽，**至少 `RingChart` 的落点会真的翻**…这两条**不能**声称不翻」）。本轮把「不能声称不翻」收成「按全口径不翻」，就是对那张表的更新。

⇒ 阶段 1b 的两个分支应改写为：**无论裁定结果如何，落点都保持出口 1，进入阶段 2；裁定结果写进 `D-299-1`。**

### 2.5 是否顺带走完 `D-299-1` 修订回路 —— 需用户决策

| 方案 | 做什么 | 后果 |
|---|---|---|
| **甲（建议）**：不走 | 只把 §2.6 的表追加进 `D-299-1`；作用域条款不动 | 五条扩展点全部落地；`RingChart` 的枚举在「若扩宽则翻」状态下发布，处置见 §3.2.5；`D-299-1` 继续挂着 |
| 乙：走 | 先成文谓词（平台口径、「本职形态」判据、由谁核验），回写公约 §1 作用域条款条件 ①，R-50 留痕；然后 `RingChart` 按新条款重判 ⇒ 3 → ≤1 ⇒ 步骤 4 ⇒ `prescriptive` / 不给扩展点 ⇒ 不做 `RingChartLayout`；J-2 定义域 17 → 16 | 少发一个可能要撤的枚举；但本 issue 范围扩成公约修订，且 `ActivityHeatmap` 在平台口径未定时仍悬 |

建议甲的理由：issue 正文自己把排序约束定为「回路走完前不得走形态 B」而非「不得走形态 D」，并明写「优先形态 D」；`D-299-1` 的谓词成文牵涉平台口径这类新裁决，不该挟在扩展点实现里。

### 2.6 写进 `D-299-1` 的重核表（供实现者照抄）

| 条目 / 候选 | 具名 API | 2.1 ① 具名 | 2.1 ② 本职 | 2.1 ③ 双平台 | 全口径结论 | 计入数 |
|---|---|---|---|---|---|---|
| `RadarChart` 候选 2 径向柱状 | Swift Charts `SectorMark` / `SectorPlot` | 是 | 否（半径是 `MarkDimension` 布局尺寸，无径向比例尺；G2 `radial` 的弧形条无法表达） | 是 | **不计** | 3 → 2，不翻 |
| `ActivityHeatmap` 候选 1 日历月视图 | UIKit `UICalendarView` + `UICalendarViewDecoration` | 是 | 是（逐日装饰是文档化能力，可承载四档色阶） | **否**（macOS 无 UIKit；`MultiDatePicker` macOS unavailable 且无装饰 API；`NSDatePicker` 无装饰） | **待口径成文**（双平台口径不计 / iOS 单平台口径计） | 双平台 3 → 2 不翻；单平台 3 → 1 会翻 |
| `RingChart`（已判） | — | — | — | — | 不变 | 3 → ≤1，**至少**这一条会翻 |

注意 `SingleSourceOfTruthGuard`：`全口径` 一词只许出现在 `docs/contract-defects.md` 与判据文件自身（`sourceOnly` 按裸子串匹配）；上表以外的落点（组件文档、registry notes、R-49）**不得**出现「全口径」三个字，只留指针。

---

## 3. 裁定 C：五个组件的形态 D 设计

### 3.0 通用约定

- **形态**：五条全部 D2 配置枚举。D1 外观槽对这五条都不成立——候选差异都是**容器级排布 / 几何**（换坐标系、换网格、换轴向、换轨道），槽够不着容器（与 `Timeline.notes` 逐字「槽够不着容器 ⇒ D1 不完整成立」同一理由）。
- **D2 成立条件**（公约逐字「判定时枚举出的候选形态若能被该枚举的 case **一一覆盖**，D2 成立」）：每个枚举 = 1 个默认 case（现状）+ 每个**计入**候选各 1 个 case。未计入的候选（`RingChart` 的 dashboard、`OrbitingLogos` 的 marquee / 网格、`RadarChart` 的 Significance 四形态）**不做 case**，理由已在各条 `notes` 里（装饰 / 来源模板不符 / 业界另一个组件）。
- **命名**：`<Component>Layout`（`NetworkGraphLayout` / `TimelineLayout` 先例）；case 名描述几何，不带裸修饰词。
- **声明形状**（照 `NetworkGraphLayout` 逐字）：`public nonisolated enum X: Sendable, Equatable, CaseIterable`。`nonisolated` 是必需的，不是风格：三个 target 都开了 `.defaultIsolation(MainActor.self)`（`Package.swift` 【实测】），几何纯函数是 `nonisolated static func`，在里面比较 `layout == .x` 要求枚举的 `Equatable` 一致性非 MainActor 隔离——下游探针注释逐字：「实测把 `nonisolated` 去掉，**库自己的 `swift build` 就硬红**（`main actor-isolated conformance of 'NetworkGraphLayout' to 'Equatable' cannot be used in nonisolated context`）」。`scripts/mainactor-static-ratchet.sh` 只扫 `swift.type.property / method / subscript`（【实测】脚本 `STATIC_KINDS`），enum case 不在射程；`allCases` 是否被采未实测——照先例写 `nonisolated` 则两种情况都安全。实现后跑一次 ratchet（先 `swift build --build-tests`），预期 `docs/mainactor-static-exemptions.txt` 零新增。
- **接入点**：`layout: X = .<default>` 放在**最后一个非闭包参数之后、第一个 `@ViewBuilder` 闭包参数之前**（评审 I-3：放在闭包之后会破坏尾随闭包调用形态）。Charts 三条无闭包参数 ⇒ 末尾（`NetworkGraph.init` 先例：`layout:` 在 `tint` 之后）；`BeforeAfterSlider.init(labels:layout:before:after:)`；`OrbitingLogos.init(_:colors:rotationPeriod:layout:logo:center:)`。J-2 扫描器只认公开 `init` 参数的基类型名（【实测】`collectStyleEnumUses`：`componentJudgeBaseTypeName(parameter.type…)`，宿主 = 外层类型名），泛型宿主（`NetworkGraph<Node>`）已证明可采。
- **BREAKING-CHANGES**：`docs/BREAKING-CHANGES.md` 新增一节「未发布（相对 `v0.10.0`）——Issue #312：四（五）个组件的布局形态扩展点」，正文照 `#312 NetworkGraph` 那节：「对已应用的调用点零影响；对未应用的函数引用是破坏性变更；新增 public 类型 …；非 `@frozen` ⇒ 将来加 case 也是破坏性变更」。
- **色彩纪律**：只用 `tint` / `Color.dividerDefault` / `Color.tertiaryFill` / `Color.quaternaryFill` / `Color.contentPrimary` / `Color.contentOnEmphasis` 及 `.opacity`，不得出现色相字面量（`EffectsColorLiteralGuard` 覆盖两个新 target）。
- **文案纪律**：本设计不新增任何 chrome 文案；SF Symbol 名（如 `arrow.up.and.down`）与既有 `arrow.left.and.right` 同类。
- **a11y**：五条的 `AXChartDescriptor` / `accessibilityValue` 都描述**数据**，与形态无关，一律不改。
- **判据放置**：Charts 三条进 `Tests/OhMyDesignChartsTests/<Component>LayoutFormTests.swift`；Effects 两条进 `Tests/OhMyDesignEffectsTests/`。每条至少一个判据走 **view 实际走的路径**（`#355` 教训 ①）：做法是给每个 view 一个 internal `renderPlan(size:)`（或复用既有 `renderInputs`），body 与判据共用它。标题只声称断言真检查的事（教训 ②）。

### 3.1 `RadarChart` → `RadarChartLayout`

**3.1.1 case 与候选对应**

| case | 候选 | 默认 |
|---|---|---|
| `.polygon` | 现状：各轴端点连成闭合轮廓 | ✔ |
| `.parallel` | 候选 1 平行坐标（AntV G2 `parallel`） | |
| `.radialBars` | 候选 2 径向柱状（AntV G2 `radial`「transposing polar coordinates」：每维一条同心**弧形条**、值编码在扫过角——与 §2.2 论证用的是**同一读法**，评审 I-2；registry `notes` 三分法「每维一根独立的条」在此读法下同样成立） | |
| `.bars` | 候选 3 笛卡尔并排条形（GitLab Pajamas “columns are horizontal”） | |

**3.1.2 共同部分（不随形态变）**：`body` 的 `ChartDegeneracy.of(raw, minimumCount: 3)` 四路分支与三种空态文案；`raw.normalizedSafely()`；`0.85 × v + 0.15` 的值→长度映射（现状 `polygon(…scales:)` 里逐字 `$0[i] * 0.85 + 0.15`）在四种形态里**共用同一个常量**，这样四种形态在同一数据上锚点长度一致，可互相验证；`tint`；`title`；`makeChartDescriptor`。

**3.1.3 纯函数**：`nonisolated static func anchors(layout: RadarChartLayout, normalized: [Double], in size: CGSize) -> [CGPoint]`，给出每个维度的「值锚点」（多边形顶点 / 条端 / 平行坐标点），四种画法都从它取点；另加 instance 方法 `func renderPlan(size:) -> RadarChartPlan?`（`nil` = 走空态），body 只消费它。

**3.1.4 逐 case 渲染规格**

- `.polygon`：现状不动。
- `.radialBars`（G2 `radial` 读法）：`center` 同 `.polygon`，外半径 R = min(w,h)/2 × 0.78；n 条同心弧轨，第 i 维（i = 0 在最外）轨道中线半径 rᵢ = R × (1 − i / n)，条宽 = R / n × 0.6；轨道 = 整圈 `Circle` 描边 `Color.tertiaryFill`、线宽同条宽；数值条 = 从 −π/2 顺时针扫过 sweepᵢ = 2π × 0.85 × (0.85 vᵢ + 0.15) 的弧（上限 0.85 圈留出缺口以区分满值与起点，地板 0.15 与 `.polygon` 共用常量），`StrokeStyle(lineWidth: 条宽, lineCap: .round)` 描 `tint`。锚点 = 弧终点。不画轴名（与 `.polygon` 一致）。
- `.parallel`：n 条竖轴，xᵢ = inset + (w − 2·inset) × i/(n−1)，inset = w × 0.11（与 0.78 半径留白同量级）；轴线 hairline `dividerDefault`；四条水平网格 hairline 在 usable 高度的 1/4…4/4；记录 = 折线连接 (xᵢ, yᵢ)，yᵢ = bottom − usableH × (0.85 vᵢ + 0.15)，描 `tint` / thin，不填；每点加直径 6 的 `Circle().fill(tint)`。不闭合（平行坐标没有闭合语义）。
- `.bars`：n 行水平条（Pajamas 的 bar = 横向 column）；行高 = usableH / n，条高 = 行高 × 0.7，条长 = usableW × (0.85 vᵢ + 0.15)，从 leading 起；形状 `RoundedRectangle(cornerRadius: 2, style: .continuous)`，填 `tint`；四条竖网格 hairline 在 1/4…4/4。**不画 `label` 文本**——`.polygon` 现状也不画轴名（【实测】源码只画网与轮廓），四种形态保持一致；轴名仍由 `AXChartDescriptor` 的 `categoryOrder` 交给 VoiceOver。
- 空态 / 不足 3 维 / 非有限：四种形态同一分支，文案不变。

**3.1.5 判据**（`RadarChartLayoutFormTests`）
1. `anchors(layout:…)` 对四个 case 都返回 n 个点、全部落在画布内（含 NaN 守卫）。
2. `.radialBars`：弧终点角（相对 −π/2 的顺时针扫过量）对 vᵢ 严格单调；v = 1 时扫过量 = 2π × 0.85；各维中线半径严格递减（同心）；`.parallel` / `.bars` / `.radialBars` 的锚点与 `.polygon` 均不等（形态真的生效）。
3. `.parallel`：x 严格递增；值大者 y 更小；v = 0 与 v = 1 的 y 差 = usableH × 0.85。
4. `.bars`：n 个不同的 y；条长与 v 单调，v = 0 时长度 = 0.15 × usableW（地板）。
5. **view 路径**：`RadarChart([1 点], layout: .bars).renderPlan(size:)` 为 `nil`（退化输入在任何形态下都走空态）；同一 5 维数据下 `renderPlan` 在四个 layout 上给出互异的 plan。
6. 三分法不测；不测散文。

### 3.2 `RingChart` → `RingChartLayout`

**3.2.1 case 与候选对应**

| case | 候选 | 默认 |
|---|---|---|
| `.rings` | 现状：同心环 | ✔ |
| `.bars` | 候选 1 并排线性进度条（Ant Design `Progress type="line"`） | |
| `.segmentedRings` | 候选 2 分段进度条（Ant Design `steps`；保持同心几何、只改「连续 → 离散」，与候选 1 的差异干净分离） | |
| `.stackedBar` | 候选 3 堆叠条（Pajamas stacked column；N 环塌成 1 条） | |

**3.2.2 共同部分**：`effectiveValues`（去重 + `recommendedRingLimit` 截断，不提示）、`drawnValue`、`goal` 非法 ⇒ 空态、`ringBaseColor / trackColor / ringColor(at:)` 三个取色函数（`RingChartColorsGuard` 的三条不变量原样成立——条形 / 段的颜色就取同一个 index 的 `ringColor` / `trackColor`）、`title`、描述符。

分段数：`public nonisolated static var segmentCount: Int { 10 }`（与 `recommendedRingLimit` 同形），**固定**——见 §0 决策项 3。

**3.2.3 纯函数**：
- `nonisolated static func filledSegments(progress: Double, segments: Int) -> Int` = `Int((clamp01(progress) × segments).rounded(.toNearestOrAwayFromZero))`，钳 0…segments（Ant Design 的 steps 按四舍五入填；本仓定死为「四舍五入」并测边界）。
- `nonisolated static func stackedWidths(progresses: [Double], trackWidth: CGFloat) -> [CGFloat]` = 各 `clamp01(p) / N × trackWidth`。
- `nonisolated static func barRows(count: Int, size: CGSize) -> [CGRect]`。
- instance `func renderPlan(size:) -> RingChartPlan?`（`nil` = 空态），body 只消费它。

**3.2.4 逐 case 渲染规格**
- `.rings`：现状不动。
- `.bars`：N 行，行间距 `CoreSpacing.sm`，行高 = (h − 间距总和) / N，条高 = min(行高 × 0.6, 24)，垂直居中；轨道 `Capsule().fill(trackColor(at: i))` 全宽；进度 `Capsule().fill(ringColor(at: i))` 宽 = progress × 全宽（progress = `min(max(value/goal,0),1)`，与现状同式），`lineCap: .round` 的观感由 Capsule 承接。
- `.segmentedRings`：几何与 `.rings` 完全相同（同 `outer` / `width` / `radius(i)`），每环 360° 切成 `segmentCount` 段，段间角隙 4°，段用 `Circle().trim(from:to:)` + `StrokeStyle(lineWidth: width, lineCap: .butt)` 画（round cap 会吃掉缝隙）；前 `filledSegments(progress:segments:)` 段取 `ringColor(at:i)`，其余取 `trackColor(at:i)`；起点 −90°。
- `.stackedBar`：一条水平轨道 `Capsule().fill(Color.tertiaryFill)`，高 = min(h × 0.4, 32) 垂直居中；从 leading 依次叠放 N 段，宽 = `stackedWidths`，色 = `ringColor(at:i)`；全部达标 ⇔ 段和填满轨道；段序 = 值序。**语义保持「完成度」**：轨道总长代表 N × goal。

**3.2.5 `D-299-1` 若扩宽的代价与处置建议**

事实：`ComponentRegistryGuard` 逐字 `if e.kind == "prescriptive" { #expect(!e.needsExtensionPoint, …) }`（【实测】）；J-2 只巡 `kind == "semantic" && needsExtensionPoint`；**没有**判据禁止 `prescriptive` 条目的 `styleEnum` 非空，也没有反向判据抓「源码有接线的公开枚举、登记表未认领」（【实测】`ComponentHostAliasGuard` 只查已登记枚举的接线与唯一认领）。

若将来 `RingChart` 退回**步骤 4**：
- registry：`kind: prescriptive` / `needsExtensionPoint: false` / `decidedBy: tiebreaker`；`styleEnum` **保留** `"RingChartLayout"`（今天无判据反对，且这是事实：枚举还在）；`notes` 写明「枚举按祖父条款同款理由保留，不作扩展点计」。
- 源码：`RingChartLayout` **不能删**（删 public 类型 = 破坏性变更，与 public 协议同级）；只能保留或 `@available(*, deprecated)`。
- 公约缺口：祖父条款逐字只覆盖「组件已经**发布了公开的样式协议**」，D2 枚举同样发布后不可撤，却不受祖父条款保护 ⇒ 建议在 `## #312` 节登记 **D-312-1**：「祖父条款的对象应扩到已发布的形态 D2 公开枚举」，交 `D-299-1` 回路一并裁。
- 结论：**接受这个代价**，理由与 issue 一致——枚举可演进（加 case）且不逼人发协议；真正不可撤的只是类型名本身。

**3.2.6 判据**（`RingChartLayoutFormTests`）
1. `filledSegments`：0 → 0；1 → 10；0.949 → 9；0.95 → 10；NaN / ∞ / 负 → 0 或 10（按 `drawnValue` 的既有非有限规则）。
2. `stackedWidths`：和 ≤ trackWidth；全 1 时和 == trackWidth；N = 6 时各段 = 1/6。
3. `barRows`：count 条、互不重叠、y 递增。
4. **view 路径**：`renderPlan(size:)` 在 `goal ≤ 0` 下四个 layout 全为 `nil`；7 个值下四个 layout 的 plan 都只含 6 条（截断走的是同一条路）；四个 layout 的 plan 互异。
5. `RingChartColorsGuard` 三条原样通过（不改取色函数）。

### 3.3 `ActivityHeatmap` → `ActivityHeatmapLayout`

**3.3.1 case 与候选对应**

| case | 候选 | 默认 |
|---|---|---|
| `.weeks` | 现状：按周成列 × 星期成行 | ✔ |
| `.monthCalendar` | 候选 1 日历月视图（Apple Activity History） | |
| `.monthTracks` | 候选 2 月轨图（Obsidian Contribution Graph “month track graphs”：每月一行、按日序成列） | |
| `.dailyColumns` | 候选 3 折线 / 柱状时间序列（Pajamas）。做成**每日一根柱**；折线与柱同槽同排布（网格 → 线性），差别属装饰档，本轮不另开 case | |

**3.3.2 共同部分**：`effectiveDays`（排序、去重、按 `maximumDays` 从最旧截断，不提示）、`buckets(for:)`、`color(for:buckets:)`（四档 `tint.opacity(0.25 + 0.25·level)` / 零值 `tertiaryFill`）、`calendar` 注入（一周起点由 `calendar.firstWeekday` 定）、`title`、描述符。`renderInputs(_:calendar:)` 扩成 `renderInputs(_:calendar:layout:)`，返回统一的 `HeatmapPlan`，body 只消费它——这就是 view 路径。

**3.3.3 纯函数**（与既有 `weeks(ofEffective:calendar:)` 同形、同文件、`static`）：
- `monthBlocks(ofEffective:calendar:) -> [MonthBlock]`，`MonthBlock { month: DateComponents(year, month); cells: [[Date?]] /* 6 行 × 7 列 */ }`：月份 = `first…last` 跨越的每个日历月；列 = `(weekday − firstWeekday + 7) % 7`；行 = 该日在本月的第几周；本月之外的格 `nil`。固定 6 行让各月块顶对齐。
- `monthTracks(ofEffective:calendar:) -> [[Date?]]`：每月一行、31 列，第 d 天在列 d−1，超出该月天数的列 `nil`。
- `dailySeries(ofEffective:calendar:) -> [Date]`：`first…last` 逐日稠密序列。
- 三者都用 `calendar.startOfDay` 与 `date(byAdding: .day, value: 1)` 前进（与 `weeks` 同法，DST 安全），并沿用 `guardCounter > maximumDays + 14 { break }` 的守卫。

**3.3.4 逐 case 渲染规格**
- `.weeks`：现状不动。
- `.monthCalendar`：`HStack(spacing: CoreSpacing.sm)` 排月块；每块 `VStack(spacing: 3)` 6 行 × `HStack(spacing: 3)` 7 格，格 = `RoundedRectangle(cornerRadius: 2, style: .continuous).aspectRatio(1, .fit)`；有日期的格取 `color(for: byDate[date], buckets:)`（区间内无数据的日与现状一样是 `tertiaryFill`），`nil` 格 `Color.clear`（保留占位，不改变对齐）。
- `.monthTracks`：`VStack(spacing: 3)` 每月一行 × `HStack(spacing: 3)` 31 格；同上取色；`nil` 格 `Color.clear`。
- `.dailyColumns`：`HStack(alignment: .bottom, spacing: 1)` 每日一柱；柱高 = `count / peak × h`（peak = `days.map(\.count).max()`；peak = 0 时全部为 0 高度、只画基线）；柱宽均分；柱色 = `color(for:buckets:)`（**保留四档强度语义**，不是单色）；无数据日不画柱；底部 hairline `dividerDefault` 基线。可读性：1830 天在 300 pt 宽下每柱 < 0.2 pt——与 `.weeks` 在 261 列下同量级问题，**不新增截断**，写进组件文档《规模上限》。
- 空数组：四种形态同走 `ChartEmptyState`。

**3.3.5 判据**（`ActivityHeatmapLayoutFormTests`，沿用 `DegenerateInputTests` 的 `America/Santiago` DST 夹具思路）
1. `monthBlocks`：每个有效日恰出现一次；每块恰 6×7；非 `nil` 格都属于该块月份；块数 = 首尾跨越的月数（跨年样例）。
2. `monthTracks`：行数 = 月数；每行 31 格；2 月 28/29 天时第 29–31 列（或 30–31 列）为 `nil`；某月第 d 天落在列 d−1。
3. `dailySeries`：长度 = 首尾天数 + 1；相邻元素相差 1 天（DST 日不丢、不重）。
4. **view 路径**：`renderInputs(days, calendar:, layout:)` 四个 layout 下 `shown` 相同（截断与去重与形态无关）、plan 互异；空数组 ⇒ 四个 layout 都零列 / 零块 / 零柱。
5. `buckets` / `color(for:)` 不改，既有判据原样。

### 3.4 `BeforeAfterSlider` → `BeforeAfterSliderLayout`

**3.4.1 case 与候选对应**

| case | 候选 | 默认 |
|---|---|---|
| `.overlay` | 现状：两层叠放、分隔线裁切 | ✔ |
| `.sideBySide` | 候选 1 左右并排两幅完整图（Lightroom left/right） | |
| `.stacked` | 候选 2 上下并排两幅完整图（Lightroom top/bottom） | |

**3.4.2 设计判断——并排形态里 `fraction` 的语义**【设计】：Lightroom 的 left/right 没有滑块；本组件的含义是「拖动分隔线对比」。公约边界条款「样式不得携带行为」⇒ 换形态不能让手势、`accessibilityAdjustableAction`、入场扫动失效。⇒ 并排形态下 `fraction` = **分隔线位置**（两个窗格的尺寸比），窗格各自给内容一个独立 frame（`before` 得到 `fraction × 全长`，`after` 得到其余），内容不再被裁切、各自完整；分隔线 + 把手照常可拖。这仍满足候选的排布差异「重叠 ↔ 并排」。

**3.4.3 硬约束**【实测】：`BeforeAfterSlider.swift` 在 `MicroInteractionReduceMotionGuard.approvedNoMotion` 名单里，判据 `contradiction = approvedNoMotion.intersection(motion)` 要求文件里**零** `motionCalls` 子串——逐字清单：`"offset(", "rotationEffect(", "scaleEffect(", "rotation3DEffect(", "symbolEffect(", "position(", "transformEffect(", "matchedGeometryEffect(", "Canvas(", "TimelineView(", "visualEffect(", "projectionEffect("`。⇒ 竖向把手**不能**用 `.rotationEffect(` 把横向把手转 90°，要另写 `BeforeAfterSliderStackedHandle`（横向分隔条 + 圆 + `arrow.up.and.down`）；位置全部走布局（组件文档逐字「位置走**布局宽度**，一个 `offset` 都不用」）。`BeforeAfterRevealClip` 只在 `.overlay` 使用；不新增 `.mask` 点位（`MaskSiteRegistryGuard`）。

**3.4.4 纯函数**（`BeforeAfterSweep`，同文件）：
- `static func axis(for layout: BeforeAfterSliderLayout) -> Axis`（`.stacked` ⇒ `.vertical`，其余 `.horizontal`）。
- `static func fraction(dragCoordinate: CGFloat, extent: CGFloat) -> CGFloat`（既有 `fraction(dragX:width:)` 改为转调它，保持签名）。
- `static func paneExtents(fraction: CGFloat, extent: CGFloat) -> (first: CGFloat, second: CGFloat)`，`first = clamp01(fraction) × max(0, extent)`，`second = extent − first`。
- `leadingInset(fraction:width:)` 复用于两个轴。

**3.4.5 逐 case 渲染规格**（`BeforeAfterSliderBody` 增 `layout` 参数；`BeforeAfterSlider` 的 `DragGesture.onChanged` 按 `axis` 取 `value.location.x / proxy.size.width` 或 `.y / .height`）
- `.overlay`：现状不动。
- `.sideBySide`：`HStack(spacing: 0)`：`before.frame(width: first, height: h).clipped()`、`after.frame(width: second, height: h).clipped()`；把手层同现状（`leadingInset` + `BeforeAfterSliderHandle`）；标签：`.standard` / `.shown` 时 before 芯片在左窗格顶部 leading、after 芯片在右窗格顶部 leading（各窗格自己一枚，宽度不足时芯片被 `clipped`，不换行）。
- `.stacked`：`VStack(spacing: 0)`：`before.frame(width: w, height: first)`、`after.frame(width: w, height: second)`；把手层 `VStack { Color.clear.frame(height: leadingInset(fraction, extent: h)); BeforeAfterSliderStackedHandle(); Spacer(minLength: 0) }`；把手 = `Rectangle().fill(contentOnEmphasis).frame(height: dividerWidth)` + 圆 + `arrow.up.and.down`，命中区 `minWidth/minHeight: handleHitSize`（≥ 44 不变）；标签：before 芯片在上窗格顶部 leading、after 芯片在下窗格顶部 leading。
- Reduce Motion / 入场扫动 / `.task` 状态机：完全不动（`introSweep` 只关心 `fraction`）。
- `accessibilityValue` 仍是 `fraction` 百分比。

**3.4.6 判据**（`Tests/OhMyDesignEffectsTests/BeforeAfterLayoutFormTests.swift`；位图断言按 `#317` 的容差形态用 `BitmapExpectations` 的既有辅助）
1. `paneExtents`：和 == extent；`fraction` 越界钳到 0…1；0.5 均分；extent ≤ 0 时两者为 0。
2. `fraction(dragCoordinate:extent:)` 与既有 `fraction(dragX:width:)` 在同输入上相等（回归）。
3. `axis(for:)`：三 case 映射钉死。
4. **view 路径**：`BeforeAfterSliderBody(fraction: 0.5, labels: .hidden, layout: …)` 用两块不同 token 色渲染，三种 layout 两两位图不同；`.overlay` 与「不传 layout」逐像素等价（默认行为未变）。
5. `ReduceMotionGuard` 全绿（文件仍在 `approvedNoMotion` 且不含运动调用）——这条由既有判据守，不另写。

### 3.5 `OrbitingLogos` → `OrbitingLogosLayout`（仅当裁定 A 落地）

**3.5.1 case 与候选对应**

| case | 候选 | 默认 |
|---|---|---|
| `.outerRing` | 现状：全部 logo 均匀落在最外环 | ✔ |
| `.multiRing` | 候选 1 多轨道分布（Magic UI 两个 `OrbitingCircles` 不同 `radius` 并列） | |
| `.ellipse` | 候选 4 椭圆轨道（Animata `radiusX` / `radiusY` / `tiltAngle`） | |

候选 2（marquee）/ 候选 3（logo 网格）**不做 case**：现行口径下不计入（`D-299-2`），且去掉运动就不是本件（组件在 Effects 层，`notes` 逐字「巡游本身就是它的含义」）。若 `D-299-2` 将来取反向口径，它们要另加 case（source-breaking，届时走 BREAKING-CHANGES）——写进 `notes` 与组件文档，作为已知的演进点。

**3.5.2 共同部分与硬约束**：
- 能耗闸与 Reduce Motion 一根手指都不碰：`OrbitingLogos.swift` 在 `energyGatedFiles` 里，判据要求 `self.reduceMotion` 的出现次数 == 喂给 `presentation(reduceMotion: self.reduceMotion)` 的次数（【实测】`reduceMotionIsOnlyConsumedByTheSharedGate`）；`layout` 只是穿过 `OrbitingLogosTimeline` / `OrbitingLogosBody` 的一个值。
- `QuotedEvidenceGuard` 登记了 `OrbitRing.swift` 的两条逐字引文：`static let ringCount: Int = 4` 与 `seats(particleScale:`（【实测】）——**这两行文本不得改动**。
- `OrbitingLogosBody` 新增 `layout: OrbitingLogosLayout = .outerRing` **带默认值**，`CrossPlatformTests.orbitBody(…)` 夹具无需改动即可编译。
- 点环的挤压位移场、轮播 `feature`、`popScale` 不变。

**3.5.3 纯函数**（`OrbitRing`，`nonisolated`）：
- `static let ellipseAspect: Double = 0.55`（`radiusY / radiusX`；Animata 的 tilt 固定取 0——椭圆的旋转角不改变 logo 彼此之间的落点关系，属同一排布的参数，本轮不开）。
- `static func point(angle:radius:center:aspect: Double = 1) -> CGPoint`：`y = center.y + sin(angle) × radius × aspect`；默认 1 与现状逐位相同。
- `static func aspect(for layout: OrbitingLogosLayout) -> Double`（`.ellipse` ⇒ `ellipseAspect`，其余 1）。
- `static func ring(forLogo index: Int, layout: OrbitingLogosLayout) -> Int`（`.multiRing` ⇒ `index % ringCount`，其余 0）。

**3.5.4 逐 case 渲染规格**
- `.outerRing`：现状不动。
- `.multiRing`：logo i 坐在第 `ring(forLogo:)` 圈，座位角仍由 `logoAngle(logoIndex:logoCount:dotsPerRing:turns:)` 算、再加该圈的相位偏移 `ring × 0.4`（与点环 `angle(index:of:turns:ring:)` 同式，保证 logo 落在那圈真画出来的点上）；半径 `ringRadius(ring:size:)`；`featurePoint` 按被点名 logo 所在圈算。
- `.ellipse`：四圈点环与 logo 一律经 `point(…, aspect: ellipseAspect)`，整件成横向椭圆；`aspectRatio(1, .fit)` 不变（容器仍方形，椭圆居中）；挤压场用变形后的坐标。
- `.hidden` / `.resting` / `.animated` 三档与形态正交。

**3.5.5 判据**（`Tests/OhMyDesignEffectsTests/OrbitingLogosLayoutFormTests.swift`）
1. `point(…, aspect: 1)` 与旧签名逐位相同（回归）；`aspect: 0.55` 保 x、y 按比例。
2. `ring(forLogo:)`：`.multiRing` 下 8 个 logo 落到 4 圈各 2 个；`.outerRing` / `.ellipse` 恒 0。
3. `.ellipse` 下全部 logo 点满足 `((x−cx)/rx)² + ((y−cy)/(rx·0.55))² ≈ 1`。
4. **view 路径**（位图，`CrossPlatformTests` 既有 `orbitBody` 夹具 + `layout:`）：三个 layout 在静止帧两两位图不同；`.outerRing` 与不传 `layout` 的位图等价（默认未变）；`.background` 注入下三个 layout 都只剩内容帧（能耗闸与形态正交）。

### 3.6 复杂度与风险

| 组件 | 复杂度 | 主要风险 |
|---|---|---|
| `RadarChart` | 中（三套手绘，几何简单） | 平行坐标的「记录 vs 单条」语义争议已在 `notes` 留痕；`.bars` 与 Swift Charts `BarMark` 重叠——`D-299-1` 扩宽后候选 3 会被排除，但 case 已发布，同 §3.2.5 处置 |
| `RingChart` | 中 | **已确证若 `D-299-1` 扩宽会翻**，见 §3.2.5；分段数固定值是决策项 |
| `ActivityHeatmap` | 中高（日历数学、DST、6 行块） | `.dailyColumns` 在 5 年数据下不可读（文档登记，不截断）；月块行数用固定 6 行——有的月只需 5 行、留一行空 |
| `BeforeAfterSlider` | 中 | `approvedNoMotion` 硬约束（不能用 `rotationEffect` 转把手）；竖向拖拽的 gesture 轴切换要走 `layoutKey` 式的 `id` 保证换形态重置 `fraction`？——不重置（`fraction` 语义跨形态一致），写进文档 |
| `OrbitingLogos` | 中 | 裁定 A 连锁（§1.3 十处落点）；`.multiRing` 下低电量档座位 23 → 12 同样作用于每一圈；`D-299-2` 反向口径会要求再加 case |

---

## 4. 同步落点清单（阶段 3）

### 4.1 判据收缩（`Tests/OhMyDesignTests/ComponentExtensionPointGuard.swift`）【实测现状 → 目标态】

| 现状 | 目标 |
|---|---|
| `static let knownMissingExtensionPoints: Set<String> = ["ActivityHeatmap", "BeforeAfterSlider", "RadarChart", "RingChart"]` | **删除** |
| `static let extensionPointFollowUpIssue = "#312"` | **删除**（issue 正文「关闭前必须满足」第一条） |
| `#expect(result.inspected.count == 16, "J-2 定义域实测 16 条（…16 名…）")` | `== 17`，名单加 `OrbitingLogos`（裁定 A 不落地则保持 16） |
| `withKnownIssue("4 条待补的扩展点，移交 #312…") { #expect(result.missing.isEmpty, …) }` | 拆掉 `withKnownIssue`，只留裸 `#expect(result.missing.isEmpty, …)`——公约 §4 逐字「落账方式是『主判据裸 `#expect(missing.isEmpty)` + 块外固定集合 canary』」；空集下 `withKnownIssue` 自己会判红（块内注释的到期机制），删是唯一出路 |
| `#expect(Set(result.missing) == Self.knownMissingExtensionPoints, …)` 及其长文案 | 改为 `#expect(result.missing.isEmpty, "J-2 出现新缺口：…（红名单已于 #312 收成空集；新缺口要么补扩展点，要么走公约 §2 判定，须挂承接 issue 后重建 knownMissingExtensionPoints）")` |
| `for component in Self.knownMissingExtensionPoints { … }` 循环 | **删除** |
| `missingFollowUp` 聚合断言 | **删除** |
| `print(… "（待补扩展点，承接 issue \(Self.extensionPointFollowUpIssue)）")` | 改成不引用已删常量 |
| （新增）`result.satisfied["…"]?.contains("…Layout")` | 为五条各加一行 D2 通路的正向断言（与 `ProgressIndicator` / `Banner` 那几行同形），例：`#expect(result.satisfied["RadarChart"]?.contains("RadarChartLayout") == true, "D2 通路未走通：…")` |

`Tests/OhMyDesignTests/ComponentJudgeMutationTests.swift` 三处【实测 :103-105 / :122 / :141】：
- `:103` `#expect(Set(judgeExtensionPoints(…).missing) == ComponentExtensionPointGuard.knownMissingExtensionPoints, …)` → `#expect(judgeExtensionPoints(…).missing.isEmpty, "副本的 J-2 缺口非空 —— 拷贝有问题，或红名单没同步")`；
- `:122` `== …knownMissingExtensionPoints.union(["Banner"])` → `== ["Banner"]`；
- `:141` 同上。

`inspected.count` 的两处文本副本：`CLAUDE.md:64` / `AGENTS.md:66`（§1.3 第 9 行）。

阶段 3 的变异实证（plan 已列）：删掉某条 `styleEnum` 字段 ⇒ 判红（走 `else` 四者皆空分支）；把 `RadarChartLayout` 改名 ⇒ 判红（`无该公开 enum 声明`）；给 `prescriptive` 条目乱填 `styleEnum` ⇒ **今天不判红**（§3.2.5 已说明无此判据）——plan 第 3 条第二句要改成如实的预期，别把它当成会红的变异。

### 4.2 `docs/component-registry.json`

五条各填 `styleEnum`；`notes` 按 `NetworkGraph.notes` 先例把「扩展点尚未落地，按成法移交 … 登记进 `knownMissingExtensionPoints`，扩展点实现移交 **`#312`**」改写为「扩展点已由 `#312` 落地 …（曾按 `Toast` 的成法暂登记在那里）」并追加 D2 段（case 与候选对应、有意不发协议、非 `@frozen` 代价、判据名）。硬约束：
- `ActivityHeatmap` / `RadarChart` / `RingChart` 三条 `notes` 必须保留逐字指针 `` `docs/contract-defects.md` 的 `D-299-1` ``（`registryNotesPointBack`）；`OrbitingLogos` 保留 `` `docs/contract-defects.md` 的 `D-299-2` ``。
- `RingChart.notes` 里 `SingleSourceOfTruthGuard.factSites` 登记的那个短语（见判据源码 `phrase:`）**恰 1 处**且前文 160 字内有 `≤1`（按处计数：registry 1、`ring-chart.md` 1、`contract-defects.md` 2、revisions 1——⚠️ 该判据扫全部 tracked 的 md/json/swift，**含 `.claude/`**；本 spec 与 `312-plan.md` 一律不得逐字写该短语）；改写时不要多写或少写。
- 不得写入 `sourceOnly` 短语。

### 4.3 `docs/components/*.md` 与 `docs/README.md`

- 五份组件文档：API 块加 `layout:`；新增「布局形态扩展点（`#312` · 形态 D2）」节（模板 = `network-graph.md` 的同名节：枚举声明、默认 case、逐 case 来源、明确不做的事、判据名、「为什么是 D2 不是协议」）；`#299` 重判小节末尾把「扩展点尚未落地」段改成「已由 `#312` 落地」（`network-graph.md` 先例）。`ring-chart.md` 同样守住该 `factSites` 短语恰 1 处。`activity-heatmap.md` / `radar-chart.md` / `ring-chart.md` 保留 `D-299-1` 指针。
- `docs/README.md` 索引行【实测】：`:177 BeforeAfterSlider(labels:before:after:)`、`:184 OrbitingLogos(_:logo:center:)`、`:193 RadarChart(_:title:tint:)`、`:194 RingChart(_:goal:title:tint:colors:)`、`:195 ActivityHeatmap(_:title:tint:calendar:)` → 各加 `layout:`（`:196 NetworkGraph(nodes:edges:title:tint:layout:)` 是先例）。

### 4.4 `docs/contract-defects.md` / `docs/component-contract.md` / `docs/component-contract-revisions.md`

见 §1.3 第 1–5 行与 §2.6。补充：`D-299-1` 判定表下方追加「`#312` 重核（只增不删）」段承载 §2.6 的表，并在《代价如实记录》段追加一句「`#312` 重核：`RadarChart` / `ActivityHeatmap` 在双平台口径下不翻；单平台口径下 `ActivityHeatmap` 会翻——口径本身待本条回路成文」。

### 4.5 其它

- `docs/BREAKING-CHANGES.md`：新增未发布节（§3.0）。顶部 tag 清单只在发 tag 时改。
- `scripts/downstream-probe/Sources/DownstreamProbe/ChartsNonisolatedUsage.swift`：照 `readNetworkGraphLayouts()` 为三个 Charts 枚举各加一个 `nonisolated func read…Layouts()`（Effects 两个可放同包另一文件）；CI 的 `downstream-probe` job 会构建它。
- `App/Sources/ComponentData.swift`：可选——`Timeline` 先例在画廊里逐形态展示（【实测】`:975-978` 三个 `layout:`），建议为五条各加形态示例；按 CLAUDE.md 的 UI 改动流程跑起来截图交视觉评审。`App/` 不受 `swift test` 覆盖，改完手动 `scripts/run-preview.sh`。
- `.claude/epics/issue-backlog-closeout/312.md` / `312-plan.md` / `epic.md`、`.claude/prds/issue-backlog-closeout.md:58`：改成最终态；`312-plan.md` 阶段 1b 按 §2.4 重写、阶段 3 第 3 条按 §4.1 末段改。
- `SingleSourceOfTruthGuard`：不需要结构改动；若有人想把「`OrbitingLogos` 翻至出口 1」也钉成 `factSites`，注意判据自陈「写下计数的那句话本身就会变成新的一处」，登记时按「处」数全。

- **design-digest**（评审 I-4）：`scripts/design-digest.py` 的 `FLOORS` 是**精确相等**（`enums` / `enumcases` 等）⇒ 新增 5 个 public enum 与其 case 后按实跑读数更新 `FLOORS`，并重生成 `docs/design-digest.md`；CI `swiftpm` job 有 `git diff --exit-code -- docs/design-digest.md`。
- **实现者硬约束补充**（评审 S-4…S-8）：新 helper 名不得含 `offset(` / `position(` 等 `motionCalls` 子串（`BeforeAfterSlider.swift` 与 `OrbitRing.swift` 在 `approvedNoMotion`，子串匹配无编译期信号）；`SingleSourceOfTruthGuard.sourceOnly` 也扫 `Sources/` 与 `Tests/` ⇒ 源码注释不得写「3D Ellipse」「全口径」等真源短语；`docs/` 与仓根 md 不得写 `X.swift:NN` 裸行号（`BareLineRefGate`）；`RingChart.segmentCount` 加进 downstream-probe 的 `readChartScaleLimits()`，probe 构建命令带 `-Xswiftc -warnings-as-errors`；`renderInputs(_:calendar:layout:)` 给 `layout` 默认值以保 `DegenerateInputTests` 调用点不变。
- **组件文档须写明的取舍**（评审 S-1…S-3）：`ActivityHeatmap.dailyColumns` 渲染柱状、折线属装饰档不另开 case、柱高与四档色阶双重编码的理由；`BeforeAfterSlider` 并排形态下入场扫动表现为窗格尺寸变化（有意保留行为一致）；`OrbitingLogos.ellipse` 明确不做 tilt 与 3D 透视。

### 4.6 验证清单

1. `swift build`；`swift test --xunit-output <path>`（权威条数看 xUnit，不看 console 行数）；
2. iOS 腿：`xcodebuild test -scheme OhMyDesign-Package -destination 'platform=iOS Simulator,id=<UDID>' -resultBundlePath <p>.xcresult` + `xcrun xcresulttool get test-results summary --path <p>.xcresult`（取顶层 `passedTests`）；
3. `swift build --build-tests && scripts/mainactor-static-ratchet.sh`（预期零新豁免）；
4. `cd scripts/downstream-probe && swift build -Xswiftc -warnings-as-errors`；`python3 scripts/design-digest.py && git diff --exit-code -- docs/design-digest.md`；
5. `swift package describe --type json | jq '…OhMyDesignTests… .target_dependencies'` 恰为 `["OhMyDesign"]`、`OhMyDesign` 为 `null`（`Package.swift` 本轮不动，仍照跑）；
6. 副本 grep 回扫（附录 B 的命令），确认「4 条待补」「现为 4 条」「翻转移交 `#312`」都已带上一层注记；
7. 全部文档改完后**重跑** 1–2（`AgentGuideSyncGuard` / `QuotedEvidenceGuard` / `SingleSourceOfTruthGuard` 都在看文档）。

---

## 附录 A：留档正文提取命令【实测】

```bash
cd /Users/evan/Repositories/work-spec/oh-my-design-wt-312
python3 - <<'EOF'
import re,html
s=open('docs/issues/animata-orbiting-items-3d-2026-09-14.html',encoding='utf-8').read()
t=re.sub(r'<script.*?</script>','',s,flags=re.S); t=re.sub(r'<style.*?</style>','',t,flags=re.S)
t=re.sub(r'<[^>]+>',' ',t); t=html.unescape(t); t=re.sub(r'\s+',' ',t)
for kw in ['3D Ellipse','radiusX','tiltAngle']:
    m=re.search(re.escape(kw),t); print(kw,'=>',t[max(0,m.start()-120):m.end()+200])
EOF
```

命中（节选）：`… Orbiting Items 3D List component with orbiting items. The items orbit around the center of an element in 3D Ellipse. …`；`interface OrbitingItems3DProps { /** * The radius of the ellipse on X-axis in percentage, relative to the container. */ radiusX : number ; /** * The radius of the ellipse on Y-axis in percentage, relative to the container. */ radiusY : number ; /** * The angle at which ellipse is tilted to x-axis. */ tiltAngle : number ; …`。

## 附录 B：副本 grep 命令与命中【实测，2026-09-16，`52412ce`】

```bash
cd /Users/evan/Repositories/work-spec/oh-my-design-wt-312
for p in "翻转移交" "4 条 → 5 条" "5 条 → 6 条" "16 → 17" "4 条待补" "现为 4 条" "knownMissingExtensionPoints" "inspected.count"; do
  echo "### $p"; grep -rn --include='*.md' --include='*.json' --include='*.swift' --include='*.sh' --include='*.yml' "$p" . | grep -v "^./.build"
done
```

命中（去掉 `.claude/epics/shipswift-*` 历史任务文件与判据自身的定义处）：

- `翻转移交`：`docs/contract-defects.md:2661, 2685, 2721`；`docs/component-registry.json:531`；`docs/component-contract-revisions.md:2154`；`docs/components/orbiting-logos.md:264, 290`。
- `4 条 → 5 条` / `5 条 → 6 条`：`docs/component-registry.json:531`；`docs/component-contract-revisions.md:2232`；`docs/contract-defects.md:2690`；`docs/components/orbiting-logos.md:321`。
- `16 → 17`：上述四处 + `.claude/epics/issue-backlog-closeout/{312.md:24,45; 312-plan.md:20; epic.md:52}`；`docs/component-contract-revisions.md:2230`；`docs/components/orbiting-logos.md:320`。
- `4 条待补`：`Tests/OhMyDesignTests/ComponentExtensionPointGuard.swift:46`；`docs/component-registry.json:531`；`docs/component-contract-revisions.md:2232`；`docs/contract-defects.md:2690`；`docs/components/orbiting-logos.md:321`。
- `现为 4 条`：`Tests/OhMyDesignTests/ComponentExtensionPointGuard.swift:53`；`docs/component-contract.md:328`（另 `:1042` / `:1717` 写作「`#312` 起为 4 条」）。
- `knownMissingExtensionPoints`（活文档侧）：`docs/component-contract.md:1035, 1042, 1556, 1567, 1581, 1594, 1717`（前四处与 `:1581` 是历史记录，只追加注记；`:1042` / `:1717` 追加最终态）；`docs/components/{network-graph:406, before-after-slider:325, ring-chart:270, radar-chart:253, activity-heatmap:277, orbiting-logos:321}.md`；`docs/contract-defects.md:1218, 2248, 2425, 2690`；`docs/component-contract-revisions.md:1397, 1406, 1694, 2165-2169, 2184`；`.claude/prds/issue-backlog-closeout.md:58`。
- `inspected.count`：`CLAUDE.md:64`、`AGENTS.md:66`、`Tests/OhMyDesignTests/ComponentExtensionPointGuard.swift:33-34, 99`、`docs/component-contract.md:1050, 1566, 1580, 1594, 1715, 1718`、`docs/contract-defects.md:1216, 2427, 2636, 2689, 2706`、`docs/component-contract-revisions.md:1399, 1406, 2107, 2165, 2167, 2185, 2228, 2230, 2237`、`docs/components/orbiting-logos.md:317, 320`。

## 附录 C：本轮实测过的 SDK 坐标

- `/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS26.4.sdk/System/Library/Frameworks/UIKit.framework/Headers/UICalendarView.h`（`:17-18` 类声明、`:61` `#pragma mark - Decorations`、`:86` delegate 方法）与 `UICalendarViewDecoration.h`（`:24` “Creates a default decoration with a circle image.”、`:34` `initWithImage:color:size:`、`:41` / `:59` custom view provider）。
- 同 SDK `Charts.framework/Modules/Charts.swiftmodule/arm64e-apple-ios.swiftinterface`：`:2075-2078` `MarkDimension.Storage` 四个 case；`:2105-2116` `MarkDimensions<DataElement>` 含 keyPath 重载；`:2337-2338` `SectorMark` 与其唯一 init；`:2345-2362` `SectorPlot`。
- `MacOSX26.sdk`：无 `UIKit.framework`；`SwiftUI.swiftmodule/arm64e-apple-macos.swiftinterface:13231-13234` `@available(macOS, unavailable)` … `public struct MultiDatePicker`；`AppKit.framework/Headers/NSDatePicker.h` `grep -ci decorat` = 0。
