import SwiftUI
import Testing
@testable import OhMyDesign

// MARK: - 样本 / Fixture

enum TreeSearchFixture {
    static func result(_ query: String) -> TreeSearchResult<String> {
        TreeSearch.result(
            TreeJudgeFixture.roots,
            id: \TreeJudgeNode.id,
            children: \TreeJudgeNode.children,
            query: query,
            text: \.id
        )
    }

    static func expansion(
        persisted: Set<String>,
        query: String,
        session: TreeSearchSession<String>? = nil
    ) -> TreeExpansionState<String> {
        TreeSearch.expansion(
            persisted: persisted,
            query: TreeSearchMatcher.normalized(query),
            revealed: Self.result(query).revealed,
            session: session
        )
    }

    static func rows(persisted: Set<String>, query: String, session: TreeSearchSession<String>? = nil) -> [TreeRow<String>] {
        let search = TreeSearchMatcher.normalized(query).map { _ in Self.result(query) }
        return TreeFlatten.rows(
            TreeJudgeFixture.roots,
            id: \TreeJudgeNode.id,
            children: \TreeJudgeNode.children,
            expanded: Self.expansion(persisted: persisted, query: query, session: session).effective,
            included: search?.included
        )
    }
}

// MARK: - 匹配 / Matcher

@Suite("Tree 搜索匹配：去首尾空白、不区分大小写 / 变音符 / 全半角的子串；空串不在搜索")
struct TreeSearchMatcherTests {
    @Test("空串与纯空白不算在搜索")
    func blankQueriesAreInactive() {
        #expect(TreeSearchMatcher.normalized("") == nil)
        #expect(TreeSearchMatcher.normalized("  \n\t") == nil)
        #expect(TreeSearchMatcher.normalized("  Col ") == "Col")
    }

    @Test("命中片段：不区分大小写与变音符，逐个不重叠地找出来")
    func rangesAreCaseAndDiacriticInsensitive() {
        let text = "Café CAFE cafe"
        let ranges = TreeSearchMatcher.ranges(of: "cafe", in: text)
        #expect(ranges.map { String(text[$0]) } == ["Café", "CAFE", "cafe"], "实得 \(ranges.map { String(text[$0]) })")
        #expect(TreeSearchMatcher.ranges(of: "aa", in: "aaaa").count == 2, "片段应当不重叠")
        #expect(TreeSearchMatcher.ranges(of: " col ", in: "Color").map { String("Color"[$0]) } == ["Col"], "搜索词应当先去首尾空白")
        #expect(TreeSearchMatcher.ranges(of: "", in: "Color").isEmpty)
        #expect(TreeSearchMatcher.ranges(of: "zz", in: "Color").isEmpty)
    }

    @Test("全角与半角同等看待")
    func widthInsensitive() {
        #expect(TreeSearchMatcher.ranges(of: "ＡＢ", in: "xab").count == 1)
    }
}

// MARK: - 留下的集合 / Retained set

@Suite("Tree 搜索留下的行：命中 ∪ 命中的祖先 ∪ 命中的后代；自动展开命中的严格祖先")
struct TreeSearchResultTests {
    @Test("叶子命中：留下它与祖先链，兄弟与无关子树都不留")
    func aLeafMatchKeepsItsAncestorChain() {
        let result = TreeSearchFixture.result("y")
        #expect(result.matches == ["a1y"])
        #expect(result.revealed == ["a", "a1"], "自动展开应当恰为命中的严格祖先，实得 \(result.revealed.sorted())")
        #expect(result.included == ["a", "a1", "a1y"], "实得 \(result.included.sorted())")
    }

    @Test("父节点命中：它的后代全部留下（可展开浏览），但不自动展开没有命中的后代")
    func aParentMatchKeepsItsWholeSubtree() {
        let result = TreeSearchFixture.result("c")
        #expect(result.matches == ["c", "c1"])
        #expect(result.revealed == ["c"], "c 是 c1 的祖先，应当自动展开")
        #expect(result.included == ["c", "c1"])

        let a1 = TreeSearchFixture.result("A1")
        #expect(a1.matches == ["a1", "a1x", "a1y"], "大小写不同也应当命中，实得 \(a1.matches.sorted())")
        #expect(a1.included == ["a", "a1", "a1x", "a1y"], "a2 既不命中也不是命中的祖先 / 后代，不应留下，实得 \(a1.included.sorted())")
    }

