import SwiftUI
import Testing
@testable import OhMyDesign

// MARK: - 样本 / Fixture

struct TreeJudgeNode: Identifiable, Equatable {
    let id: String
    var children: [TreeJudgeNode]?
}

enum TreeJudgeFixture {
    static let roots: [TreeJudgeNode] = [
        TreeJudgeNode(id: "a", children: [
            TreeJudgeNode(id: "a1", children: [
                TreeJudgeNode(id: "a1x", children: nil),
                TreeJudgeNode(id: "a1y", children: nil),
            ]),
            TreeJudgeNode(id: "a2", children: nil),
        ]),
        TreeJudgeNode(id: "b", children: nil),
        TreeJudgeNode(id: "c", children: [
            TreeJudgeNode(id: "c1", children: nil),
        ]),
    ]

    static let parentIDs: Set<String> = ["a", "a1", "c"]

    static var treeIDs: Set<String> {
        TreeFlatten.allIDs(Self.roots, id: \TreeJudgeNode.id, children: \TreeJudgeNode.children)
    }

    static func ancestors(of id: String) -> [String] {
        TreeFlatten.ancestorIDs(of: id, in: Self.roots, id: \TreeJudgeNode.id, children: \TreeJudgeNode.children)
    }

    static func rows(expanded: Set<String>) -> [TreeRow<String>] {
        TreeFlatten.rows(Self.roots, id: \TreeJudgeNode.id, children: \TreeJudgeNode.children, expanded: expanded)
    }

    static func node(_ id: String) -> TreeJudgeNode {
        func walk(_ nodes: [TreeJudgeNode]) -> TreeJudgeNode? {
            for node in nodes {
                if node.id == id { return node }
                if let kids = node.children, let hit = walk(kids) { return hit }
            }
            return nil
        }
        guard let hit = walk(Self.roots) else {
            fatalError("样本里没有 id = \(id) 的节点——样本被改了而判据没跟上")
        }
        return hit
    }
}

// MARK: - 展平

@Suite("Tree 展平：根算第 1 层、父指针、分支标记")
struct TreeFlattenTests {
    @Test("全折叠时只有 3 个根行，层级都是 1、父指针都是 nil")
    func collapsedTreeYieldsRootsOnly() {
        let rows = TreeJudgeFixture.rows(expanded: [])
        #expect(rows.map(\.id) == ["a", "b", "c"])
        #expect(rows.map(\.level) == [1, 1, 1], "根节点必须算第 1 层——「默认展开到第 N 层」的口径挂在这上面")
        #expect(rows.allSatisfy { $0.parent == nil })
        #expect(rows.map(\.hasChildren) == [true, false, true])
    }

    @Test("展开一层后子行带上层级与父指针")
    func expandingCarriesLevelAndParent() {
        let rows = TreeJudgeFixture.rows(expanded: ["a"])
        #expect(rows.map(\.id) == ["a", "a1", "a2", "b", "c"])
        let a1 = rows[1]
        #expect(a1.level == 2)
        #expect(a1.parent == "a")
        #expect(a1.hasChildren)
        #expect(rows[2].parent == "a")
    }

    @Test("children 是空集合的节点算叶节点，展开它也不会多出行")
    func emptyChildrenCollectionIsALeaf() {
        let data = [TreeJudgeNode(id: "empty", children: [])]
        let collapsed = TreeFlatten.rows(data, id: \TreeJudgeNode.id, children: \TreeJudgeNode.children, expanded: [])
        let expanded = TreeFlatten.rows(data, id: \TreeJudgeNode.id, children: \TreeJudgeNode.children, expanded: ["empty"])
        #expect(collapsed.count == 1)
        #expect(expanded.count == 1, "空 children 被当成父节点了——会画出一个展不开的 chevron")
        #expect(collapsed[0].hasChildren == false)
    }

    @Test("expandedIDs 以根为第 1 层：depth 1 全折叠，depth 2 只展开根层")
    func expandedIDsCountsRootAsLevelOne() {
        func ids(_ depth: Int) -> Set<String> {
            TreeFlatten.expandedIDs(TreeJudgeFixture.roots, id: \TreeJudgeNode.id, children: \TreeJudgeNode.children, toDepth: depth)
        }
        #expect(ids(1).isEmpty, "depth 1 应当全折叠（根即第 1 层），实得 \(ids(1).sorted())")
        #expect(ids(2) == ["a", "c"])
        #expect(ids(3) == ["a", "a1", "c"])
        #expect(ids(4) == ids(3), "样本只有 3 层，depth 4 不应比 depth 3 多")
        #expect(ids(0).isEmpty)
        #expect(ids(-5).isEmpty)
    }

    @Test("公开的 Tree.expandedIDs 与内部展平器同源")
    func publicEntryForwardsToTheFlattener() {
        let viaPublic = Tree<[TreeJudgeNode], String, Text>.expandedIDs(
            TreeJudgeFixture.roots, id: \TreeJudgeNode.id, children: \TreeJudgeNode.children, toDepth: 3
        )
        let viaInternal = TreeFlatten.expandedIDs(
            TreeJudgeFixture.roots, id: \TreeJudgeNode.id, children: \TreeJudgeNode.children, toDepth: 3
        )
        #expect(viaPublic == viaInternal)
    }

    @Test("免写行内容泛型的 Tree.expandedIDs 与内部展平器同源")
    func inferredPublicEntryForwardsToTheFlattener() {
        let inferred = Tree.expandedIDs(
            TreeJudgeFixture.roots, id: \TreeJudgeNode.id, children: \TreeJudgeNode.children, toDepth: 3
        )
        #expect(inferred == ["a", "a1", "c"], "实得 \(inferred.sorted())")
    }

    @Test("descendantLeafIDs 逐层下探、只收叶节点")
    func descendantLeafIDsSkipEveryParent() {
        let underA = TreeFlatten.descendantLeafIDs(
            of: TreeJudgeFixture.node("a"), id: \TreeJudgeNode.id, children: \TreeJudgeNode.children
        )
        #expect(underA == ["a1x", "a1y", "a2"], "父节点 a 的叶后代应当越过 a1 直达第 3 层，实得 \(underA)")
        #expect(Set(underA).isDisjoint(with: TreeJudgeFixture.parentIDs))
        let underLeaf = TreeFlatten.descendantLeafIDs(
            of: TreeJudgeFixture.node("b"), id: \TreeJudgeNode.id, children: \TreeJudgeNode.children
        )
        #expect(underLeaf == ["b"], "叶节点自己就是唯一的叶后代")
    }

    @Test("ancestorIDs 由近及远，根在最后")
    func ancestorIDsAreNearestFirst() {
        let chain = TreeFlatten.ancestorIDs(
            of: "a1x", in: TreeJudgeFixture.roots, id: \TreeJudgeNode.id, children: \TreeJudgeNode.children
        )
        #expect(chain == ["a1", "a"], "祖先链必须由近及远（焦点回退取第一个仍可见的），实得 \(chain)")
        #expect(TreeFlatten.ancestorIDs(of: "a", in: TreeJudgeFixture.roots, id: \TreeJudgeNode.id, children: \TreeJudgeNode.children).isEmpty)
        #expect(TreeFlatten.ancestorIDs(of: "zz", in: TreeJudgeFixture.roots, id: \TreeJudgeNode.id, children: \TreeJudgeNode.children).isEmpty)
    }
}

// MARK: - 七行行为真值表

@Suite("Tree 行为真值表：PRD FR-2 逐行")
struct TreeTruthTableTests {
    private static func leaves(of id: String) -> [String] {
        TreeFlatten.descendantLeafIDs(of: TreeJudgeFixture.node(id), id: \TreeJudgeNode.id, children: \TreeJudgeNode.children)
    }

