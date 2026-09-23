import SwiftUI
import Testing
@testable import OhMyDesign

// MARK: - Legacy422 拷贝 / Legacy copies (138253d)

nonisolated enum Legacy422TreeFlatten {
    static func rows<Data: RandomAccessCollection, ID: Hashable>(
        _ data: Data,
        id: KeyPath<Data.Element, ID>,
        children: KeyPath<Data.Element, Data?>,
        expanded: Set<ID>
    ) -> [TreeRow<ID>] {
        var out: [TreeRow<ID>] = []
        func walk(_ nodes: Data, level: Int, parent: ID?) {
            for node in nodes {
                let nodeID = node[keyPath: id]
                let kids = node[keyPath: children]
                let branching = !(kids?.isEmpty ?? true)
                out.append(TreeRow(id: nodeID, level: level, parent: parent, hasChildren: branching))
                if branching, expanded.contains(nodeID), let kids {
                    walk(kids, level: level + 1, parent: nodeID)
                }
            }
        }
        walk(data, level: 1, parent: nil)
        return out
    }

}

struct Legacy422TreeContext<Data: RandomAccessCollection, ID: Hashable, RowContent: View> {
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


struct Legacy422TreeBranch<Data: RandomAccessCollection, ID: Hashable, RowContent: View>: View {
    let data: Data
    let level: Int
    let context: Legacy422TreeContext<Data, ID, RowContent>

    var body: some View {
        ForEach(self.data, id: self.context.id) { element in
            if let kids = element[keyPath: self.context.children], !kids.isEmpty {
                DisclosureGroup(isExpanded: self.context.expansion(of: element[keyPath: self.context.id])) {
                    Legacy422TreeBranch(data: kids, level: self.level + 1, context: self.context)
                        .modifier(Legacy422TreeNestedStyle())
                } label: {
                    Legacy422TreeRowHost(element: element, level: self.level, hasChildren: true, context: self.context)
                }
            } else {
                Legacy422TreeRowHost(element: element, level: self.level, hasChildren: false, context: self.context)
            }
        }
    }
}


struct Legacy422TreeNestedStyle: ViewModifier {
    func body(content: Content) -> some View {
        content.disclosureGroupStyle(Legacy422TreeDisclosureGroupStyle())
    }
}


struct Legacy422TreeDisclosureGroupStyle: DisclosureGroupStyle {
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


struct Legacy422TreeRowHost<Data: RandomAccessCollection, ID: Hashable, RowContent: View>: View {
    let element: Data.Element
    let level: Int
    let hasChildren: Bool
    let context: Legacy422TreeContext<Data, ID, RowContent>

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

// MARK: - 迁移闸门 / Migration gate

nonisolated struct Legacy422Cell: CustomTestStringConvertible, Sendable {
    let expandedToLevel3: Bool
    let selectsLevel3Row: Bool
    let mixedParent: Bool
    let showsFocusIndicator: Bool
    let navigator: Bool
    let dark: Bool
    let rightToLeft: Bool

    static let all: [Legacy422Cell] = (0..<128).map { bits in
        Legacy422Cell(
            expandedToLevel3: bits & 1 != 0,
            selectsLevel3Row: bits & 2 != 0,
            mixedParent: bits & 4 != 0,
            showsFocusIndicator: bits & 8 != 0,
            navigator: bits & 16 != 0,
            dark: bits & 32 != 0,
            rightToLeft: bits & 64 != 0
        )
    }

    var expanded: Set<String> { self.expandedToLevel3 ? ["a", "a1", "c"] : [] }
    var selection: Set<String> { self.selectsLevel3Row ? ["a1x"] : [] }
    var checked: Set<String>? { self.mixedParent ? ["a1x"] : nil }
    var focus: String { self.expandedToLevel3 ? "a1" : "c" }

    var testDescription: String {
        [
            self.expandedToLevel3 ? "展开到第 3 层" : "全折叠",
            self.selectsLevel3Row ? "选中 a1x" : "无选中",
            self.mixedParent ? "父行 mixed" : "无复选框",
            self.showsFocusIndicator ? "焦点指示" : "无焦点指示",
            self.navigator ? ".navigator" : ".automatic",
            self.dark ? "dark" : "light",
            self.rightToLeft ? "RTL" : "LTR",
        ].joined(separator: " / ")
    }
}

@Suite("Legacy422 迁移闸门：展平 + LazyVStack 与递归 DisclosureGroup 逐像素一致（一次性，PR 最后一个 commit 删除）")
@MainActor
struct Legacy422ParityTests {
    private static let noiseTolerance = 2
    private static let metrics = TreeRowMetrics.resolve(.regular)