    @Test("命中的文件夹：后代即使不命中也留下（可展开浏览），但不自动展开")
    func aMatchedFolderKeepsNonMatchingDescendants() {
        let roots = [
            TreeJudgeNode(id: "docs", children: [
                TreeJudgeNode(id: "readme", children: nil),
                TreeJudgeNode(id: "guide", children: [TreeJudgeNode(id: "intro", children: nil)]),
            ]),
            TreeJudgeNode(id: "src", children: [TreeJudgeNode(id: "main", children: nil)]),
        ]
        let result = TreeSearch.result(roots, id: \TreeJudgeNode.id, children: \TreeJudgeNode.children, query: "docs", text: \.id)
        #expect(result.matches == ["docs"])
        #expect(result.included == ["docs", "readme", "guide", "intro"], "命中文件夹的后代没有留下，实得 \(result.included.sorted())")
        #expect(result.revealed.isEmpty, "docs 下没有命中，不应自动展开任何节点，实得 \(result.revealed.sorted())")
        let collapsed = TreeFlatten.rows(
            roots, id: \TreeJudgeNode.id, children: \TreeJudgeNode.children, expanded: [], included: result.included
        )
        #expect(collapsed.map(\.id) == ["docs"])
        #expect(collapsed.first?.hasChildren == true, "命中的文件夹应当仍有 chevron，能展开浏览")
        let opened = TreeFlatten.rows(
            roots, id: \TreeJudgeNode.id, children: \TreeJudgeNode.children, expanded: ["docs"], included: result.included
        )
        #expect(opened.map(\.id) == ["docs", "readme", "guide"])
    }

    @Test("留下的父行一定至少留下一个子行——所以过滤后行的 hasChildren 与数据一致")
    func everyRetainedParentKeepsAChild() {
        for query in ["y", "c", "a1", "a2", "b", "x"] {
            let result = TreeSearchFixture.result(query)
            for id in result.included where TreeJudgeFixture.parentIDs.contains(id) {
                let kids = TreeJudgeFixture.node(id).children ?? []
                #expect(kids.contains { result.included.contains($0.id) }, "\(query)：留下的父行 \(id) 一个子行都没留")
            }
        }
    }

    @Test("过滤后的可见行：命中的祖先链自动展开，未留下的行不出现")
    func filteredRowsRevealEveryMatch() {
        let rows = TreeSearchFixture.rows(persisted: [], query: "y")
        #expect(rows.map(\.id) == ["a", "a1", "a1y"], "实得 \(rows.map(\.id))")
        #expect(rows.map(\.level) == [1, 2, 3])
        #expect(rows.map(\.hasChildren) == [true, true, false])
    }
}

// MARK: - 真值表第 4 – 7 行（搜索触发）

@Suite("Tree 搜索真值表：展开只落 overlay、清空恢复、全选只作用于可见节点、焦点回退到最近可见祖先")
struct TreeSearchTruthTableTests {
    private static func press(
        _ key: TreeKey,
        _ modifiers: EventModifiers = [],
        state: TreeInteractionState<String>,
        rows: [TreeRow<String>]
    ) -> TreeInteractionOutcome<String> {
        TreeInteractionReducer.key(
            key,
            modifiers: modifiers,
            state: state,
            rows: rows,
            mode: .multiple,
            activation: .enabled,
            motion: .animated,
            treeIDs: { TreeJudgeFixture.treeIDs },
            ancestors: TreeJudgeFixture.ancestors(of:)
        )
    }