    @Test("第 1 / 3 行：父节点可以被行选中，但永远不进勾选集合")
    func parentsAreSelectableButNeverChecked() {
        let rowIDs = Set(TreeJudgeFixture.rows(expanded: ["a", "c"]).map(\.id))
        let selection = TreeSelection.toggled("a", in: [], rowIDs: rowIDs, treeIDs: TreeJudgeFixture.treeIDs, mode: .multiple)
        #expect(selection == ["a"], "行选中是导航语义，父行照样能选")

        var checked: Set<String> = []
        for parent in TreeJudgeFixture.parentIDs.sorted() {
            checked = TreeChecking.applying(true, toLeaves: Self.leaves(of: parent), in: checked)
        }
        #expect(
            checked.intersection(TreeJudgeFixture.parentIDs).isEmpty,
            "勾选集合里混进了父 ID \(checked.intersection(TreeJudgeFixture.parentIDs).sorted())——父节点只许由后代推导"
        )
        #expect(checked == ["a1x", "a1y", "a2", "c1"])
    }

    @Test("第 2 行：点 mixed 父节点级联全选全部后代，再点一次全不选")
    func checkingAMixedParentCascadesThenClears() {
        let leaves = Self.leaves(of: "a")
        #expect(leaves.count == 3, "样本里 a 的叶后代应当有 3 个，实得 \(leaves.count)")
        let mixed: Set<String> = ["a1x"]
        let afterFirstClick = TreeChecking.applying(true, toLeaves: leaves, in: mixed)
        #expect(Set(leaves).isSubset(of: afterFirstClick), "第一次点 mixed 父节点没有级联全选，实得 \(afterFirstClick.sorted())")

        let afterSecondClick = TreeChecking.applying(false, toLeaves: leaves, in: afterFirstClick)
        #expect(
            afterSecondClick.isDisjoint(with: Set(leaves)),
            "第二次点没有全不选，残留 \(afterSecondClick.intersection(Set(leaves)).sorted())"
        )
    }

    @Test("第 2 行连带：级联不碰子树以外的勾选")
    func cascadeLeavesUnrelatedChecksAlone() {
        let outside: Set<String> = ["c1"]
        let result = TreeChecking.applying(true, toLeaves: Self.leaves(of: "a"), in: outside)
        #expect(result.contains("c1"), "级联把子树外的勾选吃掉了")
        let cleared = TreeChecking.applying(false, toLeaves: Self.leaves(of: "a"), in: result)
        #expect(cleared == outside, "取消级联后应当只剩子树外那一个，实得 \(cleared.sorted())")
    }

    @Test("第 4 行：搜索期间的展开只落 overlay，持久化 Set 一个字节都不动")
    func transientExpansionNeverWritesThePersistedSet() {
        var state = TreeExpansionState<String>(persisted: ["a"])
        state.beginTransientSession()
        state.expand("c")
        state.collapse("a")
        #expect(state.persisted == ["a"], "临时展开写进了持久化集合，实得 \(state.persisted.sorted())")
        #expect(state.effective == ["c"], "overlay 的展开 / 折叠没有叠到生效集合上，实得 \(state.effective.sorted())")
    }

    @Test("第 5 行：结束临时会话就回到搜索前的展开态")
    func endingTheTransientSessionRestoresExpansion() {
        var state = TreeExpansionState<String>(persisted: ["a"])
        state.beginTransientSession()
        state.expand("c")
        state.collapse("a")
        state.endTransientSession()
        #expect(state.effective == ["a"], "清空搜索没有恢复搜索前的展开态，实得 \(state.effective.sorted())")
        #expect(state.overlay == nil)
    }

    @Test("第 4 / 5 行的反面：没有临时会话时，展开直接落持久化")
    func withoutASessionExpansionIsPersisted() {
        var state = TreeExpansionState<String>(persisted: [])
        state.expand("a")
        #expect(state.persisted == ["a"], "生产路径（overlay == nil）下展开必须写进调用方的 Set")
        #expect(state.effective == state.persisted)
        state.collapse("a")
        #expect(state.persisted.isEmpty)
    }

    @Test("第 6 行：全选的范围是可见行，看不见的后代不会被静默勾上")
    func selectAllScopeIsTheVisibleRows() {
        let rows = TreeJudgeFixture.rows(expanded: ["c"])
        #expect(rows.map(\.id) == ["a", "b", "c", "c1"])
        let selection = TreeSelection.selectingAll(in: [], rowIDs: rows.map(\.id))
        #expect(selection.count == 4, "全选后应当恰好是 4 个可见行，实得 \(selection.count) 个：\(selection.sorted())")
        #expect(!selection.contains("a1"), "全选把折叠起来看不见的 a1 也勾上了")
        #expect(!selection.contains("a1x"))
    }

    @Test("第 7 行：焦点节点被隐藏时移到最近的仍可见祖先；无祖先则移到首个可见行")
    func hiddenFocusFallsBackToTheNearestVisibleAncestor() {
        let ancestors = TreeFlatten.ancestorIDs(
            of: "a1x", in: TreeJudgeFixture.roots, id: \TreeJudgeNode.id, children: \TreeJudgeNode.children
        )
        let a1Visible = TreeJudgeFixture.rows(expanded: ["a"])
        #expect(
            TreeFocusing.reconciled("a1x", visibleRows: a1Visible, ancestorsOfFocus: ancestors) == "a1",
            "a1 仍可见时焦点应当落在 a1（最近的），而不是更远的 a"
        )
        let rootsOnly = TreeJudgeFixture.rows(expanded: [])
        #expect(
            TreeFocusing.reconciled("a1x", visibleRows: rootsOnly, ancestorsOfFocus: ancestors) == "a",
            "a1 也被折叠掉时应当继续往上找到 a"
        )
        #expect(
            TreeFocusing.reconciled("zz", visibleRows: rootsOnly, ancestorsOfFocus: []) == "a",
            "没有任何可见祖先时应当落到首个可见行"
        )
        #expect(TreeFocusing.reconciled("a", visibleRows: rootsOnly, ancestorsOfFocus: []) == "a")
        #expect(TreeFocusing.reconciled("a", visibleRows: [TreeRow<String>](), ancestorsOfFocus: []) == nil)
    }

    @Test("单选 / 多选的选中归约：单选替换、多选逐项切换，数据外的 ID 原样保留")
    func selectionReducerHonoursTheMode() {
        let rowIDs: Set<String> = ["a", "b", "c"]
        let treeIDs = TreeJudgeFixture.treeIDs
        func toggled(_ id: String, _ selection: Set<String>, _ mode: TreeSelectionMode) -> Set<String> {
            TreeSelection.toggled(id, in: selection, rowIDs: rowIDs, treeIDs: treeIDs, mode: mode)
        }
        #expect(toggled("b", ["a"], .single) == ["b"])
        #expect(toggled("a", ["a"], .single).isEmpty, "单选允许空选")
        #expect(toggled("b", ["a"], .multiple) == ["a", "b"])
        #expect(toggled("a", ["a", "b"], .multiple) == ["b"])
        #expect(
            toggled("b", ["outside"], .single) == ["outside", "b"],
            "不在数据里的 ID 必须原样保留——组件永不增删它们"
        )
        #expect(toggled("zz", ["a"], .multiple) == ["a"], "不在可见行里的 ID 不可被选上")
    }

    @Test("单选：已选项被折叠隐藏后再选另一行，隐藏的那个也被替换掉，不会留下两个选中")
    func singleSelectionReplacesCollapsedSelections() {
        let collapsedRows = Set(TreeJudgeFixture.rows(expanded: []).map(\.id))
        #expect(!collapsedRows.contains("a1x"), "样本前提变了：这条判据要的是「a1x 在数据里但不可见」")
        #expect(TreeJudgeFixture.treeIDs.contains("a1x"))
        let result = TreeSelection.toggled(
            "b", in: ["a1x", "outside"], rowIDs: collapsedRows, treeIDs: TreeJudgeFixture.treeIDs, mode: .single
        )
        #expect(result == ["b", "outside"], "单选模式下留下了被折叠的旧选中项，实得 \(result.sorted())")
    }

    @Test("allIDs 收齐整棵树的每个节点，与折叠状态无关")
    func allIDsCoverEveryNode() {
        #expect(TreeJudgeFixture.treeIDs == ["a", "a1", "a1x", "a1y", "a2", "b", "c", "c1"])
    }

    @Test("生效焦点：焦点行被折叠隐藏后归约到最近的可见祖先；无焦点时按初始焦点规则")
    func effectiveFocusReconcilesAHiddenFocus() {
        func effective(_ focus: String?, expanded: Set<String>, selection: Set<String> = []) -> String? {
            TreeFocusing.effective(
                focus,
                visibleRows: TreeJudgeFixture.rows(expanded: expanded),
                selection: selection,
                ancestors: TreeJudgeFixture.ancestors(of:)
            )
        }
        #expect(effective("a1x", expanded: ["a1", "c"]) == "a", "a 折叠后 a1x 不可见，焦点应当回到 a")
        #expect(effective("a1x", expanded: ["a"]) == "a1", "a1 仍可见时应当落在最近的 a1")
        #expect(effective("a1x", expanded: ["a", "a1"]) == "a1x", "焦点可见时原样保留")
        #expect(effective(nil, expanded: ["a"], selection: ["a2"]) == "a2", "无焦点时走初始焦点规则")
        #expect(effective(nil, expanded: []) == "a")
    }

    @Test("焦点环只在容器有键盘焦点、且最近一次交互来自键盘时显示")
    func focusRingNeedsKeyboardInteraction() {
        #expect(TreeFocusing.showsRing(containerFocused: true, lastInteraction: .keyboard))
        #expect(!TreeFocusing.showsRing(containerFocused: true, lastInteraction: .pointer), "点击也画出了焦点环")
        #expect(!TreeFocusing.showsRing(containerFocused: false, lastInteraction: .keyboard), "容器失焦后焦点环还在")
        #expect(TreeInteraction.pointer != TreeInteraction.keyboard)
    }

    @Test("初始焦点：无选中落首行，有选中落可见顺序里第一个被选中的行")
    func initialFocusFollowsTheSelection() {
        let rows = TreeJudgeFixture.rows(expanded: ["a"])
        #expect(TreeFocusing.initialFocus(rows: rows, selection: []) == "a")
        #expect(TreeFocusing.initialFocus(rows: rows, selection: ["a2"]) == "a2")
        #expect(
            TreeFocusing.initialFocus(rows: rows, selection: ["b", "a2"]) == "a2",
            "多选下应当落在**可见顺序里第一个**被选中的行（a2 在 b 之前），不是集合的任意一个"
        )
        #expect(TreeFocusing.initialFocus(rows: rows, selection: ["zz"]) == "a", "选中项不可见时退回首行")
        #expect(TreeFocusing.initialFocus(rows: [TreeRow<String>](), selection: []) == nil)
    }
}

