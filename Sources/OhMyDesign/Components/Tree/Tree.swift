import SwiftUI

// MARK: - Tree

/// 递归层级树 / Recursive tree：受控展开 + 行选中（单选 / 多选）+ 可选的三态复选框 +
/// W3C ARIA Treeview 键盘导航。
///
/// 展开态是调用方持有的 `Set<ID>`，可读可写可持久化；「默认展开到第 N 层」用
/// `Tree.expandedIDs(_:id:children:toDepth:)` 预算一份（**根为第 1 层**）。
/// 行选中与复选框是两套独立状态：前者是导航语义，后者是数据语义，互不写入。
/// 复选框只落在叶节点上——父行的勾选态由 `Toggle(sources:isOn:)` 从后代绑定派生
/// （含系统的 mixed 态），父节点自身**永不进** `checked` 集合。
///
/// 行距、缩进、chevron 与复选框字形跟随环境 `controlSize`；iOS 上行距不低于 44 pt。
/// 行外观由 `.treeStyle(_:)` 选择（`.automatic` / `.navigator`）；整行（含缩进区）都是点选区，
/// 也是 `rowContextMenu(_:)` 的右键区；单击父行是否同时展开由 `rowClickBehavior(_:)` 决定。
///
/// ⚠️ **不是原生外观**：可见行按深度优先展平进 `LazyVStack`（放在 `ScrollView` 里时只构建视口附近的行），
/// chevron、缩进、行选中底色与无障碍播报全部自绘。
public struct Tree<Data: RandomAccessCollection, ID: Hashable, RowContent: View>: View {
    // MARK: - Init

    /// 创建层级树。
    ///
    /// - Parameters:
    ///   - data: 根节点集合。
    ///   - id: 从元素取稳定 ID 的 key path；ID 在整棵树内必须唯一。
    ///   - children: 从元素取子节点的 key path；`nil` 或空集合都视为叶节点。
    ///   - expanded: 已展开节点 ID 集合的双向绑定，由调用方持有。
    ///   - selection: 已选中行 ID 集合的双向绑定。
    ///   - selectionMode: 行选择模式，默认 `.single`。
    ///   - checked: 已勾选叶节点 ID 集合的双向绑定；传 `nil`（默认）时不显示复选框。
    ///     传入时 `⌥Space` 切换焦点行的勾选，行内容带「Check / Uncheck」无障碍动作。
    ///   - onActivate: `Enter` 激活焦点行时的回调；与选中**分开**。传 `nil` 时 `Enter` 交回系统。
    ///   - content: 由元素生成行内容，常为 `Text` 或 `Label`；也用作该行复选框的无障碍标签。
    public init(
        _ data: Data,
        id: KeyPath<Data.Element, ID>,
        children: KeyPath<Data.Element, Data?>,
        expanded: Binding<Set<ID>>,
        selection: Binding<Set<ID>>,
        selectionMode: TreeSelectionMode = .single,
        checked: Binding<Set<ID>>? = nil,
        onActivate: ((ID) -> Void)? = nil,
        @ViewBuilder content: @escaping (Data.Element) -> RowContent
    ) {
        self.data = data
        self.id = id
        self.children = children
        self._expanded = expanded
        self._selection = selection
        self.selectionMode = selectionMode
        self.checked = checked
        self.onActivate = onActivate
        self.content = content
    }

    @Binding private var expanded: Set<ID>
    @Binding private var selection: Set<ID>
    @State private var focus: ID?
    @State private var lastInteraction: TreeInteraction = .pointer
    @State private var pointerClaimsFocus = false
    @State private var searchSession: TreeSearchSession<ID>?
    @FocusState private var isFocused: Bool
    @Environment(\.coreMotionPresentation) private var motionPresentation
    @Environment(\.controlSize) private var controlSize