    @Test("第 4 行：搜索期间 ← / → / 点 chevron 只写 overlay，调用方的持久化集合不变")
    func searchExpansionNeverWritesThePersistedSet() {
        let persisted: Set<String> = ["c"]
        let expansion = TreeSearchFixture.expansion(persisted: persisted, query: "y")
        let rows = TreeSearchFixture.rows(persisted: persisted, query: "y")
        let state = TreeInteractionState(focus: "a", lastInteraction: .keyboard, selection: [], expansion: expansion)

        let collapsed = Self.press(.left, state: state, rows: rows)
        #expect(collapsed.state.expanded.contains("a") == false, "← 没有折叠自动展开的 a")
        #expect(collapsed.state.expansion.persisted == persisted, "搜索期间 ← 写进了持久化集合：\(collapsed.state.expansion.persisted.sorted())")
        let session = TreeSearch.session(from: collapsed.state.expansion, query: "y")
        #expect(session?.collapsed == ["a"], "手动折叠没有记进 overlay，实得 \(String(describing: session))")

        let reopened = Self.press(.right, state: collapsed.state, rows: TreeSearchFixture.rows(persisted: persisted, query: "y", session: session))
        #expect(reopened.state.expanded.contains("a"))
        #expect(reopened.state.expansion.persisted == persisted)

        let pointer = TreeInteractionReducer.pointerExpansion("a1", to: .collapsed, state: state, motion: .animated)
        #expect(pointer.state.expansion.persisted == persisted, "搜索期间点 chevron 写进了持久化集合")
        #expect(!pointer.state.expanded.contains("a1"))
    }