// MARK: - 键盘

@Suite("Tree 键盘：W3C ARIA Treeview 逐键")
struct TreeKeyboardTests {
    private static let expanded: Set<String> = ["a", "a1", "c"]
    private static var rows: [TreeRow<String>] { TreeJudgeFixture.rows(expanded: Self.expanded) }

    private static func act(
        _ key: TreeKey,
        _ modifiers: EventModifiers = [],
        focus: String,
        expanded: Set<String> = Self.expanded,
        mode: TreeSelectionMode = .multiple
    ) -> TreeKeyAction<String> {
        TreeKeyboard.action(
            for: key,
            modifiers: modifiers,
            rows: TreeJudgeFixture.rows(expanded: expanded),
            focus: focus,
            expanded: expanded,
            mode: mode
        )
    }

    @Test("样本的可见行序列就是判据的坐标系")
    func fixtureRowOrderIsWhatTheContractAssumes() {
        #expect(Self.rows.map(\.id) == ["a", "a1", "a1x", "a1y", "a2", "b", "c", "c1"])
    }

    @Test("↓ / ↑ 只移动焦点，不改展开态、不改选择")
    func arrowsMoveFocusOnly() {
        #expect(Self.act(.down, focus: "a") == .moveFocus("a1"))
        #expect(Self.act(.up, focus: "a1") == .moveFocus("a"))
        #expect(Self.act(.down, focus: "a1y") == .moveFocus("a2"), "↓ 要跨出子树回到父级的下一个兄弟")
    }

    @Test("↓ 在最后一行、↑ 在第一行都是 does nothing")
    func arrowsStopAtTheEnds() {
        #expect(Self.act(.down, focus: "c1") == .doNothing)
        #expect(Self.act(.up, focus: "a") == .doNothing)
    }

    @Test("macOS 真 HID 给方向键带的 .numericPad | .function 不能被读成「按了修饰键」")
    func hardwareFlagsDoNotLookLikeModifiers() {
        let macArrowFlags = EventModifiers(rawValue: 96)
        #expect(
            !macArrowFlags.isEmpty,
            "前提没了：macOS 真 HID 方向键带的 .numericPad | .function（rawValue 96）若是空集，下面那条判据不再有意义"
        )
        #expect(TreeKeyboard.selectionModifiers(macArrowFlags).isEmpty, "96 里有非选择位没被剥掉")
        #expect(TreeKeyboard.selectionModifiers([.numericPad]).isEmpty)
        #expect(TreeKeyboard.selectionModifiers([.capsLock]).isEmpty)
        #expect(TreeKeyboard.selectionModifiers(macArrowFlags.union(.shift)) == .shift)
        #expect(
            Self.act(.down, macArrowFlags, focus: "a") == .moveFocus("a1"),
            "带硬件位的 ↓ 被当成了组合键——macOS 上方向键会整条失效（实测过一次）"
        )
        #expect(Self.act(.right, macArrowFlags, focus: "a2") == .doNothing)
    }

    @Test("带 command / option 的方向键交回系统")
    func systemModifiersAreLeftAlone() {
        #expect(Self.act(.down, [.command], focus: "a") == .unhandled)
        #expect(Self.act(.left, [.option], focus: "a") == .unhandled)
        #expect(Self.act(.home, [.control], focus: "a") == .unhandled)
        #expect(Self.act(.space, [.shift], focus: "a") == .unhandled, "Shift+Space（连续区间）已登记为 Out of Scope")
    }

    @Test("→ 三分支：折叠父节点展开（焦点不动）")
    func rightOnAClosedParentExpands() {
        #expect(Self.act(.right, focus: "c", expanded: ["a", "a1"]) == .expand("c"))
    }

    @Test("→ 三分支：已展开的父节点把焦点移到首个子节点")
    func rightOnAnOpenParentMovesToFirstChild() {
        #expect(Self.act(.right, focus: "a") == .moveFocus("a1"))
        #expect(Self.act(.right, focus: "a1") == .moveFocus("a1x"))
    }

    @Test("→ 三分支：叶节点上 does nothing")
    func rightOnALeafDoesNothing() {
        #expect(Self.act(.right, focus: "a1x") == .doNothing)
        #expect(Self.act(.right, focus: "b") == .doNothing)
    }

    @Test("← 三分支：已展开的父节点折叠")
    func leftOnAnOpenParentCollapses() {
        #expect(Self.act(.left, focus: "a1") == .collapse("a1"))
    }

    @Test("← 三分支：子级的叶 / 折叠节点把焦点移到父节点")
    func leftOnAChildLeafMovesToParent() {
        #expect(Self.act(.left, focus: "a1x") == .moveFocus("a1"))
        #expect(Self.act(.left, focus: "a2") == .moveFocus("a"))
        #expect(
            Self.act(.left, focus: "c1", expanded: ["c"]) == .moveFocus("c"),
            "折叠中的子级父节点也走这一支"
        )
    }

    @Test("← 三分支：根级的叶 / 折叠节点 does nothing——漏这一支会在根上误移焦点")
    func leftOnARootLevelLeafDoesNothing() {
        #expect(Self.act(.left, focus: "b") == .doNothing)
        #expect(Self.act(.left, focus: "c", expanded: ["a", "a1"]) == .doNothing)
    }

    @Test("Home 到首行；End 到最后一个**可聚焦**（即可见）行，不是数据里的最后一个")
    func homeAndEndUseTheVisibleRows() {
        #expect(Self.act(.home, focus: "a2") == .moveFocus("a"))
        let partiallyExpanded: Set<String> = ["a", "a1"]
        let visible = TreeJudgeFixture.rows(expanded: partiallyExpanded).map(\.id)
        #expect(visible.last == "c", "样本前提变了：这条判据要的是「数据末节点 c1 不可见」")
        #expect(
            Self.act(.end, focus: "a", expanded: partiallyExpanded) == .moveFocus("c"),
            "End 落到了不可见的节点上——原文限定是 last node that is focusable"
        )
    }

    @Test("Space 切换焦点行的选中态；Enter 激活，两者分开")
    func spaceSelectsAndEnterActivates() {
        #expect(Self.act(.space, focus: "a1x") == .toggleSelection("a1x"))
        #expect(Self.act(.enter, focus: "a1x") == .activate("a1x"))
        #expect(Self.act(.space, focus: "a", mode: .single) == .toggleSelection("a"))
        #expect(Self.act(.enter, focus: "a", mode: .single) == .activate("a"))
    }

    @Test("Shift+↑ / ↓ 移焦并切换目标选中态——只在多选下；单选下退化成纯移焦")
    func shiftArrowsTogglesOnlyInMultipleMode() {
        #expect(Self.act(.down, [.shift], focus: "a") == .moveFocusAndToggleSelection("a1"))
        #expect(Self.act(.up, [.shift], focus: "a1") == .moveFocusAndToggleSelection("a"))
        #expect(
            Self.act(.down, EventModifiers(rawValue: 96).union(.shift), focus: "a") == .moveFocusAndToggleSelection("a1"),
            "Shift+↓ 在 macOS 真 HID 的 mods（96 | shift）下失效"
        )
        #expect(Self.act(.down, [.shift], focus: "a", mode: .single) == .moveFocus("a1"))
    }

    @Test("Ctrl / Cmd + A 全选可见行——只在多选下；其它字符键一律交回系统")
    func selectAllIsMultipleModeOnly() {
        #expect(Self.act(.character("a"), [.control], focus: "a") == .selectAllVisible)
        #expect(Self.act(.character("A"), [.command], focus: "a") == .selectAllVisible)
        #expect(Self.act(.character("a"), [.control], focus: "a", mode: .single) == .unhandled)
        #expect(Self.act(.character("a"), focus: "a") == .unhandled)
        #expect(
            Self.act(.character("g"), focus: "a") == .unhandled,
            "type-ahead 未实现（组件不持有节点文案），必须把键交回系统而不是吞掉"
        )
        #expect(Self.act(.character("\t"), focus: "a") == .unhandled)
    }

    @Test("焦点落在可见行之外时整条通路交回系统，不猜")
    func focusOutsideTheVisibleRowsIsUnhandled() {
        #expect(Self.act(.down, focus: "zz") == .unhandled)
        #expect(Self.act(.space, focus: "zz") == .unhandled)
    }

    @Test("KeyEquivalent → TreeKey 的映射覆盖契约里的每一个键")
    func keyMappingCoversTheContract() {
        #expect(TreeKeyboard.key(for: .upArrow) == .up)
        #expect(TreeKeyboard.key(for: .downArrow) == .down)
        #expect(TreeKeyboard.key(for: .leftArrow) == .left)
        #expect(TreeKeyboard.key(for: .rightArrow) == .right)
        #expect(TreeKeyboard.key(for: .home) == .home)
        #expect(TreeKeyboard.key(for: .end) == .end)
        #expect(TreeKeyboard.key(for: .space) == .space)
        #expect(TreeKeyboard.key(for: .return) == .enter)
        #expect(TreeKeyboard.key(for: KeyEquivalent("g")) == .character("g"))
        #expect(TreeKeyboard.key(for: .tab) == .character("\t"))
    }

    @Test("TreeKeyAction 的各取值两两不等——否则上面每一条 == 判据都成自反")
    func everyActionValueIsPairwiseDistinct() {
        let values: [TreeKeyAction<String>] = [
            .moveFocus("a"), .moveFocus("b"),
            .moveFocusAndToggleSelection("a"),
            .expand("a"), .collapse("a"),
            .toggleSelection("a"), .activate("a"),
            .selectAllVisible, .doNothing, .unhandled,
        ]
        var collisions: [String] = []
        for (i, lhs) in values.enumerated() {
            for (j, rhs) in values.enumerated() where i < j {
                if lhs == rhs { collisions.append("\(i)/\(j) → \(lhs)") }
            }
        }
        #expect(collisions.isEmpty, "有 \(collisions.count) 对取值相等：\(collisions)")
        #expect(values.count == 10, "取值面被改小了，实得 \(values.count) 个")
        for value in values {
            #expect(value == value, "自反性都不成立，Equatable 被改坏了")
        }
    }

    @Test("TreeKey 与 TreeSelectionMode 的各取值两两不等")
    func everyKeyAndModeValueIsPairwiseDistinct() {
        let keys: [TreeKey] = [.up, .down, .left, .right, .home, .end, .space, .enter, .character("g"), .character("h")]
        for (i, lhs) in keys.enumerated() {
            for (j, rhs) in keys.enumerated() where i < j {
                #expect(lhs != rhs, "TreeKey 的第 \(i) / \(j) 个取值相等：\(lhs)")
            }
        }
        let modes = TreeSelectionMode.allCases
        #expect(modes.count == 2, "选择模式数变了，实得 \(modes.count)")
        #expect(modes[0] != modes[1], "两个选择模式相等——按模式分叉的判据全部失效")
    }
}