    public var body: some View {
        let frame = self.searchFrame
        let items = TreeFlatten.items(
            self.data, id: self.id, children: self.children,
            expanded: frame.expansion.effective, included: frame.included
        )
        let rows = items.map(\.row)
        let metrics = TreeRowMetrics.resolve(self.controlSize)
        return TreeRowStack(items: items, context: self.context(rows: rows, metrics: metrics, frame: frame))
            .frame(maxWidth: .infinity, alignment: .leading)
            .focusable()
            .focused(self.$isFocused)
            .onKeyPress(phases: .down) { press in self.handle(press, items: items, frame: frame) }
            .onChange(of: rows) { oldRows, newRows in
                self.commit(
                    TreeInteractionReducer.rowsChanged(state: self.interactionState(frame), from: oldRows, to: newRows),
                    frame: frame
                )
            }
            .onChange(of: self.isFocused) { _, focused in self.focusChanged(focused, rows: rows, frame: frame) }
            .onChange(of: frame.query) { self.searchSession = nil }
            .coreAnimation(.selection, value: self.selection)
    }

    // MARK: - 默认展开到第 N 层 / Expand-to-depth

    /// 算出「默认展开到第 `depth` 层」对应的展开集合——**根节点算第 1 层**，
    /// 所以 `toDepth: 1` 是全折叠、`toDepth: 2` 只展开根这一层。
    ///
    /// - Parameters:
    ///   - data: 根节点集合。
    ///   - id: 从元素取稳定 ID 的 key path。
    ///   - children: 从元素取子节点的 key path。
    ///   - depth: 要展开到的层数，根为第 1 层。
    /// - Returns: 该层数下应处于展开态的节点 ID 集合。
    nonisolated public static func expandedIDs(
        _ data: Data,
        id: KeyPath<Data.Element, ID>,
        children: KeyPath<Data.Element, Data?>,
        toDepth depth: Int
    ) -> Set<ID> {
        TreeFlatten.expandedIDs(data, id: id, children: children, toDepth: depth)
    }

    // MARK: - 交互接线 / Interaction wiring

    private var searchFrame: TreeSearchFrame<ID> {
        TreeSearch.frame(
            self.data, id: self.id, children: self.children,
            query: self.search?.query, text: self.search?.text,
            persisted: self.expanded, session: self.searchSession
        )
    }

    private func interactionState(_ frame: TreeSearchFrame<ID>) -> TreeInteractionState<ID> {
        TreeInteractionState(
            focus: self.focus,
            lastInteraction: self.lastInteraction,
            selection: self.selection,
            expansion: frame.expansion
        )
    }

    private func commit(
        _ next: TreeInteractionState<ID>,
        frame: TreeSearchFrame<ID>,
        expansionMotion: MotionPresentation? = nil
    ) {
        if next.focus != self.focus { self.focus = next.focus }
        if next.lastInteraction != self.lastInteraction { self.lastInteraction = next.lastInteraction }
        if next.selection != self.selection { self.selection = next.selection }
        if next.expansion != frame.expansion {
            let session = TreeSearch.session(from: next.expansion, query: frame.query)
            withAnimation(expansionMotion.flatMap(CoreMotionToken.treeExpansion(for:))) {
                if next.expansion.persisted != self.expanded { self.expanded = next.expansion.persisted }
                if session != self.searchSession { self.searchSession = session }
            }
        }
    }

    private func handle(
        _ press: KeyPress,
        items: [TreeRenderItem<Data.Element, ID>],
        frame: TreeSearchFrame<ID>
    ) -> KeyPress.Result {
        let outcome = TreeInteractionReducer.key(
            TreeKeyboard.key(for: press.key),
            modifiers: press.modifiers,
            state: self.interactionState(frame),
            rows: items.map(\.row),
            mode: self.selectionMode,
            activation: self.onActivate == nil ? .disabled : .enabled,
            checkColumn: self.checked == nil ? .absent : .present,
            motion: self.motionPresentation,
            treeIDs: { self.treeIDs },
            ancestors: self.ancestors(of:)
        )
        self.commit(outcome.state, frame: frame, expansionMotion: outcome.expansionMotion)
        if let activated = outcome.activated { self.onActivate?(activated) }
        if let target = outcome.checkToggled, let checked = self.checked,
           let item = items.first(where: { $0.id == target }) {
            checked.wrappedValue = TreeChecking.togglingRow(
                item.element, id: self.id, children: self.children, within: frame.included, in: checked.wrappedValue
            )
        }
        return outcome.result
    }

    private func focusChanged(_ focused: Bool, rows: [TreeRow<ID>], frame: TreeSearchFrame<ID>) {
        let source: TreeInteraction = self.pointerClaimsFocus ? .pointer : .keyboard
        self.pointerClaimsFocus = false
        guard focused else { return }
        self.commit(
            TreeInteractionReducer.focusEntered(
                via: source, state: self.interactionState(frame), rows: rows, ancestors: self.ancestors(of:)
            ),
            frame: frame
        )
    }

