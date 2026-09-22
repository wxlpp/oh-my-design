REVISE — 新增事实中仍有计数错误、原生行为归属错误和更正传播遗漏；部分上一轮问题仅被改写成后续待定事项。

| # | 上一轮 finding | 判定 | 定向复审结论 |
|---|---|---|---|
| 1 | 受控递归不等于放弃原生组合 | **处置不当** | **改得不够**。三路径 spike 合理，但又将 `.core` 描述成“只重排”、暗示保留原生动画与 chevron；实际由样式自行实现。取证材料仍留着“只覆盖单层”，见下文。 |
| 2 | CheckBox 三态不必另造模型 | **已处置** | SDK 明确标注 `isMixed` 和聚合 Toggle 自 iOS 16 / macOS 13 可用；[Apple 文档](https://developer.apple.com/documentation/swiftui/toggle/init%28sources%3Aison%3Alabel%3A%29)支持从集合派生 on/mixed/off。当前部署目标可直接使用。 |
| 3 | Tree 共同状态契约 | **处置不当** | **改得不够**。FR-2 的七行仍全部是问题，没有答案。拆成两个 epic 的用户决策自洽，理由已写清；Tree 留在 structure-components、后续拆 task 不构成问题。 |
| 4 | 键盘选择模型与最低保障 | **处置不当** | **改得不够**。已选推荐模型并设硬下限，但“初始焦点落在哪、叶节点上按右键”仍只是待定项目；单选模式下 Space 如何改变选择也未明确。 |
| 5 | StatefulButton 状态所有权 | **处置不当** | **改得不够**。独立执行门闩已明确；但唯一写入方、失败重试、成功期间点击、取消与过期结果仍是“spec 须给出”，两套状态表尚不存在。 |
| 6 | 速度补偿缺少产品依据 | **已处置** | 纯距离的用户决策自洽。FR-4 写清高代价确认的理由、实际行程阈值和拒绝短甩等负例，无须照原建议保留速度补偿。 |
| 7 | SlideToConfirm 执行与重入边界 | **处置不当** | **改得不够**。共用门闩已明确，但执行／回位期间可交互性、错误和取消收尾仍未决定。 |
| 8 | 无障碍替代表示的完整契约 | **已处置** | 已明确名称、状态、禁用、焦点、实际激活，以及三类辅助技术和独立键盘验证。 |
| 9 | Timeline 高度与连线端点 | **已处置** | 已补行高、实际几何端点、非正方形节点和三种布局验证，并明确 grouped 例外。 |
| 10 | 阶段语义与滚动揭示 | **处置不当** | **改得不够**。概念已分开，但阶段真值表、连接段归属、活动流着色、回退和重播规则仍后移至 spec。API 拼法可后移，这些产品行为仍需共同定案。 |
| 11 | 迁移面与像素适用范围 | **处置不当** | **部分改错**。5 条引文记录、三份文档归属和像素范围均正确；新增调用点计数错误，且“漏一条 CI 就红”不成立。 |
| 12 | 17 条基线漂移 | **处置不当** | **改得不够，历史解释也不准确**。当前源码确为 16；但镜像未同步，且 17 曾是有效历史基线，不能笼统说那个数本身失真。 |
| 13 | Timeline 连线误套 Steps | **已处置** | PRD 与旧分析均已分开描述；旧分析 P2 第 9 条及 B 表对应行均已更正，与两份源码一致。 |
| 14 | 策略变化、引用位置与成功反馈 | **已处置** | P2 第 8 条／A 表第 4 行定位正确；已区分策略调整与纠错，并明确不采旧成功转场。 |
| 15 | 取证依赖会话文件 | **已处置** | 材料已入仓，包含来源、源码片段和取舍依据，可交接。材料自身仍有下述错误，落盘不等于内容正确。 |

以下是任务二发现的问题。证据基于当前工作树（HEAD `e6efb5a`）、Git 历史、本机 SDK 与官方文档；未把源码检查称为运行实测。

**[Important] 迁移调用点各少算一处**

**问题**：修订稿声称两个文件分别有 3、4 个调用点，实际是 **4、5 个源码调用点**。多行调用同样必须计入。

**证据**：

- [PRD:118](/Users/evan/Repositories/work-spec/oh-my-design/.claude/prds/timeline-tree-action-buttons.md:118)：
  > `App/Sources/ComponentData.swift` 3 个调用点、`App/Sources/Previews.swift` 4 个调用点
- [ComponentData.swift:1633](/Users/evan/Repositories/work-spec/oh-my-design/App/Sources/ComponentData.swift:1633)：1633、1634、1655、1656 四处，分别为 `Timeline(items: Self.items)`、多行 `Timeline(`、`.horizontal`、`.grouped`。
- [Previews.swift:420](/Users/evan/Repositories/work-spec/oh-my-design/App/Sources/Previews.swift:420)：420、441、451、452、482 五处；482 逐字为：
  > `Timeline(items: PreviewSnapshotFixtures.timelineItems, layout: .alternate)`

**建议**：改为 4／5，并列出对应预览名称或布局，避免计数再次漏掉多行构造器。区分源码调用点与循环产生的运行时实例数。

**[Important] “迁移清单漏一条 CI 就红”扩大了验证覆盖**

**问题**：清单包含预览宿主，CI 并不构建它。该承诺会让接手者错误地用 CI 全绿判断迁移完整。

**证据**：

- [PRD:116](/Users/evan/Repositories/work-spec/oh-my-design/.claude/prds/timeline-tree-action-buttons.md:116)：
  > FR-1 的迁移面（必须逐条处置，漏一条 CI 就红）
- [CLAUDE.md:117](/Users/evan/Repositories/work-spec/oh-my-design/CLAUDE.md:117)：
  > `App/`（预览宿主）不受 `swift build` / `swift test` 覆盖，CI 也不构建它
- [ci.yml:215](/Users/evan/Repositories/work-spec/oh-my-design/.github/workflows/ci.yml:215) 的 iOS 验证走包测试；工作流未出现预览宿主项目构建。

**建议**：改成“必须逐条处置，并分别验证”。明确预览宿主要独立构建，不能靠 CI 推断其可编译。

**[Important] `.core` 的自绘行为被说成仅重排，旧“单层限制”也未清除**

**问题**：递归 `DisclosureGroup(isExpanded:)` 可行；但套用本仓 `.core` 后，点击处理、chevron 和动画由样式自行提供。“系统持有／连接展开状态”不能推出“样式只重排、保留原生交互呈现”。

**证据**：

- [PRD:58](/Users/evan/Repositories/work-spec/oh-my-design/.claude/prds/timeline-tree-action-buttons.md:58)：
  > `CoreDisclosureGroupStyle` 只重排 label / content、「展开状态仍由系统驱动」
- [源码:30](/Users/evan/Repositories/work-spec/oh-my-design/Sources/OhMyDesign/Components/Style/CoreDisclosureGroupStyle.swift:30)：
  ```swift
  Button {
      withAnimation(.snappy) {
          configuration.isExpanded.toggle()
      }
  ```
  同文件另行绘制 `DisclosureChevron`，并按状态执行 `.rotationEffect(...)`。
- [组件文档:23](/Users/evan/Repositories/work-spec/oh-my-design/docs/components/core-control-styles.md:23) 已明确：
  > 换皮后系统不再自动为这个自绘 `Button` 播报展开态
- [repo-survey.md:563](/Users/evan/Repositories/work-spec/oh-my-design/.claude/epics/structure-components/repo-survey.md:563) 仍写：
  > `InsetGroupedSection` 和 `DisclosureGroup` 的 `.core` style 都只覆盖单层。

**建议**：分别描述默认 DisclosureGroup 与 `.core`：后者复用系统状态接口，自绘整行按钮、chevron、动画及展开状态播报，不限制内容嵌套。同步修改源码第 24 行的误导注释、PRD 和 survey；登记表关于整行 Button 命中区的描述应保留。

**[Minor] “没有多选视觉反馈”把行选择与复选框勾选混为一谈**

**问题**：不能从“未找到 headless-tree 多行选择演示”扩大成“没有任何多选视觉反馈”。已保存的权限树示例就是多个叶子复选框的受控勾选呈现。

**证据**：

- [PRD:319](/Users/evan/Repositories/work-spec/oh-my-design/.claude/prds/timeline-tree-action-buttons.md:319)：
  > 没有一个展示拖拽或多选的视觉反馈（已核实），无可对照的现成形态。
- [reference-implementations.md:854](/Users/evan/Repositories/work-spec/oh-my-design/.claude/epics/structure-components/reference-implementations.md:854)：
  > Permissions tree with checkboxes（`c-tree-7`，受控多选状态，完整）
  ```tsx
  new Set(["users-view", "content-view", "content-publish", "billing-view", "api-read"])
  ```
  并实际渲染：
  ```tsx
  checked={checked.has(id)}
  onCheckedChange={() => togglePermission(id)}
  ```
- 同一材料明确解释：
  > 勾选与展开/选中是两套独立的点击目标

**建议**：缩窄为“未找到拖拽重排及 headless-tree 行多选的完整示例；权限树提供独立复选框勾选形态”。同步修正取证报告 §2.5 和“取不到的部分”第 3 条的宽泛结论。

**[Minor] 16 的当前结论正确，但更正抹平了基线变化，且漏同步镜像**

**问题**：17 并非从来就是错误数字。#312 落地时源码确为 17；之后删除 `SidebarUtilityRow` 才降到 16。本轮应更正“把历史基线当现状”，不能把历史记录本身推翻。同时 `AGENTS.md` 仍在重复过时现状。

**证据**：

- [CLAUDE.md:64](/Users/evan/Repositories/work-spec/oh-my-design/CLAUDE.md:64)：
  > 本行原写「**实测 17**」，是失真的数
- Git 对同一文件 `Tests/OhMyDesignTests/ComponentExtensionPointGuard.swift` 的历史证据：
  - `911e15d`（#312）逐字为 `#expect(result.inspected.count == 17,`
  - `39fecab` 的提交说明逐字为：
    > ComponentExtensionPointGuard inspected.count 17 -> 16 (SidebarUtilityRow)
- [AGENTS.md:66](/Users/evan/Repositories/work-spec/oh-my-design/AGENTS.md:66) 仍写：
  > **实测 17**，`#312` 把 `OrbitingLogos` 翻进定义域后的值
- [orbiting-logos.md:397](/Users/evan/Repositories/work-spec/oh-my-design/docs/components/orbiting-logos.md:397) 保留 #312 的历史结果：
  > J-2 定义域 **17** 条、全部满足

**建议**：PRD／CLAUDE 改成“#312 时为 17，`39fecab` 删除 SidebarUtilityRow 后为 16，旧现状注记未同步”，并同步 AGENTS。OrbitingLogos 的历史数字不要机械改成 16；可补当前基线说明。源码注释和 registry notes 中未发现需要同步替换的同类当前计数。

**未核实的怀疑**

“7 个示例均未演示 headless-tree **行多选**”仍不能仅凭落盘材料独立证明：报告没有保存七份完整源码，核对标题和 import 也不足以证明运行时选择行为不存在。本轮已证明的是其宽泛的“没有多选视觉反馈”不成立；没有据此反推一定存在行多选或拖拽演示。