import Foundation

/// 同一 Tree 内一次移动：移除源节点后，插入目标父节点的 beforeID 之前或末尾。
public nonisolated struct TreeMove<ID: Hashable>: Equatable {
    /// 被移动节点的稳定 ID；子树随节点整体移动。
    public let id: ID
    /// 新父节点；nil 表示根目录。
    public let parentID: ID?
    /// 目标同级中的后继节点；nil 表示末尾。
    public let beforeID: ID?

    /// 创建一次按稳定身份定位的移动。
    public init(id: ID, parentID: ID?, beforeID: ID?) {
        self.id = id
        self.parentID = parentID
        self.beforeID = beforeID
    }
}

nonisolated enum TreeDropTarget<ID: Hashable>: Equatable {
    case before(ID)
    case after(ID)
    case inside(ID)
    case rootEnd

    static func row(_ id: ID, fraction: Double, acceptsChildren: Bool) -> Self {
        if acceptsChildren {
            if fraction < 0.25 { return .before(id) }
            if fraction > 0.75 { return .after(id) }
            return .inside(id)
        }
        return fraction < 0.5 ? .before(id) : .after(id)
    }
}

nonisolated struct TreeStructure<ID: Hashable>: Equatable {
    struct Node: Equatable {
        let parentID: ID?
        let children: [ID]?
    }

    let roots: [ID]
    private(set) var nodes: [ID: Node] = [:]

    init<Data: RandomAccessCollection>(_ data: Data, id: KeyPath<Data.Element, ID>, children: KeyPath<Data.Element, Data?>) {
        self.roots = data.map { $0[keyPath: id] }
        func visit(_ elements: Data, parentID: ID?) {
            for element in elements {
                let key = element[keyPath: id]
                let descendants = element[keyPath: children]
                self.nodes[key] = Node(parentID: parentID, children: descendants.map { $0.map { $0[keyPath: id] } })
                if let descendants { visit(descendants, parentID: key) }
            }
        }
        visit(data, parentID: nil)
    }

    func move(_ id: ID, to target: TreeDropTarget<ID>) -> TreeMove<ID>? {
        guard let source = nodes[id] else { return nil }
        let parentID: ID?
        var beforeID: ID?
        switch target {
        case .rootEnd:
            parentID = nil
            beforeID = nil
        case let .inside(targetID):
            guard self.nodes[targetID]?.children != nil else { return nil }
            parentID = targetID
            beforeID = nil
        case let .before(targetID):
            guard targetID != id, let target = nodes[targetID] else { return nil }
            parentID = target.parentID
            beforeID = targetID
        case let .after(targetID):
            guard targetID != id, let target = nodes[targetID] else { return nil }
            parentID = target.parentID
            let siblings = self.children(of: parentID).filter { $0 != id }
            guard let index = siblings.firstIndex(of: targetID) else { return nil }
            beforeID = siblings.dropFirst(index + 1).first
        }
        var ancestor = parentID
        while let current = ancestor {
            if current == id { return nil }
            ancestor = self.nodes[current]?.parentID
        }
        if source.parentID == parentID {
            let siblings = self.children(of: parentID)
            guard let index = siblings.firstIndex(of: id) else { return nil }
            if siblings.dropFirst(index + 1).first == beforeID { return nil }
        }
        return TreeMove(id: id, parentID: parentID, beforeID: beforeID)
    }

    private func children(of id: ID?) -> [ID] {
        guard let id else { return self.roots }
        return self.nodes[id]?.children ?? []
    }
}
