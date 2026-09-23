import SwiftUI

// MARK: - TreeSelectionMode

/// `Tree` 的行选择模式。
///
/// 行选中是**导航语义**（当前高亮哪一行），与复选框的**数据语义**（勾了哪些）是两套独立状态，
/// 互不写入。`Shift+↑ / ↓` 与 `Ctrl / Cmd + A` 只在 `.multiple` 下生效。
public nonisolated enum TreeSelectionMode: Hashable, Sendable, CaseIterable {
    /// 单选：选中一个未选行时，替换已选集合里属于本树的全部 ID（含被折叠而不可见的）。
    /// 不属于本树数据的 ID 原样保留；再选同一行取消（允许空选）。
    case single
    /// 多选：逐行切换选中态。
    case multiple
}

// MARK: - TreeRow

nonisolated struct TreeRow<ID: Hashable>: Identifiable, Equatable {
    let id: ID
    let level: Int
    let parent: ID?
    let hasChildren: Bool
}

// MARK: - 渲染项 / Render item

nonisolated struct TreeRenderItem<Element, ID: Hashable>: Identifiable {
    let row: TreeRow<ID>
    let element: Element

    var id: ID { self.row.id }
}

// MARK: - 行度量 / Row metrics

nonisolated struct TreeRowMetrics: Equatable {
    let rowHeight: CGFloat
    let disclosureWidth: CGFloat
    let indentation: CGFloat
    let chevronSize: CGFloat
    let rowSpacing: CGFloat
    let checkBoxGlyph: CGFloat

    #if os(macOS)
    static let platformFloor: CGFloat = 0
    #else
    static let platformFloor: CGFloat = CoreControlMetrics.height(for: .regular)
    #endif

    static func resolve(_ size: ControlSize, platformFloor: CGFloat = Self.platformFloor) -> TreeRowMetrics {
        let isDense = size < .regular
        // 密集档不能套控件高度 token（small = 32 不是 22），regular 起也不能套图标 + padding（regular = 40，破 44）。
        let visualHeight = isDense
            ? CoreControlMetrics.iconSize(for: size) + 2 * CoreControlMetrics.verticalPadding(for: size)
            : CoreControlMetrics.height(for: size)
        let disclosureWidth = CoreControlMetrics.iconSize(for: size) + CoreSpacing.sm
        return TreeRowMetrics(
            rowHeight: max(visualHeight, platformFloor),
            disclosureWidth: disclosureWidth,
            indentation: disclosureWidth / 2,
            chevronSize: CoreControlMetrics.compactIconSize(for: size),
            rowSpacing: isDense ? CoreSpacing.none : CoreSpacing.xxs,
            checkBoxGlyph: CoreControlMetrics.iconSize(for: size)
        )
    }
}

// MARK: - 展平 / Flattening

