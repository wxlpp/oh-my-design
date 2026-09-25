import SwiftUI
import Testing
@testable import OhMyDesign

// MARK: - 过滤结果缓存 / Search result memo

extension TreeJudgeNode {
    var leafless: [TreeJudgeNode]? { nil }
}

@Suite("Tree 搜索缓存：按（去空白后的搜索词, 版本号）缓存过滤结果；任一变化必须重算、都不变不重算；不给版本号每次重算")
struct TreeSearchMemoTests {
    private static func key(_ query: String, version: Int) -> TreeSearchCacheKey {
        TreeSearchCacheKey(
            query: query, version: AnyHashable(version), id: \TreeJudgeNode.id, children: \TreeJudgeNode.children
        )
    }

    private static func frame(
        _ query: String,
        version: Int?,
        persisted: Set<String> = [],
        memo: inout TreeSearchMemo<String>,
        calls: inout Int
    ) -> TreeSearchFrame<String> {
        var counted = 0
        let frame = TreeSearch.frame(
            TreeJudgeFixture.roots, id: \TreeJudgeNode.id, children: \TreeJudgeNode.children,
            query: query, text: { node in counted += 1; return node.id },
            persisted: persisted, session: nil, version: version.map(AnyHashable.init), memo: &memo
        )
        calls += counted
        return frame
    }

    @Test("同一个键连取两次只算一次；换版本号、换搜索词都重算")
    func keyDecidesRecomputation() {
        var memo = TreeSearchMemo<String>()
        var computed = 0
        let compute = { () -> TreeSearchResult<String> in
            computed += 1
            return TreeSearchFixture.result("y")
        }
        _ = memo.result(for: Self.key("y", version: 1), compute: compute)
        _ = memo.result(for: Self.key("y", version: 1), compute: compute)
        #expect(computed == 1, "键没变却重算了 \(computed) 次")
        _ = memo.result(for: Self.key("y", version: 2), compute: compute)
        #expect(computed == 2, "版本号变了没有重算")
        _ = memo.result(for: Self.key("a1", version: 2), compute: compute)
        #expect(computed == 3, "搜索词变了没有重算")
        _ = memo.result(for: Self.key("y", version: 1), compute: compute)
        #expect(computed == 4, "只记最近一个键：回到旧键也要重算")
    }

    @Test("不给版本号（键为 nil）每次都重算，也不留下缓存")
    func nilKeyAlwaysRecomputes() {
        var memo = TreeSearchMemo<String>()
        var computed = 0
        let compute = { () -> TreeSearchResult<String> in
            computed += 1
            return TreeSearchFixture.result("y")
        }
        _ = memo.result(for: Self.key("y", version: 1), compute: compute)
        _ = memo.result(for: nil, compute: compute)
        _ = memo.result(for: nil, compute: compute)
        #expect(computed == 3)
        #expect(memo.key == nil, "键为 nil 之后还留着上一个键")
        _ = memo.result(for: Self.key("y", version: 1), compute: compute)
        #expect(computed == 4, "键为 nil 之后，旧键的缓存不应复活")
    }

    @Test("取子节点的 key path 是键的一部分：换了它就不命中")
    func keyPathsArePartOfTheKey() {
        let a = Self.key("y", version: 1)
        let other = TreeSearchCacheKey(
            query: "y", version: AnyHashable(1), id: \TreeJudgeNode.id, children: \TreeJudgeNode.leafless
        )
        #expect(a == Self.key("y", version: 1))
        #expect(a != other)
    }

    @Test("视图用的 frame：版本号与搜索词都不变时不再读文案，但展开态照样跟着持久化集合走")
    func frameReusesTheResultButNotTheExpansion() {
        var memo = TreeSearchMemo<String>()
        var calls = 0
        let first = Self.frame("y", version: 7, memo: &memo, calls: &calls)
        let afterFirst = calls
        #expect(afterFirst > 0)
        let second = Self.frame(" y ", version: 7, persisted: ["c"], memo: &memo, calls: &calls)
        #expect(calls == afterFirst, "搜索词（去空白后）与版本号都没变，又遍历了一次")
        #expect(second.included == first.included)
        #expect(second.expansion.effective.contains("c"), "缓存把展开态也冻住了：持久化集合里的 c 没有生效")
        _ = Self.frame("y", version: 8, memo: &memo, calls: &calls)
        #expect(calls > afterFirst, "版本号变了没有重新遍历")
        let afterVersion = calls
        let other = Self.frame("a1", version: 8, memo: &memo, calls: &calls)
        #expect(calls > afterVersion, "搜索词变了没有重新遍历")
        #expect(other.included == TreeSearchFixture.result("a1").included)
    }

    @Test("视图用的 frame：不给版本号时每次都遍历（与加缓存前相同）")
    func frameWithoutAVersionAlwaysWalks() {
        var memo = TreeSearchMemo<String>()
        var calls = 0
        _ = Self.frame("y", version: nil, memo: &memo, calls: &calls)
        let once = calls
        _ = Self.frame("y", version: nil, memo: &memo, calls: &calls)
        #expect(calls == 2 * once)
    }
}