// MARK: - 递归逐层重施样式

@Suite("Tree 递归的每一层都重施 DisclosureGroup 样式")
struct TreeNestedStyleTests {
    private static var branchBody: String {
        String(reflecting: TreeBranch<[TreeJudgeNode], String, Text>.Body.self)
    }

    @Test("嵌套的 TreeBranch 被 TreeNestedStyle 包住——DisclosureGroupStyle 在 configuration.content 内会被重置回 .automatic")
    func nestedBranchIsWrappedInTheStyleModifier() {
        let branch = String(reflecting: TreeBranch<[TreeJudgeNode], String, Text>.self)
        let expected = "SwiftUI.ModifiedContent<\(branch), OhMyDesign.TreeNestedStyle>"
        #expect(
            Self.branchBody.contains(expected),
            """
            递归层没有重施样式：body 的静态类型里找不到 \(expected)。
            失效方向是静默的——不加也能编译、也能展开，只是第 2 层起 chevron 与缩进悄悄换成系统的。
            实得类型串：\(Self.branchBody)
            """
        )
    }

    @Test("同一个样式也施在根层")
    func theRootAppliesTheStyleToo() {
        let treeBody = String(reflecting: Tree<[TreeJudgeNode], String, Text>.Body.self)
        #expect(
            treeBody.contains("OhMyDesign.TreeNestedStyle"),
            "根层没有施样式，第 1 层就会是系统外观。实得类型串：\(treeBody)"
        )
    }

    @Test("TreeNestedStyle 施的确实是 TreeDisclosureGroupStyle")
    func theModifierAppliesTreesOwnStyle() {
        let modifierBody = String(reflecting: TreeNestedStyle.Body.self)
        #expect(
            modifierBody.contains("TreeDisclosureGroupStyle"),
            "TreeNestedStyle 施的不是 Tree 自己的样式。实得类型串：\(modifierBody)"
        )
    }
}

// MARK: - 无障碍

@Suite("Tree 行的无障碍取值")
struct TreeAccessibilityTests {
    @Test("展开态的 accessibilityValue 逐态映射——自绘 Button 不会被系统自动播报，这一层是唯一来源")
    func expansionValueMapsBothStates() {
        #expect(TreeRowAccessibility.expansionValueKey(isExpanded: true) == "Expanded")
        #expect(TreeRowAccessibility.expansionValueKey(isExpanded: false) == "Collapsed")
        #expect(
            TreeRowAccessibility.expansionValueKey(isExpanded: true)
                != TreeRowAccessibility.expansionValueKey(isExpanded: false),
            "两态取到同一个 key——播报永远只有一种说法"
        )
    }

    @Test("chevron 的 accessibilityLabel 说的是动作而不是状态")
    func chevronLabelNamesTheAction() {
        #expect(TreeRowAccessibility.chevronLabelKey(isExpanded: true) == "Collapse")
        #expect(TreeRowAccessibility.chevronLabelKey(isExpanded: false) == "Expand")
    }

    @Test("选中的行带 isSelected trait，未选中的不带")
    func traitsCarryIsSelectedOnlyWhenSelected() {
        #expect(TreeRowAccessibility.traits(isSelected: true).contains(.isSelected))
        #expect(!TreeRowAccessibility.traits(isSelected: false).contains(.isSelected))
    }

    @Test("四个 a11y key 都在模块的 Localizable.strings 里——漏登记时播报会退成裸 key")
    func everyKeyIsRegisteredInTheStringsCatalog() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let url = repoRoot.appendingPathComponent("Sources/OhMyDesign/Resources/en.lproj/Localizable.strings")
        let text = try String(contentsOf: url, encoding: .utf8)
        let keys = [
            TreeRowAccessibility.expandedKey,
            TreeRowAccessibility.collapsedKey,
            TreeRowAccessibility.expandActionKey,
            TreeRowAccessibility.collapseActionKey,
        ]
        #expect(keys.count == 4)
        let missing = keys.filter { !text.contains("\"\($0)\" = ") }
        #expect(missing.isEmpty, "Localizable.strings 里缺这些 key：\(missing)")
    }
}

// MARK: - 动效台账交叉核对