    private func click(_ id: ID) {
        let frame = self.searchFrame
        let outcome = TreeInteractionReducer.pointerClick(
            id,
            behavior: self.clickBehavior,
            state: self.interactionState(frame),
            rows: self.visibleRows(frame),
            mode: self.selectionMode,
            motion: self.motionPresentation,
            treeIDs: { self.treeIDs }
        )
        guard outcome.result == .handled else { return }
        if !self.isFocused {
            self.pointerClaimsFocus = true
            self.isFocused = true
        }
        self.commit(outcome.state, frame: frame, expansionMotion: outcome.expansionMotion)
    }

    private func toggleExpansion(_ id: ID) {
        let frame = self.searchFrame
        let outcome = TreeInteractionReducer.pointerToggle(
            id, state: self.interactionState(frame), rows: self.visibleRows(frame), motion: self.motionPresentation
        )
        self.commit(outcome.state, frame: frame, expansionMotion: outcome.expansionMotion)
    }

    private func visibleRows(_ frame: TreeSearchFrame<ID>) -> [TreeRow<ID>] {
        TreeFlatten.rows(
            self.data, id: self.id, children: self.children,
            expanded: frame.expansion.effective, included: frame.included
        )
    }

    // MARK: - 派生 / Derived

    private var treeIDs: Set<ID> {
        TreeFlatten.allIDs(self.data, id: self.id, children: self.children)
    }

    private func ancestors(of hidden: ID) -> [ID] {
        TreeFlatten.ancestorIDs(of: hidden, in: self.data, id: self.id, children: self.children)
    }

    private func context(
        rows: [TreeRow<ID>],
        metrics: TreeRowMetrics,
        frame: TreeSearchFrame<ID>
    ) -> TreeContext<Data, ID, RowContent> {
        TreeContext(
            id: self.id,
            children: self.children,
            expanded: frame.expansion.effective,
            included: frame.included,
            selection: self.selection,
            checked: self.checked,
            focus: self.focus,
            metrics: metrics,
            showsFocusIndicator: TreeFocusing.showsRing(
                containerFocused: self.isFocused, lastInteraction: self.lastInteraction
            ),
            clickBehavior: self.clickBehavior,
            click: { id in self.click(id) },
            toggleExpansion: { id in self.toggleExpansion(id) },
            notePointerCheck: {
                self.commit(TreeInteractionReducer.pointerCheck(state: self.interactionState(frame)), frame: frame)
            },
            rowMenu: self.rowMenu,
            selectedVisible: self.rowMenu == nil
                ? []
                : TreeContextMenu.selectedVisible(self.selection, visibleIDs: Set(rows.map(\.id))),
            content: self.content
        )
    }

    private let data: Data
    private let id: KeyPath<Data.Element, ID>
    private let children: KeyPath<Data.Element, Data?>
    private let selectionMode: TreeSelectionMode
    private let checked: Binding<Set<ID>>?
    private let onActivate: ((ID) -> Void)?
    private let content: (Data.Element) -> RowContent
    private var rowMenu: ((Set<ID>) -> AnyView)?
    private var search: TreeSearchSpec<Data.Element>?
    private var clickBehavior: TreeRowClickBehavior = .select
}

struct TreeSearchSpec<Element> {
    let query: String
    let text: (Element) -> String
}

// MARK: - 搜索过滤 / Search filter

