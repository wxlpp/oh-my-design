# #337 普查清单：活文档源码引用（复跑于 `d3cca4a`）

承接 [#337](https://github.com/wxlpp/oh-my-design/issues/337)。本清单是**逐条核验**的产物：
issue 评论只有汇总数（a4afd16：160 条 / 129 失真 / 18 成立 / 13 跨仓），没有条目表；本节按
现树（`d3cca4a`）复跑并逐条定档、逐条修复。

## 口径与复跑命令

```bash
grep -rnoE '[A-Za-z0-9_/.-]+\.swift:[0-9]+(-[0-9]+)?' docs/ CLAUDE.md README.md AGENTS.md
```

- 射程：`docs/**`（含 `superpowers/` 与 `issues/`）+ 仓根全部 `*.md`；`.claude/` 下的
  PRD / epic / archived 是历史档，不进（与评论口径一致）。
- 本清单里的引用一律写成「`Foo.swift`（`:NN`）」的**断开形式**——本文件自身也在
  `BareLineRefGate` 的扫描面内，不这样写会自己判自己红。

## 与评论数字的出入（`160 → 162`）

复跑得 **162 条**（评论 160 条）。逐文件计数两边完全一致（registry 40 / revisions 29 /
defects 44→46 / 234 16 / contract 15 / 杂项 16），**差异全在 `contract-defects.md`**：

`git grep -c` 于 `a4afd16` 得 44 条，现树得 46 条。多出的两条是 **`#346` 新加文本**引入的
（在 `a4afd16` 上按同一正则复跑得 **0 命中**）：

- `RingChart.swift` 的一处行号举例（`:13`）——`#346` 就地更正的举例句「今天指向的是别的内容（如 ……）」；
- `X.swift`（`:12-13`）——同段描述「坐标形式」本身。

⇒ 评论的 160 是**它自己写下时的树的真值**；本清单按现树 162 条处置（多出的两条在
`D-299-1` 段，已随本节一并改写）。

## 修法分类（162 条）

| 修法 | 条数（约） | 说明 |
|---|---|---|
| 改「文件 + 逐字引文」形态（形态 2） | 100+ | 被引文字仍在同文件（纯漂移占大多数） |
| 引文源已删 ⇒ 改「已删 + `git show 4cd5fc1^:…` 取回」或换现状物 | 13 | 四图表类型文档、`SurfaceModifier` 注释、`Form` 两条注释、`Sidebar`「当前无 action」句、`OrbitingLogos` 句、scanner「本仓零使用」句、`Radio`/`ChevronRightIcon` doc 句等 |
| 跨仓（对面仓 `wxlpp/oh-my-story`）：删行号、留/补引文 | 13 | 已登记进 `QuotedEvidenceGuard.crossRepoCitations` |
| 史料（坐标断开保留、明标「仅存史料」） | 9 | `D-299-1` 段的历次坐标更正叙述 |
| 删除坐标（纯定位、无引文） | 其余 | 如「（非必需但已做）」 |
| 抄错改正 | 1 | `App/Sources/ComponentData.swift`（原引 `:418` 是空行，实际在 `:430`） |

**验证**：修复后复跑同一条命令 ⇒ **0 命中**；`BareLineRefGate` 的 allowance 已清零
（升级为零容忍）。引文侧由 `Tests/OhMyDesignTests/QuotedEvidenceGuard.swift` 逐条回扫
（90 条本仓登记 + 8 条跨仓登记）——登记表按「**源侧 + 文档侧都要逐字命中**」双侧核：
源侧是方案字面（「被引原文仍在源文件」），文档侧防「引文在文档里被悄悄改写」；
`quote` 允许名字级（签名 / 符号类引用）。⚠️ 两条补充说明：① 上述 90 条为收敛后口径
（早期表里的 5 条「文档侧无对应物」与若干 doc 侧形态不一致的条目已按「doc 里真实写了
什么就登记什么」收敛）；② `component-contract-revisions.md` 的文件头 banner 原声明
「所有行号指改动前基线 `0c863a0`」，本批行号改引文后已在该 banner 就地补一句时态说明
（只增不删）。

---

## 一、`docs/contract-defects.md`（46 条）

| 引用 | 档位 | 处置 |
|---|---|---|
| `SurfaceModifier.swift`（:12-13） | 整段被删（注释随 #328 删） | 改「已删，`git show 4cd5fc1^:Sources/CoreDesign/…` 可取回」+ 现树可核 `case canvasSubtle` |
| `ComponentJudgeRules.swift`（:86-88） | 纯漂移（判绿逻辑今在 customStyleProtocol 分支） | 改符号 + 引文 `let declared = scan.styleProtocolNames.contains(custom)` |
| `AvatarGroup.swift`（:18,22,46,…） | 纯漂移 | 删坐标串，改 `HStack(spacing:)` 引文 + `overlapOffset` 说明 |
| `AvatarGroup.swift`（:46） | 纯漂移 | 同上 |
| `Form.swift`（:87-98） | 纯漂移 + doc 句已删 | 改 `ChevronRightIcon` 符号 + 两条引文；「扩展口」句标历史 |
| `Form.swift`（:107-120） | 纯漂移 | 改 `DangerIcon` 符号 + 三条引文（含 `Text("Alert", bundle: .module)` 现状） |
| `Sidebar.swift`（:355-363） | 纯漂移 | 改 `SidebarStatusFooter` 符号 + `Circle()…fill` 引文 |
| `Form.swift`（:115-117） | 整段被删（注释） | 引文改 git 取回 + 现树可核 `.foregroundStyle(Color.statusDangerForeground)` |
| `Descriptions.swift`（:99,112-122,…） | 纯漂移 | 删坐标串，改符号 + 公开 init 引文 |
| `FloatingGlassModifier.swift`（:10-17,…）；`Sidebar.swift`（:404-406） | 纯漂移 + 超界（Sidebar 文件现 382 行） | 改 `public let shape: S` 引文；调用点改 `Toast.swift`/`ExtendedFloatButtonStyle.swift` 实况 |
| `Sidebar.swift`（:404-406） | 同上 | 同上 |
| `Form.swift`（:27-75） | 纯漂移 | 改两个 init 的描述（去坐标） |
| `SectionFooter.swift`（:20-41） | 纯漂移 | 改 3 modifier 逐字引文 |
| `SectionHeader.swift`（:15-17,25-51） | 漂移 + 长 doc 句被精简 | 改 5 modifier 引文；长句标「随 #328 精简，可取回」 |
| `Sidebar.swift`（:62-67） | 纯漂移 | 改 `Image(systemName: "ellipsis")` 引文 |
| `SettingsRow.swift`（:56-65） | 纯漂移 | 改 `SettingsRowChevron` 符号 + 四条引文 |
| `Form.swift`（:87-98） | 纯漂移 | 改 `ChevronRightIcon` 符号 |
| `Sidebar.swift`（:33-80） | 漂移 + 注释删 | 改符号 + 引文；「当前无 action」句标历史（该注释 #328 删、全仓 0 命中） |
| `Sidebar.swift`（:307-334,116-159） | 纯漂移 | 改 `SidebarTagRow` 符号 + `Text("#")` 引文 |
| `TelegramGlassButtonModifier.swift`（:58-95） | 重构顶掉（文件现 65 行） | 按现状重写：shape/border/pressFeedback 三层可换（引文）；「底色由调用方注入」句已不成立 |
| `Sidebar.swift`（:116-159,…） | 纯漂移 | 删坐标串（骨架 / `sidebarSelectedBackground(_:)` 均已符号化） |
| `StateLabel.swift`（:31） | 纯漂移 | 改 `let defaultLabel: String` 引文 |
| `ComponentJudgeRules.swift`（:70-72） | 纯漂移 | 改「`judgeExtensionPoints` 的过滤子句」+ 引文 |
| `ComponentJudgeRules.swift`（:378） | 重构顶掉（文件 342 行） | 改 `judgeTextParamCoverage` 符号 |
| `Sidebar.swift`（:220-224） | 纯漂移（且原意指 SidebarUtilityRow，今该行属 DocumentRow） | 改 `SidebarUtilityRow.init` 的 `systemImage: String,` 引文 |
| `ComponentJudgeRules.swift`（:70-113） | 漂移 + 结论被 5241175 推翻 | J-2 描述按现状重写（四分支），删坐标；#346 的更正值合并为一层 |
| `Sidebar.swift`（:221） | 纯漂移 | 改引文（`systemImage` 无默认 + `trailingSystemImage` 有 `= nil`） |
| `Timeline.swift`（:64） | 纯漂移 | 改 `@ViewBuilder node: () -> Node,` 引文；`nodeView` 已为 `nodeContent` |
| `ComponentExtensionPointGuard.swift`（:134） | 重构顶掉（文件 109 行） | 改「storyui 侧不得出现 semantic 的 canary」+ 引文 |
| `ComponentJudgeRules.swift`（:71）×4 | 纯漂移 | 四处均改「过滤子句」（同名符号） |
| `FocusModeContainer.swift`（:32）/ `StoryScaffold.swift`（:47）/ `ToolCallRow.swift`（:159） | 跨仓 | 删行号，注「源码在对面仓」；登记入跨仓清单 |
| `X.swift`（:12-13 / `RingChart.swift` 的 `:13` 举例） | 史料（`#346` 后加） | 改描述性措辞（不再逐字给坐标字样） |
| `RadarChart.swift`（:12）/ `ActivityHeatmap.swift`（:12-13）/ `NetworkGraph.swift`（:13） | 引文源已删 | 表内坐标改「类型文档（已删，取回见上）」；**顺手修正**取回命令路径 `OhMyDesignCharts` → `CoreDesignCharts`（改名后的路径在 `4cd5fc1` 上取不到——本次新发现的失真） |
| `NetworkGraph.swift`（:12-13）/ `RadarChart.swift`（:12）/ `ActivityHeatmap.swift`（:12-13）/ `RingChart.swift`（:12-13） | 史料 | 坐标断开书写、标「仅存史料」 |

## 二、`docs/component-registry.json`（40 条）

| 引用 | 档位 | 处置 |
|---|---|---|
| `ActivityHeatmap.swift`（:12-13）/ `RadarChart.swift`（:12）/ `RingChart.swift`（:12-13）/ `NetworkGraph.swift`（:13-14） | 引文源已删（#328） | 改「已删 + git 取回」，内联引文保留（承重的是引文） |
| `AvatarGroup.swift`（:46） | 纯漂移 | 改 `HStack(spacing:)` 引文 |
| `Form.swift`（:87-98）×2 / `:84-86` / `:115-117` / `:114` / `:36` | 漂移 + 注释删 | 改符号 + 引文（`ChevronRightIcon` / `DangerIcon` / `LabelIcon`）；两条注释句标 git 取回 |
| `Descriptions.swift`（:112-122） | 纯漂移 | 改符号 + 两枚举引文 |
| `FloatingGlassModifier.swift`（:10-17）；`Sidebar.swift`（:404-406）×2 | 纯漂移 + 超界 | 改引文；调用点改实况（`Toast.swift` 三种 presentation / preview） |
| `SettingsRow.swift`（:39-51） | 纯漂移 | 改「`SettingsRow.swift` 的内部类型」（去行号） |
| `OrbitRing.swift`（:44） | 纯漂移 | 改 `static let ringCount: Int = 4`（逐字） |
| `OrbitingLogos.swift`（:275-293） | 引文删 + 漂移 | 「logo 必须坐在…」句标「原注释、已删」；改引 `seatCount` / `OrbitRing.seats(particleScale:)` |
| `ProgressIndicator.swift`（:53-78）/ `Style/CoreProgressViewStyle.swift`（:37） | 纯漂移 | 改符号 + `public func makeBody` 引文 |
| `Radio.swift`（:37-39） | 引文精简 | 改引现状 doc 逐字「与 `CheckBoxToggleStyle` 同套 token、方框换圆点」 |
| `SectionFooter.swift`（:20-41） | 纯漂移 | 改 3 modifier 引文 |
| `Sidebar.swift`（:62-67）×2 / `:34-42` / `:46-68` | 漂移 + 注释删 | 改 `Image(systemName: "ellipsis")` / `showsChevron`（公开参数）引文 |
| `SectionHeader.swift`（:42-44）×2 | 已修一半（#346），历史说明仍留原坐标字样 | 历史说明改「原写行号坐标」（去数字）；本体已是逐字修饰符三连 |
| `SettingsRow.swift`（:129）/ `:56-65` / `:61-62`；`Form.swift`（:87-98）×2 | 纯漂移 | 四 init 数已核实为 4（`icon: SettingsRowIcon? = nil`）；其余改符号 / 引文 |
| `Sidebar.swift`（:116-159 长串） | 纯漂移 | 删坐标串 |
| `Sidebar.swift`（:313-329）/ `:320-321` | 纯漂移 | 改符号 + `Text("#")` / `.coreFont(.title2)` 引文 |
| `Sidebar.swift`（:220-230） | 纯漂移 | 改 `systemImage: String,` 引文 |
| `SpinningModifier.swift`（:44-60） | 纯漂移 | 删坐标（`.fill(.regularMaterial)` 为登记引文） |
| `StateLabel.swift`（:31） | 纯漂移（声明仍成立） | 改 `let defaultLabel: String` 引文 |
| `TelegramGlassButtonModifier.swift`（:59-64） | 重构顶掉（超界） | 按现状重写（同 defects） |
| `Timeline.swift`（:151） | 纯漂移 | 改 `Timeline.nodeColumnWidth` 符号 |

## 三、`docs/component-contract-revisions.md`（29 条）

| 引用 | 档位 | 处置 |
|---|---|---|
| `SurfaceModifier.swift`（:12-13） | 整段被删 | 改「注释已删，git 可取回」 |
| `SurfaceModifier.swift`（:32） | 史料（更正叙述） | 去数字（「错写过一处行号坐标，已删除」） |
| `CircularGlassButtonStyle.swift`（:12）/ `LightButtonStyle.swift`（:14）/ `SolidButtonStyle.swift`（:18） | 重构顶掉（当日 grep 快照已过时） | 文件级化；「internal 两处」保留（今日仍为 2） |
| R-18 ~ R-31 逐字段（16 条，与 registry 同文） | 同 registry | 与 registry **同步替换**（保持两处「逐字」关系） |
| `ComponentJudgeRules.swift`（:378） | 重构顶掉 | 改 `judgeTextParamCoverage` |
| `Timeline.swift`（:220） | 纯漂移 | 去行号（`Timeline` 私有 body 形态） |
| `Timeline.swift`（:61）/ `Steps.swift`（:49） | 纯漂移（探针记录） | 去坐标（`TimelineItem.node` / `StepsIndicatorStyle` 符号保留） |
| `ComponentJudgeScanner.swift`（:135-136） | 注释删 | 改「已删 + 现树可核 `bareTextTypeNames`」 |
| `CodexEntry.swift`（:11-12）/（:173） | 跨仓 | 删行号（「对面仓 `CodexEntry.swift`」） |
| `NetworkGraph.swift`（:13） | 引文源已删 | 改「已删 + git 取回」 |

## 四、`docs/issues/234-a11y-smoke.md`（16 条）

| 引用 | 档位 | 处置 |
|---|---|---|
| `SectionHeader.swift`（:27）/ `CoreMenuButton.swift`（:143）/ `Radio.swift`（:82）×2 / `Carousel.swift`（:115）×2 / `PinCode.swift`（:106）/ `Sidebar.swift`（:109）/ `BottomInputBar.swift`（:151）/ `Rating.swift`（:188-197） | **成立**（行号实测仍指对，10 条） | 仍去行号改「文件 + trait 引文」（形态 2 体例统一） |
| `SegmentedControl.swift`（:147）×2 | 漂移（实为 :149） | 改 trait 引文 |
| `SearchField.swift`（:18）/（:40） | 漂移（实为 :35 / :93） | 去行号（引文已在句中） |
| `SpinningModifier.swift`（:128） | 漂移（实为 :130） | 去行号（`.updatesFrequently` 引文） |
| `App/Sources/ComponentData.swift`（:418） | **抄错**（原引即空行；实际在 :430） | 去行号留 `SearchField(text: self.$text)` 引文 |

⚠️ 同文件 :251-253 还有七处 `UnderlinedTabBar:128` 形态的裸坐标（无 `.swift` 前缀、不命中
本任务正则）——已顺手符号化，但按射程纪律不计入 162 条。

## 五、`docs/component-contract.md`（15 条）

| 引用 | 档位 | 处置 |
|---|---|---|
| `Timeline.swift`（:64）/（:220）/ `Steps.swift`（:49） | 纯漂移 | 改引文（`@ViewBuilder node:` / `private var nodeContent` / `public enum StepsIndicatorStyle`） |
| `Sidebar.swift`（:221） | 纯漂移 | 改引文（`systemImage: String,` + `trailingSystemImage: String? = nil,`） |
| `ComponentJudgeScanner.swift`（:135-136） | 注释删 | 改「已删 + `bareTextTypeNames`」 |
| `CodexEntry.swift`（:11-12）×3 /（:173 区） | 跨仓 | 删行号留引文 |
| `Banner.swift`（:77）/ `SegmentedControl.swift`（:66） | 漂移（实为 :36 / :47） | 改 `public protocol …` 引文 |
| `CrossRepoRegistryGuard.swift`（:98-105）×2 / `TextParamScan.swift`（:127）×2 | 跨仓 | 删行号；G-8 行总说明句改「行号已删（#337 体例）」 |
| `ComponentRegistryGuard.swift`（:366） | 漂移 + 已带更正段 | 改「曾把扫描根硬编码为单根」（时态与下方更正段对齐） |

## 六、其余文件（16 条）

| 文件 · 引用 | 档位 | 处置 |
|---|---|---|
| blossom 计划（5 条：`Package.swift`（:6-32）、`ColorGrade.swift`（:11-23）、`SurfaceColors.swift`（:49-67）、`FunctionalColor.swift`（:17-20）、`InteractionColors.swift`（:10-13）） | 漂移（已执行完的 plan，坐标仍在） | 去行号（文件级引用） |
| async-button spec（3 条：`SolidButtonStyle.swift`（:40）、`BorderlessButtonStyle.swift`（:49）、`Toast.swift`（:287-289）） | 漂移 + 重构（改名 `CoreBorderlessButtonStyle`）+ 引文源已不在 | 补现状引文（disabled 分支 / `onTapGesture` / `toastHost`） |
| `bool-exemptions.json`（2 条：`FloatingGlassModifier.swift`（:20）、`BottomInputBar.swift`（:468）） | 漂移 | 改引文（`let glass = …` / `autoShowSuggestions`）；baseline 计数不受影响（只改 reason 文本，已复核 `BoolExemptionGuard` 与棘轮只读计数） |
| `a11y-exemptions.json`（1 条：`TagInput.swift`（:105）） | 说明性（死豁免故事，位于 `_comment`） | 去行号（引文已在句中） |
| `reachable-type-registry.json`（1 条：`CodexEntry.swift`（:11-12）） | 跨仓 | 删行号留引文 |
| `spikes/248-metal-packaging.md`（1 条：`ColorAssetGuardTests.swift`（:70）） | 漂移（`.enabled` 今在 :40 区） | 去行号（引文已在句中） |
| `BREAKING-CHANGES.md`（1 条：`Sidebar.swift`（:157,411）） | 重构顶掉（删除前坐标） | 改「删除前仅有的两处调用点在 `Sidebar.swift`」 |
| `components/orbiting-logos.md`（2 条：`OrbitRing.swift`（:44）、`OrbitingLogos.swift`（:275-293）） | 漂移 + 引文删 | 改 `static let ringCount: Int = 4` 引文；「logo 必须坐在…」句标「已删」 |

## 七、跨仓清单（13 条，本仓不可核、如实登记）

`CodexEntry.swift`（×6：contract ×3 + revisions ×2 + reachable ×1）、
`FocusModeContainer.swift` / `StoryScaffold.swift` / `ToolCallRow.swift`（defects ×3）、
`CrossRepoRegistryGuard.swift`（×2）、`TextParamScan.swift`（×2）——全部指向对面仓
`wxlpp/oh-my-story`。处置：删行号、保留/补齐逐字引文；登记在
`QuotedEvidenceGuard.crossRepoCitations`（8 条符号级）。**不追进他仓**。
