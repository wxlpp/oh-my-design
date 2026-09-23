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
/// 也是 `rowContextMenu(_:)` 的右键区。
///
/// ⚠️ **不是原生外观**：本组件走递归 `DisclosureGroup(isExpanded:)`，从系统拿到的是
/// 展开态接口与嵌套能力；chevron、缩进、行选中底色与无障碍播报全部自绘。
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
    ///   - onActivate: `Enter` 激活焦点行时的回调；与选中**分开**。传 `nil` 时 `Enter` 交回系统。
    ///   - content: 由元素生成行内容，常为 `Text` 或 `Label`。
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
    @FocusState private var isFocused: Bool
    @Environment(\.coreMotionPresentation) private var motionPresentation
    @Environment(\.controlSize) private var controlSize

    public var body: some View {
        let rows = self.visibleRows
        let metrics = TreeRowMetrics.resolve(self.controlSize)
        return VStack(alignment: .leading, spacing: metrics.rowSpacing) {
            TreeBranch(data: self.data, level: 1, context: self.context(rows: rows, metrics: metrics))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(TreeNestedStyle())
        .focusable()
        .focused(self.$isFocused)
        .onKeyPress(phases: .down) { press in self.handle(press, rows: rows) }
        .onChange(of: rows) { oldRows, newRows in
            self.commit(TreeInteractionReducer.rowsChanged(state: self.interactionState, from: oldRows, to: newRows))
        }
        .onChange(of: self.isFocused) { _, focused in self.focusChanged(focused, rows: rows) }
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

    private var interactionState: TreeInteractionState<ID> {
        TreeInteractionState(
            focus: self.focus,
            lastInteraction: self.lastInteraction,
            selection: self.selection,
            expanded: self.expanded
        )
    }

    private func commit(_ next: TreeInteractionState<ID>, expansionMotion: MotionPresentation? = nil) {
        if next.focus != self.focus { self.focus = next.focus }
        if next.lastInteraction != self.lastInteraction { self.lastInteraction = next.lastInteraction }
        if next.selection != self.selection { self.selection = next.selection }
        if next.expanded != self.expanded {
            withAnimation(expansionMotion.flatMap(CoreMotionToken.treeExpansion(for:))) {
                self.expanded = next.expanded
            }
        }
    }

    private func handle(_ press: KeyPress, rows: [TreeRow<ID>]) -> KeyPress.Result {
        let outcome = TreeInteractionReducer.key(
            TreeKeyboard.key(for: press.key),
            modifiers: press.modifiers,
            state: self.interactionState,
            rows: rows,
            mode: self.selectionMode,
            activation: self.onActivate == nil ? .disabled : .enabled,
            motion: self.motionPresentation,
            treeIDs: { self.treeIDs },
            ancestors: self.ancestors(of:)
        )
        self.commit(outcome.state, expansionMotion: outcome.expansionMotion)
        if let activated = outcome.activated { self.onActivate?(activated) }
        return outcome.result
    }

    private func focusChanged(_ focused: Bool, rows: [TreeRow<ID>]) {
        let source: TreeInteraction = self.pointerClaimsFocus ? .pointer : .keyboard
        self.pointerClaimsFocus = false
        guard focused else { return }
        self.commit(TreeInteractionReducer.focusEntered(
            via: source, state: self.interactionState, rows: rows, ancestors: self.ancestors(of:)
        ))
    }

    private func select(_ id: ID, rows: [TreeRow<ID>]) {
        if !self.isFocused {
            self.pointerClaimsFocus = true
            self.isFocused = true
        }
        self.commit(TreeInteractionReducer.pointerSelect(
            id,
            state: self.interactionState,
            rowIDs: Set(rows.map(\.id)),
            mode: self.selectionMode,
            treeIDs: { self.treeIDs }
        ))
    }

    private func setExpansion(_ id: ID, to target: TreeExpansionTarget) {
        let outcome = TreeInteractionReducer.pointerExpansion(
            id, to: target, state: self.interactionState, motion: self.motionPresentation
        )
        self.commit(outcome.state, expansionMotion: outcome.expansionMotion)
    }

    // MARK: - 派生 / Derived

    private var visibleRows: [TreeRow<ID>] {
        TreeFlatten.rows(self.data, id: self.id, children: self.children, expanded: self.expanded)
    }

    private var treeIDs: Set<ID> {
        TreeFlatten.allIDs(self.data, id: self.id, children: self.children)
    }

    private func ancestors(of hidden: ID) -> [ID] {
        TreeFlatten.ancestorIDs(of: hidden, in: self.data, id: self.id, children: self.children)
    }

    private func context(rows: [TreeRow<ID>], metrics: TreeRowMetrics) -> TreeContext<Data, ID, RowContent> {
        TreeContext(
            id: self.id,
            children: self.children,
            expanded: self.expanded,
            selection: self.selection,
            checked: self.checked,
            focus: self.focus,
            metrics: metrics,
            showsFocusIndicator: TreeFocusing.showsRing(
                containerFocused: self.isFocused, lastInteraction: self.lastInteraction
            ),
            select: { id in self.select(id, rows: rows) },
            setExpansion: { id, target in self.setExpansion(id, to: target) },
            notePointerCheck: { self.commit(TreeInteractionReducer.pointerCheck(state: self.interactionState)) },
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
}

// MARK: - 递归上下文 / Recursion context

struct TreeContext<Data: RandomAccessCollection, ID: Hashable, RowContent: View> {
    let id: KeyPath<Data.Element, ID>
    let children: KeyPath<Data.Element, Data?>
    let expanded: Set<ID>
    let selection: Set<ID>
    let checked: Binding<Set<ID>>?
    let focus: ID?
    let metrics: TreeRowMetrics
    let showsFocusIndicator: Bool
    let select: (ID) -> Void
    let setExpansion: (ID, TreeExpansionTarget) -> Void
    let notePointerCheck: () -> Void
    let rowMenu: ((Set<ID>) -> AnyView)?
    let selectedVisible: Set<ID>
    let content: (Data.Element) -> RowContent

    func expansion(of elementID: ID) -> Binding<Bool> {
        Binding(
            get: { self.expanded.contains(elementID) },
            set: { newValue in self.setExpansion(elementID, newValue ? .expanded : .collapsed) }
        )
    }

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

// MARK: - 递归分支 / Recursive branch

struct TreeBranch<Data: RandomAccessCollection, ID: Hashable, RowContent: View>: View {
    let data: Data
    let level: Int
    let context: TreeContext<Data, ID, RowContent>

    var body: some View {
        ForEach(self.data, id: self.context.id) { element in
            if let kids = element[keyPath: self.context.children], !kids.isEmpty {
                DisclosureGroup(isExpanded: self.context.expansion(of: element[keyPath: self.context.id])) {
                    TreeBranch(data: kids, level: self.level + 1, context: self.context)
                        .modifier(TreeNestedStyle())
                } label: {
                    TreeRowHost(element: element, level: self.level, hasChildren: true, context: self.context)
                }
            } else {
                TreeRowHost(element: element, level: self.level, hasChildren: false, context: self.context)
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

// MARK: - 逐层重施样式 / Per-level restyling

struct TreeNestedStyle: ViewModifier {
    func body(content: Content) -> some View {
        content.disclosureGroupStyle(TreeDisclosureGroupStyle())
    }
}

// MARK: - TreeDisclosureGroupStyle

struct TreeDisclosureGroupStyle: DisclosureGroupStyle {
    @Environment(\.controlSize) private var controlSize

    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: TreeRowMetrics.resolve(self.controlSize).rowSpacing) {
            configuration.label
            if configuration.isExpanded {
                configuration.content
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
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
            label: self.context.content(self.element),
            disclosure: TreeDisclosureControl(
                hasChildren: self.hasChildren, isExpanded: isExpanded, metrics: self.context.metrics
            ) {
                self.context.setExpansion(elementID, isExpanded ? .collapsed : .expanded)
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
            .onTapGesture { self.context.select(elementID) }
            .accessibilityValue(self.expansionValue(isExpanded: isExpanded))
            .accessibilityAddTraits(TreeRowAccessibility.traits(isSelected: isSelected))
    }

    @ViewBuilder
    private func row(_ configuration: TreeRowConfiguration<RowContent>) -> some View {
        switch self.style.appearance {
        case .automatic:
            AutomaticTreeRow(configuration: configuration)
                .onAppear { self.isHovered = false }
        case .navigator:
            NavigatorTreeRow(configuration: configuration)
                .contentShape(Rectangle())
                .onHover { hovering in self.isHovered = hovering }
        }
    }

    private func checkBox(_ checked: Binding<Set<ID>>) -> TreeRowCheckBox {
        let leaves = TreeFlatten.descendantLeafIDs(
            of: self.element, id: self.context.id, children: self.context.children
        )
        return TreeRowCheckBox(
            sources: leaves.map { self.context.checkState(of: $0, in: checked) },
            metrics: self.context.metrics
        )
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
    let metrics: TreeRowMetrics

    init(sources: [Binding<Bool>], metrics: TreeRowMetrics) {
        self.sources = sources
        self.metrics = metrics
    }

    var body: some View {
        Toggle(sources: self.sources, isOn: \.self) {
            EmptyView()
        }
        .toggleStyle(CheckBoxToggleStyle())
        .labelsHidden()
        .environment(
            \.checkBoxLayout,
            CheckBoxLayout(glyph: self.metrics.checkBoxGlyph, minHeight: self.metrics.rowHeight)
        )
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