public extension Tree {
    /// 按搜索词过滤行：留下文案命中的节点、它们的祖先与后代，并**临时**展开到每个命中。
    ///
    /// 匹配规则：`query` 去首尾空白后，在 `text` 给出的文案里做不区分大小写 / 变音符 / 全半角的子串匹配；
    /// 去空白后为空即不在搜索，树与不调用本方法时相同。搜索期间的展开 / 折叠只作用于本次搜索，
    /// 不写 `expanded` 绑定；清空搜索词即丢弃这些临时展开，按调用方当前的 `expanded` 显示。
    /// 键盘、全选、右键菜单与焦点只作用于过滤后的可见行。父行复选框的三态仍按它**全部**叶后代显示，
    /// 点击只勾选 / 取消被过滤留下的叶后代（含因折叠未显示的）。无命中时不显示任何行，由调用方显示空态；
    /// 命中数用 `Tree.searchMatches(_:id:children:query:text:)` 求。命中片段的高亮用 `Text(verbatim:highlighting:)`
    /// 画在行内容里。直接在 `Tree` 上调用，放在其它 modifier 之前。
    ///
    /// - Parameters:
    ///   - query: 当前搜索词，由调用方持有。
    ///   - text: 从元素取用于匹配的文案。
    /// - Returns: 带搜索过滤的同一棵树。
    func searchFilter(_ query: String, text: @escaping (Data.Element) -> String) -> Tree {
        var tree = self
        tree.search = TreeSearchSpec(query: query, text: text)
        return tree
    }

    /// 求搜索词**直接命中**的节点 ID（不含只因是命中的祖先 / 后代而留下的节点），与 `searchFilter(_:text:)`
    /// 同一个实现，供调用方算命中数、显示空态或播报结果数。搜索词去首尾空白后为空时返回空集。
    ///
    /// - Parameters:
    ///   - data: 根节点集合。
    ///   - id: 从元素取稳定 ID 的 key path。
    ///   - children: 从元素取子节点的 key path。
    ///   - query: 当前搜索词。
    ///   - text: 从元素取用于匹配的文案，与传给 `searchFilter(_:text:)` 的相同。
    /// - Returns: 文案命中的节点 ID 集合。
    nonisolated static func searchMatches(
        _ data: Data,
        id: KeyPath<Data.Element, ID>,
        children: KeyPath<Data.Element, Data?>,
        query: String,
        text: (Data.Element) -> String
    ) -> Set<ID> {
        TreeSearch.result(data, id: id, children: children, query: query, text: text).matches
    }
}

// MARK: - 整行右键菜单 / Row context menu

public extension Tree {
    /// 为整行（含缩进区）挂右键菜单。菜单作用于目标集合：右键的行已选中时，为选中集合里
    /// 当前可见的行（被折叠隐藏的选中项、不属于本树的 ID 都不在内）；否则只是右键的那一行。
    /// 唤起菜单不改变选中与焦点。builder 只在取菜单时求值（渲染行时不求值），在视图更新期执行：
    /// 必须是纯的，不要在里面写状态。直接在 `Tree` 上调用，放在其它 modifier 之前。
    ///
    /// - Parameter menu: 以目标 ID 集合生成菜单项。
    /// - Returns: 挂好菜单的同一棵树。
    func rowContextMenu<M: View>(@ViewBuilder _ menu: @escaping (Set<ID>) -> M) -> Tree {
        var tree = self
        tree.rowMenu = { targets in AnyView(menu(targets)) }
        return tree
    }
}

// MARK: - 单击父行 / Row click behavior

public extension Tree {
    /// 设置单击父行（行内容或缩进区）时做什么：`.select`（默认）只选中；`.selectAndToggleExpansion`
    /// 选中并取反该行的展开态（VS Code Explorer 式）。
    ///
    /// 展开态的取反不看这一击是选中还是取消选中。`.single` 下单击父行恒为选中（再点已选中的父行保持选中），
    /// `.multiple` 下仍逐行切换。叶行、chevron（仍只切换展开）、复选框（仍只勾选）与键盘都不受影响；
    /// 行内容里调用方自己的 `Button` / `Link` 先接到点击。搜索期间的展开只作用于本次搜索，与点 chevron 相同。
    /// 直接在 `Tree` 上调用，放在其它 modifier 之前。
    ///
    /// - Parameter behavior: 单击父行的行为。
    /// - Returns: 带该点击行为的同一棵树。
    func rowClickBehavior(_ behavior: TreeRowClickBehavior) -> Tree {
        var tree = self
        tree.clickBehavior = behavior
        return tree
    }
}

// MARK: - Identifiable convenience init