nonisolated enum TreeFlatten {
    static func hasChildren<Data: RandomAccessCollection>(
        _ element: Data.Element,
        children: KeyPath<Data.Element, Data?>
    ) -> Bool {
        guard let kids = element[keyPath: children] else { return false }
        return !kids.isEmpty
    }

    static func items<Data: RandomAccessCollection, ID: Hashable>(
        _ data: Data,
        id: KeyPath<Data.Element, ID>,
        children: KeyPath<Data.Element, Data?>,
        expanded: Set<ID>
    ) -> [TreeRenderItem<Data.Element, ID>] {
        var out: [TreeRenderItem<Data.Element, ID>] = []
        func walk(_ nodes: Data, level: Int, parent: ID?) {
            for node in nodes {
                let nodeID = node[keyPath: id]
                let kids = node[keyPath: children]
                let branching = !(kids?.isEmpty ?? true)
                out.append(TreeRenderItem(
                    row: TreeRow(id: nodeID, level: level, parent: parent, hasChildren: branching),
                    element: node
                ))
                if branching, expanded.contains(nodeID), let kids {
                    walk(kids, level: level + 1, parent: nodeID)
                }
            }
        }
        walk(data, level: 1, parent: nil)
        return out
    }

    static func rows<Data: RandomAccessCollection, ID: Hashable>(
        _ data: Data,
        id: KeyPath<Data.Element, ID>,
        children: KeyPath<Data.Element, Data?>,
        expanded: Set<ID>
    ) -> [TreeRow<ID>] {
        Self.items(data, id: id, children: children, expanded: expanded).map(\.row)
    }

    static func expandedIDs<Data: RandomAccessCollection, ID: Hashable>(
        _ data: Data,
        id: KeyPath<Data.Element, ID>,
        children: KeyPath<Data.Element, Data?>,
        toDepth depth: Int
    ) -> Set<ID> {
        var out: Set<ID> = []
        func walk(_ nodes: Data, level: Int) {
            guard level < depth else { return }
            for node in nodes {
                guard let kids = node[keyPath: children], !kids.isEmpty else { continue }
                out.insert(node[keyPath: id])
                walk(kids, level: level + 1)
            }
        }
        walk(data, level: 1)
        return out
    }

    static func descendantLeafIDs<Data: RandomAccessCollection, ID: Hashable>(
        of element: Data.Element,
        id: KeyPath<Data.Element, ID>,
        children: KeyPath<Data.Element, Data?>
    ) -> [ID] {
        var out: [ID] = []
        func walk(_ nodes: Data) {
            for node in nodes {
                if let kids = node[keyPath: children], !kids.isEmpty {
                    walk(kids)
                } else {
                    out.append(node[keyPath: id])
                }
            }
        }
        if let kids = element[keyPath: children], !kids.isEmpty {
            walk(kids)
        } else {
            out.append(element[keyPath: id])
        }
        return out
    }

    static func allIDs<Data: RandomAccessCollection, ID: Hashable>(
        _ data: Data,
        id: KeyPath<Data.Element, ID>,
        children: KeyPath<Data.Element, Data?>
    ) -> Set<ID> {
        var out: Set<ID> = []
        func walk(_ nodes: Data) {
            for node in nodes {
                out.insert(node[keyPath: id])
                if let kids = node[keyPath: children] { walk(kids) }
            }
        }
        walk(data)
        return out
    }

    static func ancestorIDs<Data: RandomAccessCollection, ID: Hashable>(
        of target: ID,
        in data: Data,
        id: KeyPath<Data.Element, ID>,
        children: KeyPath<Data.Element, Data?>
    ) -> [ID] {
        var out: [ID] = []
        func walk(_ nodes: Data, chain: [ID]) -> Bool {
            for node in nodes {
                let nodeID = node[keyPath: id]
                if nodeID == target {
                    out = chain
                    return true
                }
                if let kids = node[keyPath: children], !kids.isEmpty, walk(kids, chain: [nodeID] + chain) {
                    return true
                }
            }
            return false
        }
        _ = walk(data, chain: [])
        return out
    }
}

// MARK: - 展开态 / Expansion state

nonisolated struct TreeExpansionState<ID: Hashable>: Equatable {
    nonisolated struct Overlay: Equatable {
        var expanded: Set<ID> = []
        var collapsed: Set<ID> = []
    }

    var persisted: Set<ID>
    var overlay: Overlay?

    init(persisted: Set<ID>, overlay: Overlay? = nil) {
        self.persisted = persisted
        self.overlay = overlay
    }

    var effective: Set<ID> {
        guard let overlay = self.overlay else { return self.persisted }
        return self.persisted.union(overlay.expanded).subtracting(overlay.collapsed)
    }

    mutating func expand(_ id: ID) {
        if self.overlay == nil {
            self.persisted.insert(id)
        } else {
            self.overlay?.collapsed.remove(id)
            self.overlay?.expanded.insert(id)
        }
    }

    mutating func collapse(_ id: ID) {
        if self.overlay == nil {
            self.persisted.remove(id)
        } else {
            self.overlay?.expanded.remove(id)
            self.overlay?.collapsed.insert(id)
        }
    }

    mutating func beginTransientSession() {
        self.overlay = Overlay()
    }

    mutating func endTransientSession() {
        self.overlay = nil
    }
}