    @Test("第 5 行：清空搜索词回到搜索前的展开态，搜索期间的手动折叠不带出来")
    func clearingTheQueryRestoresTheExpansion() {
        let persisted: Set<String> = ["a"]
        let during = TreeSearchFixture.expansion(persisted: persisted, query: "y")
        var state = TreeInteractionState(focus: "a", lastInteraction: .keyboard, selection: [], expansion: during)
        state = Self.press(.left, state: state, rows: TreeSearchFixture.rows(persisted: persisted, query: "y")).state
        let session = TreeSearch.session(from: state.expansion, query: "y")
        #expect(session?.collapsed == ["a"], "前提：搜索期间手动折叠了 a")

        let cleared = TreeSearchFixture.expansion(persisted: state.expansion.persisted, query: "  ", session: session)
        #expect(cleared.overlay == nil, "清空后 overlay 还在")
        #expect(cleared.effective == persisted, "清空搜索没有恢复搜索前的展开态，实得 \(cleared.effective.sorted())")
        #expect(
            TreeSearch.session(from: cleared, query: nil) == nil,
            "清空后回写仍留着搜索会话"
        )
    }

    @Test("第 5 行：视图用的 frame 在搜索词为空时不带 overlay、不过滤，即使会话里还留着上一次的手动折叠")
    func frameWithoutAQueryIgnoresAStaleSession() {
        let stale = TreeSearchSession<String>(query: "y", expanded: [], collapsed: ["a"])
        for query: String? in [nil, "", "  "] {
            let frame = TreeSearch.frame(
                TreeJudgeFixture.roots, id: \TreeJudgeNode.id, children: \TreeJudgeNode.children,
                query: query, text: { $0.id }, persisted: ["a"], session: stale
            )
            #expect(frame.query == nil)
            #expect(frame.included == nil, "空搜索词仍在过滤")
            #expect(frame.expansion.overlay == nil, "空搜索词时 frame 带出了上一次搜索的 overlay")
            #expect(frame.expansion.effective == ["a"], "空搜索词时生效展开集合应等于持久化集合，实得 \(frame.expansion.effective.sorted())")
        }
        let active = TreeSearch.frame(
            TreeJudgeFixture.roots, id: \TreeJudgeNode.id, children: \TreeJudgeNode.children,
            query: " y ", text: { $0.id }, persisted: [], session: stale
        )
        #expect(active.included == ["a", "a1", "a1y"])
        #expect(!active.expansion.effective.contains("a"), "同一个词的手动折叠应当带上")
    }

    @Test("第 5 行连带：换一个搜索词，上一个词里的手动折叠不作用于新词")
    func changingTheQueryDropsManualOverrides() {
        let stale = TreeSearchSession<String>(query: "y", expanded: [], collapsed: ["a"])
        let next = TreeSearchFixture.expansion(persisted: [], query: "a1", session: stale)
        #expect(next.effective.contains("a"), "上一个词的手动折叠把新词的命中藏起来了，实得 \(next.effective.sorted())")
        let same = TreeSearchFixture.expansion(persisted: [], query: " y ", session: stale)
        #expect(!same.effective.contains("a"), "同一个词（去空白后相等）的手动折叠应当保留")
    }

    @Test("第 6 行：搜索期间 Ctrl/Cmd+A 只选留下且可见的行")
    func selectAllUnderSearchIsScopedToVisibleRows() {
        let rows = TreeSearchFixture.rows(persisted: [], query: "a1")
        #expect(rows.map(\.id) == ["a", "a1", "a1x", "a1y"], "前提变了：实得 \(rows.map(\.id))")
        let state = TreeInteractionState(
            focus: "a", lastInteraction: .keyboard, selection: [],
            expansion: TreeSearchFixture.expansion(persisted: [], query: "a1")
        )
        let outcome = Self.press(.character("a"), .command, state: state, rows: rows)
        #expect(outcome.state.selection == ["a", "a1", "a1x", "a1y"], "全选越出了过滤后的可见行：\(outcome.state.selection.sorted())")
    }

    @Test("第 6 行：搜索期间父行复选框只级联留下的叶后代，看不见的叶子不被勾上")
    func checkCascadeUnderSearchIsScopedToRetainedLeaves() {
        let included = TreeSearchFixture.result("y").included
        let leaves = TreeFlatten.descendantLeafIDs(
            of: TreeJudgeFixture.node("a"), id: \TreeJudgeNode.id, children: \TreeJudgeNode.children, within: included
        )
        #expect(leaves == ["a1y"], "搜索期间 a 的级联来源应当只有留下的 a1y，实得 \(leaves)")
        let checked = TreeChecking.applying(true, toLeaves: leaves, in: [])
        #expect(!checked.contains("a1x") && !checked.contains("a2"), "级联静默勾上了被过滤掉的叶子：\(checked.sorted())")

        let unfiltered = TreeFlatten.descendantLeafIDs(
            of: TreeJudgeFixture.node("a"), id: \TreeJudgeNode.id, children: \TreeJudgeNode.children, within: nil
        )
        #expect(unfiltered == ["a1x", "a1y", "a2"], "不在搜索时仍级联全部叶后代")
    }

    @Test("第 7 行：焦点行被过滤掉时移到最近的仍可见祖先，无祖先则移到首个可见行")
    func filteredFocusFallsBackToTheNearestVisibleAncestor() {
        let before = TreeSearchFixture.rows(persisted: ["a", "a1", "c"], query: "")
        let after = TreeSearchFixture.rows(persisted: ["a", "a1", "c"], query: "y")
        #expect(after.map(\.id) == ["a", "a1", "a1y"])
        func reduced(_ focus: String) -> String? {
            TreeInteractionReducer.rowsChanged(
                state: TreeInteractionState(focus: focus, lastInteraction: .keyboard, selection: [], expanded: ["a", "a1", "c"]),
                from: before,
                to: after
            ).focus
        }
        #expect(reduced("a1x") == "a1", "a1x 被过滤掉，最近的可见祖先是 a1，实得 \(String(describing: reduced("a1x")))")
        #expect(reduced("a2") == "a", "a2 被过滤掉，最近的可见祖先是 a")
        #expect(reduced("c1") == "a", "c1 与祖先 c 都被过滤掉，应当落到首个可见行 a")
        #expect(reduced("a1y") == "a1y", "仍可见的焦点原样保留")

        let keyed = Self.press(
            .space,
            state: TreeInteractionState(focus: "a1x", lastInteraction: .keyboard, selection: [], expansion: TreeSearchFixture.expansion(persisted: [], query: "y")),
            rows: after
        )
        #expect(keyed.state.focus == "a1", "按键时焦点仍在被过滤掉的 a1x 上，应先归约到 a1")
        #expect(keyed.state.selection == ["a1"])
    }

    @Test("右键菜单目标：选中集合里被过滤掉的 ID 不传给菜单")
    func contextMenuTargetsAreScopedToFilteredRows() {
        let visible = Set(TreeSearchFixture.rows(persisted: [], query: "y").map(\.id))
        let targets = TreeContextMenu.targets(for: "a1y", selection: ["a1y", "a2", "b"], visibleIDs: visible)
        #expect(targets == ["a1y"], "被过滤掉的 a2 / b 进了菜单目标：\(targets.sorted())")
    }

    @Test("不在搜索时：展开态与既有行为完全相同（overlay 为 nil，写回持久化集合）")
    func withoutASearchNothingChanges() {
        let expansion = TreeSearchFixture.expansion(persisted: ["a"], query: "")
        #expect(expansion.overlay == nil)
        let state = TreeInteractionState(focus: "a", lastInteraction: .keyboard, selection: [], expansion: expansion)
        let collapsed = Self.press(.left, state: state, rows: TreeSearchFixture.rows(persisted: ["a"], query: ""))
        #expect(collapsed.state.expansion.persisted.isEmpty, "不在搜索时 ← 应当直接写持久化集合")
        #expect(TreeSearch.session(from: collapsed.state.expansion, query: nil) == nil)
    }

    @Test("搜索期间的展开照样带环境动效档（Reduce Motion 分支不变）")
    func searchExpansionCarriesTheEnvironmentMotion() {
        let state = TreeInteractionState(
            focus: "a", lastInteraction: .keyboard, selection: [],
            expansion: TreeSearchFixture.expansion(persisted: [], query: "y")
        )
        for motion in MotionPresentation.allCases {
            let outcome = TreeInteractionReducer.key(
                .left, modifiers: [], state: state, rows: TreeSearchFixture.rows(persisted: [], query: "y"),
                mode: .multiple, activation: .enabled, motion: motion,
                treeIDs: { TreeJudgeFixture.treeIDs }, ancestors: TreeJudgeFixture.ancestors(of:)
            )
            #expect(outcome.expansionMotion == motion)
        }
    }
}