@Suite("Tree 动效：台账登记与 Reduce Motion 门控")
struct TreeMotionTests {
    @Test("Tree 在 Reduce Motion 策略台账里登记为 gated")
    func treeIsRegisteredAsGated() {
        #expect(
            CoreMotionTokenDisciplineGuard.ledger["Components/Tree/Tree.swift"] == .gated,
            "Tree 的 Reduce Motion 策略没登记——那条链路失去机器兜底"
        )
    }

    @Test("chevron 旋转这个调用点在位移台账里")
    func chevronRotationIsRegistered() {
        let key = "Components/Tree/Tree.swift|rotationEffect(.degrees(self.chevronRotation(isExpanded: isExpanded)))"
        #expect(
            CoreMotionTokenDisciplineGuard.transformLedger[key] != nil,
            "动效台账里找不到 Tree 的 rotationEffect 调用点键「\(key)」——改了实参就要同步台账"
        )
    }

    @Test("展开 / 折叠的曲线：animated 走 reveal，resting 退成同时长 easeInOut，hidden 不补间")
    func expansionAnimationHonoursReduceMotion() {
        #expect(CoreMotionToken.treeExpansion(for: .hidden) == nil, "hidden 下展开仍在补间")
        let resting = CoreMotionToken.treeExpansion(for: .resting)
        #expect(
            resting == .easeInOut(duration: CoreMotionToken.reveal.duration),
            "resting 下应当退成 reveal 同时长的 easeInOut（与 CoreDisclosureGroupStyle 同一口径），实得 \(String(describing: resting))"
        )
        #expect(resting != CoreMotionToken.reveal.animation, "resting 下仍是 animated 的 smooth 曲线")
        #expect(CoreMotionToken.treeExpansion(for: .animated) == CoreMotionToken.reveal.animation)
    }

    @Test("Reduce Motion 下 chevron 不补间（reveal 的 transformAnimation 为 nil）")
    func revealIsSilentUnderReduceMotion() {
        #expect(CoreMotionToken.reveal.transformAnimation(for: .resting) == nil)
        #expect(CoreMotionToken.reveal.transformAnimation(for: .hidden) == nil)
        #expect(CoreMotionToken.reveal.transformAnimation(for: .animated) != nil)
    }
}

// MARK: - 交互归约

@Suite("Tree 交互归约：按键 / 点击 / 获焦 / 可见行变化 →（焦点、交互来源、选中、展开、动效档）")
struct TreeInteractionReducerTests {
    private static func state(
        focus: String?,
        lastInteraction: TreeInteraction = .pointer,
        selection: Set<String> = [],
        expanded: Set<String> = []
    ) -> TreeInteractionState<String> {
        TreeInteractionState(focus: focus, lastInteraction: lastInteraction, selection: selection, expanded: expanded)
    }

    private static func press(
        _ key: TreeKey,
        _ state: TreeInteractionState<String>,
        modifiers: EventModifiers = [],
        mode: TreeSelectionMode = .multiple,
        activation: TreeActivation = .enabled,
        motion: MotionPresentation = .animated
    ) -> TreeInteractionOutcome<String> {
        TreeInteractionReducer.key(
            key,
            modifiers: modifiers,
            state: state,
            rows: TreeJudgeFixture.rows(expanded: state.expanded),
            mode: mode,
            activation: activation,
            motion: motion,
            treeIDs: { TreeJudgeFixture.treeIDs },
            ancestors: TreeJudgeFixture.ancestors(of:)
        )
    }

    @Test("焦点行已被折叠隐藏时，按键先归约到最近的可见祖先再执行——不归约就整条键盘通路交回系统")
    func aHiddenFocusIsReducedBeforeTheKey() {
        let outcome = Self.press(.down, Self.state(focus: "a1x"))
        #expect(outcome.result == .handled, "焦点被隐藏后按键被交回系统——键盘层整条失效")
        #expect(outcome.state.focus == "b", "a1x 被折叠进 a 之后，↓ 应当从 a 走到 b，实得 \(String(describing: outcome.state.focus))")
    }

    @Test("首键到达时还没有焦点：按初始焦点规则解析后再执行这一键")
    func theFirstKeyResolvesTheInitialFocus() {
        let outcome = Self.press(.down, Self.state(focus: nil, selection: ["b"]))
        #expect(outcome.result == .handled)
        #expect(outcome.state.focus == "c", "初始焦点应落在已选的 b，↓ 之后到 c，实得 \(String(describing: outcome.state.focus))")
    }

    @Test("被接住的键把交互来源置为键盘；交回系统的键不动它")
    func handledKeysMarkTheInteractionAsKeyboard() {
        let moved = Self.press(.down, Self.state(focus: "a"))
        #expect(moved.state.lastInteraction == .keyboard, "按键被接住后交互来源仍是 pointer——焦点环不会出现")
        let stuck = Self.press(.up, Self.state(focus: "a"))
        #expect(stuck.result == .handled)
        #expect(stuck.state.lastInteraction == .keyboard, "does nothing 也是被接住的键")
        let ignored = Self.press(.character("g"), Self.state(focus: "a"))
        #expect(ignored.result == .ignored)
        #expect(ignored.state.lastInteraction == .pointer, "交回系统的键不应让焦点环出现")
    }

    @Test("键盘与点击的展开都带上环境的动效档，不自己挑曲线")
    func expansionCarriesTheEnvironmentMotion() {
        for motion in MotionPresentation.allCases {
            let key = Self.press(.right, Self.state(focus: "a"), motion: motion)
            #expect(key.state.expanded == ["a"])
            #expect(key.expansionMotion == motion, "→ 展开时动效档应为 \(motion)，实得 \(String(describing: key.expansionMotion))")
            let collapse = Self.press(.left, Self.state(focus: "a", expanded: ["a"]), motion: motion)
            #expect(collapse.state.expanded.isEmpty)
            #expect(collapse.expansionMotion == motion)
            let pointer = TreeInteractionReducer.pointerExpansion(
                "a", to: .expanded, state: Self.state(focus: nil, lastInteraction: .keyboard), motion: motion
            )
            #expect(pointer.state.expanded == ["a"])
            #expect(pointer.expansionMotion == motion, "点 chevron 展开时动效档应为 \(motion)")
        }
        #expect(Self.press(.down, Self.state(focus: "a")).expansionMotion == nil, "没改展开态却带了动效档")
    }

    @Test("Enter：有 onActivate 时激活焦点行、不改选中；没有时交回系统")
    func enterActivatesOnlyWhenThereIsAHandler() {
        let enabled = Self.press(.enter, Self.state(focus: "b"))
        #expect(enabled.result == .handled)
        #expect(enabled.activated == "b")
        #expect(enabled.state.selection.isEmpty)
        let disabled = Self.press(.enter, Self.state(focus: "b"), activation: .disabled)
        #expect(disabled.result == .ignored)
        #expect(disabled.activated == nil)
    }

    @Test("点行、点 chevron、点复选框都把交互来源置回 pointer")
    func pointerInteractionsClearTheKeyboardMark() {
        let keyboard = Self.state(focus: "a", lastInteraction: .keyboard)
        let selected = TreeInteractionReducer.pointerSelect(
            "b", state: keyboard, rowIDs: ["a", "b", "c"], mode: .single, treeIDs: { TreeJudgeFixture.treeIDs }
        )
        #expect(selected.lastInteraction == .pointer)
        #expect(selected.focus == "b")
        #expect(selected.selection == ["b"])
        let chevron = TreeInteractionReducer.pointerExpansion("a", to: .expanded, state: keyboard, motion: .animated)
        #expect(chevron.state.lastInteraction == .pointer)
        #expect(TreeInteractionReducer.pointerCheck(state: keyboard).lastInteraction == .pointer)
    }

    @Test("非点击导致的获焦（Tab 进入）置为键盘交互并解析焦点行；点击导致的获焦不动状态")
    func focusEnteredByKeyboardShowsTheRing() {
        let before = Self.state(focus: nil, selection: ["b"])
        let tabbed = TreeInteractionReducer.focusEntered(
            via: .keyboard, state: before, rows: TreeJudgeFixture.rows(expanded: []), ancestors: TreeJudgeFixture.ancestors(of:)
        )
        #expect(tabbed.lastInteraction == .keyboard)
        #expect(tabbed.focus == "b", "Tab 进入后焦点应落在已选行")
        #expect(TreeFocusing.showsRing(containerFocused: true, lastInteraction: tabbed.lastInteraction))
        let clicked = TreeInteractionReducer.focusEntered(
            via: .pointer, state: before, rows: TreeJudgeFixture.rows(expanded: []), ancestors: TreeJudgeFixture.ancestors(of:)
        )
        #expect(clicked == before)
    }

    @Test("可见行变化后焦点归约只用变化前的行求祖先，不回头遍历数据")
    func rowsChangedReducesFromTheOldRows() {
        let old = TreeJudgeFixture.rows(expanded: ["a", "a1"])
        let collapsedA = TreeJudgeFixture.rows(expanded: [])
        let collapsedA1 = TreeJudgeFixture.rows(expanded: ["a"])
        let focused = Self.state(focus: "a1x", expanded: ["a", "a1"])
        #expect(TreeInteractionReducer.rowsChanged(state: focused, from: old, to: collapsedA).focus == "a")
        #expect(TreeInteractionReducer.rowsChanged(state: focused, from: old, to: collapsedA1).focus == "a1")
        #expect(TreeInteractionReducer.rowsChanged(state: Self.state(focus: nil), from: old, to: collapsedA).focus == nil)
        #expect(TreeFocusing.ancestors(of: "a1x", in: old) == ["a1", "a"])
    }
}