// MARK: - 勾选级联 / Check cascade

nonisolated enum TreeChecking {
    static func applying<ID: Hashable>(
        _ isChecked: Bool,
        toLeaves leaves: [ID],
        in checked: Set<ID>
    ) -> Set<ID> {
        isChecked ? checked.union(leaves) : checked.subtracting(leaves)
    }
}

// MARK: - 行选中归约 / Row-selection reducer

nonisolated enum TreeSelection {
    static func toggled<ID: Hashable>(
        _ id: ID,
        in selection: Set<ID>,
        rowIDs: Set<ID>,
        treeIDs: @autoclosure () -> Set<ID>,
        mode: TreeSelectionMode
    ) -> Set<ID> {
        guard rowIDs.contains(id) else { return selection }
        switch mode {
        case .multiple:
            return selection.symmetricDifference([id])
        case .single:
            let outside = selection.subtracting(treeIDs())
            return selection.contains(id) ? outside : outside.union([id])
        }
    }

    static func selectingAll<ID: Hashable>(
        in selection: Set<ID>,
        rowIDs: [ID]
    ) -> Set<ID> {
        selection.union(rowIDs)
    }
}

// MARK: - 焦点归约 / Focus reduction

nonisolated enum TreeInteraction: Hashable, Sendable {
    case pointer
    case keyboard
}

nonisolated enum TreeFocusing {
    static func initialFocus<ID: Hashable>(
        rows: [TreeRow<ID>],
        selection: Set<ID>
    ) -> ID? {
        rows.first(where: { selection.contains($0.id) })?.id ?? rows.first?.id
    }

    static func effective<ID: Hashable>(
        _ focus: ID?,
        visibleRows rows: [TreeRow<ID>],
        selection: Set<ID>,
        ancestors: (ID) -> [ID]
    ) -> ID? {
        guard let focus else { return Self.initialFocus(rows: rows, selection: selection) }
        if rows.contains(where: { $0.id == focus }) { return focus }
        return Self.reconciled(focus, visibleRows: rows, ancestorsOfFocus: ancestors(focus))
    }

    static func ancestors<ID: Hashable>(of target: ID, in rows: [TreeRow<ID>]) -> [ID] {
        let parents = Dictionary(rows.map { ($0.id, $0.parent) }, uniquingKeysWith: { first, _ in first })
        var out: [ID] = []
        var cursor = parents[target] ?? nil
        while let parent = cursor, !out.contains(parent) {
            out.append(parent)
            cursor = parents[parent] ?? nil
        }
        return out
    }

    static func showsRing(containerFocused: Bool, lastInteraction: TreeInteraction) -> Bool {
        containerFocused && lastInteraction == .keyboard
    }

    static func reconciled<ID: Hashable>(
        _ focus: ID?,
        visibleRows rows: [TreeRow<ID>],
        ancestorsOfFocus ancestors: [ID]
    ) -> ID? {
        guard let focus else { return rows.first?.id }
        let visible = Set(rows.map(\.id))
        if visible.contains(focus) { return focus }
        if let nearest = ancestors.first(where: { visible.contains($0) }) { return nearest }
        return rows.first?.id
    }
}

// MARK: - 无障碍取值 / Accessibility values

nonisolated enum TreeRowAccessibility {
    static let expandedKey = "Expanded"
    static let collapsedKey = "Collapsed"
    static let expandActionKey = "Expand"
    static let collapseActionKey = "Collapse"

    static func expansionValueKey(isExpanded: Bool) -> String {
        isExpanded ? Self.expandedKey : Self.collapsedKey
    }

    static func chevronLabelKey(isExpanded: Bool) -> String {
        isExpanded ? Self.collapseActionKey : Self.expandActionKey
    }

    static func traits(isSelected: Bool) -> AccessibilityTraits {
        isSelected ? AccessibilityTraits.isSelected : AccessibilityTraits()
    }
}