public extension Tree where Data.Element: Identifiable, ID == Data.Element.ID {
    /// 以元素自身的 `id` 作标识的便利构造。
    ///
    /// - Parameters:
    ///   - data: 根节点集合，元素须 `Identifiable`。
    ///   - children: 从元素取子节点的 key path。
    ///   - expanded: 已展开节点 ID 集合的双向绑定。
    ///   - selection: 已选中行 ID 集合的双向绑定。
    ///   - selectionMode: 行选择模式，默认 `.single`。
    ///   - checked: 已勾选叶节点 ID 集合的双向绑定；传 `nil` 时不显示复选框。
    ///   - onActivate: 激活某行时的回调。
    ///   - content: 由元素生成行内容。
    init(
        _ data: Data,
        children: KeyPath<Data.Element, Data?>,
        expanded: Binding<Set<ID>>,
        selection: Binding<Set<ID>>,
        selectionMode: TreeSelectionMode = .single,
        checked: Binding<Set<ID>>? = nil,
        onActivate: ((ID) -> Void)? = nil,
        @ViewBuilder content: @escaping (Data.Element) -> RowContent
    ) {
        self.init(
            data,
            id: \.id,
            children: children,
            expanded: expanded,
            selection: selection,
            selectionMode: selectionMode,
            checked: checked,
            onActivate: onActivate,
            content: content
        )
    }
}

// MARK: - 免写行内容泛型的 expandedIDs / expandedIDs without the row-content generic

public extension Tree where RowContent == EmptyView {
    /// 同 `expandedIDs(_:id:children:toDepth:)`，但不必写出无关的行内容泛型：
    /// `Tree.expandedIDs(roots, id: \.id, children: \.children, toDepth: 2)`。
    ///
    /// - Parameters:
    ///   - data: 根节点集合。
    ///   - id: 从元素取稳定 ID 的 key path。
    ///   - children: 从元素取子节点的 key path。
    ///   - depth: 要展开到的层数，根为第 1 层。
    /// - Returns: 该层数下应处于展开态的节点 ID 集合。
    nonisolated static func expandedIDs(
        _ data: Data,
        id: KeyPath<Data.Element, ID>,
        children: KeyPath<Data.Element, Data?>,
        toDepth depth: Int
    ) -> Set<ID> {
        TreeFlatten.expandedIDs(data, id: id, children: children, toDepth: depth)
    }

    /// 同 `searchMatches(_:id:children:query:text:)`，但不必写出无关的行内容泛型：
    /// `Tree.searchMatches(roots, id: \.id, children: \.children, query: query, text: \.name).count`。
    ///
    /// - Parameters:
    ///   - data: 根节点集合。
    ///   - id: 从元素取稳定 ID 的 key path。
    ///   - children: 从元素取子节点的 key path。
    ///   - query: 当前搜索词。
    ///   - text: 从元素取用于匹配的文案。
    /// - Returns: 文案命中的节点 ID 集合。
    nonisolated static func searchMatches(
        _ data: Data,
        id: KeyPath<Data.Element, ID>,
        children: KeyPath<Data.Element, Data?>,
        query: String,
        text: (Data.Element) -> String
    ) -> Set<ID> {
        TreeSearch.result(data, id: id, children: children, query: query, text: text).matches
    }
}

// MARK: - 行上下文 / Row context

struct TreeContext<Data: RandomAccessCollection, ID: Hashable, RowContent: View> {
    let id: KeyPath<Data.Element, ID>
    let children: KeyPath<Data.Element, Data?>
    let expanded: Set<ID>
    let included: Set<ID>?
    let selection: Set<ID>
    let checked: Binding<Set<ID>>?
    let focus: ID?
    let metrics: TreeRowMetrics
    let showsFocusIndicator: Bool
    let clickBehavior: TreeRowClickBehavior
    let click: (ID) -> Void
    let toggleExpansion: (ID) -> Void
    let notePointerCheck: () -> Void
    let rowMenu: ((Set<ID>) -> AnyView)?
    let selectedVisible: Set<ID>
    let content: (Data.Element) -> RowContent

    func checkState(of leafID: ID, in checked: Binding<Set<ID>>) -> Binding<Bool> {
        Binding(
            get: { checked.wrappedValue.contains(leafID) },
            set: { newValue in
                self.notePointerCheck()
                checked.wrappedValue = TreeChecking.applying(
                    newValue, toLeaves: [leafID], in: checked.wrappedValue
                )
            }
        )
    }
}

// MARK: - 展平行栈 / Flattened row stack

