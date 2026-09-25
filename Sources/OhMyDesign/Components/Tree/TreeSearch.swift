import SwiftUI

// MARK: - 匹配 / Matcher

nonisolated enum TreeSearchMatcher {
    static let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive, .widthInsensitive]

    static func normalized(_ query: String) -> String? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    static func firstRange(of needle: String, in text: String, from start: String.Index) -> Range<String.Index>? {
        guard start < text.endIndex,
              let hit = text.range(of: needle, options: Self.options, range: start..<text.endIndex),
              !hit.isEmpty
        else { return nil }
        return hit
    }

    static func matches(_ text: String, normalizedQuery query: String) -> Bool {
        Self.firstRange(of: query, in: text, from: text.startIndex) != nil
    }

    static func ranges(of query: String, in text: String) -> [Range<String.Index>] {
        guard let needle = Self.normalized(query) else { return [] }
        var out: [Range<String.Index>] = []
        var cursor = text.startIndex
        while let hit = Self.firstRange(of: needle, in: text, from: cursor) {
            out.append(hit)
            cursor = hit.upperBound
        }
        return out
    }
}

// MARK: - 过滤结果 / Search result

nonisolated struct TreeSearchResult<ID: Hashable>: Equatable {
    var matches: Set<ID> = []
    var revealed: Set<ID> = []
    var included: Set<ID> = []
}

nonisolated struct TreeSearchSession<ID: Hashable>: Equatable {
    let query: String
    var expanded: Set<ID> = []
    var collapsed: Set<ID> = []
}

nonisolated struct TreeSearchFrame<ID: Hashable> {
    let query: String?
    let included: Set<ID>?
    let expansion: TreeExpansionState<ID>
}

nonisolated struct TreeSearchCacheKey: Hashable {
    let query: String
    let version: AnyHashable
    let id: AnyKeyPath
    let children: AnyKeyPath
}

nonisolated struct TreeSearchMemo<ID: Hashable> {
    private(set) var key: TreeSearchCacheKey?
    private var cached: TreeSearchResult<ID>?

    mutating func result(for key: TreeSearchCacheKey?, compute: () -> TreeSearchResult<ID>) -> TreeSearchResult<ID> {
        if let key, key == self.key, let cached = self.cached { return cached }
        let fresh = compute()
        self.key = key
        self.cached = key == nil ? nil : fresh
        return fresh
    }
}

nonisolated struct TreeCheckScopeMemo<ID: Hashable> {
    private(set) var key: TreeSearchCacheKey?
    private var scopes: [ID: TreeRowCheckScope<ID>] = [:]

    mutating func scope(of rowID: ID, for key: TreeSearchCacheKey?, compute: () -> TreeRowCheckScope<ID>) -> TreeRowCheckScope<ID> {
        guard let key else { return compute() }
        if key != self.key {
            self.key = key
            self.scopes = [:]
        }
        if let hit = self.scopes[rowID] { return hit }
        let fresh = compute().indexed()
        self.scopes[rowID] = fresh
        return fresh
    }
}

nonisolated struct TreeRowsMemo<Element, ID: Hashable> {
    private(set) var key: TreeSearchCacheKey?
    private var expanded: Set<ID> = []
    private var cached: TreeVisibleRows<Element, ID>?

    mutating func rows(
        for key: TreeSearchCacheKey?,
        expanded: Set<ID>,
        compute: () -> [TreeRenderItem<Element, ID>]
    ) -> TreeVisibleRows<Element, ID> {
        if let key, key == self.key, expanded == self.expanded, let cached = self.cached { return cached }
        let items = compute()
        let fresh = TreeVisibleRows(items: items, rows: items.map(\.row))
        self.key = key
        self.expanded = key == nil ? [] : expanded
        self.cached = key == nil ? nil : fresh
        return fresh
    }
}

nonisolated struct TreeVisibleRows<Element, ID: Hashable> {
    let items: [TreeRenderItem<Element, ID>]
    let rows: [TreeRow<ID>]
}

final class TreeSearchCache<Element, ID: Hashable> {
    var memo = TreeSearchMemo<ID>()
    var checkScopes = TreeCheckScopeMemo<ID>()
    var rows = TreeRowsMemo<Element, ID>()
}