// MARK: - 折叠子树不被读取

nonisolated final class TreeChildrenReadLog {
    var reads: [String: Int] = [:]

    func reads(of ids: [String]) -> Int {
        ids.reduce(0) { $0 + self.reads[$1, default: 0] }
    }
}

nonisolated struct TreeCountingNode: Identifiable {
    let id: String
    let log: TreeChildrenReadLog
    let kids: [TreeCountingNode]?

    var children: [TreeCountingNode]? {
        self.log.reads[self.id, default: 0] += 1
        return self.kids
    }

    @MainActor static func roots(log: TreeChildrenReadLog) -> [TreeCountingNode] {
        func convert(_ node: TreeJudgeNode) -> TreeCountingNode {
            TreeCountingNode(id: node.id, log: log, kids: node.children?.map(convert))
        }
        return TreeJudgeFixture.roots.map(convert)
    }
}

@Suite("Tree 惰性：渲染 / 多选 / 按键不读折叠子树的 children，只有单选点击才遍历整树")
@MainActor
struct TreeLazinessTests {
    private static let hiddenWhenOnlyAIsExpanded = ["a1x", "a1y", "c1"]

    private static func render(_ log: TreeChildrenReadLog, mode: TreeSelectionMode) -> CGImage? {
        let renderer = ImageRenderer(
            content: Tree(
                TreeCountingNode.roots(log: log),
                children: \.children,
                expanded: .constant(["a"]),
                selection: .constant(["b"]),
                selectionMode: mode
            ) { node in
                Text(verbatim: node.id)
            }
            .frame(width: 260)
        )
        return renderer.cgImage
    }

    @Test("渲染：只读可见行的 children，折叠在 a1 / c 里的节点一次都不读", arguments: TreeSelectionMode.allCases)
    func renderingNeverReadsCollapsedSubtrees(mode: TreeSelectionMode) {
        let log = TreeChildrenReadLog()
        #expect(Self.render(log, mode: mode) != nil, "没渲染出来，下面的计数无意义")
        #expect(log.reads["a", default: 0] > 0, "可见的父行 a 一次都没读——渲染没有走到数据")
        #expect(
            log.reads(of: Self.hiddenWhenOnlyAIsExpanded) == 0,
            "渲染读了折叠子树：\(log.reads.filter { Self.hiddenWhenOnlyAIsExpanded.contains($0.key) })"
        )
    }

    @Test("按键：除单选下切换选中的键外，一律不求整树 ID、不读折叠子树")
    func keysNeverWalkTheWholeTree() {
        let log = TreeChildrenReadLog()
        let roots = TreeCountingNode.roots(log: log)
        var treeIDEvaluations = 0
        let rows = TreeFlatten.rows(roots, id: \.id, children: \.children, expanded: ["a"])
        log.reads = [:]
        func press(_ key: TreeKey, _ modifiers: EventModifiers = [], focus: String, mode: TreeSelectionMode) {
            _ = TreeInteractionReducer.key(
                key,
                modifiers: modifiers,
                state: TreeInteractionState(focus: focus, lastInteraction: .pointer, selection: [], expanded: ["a"]),
                rows: rows,
                mode: mode,
                activation: .enabled,
                motion: .animated,
                treeIDs: {
                    treeIDEvaluations += 1
                    return TreeFlatten.allIDs(roots, id: \.id, children: \.children)
                },
                ancestors: { TreeFlatten.ancestorIDs(of: $0, in: roots, id: \.id, children: \.children) }
            )
        }
        for mode in TreeSelectionMode.allCases {
            for key: TreeKey in [.down, .up, .right, .left, .home, .end, .enter] {
                press(key, focus: "a", mode: mode)
                press(key, focus: "a1", mode: mode)
            }
        }
        press(.space, focus: "b", mode: .multiple)
        press(.down, .shift, focus: "a", mode: .multiple)
        press(.character("a"), .command, focus: "a", mode: .multiple)
        #expect(treeIDEvaluations == 0, "非单选切换的按键求了整树 ID \(treeIDEvaluations) 次")
        #expect(log.reads(of: Self.hiddenWhenOnlyAIsExpanded) == 0, "按键路径读了折叠子树：\(log.reads)")
        press(.space, focus: "b", mode: .single)
        #expect(treeIDEvaluations == 1, "单选下 Space 应当求一次整树 ID（替换被折叠的旧选中）")
        #expect(log.reads(of: Self.hiddenWhenOnlyAIsExpanded) > 0, "单选切换没有遍历整树——被折叠的旧选中不会被替换")
    }

    @Test("点击：多选不求整树 ID，单选才求")
    func pointerSelectWalksTheTreeOnlyInSingleMode() {
        var evaluations = 0
        let state = TreeInteractionState<String>(focus: nil, lastInteraction: .pointer, selection: [], expanded: [])
        let treeIDs = {
            evaluations += 1
            return TreeJudgeFixture.treeIDs
        }
        _ = TreeInteractionReducer.pointerSelect("b", state: state, rowIDs: ["a", "b", "c"], mode: .multiple, treeIDs: treeIDs)
        #expect(evaluations == 0, "多选点击求了整树 ID")
        _ = TreeInteractionReducer.pointerSelect("b", state: state, rowIDs: ["a", "b", "c"], mode: .single, treeIDs: treeIDs)
        #expect(evaluations == 1)
    }
}

// MARK: - 托管窗口接线

#if os(macOS)
@MainActor
final class TreeHostedLog {
    var expanded: Set<String> = []
    var selection: Set<String> = []
    var animations: [Animation?] = []
}

struct TreeHostedHarness: View {
    let log: TreeHostedLog
    @State private var expanded: Set<String> = []
    @State private var selection: Set<String> = []