struct TreeRowStack<Data: RandomAccessCollection, ID: Hashable, RowContent: View>: View {
    let items: [TreeRenderItem<Data.Element, ID>]
    let context: TreeContext<Data, ID, RowContent>

    var body: some View {
        LazyVStack(alignment: .leading, spacing: self.context.metrics.rowSpacing) {
            ForEach(self.items) { item in
                TreeRowHost(
                    element: item.element,
                    level: item.row.level,
                    hasChildren: item.row.hasChildren,
                    context: self.context
                )
            }
        }
    }
}

// MARK: - 展开动效 / Expansion motion

extension CoreMotionToken {
    nonisolated static func treeExpansion(for presentation: MotionPresentation) -> Animation? {
        CoreMotionToken.reveal.animation(for: presentation)
    }
}

// MARK: - 行宿主 / Row host

struct TreeRowHost<Data: RandomAccessCollection, ID: Hashable, RowContent: View>: View {
    let element: Data.Element
    let level: Int
    let hasChildren: Bool
    let context: TreeContext<Data, ID, RowContent>

    @Environment(\.treeStyle) private var style
    @State private var isHovered = false

    var body: some View {
        let elementID = self.element[keyPath: self.context.id]
        let isExpanded = self.context.expanded.contains(elementID)
        let isSelected = self.context.selection.contains(elementID)
        let configuration = TreeRowConfiguration(
            label: self.context.content(self.element)
                .accessibilityValue(self.expansionValue(isExpanded: isExpanded))
                .accessibilityHint(Text(LocalizedStringKey(self.clickHint ?? ""), bundle: .module), isEnabled: self.clickHint != nil)
                .accessibilityAddTraits(TreeRowAccessibility.traits(isSelected: isSelected))
                .accessibilityActions { self.checkAction },
            disclosure: TreeDisclosureControl(
                hasChildren: self.hasChildren, isExpanded: isExpanded, metrics: self.context.metrics
            ) {
                self.context.toggleExpansion(elementID)
            },
            checkBox: self.context.checked.map { self.checkBox($0) },
            level: self.level,
            hasChildren: self.hasChildren,
            isExpanded: isExpanded,
            isSelected: isSelected,
            showsFocusIndicator: self.context.showsFocusIndicator && self.context.focus == elementID,
            isHovered: self.isHovered,
            metrics: self.context.metrics
        )
        return self.row(configuration)
            .frame(minHeight: self.context.metrics.rowHeight)
            .contentShape(Rectangle())
            .modifier(TreeRowMenu(
                menu: self.context.rowMenu,
                targets: TreeContextMenu.targets(for: elementID, selectedVisible: self.context.selectedVisible)
            ))
            .onTapGesture { self.context.click(elementID) }
    }

    @ViewBuilder
    private func row<Label: View>(_ configuration: TreeRowConfiguration<Label>) -> some View {
        switch self.style.appearance {
        case .automatic:
            AutomaticTreeRow(configuration: configuration)
                .onAppear { self.isHovered = false }
        case .navigator:
            NavigatorTreeRow(configuration: configuration)
                .contentShape(Rectangle())
                .onHover { hovering in self.isHovered = hovering }
                .onDisappear { self.isHovered = false }
        }
    }

    private func checkBox(_ checked: Binding<Set<ID>>) -> TreeRowCheckBox {
        let leaves = TreeFlatten.descendantLeafIDs(
            of: self.element, id: self.context.id, children: self.context.children
        )
        guard let hint = TreeRowAccessibility.checkBoxHintKey(
            hasChildren: self.hasChildren, isSearching: self.context.included != nil
        ) else {
            return TreeRowCheckBox(
                sources: leaves.map { self.context.checkState(of: $0, in: checked) },
                label: AnyView(self.context.content(self.element)),
                hint: nil,
                metrics: self.context.metrics
            )
        }
        let retained = TreeFlatten.descendantLeafIDs(
            of: self.element, id: self.context.id, children: self.context.children, within: self.context.included
        )
        return TreeRowCheckBox(
            sources: TreeCheckBindings.scoped(
                display: leaves, scope: retained, in: checked, onWrite: self.context.notePointerCheck
            ),
            label: AnyView(self.context.content(self.element)),
            hint: hint,
            metrics: self.context.metrics
        )
    }

