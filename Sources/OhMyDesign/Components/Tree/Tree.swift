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
    ///   - onActivate: `Enter` 或双击激活某行时的回调；与选中**分开**。
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
    @FocusState private var isFocused: Bool
    @Environment(\.coreMotionPresentation) private var motionPresentation

    public var body: some View {
        let rows = self.visibleRows
        return VStack(alignment: .leading, spacing: CoreSpacing.xxs) {
            TreeBranch(data: self.data, level: 1, context: self.context(rows: rows))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(TreeNestedStyle())
        .focusable()
        .focused(self.$isFocused)
        .onKeyPress(phases: .down) { press in self.handle(press, rows: rows) }
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

    // MARK: - 键盘 / Keyboard

    private func handle(_ press: KeyPress, rows: [TreeRow<ID>]) -> KeyPress.Result {
        guard let focused = self.focus ?? TreeFocusing.initialFocus(rows: rows, selection: self.selection)
        else { return .ignored }
        if self.focus != focused { self.focus = focused }
        let action = TreeKeyboard.action(
            for: TreeKeyboard.key(for: press.key),
            modifiers: press.modifiers,
            rows: rows,
            focus: focused,
            expanded: self.expanded,
            mode: self.selectionMode
        )
        return self.apply(action, rows: rows)
    }

    private func apply(_ action: TreeKeyAction<ID>, rows: [TreeRow<ID>]) -> KeyPress.Result {
        switch action {
        case .unhandled:
            return .ignored
        case .doNothing:
            return .handled
        case .moveFocus(let id):
            self.focus = id
        case .moveFocusAndToggleSelection(let id):
            self.focus = id
            self.toggleSelection(id, rows: rows)
        case .expand(let id):
            self.setExpansion(id, isExpanded: true)
        case .collapse(let id):
            self.setExpansion(id, isExpanded: false)
        case .toggleSelection(let id):
            self.toggleSelection(id, rows: rows)
        case .activate(let id):
            self.onActivate?(id)
        case .selectAllVisible:
            self.selection = TreeSelection.selectingAll(in: self.selection, rowIDs: rows.map(\.id))
        }
        return .handled
    }

    private func toggleSelection(_ id: ID, rows: [TreeRow<ID>]) {
        self.selection = TreeSelection.toggled(
            id, in: self.selection, rowIDs: Set(rows.map(\.id)), mode: self.selectionMode
        )
    }

    private func setExpansion(_ id: ID, isExpanded: Bool) {
        var state = TreeExpansionState(persisted: self.expanded)
        if isExpanded { state.expand(id) } else { state.collapse(id) }
        withAnimation(CoreMotionToken.reveal.animation(for: self.motionPresentation)) {
            self.expanded = state.persisted
        }
    }

    // MARK: - 派生 / Derived

    private var visibleRows: [TreeRow<ID>] {
        TreeFlatten.rows(self.data, id: self.id, children: self.children, expanded: self.expanded)
    }

    private func context(rows: [TreeRow<ID>]) -> TreeContext<Data, ID, RowContent> {
        TreeContext(
            id: self.id,
            children: self.children,
            expanded: self.$expanded,
            selection: self.$selection,
            checked: self.checked,
            selectionMode: self.selectionMode,
            rowIDs: Set(rows.map(\.id)),
            focus: self.$focus,
            claimKeyboardFocus: { self.isFocused = true },
            onActivate: self.onActivate,
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

// MARK: - 递归上下文 / Recursion context

struct TreeContext<Data: RandomAccessCollection, ID: Hashable, RowContent: View> {
    let id: KeyPath<Data.Element, ID>
    let children: KeyPath<Data.Element, Data?>
    let expanded: Binding<Set<ID>>
    let selection: Binding<Set<ID>>
    let checked: Binding<Set<ID>>?
    let selectionMode: TreeSelectionMode
    let rowIDs: Set<ID>
    let focus: Binding<ID?>
    let claimKeyboardFocus: () -> Void
    let onActivate: ((ID) -> Void)?
    let content: (Data.Element) -> RowContent

    func expansion(of elementID: ID) -> Binding<Bool> {
        Binding(
            get: { self.expanded.wrappedValue.contains(elementID) },
            set: { newValue in
                var state = TreeExpansionState(persisted: self.expanded.wrappedValue)
                if newValue { state.expand(elementID) } else { state.collapse(elementID) }
                self.expanded.wrappedValue = state.persisted
            }
        )
    }

    func checkState(of leafID: ID, in checked: Binding<Set<ID>>) -> Binding<Bool> {
        Binding(
            get: { checked.wrappedValue.contains(leafID) },
            set: { newValue in
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
                    TreeRowView(element: element, level: self.level, hasChildren: true, context: self.context)
                }
            } else {
                TreeRowView(element: element, level: self.level, hasChildren: false, context: self.context)
            }
        }
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
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: CoreSpacing.xxs) {
            configuration.label
            if configuration.isExpanded {
                configuration.content
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

// MARK: - 行 / Row

struct TreeRowView<Data: RandomAccessCollection, ID: Hashable, RowContent: View>: View {
    let element: Data.Element
    let level: Int
    let hasChildren: Bool
    let context: TreeContext<Data, ID, RowContent>

    @Environment(\.coreAccent) private var resolvedAccent

    var body: some View {
        let elementID = self.element[keyPath: self.context.id]
        let isExpanded = self.context.expanded.wrappedValue.contains(elementID)
        let isSelected = self.context.selection.wrappedValue.contains(elementID)
        let isFocused = self.context.focus.wrappedValue == elementID
        return HStack(spacing: CoreSpacing.xs) {
            TreeDisclosureControl(hasChildren: self.hasChildren, isExpanded: isExpanded) {
                self.context.expansion(of: elementID).wrappedValue.toggle()
            }
            if let checked = self.context.checked {
                self.checkBox(checked)
            }
            self.context.content(self.element)
        }
        .padding(.horizontal, CoreSpacing.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: CoreControlMetrics.height(for: .regular))
        .background(
            CoreShape.rounded(CoreRadius.small)
                .fill(isSelected ? Color.accentSubtleBackground(from: self.resolvedAccent) : Color.clear)
        )
        .contentShape(Rectangle())
        .padding(.leading, CGFloat(self.level - 1) * CoreSpacing.md)
        .onTapGesture { self.select(elementID) }
        .focusRing(visible: isFocused, cornerRadius: CoreRadius.small)
        .accessibilityValue(self.expansionValue(isExpanded: isExpanded))
        .accessibilityAddTraits(TreeRowAccessibility.traits(isSelected: isSelected))
    }

    @ViewBuilder
    private func checkBox(_ checked: Binding<Set<ID>>) -> some View {
        let leaves = TreeFlatten.descendantLeafIDs(
            of: self.element, id: self.context.id, children: self.context.children
        )
        Toggle(
            sources: leaves.map { self.context.checkState(of: $0, in: checked) },
            isOn: \.self
        ) {
            EmptyView()
        }
        .toggleStyle(CheckBoxToggleStyle())
        .labelsHidden()
    }

    private func expansionValue(isExpanded: Bool) -> Text {
        guard self.hasChildren else { return Text(verbatim: "") }
        return Text(
            LocalizedStringKey(TreeRowAccessibility.expansionValueKey(isExpanded: isExpanded)),
            bundle: .module
        )
    }

    private func select(_ elementID: ID) {
        self.context.claimKeyboardFocus()
        self.context.focus.wrappedValue = elementID
        self.context.selection.wrappedValue = TreeSelection.toggled(
            elementID,
            in: self.context.selection.wrappedValue,
            rowIDs: self.context.rowIDs,
            mode: self.context.selectionMode
        )
    }
}

// MARK: - 展开控件 / Disclosure control

struct TreeDisclosureControl: View {
    let hasChildren: Bool
    let isExpanded: Bool
    let toggle: () -> Void

    @Environment(\.coreMotionPresentation) private var motionPresentation
    @Environment(\.layoutDirection) private var layoutDirection

    var body: some View {
        let isExpanded = self.isExpanded
        if self.hasChildren {
            Button(action: self.toggle) {
                Self.chevron
                    .rotationEffect(.degrees(self.chevronRotation(isExpanded: isExpanded)))
                    .animation(
                        CoreMotionToken.reveal.transformAnimation(for: self.motionPresentation),
                        value: isExpanded
                    )
                    .modifier(TreeDisclosureSlot())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                Text(LocalizedStringKey(TreeRowAccessibility.chevronLabelKey(isExpanded: isExpanded)), bundle: .module)
            )
        } else {
            Self.chevron
                .hidden()
                .modifier(TreeDisclosureSlot())
        }
    }

    private static var chevron: some View {
        Image(systemName: "chevron.forward")
            .font(.system(size: CoreControlMetrics.iconSize(for: .small)))
            .foregroundStyle(.tint)
    }

    private func chevronRotation(isExpanded: Bool) -> Double {
        guard isExpanded else { return 0 }
        return self.layoutDirection == .rightToLeft ? -90 : 90
    }
}

struct TreeDisclosureSlot: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(
                width: CoreControlMetrics.iconSize(for: .regular) + CoreSpacing.sm,
                height: CoreControlMetrics.height(for: .regular)
            )
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
    @State private var expanded: Set<String> = Tree<[TreePreviewNode], String, Text>.expandedIDs(
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
