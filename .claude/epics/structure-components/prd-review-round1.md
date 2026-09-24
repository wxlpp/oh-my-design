REVISE — 现状取证有误，且 Tree、按钮状态机和无障碍验收仍存在会让不同实现 agent 做出不同产品的空白；建议修订后再拆 Issues。

下文“PRD”均指 [`.claude/prds/timeline-tree-action-buttons.md`](/Users/evan/Repositories/work-spec/oh-my-design/.claude/prds/timeline-tree-action-buttons.md)。源码结论来自只读核对，未将源码检查称为运行实测。

1. **[Important] 排除 `OutlineGroup`，不能推出必须放弃原生控件组合**

   **问题**：`OutlineGroup` 的初始折叠限制有依据，但“自己递归”与“使用原生展开控件”并不互斥。PRD 把两个独立选择绑在一起，提前承担了不必要的重造成本。

   **证据**：PRD FR-2 写“自己递归 + 每节点展开绑定”，随后断言“选择与键盘导航不再由 `List` 免费提供，得自己做”。Problem Statement 又称“`DisclosureGroup` 的 `.core` style 都只支持单层”。

   [CoreDisclosureGroupStyle.swift](/Users/evan/Repositories/work-spec/oh-my-design/Sources/OhMyDesign/Components/Style/CoreDisclosureGroupStyle.swift) 实际直接容纳 `configuration.content`，没有禁止嵌套；已有用法：
   `DisclosureGroup("Details", isExpanded: self.$expandedA)`。

   Apple 的 [`DisclosureGroup` 示例](https://developer.apple.com/documentation/swiftui/disclosuregroup?changes=latest_major) 同时展示展开绑定和嵌套 disclosure。普通 [`OutlineGroup` 初始化器](https://developer.apple.com/documentation/swiftui/outlinegroup/init%28_%3Achildren%3Acontent%3A%29-4rmem) 的限制，只能支持排除该初始化路径。

   **建议**：保留受控递归决定，但先比较“递归 `DisclosureGroup(isExpanded:)`”“`List(selection:)` 承载受控层级/可见节点”“完全自定义”三条路径。哪些原生行为能保留应由 spike 证明，不能预先宣称全部需要重做；也不能宣称裸 `List(children:)` 已解决受控展开。

2. **[Important] CheckBox 缺三态外观，不等于需要另造三态控件模型**

   **问题**：目录内关键词零命中只能证明当前样式没有处理 mixed，不能证明底层控件缺少三态能力。“三态不得用 Bool 表达”还可能被实现 agent 理解成禁止使用系统提供的配置。

   **证据**：PRD FR-2 写“CheckBox 现在没有中间态。要先给它加……三态不得用 Bool 表达”。

   [CheckBox.swift](/Users/evan/Repositories/work-spec/oh-my-design/Sources/OhMyDesign/Components/CheckBox/CheckBox.swift) 的真实形态是：
   `public struct CheckBoxToggleStyle: ToggleStyle`，并只判断 `if self.configuration.isOn`。

   Apple 已提供 [`ToggleStyleConfiguration.isMixed`](https://developer.apple.com/documentation/swiftui/togglestyleconfiguration)，以及 [`Toggle(sources:isOn:label:)`](https://developer.apple.com/documentation/swiftui/toggle/init%28sources%3Aison%3Alabel%3A%29)，后者从多个绑定派生 on/mixed/off。

   **建议**：将缺口准确改成“现有样式未呈现系统 mixed 状态”。先验证扩展现有 ToggleStyle 的方案；区分“禁止新增含糊的公开 Bool 参数”和“允许读取系统 `isMixed` / `isOn`”。若仍需新枚举控件，再写明系统方案无法满足的需求。

3. **[Important] Tree 的选择、勾选和过滤缺少共同状态契约**

   **问题**：这几项不是互相独立的功能。现在至少允许两种完全不同实现：行选中与复选框共享一个集合，或维护两套状态；搜索时修改持久化展开集合，或只临时展开。两者都能声称满足 PRD。

   **证据**：PRD FR-2 分别要求“单选 / 多选”“复选框含父节点三态”“按关键词过滤，自动展开到命中节点”，同时要求展开态“可读可写可持久化”，但未定义它们之间的关系。

   **建议**：至少补一个三层树的行为表：点 mixed 父节点的结果、是否级联全部后代、父节点是否进入选择集合、过滤后全选的范围、清空搜索是否恢复原展开态、焦点节点被隐藏后的去向，以及“第 2 层”的计数约定。Tree 宜作为独立交付切片；共用 motion token 不足以要求四项同步完成。

4. **[Important] 键盘清单拼接了不同选择模型，spike 只测按键接收还不够**

   **问题**：按键“能收到”不等于交互契约完整。PRD 没有决定普通方向键是否清除已有选择，也没有定义单选的激活操作。

   **证据**：PRD FR-2 写“上 / 下移动焦点”“Shift + 方向键扩展选区；Ctrl+Space 切换当前项”；FR-2a 重点是这些组合键“是否都能拿到”。

   [W3C Tree View Pattern](https://www.w3.org/WAI/ARIA/apg/patterns/treeview/) 明确区分两套多选模型：推荐模型用 Space 切换，普通移动保留选择；另一模型用 Ctrl+Space，并配套 Ctrl+方向键保留选择。它还定义 Enter 激活、初始焦点和叶节点边界。PRD 引用的 Navigation Treeview 示例并不能替代这套选择决策。

   **建议**：先选定选择模型，再测 macOS/iOS 的实际映射；补 Enter/Space、焦点与选择的关系及原生辅助技术语义。将“最低必须支持哪些操作”写死，避免 FR-2a 把所有失败项移出范围后仍可通过验收。

5. **[Important] StatefulButton 的双重状态所有权没有闭合**

   **问题**：四个枚举 case 不足以构成状态机。托管模式是否由组件写 loading、何时复位、失败能否立即重试，以及外部复位时旧任务完成如何处理，都没有答案。

   **证据**：PRD FR-3 同时写：
   “idle → loading → success → 停留 2 s → 回 idle”、
   “补上 failure 态”、
   “态可由调用方托管，也可由它自管”。
   唯一明确的触发门槛是“loading 期间必须拒绝再次触发”。

   [AsyncButton.swift](/Users/evan/Repositories/work-spec/oh-my-design/Sources/OhMyDesign/Components/Button/AsyncButton.swift) 已有生命周期处理：`.onDisappear { self.task?.cancel() }` 和 `catch is CancellationError`；新组件是否继承这些语义未说明。

   **建议**：分别列托管、自管两套事件—状态表，明确唯一写入方、failure 停留/重试、success 停留期间点击、取消与离屏、过期任务结果的处理。防重入不能只靠可被外部修改的视觉状态。

6. **[Important] SlideToConfirm 把参考实现的速度策略直接当成了产品依据**

   **问题**：先例证明“有人这样实现”，不能证明“适合本 PRD 的高代价确认”。快速短甩也确认，改变的是误触门槛，不只是动画手感；目前只有正例验收。

   **证据**：PRD Problem Statement 将需求解释为“需要持续手势”；FR-4 又承诺“快速甩动没滑到底也算确认”，并把“具体系数”留到实现期。Success Criteria 仅要求构造一次“距离不足但速度足够”的手势。

   **建议**：明确产品是否接受短距离快速确认，规定最小实际行程、方向和释放条件；补短甩、反向拖动、取消拖动、阈值两侧的拒绝用例。若尚无依据，应把速度策略纳入交互 spike，而不是让实现 agent 自选系数后自证通过。

7. **[Important] SlideToConfirm 没有定义完整的执行与重入边界**

   **问题**：确认后何时重新可用，以及错误、取消如何结束，没有契约。尤其“动作完成但回位未完成”的窗口，不同实现可能允许或拒绝再次执行。

   **证据**：PRD FR-4 只写“触发后指示器内换成进度指示、action 走完再回位”；“非 idle 态 `.disabled`”是在描述参考实现，而本组件自己的状态及转换没有定义。

   **建议**：规定拖动、执行、回位三个阶段的可交互性；所有输入路径共用一次执行门闩；补抛错/取消、宿主 `.disabled`、离屏及手势中断行为。验收应覆盖触摸与辅助技术连续激活，只执行一次。

8. **[Important] `.accessibilityRepresentation` 可行，但“存在替代路径”不足以证明可访问**

   **问题**：它可以用 Button 表示滑块；缺陷是 PRD 未规定原子树被替换后必须重新保留什么。标签、进度、结果和提示不会因为原视觉子树里存在就自动得到保留。

   **证据**：PRD FR-4 写“把整个滑块对辅助技术暴露成一个普通 `Button`”；验收仅写“替代路径有判据”。

   Apple 明确说明：“With accessibility representation, the original accessibility is completely replaced.” 见 [WWDC21](https://developer.apple.com/videos/play/wwdc2021/10119/?time=1340)。

   **建议**：要求替代 Button 具有动作名称、执行状态、正确禁用语义，且焦点在状态切换后仍可预测；测试可访问元素的角色/名称/状态及真实激活结果。补 VoiceOver、Voice Control、Switch Control 的操作检查；普通硬件键盘可达性另验，不能由该 modifier 自动推出。

9. **[Important] Timeline 只承诺自适应宽度，没有解决已指出的高度缺陷**

   **问题**：旧问题是固定方框的高度和连线起点；只让列宽随最宽指示器变化，不足以保证高节点不被连线穿过。

   **证据**：PRD FR-1 只明确“指示器列宽由最宽的指示器推导”。而 [Timeline.swift](/Users/evan/Repositories/work-spec/oh-my-design/Sources/OhMyDesign/Components/Timeline/Timeline.swift) 使用：
   `.frame(width: Timeline.nodeColumnWidth, height: Timeline.nodeColumnWidth)`，
   连线使用 `.padding(.top, Timeline.nodeColumnWidth)`，
   alternate 行高也直接纳入 `Timeline.nodeColumnWidth`。

   **建议**：补每行指示器高度、行高和连线端点的规则；用不同尺寸及非正方形节点验证 vertical/alternate/horizontal，明确 grouped 的例外。将“头像画不出来”缩窄为“大于固定槽的头像无法得到正确自适应布局”，24pt 以内头像并非画不出来。

10. **[Important] Timeline 的阶段语义与滚动揭示语义尚未分开**

   **问题**：阶段如何驱动连线、无阶段的历史事件如何显示，以及再次滚入是否重播，都属于用户可见行为，不能只靠选择一个 API 解决。

   **证据**：PRD 同时写“`step <= activeStep` 即已完成”、新增“已完成 / 进行中 / 未开始”，却没给 active 项如何成为“进行中”的规则；FR-1 又把“随阶段补间推进”和“进入视口才播”写在同一条。

   Apple 的 [`scrollTransition`](https://developer.apple.com/documentation/swiftui/view/scrolltransition%28_%3Aaxis%3Atransition%3A%29) 描述的是滚入、滚出的双向效果，并不是一次性的入场事件。

   **建议**：API 拼法可留给任务 spec，但 PRD 应定义阶段真值表、连接段归属、全完成/未开始、阶段回退，以及不使用阶段的活动流模式；另定义滚动重播、无 ScrollView、嵌套滚动和 RM 的行为。把实际容器中的逐节点滚动效果纳入原型验证。

11. **[Important] Timeline 迁移遗漏引文守卫，像素要求也没有划定适用范围**

   **问题**：删改公开 API 和固定尺寸不仅影响编译调用点，还会破坏机器登记的原文证据。与此同时，新布局和新增连线不可能一概与旧实现逐像素相同。

   **证据**：PRD NFR 写“静态外观的像素判据对照原样拷贝的旧实现”，迁移重点列了 `ComponentData.swift` 和 downstream probe。

   [QuotedEvidenceGuard.swift](/Users/evan/Repositories/work-spec/oh-my-design/Tests/OhMyDesignTests/QuotedEvidenceGuard.swift) 却登记了：
   `("docs/component-registry.json", "Sources/OhMyDesign/Components/Timeline/Timeline.swift", "static let nodeColumnWidth: CGFloat = 24")`，
   以及 `@ViewBuilder node: () -> Node,`、`private var nodeContent: some View`。

   [App/Sources/Previews.swift](/Users/evan/Repositories/work-spec/oh-my-design/App/Sources/Previews.swift) 也仍有 `Timeline(items: PreviewSnapshotFixtures.timelineItems, layout: .horizontal)`。

   **建议**：迁移清单加入快照预览、引文台账及其对应活文档，遵守 [CLAUDE.md](/Users/evan/Repositories/work-spec/oh-my-design/CLAUDE.md) 的源码注释/组件文档/registry 三处传播规则。将像素不变限定为保留外观的场景；新增布局行为另设新基线。

12. **[Important] “当前实测 17”与守卫源码不符，不能据此机械调整计数**

   **问题**：PRD 引用了已经漂移的基线。`CLAUDE.md` 中同样的旧数字也不能替代当前源码证据。

   **证据**：PRD NFR 写“`ComponentExtensionPointGuard.inspected.count`，当前实测 17”。

   [ComponentExtensionPointGuard.swift](/Users/evan/Repositories/work-spec/oh-my-design/Tests/OhMyDesignTests/ComponentExtensionPointGuard.swift) 实际为：
   `#expect(result.inspected.count == 16,`
   并逐项列出 16 个组件。

   **建议**：删除未经本轮运行支持的“当前实测”，记录基线 commit 与运行结果；新增组件是否进入该定义域要逐项裁决，不要按新增数量直接加计数。同步更正 `CLAUDE.md` 的过时注记。

13. **[Minor] Timeline 的连线现状被错误套用了 Steps 的实现**

   **问题**：这是明确的“要改的结论可以成立，但现状理由错误”，而且 PRD 自己前后矛盾。

   **证据**：PRD Problem Statement 正确写“状态只驱动圆点颜色，不驱动连线”；FR-1 却称连线是“按状态二选一填色的静态 `Rectangle`”。

   [Timeline.swift](/Users/evan/Repositories/work-spec/oh-my-design/Sources/OhMyDesign/Components/Timeline/Timeline.swift) 固定 `.fill(Color.dividerDefault)`；真正按状态二选一的是 [Steps.swift](/Users/evan/Repositories/work-spec/oh-my-design/Sources/OhMyDesign/Components/Steps/Steps.swift)：`if self.progress(for: index) == .done` 后分别填 `.tint` 和 `.dividerDefault`。

   **建议**：改为“为 Timeline 新增阶段驱动的连线表示与补间”；同时更正 `tripled-analysis.md` 中把两者合并描述的句子。

14. **[Minor] “修正旧设计两点”混淆了策略变化与错误更正，引用位置也错了**

   **问题**：旧距离阈值和 `accessibilityAction` 并未被新证据证明错误；换一种实现应说明收益与代价。PRD 还漏记了成功反馈形态的变化。

   **证据**：PRD FR-4 称“`tripled-analysis.md` A 表第 8 条”。[原分析](/Users/evan/Repositories/work-spec/oh-my-design/.claude/epics/motion-foundations/tripled-analysis.md) 实际是 **P2 第 8 条、A 表第 4 行**。旧条目写：
   “`onDragEnd` ≥180 成功否则 `x.set(0)`”、
   “`accessibilityAction` 直接确认”、
   “成功态用 `.transition(.scale.combined(with: .opacity))`”。

   新 PRD 则只明确执行中进度和结束回位，没有交代旧成功态是否取消。

   **建议**：改为“调整两项策略”，按具名条目引用；明确成功反馈取舍。不要把替换 modifier 写成旧方案无法提供替代操作的证据。

15. **[Important] 核心取证仍依赖会话文件，当前 PRD 还不能独立交接**

   **问题**：多个承重判断无法由接手 agent 从仓库恢复。等到分解时再搬运，无法保证会话材料届时仍在。

   **证据**：PRD Dependencies 自述“两份都在 session scratchpad 里”，并要求“epic 分解时应把仍需引用的结论搬进 `.claude/epics/`”。本次在仓库及所搜索的会话目录中未找到这两份材料。

   **建议**：进入分解前保存引用源码片段、来源 URL、版本/commit 和取舍依据。特别保留滑动阈值代码、reui 行为边界及 Aceternity 状态流，不能只搬结论。

   **未核实的怀疑，单独记录**：本次未取得作者那两份抓取快照，因此不判定“reui Timeline 零动效”“Tree 自身无行为”“七个示例均无多选视觉反馈”及 SlideButton 精确阈值公式为假；它们尚未完成独立复核。