// MARK: - 渲染 / Rendering

nonisolated enum TreeSearchAppearance: CaseIterable, CustomTestStringConvertible, Sendable {
    case automatic
    case navigator

    var testDescription: String {
        switch self {
        case .automatic: ".automatic"
        case .navigator: ".navigator"
        }
    }

    @MainActor var style: TreeStyle {
        switch self {
        case .automatic: .automatic
        case .navigator: .navigator
        }
    }
}

@Suite("Tree 搜索渲染：过滤后的画面与手工裁剪的同形树逐像素等价；命中高亮画得出来；两种外观一致")
@MainActor
struct TreeSearchRenderTests {
    private static let minimumSignalDelta = 8
    private static let noiseTolerance = 2

    private static func expectVisiblyDifferent(
        _ a: TreePixels,
        _ b: TreePixels,
        _ comment: String,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        guard let metrics = bitmapDifferenceMetrics(a.bytes, b.bytes) else {
            #expect(
                Bool(false),
                Comment(rawValue: bitmapExpectationMessage("两张位图未渲染或长度不同。" + comment, a.bytes, b.bytes)),
                sourceLocation: sourceLocation
            )
            return
        }
        #expect(
            metrics.maxChannelDelta > Self.minimumSignalDelta,
            Comment(rawValue: bitmapExpectationMessage(
                "逐通道最大偏差 \(metrics.maxChannelDelta) ≤ \(Self.minimumSignalDelta)，不算画得不同。" + comment,
                a.bytes, b.bytes
            )),
            sourceLocation: sourceLocation
        )
    }

    private static let pruned: [TreeJudgeNode] = [
        TreeJudgeNode(id: "a", children: [
            TreeJudgeNode(id: "a1", children: [TreeJudgeNode(id: "a1y", children: nil)]),
        ]),
    ]

    @Test("searchFilter(\"y\") 画出来等于手工裁剪成 a › a1 › a1y 并展开的树", arguments: TreeSearchAppearance.allCases)
    func filteredTreeMatchesAPrunedTree(appearance: TreeSearchAppearance) {
        let filtered = TreePixels.render(
            Tree(TreeJudgeFixture.roots, children: \.children, expanded: .constant([]), selection: .constant(["a1y"])) { node in
                Text(verbatim: node.id)
            }
            .searchFilter("y", text: \.id)
            .treeStyle(appearance.style)
        )
        let pruned = TreePixels.render(
            Tree(Self.pruned, children: \.children, expanded: .constant(["a", "a1"]), selection: .constant(["a1y"])) { node in
                Text(verbatim: node.id)
            }
            .treeStyle(appearance.style)
        )
        #expect(filtered.height > 0)
        #expect(filtered.height == pruned.height, "\(appearance)：过滤后高度 \(filtered.height)px，裁剪树 \(pruned.height)px——留下的行数不对")
        expectBitmapsEquivalent(
            filtered.bytes, pruned.bytes, maxChannelDelta: Self.noiseTolerance,
            "\(appearance)：过滤后的画面与手工裁剪的树不同——过滤没接到渲染，或自动展开没生效"
        )
    }

    @Test("空搜索词画出来与不设 searchFilter 等价", arguments: TreeSearchAppearance.allCases)
    func emptyQueryRendersTheUnfilteredTree(appearance: TreeSearchAppearance) {
        func render(_ query: String?) -> TreePixels {
            let tree = Tree(TreeJudgeFixture.roots, children: \.children, expanded: .constant(["a"]), selection: .constant([])) { node in
                Text(verbatim: node.id)
            }
            if let query {
                return TreePixels.render(tree.searchFilter(query, text: \.id).treeStyle(appearance.style))
            }
            return TreePixels.render(tree.treeStyle(appearance.style))
        }
        let plain = render(nil)
        let blank = render("   ")
        #expect(plain.height == blank.height)
        expectBitmapsEquivalent(plain.bytes, blank.bytes, maxChannelDelta: Self.noiseTolerance, "\(appearance)：空搜索词改变了画面")
        #expect(render("y").height < plain.height, "\(appearance)：有搜索词时画面没变矮——正向对照失效，上一条相等判据无意义")
    }

    @Test("Text(verbatim:highlighting:) 命中时画得与普通 Text 不同；未命中 / 空词时与普通 Text 等价", arguments: [ColorScheme.light, .dark])
    func highlightedTextDrawsTheMatch(_ scheme: ColorScheme) {
        func render(_ text: Text) -> TreePixels {
            TreePixels.render(text.padding(4), scheme: scheme, width: 120)
        }
        let plain = render(Text(verbatim: "Colors"))
        let hit = render(Text(verbatim: "Colors", highlighting: "lor"))
        Self.expectVisiblyDifferent(plain, hit, "\(scheme)：命中片段没有任何视觉呈现")
        expectBitmapsEquivalent(
            plain.bytes, render(Text(verbatim: "Colors", highlighting: "zz")).bytes,
            maxChannelDelta: Self.noiseTolerance, "\(scheme)：未命中时仍画了高亮"
        )
        expectBitmapsEquivalent(
            plain.bytes, render(Text(verbatim: "Colors", highlighting: "  ")).bytes,
            maxChannelDelta: Self.noiseTolerance, "\(scheme)：空搜索词时仍画了高亮"
        )
    }

    @Test("命中高亮在两种外观的行里都画得出来，且底色不是选中底色", arguments: TreeSearchAppearance.allCases)
    func highlightShowsInBothAppearances(appearance: TreeSearchAppearance) {
        func render(highlight: String, selection: Set<String>) -> TreePixels {
            TreePixels.render(
                Tree(TreeJudgeFixture.roots, children: \.children, expanded: .constant([]), selection: .constant(selection)) { node in
                    Text(verbatim: node.id, highlighting: highlight)
                }
                .treeStyle(appearance.style)
            )
        }
        Self.expectVisiblyDifferent(render(highlight: "", selection: []), render(highlight: "b", selection: []), "\(appearance)：行里的命中片段没画出来")
        Self.expectVisiblyDifferent(
            render(highlight: "", selection: ["b"]), render(highlight: "b", selection: ["b"]),
            "\(appearance)：选中行上的命中片段被选中底色吞掉了"
        )
    }

    @Test("命中片段除了加粗还有底色：与只加粗的同一段文字画得不同", arguments: [ColorScheme.light, .dark])
    func highlightCarriesABackgroundBeyondBold(_ scheme: ColorScheme) {
        var boldOnly = AttributedString("Colors")
        let range = boldOnly.range(of: "lor")!
        boldOnly[range].inlinePresentationIntent = .stronglyEmphasized
        let bold = TreePixels.render(Text(boldOnly).padding(4), scheme: scheme, width: 120)
        let hit = TreePixels.render(Text(verbatim: "Colors", highlighting: "lor").padding(4), scheme: scheme, width: 120)
        Self.expectVisiblyDifferent(bold, hit, "\(scheme)：命中片段只有加粗、没有底色")
    }

    @Test("高亮片段落在命中的字上：左半命中与右半命中画出来不同")
    func highlightFollowsTheMatchedRange() {
        let left = TreePixels.render(Text(verbatim: "abcabz", highlighting: "abc").padding(4), width: 120)
        let right = TreePixels.render(Text(verbatim: "abcabz", highlighting: "abz").padding(4), width: 120)
        Self.expectVisiblyDifferent(left, right, "高亮画在了固定位置而不是命中片段上")
    }
}