// MARK: - 父行勾选范围缓存 / Check scope memo

@Suite("Tree 父行勾选范围：缓存按行与（搜索词, 版本号）取；过滤后的叶子用留下的集合筛，与按留下的集合遍历等价")
struct TreeCheckScopeMemoTests {
    private static func key(_ query: String, version: Int) -> TreeSearchCacheKey {
        TreeSearchCacheKey(
            query: query, version: AnyHashable(version), id: \TreeJudgeNode.id, children: \TreeJudgeNode.children
        )
    }

    private static func resolve(_ id: String, query: String?) -> TreeRowCheckScope<String> {
        TreeRowCheckScope.resolve(
            TreeJudgeFixture.node(id), id: \TreeJudgeNode.id, children: \TreeJudgeNode.children,
            within: query.map { TreeSearchFixture.result($0).included }
        )
    }

    @Test("同一行、同一个键只算一次；换版本号或搜索词后重算；键为 nil 每次都算")
    func keyDecidesRecomputation() {
        var memo = TreeCheckScopeMemo<String>()
        var computed = 0
        let compute = { () -> TreeRowCheckScope<String> in
            computed += 1
            return Self.resolve("a", query: "y")
        }
        _ = memo.scope(of: "a", for: Self.key("y", version: 1), compute: compute)
        let hit = memo.scope(of: "a", for: Self.key("y", version: 1), compute: compute)
        #expect(computed == 1, "同一行同一个键重算了 \(computed) 次")
        #expect(hit.displaySet == Set(hit.display), "缓存里的范围没有带上索引集合")
        _ = memo.scope(of: "c", for: Self.key("y", version: 1), compute: compute)
        #expect(computed == 2, "另一行应当另算")
        _ = memo.scope(of: "a", for: Self.key("y", version: 2), compute: compute)
        #expect(computed == 3, "版本号变了没有重算")
        _ = memo.scope(of: "a", for: Self.key("a1", version: 2), compute: compute)
        #expect(computed == 4, "搜索词变了没有重算")
        _ = memo.scope(of: "a", for: nil, compute: compute)
        _ = memo.scope(of: "a", for: nil, compute: compute)
        #expect(computed == 6)
    }

    @Test("留下的每一行：用留下的集合筛全部叶后代 == 只沿留下的节点遍历", arguments: ["y", "a1", "a", "c", "1", "zz"])
    func filteringEqualsWalkingWithinIncluded(query: String) {
        let included = TreeSearchFixture.result(query).included
        for id in included.sorted() {
            let node = TreeJudgeFixture.node(id)
            let walked = TreeFlatten.descendantLeafIDs(
                of: node, id: \TreeJudgeNode.id, children: \TreeJudgeNode.children, within: included
            )
            let leaves = TreeFlatten.descendantLeafIDs(of: node, id: \TreeJudgeNode.id, children: \TreeJudgeNode.children)
            #expect(
                TreeFlatten.retainedLeafIDs(leaves, within: included) == walked,
                "\(query) / \(id)：筛出 \(TreeFlatten.retainedLeafIDs(leaves, within: included))，遍历得 \(walked)"
            )
        }
    }

    @Test("按集合求两路来源与按数组求逐一相同：每个父行 × 叶子勾选的全部组合")
    func setIndicatorMatchesArrayIndicator() {
        let allLeaves = TreeFlatten.descendantLeafIDs(
            of: TreeJudgeNode(id: "root", children: TreeJudgeFixture.roots),
            id: \TreeJudgeNode.id, children: \TreeJudgeNode.children
        )
        let subsets = (0..<(1 << allLeaves.count)).map { mask in
            Set(allLeaves.enumerated().filter { mask & (1 << $0.offset) != 0 }.map(\.element))
        }
        for id in TreeJudgeFixture.parentIDs.sorted() + ["b", "c1"] {
            let leaves = Self.resolve(id, query: nil).display
            for checked in subsets {
                #expect(
                    TreeChecking.indicatorSources(ofLeafSet: Set(leaves), in: checked)
                        == TreeChecking.indicatorSources(ofLeaves: leaves, in: checked),
                    "\(id) / \(checked.sorted())"
                )
            }
        }
        #expect(TreeChecking.indicatorSources(ofLeafSet: Set<String>(), in: ["a"]) == [false, false])
    }

    @Test("带索引集合的两路绑定与不带的读数相同", arguments: [Set<String>(), ["a1y"], ["a1x", "a1y", "a2"], ["b"]])
    func indexedBindingsReadTheSame(checked: Set<String>) {
        var store = checked
        let binding = Binding(get: { store }, set: { store = $0 })
        let scope = Self.resolve("a", query: "y")
        let plain = TreeCheckBindings.scoped(display: scope.display, scope: scope.action, in: binding, onWrite: {})
        let indexed = TreeCheckBindings.scoped(
            display: scope.display, indexed: Set(scope.display), scope: scope.action, in: binding, onWrite: {}
        )
        #expect(plain.map(\.wrappedValue) == indexed.map(\.wrappedValue))
    }
}