    @ViewBuilder
    private var checkAction: some View {
        if let checked = self.context.checked {
            let scope = TreeFlatten.descendantLeafIDs(
                of: self.element, id: self.context.id, children: self.context.children, within: self.context.included
            )
            Button {
                self.context.notePointerCheck()
                checked.wrappedValue = TreeChecking.togglingRow(
                    self.element, id: self.context.id, children: self.context.children,
                    within: self.context.included, in: checked.wrappedValue
                )
            } label: {
                Text(LocalizedStringKey(TreeRowAccessibility.checkActionKey(scope: scope, in: checked.wrappedValue)), bundle: .module)
            }
        }
    }

    private var clickHint: String? {
        TreeRowAccessibility.rowHintKey(hasChildren: self.hasChildren, clickBehavior: self.context.clickBehavior)
    }

    private func expansionValue(isExpanded: Bool) -> Text {
        guard self.hasChildren else { return Text(verbatim: "") }
        return Text(
            LocalizedStringKey(TreeRowAccessibility.expansionValueKey(isExpanded: isExpanded)),
            bundle: .module
        )
    }
}

// MARK: - 行右键菜单 / Row menu

struct TreeRowMenu<ID: Hashable>: ViewModifier {
    let menu: ((Set<ID>) -> AnyView)?
    let targets: Set<ID>

    func body(content: Content) -> some View {
        if let menu = self.menu {
            content.contextMenu { TreeDeferredMenu(targets: self.targets, make: menu) }
        } else {
            content
        }
    }
}

struct TreeDeferredMenu<ID: Hashable>: View {
    let targets: Set<ID>
    let make: (Set<ID>) -> AnyView

    var body: some View {
        self.make(self.targets)
    }
}

// MARK: - 复选框 / Check box

struct TreeRowCheckBox: View {
    private let sources: [Binding<Bool>]
    private let label: AnyView
    private let hint: String?
    let metrics: TreeRowMetrics

    init(sources: [Binding<Bool>], label: AnyView = AnyView(EmptyView()), hint: String? = nil, metrics: TreeRowMetrics) {
        self.sources = sources
        self.label = label
        self.hint = hint
        self.metrics = metrics
    }

    var body: some View {
        Toggle(sources: self.sources, isOn: \.self) {
            self.label
        }
        .toggleStyle(CheckBoxToggleStyle())
        .labelsHidden()
        .accessibilityHint(Text(LocalizedStringKey(self.hint ?? ""), bundle: .module), isEnabled: self.hint != nil)
        .environment(
            \.checkBoxLayout,
            CheckBoxLayout(glyph: self.metrics.checkBoxGlyph, minHeight: self.metrics.rowHeight)
        )
    }
}

// MARK: - 搜索期间的父行复选框 / Parent check box under search

enum TreeCheckBindings {
    // 恰两路来源让系统派生 off / mixed / on。动作只挂一路（两路都挂则一次点击翻转两次），且挂在「全勾」那一路：
    // 系统把 mixed 点成 on 时，三种态下写入的新值都与它的现值相反，即使系统只写值有变化的来源也写得到它。
    static func scoped<ID: Hashable>(
        display leaves: [ID],
        scope retained: [ID],
        in checked: Binding<Set<ID>>,
        onWrite: @escaping () -> Void
    ) -> [Binding<Bool>] {
        [
            Binding(
                get: { TreeChecking.indicatorSources(ofLeaves: leaves, in: checked.wrappedValue)[0] },
                set: { _ in }
            ),
            Binding(
                get: { TreeChecking.indicatorSources(ofLeaves: leaves, in: checked.wrappedValue)[1] },
                set: { _ in
                    onWrite()
                    checked.wrappedValue = TreeChecking.toggling(scope: retained, in: checked.wrappedValue)
                }
            ),
        ]
    }
}

// MARK: - 展开控件 / Disclosure control

struct TreeDisclosureControl: View {
    let hasChildren: Bool
    let isExpanded: Bool
    let metrics: TreeRowMetrics
    private let toggle: () -> Void

    @Environment(\.coreMotionPresentation) private var motionPresentation

    init(hasChildren: Bool, isExpanded: Bool, metrics: TreeRowMetrics, toggle: @escaping () -> Void) {
        self.hasChildren = hasChildren
        self.isExpanded = isExpanded
        self.metrics = metrics
        self.toggle = toggle
    }