// MARK: - 托管窗口接线 / Hosted wiring

#if os(macOS)
@MainActor
@Observable
final class TreeSearchHostedModel {
    var query: String
    var expanded: Set<String>
    var selection: Set<String> = []
    var checked: Set<String> = []

    init(query: String = "", expanded: Set<String> = []) {
        self.query = query
        self.expanded = expanded
    }
}

struct TreeSearchHostedHarness: View {
    let model: TreeSearchHostedModel
    let style: TreeStyle
    let showsCheckBoxes: TreeHostedCheckBoxes

    var body: some View {
        Tree(
            TreeJudgeFixture.roots,
            children: \.children,
            expanded: Binding(get: { self.model.expanded }, set: { self.model.expanded = $0 }),
            selection: Binding(get: { self.model.selection }, set: { self.model.selection = $0 }),
            selectionMode: .multiple,
            checked: self.showsCheckBoxes == .shown
                ? Binding(get: { self.model.checked }, set: { self.model.checked = $0 })
                : nil
        ) { node in
            Text(verbatim: node.id, highlighting: self.model.query)
        }
        .searchFilter(self.model.query, text: \.id)
        .treeStyle(self.style)
        .frame(maxHeight: .infinity, alignment: .top)
        .allowsWindowActivationEvents(true)
    }
}