// MARK: - 托管窗口 / Hosted

#if os(macOS)
@MainActor
@Observable
final class TreeSearchCacheModel {
    var query = "y"
    var version = 0
    var expanded: Set<String> = []
    var selection: Set<String> = []
    var checked: Set<String> = []
    @ObservationIgnored var textReads = 0
}

enum TreeSearchCacheVersioning: CaseIterable, CustomTestStringConvertible, Sendable {
    case versioned
    case unversioned

    var testDescription: String {
        switch self {
        case .versioned: "带版本号"
        case .unversioned: "不带版本号"
        }
    }
}

struct TreeSearchCacheHarness: View {
    let model: TreeSearchCacheModel
    let versioning: TreeSearchCacheVersioning

    var body: some View {
        let tree = Tree(
            TreeJudgeFixture.roots,
            children: \.children,
            expanded: Binding(get: { self.model.expanded }, set: { self.model.expanded = $0 }),
            selection: Binding(get: { self.model.selection }, set: { self.model.selection = $0 }),
            selectionMode: .multiple,
            checked: Binding(get: { self.model.checked }, set: { self.model.checked = $0 })
        ) { node in
            Text(verbatim: node.id)
        }
        let text: (TreeJudgeNode) -> String = { node in
            self.model.textReads += 1
            return node.id
        }
        return Group {
            switch self.versioning {
            case .versioned: tree.searchFilter(self.model.query, text: text, version: self.model.version)
            case .unversioned: tree.searchFilter(self.model.query, text: text)
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .allowsWindowActivationEvents(true)
    }
}

@Suite("Tree 搜索缓存接线（macOS 托管窗口）：带版本号时选中 / 展开 / 勾选引起的重算不读文案，换版本号或搜索词才读；不带版本号照旧每次读")
@MainActor
struct TreeSearchCacheHostedTests {
    private static func window(_ model: TreeSearchCacheModel, _ versioning: TreeSearchCacheVersioning) -> HostedWindow {
        HostedWindow(
            TreeSearchCacheHarness(model: model, versioning: versioning),
            size: CGSize(width: 260, height: 400),
            scheme: .light
        )
    }

    private static func reads(_ window: HostedWindow, _ model: TreeSearchCacheModel, after change: () -> Void) -> Int {
        let before = model.textReads
        change()
        window.settle()
        return model.textReads - before
    }

    @Test("带版本号：数据与搜索词都不变的重算不读文案；换版本号、换搜索词各重读一遍")
    func versionedRecomputesOnlyWhenTheKeyChanges() {
        let model = TreeSearchCacheModel()
        let window = Self.window(model, .versioned)
        defer { window.close() }
        #expect(model.textReads > 0, "托管窗口没有渲染出搜索")
        #expect(Self.reads(window, model) { model.selection = ["a1y"] } == 0, "改选中又读了文案")
        #expect(Self.reads(window, model) { model.expanded = ["c"] } == 0, "改展开又读了文案")
        #expect(Self.reads(window, model) { model.checked = ["a1y"] } == 0, "改勾选又读了文案")
        #expect(Self.reads(window, model) { model.query = " y " } == 0, "只差首尾空白的搜索词又读了文案")
        #expect(Self.reads(window, model) { model.version += 1 } > 0, "换版本号没有重读文案")
        #expect(Self.reads(window, model) { model.query = "a1" } > 0, "换搜索词没有重读文案")
    }

    @Test("不带版本号：改选中照旧重读文案（行为与加缓存前相同）")
    func unversionedStillWalksOnEveryRecompute() {
        let model = TreeSearchCacheModel()
        let window = Self.window(model, .unversioned)
        defer { window.close() }
        #expect(Self.reads(window, model) { model.selection = ["a1y"] } > 0)
    }

    @Test(
        "带与不带版本号，搜索期间连点两次父行复选框的结果逐条相同",
        arguments: TreeSearchCacheVersioning.allCases, TreeSearchCheckScopeTests.clicks
    )
    func checkCascadeMatchesAcrossVersioning(versioning: TreeSearchCacheVersioning, click: TreeSearchCheckScopeTests.Click) {
        let model = TreeSearchCacheModel()
        model.checked = click.initial
        let window = Self.window(model, versioning)
        defer { window.close() }
        let metrics = TreeRowMetrics.resolve(.regular)
        let x = CoreSpacing.xs + metrics.disclosureWidth + CoreSpacing.xs + metrics.checkBoxGlyph / 2
        let point = CGPoint(x: x, y: metrics.rowHeight / 2)
        window.sendMouse(.leftMouseDown, at: point)
        window.sendMouse(.leftMouseUp, at: point)
        window.settle()
        #expect(model.checked == click.first, "\(versioning) / \(click.reason)：第一次点击实得 \(model.checked.sorted())")
        window.sendMouse(.leftMouseDown, at: point)
        window.sendMouse(.leftMouseUp, at: point)
        window.settle()
        #expect(model.checked == click.second, "\(versioning) / \(click.reason)：第二次点击实得 \(model.checked.sorted())")
    }
}
#endif