    var body: some View {
        Tree(TreeJudgeFixture.roots, children: \.children, expanded: self.$expanded, selection: self.$selection) { node in
            Text(verbatim: node.id)
        }
        .transaction { transaction in self.log.animations.append(transaction.animation) }
        .onChange(of: self.expanded) { self.log.expanded = self.expanded }
        .onChange(of: self.selection) { self.log.selection = self.selection }
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

@Suite("Tree 视图接线（macOS 托管窗口 + 合成事件）：按键经 onKeyPress 到归约，展开曲线取自环境动效档")
@MainActor
struct TreeHostedWiringTests {
    private static let chevronOfA = CGPoint(x: CoreSpacing.xs + 12, y: 22)
    private static let leftArrow = String(Character(UnicodeScalar(NSLeftArrowFunctionKey)!))
    private static let downArrow = String(Character(UnicodeScalar(NSDownArrowFunctionKey)!))

    private static func window(_ log: TreeHostedLog, motion: MotionPresentation = .animated) -> HostedWindow {
        HostedWindow(
            TreeHostedHarness(log: log).environment(\.coreMotionPresentationOverride, motion),
            size: CGSize(width: 260, height: 200),
            scheme: .light
        )
    }

    @Test("点 chevron 与按 ← 的展开事务都带环境动效档对应的曲线", arguments: MotionPresentation.allCases)
    func expansionTransactionsFollowTheEnvironment(motion: MotionPresentation) {
        let log = TreeHostedLog()
        let window = Self.window(log, motion: motion)
        defer { window.close() }
        let expected = CoreMotionToken.treeExpansion(for: motion)

        log.animations = []
        window.sendMouse(.leftMouseDown, at: Self.chevronOfA)
        window.sendMouse(.leftMouseUp, at: Self.chevronOfA)
        window.settle()
        #expect(log.expanded == ["a"], "点 chevron 没有展开 a——点击没走到 setExpansion，下面的曲线判据无意义")
        let pointer = log.animations.compactMap { $0 }

        log.animations = []
        window.sendKey(keyCode: 123, characters: Self.leftArrow)
        window.settle()
        #expect(log.expanded.isEmpty, "← 没有折叠 a——按键没经 onKeyPress 走到归约，下面的曲线判据无意义")
        let keyboard = log.animations.compactMap { $0 }

        for (path, animations) in [("点 chevron", pointer), ("按 ←", keyboard)] {
            if let expected {
                #expect(!animations.isEmpty, "\(path)：\(motion) 下展开事务没带曲线")
                #expect(animations.allSatisfy { $0 == expected }, "\(path)：\(motion) 下曲线应为 \(expected)，实得 \(animations)")
            } else {
                #expect(animations.isEmpty, "\(path)：hidden 下展开仍在补间，实得 \(animations)")
            }
        }
    }

    @Test("按键把归约结果写回宿主绑定：首键解析初始焦点，↓ 移焦，Space 选中")
    func keysWriteTheReducedStateBack() {
        let log = TreeHostedLog()
        let window = Self.window(log)
        defer { window.close() }
        window.sendKey(keyCode: 125, characters: Self.downArrow)
        window.sendKey(keyCode: 49, characters: " ")
        window.settle()
        #expect(log.selection == ["b"], "首键落在初始焦点 a，↓ 到 b，Space 应当选中 b，实得 \(log.selection)")
    }
}
#endif

// MARK: - 渲染

@Suite("Tree 渲染：选中态 / 展开态 / 父节点三态复选框")
@MainActor
struct TreeRenderTests {
    private static func pixels(
        _ view: some View,
        scheme: ColorScheme = .light,
        width: CGFloat = 260
    ) -> (bytes: [UInt8]?, width: Int, height: Int) {
        let renderer = ImageRenderer(
            content: view
                .frame(width: width)
                .padding(8)
                .background(Color.surfaceCanvas)
                .environment(\.colorScheme, scheme)
        )
        renderer.scale = 2
        _ = renderer.cgImage
        guard let image = renderer.cgImage else { return (nil, 0, 0) }
        let bytesPerRow = image.width * 4
        var bytes = [UInt8](repeating: 0, count: bytesPerRow * image.height)
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                  data: &bytes, width: image.width, height: image.height,
                  bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: space,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              )
        else { return (nil, image.width, image.height) }
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return (bytes, image.width, image.height)
    }

    // 同一内容连渲的噪声实测为 1 LSB；本套「应不同」里最弱的真实信号是选中底色，逐通道最大偏差 20。
    private static let minimumSignalDelta = 8
    private static let noiseTolerance = 2

    private static func expectVisiblyDifferent(
        _ a: [UInt8]?,
        _ b: [UInt8]?,
        _ comment: String,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        guard let metrics = bitmapDifferenceMetrics(a, b) else {
            #expect(
                Bool(false),
                Comment(rawValue: bitmapExpectationMessage("两张位图未渲染或长度不同。" + comment, a, b)),
                sourceLocation: sourceLocation
            )
            return
        }
        #expect(
            metrics.maxChannelDelta > Self.minimumSignalDelta,
            Comment(rawValue: bitmapExpectationMessage(
                "逐通道最大偏差 \(metrics.maxChannelDelta) ≤ \(Self.minimumSignalDelta)（差异字节 \(metrics.differingCount)），"
                + "在渲染噪声量级内，不算画得不同。" + comment, a, b
            )),
            sourceLocation: sourceLocation
        )
    }

    private static func tree(
        expanded: Set<String>,
        selection: Set<String> = [],
        checked: Set<String>? = nil,
        accent: Color? = nil
    ) -> some View {
        let tree = Tree(
            TreeJudgeFixture.roots,
            children: \.children,
            expanded: .constant(expanded),
            selection: .constant(selection),
            selectionMode: .multiple,
            checked: checked.map { Binding.constant($0) }
        ) { node in
            Text(verbatim: node.id)
        }
        return Group {
            if let accent {
                tree.coreAccent(accent)
            } else {
                tree
            }
        }
    }

    @Test("选中行与未选中行画出来不一样")
    func selectedRowDiffersFromUnselected() {
        let plain = Self.pixels(Self.tree(expanded: []))
        let selected = Self.pixels(Self.tree(expanded: [], selection: ["b"]))
        Self.expectVisiblyDifferent(plain.bytes, selected.bytes, "行选中没有任何视觉呈现")
    }

    @Test("选中底色跟着环境 coreAccent 走（与 TagGroup 同一条通路）")
    func selectionHighlightFollowsTheEnvironmentAccent() {
        let red = Self.pixels(Self.tree(expanded: [], selection: ["b"], accent: .red))
        let blue = Self.pixels(Self.tree(expanded: [], selection: ["b"], accent: .blue))
        Self.expectVisiblyDifferent(red.bytes, blue.bytes, "换 coreAccent 选中底色没变——底色没走环境")
        let redUnselected = Self.pixels(Self.tree(expanded: [], accent: .red))
        let blueUnselected = Self.pixels(Self.tree(expanded: [], accent: .blue))
        expectBitmapsEquivalent(
            redUnselected.bytes, blueUnselected.bytes,
            maxChannelDelta: Self.noiseTolerance,
            "没有选中项时换 accent 也变了——说明 accent 漏进了非选中的行"
        )
    }

    @Test("展开父节点后画面变高（子行真的画出来了）")
    func expandingMakesTheTreeTaller() {
        let collapsed = Self.pixels(Self.tree(expanded: []))
        let expanded = Self.pixels(Self.tree(expanded: ["a"]))
        #expect(collapsed.height > 0, "折叠态没渲染出来，下面的比较无意义")
        #expect(
            expanded.height > collapsed.height,
            "展开后高度没增加（折叠 \(collapsed.height)px vs 展开 \(expanded.height)px）——子行没画出来"
        )
    }

    @Test("父行的复选框在 off / mixed / on 三态下画出三张不同的图（子行全折叠，只有父行自己能产生差异）")
    func parentRowRendersThreeDistinctCheckStates() {
        let off = Self.pixels(Self.tree(expanded: [], checked: []))
        let mixed = Self.pixels(Self.tree(expanded: [], checked: ["a1x"]))
        let on = Self.pixels(Self.tree(expanded: [], checked: ["a1x", "a1y", "a2"]))
        Self.expectVisiblyDifferent(off.bytes, mixed.bytes, "off 与 mixed 画得一样——系统没从 Toggle(sources:) 派生出 mixed")
        Self.expectVisiblyDifferent(mixed.bytes, on.bytes, "mixed 与 on 画得一样")
        Self.expectVisiblyDifferent(off.bytes, on.bytes, "off 与 on 画得一样")
    }

    private static func row(focus: String?, showsFocusRing: Bool) -> some View {
        let context = TreeContext<[TreeJudgeNode], String, Text>(
            id: \.id,
            children: \.children,
            expanded: [],
            selection: [],
            checked: nil,
            focus: focus,
            metrics: TreeRowMetrics.resolve(.regular),
            showsFocusRing: showsFocusRing,
            select: { _ in },
            setExpansion: { _, _ in },
            notePointerCheck: {},
            content: { Text(verbatim: $0.id) }
        )
        return TreeRowView(element: TreeJudgeFixture.node("b"), level: 1, hasChildren: false, context: context)
            .padding(8)
    }

    @Test("焦点行在点击交互后不画焦点环，键盘交互后才画")
    func focusRingIsDrawnOnlyAfterKeyboardInteraction() {
        let unfocused = Self.pixels(Self.row(focus: nil, showsFocusRing: true))
        let pointer = Self.pixels(Self.row(focus: "b", showsFocusRing: false))
        let keyboard = Self.pixels(Self.row(focus: "b", showsFocusRing: true))
        Self.expectVisiblyDifferent(unfocused.bytes, keyboard.bytes, "键盘交互后焦点行没画焦点环——下面那条相等判据会空转")
        expectBitmapsEquivalent(
            unfocused.bytes, pointer.bytes, maxChannelDelta: Self.noiseTolerance, "点击选中后焦点行画出了焦点环"
        )
    }

    @Test("不传 checked 时不画复选框")
    func withoutTheCheckedBindingNoCheckBoxIsDrawn() {
        let withBox = Self.pixels(Self.tree(expanded: [], checked: []))
        let withoutBox = Self.pixels(Self.tree(expanded: []))
        Self.expectVisiblyDifferent(withoutBox.bytes, withBox.bytes, "传不传 checked 画得一样——复选框没接上")
    }
}

// MARK: - 密度

@Suite("Tree 密度：行度量从 controlSize 推导，渲染行距 / 缩进 / 行间距逐档跟随")
@MainActor
struct TreeDensityTests {
    private struct Expected {
        let rowHeight: CGFloat
        let disclosureWidth: CGFloat
        let indentation: CGFloat
        let chevronSize: CGFloat
        let rowSpacing: CGFloat
        let checkBoxGlyph: CGFloat
    }

    private static let table: [ControlSize: Expected] = [
        .mini: Expected(rowHeight: 20, disclosureWidth: 20, indentation: 10, chevronSize: 10, rowSpacing: 0, checkBoxGlyph: 12),
        .small: Expected(rowHeight: 22, disclosureWidth: 22, indentation: 11, chevronSize: 12, rowSpacing: 0, checkBoxGlyph: 14),
        .regular: Expected(rowHeight: 44, disclosureWidth: 24, indentation: 12, chevronSize: 14, rowSpacing: 2, checkBoxGlyph: 16),
        .large: Expected(rowHeight: 50, disclosureWidth: 28, indentation: 14, chevronSize: 16, rowSpacing: 2, checkBoxGlyph: 20),
        .extraLarge: Expected(rowHeight: 56, disclosureWidth: 32, indentation: 16, chevronSize: 18, rowSpacing: 2, checkBoxGlyph: 24),
    ]