    var body: some View {
        let isExpanded = self.isExpanded
        if self.hasChildren {
            Button(action: self.toggle) {
                self.chevron
                    .rotationEffect(.degrees(self.chevronRotation(isExpanded: isExpanded)))
                    .animation(
                        CoreMotionToken.reveal.transformAnimation(for: self.motionPresentation),
                        value: isExpanded
                    )
                    .modifier(TreeDisclosureSlot(metrics: self.metrics))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                Text(LocalizedStringKey(TreeRowAccessibility.chevronLabelKey(isExpanded: isExpanded)), bundle: .module)
            )
        } else {
            self.chevron
                .hidden()
                .modifier(TreeDisclosureSlot(metrics: self.metrics))
        }
    }

    private var chevron: some View {
        Image(systemName: "chevron.forward")
            .font(.system(size: self.metrics.chevronSize))
            .foregroundStyle(.tint)
    }

    private func chevronRotation(isExpanded: Bool) -> Double {
        isExpanded ? 90 : 0
    }
}

struct TreeDisclosureSlot: ViewModifier {
    let metrics: TreeRowMetrics

    func body(content: Content) -> some View {
        content
            .frame(width: self.metrics.disclosureWidth, height: self.metrics.rowHeight)
            .contentShape(Rectangle())
    }
}

// MARK: - Preview

private struct TreePreviewNode: Identifiable {
    let id: String
    let name: String
    let children: [TreePreviewNode]?
}

private enum TreePreviewData {
    static let roots: [TreePreviewNode] = [
        TreePreviewNode(id: "design", name: "Design", children: [
            TreePreviewNode(id: "tokens", name: "Tokens", children: [
                TreePreviewNode(id: "color", name: "Color", children: nil),
                TreePreviewNode(id: "spacing", name: "Spacing", children: nil),
            ]),
            TreePreviewNode(id: "icons", name: "Icons", children: nil),
        ]),
        TreePreviewNode(id: "readme", name: "README.md", children: nil),
        TreePreviewNode(id: "tests", name: "Tests", children: [
            TreePreviewNode(id: "unit", name: "Unit", children: nil),
        ]),
    ]
}

private struct TreePreviewGallery: View {
    @State private var expanded: Set<String> = Tree.expandedIDs(
        TreePreviewData.roots, id: \.id, children: \.children, toDepth: 2
    )
    @State private var selection: Set<String> = ["icons"]
    @State private var checked: Set<String> = ["color"]

    var body: some View {
        VStack(alignment: .leading, spacing: CoreSpacing.lg) {
            VStack(alignment: .leading, spacing: CoreSpacing.xs) {
                Text(verbatim: "单选 / single")
                    .coreFont(.footnote)
                    .foregroundStyle(.secondary)
                Tree(
                    TreePreviewData.roots,
                    children: \.children,
                    expanded: self.$expanded,
                    selection: self.$selection
                ) { node in
                    Text(verbatim: node.name)
                }
            }
            VStack(alignment: .leading, spacing: CoreSpacing.xs) {
                Text(verbatim: "多选 + 三态复选框 / multiple + tri-state checkbox")
                    .coreFont(.footnote)
                    .foregroundStyle(.secondary)
                Tree(
                    TreePreviewData.roots,
                    children: \.children,
                    expanded: self.$expanded,
                    selection: self.$selection,
                    selectionMode: .multiple,
                    checked: self.$checked
                ) { node in
                    Text(verbatim: node.name)
                }
            }
            VStack(alignment: .leading, spacing: CoreSpacing.xs) {
                Text(verbatim: "导航器 / navigator + .controlSize(.small)")
                    .coreFont(.footnote)
                    .foregroundStyle(.secondary)
                Tree(
                    TreePreviewData.roots,
                    children: \.children,
                    expanded: self.$expanded,
                    selection: self.$selection
                ) { node in
                    Label(node.name, systemImage: node.children == nil ? "doc" : "folder")
                }
                .treeStyle(.navigator)
                .controlSize(.small)
            }
        }
        .padding()
        .background(Color.surfaceCanvas)
    }
}

#Preview("Tree — Light") {
    TreePreviewGallery()
        .preferredColorScheme(.light)
}

#Preview("Tree — Dark") {
    TreePreviewGallery()
        .preferredColorScheme(.dark)
}