    private static func legacy(_ cell: Legacy422Cell) -> some View {
        let context = Legacy422TreeContext<[TreeJudgeNode], String, Text>(
            id: \.id,
            children: \.children,
            expanded: cell.expanded,
            selection: cell.selection,
            checked: cell.checked.map { Binding.constant($0) },
            focus: cell.focus,
            metrics: Self.metrics,
            showsFocusIndicator: cell.showsFocusIndicator,
            select: { _ in },
            setExpansion: { _, _ in },
            notePointerCheck: {},
            rowMenu: nil,
            selectedVisible: [],
            content: { Text(verbatim: $0.id) }
        )
        return VStack(alignment: .leading, spacing: Self.metrics.rowSpacing) {
            Legacy422TreeBranch(data: TreeJudgeFixture.roots, level: 1, context: context)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(Legacy422TreeNestedStyle())
    }

    private static func flattened(_ cell: Legacy422Cell) -> some View {
        let context = TreeContext<[TreeJudgeNode], String, Text>(
            id: \.id,
            children: \.children,
            expanded: cell.expanded,
            selection: cell.selection,
            checked: cell.checked.map { Binding.constant($0) },
            focus: cell.focus,
            metrics: Self.metrics,
            showsFocusIndicator: cell.showsFocusIndicator,
            select: { _ in },
            setExpansion: { _, _ in },
            notePointerCheck: {},
            rowMenu: nil,
            selectedVisible: [],
            content: { Text(verbatim: $0.id) }
        )
        let items = TreeFlatten.items(
            TreeJudgeFixture.roots, id: \.id, children: \.children, expanded: cell.expanded
        )
        return TreeRowStack(items: items, context: context)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private static func publicTree(_ cell: Legacy422Cell) -> some View {
        Tree(
            TreeJudgeFixture.roots,
            children: \.children,
            expanded: .constant(cell.expanded),
            selection: .constant(cell.selection),
            selectionMode: .multiple,
            checked: cell.checked.map { Binding.constant($0) }
        ) { node in
            Text(verbatim: node.id)
        }
    }

    private static func render(_ view: some View, _ cell: Legacy422Cell) -> TreePixels {
        TreePixels.render(
            view
                .treeStyle(cell.navigator ? .navigator : .automatic)
                .environment(\.layoutDirection, cell.rightToLeft ? .rightToLeft : .leftToRight),
            scheme: cell.dark ? .dark : .light
        )
    }

    private static func expectParity(
        _ lhs: TreePixels, _ rhs: TreePixels, _ label: String, sourceLocation: SourceLocation = #_sourceLocation
    ) {
        #expect(lhs.bytes != nil && rhs.bytes != nil, "\(label)：没渲染出来", sourceLocation: sourceLocation)
        #expect(
            lhs.width == rhs.width && lhs.height == rhs.height,
            "\(label)：尺寸不同（\(lhs.width)x\(lhs.height) vs \(rhs.width)x\(rhs.height)）",
            sourceLocation: sourceLocation
        )
        let metrics = bitmapDifferenceMetrics(lhs.bytes, rhs.bytes)
        let delta = metrics?.maxChannelDelta ?? Int.max
        print("Legacy422 \(label) size=\(lhs.width)x\(lhs.height) maxDelta=\(delta) differing=\(metrics?.differingCount ?? -1)")
        #expect(
            delta <= Self.noiseTolerance,
            "\(label)：逐通道最大偏差 \(delta) > \(Self.noiseTolerance)（差异字节 \(metrics?.differingCount ?? -1)）",
            sourceLocation: sourceLocation
        )
    }

    @Test("矩阵共 128 格")
    func matrixCardinality() {
        #expect(Legacy422Cell.all.count == 128)
        #expect(Set(Legacy422Cell.all.map(\.testDescription)).count == 128)
    }

    @Test("展平行栈与递归 DisclosureGroup 画得一样", arguments: Legacy422Cell.all)
    func flattenedMatchesRecursive(cell: Legacy422Cell) {
        Self.expectParity(Self.render(Self.legacy(cell), cell), Self.render(Self.flattened(cell), cell), "展平 vs 递归")
    }

    @Test("公开 Tree（不画焦点指示的格）与递归 DisclosureGroup 画得一样", arguments: Legacy422Cell.all.filter { !$0.showsFocusIndicator })
    func publicTreeMatchesRecursive(cell: Legacy422Cell) {
        Self.expectParity(Self.render(Self.legacy(cell), cell), Self.render(Self.publicTree(cell), cell), "公开 Tree vs 递归")
    }

    @Test("rows 与旧的直接遍历逐项相等（全部 2^3 种父节点展开组合）")
    func rowsMatchTheLegacyWalk() {
        let parents = Array(TreeJudgeFixture.parentIDs).sorted()
        for mask in 0..<(1 << parents.count) {
            let expanded = Set(parents.enumerated().filter { mask & (1 << $0.offset) != 0 }.map(\.element))
            let legacy = Legacy422TreeFlatten.rows(
                TreeJudgeFixture.roots, id: \TreeJudgeNode.id, children: \TreeJudgeNode.children, expanded: expanded
            )
            #expect(TreeJudgeFixture.rows(expanded: expanded) == legacy, "expanded = \(expanded.sorted())")
        }
    }
}
