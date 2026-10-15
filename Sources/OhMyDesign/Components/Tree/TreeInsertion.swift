import SwiftUI

/// 非数据行的显示位置；不会进入树的选中、移动或数据拓扑。
nonisolated struct TreeInsertionPosition<ID: Hashable>: Equatable {
    let afterID: ID?
    let level: Int

    init?(parentID: ID?, rows: [TreeRow<ID>], expanded: Set<ID>) {
        guard let parentID else {
            afterID = rows.last?.id
            level = 1
            return
        }
        guard expanded.contains(parentID), let index = rows.firstIndex(where: { $0.id == parentID }) else {
            return nil
        }
        let parent = rows[index]
        var last = parent.id
        for row in rows.dropFirst(index + 1) {
            guard row.level > parent.level else { break }
            last = row.id
        }
        afterID = last
        level = parent.level + 1
    }
}

struct TreeInsertion<ID: Hashable> {
    let parentID: ID?
    let content: AnyView
}

struct TreeInsertionRow: View {
    let content: AnyView
    let level: Int
    let metrics: TreeRowMetrics
    @Environment(\.treeStyle) private var style

    var body: some View {
        let configuration = TreeRowConfiguration(
            label: content,
            disclosure: TreeDisclosureControl(hasChildren: false, isExpanded: false, metrics: metrics) {},
            checkBox: nil,
            level: level, hasChildren: false, isExpanded: false, isSelected: false,
            showsFocusIndicator: false, isHovered: false, metrics: metrics
        )
        switch style.appearance {
        case .automatic: AutomaticTreeRow(configuration: configuration)
        case .navigator: NavigatorTreeRow(configuration: configuration)
        }
    }
}