nonisolated enum TreeSearch {
    static func result<Data: RandomAccessCollection, ID: Hashable>(
        _ data: Data,
        id: KeyPath<Data.Element, ID>,
        children: KeyPath<Data.Element, Data?>,
        query: String,
        text: (Data.Element) -> String
    ) -> TreeSearchResult<ID> {
        var result = TreeSearchResult<ID>()
        guard let needle = TreeSearchMatcher.normalized(query) else { return result }
        func walk(_ nodes: Data, underMatch: Bool) -> Bool {
            var found = false
            for node in nodes {
                let nodeID = node[keyPath: id]
                let isMatch = TreeSearchMatcher.matches(text(node), normalizedQuery: needle)
                var below = false
                if let kids = node[keyPath: children], !kids.isEmpty {
                    below = walk(kids, underMatch: underMatch || isMatch)
                }
                if isMatch { result.matches.insert(nodeID) }
                if below { result.revealed.insert(nodeID) }
                if isMatch || below || underMatch { result.included.insert(nodeID) }
                found = found || isMatch || below
            }
            return found
        }
        _ = walk(data, underMatch: false)
        return result
    }

    static func expansion<ID: Hashable>(
        persisted: Set<ID>,
        query: String?,
        revealed: Set<ID>,
        session: TreeSearchSession<ID>?
    ) -> TreeExpansionState<ID> {
        guard let query else { return TreeExpansionState(persisted: persisted) }
        let carried = session?.query == query ? session : nil
        return TreeExpansionState(
            persisted: persisted,
            overlay: TreeExpansionState.Overlay(
                revealed: revealed,
                expanded: carried?.expanded ?? [],
                collapsed: carried?.collapsed ?? []
            )
        )
    }

    static func session<ID: Hashable>(from state: TreeExpansionState<ID>, query: String?) -> TreeSearchSession<ID>? {
        guard let query = query.flatMap(TreeSearchMatcher.normalized), let overlay = state.overlay else { return nil }
        return TreeSearchSession(query: query, expanded: overlay.expanded, collapsed: overlay.collapsed)
    }

    static func frame<Data: RandomAccessCollection, ID: Hashable>(
        _ data: Data,
        id: KeyPath<Data.Element, ID>,
        children: KeyPath<Data.Element, Data?>,
        query rawQuery: String?,
        text: ((Data.Element) -> String)?,
        persisted: Set<ID>,
        session: TreeSearchSession<ID>?
    ) -> TreeSearchFrame<ID> {
        var memo = TreeSearchMemo<ID>()
        return Self.frame(
            data, id: id, children: children, query: rawQuery, text: text,
            persisted: persisted, session: session, version: nil, memo: &memo
        )
    }

    static func frame<Data: RandomAccessCollection, ID: Hashable>(
        _ data: Data,
        id: KeyPath<Data.Element, ID>,
        children: KeyPath<Data.Element, Data?>,
        query rawQuery: String?,
        text: ((Data.Element) -> String)?,
        persisted: Set<ID>,
        session: TreeSearchSession<ID>?,
        version: AnyHashable?,
        memo: inout TreeSearchMemo<ID>
    ) -> TreeSearchFrame<ID> {
        guard let query = rawQuery.flatMap(TreeSearchMatcher.normalized), let text else {
            return TreeSearchFrame(query: nil, included: nil, expansion: TreeExpansionState(persisted: persisted))
        }
        let key = version.map { TreeSearchCacheKey(query: query, version: $0, id: id, children: children) }
        let found = memo.result(for: key) {
            Self.result(data, id: id, children: children, query: query, text: text)
        }
        return TreeSearchFrame(
            query: query,
            included: found.included,
            expansion: Self.expansion(persisted: persisted, query: query, revealed: found.revealed, session: session)
        )
    }
}

// MARK: - 命中高亮 / Match highlighting

public extension Text {
    /// 以原文显示 `content`（不本地化），并高亮其中与 `query` 匹配的片段：加粗 + `Color.searchMatchBackground` 底色。
    ///
    /// 匹配规则与 `Tree.searchFilter(_:text:)`、`Tree.searchMatches(_:id:children:query:text:)` 相同
    /// （去首尾空白后，不区分大小写 / 变音符 / 全半角的子串，片段逐个不重叠）；只有传入与过滤相同的搜索词、相同的文案时，
    /// 高亮的片段才是该行被过滤留下的原因。`query` 为空时与 `Text(verbatim:)` 相同。
    ///
    /// - Parameters:
    ///   - content: 要显示的原文，通常是节点文案。
    ///   - query: 当前搜索词。
    init(verbatim content: String, highlighting query: String) {
        self.init(TreeHighlight.attributed(content, query: query))
    }
}

enum TreeHighlight {
    static func attributed(_ content: String, query: String) -> AttributedString {
        var attributed = AttributedString(content)
        for range in TreeSearchMatcher.ranges(of: query, in: content) {
            guard let lower = AttributedString.Index(range.lowerBound, within: attributed),
                  let upper = AttributedString.Index(range.upperBound, within: attributed)
            else { continue }
            attributed[lower..<upper].inlinePresentationIntent = .stronglyEmphasized
            attributed[lower..<upper].backgroundColor = Color.searchMatchBackground
        }
        return attributed
    }
}