@Suite("Tree 搜索接线（macOS 托管窗口 + 合成事件）：搜索期间按键不写持久化集合、清空恢复、全选 / 级联只作用于留下的行、焦点回退；两种外观逐条同一结论")
@MainActor
struct TreeSearchHostedTests {
    private static let regular = TreeRowMetrics.resolve(.regular)
    private static let pitch = Self.regular.rowHeight + Self.regular.rowSpacing
    private static let leftArrow = String(Character(UnicodeScalar(NSLeftArrowFunctionKey)!))
    private static let downArrow = String(Character(UnicodeScalar(NSDownArrowFunctionKey)!))

    private static func window(
        _ model: TreeSearchHostedModel,
        appearance: TreeHostedAppearance,
        showsCheckBoxes: TreeHostedCheckBoxes = .hidden
    ) -> HostedWindow {
        HostedWindow(
            TreeSearchHostedHarness(model: model, style: appearance.style, showsCheckBoxes: showsCheckBoxes),
            size: CGSize(width: 260, height: 400),
            scheme: .light
        )
    }

    private static func key(_ window: HostedWindow, _ code: UInt16, _ characters: String, modifiers: NSEvent.ModifierFlags = []) {
        window.sendKey(keyCode: code, characters: characters, modifiers: modifiers)
        window.settle()
    }