    #if os(iOS)
    private static let platformFloor: CGFloat = 44
    #else
    private static let platformFloor: CGFloat = 0
    #endif

    private static func expected(_ size: ControlSize) -> Expected {
        guard let hit = Self.table[size] else {
            fatalError("推导表里没有 \(size)——ControlSize 新增了一档而判据没跟上")
        }
        return hit
    }

    private static func pitch(_ size: ControlSize) -> CGFloat {
        max(Self.expected(size).rowHeight, Self.platformFloor)
    }

    @Test("推导表五档逐项取值（不含平台下限）", arguments: ControlSize.allCases)
    func metricsMatchTheTable(size: ControlSize) {
        let metrics = TreeRowMetrics.resolve(size, platformFloor: 0)
        let want = Self.expected(size)
        #expect(metrics.rowHeight == want.rowHeight, "\(size) 行高")
        #expect(metrics.disclosureWidth == want.disclosureWidth, "\(size) 展开槽宽")
        #expect(metrics.indentation == want.indentation, "\(size) 缩进步长")
        #expect(metrics.chevronSize == want.chevronSize, "\(size) chevron 字号")
        #expect(metrics.rowSpacing == want.rowSpacing, "\(size) 行间距")
        #expect(metrics.checkBoxGlyph == want.checkBoxGlyph, "\(size) 复选框字形")
    }

    @Test(".regular 一档逐项等于 #422 写死的取值——默认外观在默认档位下不变")
    func regularEqualsTheShippedConstants() {
        let metrics = TreeRowMetrics.resolve(.regular, platformFloor: 0)
        #expect(metrics.rowHeight == CoreControlMetrics.height(for: .regular))
        #expect(metrics.disclosureWidth == CoreControlMetrics.iconSize(for: .regular) + CoreSpacing.sm)
        #expect(metrics.indentation == CoreSpacing.md)
        #expect(metrics.chevronSize == CoreControlMetrics.iconSize(for: .small))
        #expect(metrics.rowSpacing == CoreSpacing.xxs)
        #expect(metrics.checkBoxGlyph == CoreControlMetrics.iconSize(for: .regular))
    }

    @Test("五档单调不减：档位越大，每个量都不变小")
    func metricsAreMonotonic() {
        let all = ControlSize.allCases.map { TreeRowMetrics.resolve($0, platformFloor: 0) }
        for (lhs, rhs) in zip(all, all.dropFirst()) {
            #expect(lhs.rowHeight <= rhs.rowHeight)
            #expect(lhs.disclosureWidth <= rhs.disclosureWidth)
            #expect(lhs.indentation <= rhs.indentation)
            #expect(lhs.chevronSize <= rhs.chevronSize)
            #expect(lhs.rowSpacing <= rhs.rowSpacing)
            #expect(lhs.checkBoxGlyph <= rhs.checkBoxGlyph)
        }
    }

    @Test("平台下限只抬行高，不动其余各量")
    func platformFloorRaisesOnlyTheRowHeight() {
        let bare = TreeRowMetrics.resolve(.small, platformFloor: 0)
        let floored = TreeRowMetrics.resolve(.small, platformFloor: 44)
        #expect(floored.rowHeight == 44)
        #expect(floored.disclosureWidth == bare.disclosureWidth)
        #expect(floored.indentation == bare.indentation)
        #expect(floored.chevronSize == bare.chevronSize)
        #expect(floored.rowSpacing == bare.rowSpacing)
        #expect(floored.checkBoxGlyph == bare.checkBoxGlyph)
    }

    // MARK: - 渲染

    private static let leaf = [TreeJudgeNode(id: "leaf", children: nil)]
    private static let parent = [TreeJudgeNode(id: "p", children: [TreeJudgeNode(id: "c", children: nil)])]

    private static func tree(
        _ roots: [TreeJudgeNode],
        expanded: Set<String> = [],
        checked: Set<String>? = nil,
        size: ControlSize
    ) -> some View {
        Tree(
            roots,
            children: \.children,
            expanded: .constant(expanded),
            selection: .constant([]),
            checked: checked.map { Binding.constant($0) }
        ) { node in
            Text(verbatim: node.id)
        }
        .controlSize(size)
    }

    private static func swatchTree(size: ControlSize) -> some View {
        Tree(
            Self.parent,
            children: \.children,
            expanded: .constant(["p"]),
            selection: .constant([])
        ) { _ in
            Rectangle().fill(Color(red: 1, green: 0, blue: 0)).frame(width: 10, height: 10)
        }
        .tint(Color(white: 0.5))
        .controlSize(size)
    }

    private static func renderedHeight(_ view: some View) -> CGFloat {
        let renderer = ImageRenderer(content: view.frame(width: 260))
        renderer.scale = 1
        guard let image = renderer.cgImage else { return 0 }
        return CGFloat(image.height)
    }

    @Test("叶行渲染行距逐档等于推导表（iOS 过 44 下限）", arguments: ControlSize.allCases)
    func leafRowPitchFollowsControlSize(size: ControlSize) {
        let height = Self.renderedHeight(Self.tree(Self.leaf, size: size))
        #expect(height == Self.pitch(size), "\(size)：叶行渲染高 \(height)pt，应为 \(Self.pitch(size))pt")
    }

    @Test("带复选框的叶行渲染行距逐档等于推导表——复选框不把密集行撑回 44", arguments: ControlSize.allCases)
    func checkBoxRowPitchFollowsControlSize(size: ControlSize) {
        let height = Self.renderedHeight(Self.tree(Self.leaf, checked: [], size: size))
        #expect(height == Self.pitch(size), "\(size)：带复选框的叶行渲染高 \(height)pt，应为 \(Self.pitch(size))pt")
    }

    @Test("父行（有 chevron）折叠态渲染行距逐档等于推导表——chevron 命中槽不把密集行撑回 44", arguments: ControlSize.allCases)
    func parentRowPitchFollowsControlSize(size: ControlSize) {
        let height = Self.renderedHeight(Self.tree(Self.parent, size: size))
        #expect(height == Self.pitch(size), "\(size)：父行渲染高 \(height)pt，应为 \(Self.pitch(size))pt")
    }

    @Test("展开的两层树：总高 = 两个行距 + 一个行间距（嵌套层的行间距同样跟随档位）", arguments: [ControlSize.small, .regular])
    func nestedRowSpacingFollowsControlSize(size: ControlSize) {
        let height = Self.renderedHeight(Self.tree(Self.parent, expanded: ["p"], size: size))
        let want = 2 * Self.pitch(size) + Self.expected(size).rowSpacing
        #expect(height == want, "\(size)：两层树渲染高 \(height)pt，应为 \(want)pt")
    }

    @Test("父子两行色块左缘的列差等于该档的缩进步长", arguments: [ControlSize.small, .regular])
    func indentationFollowsControlSize(size: ControlSize) {
        let scale: CGFloat = 2
        let renderer = ImageRenderer(
            content: Self.swatchTree(size: size)
                .frame(width: 260)
                .background(Color.white)
                .environment(\.colorScheme, .light)
        )
        renderer.scale = scale
        guard let image = renderer.cgImage,
              let space = CGColorSpace(name: CGColorSpace.sRGB)
        else {
            Issue.record("\(size)：没渲染出来")
            return
        }
        let bytesPerRow = image.width * 4
        var bytes = [UInt8](repeating: 0, count: bytesPerRow * image.height)
        guard let context = CGContext(
            data: &bytes, width: image.width, height: image.height,
            bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            Issue.record("\(size)：取不到位图")
            return
        }
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        var leftEdges: [Int] = []
        var inSwatch = false
        for y in 0..<image.height {
            var left: Int?
            for x in 0..<image.width {
                let i = y * bytesPerRow + x * 4
                if bytes[i] > 200, bytes[i + 1] < 60, bytes[i + 2] < 60 {
                    left = x
                    break
                }
            }
            if let left, !inSwatch { leftEdges.append(left) }
            inSwatch = left != nil
        }
        #expect(leftEdges.count == 2, "\(size)：应找到父子两块色块，实得 \(leftEdges.count) 块")
        guard leftEdges.count == 2 else { return }
        let step = CGFloat(abs(leftEdges[1] - leftEdges[0])) / scale
        #expect(step == Self.expected(size).indentation, "\(size)：父子色块左缘差 \(step)pt，应为 \(Self.expected(size).indentation)pt")
    }
}