    @Test("第 4 / 5 行：搜索期间 ← 折叠不写宿主的 expanded；清空后回到搜索前的展开态", arguments: TreeHostedAppearance.allCases)
    func searchExpansionStaysTransient(appearance: TreeHostedAppearance) {
        let model = TreeSearchHostedModel(query: "y", expanded: ["a"])
        let window = Self.window(model, appearance: appearance)
        defer { window.close() }
        Self.key(window, 123, Self.leftArrow)
        #expect(model.expanded == ["a"], "\(appearance)：搜索期间 ← 写了宿主的 expanded：\(model.expanded.sorted())")
        Self.key(window, 125, Self.downArrow)
        Self.key(window, 49, " ")
        #expect(
            model.selection == ["a"],
            "\(appearance)：← 应当在 overlay 里折叠 a（只剩一行，↓ does nothing，Space 选中 a），实得 \(model.selection.sorted())"
        )

        model.selection = []
        model.query = ""
        window.settle()
        Self.key(window, 125, Self.downArrow)
        Self.key(window, 49, " ")
        #expect(model.expanded == ["a"], "\(appearance)：清空后宿主的 expanded 被改了：\(model.expanded.sorted())")
        #expect(model.selection == ["a1"], "\(appearance)：清空后 a 应当恢复展开（↓ 从 a 到 a1），实得选中 \(model.selection.sorted())")
    }

    @Test("第 5 行连带：清空后再搜同一个词，上一次搜索里的手动折叠不复活", arguments: TreeHostedAppearance.allCases)
    func researchingTheSameWordStartsFresh(appearance: TreeHostedAppearance) {
        let model = TreeSearchHostedModel(query: "y", expanded: [])
        let window = Self.window(model, appearance: appearance)
        defer { window.close() }
        Self.key(window, 123, Self.leftArrow)
        model.query = ""
        window.settle()
        model.query = "y"
        window.settle()
        Self.key(window, 125, Self.downArrow)
        Self.key(window, 49, " ")
        #expect(
            model.selection == ["a1"],
            "\(appearance)：重新搜 y 时 a 应当重新自动展开（↓ 从 a 到 a1），实得选中 \(model.selection.sorted())"
        )
    }

    @Test("第 6 行：搜索期间 Cmd+A 只选留下的可见行", arguments: TreeHostedAppearance.allCases)
    func selectAllUnderSearch(appearance: TreeHostedAppearance) {
        let model = TreeSearchHostedModel(query: "a1")
        let window = Self.window(model, appearance: appearance)
        defer { window.close() }
        Self.key(window, 0, "a", modifiers: .command)
        #expect(model.selection == ["a", "a1", "a1x", "a1y"], "\(appearance)：全选越出了过滤后的可见行：\(model.selection.sorted())")
    }

    @Test("第 6 行：搜索期间点父行复选框只勾留下的叶子", arguments: TreeHostedAppearance.allCases)
    func checkCascadeUnderSearch(appearance: TreeHostedAppearance) {
        let model = TreeSearchHostedModel(query: "y")
        let window = Self.window(model, appearance: appearance, showsCheckBoxes: .shown)
        defer { window.close() }
        let x = CoreSpacing.xs + Self.regular.disclosureWidth + CoreSpacing.xs + Self.regular.checkBoxGlyph / 2
        let point = CGPoint(x: x, y: Self.regular.rowHeight / 2)
        window.sendMouse(.leftMouseDown, at: point)
        window.sendMouse(.leftMouseUp, at: point)
        window.settle()
        #expect(model.checked == ["a1y"], "\(appearance)：搜索 y 时点 a 的复选框应当只勾 a1y，实得 \(model.checked.sorted())")
    }

    @Test("第 7 行：焦点行被搜索过滤掉后，下一键从最近的可见祖先出发", arguments: TreeHostedAppearance.allCases)
    func hiddenFocusFallsBackUnderSearch(appearance: TreeHostedAppearance) {
        let model = TreeSearchHostedModel(expanded: ["a", "a1"])
        let window = Self.window(model, appearance: appearance)
        defer { window.close() }
        Self.key(window, 125, Self.downArrow)
        Self.key(window, 125, Self.downArrow)
        model.query = "y"
        window.settle()
        Self.key(window, 49, " ")
        #expect(model.selection == ["a1"], "\(appearance)：焦点 a1x 被过滤掉后应当回到 a1，Space 选中 a1，实得 \(model.selection.sorted())")
    }
}
#endif
